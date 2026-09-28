// ─────────────────────────────────────────────────────────────────────────────
// lienzo_escritura.dart — Donde escribes el carácter con el dedo
//
// Capas (de abajo hacia arriba), cada una en su propio RepaintBoundary para
// que solo se repinte la que cambia:
//   1. Cuadrícula 米字格                              (nunca cambia)
//   2. Silueta gris del carácter (solo modo novato)   (cambia con el carácter)
//   3. Pista roja del trazo esperado al equivocarte   (un instante)
//   4. Animación del trazo correcto (modo novato)
//   5. Destello verde al acertar
//   6. Tu tinta                                       (cada punto del dedo)
//
// Cómo se evalúa cada trazo:
//   - Al levantar el dedo, tu trazo se compara con la "mediana" (línea
//     central) del trazo que sigue, usando DTW (ver dtw_helper.dart).
//   - Si el costo es menor que [umbralDtw] × ancho del lienzo, es correcto.
//   - Los trazos deben hacerse en orden, como en la escritura real.
//
// Rendimiento:
//   - Se usa Listener (eventos crudos del dedo) en vez de GestureDetector:
//     no espera a que el dedo se mueva unos píxeles para empezar, así el
//     trazo arranca justo donde tocas.
//   - Cada punto solo avisa al ControladorTrazos; no se llama a setState, así
//     que el resto de la pantalla no se reconstruye mientras dibujas.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/cache_trazos.dart';
import '../helpers/dtw_helper.dart';
import '../painters/fondo_caracter_painter.dart';
import '../painters/geometria.dart';
import '../painters/grid_painter.dart';
import '../painters/pincel_painter.dart';
import '../painters/pista_roja_painter.dart';
import '../painters/trazo_guia_painter.dart';

class LienzoEscritura extends StatefulWidget {
  const LienzoEscritura({
    super.key,
    required this.caracter,
    required this.trazosSvg,
    required this.medianas,
    required this.modoNovato,
    required this.onCompletado,
  });

  /// El carácter (se usa como clave de la caché de contornos).
  final String caracter;

  /// Contornos SVG de cada trazo y sus medianas (coordenadas de 1024×1024).
  final List<String> trazosSvg;
  final List<List<Offset>> medianas;

  /// Novato: muestra la silueta del carácter y anima el trazo correcto
  /// cuando te equivocas. Experto: sin silueta ni animación.
  final bool modoNovato;

  /// Se llama al completar todos los trazos, con el número de errores.
  final ValueChanged<int> onCompletado;

  /// Qué tan tolerante es la evaluación: costo DTW máximo aceptado como
  /// fracción del ancho del lienzo. Más alto = más permisivo.
  static const double umbralDtw = 0.28;

  @override
  State<LienzoEscritura> createState() => LienzoEscrituraState();
}

class LienzoEscrituraState extends State<LienzoEscritura>
    with SingleTickerProviderStateMixin {
  final ControladorTrazos _tinta = ControladorTrazos();
  late final AnimationController _guia = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late List<Path> _contornos;
  int _siguienteTrazo = 0;
  int _errores = 0;
  bool _completo = false;
  bool _mostrarPista = false;
  bool _mostrarGuia = false;
  bool _destello = false;
  int? _punteroActivo;

  // Medianas convertidas a píxeles; se recalculan solo si cambia el tamaño.
  Size _tamano = Size.zero;
  List<List<Offset>> _medianasLienzo = const [];

  final List<Timer> _temporizadores = [];

  int get errores => _errores;
  bool get completo => _completo;

  @override
  void initState() {
    super.initState();
    _contornos = CacheTrazos.contornos(widget.caracter, widget.trazosSvg);
    _completo = widget.medianas.isEmpty; // sin datos de trazo: nada que dibujar
  }

  @override
  void didUpdateWidget(LienzoEscritura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caracter != widget.caracter) {
      _contornos = CacheTrazos.contornos(widget.caracter, widget.trazosSvg);
      _tamano = Size.zero; // fuerza recalcular medianas
      reiniciar();
    }
  }

  @override
  void dispose() {
    _cancelarTemporizadores();
    _guia.dispose();
    _tinta.dispose();
    super.dispose();
  }

  /// Borra lo dibujado y vuelve al primer trazo (botón ↻).
  void reiniciar() {
    _cancelarTemporizadores(); // que un borrado pendiente no toque lo nuevo
    _tinta.limpiar();
    _guia.reset();
    setState(() {
      _siguienteTrazo = 0;
      _errores = 0;
      _completo = widget.medianas.isEmpty; // sin datos de trazo: nada que dibujar
      _mostrarPista = false;
      _mostrarGuia = false;
      _destello = false;
    });
  }

  void _despues(Duration d, VoidCallback accion) {
    late final Timer t;
    t = Timer(d, () {
      _temporizadores.remove(t);
      if (mounted) accion();
    });
    _temporizadores.add(t);
  }

  void _cancelarTemporizadores() {
    for (final t in _temporizadores) {
      t.cancel();
    }
    _temporizadores.clear();
  }

  // ── Eventos del dedo ─────────────────────────────────────────────────────

  void _alTocar(PointerDownEvent e) {
    if (_completo || _punteroActivo != null) return; // un solo dedo a la vez
    _punteroActivo = e.pointer;
    _tinta.empezar(e.localPosition);
  }

  void _alMover(PointerMoveEvent e) {
    if (e.pointer != _punteroActivo) return;
    _tinta.agregar(e.localPosition);
  }

  void _alSoltar(PointerUpEvent e) {
    if (e.pointer != _punteroActivo) return;
    _punteroActivo = null;
    _evaluar();
  }

  void _alCancelar(PointerCancelEvent e) {
    if (e.pointer != _punteroActivo) return;
    _punteroActivo = null;
    _tinta.descartarActual();
  }

  // ── Evaluación ───────────────────────────────────────────────────────────

  void _evaluar() {
    final puntos = _tinta.puntosActuales;
    if (_siguienteTrazo >= _medianasLienzo.length) {
      _tinta.descartarActual();
      return;
    }
    // Un toque sin movimiento no cuenta ni como acierto ni como error.
    if (puntos.length < 2) {
      _tinta.descartarActual();
      return;
    }

    final costo = DTWHelper.calcular(puntos, _medianasLienzo[_siguienteTrazo]);
    final acierto = costo <= _tamano.width * LienzoEscritura.umbralDtw;

    if (acierto) {
      HapticFeedback.lightImpact();
      _tinta.aceptarActual();
      _guia.reset();
      setState(() {
        _siguienteTrazo++;
        _mostrarGuia = false;
        _destello = true;
        if (_siguienteTrazo >= _medianasLienzo.length) _completo = true;
      });
      _despues(const Duration(milliseconds: 300), () => setState(() => _destello = false));
      if (_completo) widget.onCompletado(_errores);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errores++;
        _mostrarPista = true;
        _mostrarGuia = widget.modoNovato;
      });
      if (widget.modoNovato) _guia.forward(from: 0);
      // El trazo equivocado se ve un instante y luego se borra. Si en ese
      // instante ya empezaste otro trazo, NO se toca (ese es el nuevo intento;
      // el equivocado ya desapareció al empezarlo).
      final trazoEquivocado = _tinta.numeroTrazo;
      _despues(const Duration(milliseconds: 450), () {
        if (_tinta.numeroTrazo == trazoEquivocado) _tinta.descartarActual();
        setState(() => _mostrarPista = false);
      });
      _despues(const Duration(milliseconds: 1800), () => setState(() => _mostrarGuia = false));
    }
  }

  // ── Dibujo ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, restricciones) {
      final tamano = restricciones.biggest;
      if (tamano != _tamano) {
        _tamano = tamano;
        _medianasLienzo = [
          for (final m in widget.medianas) GeometriaLienzo.trazoALienzo(m, tamano),
        ];
      }
      final hayTrazoPendiente = _siguienteTrazo < _contornos.length;

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _alTocar,
        onPointerMove: _alMover,
        onPointerUp: _alSoltar,
        onPointerCancel: _alCancelar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: CustomPaint(painter: GridPainter())),
            if (widget.modoNovato)
              RepaintBoundary(
                child: CustomPaint(painter: FondoCaracterPainter(_contornos)),
              ),
            if (hayTrazoPendiente)
              RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: _mostrarPista ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: CustomPaint(painter: PistaRojaPainter(_contornos[_siguienteTrazo])),
                ),
              ),
            if (_mostrarGuia && _siguienteTrazo < _medianasLienzo.length)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _guia,
                  builder: (context, _) => CustomPaint(
                    painter: TrazoGuiaPainter(
                      puntos: _medianasLienzo[_siguienteTrazo],
                      progreso: Curves.easeInOut.transform(_guia.value),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _destello ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const ColoredBox(color: Color(0x1A00C853)),
              ),
            ),
            RepaintBoundary(child: CustomPaint(painter: PincelPainter(_tinta))),
          ],
        ),
      );
    });
  }
}

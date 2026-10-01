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
//   7. Aviso "al revés"                               (un instante)
//
// Cómo se evalúa cada trazo (ver evaluacion_trazo.dart):
//   - Al levantar el dedo, tu trazo se compara con la "mediana" (línea
//     central) del trazo que sigue, usando DTW (ver dtw_helper.dart).
//   - Si el costo es menor que [umbralDtw] × ancho del lienzo y va en el
//     sentido correcto, es correcto. Si la forma está bien pero va al revés,
//     se te avisa y se muestra por dónde empieza.
//   - Los trazos deben hacerse en orden, como en la escritura real.
//
// Ajuste caligráfico (si está activo en Ajustes): un trazo correcto se
// transforma, con un rebote de resorte, en el trazo exacto del carácter
// (ver ajuste_trazo.dart). Puedes seguir escribiendo mientras se acomoda.
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
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../helpers/cache_trazos.dart';
import '../helpers/evaluacion_trazo.dart';
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
    this.ajusteCaligrafico = true,
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

  /// true: cada trazo correcto se acomoda en su forma caligráfica exacta.
  /// false: se queda tal como lo dibujaste.
  final bool ajusteCaligrafico;

  /// Qué tan tolerante es la evaluación: costo DTW máximo aceptado como
  /// fracción del ancho del lienzo. Más alto = más permisivo.
  static const double umbralDtw = 0.28;

  /// "Carácter" del resorte con el que se acomoda el trazo:
  ///   rigidez: más alta = más rápido (420 ≈ se asienta en ~0.35 s).
  ///   amortiguamiento: 1.0 = sin rebote; más bajo = rebota más
  ///   (0.62 ≈ se pasa un 8 % de su lugar y regresa una vez).
  static const double rigidezResorte = 420;
  static const double amortiguamientoResorte = 0.62;

  @override
  State<LienzoEscritura> createState() => LienzoEscrituraState();
}

class LienzoEscrituraState extends State<LienzoEscritura>
    with TickerProviderStateMixin {
  final ControladorTrazos _tinta = ControladorTrazos();

  /// Animación de la guía azul. Se crea en initState (no "perezosa"): si se
  /// creara la primera vez que se usa y eso fuera en dispose(), Flutter
  /// fallaría al buscar el TickerMode de un widget que ya se está quitando.
  late final AnimationController _guia;

  late List<Path> _contornos;
  int _siguienteTrazo = 0;
  int _errores = 0;
  bool _completo = false;
  bool _mostrarPista = false;
  bool _mostrarGuia = false;
  bool _destello = false;
  bool _avisoAlReves = false;
  int? _punteroActivo;

  /// Resortes de los trazos que se están acomodando (número de ajuste → animación).
  final Map<int, AnimationController> _resortes = {};

  // Medianas convertidas a píxeles; se recalculan solo si cambia el tamaño.
  Size _tamano = Size.zero;
  List<List<Offset>> _medianasLienzo = const [];

  final List<Timer> _temporizadores = [];

  int get errores => _errores;
  bool get completo => _completo;

  @override
  void initState() {
    super.initState();
    _guia = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
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
    _cancelarResortes();
    _guia.dispose();
    _tinta.dispose();
    super.dispose();
  }

  /// Borra lo dibujado y vuelve al primer trazo (botón ↻).
  void reiniciar() {
    _cancelarTemporizadores(); // que un borrado pendiente no toque lo nuevo
    _cancelarResortes();
    _tinta.limpiar();
    _guia.reset();
    setState(() {
      _siguienteTrazo = 0;
      _errores = 0;
      _completo = widget.medianas.isEmpty; // sin datos de trazo: nada que dibujar
      _mostrarPista = false;
      _mostrarGuia = false;
      _destello = false;
      _avisoAlReves = false;
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

  /// Detiene los acomodos en curso (al reiniciar o salir). Sus futures no se
  /// completan al cancelarlos, así que no se cierran dos veces.
  void _cancelarResortes() {
    final resortes = _resortes.values.toList();
    _resortes.clear();
    for (final r in resortes) {
      r.dispose();
    }
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

    final resultado = EvaluacionTrazo.evaluar(
      puntos,
      _medianasLienzo[_siguienteTrazo],
      _tamano.width * LienzoEscritura.umbralDtw,
    );

    if (resultado == ResultadoTrazo.correcto) {
      HapticFeedback.lightImpact();
      _aceptarTrazo(_siguienteTrazo);
      _guia.reset();
      setState(() {
        _siguienteTrazo++;
        _mostrarGuia = false;
        _avisoAlReves = false;
        _destello = true;
        if (_siguienteTrazo >= _medianasLienzo.length) _completo = true;
      });
      _despues(const Duration(milliseconds: 300), () => setState(() => _destello = false));
      if (_completo) widget.onCompletado(_errores);
    } else {
      HapticFeedback.heavyImpact();
      final alReves = resultado == ResultadoTrazo.alReves;
      // Al revés, la animación del trazo correcto se muestra también en modo
      // experto: es la forma más clara de enseñar por dónde empieza.
      final mostrarGuia = widget.modoNovato || alReves;
      setState(() {
        _errores++;
        _mostrarPista = true;
        _mostrarGuia = mostrarGuia;
        _avisoAlReves = alReves;
      });
      if (mostrarGuia) _guia.forward(from: 0);
      // El trazo equivocado se ve un instante y luego se borra. Si en ese
      // instante ya empezaste otro trazo, NO se toca (ese es el nuevo intento;
      // el equivocado ya desapareció al empezarlo).
      final trazoEquivocado = _tinta.numeroTrazo;
      _despues(const Duration(milliseconds: 450), () {
        if (_tinta.numeroTrazo == trazoEquivocado) _tinta.descartarActual();
        setState(() => _mostrarPista = false);
      });
      _despues(const Duration(milliseconds: 1800), () => setState(() {
            _mostrarGuia = false;
            _avisoAlReves = false;
          }));
    }
  }

  /// Deja el trazo [indice] en el lienzo: acomodándolo con el resorte en su
  /// forma caligráfica, o tal como lo dibujaste si el ajuste está apagado.
  void _aceptarTrazo(int indice) {
    if (!widget.ajusteCaligrafico || indice >= _contornos.length) {
      _tinta.aceptarActual();
      return;
    }
    final mediana = _medianasLienzo[indice];
    final id = _tinta.ajustarActual(
      GeometriaLienzo.pathALienzo(_contornos[indice], _tamano),
      mediana.first,
      mediana.last,
    );
    final resorte = AnimationController.unbounded(vsync: this);
    _resortes[id] = resorte;
    resorte.addListener(() => _tinta.moverAjuste(id, resorte.value));
    final fisica = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: LienzoEscritura.rigidezResorte,
      ratio: LienzoEscritura.amortiguamientoResorte,
    );
    resorte.animateWith(SpringSimulation(fisica, 0, 1, 0)).whenComplete(() {
      if (_resortes.remove(id) == null) return; // se canceló al reiniciar
      resorte.dispose();
      _tinta.terminarAjuste(id);
    });
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
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _avisoAlReves ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(child: _AvisoAlReves()),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Pastilla "Al revés" que aparece arriba del lienzo.
class _AvisoAlReves extends StatelessWidget {
  const _AvisoAlReves();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x55D32F2F)),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: const Text(
        '↺  Al revés: empieza donde inicia la flecha',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC62828)),
      ),
    );
  }
}

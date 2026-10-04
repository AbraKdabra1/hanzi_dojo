// ─────────────────────────────────────────────────────────────────────────────
// pantalla_inicio.dart — Pantalla principal
//
// - Resumen del día: repasos pendientes, nuevos que llevas vs. tu meta y tu
//   racha de días seguidos (🔥).
// - Botón "Estudiar" → elegir modo (novato/experto) y qué estudiar.
// - Botón "Leer" → libros graduados por nivel HSK (pantalla_biblioteca.dart).
// - Botón "Oído" → tonos, escucha y pinyin con grabaciones (pantalla_oido.dart).
// - Estadísticas y Ajustes.
// - Abajo, una frase que cambia cada 4 segundos con un giro suave (solo
//   mientras la pantalla se ve: con otra pantalla encima o la app en segundo
//   plano el reloj se detiene, para no gastar batería).
// - Fondo: rama de ciruelo en flor que se mece con el viento y suelta pétalos
//   (ver fondo_tinta.dart y painters/rama_ciruelo.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/estadisticas.dart';
import '../tema.dart';
import '../widgets/fondo_tinta.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_biblioteca.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_modo.dart';
import 'pantalla_oido.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> with WidgetsBindingObserver {
  static const _frases = [
    'El viaje de mil millas comienza con un solo paso.',
    'Aprender es un tesoro que seguirá a su dueño a todas partes.',
    'No temas ir despacio, teme solo a detenerte.',
    'La paciencia es una planta amarga, pero su fruto es dulce.',
  ];
  int _indiceFrase = 0;
  Timer? _temporizador;

  int? _pendientes;
  int? _nuevosHoy;
  int? _meta;
  int _racha = 0;

  bool _visible = true;
  bool _enPrimerPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarResumen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // false mientras otra pantalla está encima.
    _visible = ModalRoute.of(context)?.isCurrent ?? true;
    _actualizarFrases();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    _actualizarFrases();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizador?.cancel();
    super.dispose();
  }

  /// El reloj de las frases corre solo mientras la pantalla se ve.
  void _actualizarFrases() {
    final correr = _visible && _enPrimerPlano;
    if (correr && _temporizador == null) {
      _temporizador = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) setState(() => _indiceFrase = (_indiceFrase + 1) % _frases.length);
      });
    } else if (!correr && _temporizador != null) {
      _temporizador!.cancel();
      _temporizador = null;
    }
  }

  Future<void> _cargarResumen() async {
    final repo = DatosApp.de(context);
    final pendientes = await repo.repasosPendientes();
    final nuevos = await repo.nuevosHoy();
    final meta = await repo.limiteNuevosPorDia();
    final actividad = await repo.actividadPorDia();
    if (!mounted) return;
    setState(() {
      _pendientes = pendientes;
      _nuevosHoy = nuevos;
      _meta = meta;
      _racha = Estadisticas.racha(actividad.map((d) => d.dia), DateTime.now()).actual;
    });
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargarResumen(); // al volver, actualizar el resumen del día
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return FondoTintaChina(
      ramaAnimada: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.settings_outlined, color: c.icono),
                  tooltip: 'Ajustes y créditos',
                  onPressed: () => _ir(const PantallaAjustes()),
                ),
              ),
              const Spacer(),
              const Text('汉字道场', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('Hanzi Dojo', style: TextStyle(fontSize: 14, color: c.tenue, letterSpacing: 2)),
              const SizedBox(height: 28),
              _ResumenDelDia(pendientes: _pendientes, nuevosHoy: _nuevosHoy, meta: _meta, racha: _racha),
              const SizedBox(height: 28),

              // Botón principal → PantallaModo
              Material(
                color: c.boton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: c.bordeTarjeta, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _ir(const PantallaModo()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                    child: Text('Estudiar',
                        style: TextStyle(fontSize: 18, color: c.textoBoton, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botones secundarios: «Leer» (libros graduados) y «Oído» (tonos,
              // escucha y pinyin con grabaciones de nativos).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotonSecundario(
                    icono: Icons.menu_book_rounded,
                    texto: 'Leer',
                    onTap: () => _ir(const PantallaBiblioteca()),
                  ),
                  const SizedBox(width: 10),
                  _BotonSecundario(
                    icono: Icons.hearing_rounded,
                    texto: 'Oído',
                    onTap: () => _ir(const PantallaOido()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Botón estadísticas (con fondo de papel translúcido: si un pétalo
              // pasa por detrás, el texto se sigue leyendo bien).
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: c.translucido,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(Icons.pie_chart_outline, color: c.suave, size: 20),
                label: Text('Ver mis estadísticas',
                    style: TextStyle(color: c.suave, fontSize: 15, fontWeight: FontWeight.w500)),
                onPressed: () => _ir(const PantallaEstadisticas()),
              ),
              const Spacer(),

              // Frase que gira cada 4 s
              SizedBox(
                height: 60,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animacion) {
                      final giro = Tween(begin: math.pi / 2, end: 0.0)
                          .animate(CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic));
                      return AnimatedBuilder(
                        animation: animacion,
                        child: child,
                        builder: (context, child) => Transform(
                          transform: Matrix4.rotationX(giro.value),
                          alignment: Alignment.center,
                          child: Opacity(opacity: animacion.value, child: child),
                        ),
                      );
                    },
                    child: Text(
                      _frases[_indiceFrase],
                      key: ValueKey<int>(_indiceFrase),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.suave, fontStyle: FontStyle.italic, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón con borde (Leer, Oído) bajo el botón principal.
class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({required this.icono, required this.texto, required this.onTap});

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: c.tinta, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20, color: c.tinta),
              const SizedBox(width: 8),
              Text(texto, style: TextStyle(fontSize: 17, color: c.tinta, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "12 repasos pendientes · 3 de 15 nuevos hoy"
class _ResumenDelDia extends StatelessWidget {
  const _ResumenDelDia({required this.pendientes, required this.nuevosHoy, required this.meta, this.racha = 0});

  final int? pendientes;
  final int? nuevosHoy;
  final int? meta;

  /// Días seguidos estudiando (0 = no se muestra).
  final int racha;

  @override
  Widget build(BuildContext context) {
    if (pendientes == null) return const SizedBox(height: 40);
    final c = context.colores;
    final estilo = TextStyle(fontSize: 13, color: c.suave);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.translucido,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.bordeTarjeta),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.replay_rounded, size: 16, color: c.icono),
          const SizedBox(width: 4),
          Text('$pendientes ${pendientes == 1 ? 'repaso' : 'repasos'} hoy', style: estilo),
          const SizedBox(width: 14),
          Icon(Icons.fiber_new_outlined, size: 18, color: c.icono),
          const SizedBox(width: 4),
          Text('$nuevosHoy de $meta nuevos', style: estilo),
          if (racha > 0) ...[
            const SizedBox(width: 14),
            Text('🔥 $racha', style: estilo.copyWith(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

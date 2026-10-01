// ─────────────────────────────────────────────────────────────────────────────
// pantalla_inicio.dart — Pantalla principal
//
// - Resumen del día: repasos pendientes y nuevos que llevas vs. tu meta.
// - Botón "Estudiar" → elegir modo (novato/experto) y qué estudiar.
// - Botón "Leer" → libros graduados por nivel HSK (pantalla_biblioteca.dart).
// - Estadísticas y Ajustes.
// - Abajo, una frase que cambia cada 4 segundos con un giro suave.
// - Fondo: ilustración del Templo del Cielo (ver fondo_tinta.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../widgets/fondo_tinta.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_biblioteca.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_modo.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
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

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _indiceFrase = (_indiceFrase + 1) % _frases.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarResumen());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargarResumen() async {
    final repo = DatosApp.de(context);
    final pendientes = await repo.repasosPendientes();
    final nuevos = await repo.nuevosHoy();
    final meta = await repo.limiteNuevosPorDia();
    if (!mounted) return;
    setState(() {
      _pendientes = pendientes;
      _nuevosHoy = nuevos;
      _meta = meta;
    });
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargarResumen(); // al volver, actualizar el resumen del día
  }

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      templo: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.black54),
                  tooltip: 'Ajustes y créditos',
                  onPressed: () => _ir(const PantallaAjustes()),
                ),
              ),
              const Spacer(),
              const Text('汉字道场', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('Hanzi Dojo', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, letterSpacing: 2)),
              const SizedBox(height: 28),
              _ResumenDelDia(pendientes: _pendientes, nuevosHoy: _nuevosHoy, meta: _meta),
              const SizedBox(height: 28),

              // Botón principal → PantallaModo
              Material(
                color: const Color(0xDE000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Color(0x4DFFFFFF), width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _ir(const PantallaModo()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                    child: Text('Estudiar',
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón secundario → «Leer» (libros graduados por nivel HSK)
              Material(
                color: const Color(0xCCFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Color(0xDE000000), width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _ir(const PantallaBiblioteca()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 20, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Leer',
                            style: TextStyle(fontSize: 17, color: Colors.black87, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón estadísticas (con fondo de papel translúcido: en pantallas
              // cortas queda encima del templo y así se sigue leyendo bien).
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x99FFFFFF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(Icons.pie_chart_outline, color: Colors.grey.shade800, size: 20),
                label: Text('Ver mis estadísticas',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 15, fontWeight: FontWeight.w500)),
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
                      style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic, fontSize: 14),
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

/// "12 repasos pendientes · 3 de 15 nuevos hoy"
class _ResumenDelDia extends StatelessWidget {
  const _ResumenDelDia({required this.pendientes, required this.nuevosHoy, required this.meta});

  final int? pendientes;
  final int? nuevosHoy;
  final int? meta;

  @override
  Widget build(BuildContext context) {
    if (pendientes == null) return const SizedBox(height: 40);
    final estilo = TextStyle(fontSize: 13, color: Colors.grey.shade700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x99FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xB3FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_rounded, size: 16, color: Colors.black54),
          const SizedBox(width: 4),
          Text('$pendientes ${pendientes == 1 ? 'repaso' : 'repasos'} hoy', style: estilo),
          const SizedBox(width: 14),
          const Icon(Icons.fiber_new_outlined, size: 18, color: Colors.black54),
          const SizedBox(width: 4),
          Text('$nuevosHoy de $meta nuevos', style: estilo),
        ],
      ),
    );
  }
}

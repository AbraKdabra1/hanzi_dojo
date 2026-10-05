// ─────────────────────────────────────────────────────────────────────────────
// animacion_trazos.dart — El orden de trazos completo, animado (fase 7)
//
// Antes de escribir un carácter puedes ver cómo se hace: cada trazo aparece
// en orden, «pintado» de su inicio a su fin como con un pincel, y queda su
// número junto al punto donde empieza. Se repite con un toque.
//
// Cómo se pinta un trazo a medias: se recorta el lienzo con el contorno del
// trazo (make-me-a-hanzi) y se dibuja encima una línea gruesa que sigue su
// mediana hasta donde va la animación. Así el trazo crece en la dirección
// correcta y con su forma exacta.
//
// Batería: el AnimationController corre solo mientras la animación avanza
// (unos segundos) y se detiene al terminar.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../helpers/cache_trazos.dart';
import '../idioma.dart';
import '../painters/geometria.dart';
import '../painters/grid_painter.dart';
import '../tema.dart';

/// Hoja inferior con la animación del orden de trazos de [caracter].
Future<void> mostrarOrdenDeTrazos(
  BuildContext context, {
  required String caracter,
  required List<String> trazosSvg,
  required List<List<Offset>> medianas,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HojaOrden(caracter: caracter, trazosSvg: trazosSvg, medianas: medianas),
  );
}

class _HojaOrden extends StatelessWidget {
  const _HojaOrden({required this.caracter, required this.trazosSvg, required this.medianas});

  final String caracter;
  final List<String> trazosSvg;
  final List<List<Offset>> medianas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final lado = math.min(MediaQuery.sizeOf(context).width - 64, 340.0);
    return Container(
      decoration: BoxDecoration(
        color: c.hoja,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: c.separador, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Text(tr('Orden de trazos'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            width: lado,
            height: lado + 52,
            child: AnimacionTrazos(caracter: caracter, trazosSvg: trazosSvg, medianas: medianas),
          ),
        ],
      ),
    );
  }
}

/// El carácter que se dibuja solo, trazo por trazo, con un botón para repetir.
class AnimacionTrazos extends StatefulWidget {
  const AnimacionTrazos({
    super.key,
    required this.caracter,
    required this.trazosSvg,
    required this.medianas,
    this.segundosPorTrazo = 0.7,
  });

  final String caracter;
  final List<String> trazosSvg;

  /// En coordenadas de make-me-a-hanzi (Caracter.medianas).
  final List<List<Offset>> medianas;
  final double segundosPorTrazo;

  @override
  State<AnimacionTrazos> createState() => _AnimacionTrazosState();
}

class _AnimacionTrazosState extends State<AnimacionTrazos> with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late final List<Path> _contornos;

  int get _n => math.min(widget.trazosSvg.length, widget.medianas.length);

  @override
  void initState() {
    super.initState();
    _contornos = CacheTrazos.contornos(widget.caracter, widget.trazosSvg);
    _control = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (math.max(_n, 1) * widget.segundosPorTrazo * 1000).round()),
    )..forward();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _repetir() => _control.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: c.lienzo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.bordeLienzo, width: 1.5),
              ),
              child: GestureDetector(
                onTap: _repetir,
                child: CustomPaint(
                  painter: GridPainter(color: c.cuadricula),
                  foregroundPainter: _PintorOrden(
                    contornos: _contornos,
                    medianas: widget.medianas,
                    progreso: _control,
                    n: _n,
                    tinta: c.trazo,
                    actual: c.oscuro ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
                    silueta: c.silueta,
                    numero: c.tenue,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _control,
          builder: (context, _) {
            final k = math.min((_control.value * _n).floor() + 1, _n);
            final terminado = _control.isCompleted;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  terminado ? tr('{0} trazos', [_n]) : tr('Trazo {0} de {1}', [k, _n]),
                  style: TextStyle(fontSize: 14, color: c.suave),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _repetir,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(tr('Repetir')),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PintorOrden extends CustomPainter {
  _PintorOrden({
    required this.contornos,
    required this.medianas,
    required this.progreso,
    required this.n,
    required this.tinta,
    required this.actual,
    required this.silueta,
    required this.numero,
  }) : super(repaint: progreso);

  final List<Path> contornos;
  final List<List<Offset>> medianas;
  final Animation<double> progreso;
  final int n;
  final Color tinta;
  final Color actual;
  final Color silueta;
  final Color numero;

  @override
  void paint(Canvas canvas, Size size) {
    if (n == 0) return;
    final avance = progreso.value * n; // 2.4 = dos trazos completos y 40 % del tercero
    final relleno = Paint()..style = PaintingStyle.fill;

    canvas.save();
    GeometriaLienzo.aplicar(canvas, size); // de aquí en adelante, coordenadas de make-me-a-hanzi
    for (var i = 0; i < n; i++) {
      final contorno = contornos[i];
      if (avance >= i + 1) {
        canvas.drawPath(contorno, relleno..color = tinta);
      } else if (avance > i) {
        canvas.drawPath(contorno, relleno..color = silueta);
        canvas.save();
        canvas.clipPath(contorno);
        canvas.drawPath(
          _parcial(medianas[i], avance - i),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 150
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = actual,
        );
        canvas.restore();
      } else {
        canvas.drawPath(contorno, relleno..color = silueta);
      }
    }
    canvas.restore();

    // Número de cada trazo ya empezado, junto a su punto de inicio.
    final hasta = math.min(avance.ceil(), n);
    for (var i = 0; i < hasta; i++) {
      if (medianas[i].isEmpty) continue;
      final p = GeometriaLienzo.aLienzo(medianas[i].first, size);
      final texto = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(fontSize: size.width * 0.045, color: numero, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      texto.paint(canvas, p - Offset(texto.width / 2, texto.height * 1.1));
      texto.dispose();
    }
  }

  /// La mediana desde su inicio hasta la fracción [t] de su largo.
  static Path _parcial(List<Offset> puntos, double t) {
    final ruta = Path();
    if (puntos.isEmpty) return ruta;
    ruta.moveTo(puntos.first.dx, puntos.first.dy);
    var total = 0.0;
    for (var k = 1; k < puntos.length; k++) {
      total += (puntos[k] - puntos[k - 1]).distance;
    }
    var restante = total * t.clamp(0.0, 1.0);
    for (var k = 1; k < puntos.length && restante > 0; k++) {
      final tramo = puntos[k] - puntos[k - 1];
      final largo = tramo.distance;
      if (largo <= restante) {
        ruta.lineTo(puntos[k].dx, puntos[k].dy);
        restante -= largo;
      } else {
        final p = puntos[k - 1] + tramo * (restante / largo);
        ruta.lineTo(p.dx, p.dy);
        restante = 0;
      }
    }
    if (puntos.length == 1 || total == 0) ruta.lineTo(puntos.first.dx + 1, puntos.first.dy);
    return ruta;
  }

  @override
  bool shouldRepaint(_PintorOrden old) =>
      old.contornos != contornos || old.tinta != tinta || old.silueta != silueta || old.n != n;
}

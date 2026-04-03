import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dibuja el trazo esperado como una línea animada azul que avanza
/// de inicio a fin según [progreso] (0.0 → 1.0).
/// Incluye un punto brillante en la punta para mayor claridad.
class TrazoGuiaPainter extends CustomPainter {
  final List<Offset> puntos;
  final double progreso; // 0.0 a 1.0

  const TrazoGuiaPainter({
    required this.puntos,
    required this.progreso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.length < 2) return;

    // Calcular longitud total del trazo
    final List<double> distancias = [0.0];
    double longitudTotal = 0;
    for (int i = 1; i < puntos.length; i++) {
      longitudTotal += _dist(puntos[i - 1], puntos[i]);
      distancias.add(longitudTotal);
    }

    final double objetivo = longitudTotal * progreso;

    // Pincel principal — trazo azul semitransparente
    final paintLinea = Paint()
      ..color = const Color(0xCC2979FF)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Pincel de fondo — halo suave
    final paintHalo = Paint()
      ..color = const Color(0x332979FF)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path     = Path();
    final pathHalo = Path();

    path.moveTo(puntos.first.dx, puntos.first.dy);
    pathHalo.moveTo(puntos.first.dx, puntos.first.dy);

    Offset puntoActual = puntos.first;

    for (int i = 1; i < puntos.length; i++) {
      final double dAcum = distancias[i];

      if (dAcum <= objetivo) {
        // Segmento completo dentro del progreso
        path.lineTo(puntos[i].dx, puntos[i].dy);
        pathHalo.lineTo(puntos[i].dx, puntos[i].dy);
        puntoActual = puntos[i];
      } else {
        // Segmento parcial
        final double dPrev = distancias[i - 1];
        final double resto = objetivo - dPrev;
        final double segmento = dAcum - dPrev;
        if (segmento > 0) {
          final double t = resto / segmento;
          puntoActual = Offset(
            puntos[i - 1].dx + t * (puntos[i].dx - puntos[i - 1].dx),
            puntos[i - 1].dy + t * (puntos[i].dy - puntos[i - 1].dy),
          );
          path.lineTo(puntoActual.dx, puntoActual.dy);
          pathHalo.lineTo(puntoActual.dx, puntoActual.dy);
        }
        break;
      }
    }

    canvas.drawPath(pathHalo, paintHalo);
    canvas.drawPath(path, paintLinea);

    // Punto brillante en la punta (solo si hay progreso)
    if (progreso > 0.01) {
      final paintPunta = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final paintPuntaBorde = Paint()
        ..color = const Color(0xFF2979FF)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(puntoActual, 7, paintPuntaBorde);
      canvas.drawCircle(puntoActual, 4, paintPunta);
    }

    // Flecha de dirección al inicio (modo novato: indica por dónde empezar)
    if (progreso < 0.15) {
      _dibujarFlecha(canvas, puntos.first, puntos[1]);
    }
  }

  void _dibujarFlecha(Canvas canvas, Offset desde, Offset hacia) {
    final angulo = math.atan2(
        hacia.dy - desde.dy, hacia.dx - desde.dx);
    const double largo = 14;
    const double apertura = 0.5;

    final paint = Paint()
      ..color = const Color(0xCC2979FF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      desde,
      Offset(desde.dx + math.cos(angulo + apertura) * largo,
          desde.dy + math.sin(angulo + apertura) * largo),
      paint,
    );
    canvas.drawLine(
      desde,
      Offset(desde.dx + math.cos(angulo - apertura) * largo,
          desde.dy + math.sin(angulo - apertura) * largo),
      paint,
    );
  }

  double _dist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(covariant TrazoGuiaPainter old) =>
      old.progreso != progreso || old.puntos != puntos;
}
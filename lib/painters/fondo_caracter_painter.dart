// ─────────────────────────────────────────────────────────────────────────────
// fondo_caracter_painter.dart — Silueta gris del carácter (modo novato)
//
// Dibuja todos los trazos del carácter en gris muy claro, como plantilla
// para calcar. Recibe los Path ya interpretados (CacheTrazos), así que solo
// se repinta cuando cambia el carácter.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'geometria.dart';

class FondoCaracterPainter extends CustomPainter {
  const FondoCaracterPainter(this.contornos, {this.color = const Color(0x1F9E9E9E)});

  final List<Path> contornos;

  /// Gris muy claro de día; blanco muy tenue de noche.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    GeometriaLienzo.aplicar(canvas, size);
    for (final c in contornos) {
      canvas.drawPath(c, pintura);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FondoCaracterPainter old) => !identical(old.contornos, contornos) || old.color != color;
}

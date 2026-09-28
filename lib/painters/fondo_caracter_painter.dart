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
  const FondoCaracterPainter(this.contornos);

  final List<Path> contornos;

  static final Paint _pintura = Paint()
    ..color = const Color(0x1F9E9E9E)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    GeometriaLienzo.aplicar(canvas, size);
    for (final c in contornos) {
      canvas.drawPath(c, _pintura);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FondoCaracterPainter old) => !identical(old.contornos, contornos);
}

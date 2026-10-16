// ─────────────────────────────────────────────────────────────────────────────
// pista_roja_painter.dart — Muestra en rojo el trazo que tocaba
//
// Aparece un instante cuando el trazo que dibujaste no coincide con el que
// sigue, para que veas dónde y cómo iba.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'geometria.dart';

class PistaRojaPainter extends CustomPainter {
  const PistaRojaPainter(this.contorno);

  /// Contorno del trazo esperado (coordenadas de 1024×1024).
  final Path contorno;

  static final Paint _pintura = Paint()
    ..color = const Color(0x66F44336)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    GeometriaLienzo.aplicar(canvas, size);
    canvas.drawPath(contorno, _pintura);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PistaRojaPainter old) => !identical(old.contorno, contorno);
}

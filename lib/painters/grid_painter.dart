import 'dart:math' as math;
import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 8.0;
    const dashSpace = 6.0;

    _dash(canvas, Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint, dashWidth, dashSpace);
    _dash(canvas, Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint, dashWidth, dashSpace);
    _dash(canvas, Offset.zero, Offset(size.width, size.height), paint, dashWidth, dashSpace);
    _dash(canvas, Offset(size.width, 0), Offset(0, size.height), paint, dashWidth, dashSpace);
  }

  void _dash(Canvas canvas, Offset p1, Offset p2, Paint paint, double dw, double ds) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist, uy = dy / dist;
    double cx = p1.dx, cy = p1.dy, drawn = 0.0;
    while (drawn < dist) {
      canvas.drawLine(Offset(cx, cy), Offset(cx + ux * dw, cy + uy * dw), paint);
      cx += ux * (dw + ds); cy += uy * (dw + ds); drawn += dw + ds;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
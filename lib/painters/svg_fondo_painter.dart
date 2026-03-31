import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class SvgFondoPainter extends CustomPainter {
  final List<String> trazosSvg;
  const SvgFondoPainter(this.trazosSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1F9E9E9E)
      ..style = PaintingStyle.fill;
    final scaleX = (size.width * 0.9) / 1024;
    final scaleY = (size.height * 0.9) / 1024;
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.scale(scaleX, -scaleY);
    canvas.translate(0, -1024);
    for (final trazo in trazosSvg) {
      canvas.drawPath(parseSvgPathData(trazo), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
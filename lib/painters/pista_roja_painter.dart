import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class PistaRojaPainter extends CustomPainter {
  final String trazoSvg;
  const PistaRojaPainter(this.trazoSvg);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x66F44336)
      ..style = PaintingStyle.fill;
    final scaleX = (size.width * 0.9) / 1024;
    final scaleY = (size.height * 0.9) / 1024;
    canvas.translate(size.width * 0.05, size.height * 0.05);
    canvas.scale(scaleX, -scaleY);
    canvas.translate(0, -1024);
    canvas.drawPath(parseSvgPathData(trazoSvg), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
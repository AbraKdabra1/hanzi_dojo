import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class PincelPainter extends CustomPainter {
  final List<List<PointVector>> trazos;
  const PincelPainter(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    for (var trazo in trazos) {
      final outline = getStroke(
        trazo,
        options: StrokeOptions(
          size: 8,
          thinning: 0.8,
          smoothing: 0.8,
          streamline: 0.8,
        ),
      );
      if (outline.isEmpty) continue;
      final path = Path();
      path.moveTo(outline.first.dx, outline.first.dy);
      for (int i = 1; i < outline.length; i++) {
        path.lineTo(outline[i].dx, outline[i].dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
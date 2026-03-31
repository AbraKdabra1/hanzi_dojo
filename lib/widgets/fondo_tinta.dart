// lib/widgets/fondo_tinta.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class FondoTintaChina extends StatelessWidget {
  final Widget child;
  const FondoTintaChina({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8F4EE),
                Color(0xFFF2EDE5),
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: _TintaPainter(),
          child: const SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

class _TintaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _dibujarManchasTinta(canvas, size);
    _dibujarRamaCiruelo(canvas, size);
  }

  void _dibujarManchasTinta(Canvas canvas, Size size) {
    final List<List<double>> manchas = [
      [0.08, 0.12, 90.0, 0.06],
      [0.85, 0.08, 70.0, 0.04],
      [0.92, 0.55, 110.0, 0.05],
      [0.05, 0.75, 80.0, 0.04],
      [0.50, 0.92, 100.0, 0.03],
    ];

    for (final m in manchas) {
      final cx      = m[0];
      final cy      = m[1];
      final radio   = m[2];
      final opacidad = m[3];

      final center = Offset(size.width * cx, size.height * cy);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromARGB((opacidad * 255).round(), 60, 40, 20),
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radio))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

      canvas.drawCircle(center, radio, paint);
    }
  }

  void _dibujarRamaCiruelo(Canvas canvas, Size size) {
    final paintRama = Paint()
      ..color = const Color(0x18402010)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Tronco principal
    path.moveTo(size.width * 0.0,  size.height * 0.18);
    path.cubicTo(
      size.width * 0.08, size.height * 0.10,
      size.width * 0.18, size.height * 0.08,
      size.width * 0.32, size.height * 0.04,
    );

    // Rama superior
    path.moveTo(size.width * 0.20, size.height * 0.07);
    path.cubicTo(
      size.width * 0.22, size.height * 0.03,
      size.width * 0.26, size.height * 0.01,
      size.width * 0.30, size.height * 0.00,
    );

    // Rama lateral
    path.moveTo(size.width * 0.13, size.height * 0.09);
    path.cubicTo(
      size.width * 0.11, size.height * 0.14,
      size.width * 0.09, size.height * 0.17,
      size.width * 0.07, size.height * 0.22,
    );

    canvas.drawPath(path, paintRama);

    _dibujarFlor(canvas, size, 0.30, 0.03, 5.0);
    _dibujarFlor(canvas, size, 0.22, 0.01, 4.0);
    _dibujarFlor(canvas, size, 0.08, 0.22, 4.5);
    _dibujarFlor(canvas, size, 0.33, 0.055, 3.5);
  }

  void _dibujarFlor(Canvas canvas, Size size, double cx, double cy, double r) {
    final paintPetalo = Paint()
      ..color = const Color(0x22C87080)
      ..style = PaintingStyle.fill;

    final paintCentro = Paint()
      ..color = const Color(0x33E8A0A8)
      ..style = PaintingStyle.fill;

    final centro = Offset(size.width * cx, size.height * cy);

    for (int i = 0; i < 5; i++) {
      final angulo = (i * 2 * math.pi / 5) - math.pi / 2;
      final petaloCentro = Offset(
        centro.dx + math.cos(angulo) * r * 0.9,
        centro.dy + math.sin(angulo) * r * 0.9,
      );
      canvas.drawCircle(petaloCentro, r * 0.75, paintPetalo);
    }

    canvas.drawCircle(centro, r * 0.4, paintCentro);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
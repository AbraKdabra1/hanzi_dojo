// ─────────────────────────────────────────────────────────────────────────────
// fondo_tinta.dart — Fondo de papel de arroz con manchas de tinta y una rama
// de ciruelo, detrás de las pantallas principales.
//
// En la pantalla de inicio se agrega la ilustración del Templo del Cielo
// (天坛, 祈年殿), anclada abajo. Es una imagen ya difuminada
// (herramientas_arte/templo_del_cielo.py): no se difumina en vivo.
//
// Rendimiento: el dibujo está dentro de un RepaintBoundary, así que se
// rasteriza una vez y se reutiliza; aunque el resto de la pantalla se anime,
// el fondo no se vuelve a pintar.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ilustración del Templo del Cielo para el fondo de la pantalla de inicio.
const rutaFondoTemplo = 'assets/imagenes/fondo_templo.jpg';

/// Envuelve una pantalla con el fondo de papel y tinta.
class FondoTintaChina extends StatelessWidget {
  final Widget child;

  /// true: muestra la ilustración del Templo del Cielo (pantalla de inicio).
  final bool templo;

  const FondoTintaChina({super.key, required this.child, this.templo = false});

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
        if (templo)
          const Positioned.fill(
            child: RepaintBoundary(
              child: Image(
                image: AssetImage(rutaFondoTemplo),
                fit: BoxFit.cover,
                // Anclada abajo: en pantallas más cortas se recorta el cielo,
                // nunca el templo.
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
          ),
        const RepaintBoundary(
          child: CustomPaint(
            painter: _TintaPainter(),
            isComplex: true, // pista para que Flutter guarde la imagen en caché
            child: SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class _TintaPainter extends CustomPainter {
  const _TintaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _dibujarManchasTinta(canvas, size);
    _dibujarRamaCiruelo(canvas, size);
  }

  /// Cinco manchas difusas de tinta café en las orillas.
  /// Cada fila: [x relativa, y relativa, radio, opacidad].
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

  /// Rama de ciruelo (梅花) en la esquina superior izquierda.
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

  /// Flor de cinco pétalos centrada en (cx, cy) relativos, de radio r.
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
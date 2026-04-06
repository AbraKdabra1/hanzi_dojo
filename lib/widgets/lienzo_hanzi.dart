import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class LienzoHanzi extends StatefulWidget {
  final String caracterEsperado;
  const LienzoHanzi({super.key, required this.caracterEsperado});

  @override
  State<LienzoHanzi> createState() => _LienzoHanziState();
}

class _LienzoHanziState extends State<LienzoHanzi> {
  final List<PointVector> _trazoActual = [];
  final List<List<PointVector>> _trazosAprobados = [];
  bool _alertaRoja = false;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_alertaRoja) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() => _trazoActual.add(PointVector(local.dx, local.dy)));
  }

  void _onPanEnd(DragEndDetails details) async {
    if (_trazoActual.isEmpty || _alertaRoja) return;
    if (_trazoActual.length >= 10) {
      setState(() {
        _trazosAprobados.add(List.from(_trazoActual));
        _trazoActual.clear();
      });
    } else {
      setState(() => _alertaRoja = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() { _trazoActual.clear(); _alertaRoja = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: CustomPaint(
          size: const Size(300, 300),
          painter: _HanziPainter(
            trazosAprobados: _trazosAprobados,
            trazoActual: _trazoActual,
            alertaRoja: _alertaRoja,
          ),
        ),
      ),
    );
  }
}

class _HanziPainter extends CustomPainter {
  final List<List<PointVector>> trazosAprobados;
  final List<PointVector> trazoActual;
  final bool alertaRoja;

  const _HanziPainter({
    required this.trazosAprobados,
    required this.trazoActual,
    required this.alertaRoja,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final negro = Paint()..color = Colors.black87..style = PaintingStyle.fill;
    final rojo  = Paint()..color = Colors.redAccent.shade700..style = PaintingStyle.fill;

    for (final trazo in trazosAprobados) { _dibujar(canvas, trazo, negro); }
    if (trazoActual.isNotEmpty) _dibujar(canvas, trazoActual, alertaRoja ? rojo : negro);
  }

  void _dibujar(Canvas canvas, List<PointVector> puntos, Paint pincel) {
    if (puntos.isEmpty) return;
    final contorno = getStroke(puntos,
        options: StrokeOptions(size: 14, thinning: 0.6, smoothing: 0.5, streamline: 0.5));
    if (contorno.isEmpty) return;

    final path = Path();
    path.moveTo(contorno.first.dx, contorno.first.dy);
    for (int i = 1; i < contorno.length - 1; i++) {
      final p0 = contorno[i], p1 = contorno[i + 1];
      path.quadraticBezierTo(
          p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }
    canvas.drawPath(path, pincel);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
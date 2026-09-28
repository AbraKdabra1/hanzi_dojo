// ─────────────────────────────────────────────────────────────────────────────
// pincel_painter.dart — La tinta que dibujas con el dedo
//
// ControladorTrazos guarda lo que vas dibujando. Cada vez que agregas un
// punto avisa (notifyListeners) y SOLO este painter se vuelve a pintar; el
// resto de la pantalla no se reconstruye. Esa es la clave para que el trazo
// siga al dedo a la tasa de refresco de la pantalla (60, 90, 120 Hz…).
//
// Además, los trazos ya aceptados se convierten en Path una sola vez; en
// cada cuadro solo se recalcula el trazo que estás haciendo.
// El grosor variable (efecto pincel) lo calcula perfect_freehand.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class ControladorTrazos extends ChangeNotifier {
  final List<Path> _aceptados = [];
  final List<PointVector> _actual = [];
  Path? _pathActual;

  static final StrokeOptions _opciones = StrokeOptions(
    size: 8,
    thinning: 0.8,
    smoothing: 0.8,
    streamline: 0.8,
  );

  /// Trazos ya aceptados (se dibujan tal cual).
  List<Path> get aceptados => _aceptados;

  /// Contorno del trazo en curso (null si no estás dibujando).
  Path? get pathActual => _pathActual;

  /// Puntos del trazo en curso, en píxeles del lienzo.
  List<Offset> get puntosActuales => [for (final p in _actual) Offset(p.dx, p.dy)];

  bool get dibujando => _actual.isNotEmpty;

  /// Cuenta los trazos empezados. Sirve para saber si el trazo "actual"
  /// sigue siendo el mismo (ver LienzoEscritura: borrar un trazo equivocado
  /// sin tocar el siguiente si el usuario ya empezó otro).
  int get numeroTrazo => _numeroTrazo;
  int _numeroTrazo = 0;

  void empezar(Offset p) {
    _numeroTrazo++;
    _actual
      ..clear()
      ..add(PointVector(p.dx, p.dy));
    _pathActual = _contorno(_actual);
    notifyListeners();
  }

  void agregar(Offset p) {
    if (_actual.isEmpty) return;
    _actual.add(PointVector(p.dx, p.dy));
    _pathActual = _contorno(_actual);
    notifyListeners();
  }

  /// El trazo en curso fue correcto: se queda en el lienzo.
  void aceptarActual() {
    if (_pathActual != null) _aceptados.add(_pathActual!);
    _actual.clear();
    _pathActual = null;
    notifyListeners();
  }

  /// El trazo en curso fue incorrecto (o fue solo un toque): se borra.
  void descartarActual() {
    _actual.clear();
    _pathActual = null;
    notifyListeners();
  }

  /// Borra todo (botón "reiniciar" o carácter nuevo).
  void limpiar() {
    _aceptados.clear();
    descartarActual();
  }

  static Path? _contorno(List<PointVector> puntos) {
    final contorno = getStroke(puntos, options: _opciones);
    if (contorno.isEmpty) return null;
    final path = Path()..moveTo(contorno.first.dx, contorno.first.dy);
    for (int i = 1; i < contorno.length; i++) {
      path.lineTo(contorno[i].dx, contorno[i].dy);
    }
    return path..close();
  }
}

class PincelPainter extends CustomPainter {
  PincelPainter(this.controlador) : super(repaint: controlador);

  final ControladorTrazos controlador;

  static final Paint _tinta = Paint()
    ..color = const Color(0xDD000000)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in controlador.aceptados) {
      canvas.drawPath(p, _tinta);
    }
    final actual = controlador.pathActual;
    if (actual != null) canvas.drawPath(actual, _tinta);
  }

  @override
  bool shouldRepaint(PincelPainter old) => !identical(old.controlador, controlador);
}

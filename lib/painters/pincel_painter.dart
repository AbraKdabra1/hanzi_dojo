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
//
// Ajuste caligráfico: un trazo correcto puede "acomodarse" en el trazo exacto
// del carácter (ver ajuste_trazo.dart). Mientras dura esa animación, el trazo
// vive en [_ajustes]; al terminar, queda en [aceptados] ya con la forma final.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../helpers/ajuste_trazo.dart';

/// Un trazo que se está transformando de tu tinta a la forma caligráfica.
class _Ajuste {
  _Ajuste(this.desde, this.hasta, this.pathFinal);

  final List<Offset> desde; // tu trazo (contorno alineado)
  final List<Offset> hasta; // el trazo caligráfico (contorno alineado)
  final Path pathFinal; // forma exacta con la que se queda
  double t = 0; // 0 = tu trazo, 1 = caligráfico (el resorte pasa un poco de 1)
}

class ControladorTrazos extends ChangeNotifier {
  final List<Path> _aceptados = [];
  final List<PointVector> _actual = [];
  Path? _pathActual;
  List<Offset> _contornoActual = const [];
  final Map<int, _Ajuste> _ajustes = {};
  int _siguienteAjuste = 0;

  static final StrokeOptions _opciones = StrokeOptions(
    size: 8,
    thinning: 0.8,
    smoothing: 0.8,
    streamline: 0.8,
  );

  /// Trazos ya aceptados (se dibujan tal cual).
  List<Path> get aceptados => _aceptados;

  /// Trazos que se están acomodando ahora mismo, en su forma de este cuadro.
  Iterable<Path> get ajustando =>
      _ajustes.values.map((a) => AjusteTrazo.aPath(AjusteTrazo.interpolar(a.desde, a.hasta, a.t)));

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
    _actualizarContorno();
    notifyListeners();
  }

  void agregar(Offset p) {
    if (_actual.isEmpty) return;
    _actual.add(PointVector(p.dx, p.dy));
    _actualizarContorno();
    notifyListeners();
  }

  /// El trazo en curso fue correcto: se queda en el lienzo tal como lo hiciste.
  void aceptarActual() {
    if (_pathActual != null) _aceptados.add(_pathActual!);
    _limpiarActual();
    notifyListeners();
  }

  /// El trazo en curso fue correcto y se va a acomodar en la forma
  /// caligráfica [pathFinal] (ya en píxeles del lienzo). [inicio] y [fin]
  /// son los extremos de la mediana esperada. Devuelve el número de ajuste
  /// para moverlo con [moverAjuste] y cerrarlo con [terminarAjuste].
  int ajustarActual(Path pathFinal, Offset inicio, Offset fin) {
    final puntos = puntosActuales;
    final destino = AjusteTrazo.muestrearPath(pathFinal, 2 * AjusteTrazo.puntosPorLado);
    final id = _siguienteAjuste++;
    if (puntos.length < 2 || _contornoActual.length < 3 || destino.length < 3) {
      // Sin datos suficientes para transformar: queda la forma final directo.
      _aceptados.add(pathFinal);
    } else {
      _ajustes[id] = _Ajuste(
        AjusteTrazo.alinear(_contornoActual, puntos.first, puntos.last),
        AjusteTrazo.alinear(destino, inicio, fin),
        pathFinal,
      );
    }
    _limpiarActual();
    notifyListeners();
    return id;
  }

  /// Avance de la animación de un ajuste (lo llama el resorte en cada cuadro).
  void moverAjuste(int id, double t) {
    final a = _ajustes[id];
    if (a == null) return;
    a.t = t;
    notifyListeners();
  }

  /// El ajuste terminó: el trazo se queda con su forma caligráfica exacta.
  void terminarAjuste(int id) {
    final a = _ajustes.remove(id);
    if (a == null) return;
    _aceptados.add(a.pathFinal);
    notifyListeners();
  }

  /// El trazo en curso fue incorrecto (o fue solo un toque): se borra.
  void descartarActual() {
    _limpiarActual();
    notifyListeners();
  }

  /// Borra todo (botón "reiniciar" o carácter nuevo).
  void limpiar() {
    _aceptados.clear();
    _ajustes.clear();
    descartarActual();
  }

  void _limpiarActual() {
    _actual.clear();
    _pathActual = null;
    _contornoActual = const [];
  }

  void _actualizarContorno() {
    final contorno = getStroke(_actual, options: _opciones);
    _contornoActual = contorno;
    _pathActual = contorno.isEmpty ? null : AjusteTrazo.aPath(contorno);
  }
}

class PincelPainter extends CustomPainter {
  PincelPainter(this.controlador, {Color color = const Color(0xDD000000)})
      : _tinta = Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
        super(repaint: controlador);

  final ControladorTrazos controlador;

  /// Tinta negra de día; color papel de noche.
  final Paint _tinta;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in controlador.aceptados) {
      canvas.drawPath(p, _tinta);
    }
    for (final p in controlador.ajustando) {
      canvas.drawPath(p, _tinta);
    }
    final actual = controlador.pathActual;
    if (actual != null) canvas.drawPath(actual, _tinta);
  }

  @override
  bool shouldRepaint(PincelPainter old) => !identical(old.controlador, controlador) || old._tinta.color != _tinta.color;
}

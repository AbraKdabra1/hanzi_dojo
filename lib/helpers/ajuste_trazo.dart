// ─────────────────────────────────────────────────────────────────────────────
// ajuste_trazo.dart — Geometría para que tu trazo "se acomode" en caligrafía
//
// Cuando un trazo es correcto, la tinta que dibujaste se transforma (con un
// rebote de resorte) en el trazo exacto del carácter: el contorno de pincel
// de la fuente kaishu de make-me-a-hanzi.
//
// Para transformar una figura en otra, las dos se describen con la MISMA
// cantidad de puntos y cada punto de una tiene su pareja en la otra:
//
//   1. Se toma el contorno (polígono cerrado) de cada figura.
//   2. Se orientan igual (mismo sentido de giro).
//   3. Se parte cada contorno en sus dos "lados", cortando en el punto más
//      cercano al INICIO del trazo y en el más cercano al FINAL.
//   4. Cada lado se remuestrea a [puntosPorLado] puntos equidistantes.
//
// Así el lado izquierdo de tu trazo se transforma en el lado izquierdo del
// trazo caligráfico, la punta en la punta, etc. Luego basta interpolar punto
// a punto: t = 0 es tu trazo, t = 1 el caligráfico (y t un poco mayor que 1
// es el "pasarse" del resorte antes de asentarse).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'dtw_helper.dart';

class AjusteTrazo {
  AjusteTrazo._();

  /// Puntos por lado del contorno (el polígono final tiene el doble).
  static const int puntosPorLado = 48;

  /// Puntos con los que se densifica un contorno antes de buscar los cortes.
  static const int _densidad = 240;

  /// Muestrea el contorno más largo de [path] en [n] puntos equidistantes.
  static List<Offset> muestrearPath(Path path, int n) {
    PathMetric? mayor;
    for (final m in path.computeMetrics()) {
      if (mayor == null || m.length > mayor.length) mayor = m;
    }
    if (mayor == null || mayor.length == 0) return const [];
    return [
      for (int i = 0; i < n; i++) mayor.getTangentForOffset(mayor.length * i / n)!.position,
    ];
  }

  /// Área con signo de un polígono (el signo indica el sentido de giro).
  static double areaFirmada(List<Offset> p) {
    double a = 0;
    for (int i = 0; i < p.length; i++) {
      final q = p[i];
      final r = p[(i + 1) % p.length];
      a += q.dx * r.dy - r.dx * q.dy;
    }
    return a / 2;
  }

  /// Remuestrea un polígono CERRADO a [n] puntos equidistantes.
  static List<Offset> remuestrearCerrado(List<Offset> p, int n) {
    if (p.length < 2) return p;
    final abierto = DTWHelper.normalizar([...p, p.first], n + 1);
    return abierto.sublist(0, n);
  }

  /// Prepara un contorno para transformarlo: misma orientación, cortado en
  /// sus dos lados por los puntos más cercanos a [inicio] y [fin] del trazo,
  /// y cada lado con [porLado] puntos. Devuelve 2 × [porLado] puntos.
  static List<Offset> alinear(
    List<Offset> contorno,
    Offset inicio,
    Offset fin, {
    int porLado = puntosPorLado,
  }) {
    if (contorno.length < 3) return List.filled(2 * porLado, contorno.isEmpty ? inicio : contorno.first);
    var p = remuestrearCerrado(contorno, _densidad);
    if (areaFirmada(p) < 0) p = p.reversed.toList();

    final iInicio = _masCercano(p, inicio);
    var iFin = _masCercano(p, fin);
    if (iFin == iInicio) iFin = (iInicio + p.length ~/ 2) % p.length; // trazo casi puntual

    final ladoA = _recorrido(p, iInicio, iFin);
    final ladoB = _recorrido(p, iFin, iInicio);
    return [
      ...DTWHelper.normalizar(ladoA, porLado),
      ...DTWHelper.normalizar(ladoB, porLado),
    ];
  }

  /// Interpola punto a punto entre [a] (t = 0) y [b] (t = 1). Acepta t fuera
  /// de [0, 1] (el rebote del resorte).
  static List<Offset> interpolar(List<Offset> a, List<Offset> b, double t) => [
        for (int i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * t,
      ];

  /// Polígono cerrado como Path.
  static Path aPath(List<Offset> puntos) {
    final path = Path();
    if (puntos.isEmpty) return path;
    path.moveTo(puntos.first.dx, puntos.first.dy);
    for (int i = 1; i < puntos.length; i++) {
      path.lineTo(puntos[i].dx, puntos[i].dy);
    }
    return path..close();
  }

  static int _masCercano(List<Offset> p, Offset objetivo) {
    var mejor = 0;
    var mejorDistancia = double.infinity;
    for (int i = 0; i < p.length; i++) {
      final d = (p[i] - objetivo).distanceSquared;
      if (d < mejorDistancia) {
        mejorDistancia = d;
        mejor = i;
      }
    }
    return mejor;
  }

  /// Puntos de [desde] a [hasta] (inclusive) avanzando, dando la vuelta si hace falta.
  static List<Offset> _recorrido(List<Offset> p, int desde, int hasta) {
    final salida = <Offset>[p[desde]];
    var i = desde;
    while (i != hasta) {
      i = (i + 1) % p.length;
      salida.add(p[i]);
    }
    return salida;
  }
}

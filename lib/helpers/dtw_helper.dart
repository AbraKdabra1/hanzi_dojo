// ─────────────────────────────────────────────────────────────────────────────
// dtw_helper.dart — ¿Qué tan parecido es tu trazo al trazo correcto?
//
// DTW (Dynamic Time Warping, "alineamiento temporal dinámico") compara dos
// secuencias de puntos aunque se hayan dibujado a distinta velocidad.
//
// Pasos:
//   1. Ambos trazos se remuestrean a 16 puntos equidistantes a lo largo del
//      recorrido (así no importa si dibujaste rápido o lento).
//   2. Se busca la mejor forma de emparejar los puntos de uno con los del
//      otro, respetando el orden (inicio con inicio, final con final).
//   3. El costo es la distancia promedio entre puntos emparejados.
//      Menor = más parecido. Un trazo dibujado al revés sale caro, porque
//      el inicio queda lejos del inicio.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' show Offset;

class DTWHelper {
  DTWHelper._();

  /// Puntos a los que se remuestrea cada trazo.
  static const int puntosComparacion = 16;

  static double _distancia(Offset a, Offset b) => (a - b).distance;

  /// Reduce una lista de puntos a [n] puntos igualmente espaciados sobre el
  /// recorrido.
  static List<Offset> normalizar(List<Offset> puntos, int n) {
    if (puntos.length <= 1) return puntos;

    double longitudTotal = 0;
    for (int i = 1; i < puntos.length; i++) {
      longitudTotal += _distancia(puntos[i - 1], puntos[i]);
    }
    if (longitudTotal == 0) return List.filled(n, puntos.first);

    final double paso = longitudTotal / (n - 1);
    final List<Offset> resultado = [puntos.first];
    double acumulado = 0;
    int j = 0;

    for (int i = 1; i < n - 1; i++) {
      final double objetivo = paso * i;
      while (j < puntos.length - 2 &&
          acumulado + _distancia(puntos[j], puntos[j + 1]) < objetivo) {
        acumulado += _distancia(puntos[j], puntos[j + 1]);
        j++;
      }
      final double resto = objetivo - acumulado;
      final double segmento = _distancia(puntos[j], puntos[j + 1]);
      final double t = segmento == 0 ? 0 : (resto / segmento).clamp(0.0, 1.0);
      resultado.add(Offset.lerp(puntos[j], puntos[j + 1], t)!);
    }

    resultado.add(puntos.last);
    return resultado;
  }

  /// Costo DTW normalizado entre dos trazos (en las mismas unidades que los
  /// puntos, p. ej. píxeles del lienzo). Devuelve infinito si alguno tiene
  /// menos de 2 puntos.
  static double calcular(List<Offset> trazoUsuario, List<Offset> trazoEsperado) {
    if (trazoUsuario.length < 2 || trazoEsperado.length < 2) {
      return double.infinity;
    }
    const int n = puntosComparacion;
    final a = normalizar(trazoUsuario, n);
    final b = normalizar(trazoEsperado, n);

    // matriz[i][j] = costo mínimo para emparejar a[0..i] con b[0..j].
    final matriz = List.generate(n, (_) => List<double>.filled(n, double.infinity));
    matriz[0][0] = _distancia(a[0], b[0]);
    for (int i = 1; i < n; i++) {
      matriz[i][0] = matriz[i - 1][0] + _distancia(a[i], b[0]);
    }
    for (int j = 1; j < n; j++) {
      matriz[0][j] = matriz[0][j - 1] + _distancia(a[0], b[j]);
    }
    for (int i = 1; i < n; i++) {
      for (int j = 1; j < n; j++) {
        final double previo = math.min(
          matriz[i - 1][j - 1],
          math.min(matriz[i - 1][j], matriz[i][j - 1]),
        );
        matriz[i][j] = _distancia(a[i], b[j]) + previo;
      }
    }
    return matriz[n - 1][n - 1] / n;
  }
}

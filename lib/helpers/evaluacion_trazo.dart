// ─────────────────────────────────────────────────────────────────────────────
// evaluacion_trazo.dart — ¿Tu trazo es correcto, está al revés o es otro?
//
// La comparación de formas la hace DTW (dtw_helper.dart). Aquí se agrega la
// revisión del SENTIDO, para poder decirte "al revés" en vez de solo "error":
//
//   · Extremos: si tu inicio quedó cerca del final esperado y tu final cerca
//     del inicio esperado, el trazo va al revés. Esto atrapa los trazos
//     cortos (como el punto 丶), donde DTW por sí solo a veces lo dejaba pasar.
//   · Forma invertida: si tu trazo NO se parece al esperado, pero dado la
//     vuelta sí, también fue al revés.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'dtw_helper.dart';

enum ResultadoTrazo { correcto, alReves, incorrecto }

class EvaluacionTrazo {
  EvaluacionTrazo._();

  /// Qué tanto más cerca deben quedar los extremos cruzados que los directos
  /// para considerar el trazo al revés (0.6 = 40 % más cerca).
  static const double margenExtremos = 0.6;

  /// Compara tu trazo con la mediana esperada (ambos en píxeles del lienzo).
  /// [umbral] es el costo DTW máximo aceptado (en píxeles).
  static ResultadoTrazo evaluar(List<Offset> usuario, List<Offset> mediana, double umbral) {
    if (usuario.length < 2 || mediana.length < 2) return ResultadoTrazo.incorrecto;
    final alRevesPorExtremos = extremosInvertidos(usuario, mediana);
    final costo = DTWHelper.calcular(usuario, mediana);
    if (costo <= umbral && !alRevesPorExtremos) return ResultadoTrazo.correcto;

    final costoInvertido = DTWHelper.calcular(usuario.reversed.toList(), mediana);
    if (costoInvertido <= umbral && (alRevesPorExtremos || costoInvertido < costo)) {
      return ResultadoTrazo.alReves;
    }
    return ResultadoTrazo.incorrecto;
  }

  /// true si el inicio y el final de tu trazo quedaron "cruzados" respecto a
  /// los del trazo esperado.
  static bool extremosInvertidos(List<Offset> usuario, List<Offset> mediana) {
    final u0 = usuario.first, u1 = usuario.last;
    final m0 = mediana.first, m1 = mediana.last;
    final directo = (u0 - m0).distance + (u1 - m1).distance;
    final cruzado = (u0 - m1).distance + (u1 - m0).distance;
    return cruzado < directo * margenExtremos;
  }
}

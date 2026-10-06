// ─────────────────────────────────────────────────────────────────────────────
// evaluacion_trazo.dart — ¿Tu trazo es correcto, está al revés o es otro?
//
// Un trazo es correcto solo si pasa TODAS estas pruebas contra la mediana
// (línea central) del trazo que sigue:
//
//   1. Lugar y forma: la distancia promedio DTW (dtw_helper.dart) cabe en
//      [umbralDistancia] × ancho del lienzo.
//   2. Dirección: punto por punto, tu trazo avanza hacia donde avanza el
//      correcto (similitud de dirección ≥ [similitudMinima]). Un horizontal
//      contra un vertical da ~0: ya no pasa aunque se crucen en el centro.
//   3. Ángulo de los trazos rectos (横, 竖, 撇, 点…): de tu inicio a tu final
//      no puede desviarse más de [anguloMaximo] grados del correcto.
//   4. Largo: ni mucho más corto ni mucho más largo que el correcto.
//   5. Orden: si tu trazo se parece claramente más a uno de los trazos que
//      faltan (la mitad de distancia o menos), dibujaste otro trazo antes de
//      tiempo y no cuenta.
//
// Antes solo existía la prueba 1 (y con más tolerancia), así que un vertical
// que cruzaba por el centro de un horizontal pasaba como bueno.
//
// El SENTIDO se revisa aparte, para poder decirte "al revés" en vez de solo
// "error":
//   · Extremos: si tu inicio quedó cerca del final esperado y tu final cerca
//     del inicio esperado, el trazo va al revés. Esto atrapa los trazos
//     cortos (como el punto 丶), donde la forma sola a veces lo dejaba pasar.
//   · Forma invertida: si tu trazo NO pasa, pero dado la vuelta sí, también
//     fue al revés.
//
// Los números salen de una simulación con caracteres HSK (trazos bien hechos
// con temblor, desplazamiento, escala y giro, contra los otros trazos del
// mismo carácter). Antes / ahora:
//   · horizontal ↔ vertical aceptado:          42 %  →  0 %
//   · trazo que toca después, aceptado:          40 %  →  3.5 %
//   · al revés reconocido como «al revés»:       91 %  →  99 %
//   · trazos bien hechos aceptados:             100 %  →  98.7 %
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

import 'dtw_helper.dart';

enum ResultadoTrazo { correcto, alReves, incorrecto }

class EvaluacionTrazo {
  EvaluacionTrazo._();

  /// 1. Distancia promedio máxima, como fracción del ancho del lienzo.
  static const double umbralDistancia = 0.24;

  /// 2. Similitud de dirección mínima (coseno promedio; 1 = misma dirección).
  static const double similitudMinima = 0.3;

  /// 3. Desviación máxima (grados) de un trazo recto, y desde qué rectitud
  ///    (distancia entre extremos ÷ largo) se considera recto.
  static const double anguloMaximo = 40;
  static const double rectitudMinima = 0.8;

  /// 4. Razón de largos aceptada (tuyo ÷ correcto, con un margen de
  ///    [margenLargo] × ancho para que los trazos cortos no se castiguen).
  static const double largoMinimo = 0.5;
  static const double largoMaximo = 2.2;
  static const double margenLargo = 0.04;

  /// 5. Si un trazo pendiente cuesta menos que esta fracción del esperado,
  ///    dibujaste ese otro trazo.
  static const double ventajaOtroTrazo = 0.5;

  /// Qué tanto más cerca deben quedar los extremos cruzados que los directos
  /// para considerar el trazo al revés (0.6 = 40 % más cerca).
  static const double margenExtremos = 0.6;

  /// Compara tu trazo con la mediana esperada (ambos en píxeles de un lienzo
  /// de [ancho] píxeles). [pendientes]: medianas de los trazos que todavía
  /// faltan después de este, para notar si dibujaste otro antes de tiempo.
  static ResultadoTrazo evaluar(
    List<Offset> usuario,
    List<Offset> mediana, {
    required double ancho,
    List<List<Offset>> pendientes = const [],
  }) {
    if (usuario.length < 2 || mediana.length < 2) return ResultadoTrazo.incorrecto;
    const n = DTWHelper.puntosComparacion;
    final esperado = DTWHelper.normalizar(mediana, n);
    final otros = [
      for (final p in pendientes)
        if (p.length >= 2) DTWHelper.normalizar(p, n),
    ];
    final alRevesPorExtremos = extremosInvertidos(usuario, mediana);

    final directo = _revisar(usuario, mediana, esperado, otros, ancho);
    if (directo.pasa && !alRevesPorExtremos) return ResultadoTrazo.correcto;

    final invertido = _revisar(usuario.reversed.toList(), mediana, esperado, otros, ancho);
    if (invertido.pasa && (alRevesPorExtremos || invertido.costo < directo.costo)) {
      return ResultadoTrazo.alReves;
    }
    return ResultadoTrazo.incorrecto;
  }

  /// Las pruebas 1 a 5 (sin el sentido). Devuelve también el costo DTW, que
  /// sirve para decidir entre "al revés" y "otro trazo".
  static ({bool pasa, double costo}) _revisar(
    List<Offset> usuario,
    List<Offset> mediana,
    List<Offset> esperado,
    List<List<Offset>> otros,
    double ancho,
  ) {
    final tuyo = DTWHelper.normalizar(usuario, DTWHelper.puntosComparacion);
    final (:costo, :camino) = DTWHelper.alinear(tuyo, esperado);
    ({bool pasa, double costo}) no() => (pasa: false, costo: costo);

    // 1. Lugar y forma.
    if (costo > umbralDistancia * ancho) return no();
    // 4. Largo.
    final margen = margenLargo * ancho;
    final razon = (DTWHelper.longitud(usuario) + margen) / (DTWHelper.longitud(mediana) + margen);
    if (razon < largoMinimo || razon > largoMaximo) return no();
    // 2. Dirección punto por punto.
    if (DTWHelper.similitudDireccion(tuyo, esperado, camino) < similitudMinima) return no();
    // 3. Ángulo de los trazos rectos.
    if (rectitud(mediana) >= rectitudMinima && anguloEntre(usuario, mediana) > anguloMaximo) return no();
    // 5. ¿Se parece claramente más a un trazo que falta?
    for (final otro in otros) {
      if (DTWHelper.alinear(tuyo, otro).costo < costo * ventajaOtroTrazo) return no();
    }
    return (pasa: true, costo: costo);
  }

  /// Distancia entre extremos ÷ largo del recorrido (1 = línea recta).
  static double rectitud(List<Offset> p) {
    final largo = DTWHelper.longitud(p);
    return largo == 0 ? 1 : (p.last - p.first).distance / largo;
  }

  /// Ángulo (grados, 0-180) entre las direcciones inicio→final de dos trazos.
  static double anguloEntre(List<Offset> a, List<Offset> b) {
    final v = a.last - a.first, w = b.last - b.first;
    final nv = v.distance, nw = w.distance;
    if (nv == 0 || nw == 0) return 180;
    final coseno = ((v.dx * w.dx + v.dy * w.dy) / (nv * nw)).clamp(-1.0, 1.0);
    return math.acos(coseno) * 180 / math.pi;
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

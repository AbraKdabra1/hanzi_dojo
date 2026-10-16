// ─────────────────────────────────────────────────────────────────────────────
// reconocedor.dart — Buscar un carácter dibujándolo (fase 7)
//
// Sin internet y sin modelos de aprendizaje automático: se compara tu dibujo
// con las medianas (la línea central de cada trazo) de los caracteres HSK de
// make-me-a-hanzi, las mismas que se usan para revisar tus trazos.
//
//   1. Todo se lleva a un cuadro de 1 × 1: el dibujo y cada carácter se
//      centran y escalan por su contorno (así da igual si dibujas chico o en
//      una esquina).
//   2. Cada trazo se remuestrea a 12 puntos repartidos a lo largo.
//   3. Costo de un carácter = distancia promedio entre tus trazos y los suyos.
//      Se prueba en orden (trazo 1 con trazo 1…) y también emparejando cada
//      trazo con el más parecido (por si el orden no fue el correcto); vale
//      el menor. Cada trazo de más o de menos suma una penalización.
//   4. Los de menor costo son los candidatos.
//
// Todo es cálculo puro, para probarlo sin pantalla.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Un carácter listo para comparar.
class ModeloTrazos {
  const ModeloTrazos(this.caracter, this.trazos);

  final String caracter;

  /// Trazos normalizados (cuadro 1 × 1, y hacia abajo), 12 puntos cada uno.
  final List<List<Offset>> trazos;
}

class Reconocedor {
  Reconocedor._();

  static const puntosPorTrazo = 12;

  /// Penalización por cada trazo de más o de menos.
  static const penalizacionTrazo = 0.11;

  /// [puntos] repartidos a distancias iguales a lo largo del trazo.
  static List<Offset> remuestrear(List<Offset> puntos, [int n = puntosPorTrazo]) {
    if (puntos.isEmpty) return List.filled(n, Offset.zero);
    if (puntos.length == 1) return List.filled(n, puntos.first);
    final acumulado = <double>[0];
    for (var i = 1; i < puntos.length; i++) {
      acumulado.add(acumulado.last + (puntos[i] - puntos[i - 1]).distance);
    }
    final total = acumulado.last;
    if (total == 0) return List.filled(n, puntos.first);
    final salida = <Offset>[];
    var j = 1;
    for (var k = 0; k < n; k++) {
      final objetivo = total * k / (n - 1);
      while (j < puntos.length - 1 && acumulado[j] < objetivo) {
        j++;
      }
      final tramo = acumulado[j] - acumulado[j - 1];
      final t = tramo == 0 ? 0.0 : ((objetivo - acumulado[j - 1]) / tramo).clamp(0.0, 1.0);
      salida.add(Offset.lerp(puntos[j - 1], puntos[j], t)!);
    }
    return salida;
  }

  /// Centra y escala los trazos para que su contorno quepa en 1 × 1
  /// (conservando la proporción), y los remuestrea.
  static List<List<Offset>> normalizar(List<List<Offset>> trazos) {
    final todos = [for (final t in trazos) ...t];
    if (todos.isEmpty) return const [];
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in todos) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final escala = math.max(math.max(maxX - minX, maxY - minY), 1e-6);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    return [
      for (final t in trazos)
        remuestrear([for (final p in t) Offset((p.dx - cx) / escala + 0.5, (p.dy - cy) / escala + 0.5)]),
    ];
  }

  /// Modelo a partir de las medianas de make-me-a-hanzi (y hacia arriba).
  static ModeloTrazos modelo(String caracter, List<List<Offset>> medianas) =>
      ModeloTrazos(caracter, normalizar([for (final t in medianas) [for (final p in t) Offset(p.dx, -p.dy)]]));

  /// Modelo a partir de la columna `medianas` (JSON) de la base.
  static ModeloTrazos modeloDeJson(String caracter, String json) {
    final lista = jsonDecode(json) as List;
    return modelo(caracter, [
      for (final t in lista)
        [for (final p in t as List) Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())],
    ]);
  }

  /// Distancia promedio entre dos trazos ya remuestreados.
  static double distancia(List<Offset> a, List<Offset> b) {
    var s = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      s += (a[i] - b[i]).distance;
    }
    return n == 0 ? 1 : s / n;
  }

  /// Qué tan distinto es el dibujo (ya normalizado) del modelo: 0 = igual.
  static double costo(List<List<Offset>> dibujo, ModeloTrazos m) {
    final n = dibujo.length;
    final k = m.trazos.length;
    if (n == 0 || k == 0) return double.infinity;
    final comunes = math.min(n, k);

    // En orden.
    var ordenado = 0.0;
    for (var i = 0; i < comunes; i++) {
      ordenado += distancia(dibujo[i], m.trazos[i]);
    }
    ordenado /= comunes;

    // Libre: cada trazo con el más parecido que quede (por si el orden falló).
    final usados = List<bool>.filled(k, false);
    var libre = 0.0;
    for (var i = 0; i < comunes; i++) {
      var mejor = double.infinity;
      var cual = -1;
      for (var j = 0; j < k; j++) {
        if (usados[j]) continue;
        final d = distancia(dibujo[i], m.trazos[j]);
        if (d < mejor) {
          mejor = d;
          cual = j;
        }
      }
      usados[cual] = true;
      libre += mejor;
    }
    libre = libre / comunes + 0.04; // el orden correcto vale un poco más

    return math.min(ordenado, libre) + penalizacionTrazo * (n - k).abs();
  }

  /// Los [cuantos] caracteres más parecidos al dibujo (trazos en cualquier
  /// sistema de coordenadas con y hacia abajo, p. ej. píxeles del lienzo).
  static List<String> buscar(List<List<Offset>> trazos, List<ModeloTrazos> modelos, {int cuantos = 12}) {
    final validos = [for (final t in trazos) if (t.isNotEmpty) t];
    if (validos.isEmpty) return const [];
    final dibujo = normalizar(validos);
    final n = dibujo.length;
    final puntuados = <(String, double)>[];
    for (final m in modelos) {
      if ((m.trazos.length - n).abs() > 3) continue;
      puntuados.add((m.caracter, costo(dibujo, m)));
    }
    puntuados.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (c, _) in puntuados.take(cuantos)) c];
  }
}

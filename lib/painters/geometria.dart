// ─────────────────────────────────────────────────────────────────────────────
// geometria.dart — De coordenadas de make-me-a-hanzi a píxeles del lienzo
//
// make-me-a-hanzi dibuja cada carácter en un cuadro de 1024 × 1024 con el eje
// Y hacia ARRIBA: la parte de arriba del carácter está en y = 900 y la de
// abajo en y = −124. En la pantalla el eje Y va hacia ABAJO.
//
// El carácter ocupa el 90 % del lienzo, con un margen de 5 % en cada lado.
// Todos los painters y la evaluación de trazos usan esta misma conversión;
// si no coincidieran, lo que ves y lo que se evalúa no estarían alineados.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'dart:ui';

class GeometriaLienzo {
  GeometriaLienzo._();

  /// Tamaño del cuadro de make-me-a-hanzi.
  static const double lado = 1024;

  /// Coordenada Y del borde superior del cuadro.
  static const double techo = 900;

  /// Margen alrededor del carácter (fracción del lienzo).
  static const double margen = 0.05;

  /// Píxeles por unidad de make-me-a-hanzi.
  static double escala(Size s) => s.shortestSide * (1 - 2 * margen) / lado;

  /// Aplica la transformación al canvas: después de esto se puede dibujar
  /// directamente en coordenadas de make-me-a-hanzi.
  static void aplicar(Canvas canvas, Size s) {
    final e = escala(s);
    canvas.translate(s.width * margen, s.height * margen);
    canvas.scale(e, -e);
    canvas.translate(0, -techo);
  }

  /// Convierte un punto de make-me-a-hanzi a píxeles del lienzo.
  static Offset aLienzo(Offset p, Size s) {
    final e = escala(s);
    return Offset(s.width * margen + p.dx * e, s.height * margen + (techo - p.dy) * e);
  }

  /// Lo contrario de [aLienzo]: de píxeles del lienzo a make-me-a-hanzi
  /// (para guardar un trazo del usuario sin depender del tamaño de pantalla).
  static Offset deLienzo(Offset p, Size s) {
    final e = escala(s);
    return Offset((p.dx - s.width * margen) / e, techo - (p.dy - s.height * margen) / e);
  }

  /// La misma transformación que [aplicar], como matriz para Path.transform.
  static Float64List matriz(Size s) {
    final e = escala(s);
    return Float64List.fromList([
      e, 0, 0, 0, //
      0, -e, 0, 0, //
      0, 0, 1, 0, //
      s.width * margen, s.height * margen + techo * e, 0, 1,
    ]);
  }

  /// Convierte un contorno (Path de make-me-a-hanzi) a píxeles del lienzo.
  static Path pathALienzo(Path p, Size s) => p.transform(matriz(s));

  /// Convierte un trazo (lista de puntos) completo.
  static List<Offset> trazoALienzo(List<Offset> puntos, Size s) =>
      [for (final p in puntos) aLienzo(p, s)];
}

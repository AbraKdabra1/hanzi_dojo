// ─────────────────────────────────────────────────────────────────────────────
// cache_trazos.dart — Convierte los contornos SVG en Path una sola vez
//
// Interpretar un contorno SVG ("M 520 133 Q 523 296 …") cuesta tiempo. Antes
// se hacía en cada cuadro de animación, con todos los trazos del carácter, y
// eso era lo que trababa el dibujo. Ahora se interpreta una vez por carácter
// y se guarda aquí (se conservan los últimos 40 caracteres).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:collection';
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

class CacheTrazos {
  CacheTrazos._();

  static const int _maximo = 40;
  static final LinkedHashMap<String, List<Path>> _cache = LinkedHashMap();

  /// Contornos de un carácter como objetos Path (coordenadas de 1024×1024).
  static List<Path> contornos(String caracter, List<String> svg) {
    final existente = _cache.remove(caracter);
    if (existente != null) {
      _cache[caracter] = existente; // lo mueve al final (usado recientemente)
      return existente;
    }
    final paths = [for (final s in svg) parseSvgPathData(s)];
    _cache[caracter] = paths;
    if (_cache.length > _maximo) {
      _cache.remove(_cache.keys.first);
    }
    return paths;
  }
}

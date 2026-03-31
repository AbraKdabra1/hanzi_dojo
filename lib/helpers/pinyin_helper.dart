import 'package:flutter/material.dart';

class PinyinHelper {
  static const Map<String, List<String>> _map = {
    'a': ['ā', 'á', 'ǎ', 'à'],
    'e': ['ē', 'é', 'ě', 'è'],
    'i': ['ī', 'í', 'ǐ', 'ì'],
    'o': ['ō', 'ó', 'ǒ', 'ò'],
    'u': ['ū', 'ú', 'ǔ', 'ù'],
    'v': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
    'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
  };

  static String _aplicarTono(String silaba, int tono) {
    if (tono < 1 || tono > 4) return silaba;
    final t = tono - 1;
    for (final vocal in ['a', 'e', 'o']) {
      if (silaba.contains(vocal)) {
        return silaba.replaceFirst(vocal, _map[vocal]![t]);
      }
    }
    for (int i = silaba.length - 1; i >= 0; i--) {
      final letra = silaba[i];
      if (_map.containsKey(letra)) {
        return silaba.replaceRange(i, i + 1, _map[letra]![t]);
      }
    }
    return silaba;
  }

  static String formatear(String texto) {
    if (texto.isEmpty) return texto;
    return texto
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((palabra) {
          final match = RegExp(r'([a-züv]+)(\d)').firstMatch(palabra);
          if (match == null) return palabra.replaceAll('v', 'ü');
          final silaba = _aplicarTono(
              match.group(1)!.replaceAll('v', 'ü'),
              int.parse(match.group(2)!));
          return silaba + palabra.substring(match.end);
        })
        .join(' ');
  }

  static Color colorDeTono(String palabra) {
    final match = RegExp(r'(\d)').firstMatch(palabra);
    if (match == null) return const Color(0xFF9E9E9E);
    return switch (match.group(1)) {
      '1' => const Color(0xFFE53935),
      '2' => const Color(0xFFF57C00),
      '3' => const Color(0xFF2E7D32),
      '4' => const Color(0xFF1565C0),
      _   => const Color(0xFF9E9E9E),
    };
  }

  static List<(String, Color)> formatearConColores(String texto) {
    if (texto.isEmpty) return [];
    final palabras = texto.toLowerCase().split(RegExp(r'\s+'));
    final resultado = <(String, Color)>[];

    for (int i = 0; i < palabras.length; i++) {
      final palabra = palabras[i];
      final match = RegExp(r'([a-züv]+)(\d)').firstMatch(palabra);
      final color = colorDeTono(palabra);

      if (match == null) {
        resultado.add((palabra.replaceAll('v', 'ü'), const Color(0xFF9E9E9E)));
      } else {
        final silaba = _aplicarTono(
            match.group(1)!.replaceAll('v', 'ü'),
            int.parse(match.group(2)!));
        resultado.add((silaba + palabra.substring(match.end), color));
      }
      if (i < palabras.length - 1) {
        resultado.add((' ', const Color(0xFF9E9E9E)));
      }
    }
    return resultado;
  }
}
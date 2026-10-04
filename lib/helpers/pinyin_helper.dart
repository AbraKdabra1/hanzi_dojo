// ─────────────────────────────────────────────────────────────────────────────
// pinyin_helper.dart — Colores por tono
//
// La base de datos ya trae el pinyin con acentos ("hǎo") y con número
// ("hao3"), así que aquí solo se decide el color de cada tono:
//   1.º (ā) rojo · 2.º (á) naranja · 3.º (ǎ) verde · 4.º (à) azul · neutro gris
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class PinyinHelper {
  PinyinHelper._();

  static const Color tono1 = Color(0xFFE53935);
  static const Color tono2 = Color(0xFFF57C00);
  static const Color tono3 = Color(0xFF2E7D32);
  static const Color tono4 = Color(0xFF1565C0);
  static const Color neutro = Color(0xFF9E9E9E);

  /// Color de un tono (1-4; cualquier otro valor = neutro).
  /// [oscuro]: en modo oscuro se aclara un poco (verde y azul profundos no
  /// se leerían sobre negro).
  static Color colorDeTono(int tono, {bool oscuro = false}) {
    final base = switch (tono) {
      1 => tono1,
      2 => tono2,
      3 => tono3,
      4 => tono4,
      _ => neutro,
    };
    return oscuro ? Color.lerp(base, const Color(0xFFFFFFFF), 0.3)! : base;
  }

  /// Tono a partir del pinyin con número: "hao3" → 3, "ma5" → 5.
  static int tonoDeNumero(String pinyinNum) {
    final m = RegExp(r'([1-5])$').firstMatch(pinyinNum);
    return m == null ? 5 : int.parse(m.group(1)!);
  }

  /// Sílaba sin tono + tono → con su acento: ('ma', 3) → 'mǎ', ('lv', 4) → 'lǜ',
  /// ('gui', 4) → 'guì', ('zhou', 1) → 'zhōu'. Tono 5 (neutro) va sin acento.
  /// Regla del pinyin: el acento va en la a o la e si las hay; en "ou", en la
  /// o; si no, en la última vocal.
  static String conTono(String base, int tono) {
    final s = base.replaceAll('v', 'ü');
    if (tono < 1 || tono > 4) return s;
    const marcas = {
      'a': 'āáǎà', 'e': 'ēéěè', 'i': 'īíǐì', 'o': 'ōóǒò', 'u': 'ūúǔù', 'ü': 'ǖǘǚǜ',
    };
    int pos;
    if (s.contains('a')) {
      pos = s.indexOf('a');
    } else if (s.contains('e')) {
      pos = s.indexOf('e');
    } else if (s.contains('ou')) {
      pos = s.indexOf('o');
    } else {
      pos = -1;
      for (var i = s.length - 1; i >= 0; i--) {
        if (marcas.containsKey(s[i])) {
          pos = i;
          break;
        }
      }
    }
    if (pos < 0) return s;
    return s.substring(0, pos) + marcas[s[pos]]![tono - 1] + s.substring(pos + 1);
  }

  /// Tono a partir del pinyin con acentos: "hǎo" → 3, "ma" → 5.
  static int tonoDeAcentos(String silaba) {
    const tonos = {
      'āēīōūǖ': 1, 'áéíóúǘḿń': 2, 'ǎěǐǒǔǚň': 3, 'àèìòùǜǹ': 4,
    };
    for (final ch in silaba.split('')) {
      for (final entrada in tonos.entries) {
        if (entrada.key.contains(ch)) return entrada.value;
      }
    }
    return 5;
  }
}

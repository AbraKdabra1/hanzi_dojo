// ─────────────────────────────────────────────────────────────────────────────
// pinyin_entrada.dart — Leer el pinyin que escribe el usuario
//
// En el ejercicio de pinyin escribes la lectura de una palabra. Se aceptan
// todas las formas habituales:
//   · con números:     ni3hao3, ni3 hao3, ba4ba (sin número = tono neutro)
//   · con acentos:     nǐhǎo, bàba
//   · la ü como v, u: o ü:  lv4, lu:4, lǜ
// y se compara sílaba por sílaba con la lectura correcta.
//
// Todo es cálculo puro (sin interfaz) para poder probarlo.
// ─────────────────────────────────────────────────────────────────────────────

import '../datos/audio.dart';

/// Qué tan bien escribiste el pinyin.
enum Veredicto {
  /// Sílabas y tonos correctos.
  correcto,

  /// Las sílabas están bien pero algún tono no.
  tonos,

  /// Alguna sílaba está mal (o no se entendió lo que escribiste).
  incorrecto,
}

class ResultadoPinyin {
  const ResultadoPinyin(this.veredicto, this.silabasBien);

  final Veredicto veredicto;

  /// Una entrada por sílaba esperada: true si la escribiste exactamente igual.
  final List<bool> silabasBien;
}

class PinyinEntrada {
  PinyinEntrada._();

  static const _vocales = {
    'a': 'āáǎà', 'e': 'ēéěè', 'i': 'īíǐì', 'o': 'ōóǒò', 'u': 'ūúǔù', 'ü': 'ǖǘǚǜ',
  };

  /// 'hao3' → 'hǎo';  'lv4' → 'lǜ';  'ma5' → 'ma';  '_' (儿 de erhua) → ''.
  static String numAAcentos(String silaba) {
    final s = silaba.trim().toLowerCase().replaceAll('u:', 'v');
    if (s == '_') return '';
    final m = RegExp(r'^([a-zv]+)([0-5])$').firstMatch(s);
    if (m == null) return s.replaceAll('v', 'ü');
    final base = m.group(1)!.replaceAll('v', 'ü');
    final tono = int.parse(m.group(2)!);
    if (tono == 0 || tono == 5) return base;
    var i = -1;
    if (base.contains('a')) {
      i = base.indexOf('a');
    } else if (base.contains('e')) {
      i = base.indexOf('e');
    } else if (base.contains('ou')) {
      i = base.indexOf('o');
    } else {
      for (var k = base.length - 1; k >= 0; k--) {
        if (_vocales.containsKey(base[k])) {
          i = k;
          break;
        }
      }
    }
    if (i < 0) return base;
    return '${base.substring(0, i)}${_vocales[base[i]]![tono - 1]}${base.substring(i + 1)}';
  }

  /// Sílabas sin tono que existen ('ma', 'zhuang', 'lv'…) a partir de la
  /// lista de sílabas grabadas ('ma1', '_ng2'…).
  static Set<String> basesDe(Iterable<String> silabasGrabadas) =>
      {for (final s in silabasGrabadas) s.replaceAll(RegExp(r'[0-9_]'), '')};

  static final _separadores = RegExp(r"[\s'’\-·,.;:!?]+");
  static final _trozoValido = RegExp(r'^[a-zvāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ]+[0-5]?$');

  /// Lo que escribió el usuario → claves de sílaba ('ni3', 'hao3'), o null
  /// si no se puede leer como pinyin. Una sílaba sin número ni acento es
  /// tono neutro (5).
  static List<String>? analizar(String entrada, Set<String> bases) {
    final texto = entrada.toLowerCase().replaceAll('u:', 'v').replaceAll('ü', 'v');
    final salida = <String>[];
    for (final palabra in texto.split(_separadores)) {
      if (palabra.isEmpty) continue;
      final partes = _partir(palabra, bases);
      if (partes == null) return null;
      salida.addAll(partes);
    }
    return salida.isEmpty ? null : salida;
  }

  /// Parte una palabra en sílabas: la partición con MENOS sílabas (así
  /// 'xian1' es una sílaba; para 西安 hay que escribir 'xi1an1' o "xi'an").
  /// Un número solo puede ir al final de su sílaba.
  static List<String>? _partir(String palabra, Set<String> bases) {
    final n = palabra.length;
    final mejor = List<List<String>?>.filled(n + 1, null);
    mejor[0] = const [];
    for (var i = 0; i < n; i++) {
      final previo = mejor[i];
      if (previo == null) continue;
      for (var j = i + 1; j <= n && j <= i + 8; j++) {
        final trozo = palabra.substring(i, j);
        if (!_trozoValido.hasMatch(trozo)) continue;
        final clave = Audio.claveSilaba(trozo);
        if (clave == null) continue;
        if (!bases.contains(clave.substring(0, clave.length - 1))) continue;
        final candidato = [...previo, clave];
        final actual = mejor[j];
        if (actual == null || actual.length > candidato.length) mejor[j] = candidato;
      }
    }
    return mejor[n];
  }

  /// Compara lo esperado (claves como 'ba4', 'ba5') con lo escrito.
  static ResultadoPinyin comparar(List<String> esperadas, List<String>? escritas) {
    if (escritas == null || escritas.length != esperadas.length) {
      return ResultadoPinyin(Veredicto.incorrecto, List.filled(esperadas.length, false));
    }
    final bien = <bool>[];
    var mismasSilabas = true;
    for (var k = 0; k < esperadas.length; k++) {
      final e = esperadas[k];
      final w = escritas[k];
      bien.add(e == w);
      if (_base(e) != _base(w)) mismasSilabas = false;
    }
    if (bien.every((b) => b)) return ResultadoPinyin(Veredicto.correcto, bien);
    return ResultadoPinyin(mismasSilabas ? Veredicto.tonos : Veredicto.incorrecto, bien);
  }

  static String _base(String clave) => clave.replaceAll(RegExp(r'[0-9]'), '');

  /// Vista previa con acentos de lo que llevas escrito ('ni3hao' → 'nǐ hao'),
  /// o null si todavía no se puede leer.
  static String? vistaPrevia(String entrada, Set<String> bases) {
    final claves = analizar(entrada, bases);
    if (claves == null) return null;
    return claves.map(numAAcentos).join(' ');
  }
}

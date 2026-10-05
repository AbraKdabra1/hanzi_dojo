// ─────────────────────────────────────────────────────────────────────────────
// audio.dart — Qué grabaciones tocar para pronunciar un texto
//
// La app trae grabaciones de hablantes nativos (assets/audio/, ver
// herramientas_datos/preparar_audio.py):
//   · silabas/ma1.opus  — las 1,707 sílabas del mandarín, con su tono.
//   · palabras/<código>.opus — ~8,500 palabras y caracteres HSK.
//
// Aquí está solo la lógica (sin reproducir nada), para poder probarla:
//   · claveSilaba('zhǎng') → 'zhang3'
//   · nombrePalabra('图书馆') → '56fe-4e66-9986'
//   · planDeLectura(...) → la lista de grabaciones para leer un texto: las
//     palabras grabadas más largas que quepan y, para lo demás, la sílaba de
//     cada carácter según su pinyin en ESE texto (长 de 长大 = zhǎng).
// La reproducción está en widgets/boton_voz.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// Una pieza de la lectura: una grabación o una pausa breve.
class Clip {
  Clip.palabra(String palabra, {this.inicio = -1, this.fin = -1})
      : ruta = 'assets/audio/palabras/$palabra.opus',
        pausaMs = 0;
  Clip.silaba(String clave, {this.inicio = -1, this.fin = -1})
      : ruta = 'assets/audio/silabas/$clave.opus',
        pausaMs = 0;
  const Clip.pausa(this.pausaMs)
      : ruta = '',
        inicio = -1,
        fin = -1;

  /// Asset a reproducir ('' si es una pausa).
  final String ruta;
  final int pausaMs;

  /// Qué parte del texto suena: runas [inicio, fin) (-1 si no se sabe).
  /// Sirve para resaltar lo que se va leyendo.
  final int inicio;
  final int fin;

  bool get esPausa => pausaMs > 0;

  @override
  String toString() => esPausa ? 'pausa($pausaMs)' : ruta.split('/').last;
}

/// Plan para leer un texto.
class PlanLectura {
  const PlanLectura(this.clips, {required this.caracteres, required this.cubiertos});

  final List<Clip> clips;

  /// Caracteres chinos del texto y cuántos tienen grabación.
  final int caracteres;
  final int cubiertos;

  bool get completo => caracteres > 0 && cubiertos == caracteres;
  int get grabaciones => clips.where((c) => !c.esPausa).length;
}

class Audio {
  Audio._();

  static const _conTono = {
    'ā': ('a', 1), 'á': ('a', 2), 'ǎ': ('a', 3), 'à': ('a', 4),
    'ē': ('e', 1), 'é': ('e', 2), 'ě': ('e', 3), 'è': ('e', 4),
    'ī': ('i', 1), 'í': ('i', 2), 'ǐ': ('i', 3), 'ì': ('i', 4),
    'ō': ('o', 1), 'ó': ('o', 2), 'ǒ': ('o', 3), 'ò': ('o', 4),
    'ū': ('u', 1), 'ú': ('u', 2), 'ǔ': ('u', 3), 'ù': ('u', 4),
    'ǖ': ('v', 1), 'ǘ': ('v', 2), 'ǚ': ('v', 3), 'ǜ': ('v', 4),
    'ń': ('n', 2), 'ň': ('n', 3), 'ǹ': ('n', 4), 'ḿ': ('m', 2),
  };

  static final _letra = RegExp(r'[a-z]');
  static final _digitoTono = RegExp(r'[1-5]');
  static final _conU = RegExp(r'^[jqxy]');

  /// Sílaba de pinyin (con marca de tono o con número) → nombre del archivo,
  /// sin comprobar que exista: 'zhǎng' → 'zhang3', 'lǜ' → 'lv4', 'ma' → 'ma5',
  /// 'huàr' → 'hua4' (la r final se omite: no hay grabaciones con erhua).
  static String? claveSilaba(String pinyin) {
    final p = pinyin.trim().toLowerCase();
    if (p.isEmpty) return null;
    var tono = 0;
    final base = StringBuffer();
    for (final r in p.runes) {
      final c = String.fromCharCode(r);
      final marcado = _conTono[c];
      if (marcado != null) {
        base.write(marcado.$1);
        tono = marcado.$2;
      } else if (c == 'ü' || c == 'v') {
        base.write('v');
      } else if (_letra.hasMatch(c)) {
        base.write(c);
      } else if (_digitoTono.hasMatch(c)) {
        tono = int.parse(c);
      } else if (c == ':') {
        // 'u:' = ü (estilo CC-CEDICT)
        final s = base.toString();
        if (s.endsWith('u')) {
          base
            ..clear()
            ..write('${s.substring(0, s.length - 1)}v');
        }
      }
    }
    var b = base.toString();
    if (b.isEmpty) return null;
    // Después de j, q, x, y la ü se escribe u (ju, que, xun, yue).
    if (_conU.hasMatch(b)) b = b.replaceAll('v', 'u');
    // Erhua: 'huar' → 'hua' (pero 'er' es una sílaba por sí misma).
    if (b.length > 2 && b.endsWith('r')) b = b.substring(0, b.length - 1);
    return '$b${tono == 0 ? 5 : tono}';
  }

  /// La clave de la sílaba que SÍ está grabada, o null.
  /// Prueba la exacta; luego la versión de interjección ('_ng2'); y si el
  /// tono neutro no está, el mismo sonido en tono 1.
  static String? silabaDisponible(String pinyin, Set<String> silabas) {
    final clave = claveSilaba(pinyin);
    if (clave == null) return null;
    if (silabas.contains(clave)) return clave;
    if (silabas.contains('_$clave')) return '_$clave';
    // En la colección, jù está guardada como 'jv4'.
    if (RegExp(r'^[jqxy]u').hasMatch(clave)) {
      final conV = clave.replaceFirst('u', 'v');
      if (silabas.contains(conV)) return conV;
    }
    if (clave.endsWith('5')) {
      final base = clave.substring(0, clave.length - 1);
      for (final t in ['1', '2', '3', '4']) {
        if (silabas.contains('$base$t')) return '$base$t';
        if (silabas.contains('_$base$t')) return '_$base$t';
      }
    }
    return null;
  }

  /// '图书馆' → '56fe-4e66-9986' (igual que en preparar_audio.py).
  static String nombrePalabra(String palabra) =>
      [for (final r in palabra.runes) r.toRadixString(16)].join('-');

  static bool esHan(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF) || (r >= 0x20000 && r <= 0x2FFFF);

  static const _pausaLarga = '。！？；…\n';
  static const _pausaCorta = '，、：,.!?;:—';

  /// Cómo leer [texto] con las grabaciones.
  ///
  /// [pinyin], si se da, trae una sílaba por carácter de [texto] (por runa) y
  /// sirve para elegir la lectura correcta de los caracteres sueltos.
  static PlanLectura planDeLectura(
    String texto, {
    List<String>? pinyin,
    required Set<String> palabras,
    required Set<String> silabas,
    int largoMaximo = 4,
  }) {
    final runas = texto.runes.toList();
    final conPinyin = pinyin != null && pinyin.length == runas.length;
    final clips = <Clip>[];
    var caracteres = 0;
    var cubiertos = 0;

    void pausa(int ms) {
      if (clips.isEmpty) return;
      if (clips.last.esPausa) {
        if (clips.last.pausaMs < ms) clips[clips.length - 1] = Clip.pausa(ms);
      } else {
        clips.add(Clip.pausa(ms));
      }
    }

    var i = 0;
    while (i < runas.length) {
      final r = runas[i];
      if (!esHan(r)) {
        final c = String.fromCharCode(r);
        if (_pausaLarga.contains(c)) {
          pausa(450);
        } else if (_pausaCorta.contains(c)) {
          pausa(250);
        }
        i++;
        continue;
      }

      // ¿Empieza aquí una palabra grabada (de 2 caracteres o más)?
      var largo = 0;
      for (var l = largoMaximo; l >= 2; l--) {
        if (i + l > runas.length) continue;
        final trozo = runas.sublist(i, i + l);
        if (!trozo.every(esHan)) continue;
        if (palabras.contains(String.fromCharCodes(trozo))) {
          largo = l;
          break;
        }
      }
      if (largo > 0) {
        clips.add(Clip.palabra(nombrePalabra(String.fromCharCodes(runas.sublist(i, i + largo))),
            inicio: i, fin: i + largo));
        caracteres += largo;
        cubiertos += largo;
        i += largo;
        continue;
      }

      // Carácter suelto: su sílaba según el pinyin del texto; si no hay
      // pinyin, la grabación del carácter (si la hay).
      caracteres++;
      final silaba = conPinyin ? silabaDisponible(pinyin[i], silabas) : null;
      final c = String.fromCharCode(r);
      if (silaba != null) {
        clips.add(Clip.silaba(silaba, inicio: i, fin: i + 1));
        cubiertos++;
      } else if (palabras.contains(c)) {
        clips.add(Clip.palabra(nombrePalabra(c), inicio: i, fin: i + 1));
        cubiertos++;
      }
      i++;
    }
    while (clips.isNotEmpty && clips.last.esPausa) {
      clips.removeLast();
    }
    return PlanLectura(clips, caracteres: caracteres, cubiertos: cubiertos);
  }

  /// Parte un pinyin escrito por palabras ('Wǒ xǐhuan chī píngguǒ.') en
  /// sílabas, usando la lista de sílabas grabadas para saber dónde cortar.
  /// null si alguna palabra no se puede partir.
  static List<String>? silabasDePinyin(String pinyin, Set<String> silabas) {
    final bases = {for (final s in silabas) s.replaceAll(RegExp(r'[0-9_]'), '')};
    final resultado = <String>[];
    for (final palabra in pinyin.split(RegExp(r"[\s'’\-]+"))) {
      // Solo letras (con sus marcas de tono): fuera puntuación.
      final limpia = palabra.replaceAll(RegExp(r'[^a-zA-ZāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüÜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙ]'), '');
      if (limpia.isEmpty) continue;
      final partes = _partir(limpia, bases);
      if (partes == null) return null;
      resultado.addAll(partes);
    }
    return resultado;
  }

  /// Una sílaba por runa de [texto] ('' en la puntuación), a partir de un
  /// pinyin escrito por palabras. null si no cuadra (así nunca se lee un
  /// carácter con la sílaba de otro).
  ///
  /// Erhua: en 这儿 = 'zhèr' hay dos caracteres y una sola sílaba; ese 儿 se
  /// queda sin sílaba propia ('').
  static List<String>? alinearPinyin(String texto, String pinyinPorPalabras, Set<String> silabas) {
    final silabasTexto = silabasDePinyin(pinyinPorPalabras, silabas);
    if (silabasTexto == null) return null;
    final resultado = <String>[];
    var k = 0;
    var anteriorConR = false;
    for (final r in texto.runes) {
      if (!esHan(r)) {
        resultado.add('');
        continue;
      }
      if (r == 0x513F && anteriorConR) {
        // 儿 de erhua
        resultado.add('');
        anteriorConR = false;
        continue;
      }
      if (k >= silabasTexto.length) return null;
      final silaba = silabasTexto[k++];
      anteriorConR = silaba.length > 2 && silaba.toLowerCase().endsWith('r');
      resultado.add(silaba);
    }
    return k == silabasTexto.length ? resultado : null;
  }

  /// Parte una palabra de pinyin en sílabas (la partición más corta posible,
  /// para preferir 'xian' a 'xi'+'an').
  static List<String>? _partir(String palabra, Set<String> bases) {
    final p = palabra.toLowerCase();
    final n = p.length;
    final mejor = List<List<String>?>.filled(n + 1, null);
    mejor[0] = [];
    for (var i = 0; i < n; i++) {
      final previo = mejor[i];
      if (previo == null) continue;
      for (var j = n; j > i; j--) {
        final trozo = p.substring(i, j);
        final clave = claveSilaba(trozo);
        if (clave == null) continue;
        final base = clave.substring(0, clave.length - 1);
        // claveSilaba ya quitó la r del erhua ('huar' → 'hua').
        if (!bases.contains(base)) continue;
        final candidato = [...previo, palabra.substring(i, j)];
        if (mejor[j] == null || mejor[j]!.length > candidato.length) mejor[j] = candidato;
      }
    }
    return mejor[n];
  }
}

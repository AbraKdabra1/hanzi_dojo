// ─────────────────────────────────────────────────────────────────────────────
// importar_libro.dart — Convierte un archivo del usuario en un libro de «Leer»
//
// Formatos:
//   TXT   UTF-8 (con o sin BOM), UTF-16 (con BOM) o GBK/GB18030, que es como
//         vienen muchísimos archivos chinos. El GBK se decodifica con una
//         tabla que trae contenido.db (no hace falta ningún paquete).
//   EPUB  sin protección (DRM). Un EPUB es un ZIP con páginas XHTML: se lee
//         con un lector de ZIP propio (zip_simple.dart) y se sigue el orden
//         de lectura del libro (el "spine").
//   Texto pegado directamente.
//
// Lo que sale: título, capítulos y párrafos. Los capítulos se detectan por
// sus encabezados (第一章, 第二回, 序…); si no hay, el texto se parte en
// "Partes" de unos 3,000 caracteres. Los párrafos larguísimos (texto sin
// saltos de línea) se parten por oraciones.
//
// Después, para cada carácter se calcula su pinyin (lectura principal de la
// base, con reglas para las partículas y los cambios de tono de 一 y 不) y se
// estima el nivel HSK del libro. Todo es Dart puro: corre en otro isolate
// para no congelar la pantalla.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import '../helpers/zip_simple.dart';
import '../idioma.dart';

/// El archivo no se puede convertir en libro (el mensaje se muestra al usuario).
class LibroInvalido implements Exception {
  const LibroInvalido(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class CapituloImportado {
  const CapituloImportado(this.titulo, this.parrafos);
  final String titulo;
  final List<String> parrafos;
}

/// Un libro ya partido en capítulos y párrafos (sin pinyin todavía).
class LibroImportado {
  const LibroImportado({required this.titulo, required this.formato, required this.capitulos});
  final String titulo;

  /// txt | epub | texto
  final String formato;
  final List<CapituloImportado> capitulos;

  int get caracteresChinos =>
      capitulos.fold(0, (n, c) => n + c.parrafos.fold(0, (m, p) => m + contarHan(p)));
}

/// Datos de la base que hacen falta para preparar el libro.
class DiccionarioLectura {
  const DiccionarioLectura({
    required this.pinyin,
    required this.nivel,
    required this.simplificado,
  });

  /// Carácter → lectura principal ("hǎo").
  final Map<String, String> pinyin;

  /// Carácter → nivel HSK (1-7; 0 = fuera de HSK).
  final Map<String, int> nivel;

  /// Tradicional → simplificado.
  final Map<String, String> simplificado;

  String simple(String c) => simplificado[c] ?? c;
}

/// Un libro listo para guardar: cada párrafo con su pinyin.
class LibroPreparado {
  const LibroPreparado({
    required this.libro,
    required this.pinyin,
    required this.nivelEstimado,
    required this.cobertura,
    required this.caracteres,
  });

  final LibroImportado libro;

  /// pinyin[capítulo][párrafo] = una sílaba por carácter (por código Unicode).
  final List<List<List<String>>> pinyin;

  /// Nivel HSK más bajo con el que se conoce al menos el 90 % de los
  /// caracteres (1-7); 0 si ni con HSK 7-9 se llega.
  final int nivelEstimado;

  /// Fracción conocida en [nivelEstimado] (o en 7-9 si es 0).
  final double cobertura;
  final int caracteres;
}

bool esHanRuna(int r) =>
    (r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF) || (r >= 0x20000 && r <= 0x2FFFF);

int contarHan(String s) => s.runes.where(esHanRuna).length;

class ImportadorLibros {
  ImportadorLibros._();

  /// Archivos más grandes no se intentan leer.
  static const tamanoMaximo = 20 * 1024 * 1024;

  /// Caracteres por "Parte" cuando el texto no tiene capítulos.
  static const caracteresPorParte = 3000;

  /// Párrafos más largos que esto se parten por oraciones.
  static const largoMaximoParrafo = 600;

  static const coberturaParaNivel = 0.90;

  // ═══════════════════════════════════════════════════════════════════════
  // Leer archivos
  // ═══════════════════════════════════════════════════════════════════════

  /// Convierte un archivo en libro. [tablaGbk]: tabla "gbk" de contenido.db.
  static LibroImportado leer(String nombreArchivo, Uint8List bytes, {required String tablaGbk}) {
    if (bytes.length > tamanoMaximo) {
      throw LibroInvalido(tr('El archivo es demasiado grande (máximo 20 MB).'));
    }
    final minusculas = nombreArchivo.toLowerCase();
    if (minusculas.endsWith('.pdf') || _empiezaCon(bytes, '%PDF')) {
      throw LibroInvalido(tr('Los PDF todavía no se pueden abrir. Por ahora: TXT o EPUB.'));
    }
    final titulo = _sinExtension(nombreArchivo);
    if (ZipSimple.esZip(bytes)) return _leerEpub(bytes, titulo);
    return desdeTexto(titulo, decodificarTexto(bytes, tablaGbk), formato: 'txt');
  }

  /// Un libro a partir de texto ya decodificado (TXT o texto pegado).
  static LibroImportado desdeTexto(String titulo, String texto, {String formato = 'texto'}) {
    final capitulos = partirEnCapitulos(texto);
    final libro = LibroImportado(
      titulo: titulo.trim().isEmpty ? tr('Mi libro') : titulo.trim(),
      formato: formato,
      capitulos: capitulos,
    );
    _revisar(libro);
    return libro;
  }

  static void _revisar(LibroImportado libro) {
    if (libro.capitulos.isEmpty || libro.caracteresChinos < 10) {
      throw LibroInvalido(tr('No encontré texto en chino en este archivo.'));
    }
  }

  static bool _empiezaCon(Uint8List b, String ascii) =>
      b.length >= ascii.length && String.fromCharCodes(b.sublist(0, ascii.length)) == ascii;

  static String _sinExtension(String nombre) {
    final base = nombre.split(RegExp(r'[\\/]')).last;
    final punto = base.lastIndexOf('.');
    return punto > 0 ? base.substring(0, punto) : base;
  }

  // ── Texto: codificación ─────────────────────────────────────────────────

  /// Decodifica bytes de texto: UTF-8 (con o sin BOM), UTF-16 con BOM o GBK.
  static String decodificarTexto(Uint8List b, String tablaGbk) {
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      return utf8.decode(b.sublist(3), allowMalformed: true);
    }
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return _utf16(b, 2, little: true);
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return _utf16(b, 2, little: false);
    try {
      return utf8.decode(b);
    } on FormatException {
      return decodificarGbk(b, tablaGbk);
    }
  }

  static String _utf16(Uint8List b, int inicio, {required bool little}) {
    final unidades = <int>[];
    for (int i = inicio; i + 1 < b.length; i += 2) {
      unidades.add(little ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(unidades);
  }

  /// GBK / GB18030 con la tabla de 126 × 191 caracteres de contenido.db.
  static String decodificarGbk(Uint8List b, String tabla) {
    final s = StringBuffer();
    int i = 0;
    while (i < b.length) {
      final b1 = b[i];
      if (b1 < 0x80) {
        s.writeCharCode(b1);
        i++;
      } else if (b1 >= 0x81 && b1 <= 0xFE && i + 1 < b.length) {
        final b2 = b[i + 1];
        if (b2 >= 0x30 && b2 <= 0x39) {
          // Secuencia de 4 bytes de GB18030 (muy rara en texto chino común).
          s.write('\uFFFD');
          i += 4;
        } else if (b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F) {
          final pos = (b1 - 0x81) * 191 + (b2 - 0x40);
          s.write(pos < tabla.length ? tabla[pos] : '\uFFFD');
          i += 2;
        } else {
          s.write('\uFFFD');
          i++;
        }
      } else {
        s.write('\uFFFD');
        i++;
      }
    }
    return s.toString();
  }

  // ── Texto: capítulos y párrafos ─────────────────────────────────────────

  /// 第一章…, 第十二回…, 第3节… (con o sin título después).
  static final _encabezadoNumerado =
      RegExp(r'^第[0-9０-９零〇一二三四五六七八九十百千两]+[章回节卷部篇集幕]');

  /// 序, 前言, 后记… solos (seguidos de espacio, dos puntos o nada).
  static final _encabezadoSuelto = RegExp(r'^(序章|序言|序|楔子|引子|前言|尾声|后记|番外)(\s|：|:|$)');

  static bool _esEncabezado(String l) =>
      l.length <= 40 && (_encabezadoNumerado.hasMatch(l) || _encabezadoSuelto.hasMatch(l));

  /// Parte un texto en capítulos y párrafos.
  static List<CapituloImportado> partirEnCapitulos(String texto) {
    final lineas = texto
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll('\u3000', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final esEncabezado = [for (final l in lineas) _esEncabezado(l)];
    final cuantos = esEncabezado.where((e) => e).length;

    final capitulos = <CapituloImportado>[];
    if (cuantos >= 2) {
      String? titulo;
      var parrafos = <String>[];
      void cerrar() {
        final ps = _partirLargos(parrafos);
        if (ps.isNotEmpty) capitulos.add(CapituloImportado(titulo ?? 'Inicio', ps));
      }

      for (int i = 0; i < lineas.length; i++) {
        if (esEncabezado[i]) {
          cerrar();
          titulo = lineas[i];
          parrafos = [];
        } else {
          parrafos.add(lineas[i]);
        }
      }
      cerrar();
      return capitulos;
    }

    // Sin encabezados: "Partes" de unos [caracteresPorParte] caracteres.
    var parte = <String>[];
    var largo = 0;
    for (final p in _partirLargos(lineas)) {
      parte.add(p);
      largo += p.length;
      if (largo >= caracteresPorParte) {
        capitulos.add(CapituloImportado(tr('Parte {0}', [capitulos.length + 1]), parte));
        parte = [];
        largo = 0;
      }
    }
    if (parte.isNotEmpty) {
      capitulos.add(CapituloImportado(
          capitulos.isEmpty ? tr('Texto') : tr('Parte {0}', [capitulos.length + 1]), parte));
    }
    return capitulos;
  }

  /// Parte los párrafos larguísimos en trozos que terminan en fin de oración.
  static List<String> _partirLargos(List<String> parrafos) {
    final salida = <String>[];
    for (final p in parrafos) {
      if (p.length <= largoMaximoParrafo) {
        salida.add(p);
        continue;
      }
      final oraciones = RegExp(r'[^。！？!?]+[。！？!?」”’]*').allMatches(p).map((m) => m[0]!);
      var trozo = StringBuffer();
      for (final o in oraciones) {
        trozo.write(o);
        if (trozo.length >= 200) {
          salida.add(trozo.toString().trim());
          trozo = StringBuffer();
        }
      }
      if (trozo.isNotEmpty) salida.add(trozo.toString().trim());
    }
    return salida.where((p) => p.isNotEmpty).toList();
  }

  // ── EPUB ────────────────────────────────────────────────────────────────

  static LibroImportado _leerEpub(Uint8List bytes, String tituloArchivo) {
    final Map<String, Uint8List> archivos;
    try {
      archivos = ZipSimple.leer(bytes);
    } catch (_) {
      throw LibroInvalido(tr('El archivo está dañado o no es un EPUB.'));
    }
    String? texto(String ruta) {
      final b = archivos[ruta];
      return b == null ? null : utf8.decode(b, allowMalformed: true);
    }

    final contenedor = texto('META-INF/container.xml');
    final rutaOpf = contenedor == null ? null : RegExp(r'full-path="([^"]+)"').firstMatch(contenedor)?[1];
    final opf = rutaOpf == null ? null : texto(rutaOpf);
    if (rutaOpf == null || opf == null) {
      throw LibroInvalido(tr('Este archivo no es un EPUB.'));
    }

    // DRM: si el contenido (no solo las fuentes) está cifrado, no se puede leer.
    final cifrado = texto('META-INF/encryption.xml');
    if (cifrado != null &&
        RegExp(r'CipherReference[^>]*URI="[^"]+\.(x?html?|xml)"', caseSensitive: false).hasMatch(cifrado)) {
      throw LibroInvalido(tr('Este EPUB tiene protección (DRM) y no se puede leer.'));
    }

    final carpeta = rutaOpf.contains('/') ? rutaOpf.substring(0, rutaOpf.lastIndexOf('/') + 1) : '';
    final titulo = _entidades(_sinEtiquetas(
            RegExp(r'<dc:title[^>]*>(.*?)</dc:title>', dotAll: true).firstMatch(opf)?[1] ?? ''))
        .trim();

    // Manifiesto: id → ruta. Spine: orden de lectura.
    final manifiesto = <String, String>{};
    for (final m in RegExp(r'<item\b[^>]*>', dotAll: true).allMatches(opf)) {
      final etiqueta = m[0]!;
      final id = _atributo(etiqueta, 'id');
      final href = _atributo(etiqueta, 'href');
      final tipo = _atributo(etiqueta, 'media-type') ?? '';
      if (id != null && href != null && tipo.contains('html')) {
        manifiesto[id] = _resolver(carpeta, Uri.decodeFull(href));
      }
    }
    final orden = [
      for (final m in RegExp(r'<itemref\b[^>]*>').allMatches(opf))
        if (_atributo(m[0]!, 'idref') case final idref? when manifiesto.containsKey(idref)) manifiesto[idref]!,
    ];

    final capitulos = <CapituloImportado>[];
    for (final ruta in orden) {
      final html = texto(ruta);
      if (html == null) continue;
      final parrafos = _partirLargos(_parrafosHtml(html));
      if (parrafos.fold(0, (n, p) => n + contarHan(p)) < 10) continue; // portada, índice…
      final tituloCap = _tituloHtml(html) ?? tr('Capítulo {0}', [capitulos.length + 1]);
      // Si el primer párrafo es el mismo título, no se repite.
      if (parrafos.isNotEmpty && parrafos.first == tituloCap) parrafos.removeAt(0);
      if (parrafos.isNotEmpty) capitulos.add(CapituloImportado(tituloCap, parrafos));
    }
    final libro = LibroImportado(
      titulo: titulo.isEmpty ? tituloArchivo : titulo,
      formato: 'epub',
      capitulos: capitulos,
    );
    _revisar(libro);
    return libro;
  }

  static String? _atributo(String etiqueta, String nombre) =>
      RegExp('\\s$nombre\\s*=\\s*["\']([^"\']*)["\']').firstMatch(etiqueta)?[1];

  /// Une la carpeta del OPF con una ruta relativa ("../Text/c1.xhtml").
  static String _resolver(String carpeta, String href) {
    final partes = <String>[...carpeta.split('/').where((p) => p.isNotEmpty)];
    for (final p in href.split('#').first.split('/')) {
      if (p == '..') {
        if (partes.isNotEmpty) partes.removeLast();
      } else if (p.isNotEmpty && p != '.') {
        partes.add(p);
      }
    }
    return partes.join('/');
  }

  static String? _tituloHtml(String html) {
    for (final patron in [r'<h[1-3][^>]*>(.*?)</h[1-3]>', r'<title[^>]*>(.*?)</title>']) {
      final m = RegExp(patron, dotAll: true, caseSensitive: false).firstMatch(html);
      final t = m == null ? '' : _entidades(_sinEtiquetas(m[1]!)).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.isNotEmpty && t.length <= 60) return t;
    }
    return null;
  }

  static List<String> _parrafosHtml(String html) {
    var cuerpo = html;
    final inicio = RegExp(r'<body[^>]*>', caseSensitive: false).firstMatch(cuerpo);
    if (inicio != null) cuerpo = cuerpo.substring(inicio.end);
    cuerpo = cuerpo
        .replaceAll(RegExp(r'<(script|style|rt|rp)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>|</(p|div|h[1-6]|li|tr|blockquote)>', caseSensitive: false), '\n');
    return _entidades(_sinEtiquetas(cuerpo))
        .split('\n')
        .map((l) => l.replaceAll('\u3000', ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static String _sinEtiquetas(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  static String _entidades(String s) => s.replaceAllMapped(
        RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);'),
        (m) {
          final e = m[1]!;
          if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
          if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
          return const {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '}[e]!;
        },
      );

  // ═══════════════════════════════════════════════════════════════════════
  // Pinyin y nivel
  // ═══════════════════════════════════════════════════════════════════════

  /// Agrega el pinyin a cada carácter y estima el nivel HSK.
  static LibroPreparado preparar(LibroImportado libro, DiccionarioLectura d) {
    final porNivel = List<int>.filled(8, 0); // caracteres de cada nivel (0 = fuera)
    var total = 0;
    final pinyin = <List<List<String>>>[];
    for (final cap in libro.capitulos) {
      final pc = <List<String>>[];
      for (final p in cap.parrafos) {
        final caracteres = [for (final r in p.runes) String.fromCharCode(r)];
        pc.add(pinyinDe(caracteres, d));
        for (final c in caracteres) {
          if (!esHanRuna(c.runes.first)) continue;
          total++;
          final n = d.nivel[d.simple(c)] ?? 0;
          porNivel[n < 0 || n > 7 ? 0 : n]++;
        }
      }
      pinyin.add(pc);
    }
    var nivel = 0;
    var cobertura = 0.0;
    var acumulado = 0;
    for (int n = 1; n <= 7; n++) {
      acumulado += porNivel[n];
      cobertura = total == 0 ? 0 : acumulado / total;
      if (cobertura >= coberturaParaNivel) {
        nivel = n;
        break;
      }
    }
    return LibroPreparado(
      libro: libro,
      pinyin: pinyin,
      nivelEstimado: nivel,
      cobertura: cobertura,
      caracteres: total,
    );
  }

  static const _numeros = '零一二三四五六七八九十百千万两几第';

  /// Una sílaba por carácter: la lectura principal de la base, más reglas
  /// para las partículas más comunes y los cambios de tono de 一 y 不.
  /// (Los caracteres con varias lecturas pueden salir con la principal.)
  static List<String> pinyinDe(List<String> cs, DiccionarioLectura d) {
    final salida = [
      for (final c in cs) esHanRuna(c.runes.first) ? (d.pinyin[d.simple(c)] ?? '') : '',
    ];
    String en(int i) => i >= 0 && i < cs.length ? d.simple(cs[i]) : '';
    for (int i = 0; i < cs.length; i++) {
      final c = d.simple(cs[i]);
      final antes = en(i - 1);
      final despues = en(i + 1);
      switch (c) {
        case '的':
          salida[i] = despues == '确' ? 'dí' : (antes == '目' ? 'dì' : 'de');
        case '了':
          // 了解, 受不了, 来得了: liǎo. Si no, la partícula "le".
          salida[i] = (despues == '解' || antes == '不' || antes == '得') ? 'liǎo' : 'le';
        case '着':
          salida[i] = (despues == '急' || despues == '火' || despues == '凉') ? 'zháo' : 'zhe';
        case '们' || '么' || '吗' || '呢' || '吧':
          salida[i] = const {'们': 'men', '么': 'me', '吗': 'ma', '呢': 'ne', '吧': 'ba'}[c]!;
        case '得':
          salida[i] = (despues == '到' || despues == '意') ? 'dé' : 'de';
        case '都':
          salida[i] = (despues == '市' || antes == '首' || antes == '成') ? 'dū' : 'dōu';
        case '谁':
          salida[i] = 'shéi';
      }
    }
    // 一 y 不 según el tono de la sílaba siguiente.
    for (int i = 0; i < cs.length; i++) {
      final c = d.simple(cs[i]);
      if (c != '一' && c != '不') continue;
      final antes = en(i - 1);
      final despues = en(i + 1);
      final sig = i + 1 < cs.length ? salida[i + 1] : '';
      final tono = _tono(sig);
      if (c == '不') {
        salida[i] = sig.isNotEmpty && tono == 4 ? 'bú' : 'bù';
      } else if (sig.isEmpty ||
          (antes.isNotEmpty && _numeros.contains(antes)) ||
          (despues.isNotEmpty && (_numeros.contains(despues) || '月号'.contains(despues)))) {
        // Ojo: ''.contains('') es true; por eso se revisa que no estén vacíos.
        salida[i] = 'yī';
      } else {
        salida[i] = (tono == 4 || tono == 5) ? 'yí' : 'yì';
      }
    }
    return salida;
  }

  static int _tono(String silaba) {
    for (final c in silaba.split('')) {
      if ('āēīōūǖ'.contains(c)) return 1;
      if ('áéíóúǘ'.contains(c)) return 2;
      if ('ǎěǐǒǔǚ'.contains(c)) return 3;
      if ('àèìòùǜ'.contains(c)) return 4;
    }
    return 5;
  }
}

/// Lo que se manda al isolate de fondo para preparar un libro: o un archivo
/// ([bytes] y su [nombre]) o un texto pegado ([titulo] y [texto]).
class PeticionLibro {
  const PeticionLibro.archivo(this.nombre, Uint8List this.bytes, this.tablaGbk, this.diccionario)
      : titulo = '',
        texto = '';

  const PeticionLibro.texto(this.titulo, this.texto, this.diccionario)
      : nombre = '',
        bytes = null,
        tablaGbk = '';

  final String nombre;
  final Uint8List? bytes;
  final String tablaGbk;
  final String titulo;
  final String texto;
  final DiccionarioLectura diccionario;
}

/// Lee y prepara un libro. Es una función de nivel superior para poder
/// correrla en otro isolate con `compute` (sin congelar la pantalla).
LibroPreparado prepararLibro(PeticionLibro p) {
  final bytes = p.bytes;
  final libro = bytes != null
      ? ImportadorLibros.leer(p.nombre, bytes, tablaGbk: p.tablaGbk)
      : ImportadorLibros.desdeTexto(p.titulo, p.texto);
  return ImportadorLibros.preparar(libro, p.diccionario);
}

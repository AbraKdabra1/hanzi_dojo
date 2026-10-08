// ─────────────────────────────────────────────────────────────────────────────
// practica.dart — Práctica con audio (fase 5)
//
//   Palabra        → una palabra del vocabulario HSK (tabla c.palabras).
//   SilabaTono     → una sílaba grabada para el entrenador de tonos.
//   Preguntas      → cómo se arman las preguntas de opción múltiple.
//   SesionPalabras → qué palabra sigue en el repaso de vocabulario.
//   Estadísticas   → aciertos por ejercicio y qué tonos confundes.
//
// Todo lo que no toca la base ni la interfaz está aquí para poder probarlo.
// Las consultas están en repositorio_practica.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../helpers/pinyin_entrada.dart';
import 'audio.dart';
import 'modelos.dart';
import 'srs.dart';
import '../idioma.dart';

/// Valores de la columna `tipo` de la tabla ejercicios.
class TipoEjercicio {
  TipoEjercicio._();

  /// Entrenador de tonos con una sílaba ('ma3' → elegiste '2').
  static const tono = 'tono';

  /// Entrenador de tonos con palabras de dos sílabas ('ni3 hao3' → '2 3').
  static const tonosPalabra = 'tonos_palabra';

  /// Escucha: oír una palabra y elegir su carácter o su significado.
  static const escucha = 'escucha';

  /// Escribir el pinyin de una palabra.
  static const pinyin = 'pinyin';

  /// Repaso de vocabulario (resultado = q de SM-2).
  static const palabra = 'palabra';

  /// Preguntas de comprensión de Leer ('cuentos-para-ninos:2:1' → la opción
  /// elegida, en el orden de la base).
  static const comprension = 'comprension';

  static String nombre(String tipo) => switch (tipo) {
        tono => tr('Tonos (sílabas)'),
        tonosPalabra => tr('Tonos (palabras)'),
        escucha => tr('Escucha'),
        pinyin => tr('Pinyin'),
        palabra => tr('Vocabulario'),
        comprension => tr('Comprensión'),
        _ => tipo,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Palabra
// ═══════════════════════════════════════════════════════════════════════════

class Palabra {
  const Palabra({
    required this.id,
    required this.palabra,
    required this.forma,
    required this.pinyin,
    required this.pinyinNum,
    required this.clase,
    required this.nivelHsk,
    required this.significadoEs,
    required this.significadoEn,
    required this.audio,
    this.progreso,
  });

  final int id;

  /// La palabra en simplificado: "爸爸".
  final String palabra;

  /// Como viene en la lista oficial ("爸爸|爸", "有（一）些").
  final String forma;

  /// Pinyin con acentos, como en la lista oficial ("bàba").
  final String pinyin;

  /// Una sílaba por carácter, con número ("ba4 ba5"); "_" es el 儿 del erhua.
  final String pinyinNum;

  /// Categoría gramatical de la lista (N, V, Adj…) o ''.
  final String clase;

  /// 1-6, o 7 = niveles 7-9.
  final int nivelHsk;

  final String? significadoEs;
  final String significadoEn;

  /// ¿Hay grabación de la palabra completa?
  final bool audio;

  /// Tu avance con esta palabra (null si nunca la has repasado).
  final Progreso? progreso;

  factory Palabra.desdeFila(Map<String, Object?> f) => Palabra(
        id: f['id'] as int,
        palabra: f['palabra'] as String,
        forma: f['forma'] as String? ?? f['palabra'] as String,
        pinyin: f['pinyin'] as String,
        pinyinNum: f['pinyin_num'] as String,
        clase: f['clase'] as String? ?? '',
        nivelHsk: f['nivel_hsk'] as int,
        significadoEs: f['significado_es'] as String?,
        significadoEn: f['significado_en'] as String? ?? '',
        audio: (f['audio'] as int? ?? 0) == 1,
        progreso: Progreso.desdeFila(f),
      );

  List<String> get silabas => pinyinNum.split(' ');

  /// Claves de las sílabas que se pronuncian ('ba4', 'ba5'), sin el 儿 del
  /// erhua. Son las que se comparan en el ejercicio de pinyin.
  List<String> get claves => [
        for (final s in silabas)
          if (s != '_') Audio.claveSilaba(s) ?? s,
      ];

  /// Tono de cada sílaba que se pronuncia (5 = neutro).
  List<int> get tonos => [for (final c in claves) int.tryParse(c.substring(c.length - 1)) ?? 5];

  bool get tieneErhua => pinyinNum.contains('_');

  /// Una sílaba con acentos por carácter ('' en el 儿 del erhua), para que
  /// BotonVoz lea cada carácter con su lectura en esta palabra.
  List<String> get pinyinPorCaracter => [for (final s in silabas) PinyinEntrada.numAAcentos(s)];

  bool get tieneEspanol => significadoEs != null && significadoEs!.isNotEmpty;

  /// Significado a mostrar: en inglés con la interfaz en inglés (si lo hay);
  /// si no, español si existe y si no, inglés.
  String get significado =>
      (Idioma.ingles && significadoEn.isNotEmpty) || !tieneEspanol ? significadoEn : significadoEs!;

  /// ¿El significado está en el idioma de la interfaz? (Si no, se marca "EN".)
  bool get significadoEnIdioma => Idioma.ingles || tieneEspanol;

  String get nombreNivel => nombreDeNivel(nivelHsk);

  @override
  bool operator ==(Object other) => other is Palabra && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════════════════
// Entrenador de tonos
// ═══════════════════════════════════════════════════════════════════════════

/// Una sílaba grabada: se oye y hay que adivinar su tono.
class SilabaTono {
  const SilabaTono({
    required this.archivo,
    required this.tono,
    required this.caracter,
    required this.pinyin,
    required this.significado,
  });

  /// Nombre de la grabación en assets/audio/silabas ('ma3', 'jv4'…).
  final String archivo;

  /// 1 a 4.
  final int tono;

  /// Un carácter HSK que se lee así (para mostrarlo después de contestar).
  final String caracter;
  final String pinyin;
  final String significado;

  /// Caracteres (carácter, pinyin con número, pinyin con acentos, significado)
  /// → sílabas con grabación y tono 1-4. Sin repetir la misma sílaba.
  static List<SilabaTono> conGrabacion(
    Iterable<(String, String, String, String)> caracteres,
    Set<String> silabasGrabadas,
  ) {
    final vistas = <String>{};
    final salida = <SilabaTono>[];
    for (final (caracter, num, acentos, significado) in caracteres) {
      final clave = Audio.claveSilaba(num);
      if (clave == null) continue;
      final tono = int.tryParse(clave.substring(clave.length - 1)) ?? 5;
      if (tono < 1 || tono > 4) continue;
      // Con tono 1-4 la grabación que se encuentre es la de ese mismo sonido
      // (el respaldo a otro tono solo se usa para el tono neutro).
      final archivo = Audio.silabaDisponible(num, silabasGrabadas);
      if (archivo == null) continue;
      if (!vistas.add(clave)) continue;
      salida.add(SilabaTono(archivo: archivo, tono: tono, caracter: caracter, pinyin: acentos, significado: significado));
    }
    return salida;
  }

  /// Elige [n] sílabas repartiendo los cuatro tonos lo más parejo posible.
  static List<SilabaTono> equilibradas(List<SilabaTono> lista, int n, Random azar) {
    final porTono = <int, List<SilabaTono>>{};
    for (final s in lista) {
      porTono.putIfAbsent(s.tono, () => []).add(s);
    }
    for (final l in porTono.values) {
      l.shuffle(azar);
    }
    final salida = <SilabaTono>[];
    while (salida.length < n && porTono.values.any((l) => l.isNotEmpty)) {
      final tonos = porTono.keys.where((t) => porTono[t]!.isNotEmpty).toList()..shuffle(azar);
      for (final t in tonos) {
        if (salida.length >= n) break;
        salida.add(porTono[t]!.removeLast());
      }
    }
    salida.shuffle(azar);
    return salida;
  }
}

/// Nombre corto de cada tono, para los botones.
String nombreDeTono(int tono) => switch (tono) {
      1 => tr('alto y plano'),
      2 => tr('sube'),
      3 => tr('baja y sube'),
      4 => tr('baja'),
      _ => tr('neutro'),
    };

// ═══════════════════════════════════════════════════════════════════════════
// Preguntas de opción múltiple
// ═══════════════════════════════════════════════════════════════════════════

class PreguntaOpciones {
  const PreguntaOpciones(this.objetivo, this.opciones);

  final Palabra objetivo;
  final List<Palabra> opciones;

  int get correcta => opciones.indexOf(objetivo);

  /// Arma una pregunta de escucha: [objetivo] más 3 distractores de [otras].
  ///
  /// Nunca se usa como distractor una palabra que suene IGUAL (是 y 事 son
  /// "shì": con el audio no se pueden distinguir) ni, si se pregunta por el
  /// significado, una con el mismo significado. Se prefieren las del mismo
  /// largo (con 4 opciones de 2 caracteres no se adivina por el tamaño).
  static PreguntaOpciones armar(Palabra objetivo, List<Palabra> otras, Random azar,
      {bool porSignificado = false, int cantidad = 4}) {
    final sonido = objetivo.claves.join(' ');
    final candidatos = [
      for (final p in otras)
        if (p.id != objetivo.id &&
            p.palabra != objetivo.palabra &&
            p.claves.join(' ') != sonido &&
            (!porSignificado || p.significado != objetivo.significado))
          p,
    ]..shuffle(azar);
    candidatos.sort((a, b) =>
        (a.palabra.length - objetivo.palabra.length).abs() - (b.palabra.length - objetivo.palabra.length).abs());
    final elegidos = <Palabra>[];
    final textos = <String>{objetivo.palabra};
    final significados = <String>{objetivo.significado};
    for (final p in candidatos) {
      if (elegidos.length >= cantidad - 1) break;
      if (!textos.add(p.palabra)) continue;
      if (porSignificado && !significados.add(p.significado)) continue;
      elegidos.add(p);
    }
    final opciones = [objetivo, ...elegidos]..shuffle(azar);
    return PreguntaOpciones(objetivo, opciones);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Repaso de vocabulario
// ═══════════════════════════════════════════════════════════════════════════

/// De las palabras nuevas, la que tenga más caracteres que ya estudiaste
/// (en proporción); a igualdad, la primera de la lista oficial.
/// [candidatas]: (id, palabra) en el orden oficial.
int? elegirPalabraNueva(List<(int, String)> candidatas, Set<String> conocidos) {
  int? mejor;
  var mejorPuntos = -1.0;
  for (final (id, texto) in candidatas) {
    final runas = texto.runes.toList();
    if (runas.isEmpty) continue;
    final sabidos = runas.where((r) => conocidos.contains(String.fromCharCode(r))).length;
    final puntos = sabidos / runas.length;
    if (puntos > mejorPuntos) {
      mejorPuntos = puntos;
      mejor = id;
    }
  }
  return mejor;
}

/// Lo que la sesión de vocabulario necesita de la base de datos.
abstract class FuentePalabras {
  Future<Palabra?> siguientePalabra({required int nivel, required bool permitirNuevas, required Set<int> excluir});
  Future<Palabra?> palabra(int id);
  Future<void> registrarPalabra(Palabra p, Calificacion calificacion, {int duracionMs = 0});
  Future<int> nuevasPalabrasHoy();
  Future<int> limitePalabrasPorDia();
  Future<bool> quedanPalabrasNuevas(int nivel);
}

enum FinSesionPalabras { completo, limiteDiario }

/// Igual que SesionEstudio (sesion_estudio.dart), pero con palabras:
///   1. Lo calificado "Difícil" vuelve a salir tras unas tarjetas.
///   2. Repasos vencidos de cualquier nivel (tu vocabulario).
///   3. Palabras nuevas del nivel elegido, hasta el límite diario.
class SesionPalabras {
  SesionPalabras(this.fuente, this.nivel);

  final FuentePalabras fuente;
  final int nivel;

  static const tarjetasAntesDeReaprender = 3;

  bool ignorarLimite = false;
  int _mostradas = 0;
  int nuevas = 0;
  int repasadas = 0;
  final Map<int, int> _reaprender = {};
  FinSesionPalabras? fin;

  Future<Palabra?> siguiente() async {
    final listo = _reaprender.entries.where((e) => e.value <= _mostradas).map((e) => e.key).firstOrNull;
    if (listo != null) {
      _reaprender.remove(listo);
      return fuente.palabra(listo);
    }
    final permitirNuevas = ignorarLimite || await fuente.nuevasPalabrasHoy() < await fuente.limitePalabrasPorDia();
    final p = await fuente.siguientePalabra(
        nivel: nivel, permitirNuevas: permitirNuevas, excluir: _reaprender.keys.toSet());
    if (p != null) return p;
    if (_reaprender.isNotEmpty) {
      final id = _reaprender.keys.first;
      _reaprender.remove(id);
      return fuente.palabra(id);
    }
    fin = !permitirNuevas && await fuente.quedanPalabrasNuevas(nivel)
        ? FinSesionPalabras.limiteDiario
        : FinSesionPalabras.completo;
    return null;
  }

  Future<void> responder(Palabra p, Calificacion calificacion, {int duracionMs = 0}) async {
    if (p.progreso == null) {
      nuevas++;
    } else {
      repasadas++;
    }
    await fuente.registrarPalabra(p, calificacion, duracionMs: duracionMs);
    _mostradas++;
    if (!calificacion.aprobado) _reaprender[p.id] = _mostradas + tarjetasAntesDeReaprender;
  }

  void estudiarMas() {
    ignorarLimite = true;
    fin = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Estadísticas de la práctica
// ═══════════════════════════════════════════════════════════════════════════

/// Aciertos de un tipo de ejercicio en los últimos días.
class ResumenEjercicio {
  const ResumenEjercicio({required this.tipo, required this.total, required this.aciertos});

  final String tipo;
  final int total;
  final int aciertos;

  double? get precision => total == 0 ? null : aciertos / total;
}

/// Oíste el tono [esperado] y elegiste [elegido], [veces] veces.
class ConfusionTono {
  const ConfusionTono({required this.esperado, required this.elegido, required this.veces});

  final int esperado;
  final int elegido;
  final int veces;
}

/// A partir de los ejercicios de tonos (elemento 'ni3 hao3', respuesta '2 3'),
/// los pares de tonos que más confundes (de más a menos, al menos 2 veces).
List<ConfusionTono> confusionesDeTono(Iterable<(String, String)> filas, {int limite = 3}) {
  final veces = <(int, int), int>{};
  for (final (elemento, respuesta) in filas) {
    final esperados = [
      for (final s in elemento.split(' '))
        if (s.isNotEmpty) int.tryParse(s.substring(s.length - 1)) ?? 0,
    ];
    final elegidos = [for (final s in respuesta.split(' ')) if (s.isNotEmpty) int.tryParse(s) ?? 0];
    if (esperados.length != elegidos.length) continue;
    for (var k = 0; k < esperados.length; k++) {
      final e = esperados[k];
      final g = elegidos[k];
      if (e == g || e < 1 || e > 4 || g < 1 || g > 4) continue;
      veces[(e, g)] = (veces[(e, g)] ?? 0) + 1;
    }
  }
  final lista = [
    for (final MapEntry(key: (e, g), value: n) in veces.entries) ConfusionTono(esperado: e, elegido: g, veces: n),
  ]..sort((a, b) => b.veces - a.veces);
  return lista.where((c) => c.veces >= 2).take(limite).toList();
}

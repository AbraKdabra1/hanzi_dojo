// ─────────────────────────────────────────────────────────────────────────────
// oido.dart — Práctica de oído: qué preguntar (sin interfaz, para probarlo)
//
// Tres ejercicios con las grabaciones de la app (ver audio.dart):
//   · Tonos: suena una sílaba (p. ej. mǎ) y eliges su tono. Se usan solo
//     sílabas que existen con los cuatro tonos, y salen más las comunes.
//   · Escucha: suena un carácter y eliges cuál es entre cuatro. Las opciones
//     siempre suenan distinto (si no, sería adivinar entre homófonos): una
//     suele tener la misma sílaba con otro tono y otra el mismo tono con otra
//     sílaba, para que entrenes justo lo que confunde.
//   · Pinyin: ves un carácter y escribes cómo se lee ("hao3" o "hǎo").
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'audio.dart';
import 'modelos.dart';

enum EjercicioOido {
  tonos('tonos', 'Tonos'),
  escucha('escucha', 'Escucha'),
  pinyin('pinyin', 'Pinyin');

  const EjercicioOido(this.clave, this.nombre);

  /// Como se guarda en la tabla sesiones.
  final String clave;
  final String nombre;
}

/// "zhang3" → ('zhang', 3).
(String, int) partirClave(String clave) {
  final digito = clave.isEmpty ? '' : clave[clave.length - 1];
  final tono = int.tryParse(digito);
  if (tono == null) return (clave, 5);
  return (clave.substring(0, clave.length - 1), tono);
}

// ── Tonos ────────────────────────────────────────────────────────────────────

class PreguntaTono {
  const PreguntaTono(this.base, this.tono, this.opciones);

  /// Sílaba sin tono: 'ma'.
  final String base;

  /// Tono que suena (1-4).
  final int tono;

  /// Tonos entre los que se elige (ordenados).
  final List<int> opciones;

  /// Archivo de la sílaba que suena: 'ma3'.
  String get clave => '$base$tono';
}

class GeneradorTonos {
  /// [silabas]: las grabadas (silabas.txt). [frecuencia]: cuántos caracteres
  /// HSK usan cada sílaba sin tono (para que salgan más las comunes).
  GeneradorTonos({required Set<String> silabas, required Map<String, int> frecuencia, math.Random? azar})
      : _azar = azar ?? math.Random() {
    final tonosPorBase = <String, Set<int>>{};
    for (final s in silabas) {
      if (s.startsWith('_')) continue; // interjecciones (hm, ng…)
      final (base, tono) = partirClave(s);
      tonosPorBase.putIfAbsent(base, () => {}).add(tono);
    }
    for (final MapEntry(key: base, value: tonos) in tonosPorBase.entries) {
      if ([1, 2, 3, 4].every(tonos.contains)) {
        _bases.add(base);
        _pesos.add(1 + (frecuencia[base] ?? 0));
      }
    }
  }

  final math.Random _azar;
  final _bases = <String>[];
  final _pesos = <int>[];
  String? _anterior;

  /// Sílabas con los cuatro tonos grabados.
  List<String> get bases => List.unmodifiable(_bases);

  PreguntaTono siguiente(List<int> tonos) {
    final opciones = [...tonos]..sort();
    final total = _pesos.fold<int>(0, (a, b) => a + b);
    late String base;
    late int tono;
    for (var intento = 0; intento < 8; intento++) {
      var r = _azar.nextInt(total);
      var i = 0;
      while (r >= _pesos[i]) {
        r -= _pesos[i];
        i++;
      }
      base = _bases[i];
      tono = opciones[_azar.nextInt(opciones.length)];
      if ('$base$tono' != _anterior) break;
    }
    _anterior = '$base$tono';
    return PreguntaTono(base, tono, opciones);
  }
}

// ── Escucha ─────────────────────────────────────────────────────────────────

class PreguntaEscucha {
  const PreguntaEscucha(this.correcto, this.opciones, this.silaba);

  final Caracter correcto;

  /// Cuatro caracteres (incluye el correcto), en orden aleatorio.
  final List<Caracter> opciones;

  /// Grabación que suena: 'ma3'.
  final String silaba;
}

class GeneradorEscucha {
  GeneradorEscucha({required List<Caracter> candidatos, required Set<String> silabas, math.Random? azar})
      : _azar = azar ?? math.Random() {
    for (final c in candidatos) {
      final s = Audio.silabaDisponible(c.pinyinNum, silabas);
      if (s != null && !s.startsWith('_')) _con.add((c, s));
    }
  }

  final math.Random _azar;
  final _con = <(Caracter, String)>[];
  final _recientes = <int>[];

  /// ¿Hay suficientes caracteres para preguntar?
  bool get alcanza => _con.map((e) => e.$2).toSet().length >= 4;

  PreguntaEscucha siguiente() {
    // El correcto: uno que no haya salido hace poco.
    (Caracter, String) correcto;
    var intentos = 0;
    do {
      correcto = _con[_azar.nextInt(_con.length)];
      intentos++;
    } while (_recientes.contains(correcto.$1.id) && intentos < 20);
    _recientes.add(correcto.$1.id);
    if (_recientes.length > 12) _recientes.removeAt(0);

    final (base, tono) = partirClave(correcto.$2);
    final usadas = {correcto.$2};
    final opciones = <Caracter>[correcto.$1];

    void agregarDe(Iterable<(Caracter, String)> grupo) {
      final lista = grupo.where((e) => !usadas.contains(e.$2)).toList();
      if (lista.isEmpty || opciones.length >= 4) return;
      final e = lista[_azar.nextInt(lista.length)];
      usadas.add(e.$2);
      opciones.add(e.$1);
    }

    // Misma sílaba con otro tono (mā / mà) y mismo tono con otra sílaba.
    agregarDe(_con.where((e) => partirClave(e.$2).$1 == base));
    agregarDe(_con.where((e) => partirClave(e.$2).$2 == tono));
    for (var i = 0; i < 50 && opciones.length < 4; i++) {
      agregarDe(_con);
    }
    opciones.shuffle(_azar);
    return PreguntaEscucha(correcto.$1, opciones, correcto.$2);
  }
}

// ── Pinyin ───────────────────────────────────────────────────────────────────

enum ResultadoPinyin {
  correcto,

  /// La sílaba está bien pero el tono no (o faltó).
  tonoEquivocado,
  incorrecto,
}

/// Revisa lo que escribiste para [c]. Acepta número ("hao3"), acentos ("hǎo")
/// y cualquiera de sus lecturas oficiales; el tono neutro puede ir sin número.
ResultadoPinyin revisarPinyin(String respuesta, Caracter c) {
  final escrita = Audio.claveSilaba(respuesta.replaceAll(RegExp(r'\s'), ''));
  if (escrita == null) return ResultadoPinyin.incorrecto;
  final lecturas = [
    c.pinyinNum,
    for (final l in c.otrasLecturas.split(RegExp(r'[\s,;/]+')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  var casi = false;
  for (final l in lecturas) {
    final clave = Audio.claveSilaba(l);
    if (clave == null) continue;
    if (clave == escrita) return ResultadoPinyin.correcto;
    if (partirClave(clave).$1 == partirClave(escrita).$1) casi = true;
  }
  return casi ? ResultadoPinyin.tonoEquivocado : ResultadoPinyin.incorrecto;
}

// ─────────────────────────────────────────────────────────────────────────────
// respaldo.dart — Exportar e importar tu progreso
//
// Para qué: el progreso vive solo en el teléfono. En teléfonos sin servicios
// de Google (como los Huawei recientes) el respaldo automático de Android no
// existe, así que si cambias de teléfono o lo reinicias, se perdería. Con
// "Exportar progreso" te llevas un archivo y con "Importar" lo recuperas.
//
// El archivo .hanzidojo es un JSON comprimido con gzip:
//
//   {
//     "formato":   "hanzi-dojo-respaldo",
//     "version":   1,
//     "creado":    "2026-09-30T21:40:00.000",
//     "progreso":  [ {"caracter": "好", "intervalo": 6, "factor": 2.5, …}, … ],
//     "historial": [ {"caracter": "好", "momento": 1790000000, …}, … ],
//     "lectura":   [ {"libro": "cuentos-para-ninos", "capitulo": 1, "momento": …}, … ],
//     "progreso_palabras": [ {"palabra": "爸爸", "intervalo": 6, …}, … ],
//     "ejercicios": [ {"tipo": "tono", "elemento": "ma3", "resultado": 1, …}, … ],
//     "logros":    [ {"clave": "racha_7", "momento": …}, … ],
//     "protecciones": [ {"dia": "2026-10-04", "momento": …}, … ],
//     "ajustes":   { "nuevos_por_dia": "15", … }
//   }
//
// Todo se guarda por CARÁCTER (no por número de fila), así que un respaldo
// sirve aunque cambie el contenido de la app. Es un formato abierto:
// cualquiera puede descomprimirlo (gunzip) y leerlo.
//
// Importar REEMPLAZA tu progreso actual. Antes se guarda una copia de lo que
// tenías (respaldo_previo.hanzidojo) para poder deshacerlo.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show GZipDecoder, GZipEncoder;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../plataforma/almacen.dart';
import 'base_datos.dart';
import '../idioma.dart';

/// El archivo no es un respaldo válido (el mensaje se muestra al usuario).
class RespaldoInvalido implements Exception {
  const RespaldoInvalido(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Contenido de un respaldo ya leído y revisado.
class DatosRespaldo {
  const DatosRespaldo({
    required this.creado,
    required this.progreso,
    required this.historial,
    this.lectura = const [],
    this.progresoPalabras = const [],
    this.ejercicios = const [],
    this.logros = const [],
    this.protecciones = const [],
    required this.ajustes,
  });

  final DateTime? creado;
  final List<Map<String, Object>> progreso;
  final List<Map<String, Object>> historial;

  /// Capítulos leídos en «Leer».
  final List<Map<String, Object>> lectura;

  /// Repaso del vocabulario y respuestas de los ejercicios con audio.
  final List<Map<String, Object>> progresoPalabras;
  final List<Map<String, Object>> ejercicios;

  /// Logros desbloqueados y días cubiertos por el protector de racha.
  final List<Map<String, Object>> logros;
  final List<Map<String, Object>> protecciones;
  final Map<String, String> ajustes;

  int get caracteres => progreso.length;
  int get repasos => historial.length;
}

enum _Tipo { texto, entero, real }

class Respaldo {
  Respaldo._();

  static const formato = 'hanzi-dojo-respaldo';
  static const version = 1;
  static const extension = 'hanzidojo';

  /// Copia de lo que había antes de la última importación.
  static const archivoPrevio = 'respaldo_previo.$extension';

  /// Ajustes propios de esta instalación: no viajan en el respaldo.
  static const _ajustesLocales = {'version_contenido'};

  /// Archivos más grandes que esto no se intentan leer.
  static const tamanoMaximo = 50 * 1024 * 1024;

  static const _columnasProgreso = {
    'caracter': _Tipo.texto,
    'intervalo': _Tipo.entero,
    'factor': _Tipo.real,
    'aciertos_seguidos': _Tipo.entero,
    'veces_visto': _Tipo.entero,
    'proximo_repaso': _Tipo.entero,
    'primera_vez': _Tipo.entero,
    'ultima_vez': _Tipo.entero,
  };

  static const _columnasHistorial = {
    'caracter': _Tipo.texto,
    'momento': _Tipo.entero,
    'duracion_ms': _Tipo.entero,
    'calificacion': _Tipo.entero,
    'errores': _Tipo.entero,
    'al_reves': _Tipo.entero,
    'fallos': _Tipo.texto,
    'modo_novato': _Tipo.entero,
    'nuevo': _Tipo.entero,
    'intervalo': _Tipo.entero,
  };

  static const _columnasProgresoPalabras = {
    'palabra': _Tipo.texto,
    'intervalo': _Tipo.entero,
    'factor': _Tipo.real,
    'aciertos_seguidos': _Tipo.entero,
    'veces_visto': _Tipo.entero,
    'proximo_repaso': _Tipo.entero,
    'primera_vez': _Tipo.entero,
    'ultima_vez': _Tipo.entero,
  };

  static const _columnasEjercicios = {
    'tipo': _Tipo.texto,
    'elemento': _Tipo.texto,
    'momento': _Tipo.entero,
    'resultado': _Tipo.entero,
    'respuesta': _Tipo.texto,
    'duracion_ms': _Tipo.entero,
  };

  static const _columnasLogros = {
    'clave': _Tipo.texto,
    'momento': _Tipo.entero,
  };

  static const _columnasProtecciones = {
    'dia': _Tipo.texto,
    'momento': _Tipo.entero,
  };

  static const _columnasLectura = {
    'libro': _Tipo.texto,
    'capitulo': _Tipo.entero,
    'momento': _Tipo.entero,
  };

  /// Nombre sugerido para el archivo: hanzi_dojo_2026-09-30.hanzidojo
  static String nombreSugerido(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'hanzi_dojo_${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}.$extension';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Exportar
  // ═══════════════════════════════════════════════════════════════════════

  /// Todo tu progreso como bytes de un archivo .hanzidojo.
  static Future<Uint8List> exportar(Database db, {DateTime? ahora}) async {
    final progreso = await db.rawQuery(
        'SELECT ${_columnasProgreso.keys.join(', ')} FROM progreso ORDER BY caracter');
    final historial = await db.rawQuery(
        'SELECT ${_columnasHistorial.keys.join(', ')} FROM historial ORDER BY momento, id');
    final lectura = await db.rawQuery(
        'SELECT ${_columnasLectura.keys.join(', ')} FROM lectura ORDER BY libro, capitulo');
    final progresoPalabras = await db.rawQuery(
        'SELECT ${_columnasProgresoPalabras.keys.join(', ')} FROM progreso_palabras ORDER BY palabra');
    final ejercicios = await db.rawQuery(
        'SELECT ${_columnasEjercicios.keys.join(', ')} FROM ejercicios ORDER BY momento, id');
    final logros = await db.rawQuery('SELECT clave, momento FROM logros ORDER BY momento, clave');
    final protecciones = await db.rawQuery('SELECT dia, momento FROM protecciones ORDER BY dia');
    final ajustes = await db.rawQuery('SELECT clave, valor FROM ajustes ORDER BY clave');
    final json = <String, Object?>{
      'formato': formato,
      'version': version,
      'creado': (ahora ?? DateTime.now()).toIso8601String(),
      'progreso': progreso,
      'historial': historial,
      'lectura': lectura,
      'progreso_palabras': progresoPalabras,
      'ejercicios': ejercicios,
      'logros': logros,
      'protecciones': protecciones,
      'ajustes': {
        for (final f in ajustes)
          if (!_ajustesLocales.contains(f['clave'])) f['clave'] as String: f['valor'] as String,
      },
    };
    return Uint8List.fromList(GZipEncoder().encodeBytes(utf8.encode(jsonEncode(json))));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Leer y revisar
  // ═══════════════════════════════════════════════════════════════════════

  /// Lee un archivo .hanzidojo y revisa que todo esté en orden ANTES de
  /// tocar la base. Lanza [RespaldoInvalido] con un mensaje para el usuario.
  static DatosRespaldo leer(Uint8List bytes) {
    if (bytes.length > tamanoMaximo) {
      throw RespaldoInvalido(tr('El archivo es demasiado grande para ser un respaldo.'));
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes)));
    } catch (_) {
      throw RespaldoInvalido(tr('Este archivo no es un respaldo de Hanzi Dojo.'));
    }
    if (json is! Map<String, Object?> || json['formato'] != formato) {
      throw RespaldoInvalido(tr('Este archivo no es un respaldo de Hanzi Dojo.'));
    }
    final v = json['version'];
    if (v is! int || v < 1) {
      throw RespaldoInvalido(tr('El respaldo está dañado (versión desconocida).'));
    }
    if (v > version) {
      throw RespaldoInvalido(
          tr('Este respaldo viene de una versión más nueva de Hanzi Dojo. Actualiza la app para importarlo.'));
    }

    final ajustes = <String, String>{};
    final crudos = json['ajustes'] ?? const <String, Object?>{};
    if (crudos is! Map<String, Object?>) {
      throw RespaldoInvalido(tr('El respaldo está dañado (ajustes).'));
    }
    for (final MapEntry(:key, :value) in crudos.entries) {
      if (value is! String) throw RespaldoInvalido(tr('El respaldo está dañado (ajustes).'));
      if (!_ajustesLocales.contains(key)) ajustes[key] = value;
    }

    return DatosRespaldo(
      creado: switch (json['creado']) { final String t => DateTime.tryParse(t), _ => null },
      progreso: _filas(json['progreso'], _columnasProgreso, 'progreso'),
      historial: _filas(json['historial'] ?? const [], _columnasHistorial, 'historial'),
      lectura: _filas(json['lectura'] ?? const [], _columnasLectura, 'lectura'),
      progresoPalabras:
          _filas(json['progreso_palabras'] ?? const [], _columnasProgresoPalabras, 'vocabulario'),
      ejercicios: _filas(json['ejercicios'] ?? const [], _columnasEjercicios, 'ejercicios'),
      logros: _filas(json['logros'] ?? const [], _columnasLogros, 'logros'),
      protecciones: _filas(json['protecciones'] ?? const [], _columnasProtecciones, 'protecciones'),
      ajustes: ajustes,
    );
  }

  static List<Map<String, Object>> _filas(Object? lista, Map<String, _Tipo> columnas, String que) {
    final error = RespaldoInvalido(tr('El respaldo está dañado ({0}).', [tr(que)]));
    if (lista is! List) throw error;
    return [
      for (final fila in lista)
        if (fila is Map<String, Object?>)
          {for (final MapEntry(key: col, value: tipo) in columnas.entries) col: _valor(fila[col], tipo, error)}
        else
          throw error,
    ];
  }

  static Object _valor(Object? v, _Tipo tipo, RespaldoInvalido error) => switch (tipo) {
        _Tipo.texto when v is String => v,
        _Tipo.entero when v is int => v,
        // Otro programa pudo escribir 6.0 en vez de 6.
        _Tipo.entero when v is double && v == v.roundToDouble() => v.toInt(),
        _Tipo.real when v is num => v.toDouble(),
        _ => throw error,
      };

  // ═══════════════════════════════════════════════════════════════════════
  // Importar y deshacer
  // ═══════════════════════════════════════════════════════════════════════

  static String _previo(BaseDatos base) => p.join(base.carpeta, archivoPrevio);

  /// Reemplaza tu progreso por el de [datos]. Antes guarda una copia de lo
  /// que había, para [deshacerImportacion].
  static Future<void> importar(BaseDatos base, DatosRespaldo datos) async {
    final copia = await exportar(base.db);
    await Almacen.escribir(_previo(base), copia);
    await _reemplazar(base.db, datos);
  }

  /// ¿Hay una importación que se pueda deshacer?
  static Future<bool> hayRespaldoPrevio(BaseDatos base) => Almacen.existe(_previo(base));

  /// Regresa al progreso que tenías antes de la última importación.
  static Future<void> deshacerImportacion(BaseDatos base) async {
    final previo = _previo(base);
    final datos = leer((await Almacen.leer(previo)) ?? Uint8List(0));
    await _reemplazar(base.db, datos);
    await Almacen.borrar(previo);
  }

  /// Todo en una transacción: si algo falla, tu progreso queda como estaba.
  static Future<void> _reemplazar(Database db, DatosRespaldo datos) async {
    await db.transaction((txn) async {
      await txn.delete('progreso');
      await txn.delete('historial');
      await txn.delete('lectura');
      await txn.delete('progreso_palabras');
      await txn.delete('ejercicios');
      await txn.delete('logros');
      await txn.delete('protecciones');
      final locales = _ajustesLocales.map((_) => '?').join(', ');
      await txn.rawDelete('DELETE FROM ajustes WHERE clave NOT IN ($locales)', _ajustesLocales.toList());

      final lote = txn.batch();
      for (final fila in datos.progreso) {
        lote.insert('progreso', fila, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final fila in datos.historial) {
        lote.insert('historial', fila);
      }
      for (final fila in datos.lectura) {
        lote.insert('lectura', fila, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final fila in datos.progresoPalabras) {
        lote.insert('progreso_palabras', fila, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final fila in datos.ejercicios) {
        lote.insert('ejercicios', fila);
      }
      for (final fila in datos.logros) {
        lote.insert('logros', fila, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final fila in datos.protecciones) {
        lote.insert('protecciones', fila, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final MapEntry(:key, :value) in datos.ajustes.entries) {
        lote.insert('ajustes', {'clave': key, 'valor': value}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await lote.commit(noResult: true);
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

// =========================================================================
// 1. CONFIGURACIÓN E INICIALIZACIÓN (Singleton)
// =========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hanzi_dojo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,                  // ← subimos de 2 a 3
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Migración incremental ─────────────────────────────────────────────────
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2 → v3: agregar columnas de radical
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE caracteres ADD COLUMN es_radical INTEGER DEFAULT 0'
      );
      await db.execute(
        'ALTER TABLE caracteres ADD COLUMN numero_radical INTEGER DEFAULT 0'
      );
      debugPrint("✅ Migración v3: columnas es_radical y numero_radical agregadas.");
    }
  }

  // ── Creación inicial (instalaciones nuevas) ───────────────────────────────
  Future _createDB(Database db, int version) async {
    const idType   = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType  = 'INTEGER DEFAULT 0';

    await db.execute('''
    CREATE TABLE caracteres (
      id               $idType,
      simplificado     $textType,
      tradicional      $textType,
      pinyin           $textType,
      significados     TEXT,
      trazos           TEXT,
      medianas         TEXT,
      nivel            $intType,
      srs_interval     $intType,
      e_factor         REAL DEFAULT 2.5,
      proximo_repaso   $intType,
      veces_visto      $intType,
      aciertos_seguidos $intType,
      audio_metodo     TEXT,
      audio_ruta       TEXT,
      es_radical       $intType,
      numero_radical   $intType
    )
    ''');

    await db.execute('''
    CREATE TABLE ejemplos (
      id           $idType,
      caracter_id  INTEGER,
      palabra      $textType,
      pinyin       $textType,
      significado  $textType,
      FOREIGN KEY (caracter_id) REFERENCES caracteres (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE vocabulario (
      id          $idType,
      hanzi_simp  $textType,
      palabra     $textType,
      tradicional TEXT,
      pinyin      TEXT,
      definicion  TEXT,
      FOREIGN KEY (hanzi_simp) REFERENCES caracteres (simplificado) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE oraciones (
      id           $idType,
      hanzi_simp   $textType,
      oracion_simp $textType,
      oracion_trad TEXT,
      pinyin       TEXT,
      traduccion   TEXT,
      FOREIGN KEY (hanzi_simp) REFERENCES caracteres (simplificado) ON DELETE CASCADE
    )
    ''');
  }

// =========================================================================
// 2. INYECCIÓN MASIVA DE DATOS
// =========================================================================
  Future<void> poblarBaseDeDatos() async {
    final db = await instance.database;
    final conteo = await db.rawQuery('SELECT COUNT(*) FROM caracteres');
    final int? n = Sqflite.firstIntValue(conteo);
    if (n != null && n > 0) return;

    debugPrint("📖 Leyendo JSON desde assets...");
    final String respuesta = await rootBundle
        .loadString('assets/diccionario_supercargado_completo.json');
    final List<dynamic> datos = json.decode(respuesta);

    debugPrint("💾 Iniciando inyección masiva en SQLite...");
    final Batch batch = db.batch();

    for (var item in datos) {
      final String significadosUnidos = item['significados'] != null
          ? (item['significados'] as List).join(', ')
          : '';
      final String trazosStr   = jsonEncode(item['strokes']  ?? []);
      final String medianasStr = jsonEncode(item['medians']  ?? []);

      final int nivelAsignado = item['hsk_nivel_oficial'] != null
          ? int.tryParse(item['hsk_nivel_oficial'].toString()) ?? 10
          : (item['nivel'] ?? 10);

      // ── Campos nuevos de radical ─────────────────────────────────────────
      final int esRadical      = (item['es_radical'] == true) ? 1 : 0;
      final int numeroRadical  = item['numero_radical'] ?? 0;

      batch.insert('caracteres', {
        'simplificado'  : item['simplificado'],
        'tradicional'   : item['tradicional']  ?? '',
        'pinyin'        : item['pinyin']        ?? '',
        'significados'  : significadosUnidos,
        'trazos'        : trazosStr,
        'medianas'      : medianasStr,
        'nivel'         : nivelAsignado,
        'audio_metodo'  : item['audio_config']?['metodo']              ?? 'tts',
        'audio_ruta'    : item['audio_config']?['ruta_futura_local']   ?? '',
        'es_radical'    : esRadical,
        'numero_radical': numeroRadical,
      });

      // ── Vocabulario relacionado ──────────────────────────────────────────
      if (item['vocabulario_relacionado'] != null) {
        for (var v in item['vocabulario_relacionado']) {
          batch.insert('vocabulario', {
            'hanzi_simp' : item['simplificado'],
            'palabra'    : v['palabra']           ?? '',
            'tradicional': v['tradicional']        ?? '',
            'pinyin'     : v['pinyin']             ?? '',
            'definicion' : v['definicion_ingles']  ?? '',
          });
        }
      }

      // ── Oraciones de ejemplo ─────────────────────────────────────────────
      if (item['oraciones_ejemplo'] != null) {
        for (var o in item['oraciones_ejemplo']) {
          batch.insert('oraciones', {
            'hanzi_simp'  : item['simplificado'],
            'oracion_simp': o['oracion_simp']        ?? '',
            'oracion_trad': o['oracion_trad']        ?? '',
            'pinyin'      : o['pinyin']              ?? '',
            'traduccion'  : o['traduccion_ingles']   ?? '',
          });
        }
      }
    }

    await batch.commit(noResult: true);
    debugPrint("✅ Base de datos poblada exitosamente.");
  }

// =========================================================================
// 3. MOTOR SRS — SM-2 COMPLETO
// Implementa el algoritmo SM-2 de Anki usando e_factor y srs_interval.
// =========================================================================
  Future<void> actualizarProgresoSRS(int id, int calificacion) async {
    // calificacion: 0=Difícil, 3=Medio, 5=Fácil  (escala SM-2)
    final db = await instance.database;

    final List<Map> rows = await db.query(
      'caracteres',
      columns: ['srs_interval', 'e_factor', 'aciertos_seguidos'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;

    int    intervalo        = rows.first['srs_interval']      as int;
    double eFactor          = rows.first['e_factor']           as double;
    int    aciertrosSeguidos = rows.first['aciertos_seguidos'] as int;

    // ── Algoritmo SM-2 ────────────────────────────────────────────────────
    if (calificacion < 3) {
      // Respuesta incorrecta: reiniciar
      intervalo         = 1;
      aciertrosSeguidos = 0;
    } else {
      // Respuesta correcta
      if (aciertrosSeguidos == 0) {
        intervalo = 1;
      } else if (aciertrosSeguidos == 1) {
        intervalo = 6;
      } else {
        intervalo = (intervalo * eFactor).round();
      }
      aciertrosSeguidos++;
    }

    // Actualizar e_factor (mínimo 1.3)
    eFactor = (eFactor + 0.1 - (5 - calificacion) * (0.08 + (5 - calificacion) * 0.02))
        .clamp(1.3, 2.5);

    final int timestampProximo = DateTime.now()
        .add(Duration(days: intervalo))
        .millisecondsSinceEpoch ~/ 1000;

    await db.update(
      'caracteres',
      {
        'srs_interval'     : intervalo,
        'e_factor'         : eFactor,
        'aciertos_seguidos': aciertrosSeguidos,
        'veces_visto'      : rows.first['veces_visto'] ?? 0 + 1,
        'proximo_repaso'   : timestampProximo,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// =========================================================================
// 4. CONSULTAS DE ESTUDIO — POR NIVEL HSK
// =========================================================================
  Future<Map<String, dynamic>?> obtenerSiguienteHanziParaEstudiar(
      int nivelHSK) async {
    final db = await instance.database;
    final int ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // A. Repasos vencidos
    final vencidos = await db.query(
      'caracteres',
      where: 'proximo_repaso <= ? AND veces_visto > 0 AND nivel = ?',
      whereArgs: [ahora, nivelHSK],
      orderBy: 'proximo_repaso ASC',
      limit: 1,
    );
    if (vencidos.isNotEmpty) return vencidos.first;

    // B. Tarjetas nuevas
    final nuevas = await db.query(
      'caracteres',
      where: 'veces_visto = 0 AND nivel = ?',
      whereArgs: [nivelHSK],
      orderBy: 'RANDOM()',
      limit: 1,
    );
    if (nuevas.isNotEmpty) return nuevas.first;

    return null;
  }

// =========================================================================
// 5. CONSULTAS DE ESTUDIO — POR RADICAL
// =========================================================================
  Future<Map<String, dynamic>?> obtenerSiguienteRadicalParaEstudiar() async {
    final db = await instance.database;
    final int ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // A. Repasos vencidos de radicales
    final vencidos = await db.query(
      'caracteres',
      where: 'proximo_repaso <= ? AND veces_visto > 0 AND es_radical = 1',
      whereArgs: [ahora],
      orderBy: 'numero_radical ASC',
      limit: 1,
    );
    if (vencidos.isNotEmpty) return vencidos.first;

    // B. Radicales nuevos (en orden de número Kangxi)
    final nuevos = await db.query(
      'caracteres',
      where: 'veces_visto = 0 AND es_radical = 1',
      whereArgs: [],
      orderBy: 'numero_radical ASC',
      limit: 1,
    );
    if (nuevos.isNotEmpty) return nuevos.first;

    return null;
  }

// =========================================================================
// 6. LISTA DE TODOS LOS RADICALES (para pantalla de selección)
// =========================================================================
  Future<List<Map<String, dynamic>>> obtenerTodosLosRadicales() async {
    final db = await instance.database;
    return await db.query(
      'caracteres',
      where: 'es_radical = 1',
      orderBy: 'numero_radical ASC',
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
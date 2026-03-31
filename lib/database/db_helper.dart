import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

// =========================================================================
// 1. CONFIGURACIÓN E INICIALIZACIÓN (Singleton)
// Maneja la creación de la base de datos y la estructura de las tablas.
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
    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER DEFAULT 0';

    // Tabla Principal (Caracteres)
    await db.execute('''
    CREATE TABLE caracteres (
      id $idType,
      simplificado $textType,
      tradicional $textType,
      pinyin $textType,
      significados TEXT,
      trazos TEXT,
      medianas TEXT,
      nivel $intType,
      srs_interval $intType,
      e_factor REAL DEFAULT 2.5,
      proximo_repaso $intType,
      veces_visto $intType,
      aciertos_seguidos $intType,
      audio_metodo TEXT,
      audio_ruta TEXT
    )
    ''');

    // Tabla de Ejemplos (Relacionada a la tabla caracteres)
    await db.execute('''
    CREATE TABLE ejemplos (
      id $idType,
      caracter_id INTEGER,
      palabra $textType,
      pinyin $textType,
      significado $textType,
      FOREIGN KEY (caracter_id) REFERENCES caracteres (id) ON DELETE CASCADE
    )
    ''');
  // Tabla de Vocabulario Cruzado
    await db.execute('''
    CREATE TABLE vocabulario (
      id $idType,
      hanzi_simp $textType,
      palabra $textType,
      tradicional TEXT,
      pinyin TEXT,
      definicion TEXT,
      FOREIGN KEY (hanzi_simp) REFERENCES caracteres (simplificado) ON DELETE CASCADE
    )
    ''');

    // Tabla de Oraciones Reales
    await db.execute('''
    CREATE TABLE oraciones (
      id $idType,
      hanzi_simp $textType,
      oracion_simp $textType,
      oracion_trad TEXT,
      pinyin TEXT,
      traduccion TEXT,
      FOREIGN KEY (hanzi_simp) REFERENCES caracteres (simplificado) ON DELETE CASCADE
    )
    ''');
  }

// =========================================================================
// 2. INYECCIÓN MASIVA DE DATOS (Población Inicial)
// Lee el archivo JSON y carga los miles de caracteres en la primera apertura.
// =========================================================================
  Future<void> poblarBaseDeDatos() async {
    final db = await instance.database;
    var conteo = await db.rawQuery('SELECT COUNT(*) FROM caracteres');
    int? numeroDeCaracteres = Sqflite.firstIntValue(conteo);
    
    if (numeroDeCaracteres != null && numeroDeCaracteres > 0) return;

    debugPrint("Leyendo el archivo JSON supercargado desde los assets...");
    // Asegúrate de que el nombre coincida con tu nuevo archivo maestro
    final String respuesta = await rootBundle.loadString('assets/diccionario_supercargado_completo.json');
    final List<dynamic> datos = json.decode(respuesta);

    debugPrint("Iniciando la inyección masiva en SQLite...");
    Batch batch = db.batch();

    for (var item in datos) {
      String significadosUnidos = item['significados'] != null ? item['significados'].join(', ') : '';
      String trazosStr = jsonEncode(item['strokes'] ?? []);
      String medianasStr = jsonEncode(item['medians'] ?? []);
      
      // Tomamos el nivel oficial del HSK 3.0, o el genérico si falla
      int nivelAsignado = item['hsk_nivel_oficial'] != null 
          ? int.tryParse(item['hsk_nivel_oficial'].toString()) ?? 10 
          : (item['nivel'] ?? 10);

      // ==========================================
      // PASO 4: Inserción Principal (Actualizada)
      // ==========================================
      batch.insert('caracteres', {
        'simplificado': item['simplificado'],
        'tradicional': item['tradicional'] ?? '',
        'pinyin': item['pinyin'] ?? '',
        'significados': significadosUnidos,
        'trazos': trazosStr,
        'medianas': medianasStr,
        'nivel': nivelAsignado,
        'audio_metodo': item['audio_config']?['metodo'] ?? 'tts',
        'audio_ruta': item['audio_config']?['ruta_futura_local'] ?? '',
      });

      // ==========================================
      // PASO 5: Inserción de Tablas Relacionadas
      // ==========================================
      
      // A. Insertar Vocabulario Relacionado
      if (item['vocabulario_relacionado'] != null) {
        for (var v in item['vocabulario_relacionado']) {
          batch.insert('vocabulario', {
            'hanzi_simp': item['simplificado'], // Usamos el carácter para relacionarlo
            'palabra': v['palabra'] ?? '',
            'tradicional': v['tradicional'] ?? '',
            'pinyin': v['pinyin'] ?? '',
            'definicion': v['definicion_ingles'] ?? '',
          });
        }
      }

      // B. Insertar Oraciones de Ejemplo
      if (item['oraciones_ejemplo'] != null) {
        for (var o in item['oraciones_ejemplo']) {
          batch.insert('oraciones', {
            'hanzi_simp': item['simplificado'], // Usamos el carácter para relacionarlo
            'oracion_simp': o['oracion_simp'] ?? '',
            'oracion_trad': o['oracion_trad'] ?? '',
            'pinyin': o['pinyin'] ?? '',
            'traduccion': o['traduccion_ingles'] ?? '',
          });
        }
      }
    } // Fin del ciclo for

    await batch.commit(noResult: true);
    debugPrint("¡Base de datos poblada con éxito con HSK 3.0, Vocabulario y Oraciones!");
  }

// =========================================================================
// 3. ACTUALIZACIÓN DE PROGRESO (Motor SRS)
// Lógica que calcula y guarda los tiempos para el siguiente repaso.
// =========================================================================
  Future<void> actualizarProgresoSRS(int id, int minutosParaElSiguienteRepaso) async {
    final db = await instance.database;
    final DateTime ahora = DateTime.now();
    final DateTime tiempoProximo = ahora.add(Duration(minutes: minutosParaElSiguienteRepaso));
    final int timestampProximo = tiempoProximo.millisecondsSinceEpoch ~/ 1000;
    
    await db.rawUpdate(
      'UPDATE caracteres SET veces_visto = veces_visto + 1, proximo_repaso = ? WHERE id = ?',
      [timestampProximo, id]
    );
  }

// =========================================================================
// 4. CONSULTAS DE ESTUDIO (Lectura)
// Extrae el siguiente Hanzi a estudiar basado en urgencia y nivel.
// =========================================================================
  Future<Map<String, dynamic>?> obtenerSiguienteHanziParaEstudiar(int nivelHSK) async {
    final db = await instance.database;
    final int ahoraTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // A. Buscamos repasos vencidos estrictamente de ESE nivel
    final List<Map<String, dynamic>> repasosVencidos = await db.query(
      'caracteres',
      where: 'proximo_repaso <= ? AND veces_visto > 0 AND nivel = ?',
      whereArgs: [ahoraTimestamp, nivelHSK],
      orderBy: 'proximo_repaso ASC',
      limit: 1,
    );
    
    if (repasosVencidos.isNotEmpty) {
      return repasosVencidos.first;
    }

    // B. Si no hay repasos urgentes, buscamos tarjetas nuevas de ESE nivel
    final List<Map<String, dynamic>> tarjetasNuevas = await db.query(
      'caracteres',
      where: 'veces_visto = 0 AND nivel = ?',
      whereArgs: [nivelHSK],
      orderBy: 'RANDOM()', 
      limit: 1,
    );
    
    if (tarjetasNuevas.isNotEmpty) {
      return tarjetasNuevas.first;
    }

    return null; // Si ya se aprendió todo ese nivel, devuelve null
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
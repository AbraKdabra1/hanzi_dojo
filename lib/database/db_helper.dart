import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; 

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
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 1. LOS ESTANTES (Con las columnas de SRS y Vectores)
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER DEFAULT 0'; 

    await db.execute('''
    CREATE TABLE caracteres (
      id $idType,
      simplificado $textType,
      tradicional $textType,
      pinyin $textType,
      significados $textType,
      nivel $intType,
      veces_visto $intType,
      proximo_repaso $intType,
      trazos $textType,
      medianas $textType
    )
    ''');
  }

  // 2. INYECCIÓN MASIVA
  Future<void> poblarBaseDeDatos() async {
    final db = await instance.database;
    var conteo = await db.rawQuery('SELECT COUNT(*) FROM caracteres');
    int? numeroDeCaracteres = Sqflite.firstIntValue(conteo);

    if (numeroDeCaracteres != null && numeroDeCaracteres > 0) return;

    debugPrint("Leyendo el archivo JSON supercargado desde los assets...");
    final String respuesta = await rootBundle.loadString('assets/diccionario_supercargado.json');
    final List<dynamic> datos = json.decode(respuesta);

    debugPrint("Iniciando la inyección masiva en SQLite...");
    Batch batch = db.batch();

    for (var item in datos) {
      String significadosUnidos = item['significados'].join(', ');
      
      // Convertimos las listas matemáticas a texto para SQLite
      String trazosStr = jsonEncode(item['strokes']);
      String medianasStr = jsonEncode(item['medians']);

      batch.insert('caracteres', {
        'simplificado': item['simplificado'],
        'tradicional': item['tradicional'],
        'pinyin': item['pinyin'],
        'significados': significadosUnidos,
        'trazos': trazosStr,
        'medianas': medianasStr,
      });
    }

    await batch.commit(noResult: true);
    debugPrint("¡Base de datos poblada con éxito!");
  }

  // ----------------------------------------------------------------
  // MOTOR SRS (LA INTELIGENCIA DE LA APP)
  // ----------------------------------------------------------------

  // 3. ACTUALIZAR TIEMPOS
  Future<void> actualizarProgresoSRS(int id, int minutosParaElSiguienteRepaso) async {
    final db = await instance.database;

    final DateTime ahora = DateTime.now();
    final DateTime tiempoProximo = ahora.add(Duration(minutes: minutosParaElSiguienteRepaso));
    final int timestampProximo = tiempoProximo.millisecondsSinceEpoch ~/ 1000;

    await db.rawUpdate(
      'UPDATE caracteres SET veces_visto = veces_visto + 1, proximo_repaso = ? WHERE id = ?',
      [timestampProximo, id]
    );
    
    debugPrint("Hanzi ID $id actualizado. Volverá a aparecer en $minutosParaElSiguienteRepaso minutos.");
  }

  // 4. EXTRAER TARJETA INTELIGENTE
  Future<Map<String, dynamic>?> obtenerSiguienteHanziParaEstudiar() async {
    final db = await instance.database;
    final int ahoraTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final List<Map<String, dynamic>> repasosVencidos = await db.query(
      'caracteres',
      where: 'proximo_repaso <= ? AND veces_visto > 0',
      whereArgs: [ahoraTimestamp],
      orderBy: 'proximo_repaso ASC',
      limit: 1,
    );

    if (repasosVencidos.isNotEmpty) {
      debugPrint("Extrayendo tarjeta para REPASO.");
      return repasosVencidos.first;
    }

    final List<Map<String, dynamic>> tarjetasNuevas = await db.query(
      'caracteres',
      where: 'veces_visto = 0',
      orderBy: 'RANDOM()', 
      limit: 1,
    );

    if (tarjetasNuevas.isNotEmpty) {
      debugPrint("Extrayendo tarjeta NUEVA.");
      return tarjetasNuevas.first;
    }

    return null; 
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
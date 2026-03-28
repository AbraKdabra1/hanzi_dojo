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
      String trazosStr = jsonEncode(item['strokes']);
      String medianasStr = jsonEncode(item['medians']);

      // Extraemos el nivel del JSON (si no existe la llave, le asignamos nivel 1 por defecto)
      int nivelAsignado = item['hsk'] ?? item['nivel'] ?? 1;

      batch.insert('caracteres', {
        'simplificado': item['simplificado'],
        'tradicional': item['tradicional'],
        'pinyin': item['pinyin'],
        'significados': significadosUnidos,
        'trazos': trazosStr,
        'medianas': medianasStr,
        'nivel': nivelAsignado, // <-- ¡NUEVO! Ahora sí guardamos a qué nivel pertenece
      });
    }

    await batch.commit(noResult: true);
    debugPrint("¡Base de datos poblada con éxito!");
  }

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

  // ¡LA AUDITORÍA INTELIGENTE! Ahora exige un nivel como parámetro
  Future<Map<String, dynamic>?> obtenerSiguienteHanziParaEstudiar(int nivelHSK) async {
    final db = await instance.database;
    final int ahoraTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Buscamos repasos vencidos estrictamente de ESE nivel
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

    // 2. Si no hay repasos urgentes, buscamos tarjetas nuevas de ESE nivel
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
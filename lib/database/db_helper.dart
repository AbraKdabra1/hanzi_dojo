import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // Importante para usar debugPrint

class DatabaseHelper {
  // Usamos el patrón "Singleton".
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Si la base de datos ya existe, la devuelve. Si no, la construye.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hanzi_dojo.db');
    return _database!;
  }

  // Creamos el archivo físico en la memoria del teléfono
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // FUNCIÓN 1: Construir los "estantes" (La tabla SQL)
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
    CREATE TABLE caracteres (
      id $idType,
      simplificado $textType,
      tradicional $textType,
      pinyin $textType,
      significados $textType
    )
    ''');
  }

  // FUNCIÓN 2: Llenar los estantes (La inyección masiva)
  Future<void> poblarBaseDeDatos() async {
    final db = await instance.database;

    // 1. Verificamos si la tabla ya tiene datos
    var conteo = await db.rawQuery('SELECT COUNT(*) FROM caracteres');
    int? numeroDeCaracteres = Sqflite.firstIntValue(conteo);

    if (numeroDeCaracteres != null && numeroDeCaracteres > 0) {
      debugPrint("La base de datos ya tiene $numeroDeCaracteres caracteres. Saltando inyección.");
      return;
    }

    debugPrint("Leyendo el archivo JSON desde los assets...");
    final String respuesta = await rootBundle.loadString('assets/diccionario_limpio.json');
    final List<dynamic> datos = json.decode(respuesta);

    debugPrint("Iniciando la inyección masiva en SQLite...");
    Batch batch = db.batch();

    for (var item in datos) {
      String significadosUnidos = item['significados'].join(', ');

      batch.insert('caracteres', {
        'simplificado': item['simplificado'],
        'tradicional': item['tradicional'],
        'pinyin': item['pinyin'],
        'significados': significadosUnidos,
      });
    }

    await batch.commit(noResult: true);
    debugPrint("¡Base de datos poblada con éxito!");
  }
  
// Extraemos exactamente 1 registro al azar de los 120,000 disponibles
  Future<Map<String, dynamic>?> obtenerHanziAlAzar() async {
    final db = await instance.database;
    
    // La magia de SQLite: ORDER BY RANDOM() los mezcla y LIMIT 1 saca el de hasta arriba
    final resultado = await db.rawQuery('SELECT * FROM caracteres ORDER BY RANDOM() LIMIT 1');
    
    if (resultado.isNotEmpty) {
      return resultado.first; // Devolvemos el diccionario con los datos
    }
    return null;
  }
}
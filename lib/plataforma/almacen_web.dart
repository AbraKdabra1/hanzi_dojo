// Archivos de la app en el navegador (ver almacen.dart): se guardan en el
// sistema de archivos de sqflite en la web (IndexedDB), el mismo donde viven
// las bases de datos, así ATTACH encuentra la base de contenido.

import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

class Almacen {
  Almacen._();

  static Future<bool> existe(String ruta) => databaseFactory.databaseExists(ruta);

  /// null si no existe.
  static Future<Uint8List?> leer(String ruta) async =>
      await existe(ruta) ? databaseFactory.readDatabaseBytes(ruta) : null;

  static Future<void> escribir(String ruta, List<int> bytes) =>
      databaseFactory.writeDatabaseBytes(ruta, bytes is Uint8List ? bytes : Uint8List.fromList(bytes));

  static Future<void> borrar(String ruta) async {
    if (await existe(ruta)) await databaseFactory.deleteDatabase(ruta);
  }

  /// En el navegador no hay carpetas reales.
  static Future<void> crearCarpeta(String ruta) async {}
}

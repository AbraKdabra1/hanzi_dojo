// En la web: SQLite en WebAssembly dentro de un worker (SharedWorker si el
// navegador lo tiene: varias pestañas comparten la misma base), con las bases
// guardadas en IndexedDB (ver base_web.dart). web/sqflite_sw.js y
// web/sqlite3.wasm los deja "dart run sqflite_common_ffi_web:setup".
//
// Sin worker (databaseFactoryFfiWebNoWebWorker), Chrome se quedaba sin
// responder al volver a abrir la app con la base ya guardada.

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void prepararBaseDeDatos() {
  databaseFactory = databaseFactoryFfiWeb;
}

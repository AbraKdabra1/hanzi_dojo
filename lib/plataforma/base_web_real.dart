// En la web: SQLite en WebAssembly, en el hilo principal (sin worker), con
// las bases guardadas en IndexedDB (ver base_web.dart).

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void prepararBaseDeDatos() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

// Archivos de la app en el teléfono (ver almacen.dart).

import 'dart:io';
import 'dart:typed_data';

class Almacen {
  Almacen._();

  static Future<bool> existe(String ruta) => File(ruta).exists();

  /// null si no existe.
  static Future<Uint8List?> leer(String ruta) async {
    final f = File(ruta);
    return await f.exists() ? f.readAsBytes() : null;
  }

  /// Escribe de forma segura: primero a un temporal y luego se renombra. Si
  /// la app se cierra a la mitad, no queda un archivo a medias.
  static Future<void> escribir(String ruta, List<int> bytes) async {
    final temporal = File('$ruta.tmp');
    await temporal.writeAsBytes(bytes, flush: true);
    await temporal.rename(ruta);
  }

  static Future<void> borrar(String ruta) async {
    final f = File(ruta);
    if (await f.exists()) await f.delete();
  }

  static Future<void> crearCarpeta(String ruta) => Directory(ruta).create(recursive: true);
}

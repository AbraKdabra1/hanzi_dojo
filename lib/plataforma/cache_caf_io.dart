// Grabaciones CAF en la carpeta temporal (iPhone/iPad; ver cache_caf.dart).
//
// Archivos de 1-5 KB: las operaciones síncronas tardan microsegundos.

import 'dart:io';
import 'dart:typed_data';

class CacheCaf {
  CacheCaf._();

  static Directory get _carpeta => Directory('${Directory.systemTemp.path}/grabaciones_caf');

  /// Ruta del CAF ya guardado, o null.
  static String? buscar(String nombre) {
    final caf = File('${_carpeta.path}/$nombre');
    return caf.existsSync() && caf.lengthSync() > 0 ? caf.path : null;
  }

  /// Lo guarda y devuelve su ruta. Primero a un nombre provisional: si la app
  /// se cierra a la mitad, no queda un CAF a medias que parezca bueno.
  static String guardar(String nombre, Uint8List caf) {
    _carpeta.createSync(recursive: true);
    final destino = '${_carpeta.path}/$nombre';
    File('$destino.tmp')
      ..writeAsBytesSync(caf)
      ..renameSync(destino);
    return destino;
  }

  /// Para el reproductor: se carga como archivo.
  static const esArchivo = true;
}

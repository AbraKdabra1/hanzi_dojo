// Grabaciones CAF en memoria, como direcciones blob: (Safari; ver
// cache_caf.dart). Se pierden al cerrar la pestaña y se vuelven a hacer en
// milisegundos.

import 'dart:typed_data';

import 'navegador.dart';

class CacheCaf {
  CacheCaf._();

  static final Map<String, String> _urls = {};

  static String? buscar(String nombre) => _urls[nombre];

  static String guardar(String nombre, Uint8List caf) =>
      _urls[nombre] = Navegador.urlDeBytes(caf, 'audio/x-caf');

  /// Para el reproductor: se carga como dirección.
  static const esArchivo = false;
}

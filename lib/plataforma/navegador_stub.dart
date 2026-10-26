// Fuera de la web no se usa (ver navegador.dart).

import 'dart:typed_data';

class Navegador {
  Navegador._();

  static Never _no() => throw UnsupportedError('Solo en la versión web');

  static Future<String?> guardar(String nombre, Uint8List bytes, String tipo) async => _no();
  static Future<(String, Uint8List)?> abrir(List<String> tipos) async => _no();
  static bool abrirEnlace(Uri url) => _no();
  static Future<bool> compartirImagen(Uint8List png, String texto) async => _no();
  static Future<bool> compartirTexto(String texto) async => _no();
  static String get agente => _no();
  static bool get oggOpus => true;
  static String urlDeBytes(Uint8List bytes, String tipo) => _no();
  static Future<Uint8List?> descargarGzip(String url) async => null;
}

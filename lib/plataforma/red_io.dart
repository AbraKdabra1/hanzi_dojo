import 'dart:async';
import 'dart:convert';
import 'dart:io';

class Red {
  Red._();

  /// GET de [url]; el cuerpo como texto, o null si no hay conexión, tarda
  /// más de [espera] o no responde 200.
  static Future<String?> obtenerTexto(Uri url, {Duration espera = const Duration(seconds: 12)}) async {
    final cliente = HttpClient()
      ..connectionTimeout = espera
      ..userAgent = 'Meizi-Hanzi';
    try {
      final pedido = await cliente.getUrl(url).timeout(espera);
      pedido.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final respuesta = await pedido.close().timeout(espera);
      if (respuesta.statusCode != 200) {
        await respuesta.drain<void>();
        return null;
      }
      return await respuesta.transform(utf8.decoder).join().timeout(espera);
    } on Object {
      return null;
    } finally {
      cliente.close(force: true);
    }
  }
}

// En la web (ver navegador.dart).

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class Navegador {
  Navegador._();

  /// Descarga [bytes] con el nombre sugerido. Devuelve el nombre.
  static Future<String?> guardar(String nombre, Uint8List bytes, String tipo) async {
    final archivo = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: tipo));
    final url = web.URL.createObjectURL(archivo);
    final enlace = web.HTMLAnchorElement()
      ..href = url
      ..download = nombre;
    web.document.body?.append(enlace);
    enlace.click();
    enlace.remove();
    // Dejar tiempo a que empiece la descarga antes de soltar la dirección.
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    return nombre;
  }

  /// El selector de archivos del navegador: (nombre, bytes), o null si se
  /// canceló.
  static Future<(String, Uint8List)?> abrir(List<String> tipos) {
    final listo = Completer<(String, Uint8List)?>();
    final entrada = web.HTMLInputElement()..type = 'file';
    if (tipos.isNotEmpty && !tipos.contains('*/*')) entrada.accept = tipos.join(',');
    entrada.onchange = ((web.Event _) {
      final archivo = entrada.files?.item(0);
      if (archivo == null) {
        if (!listo.isCompleted) listo.complete(null);
        return;
      }
      archivo.arrayBuffer().toDart.then((buffer) {
        if (!listo.isCompleted) listo.complete((archivo.name, buffer.toDart.asUint8List()));
      }, onError: (Object e) {
        if (!listo.isCompleted) listo.completeError(e);
      });
    }).toJS;
    entrada.addEventListener(
        'cancel',
        ((web.Event _) {
          if (!listo.isCompleted) listo.complete(null);
        }).toJS);
    entrada.click();
    return listo.future;
  }

  static bool abrirEnlace(Uri url) => web.window.open(url.toString(), '_blank') != null;

  /// Menú Compartir del teléfono (o de la computadora) con la imagen; si el
  /// navegador no lo tiene, la descarga.
  static Future<bool> compartirImagen(Uint8List png, String texto) async {
    final archivo = web.File(<JSAny>[png.toJS].toJS, 'hanzi_dojo.png', web.FilePropertyBag(type: 'image/png'));
    final datos = web.ShareData(files: <web.File>[archivo].toJS, text: texto);
    try {
      if (web.window.navigator.canShare(datos)) {
        await web.window.navigator.share(datos).toDart;
        return true;
      }
    } catch (_) {
      // Cancelado o no permitido: se descarga.
    }
    await guardar('hanzi_dojo.png', png, 'image/png');
    return true;
  }

  /// Menú Compartir del teléfono con un texto; si el navegador no lo tiene
  /// (o se cancela), el texto se copia al portapapeles.
  static Future<bool> compartirTexto(String texto) async {
    final datos = web.ShareData(text: texto);
    try {
      if (web.window.navigator.canShare(datos)) {
        await web.window.navigator.share(datos).toDart;
        return true;
      }
    } catch (_) {
      // Cancelado o no permitido: se copia.
    }
    try {
      await web.window.navigator.clipboard.writeText(texto).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Navegador y sistema (para el informe de errores).
  static String get agente => web.window.navigator.userAgent;

  /// ¿Puede tocar Opus dentro de Ogg?
  static bool get oggOpus => _oggOpus ??= web.HTMLAudioElement().canPlayType('audio/ogg; codecs=opus') != '';
  static bool? _oggOpus;

  /// Descarga [url] (relativa a la página) comprimida con gzip y la
  /// descomprime el propio navegador (rápido, sin pasar por Dart). null si no
  /// se pudo: quien llama usa entonces la versión sin comprimir.
  static Future<Uint8List?> descargarGzip(String url) async {
    try {
      final respuesta = await web.window.fetch(url.toJS).toDart;
      final cuerpo = respuesta.body;
      if (!respuesta.ok || cuerpo == null) return null;
      final descompresor = web.DecompressionStream('gzip');
      final flujo = cuerpo.pipeThrough(
        web.ReadableWritablePair(readable: descompresor.readable, writable: descompresor.writable),
      );
      final buffer = await web.Response(flujo).arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Dirección blob: con estos bytes, para el reproductor.
  static String urlDeBytes(Uint8List bytes, String tipo) =>
      web.URL.createObjectURL(web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: tipo)));
}

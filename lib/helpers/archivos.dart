// ─────────────────────────────────────────────────────────────────────────────
// archivos.dart — Guardar y abrir archivos con los diálogos de Android
//
// Habla con MainActivity.kt por el canal "hanzi_dojo/archivos":
//   guardar → diálogo "Guardar como…" del sistema (Descargas, Drive, la nube
//             de Huawei… lo que tenga el teléfono). Sin permisos de
//             almacenamiento: el usuario elige dónde y la app solo escribe ahí.
//   abrir   → selector de archivos del sistema; devuelve nombre y bytes.
//   info    → versión de la app y modelo del teléfono (para el informe de
//             errores; solo se muestra en pantalla, no se envía a ningún lado).
//   abrirEnlace → abre una URL en el navegador (reportar un problema).
//
// Se usa un canal propio en vez de un paquete externo: son pocas líneas, no
// agrega dependencias y la app sigue sin pedir permiso de internet.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';

/// Un archivo elegido por el usuario.
class ArchivoAbierto {
  const ArchivoAbierto(this.nombre, this.bytes);
  final String nombre;
  final Uint8List bytes;
}

/// Versión de la app y datos del teléfono.
class InfoDispositivo {
  const InfoDispositivo({
    required this.version,
    required this.compilacion,
    required this.modelo,
    required this.android,
  });

  /// Cuando no hay plataforma (pruebas) o falla la consulta.
  static const desconocida =
      InfoDispositivo(version: '?', compilacion: '?', modelo: '?', android: '?');

  final String version;
  final String compilacion;
  final String modelo;
  final String android;

  @override
  String toString() => 'Hanzi Dojo $version ($compilacion) · $modelo · Android $android';
}

class Archivos {
  Archivos._();

  static const _canal = MethodChannel('hanzi_dojo/archivos');

  /// Abre "Guardar como…" con [nombre] sugerido y escribe [bytes] donde el
  /// usuario elija. Devuelve el nombre final, o null si canceló.
  static Future<String?> guardar({
    required String nombre,
    required Uint8List bytes,
    String tipo = 'application/octet-stream',
  }) =>
      _canal.invokeMethod<String>('guardar', {'nombre': nombre, 'bytes': bytes, 'tipo': tipo});

  /// Abre el selector de archivos. [tipos] son tipos MIME ("*/*" = cualquiera).
  /// Devuelve null si el usuario canceló.
  static Future<ArchivoAbierto?> abrir({List<String> tipos = const ['*/*']}) async {
    final r = await _canal.invokeMapMethod<String, Object?>('abrir', {'tipos': tipos});
    if (r == null) return null;
    return ArchivoAbierto(r['nombre'] as String? ?? '', r['bytes'] as Uint8List);
  }

  /// Abre [url] en el navegador. false si no hay navegador.
  static Future<bool> abrirEnlace(Uri url) async =>
      await _canal.invokeMethod<bool>('abrirEnlace', {'url': url.toString()}) ?? false;

  static InfoDispositivo? _info;

  static Future<InfoDispositivo> info() async {
    if (_info case final i?) return i;
    try {
      final r = await _canal.invokeMapMethod<String, Object?>('info');
      return _info = InfoDispositivo(
        version: r?['version'] as String? ?? '?',
        compilacion: '${r?['compilacion'] ?? '?'}',
        modelo: r?['modelo'] as String? ?? '?',
        android: r?['android'] as String? ?? '?',
      );
    } on MissingPluginException {
      return InfoDispositivo.desconocida;
    } on PlatformException {
      return InfoDispositivo.desconocida;
    }
  }
}

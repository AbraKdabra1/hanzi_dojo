// ─────────────────────────────────────────────────────────────────────────────
// archivos.dart — Guardar y abrir archivos con los diálogos del sistema
//
// Habla con MainActivity.kt (Android) o AppDelegate.swift (iOS) por el canal
// "hanzi_dojo/archivos" (en la web, plataforma/navegador.dart):
//   guardar → diálogo "Guardar como…" del sistema (Descargas, Drive, la nube
//             de Huawei… lo que tenga el teléfono). Sin permisos de
//             almacenamiento: el usuario elige dónde y la app solo escribe ahí.
//   abrir   → selector de archivos del sistema; devuelve nombre y bytes.
//   info    → versión de la app y modelo del teléfono (para el informe de
//             errores; solo se muestra en pantalla, no se envía a ningún lado).
//   abrirEnlace → abre una URL en el navegador (reportar un problema).
//   compartirTexto → el menú Compartir del sistema con un texto (resumen de
//             la beta).
//
// Se usa un canal propio en vez de un paquete externo: son pocas líneas y no
// agrega dependencias.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../plataforma/navegador.dart';

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
    this.abis = const [],
  });

  /// Cuando no hay plataforma (pruebas) o falla la consulta.
  static const desconocida =
      InfoDispositivo(version: '?', compilacion: '?', modelo: '?', android: '?');

  final String version;
  final String compilacion;
  final String modelo;

  /// Versión del sistema: "14 (API 34)" en Android; en iPhone/iPad ya viene
  /// con el nombre ("iOS 18.2", "iPadOS 18.2").
  final String android;

  /// Arquitecturas del procesador, de la preferida a la menos ("arm64-v8a",
  /// "armeabi-v7a"…). Solo en Android; sirve para descargar el APK correcto.
  final List<String> abis;

  String get sistema => RegExp(r'^\d').hasMatch(android) ? 'Android $android' : android;

  @override
  String toString() => 'Meizi Hanzi $version ($compilacion) · $modelo · $sistema';
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
      kIsWeb
          ? Navegador.guardar(nombre, bytes, tipo)
          : _canal.invokeMethod<String>('guardar', {'nombre': nombre, 'bytes': bytes, 'tipo': tipo});

  /// Abre el selector de archivos. [tipos] son tipos MIME ("*/*" = cualquiera).
  /// Devuelve null si el usuario canceló.
  static Future<ArchivoAbierto?> abrir({List<String> tipos = const ['*/*']}) async {
    if (kIsWeb) {
      final elegido = await Navegador.abrir(tipos);
      return elegido == null ? null : ArchivoAbierto(elegido.$1, elegido.$2);
    }
    final r = await _canal.invokeMapMethod<String, Object?>('abrir', {'tipos': tipos});
    if (r == null) return null;
    return ArchivoAbierto(r['nombre'] as String? ?? '', r['bytes'] as Uint8List);
  }

  /// Abre [url] en el navegador. false si no hay navegador.
  static Future<bool> abrirEnlace(Uri url) async => kIsWeb
      ? Navegador.abrirEnlace(url)
      : await _canal.invokeMethod<bool>('abrirEnlace', {'url': url.toString()}) ?? false;

  /// Abre el menú Compartir con [texto] (en la web, el del navegador; si no
  /// lo tiene, se copia). false si no se pudo.
  static Future<bool> compartirTexto(String texto, {String titulo = ''}) async => kIsWeb
      ? Navegador.compartirTexto(texto)
      : await _canal.invokeMethod<bool>('compartirTexto', {'texto': texto, 'titulo': titulo}) ?? false;

  static InfoDispositivo? _info;

  static Future<InfoDispositivo> info() async {
    if (_info case final i?) return i;
    if (kIsWeb) {
      return _info = InfoDispositivo(version: 'web', compilacion: '-', modelo: 'Navegador', android: Navegador.agente);
    }
    try {
      final r = await _canal.invokeMapMethod<String, Object?>('info');
      return _info = InfoDispositivo(
        version: r?['version'] as String? ?? '?',
        compilacion: '${r?['compilacion'] ?? '?'}',
        modelo: r?['modelo'] as String? ?? '?',
        android: r?['android'] as String? ?? '?',
        abis: [
          for (final a in (r?['abis'] as String? ?? '').split(','))
            if (a.trim().isNotEmpty) a.trim(),
        ],
      );
    } on MissingPluginException {
      return InfoDispositivo.desconocida;
    } on PlatformException {
      return InfoDispositivo.desconocida;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// habito.dart — Lo que del hábito hace Android (canal "hanzi_dojo/habito")
//
//   · Recordatorio diario: una notificación a la hora que elijas. La programa
//     Android (AlarmManager, sin servicios de Google: funciona en Huawei) y
//     solo aparece si ese día todavía no cumples tu meta.
//   · Widget de la pantalla de inicio: carácter del día y repasos pendientes;
//     la app le pide actualizarse al salir.
//   · Compartir una imagen (la tarjeta de progreso) con cualquier app.
//
// Si algo falla (o en las pruebas, donde no hay Android) devuelve false y la
// app sigue normal.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../datos/registro_errores.dart';

class Habito {
  Habito._();

  static const _canal = MethodChannel('hanzi_dojo/habito');

  static Future<T?> _llamar<T>(String metodo, [Map<String, Object?>? argumentos]) async {
    try {
      return await _canal.invokeMethod<T>(metodo, argumentos);
    } on MissingPluginException {
      return null; // pruebas en la computadora
    } catch (e, pila) {
      RegistroErrores.registrar('Hábito ($metodo)', e, pila);
      return null;
    }
  }

  /// Programa el recordatorio diario. Pide antes el permiso de notificaciones
  /// (Android 13+). false si no se pudo o el usuario no dio permiso.
  static Future<bool> programarRecordatorio(int hora, int minuto) async =>
      await _llamar<bool>('programarRecordatorio', {'hora': hora, 'minuto': minuto}) ?? false;

  static Future<void> cancelarRecordatorio() => _llamar<void>('cancelarRecordatorio');

  /// Pide al widget de la pantalla de inicio que se vuelva a dibujar.
  static Future<void> actualizarWidget() => _llamar<void>('actualizarWidget');

  /// Abre el menú "Compartir" de Android con esta imagen PNG.
  static Future<bool> compartirImagen(Uint8List png, {String texto = ''}) async =>
      await _llamar<bool>('compartirImagen', {'png': png, 'texto': texto}) ?? false;
}

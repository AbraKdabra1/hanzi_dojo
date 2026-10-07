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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../datos/registro_errores.dart';
import '../plataforma/navegador.dart';

class Habito {
  Habito._();

  static const _canal = MethodChannel('hanzi_dojo/habito');

  /// ¿Hay recordatorio diario? (En la web no: el navegador no avisa con la
  /// página cerrada.)
  static bool get hayRecordatorio => !kIsWeb;

  static Future<T?> _llamar<T>(String metodo, [Map<String, Object?>? argumentos]) async {
    if (kIsWeb) return null;
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

  /// ¿Hay carácter del día en la pantalla de bloqueo? (En la web no.)
  static bool get hayCaracterDia => !kIsWeb;

  /// Carácter del día: una notificación silenciosa al día a esa hora, con un
  /// carácter para repasar de un vistazo (visible en la pantalla de bloqueo).
  /// [mostrarAhora]: además, la de hoy enseguida (al activarlo). false si no
  /// hay permiso de notificaciones.
  static Future<bool> programarCaracterDia(int hora, int minuto, {bool mostrarAhora = false}) async =>
      await _llamar<bool>('programarCaracterDia', {'hora': hora, 'minuto': minuto, 'mostrarAhora': mostrarAhora}) ??
      false;

  static Future<void> cancelarCaracterDia() => _llamar<void>('cancelarCaracterDia');

  /// Pide al widget de la pantalla de inicio que se vuelva a dibujar.
  static Future<void> actualizarWidget() => _llamar<void>('actualizarWidget');

  /// Abre el menú "Compartir" de Android con esta imagen PNG.
  static Future<bool> compartirImagen(Uint8List png, {String texto = ''}) async => kIsWeb
      ? Navegador.compartirImagen(png, texto)
      : await _llamar<bool>('compartirImagen', {'png': png, 'texto': texto}) ?? false;
}

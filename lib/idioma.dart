// ─────────────────────────────────────────────────────────────────────────────
// idioma.dart — Español o inglés
//
// Los textos de la interfaz están escritos en español directamente en el
// código y pasan por tr(): en español se usan tal cual; en inglés se buscan
// en textos_en.dart. Si alguno falta, se queda en español (nunca se ve una
// clave rara). test/idioma_test.dart revisa que todos tengan traducción.
//
//   Text(tr('Estudiar'))
//   Text(tr('Hoy: {0} de {1}', [hoy, meta]))   → "Today: 3 of 20"
//
// El contenido (significados, ejemplos) también cambia: en inglés se usan los
// significados en inglés de CC-CEDICT y las traducciones al inglés de
// Tatoeba (ver Caracter.significado y Ejemplo.traduccion).
//
// Ajustes → Idioma: Automático (el del teléfono: español si está en español;
// si no, inglés), Español o English.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'textos_en.dart';

enum Lengua { espanol, ingles }

class Idioma {
  Idioma._();

  /// El idioma en uso (la app lo escucha para cambiar al momento).
  static final actual = ValueNotifier<Lengua>(Lengua.espanol);

  static bool get ingles => actual.value == Lengua.ingles;

  /// 'auto' | 'es' | 'en' (como se guarda en la base) → idioma.
  /// [delTelefono]: código del idioma del teléfono ('es', 'en'…).
  static Lengua desdeTexto(String? texto, {String? delTelefono}) => switch (texto) {
        'es' => Lengua.espanol,
        'en' => Lengua.ingles,
        _ => (delTelefono ?? PlatformDispatcher.instance.locale.languageCode) == 'es'
            ? Lengua.espanol
            : Lengua.ingles,
      };

  /// Locale para los textos propios de Flutter (calendario, reloj, botones
  /// de diálogo…), con flutter_localizations.
  static Locale get locale => ingles ? const Locale('en') : const Locale('es');

  static const locales = [Locale('es'), Locale('en')];
}

/// Iniciales de los días (el calendario empieza en lunes).
List<String> get diasLetra => Idioma.ingles
    ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
    : const ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Días abreviados, de lunes a domingo.
List<String> get diasCortos => Idioma.ingles
    ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    : const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// Meses abreviados.
List<String> get mesesCortos => Idioma.ingles
    ? const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    : const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Meses completos.
List<String> get mesesLargos => Idioma.ingles
    ? const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
        'October', 'November', 'December']
    : const ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre',
        'octubre', 'noviembre', 'diciembre'];

/// Un texto de la interfaz en el idioma actual. {0}, {1}… se reemplazan por
/// [args] en orden.
String tr(String texto, [List<Object?> args = const []]) {
  var s = Idioma.ingles ? (textosEn[texto] ?? texto) : texto;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

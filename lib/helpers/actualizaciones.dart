// ─────────────────────────────────────────────────────────────────────────────
// actualizaciones.dart — Avisar cuando hay una versión nueva
//
// Quien instala el APK de GitHub no se entera solo de las versiones nuevas.
// Si el usuario lo acepta (se pregunta una vez; se cambia en Ajustes), la
// app consulta una vez al día la lista de versiones del repositorio en
// GitHub y, si hay una más nueva, la ofrece en el inicio con un botón que
// descarga el APK de su procesador. La consulta no lleva nada del usuario:
// es la misma página pública que cualquiera puede abrir.
//
// Solo en las versiones que se instalan desde GitHub: la web se actualiza
// sola, y las de tiendas (--dart-define=TIENDA=play o fdroid) las actualiza
// la tienda.
//
// Las versiones de prueba (2.1.0-beta.2) ven las betas nuevas; las estables
// (2.1.0) solo las estables.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../datos/repositorio.dart';
import '../plataforma/red.dart';
import 'archivos.dart';

/// Un número de versión como "2.1.0-beta.2" (se ignora la "v" y el "+3").
@immutable
class Version implements Comparable<Version> {
  const Version(this.numeros, [this.previa = const []]);

  final List<int> numeros;

  /// Lo que va después del guion: ["beta", "2"] (vacío en las estables).
  final List<String> previa;

  static Version? leer(String texto) {
    var t = texto.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    final mas = t.indexOf('+');
    if (mas >= 0) t = t.substring(0, mas);
    final guion = t.indexOf('-');
    final nucleo = guion >= 0 ? t.substring(0, guion) : t;
    final numeros = [for (final n in nucleo.split('.')) int.tryParse(n)];
    if (nucleo.isEmpty || numeros.contains(null)) return null;
    final previa = guion >= 0 ? t.substring(guion + 1).split('.').where((x) => x.isNotEmpty).toList() : <String>[];
    return Version([for (final n in numeros) n!], previa);
  }

  bool get esPrevia => previa.isNotEmpty;

  /// Orden de versiones semántico: 2.1.0-beta.1 < 2.1.0-beta.2 < 2.1.0.
  @override
  int compareTo(Version otra) {
    for (var i = 0; i < math.max(numeros.length, otra.numeros.length); i++) {
      final a = i < numeros.length ? numeros[i] : 0;
      final b = i < otra.numeros.length ? otra.numeros[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    if (previa.isEmpty || otra.previa.isEmpty) {
      return previa.isEmpty == otra.previa.isEmpty ? 0 : (previa.isEmpty ? 1 : -1);
    }
    for (var i = 0; i < math.min(previa.length, otra.previa.length); i++) {
      final a = previa[i], b = otra.previa[i];
      final na = int.tryParse(a), nb = int.tryParse(b);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : (na != null ? -1 : (nb != null ? 1 : a.compareTo(b)));
      if (c != 0) return c;
    }
    return previa.length.compareTo(otra.previa.length);
  }

  bool operator >(Version otra) => compareTo(otra) > 0;

  @override
  String toString() => '${numeros.join('.')}${previa.isEmpty ? '' : '-${previa.join('.')}'}';
}

/// Una versión más nueva que la instalada.
@immutable
class VersionNueva {
  const VersionNueva({required this.version, required this.pagina, required this.descarga});

  /// "2.1.0-beta.3"
  final String version;

  /// Página de la versión en GitHub (novedades y todos los archivos).
  final Uri pagina;

  /// APK para este procesador (o la página, si no hay APK que elegir).
  final Uri descarga;

  Map<String, String> aJson() => {'v': version, 'p': '$pagina', 'd': '$descarga'};

  static VersionNueva? desdeJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final v = j['v'], p = Uri.tryParse('${j['p']}'), d = Uri.tryParse('${j['d']}');
    if (v is! String || p == null || d == null) return null;
    return VersionNueva(version: v, pagina: p, descarga: d);
  }
}

/// El final del nombre del APK para estas arquitecturas (ver lanzamiento.yml:
/// Meizi_Hanzi_<versión>_arm64.apk, _arm32, _x86_64, _universal).
String sufijoApk(List<String> abis) {
  for (final abi in abis) {
    switch (abi) {
      case 'arm64-v8a':
        return '_arm64.apk';
      case 'armeabi-v7a':
        return '_arm32.apk';
      case 'x86_64':
        return '_x86_64.apk';
    }
  }
  return '_universal.apk';
}

/// De la lista de versiones de GitHub (JSON de /releases), la más nueva que
/// sea mayor que [actual]; null si ya tienes la más reciente. [android]:
/// se ofrece el APK de [abis]; si no (iPhone), la página de la versión.
VersionNueva? elegirVersionNueva(
  List<Object?> versiones,
  Version actual, {
  List<String> abis = const [],
  bool android = true,
}) {
  Map<String, Object?>? mejor;
  Version? mejorVersion;
  for (final j in versiones) {
    if (j is! Map<String, Object?> || j['draft'] == true) continue;
    if (j['prerelease'] == true && !actual.esPrevia) continue;
    final v = Version.leer('${j['tag_name'] ?? ''}');
    if (v == null || !(v > actual)) continue;
    if (mejorVersion == null || v > mejorVersion) {
      mejor = j;
      mejorVersion = v;
    }
  }
  if (mejor == null || mejorVersion == null) return null;
  final url = mejor['html_url'];
  final pagina = Uri.parse(
      url is String && url.startsWith('https://') ? url : 'https://github.com/AbraKdabra1/hanzi_dojo/releases');
  var descarga = pagina;
  if (android) {
    final assets = mejor['assets'];
    final archivos = [
      for (final a in assets is List ? assets : const [])
        if (a is Map) ('${a['name'] ?? ''}', '${a['browser_download_url'] ?? ''}'),
    ];
    for (final sufijo in [sufijoApk(abis), '_universal.apk']) {
      final hallado = archivos.where((a) => a.$1.endsWith(sufijo) && a.$2.isNotEmpty);
      final enlace = hallado.isEmpty ? null : Uri.tryParse(hallado.first.$2);
      if (enlace != null && enlace.scheme == 'https') {
        descarga = enlace;
        break;
      }
    }
  }
  return VersionNueva(version: '$mejorVersion', pagina: pagina, descarga: descarga);
}

enum EstadoRevision { alDia, nueva, sinConexion, noDisponible }

@immutable
class ResultadoRevision {
  const ResultadoRevision(this.estado, [this.nueva]);

  final EstadoRevision estado;
  final VersionNueva? nueva;
}

extension ActualizacionesRepositorio on Repositorio {
  /// null = todavía no se le ha preguntado.
  Future<bool?> avisarVersiones() async => switch (await base.leerAjuste('versiones_avisar')) {
        '1' => true,
        '0' => false,
        _ => null,
      };

  Future<void> guardarAvisarVersiones(bool avisar) => base.guardarAjuste('versiones_avisar', avisar ? '1' : '0');

  /// La versión que el usuario dejó para después («Ahora no»): no se vuelve a
  /// ofrecer hasta que salga otra.
  Future<String?> versionDescartada() => base.leerAjuste('versiones_descartada');

  Future<void> descartarVersion(String version) => base.guardarAjuste('versiones_descartada', version);

  Future<DateTime?> _ultimaRevision() async {
    final s = int.tryParse(await base.leerAjuste('versiones_revision') ?? '');
    return s == null ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  Future<VersionNueva?> _nuevaGuardada() async {
    final texto = await base.leerAjuste('versiones_nueva');
    if (texto == null || texto.isEmpty) return null;
    try {
      return VersionNueva.desdeJson(jsonDecode(texto));
    } on FormatException {
      return null;
    }
  }

  Future<void> _guardarRevision(DateTime cuando, VersionNueva? nueva) async {
    await base.guardarAjuste('versiones_revision', '${cuando.millisecondsSinceEpoch ~/ 1000}');
    await base.guardarAjuste('versiones_nueva', nueva == null ? '' : jsonEncode(nueva.aJson()));
  }
}

class Actualizaciones {
  Actualizaciones._();

  static const _tienda = String.fromEnvironment('TIENDA');

  static final api = Uri.parse('https://api.github.com/repos/AbraKdabra1/hanzi_dojo/releases?per_page=20');

  /// Entre una consulta y otra (si no se pide a mano con «Buscar ahora»).
  static const cadaCuanto = Duration(hours: 20);

  /// ¿Esta copia de la app puede avisar? (instalada desde GitHub en un
  /// teléfono; no en la web ni en versiones de tienda).
  static bool get disponible =>
      !kIsWeb &&
      _tienda.isEmpty &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Cómo se consulta la lista (se cambia en las pruebas).
  @visibleForTesting
  static Future<String?> Function(Uri url) consultar = Red.obtenerTexto;

  /// Revisa si hay versión nueva. Si ya se revisó hace menos de [cadaCuanto]
  /// (y no es [forzar]), responde con lo que se guardó entonces.
  static Future<ResultadoRevision> revisar(
    Repositorio repo, {
    bool forzar = false,
    DateTime? ahora,
    InfoDispositivo? info,
  }) async {
    final t = ahora ?? DateTime.now();
    final datos = info ?? await Archivos.info();
    final actual = Version.leer(datos.version);
    if (actual == null) return const ResultadoRevision(EstadoRevision.noDisponible);
    final android = defaultTargetPlatform != TargetPlatform.iOS;

    ResultadoRevision resultado(VersionNueva? nueva) {
      // Lo guardado puede ser la versión que ya instalaste.
      final v = nueva == null ? null : Version.leer(nueva.version);
      return v != null && v > actual
          ? ResultadoRevision(EstadoRevision.nueva, nueva)
          : const ResultadoRevision(EstadoRevision.alDia);
    }

    final ultima = await repo._ultimaRevision();
    if (!forzar && ultima != null && t.difference(ultima).abs() < cadaCuanto) {
      return resultado(await repo._nuevaGuardada());
    }
    final texto = await consultar(api);
    if (texto == null) return const ResultadoRevision(EstadoRevision.sinConexion);
    List<Object?>? versiones;
    try {
      final j = jsonDecode(texto);
      if (j is List) versiones = j;
    } on FormatException {
      versiones = null;
    }
    if (versiones == null) return const ResultadoRevision(EstadoRevision.sinConexion);
    final nueva = elegirVersionNueva(versiones, actual, abis: datos.abis, android: android);
    await repo._guardarRevision(t, nueva);
    return resultado(nueva);
  }
}

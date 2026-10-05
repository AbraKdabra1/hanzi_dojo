// ─────────────────────────────────────────────────────────────────────────────
// main.dart — Punto de entrada de Hanzi Dojo
//
// Arranque:
//   0. Se instala el registro de errores (registro_errores.dart): desde aquí,
//      cualquier falla se guarda en el teléfono para el informe de errores.
//   1. Se registra el texto de las licencias (pantalla de Créditos).
//   2. Se muestra de inmediato una pantalla de carga (sin esperar a nada).
//   3. Mientras tanto se abren las bases de datos (la primera vez se copia
//      la base de contenido, ~1 s; las siguientes es instantáneo) y se
//      dibujan las flores de la rama de ciruelo del fondo (unos ms), para que
//      aparezcan completas desde el primer cuadro.
//   4. Al terminar, se muestra la pantalla de inicio.
//
// Batería (helpers/energia.dart): DetectorActividad, en el builder de
// MaterialApp, sube la pantalla a 120 Hz solo mientras tocas o algo se
// desplaza; en segundo plano se suelta todo.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'datos/base_datos.dart';
import 'datos/datos_app.dart';
import 'datos/registro_errores.dart';
import 'datos/repositorio.dart';
import 'datos/repositorio_habito.dart';
import 'datos/repositorio_practica.dart';
import 'helpers/energia.dart';
import 'idioma.dart';
import 'helpers/habito.dart';
import 'painters/rama_ciruelo.dart';
import 'screens/pantalla_inicio.dart';
import 'tema.dart';
import 'widgets/boton_voz.dart';
import 'widgets/fondo_tinta.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RegistroErrores.instalar();
  // Mientras se abre la base: el idioma del teléfono (luego, el de Ajustes).
  Idioma.actual.value = Idioma.desdeTexto(null);
  _registrarLicencias();
  runApp(const HanziDojoApp());
}

class HanziDojoApp extends StatefulWidget {
  const HanziDojoApp({super.key});

  @override
  State<HanziDojoApp> createState() => _HanziDojoAppState();
}

class _HanziDojoAppState extends State<HanziDojoApp> with WidgetsBindingObserver {
  Repositorio? _repo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirDatos());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Batería: en segundo plano se sueltan los 120 Hz; al volver se revisa si
  /// el teléfono activó el ahorro de batería mientras tanto.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Energia.alVolver();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      Energia.enPausa();
      // El widget de la pantalla de inicio refleja lo que acabas de practicar.
      if (state == AppLifecycleState.paused) Habito.actualizarWidget();
    }
  }

  Future<void> _abrirDatos() async {
    try {
      final fondo = SpritesCiruelo.cargar();
      await RegistroErrores.iniciar(await getDatabasesPath());
      final base = await BaseDatos.abrir();
      final repo = Repositorio(base);
      await Energia.iniciar(await repo.fluidezMaxima() ? ModoFluidez.maxima : ModoFluidez.automatica);
      Apariencia.modo.value = Apariencia.desdeTexto(await repo.apariencia());
      Idioma.actual.value = Idioma.desdeTexto(await repo.idioma());
      Voz.velocidad = await repo.vozLenta() ? 0.75 : 1.0;
      // El recordatorio lo programa Android; se vuelve a poner por si la app se
      // reinstaló o se importó un respaldo (si ya estaba, no cambia nada).
      final recordatorio = await repo.recordatorio();
      if (recordatorio != null) Habito.programarRecordatorio(recordatorio.$1, recordatorio.$2);
      await fondo;
      if (mounted) setState(() => _repo = repo);
    } catch (e, pila) {
      debugPrint('Error al abrir la base de datos: $e\n$pila');
      RegistroErrores.registrar('Inicio', e, pila);
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // La apariencia y el idioma (Ajustes) cambian al momento, sin reiniciar.
    return ValueListenableBuilder<Lengua>(
      valueListenable: Idioma.actual,
      builder: (context, lengua, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: Apariencia.modo,
      builder: (context, modo, _) {
        final repo = _repo;
        if (repo == null) {
          // Pantalla de carga (o de error) mientras se abre la base.
          return MaterialApp(
            title: 'Hanzi Dojo',
            debugShowCheckedModeBanner: false,
            theme: temaHanziDojo(),
            darkTheme: temaHanziDojo(Brightness.dark),
            themeMode: modo,
            locale: Idioma.locale,
            supportedLocales: Idioma.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _PantallaCarga(error: _error),
          );
        }
        return DatosApp(
          repo: repo,
          child: MaterialApp(
            // Al cambiar de idioma se arma la app de nuevo (vuelve al inicio):
            // los textos de tr() se leen al construir cada pantalla.
            key: ValueKey(lengua),
            title: 'Hanzi Dojo',
            debugShowCheckedModeBanner: false,
            theme: temaHanziDojo(),
            darkTheme: temaHanziDojo(Brightness.dark),
            themeMode: modo,
            locale: Idioma.locale,
            supportedLocales: Idioma.locales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              // Íconos de la barra de estado legibles también en pantallas sin AppBar.
              value: Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              // Cada toque o desplazamiento sube la pantalla a 120 Hz un momento.
              child: DetectorActividad(child: child ?? const SizedBox()),
            ),
            home: const PantallaInicio(),
          ),
        );
      },
      ),
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        body: Center(
          child: error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('汉字道场', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300)),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    tr('No se pudo abrir la base de datos.\n\n{0}', [error]),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Agrega las licencias de los datos y la tipografía a la página de
/// licencias de Flutter (Créditos → "Ver licencias completas").
void _registrarLicencias() {
  const licencias = {
    'Hanzi Dojo (código de la app)': 'assets/licencias/hanzi_dojo_GPL-3.0.txt',
    'CC-CEDICT (significados)': 'assets/licencias/cc_cedict_CC-BY-SA-4.0.txt',
    'Make Me a Hanzi – graphics.txt (trazos)': 'assets/licencias/make_me_a_hanzi_graphics_ARPHIC.txt',
    'Make Me a Hanzi – dictionary.txt (lecturas)': 'assets/licencias/make_me_a_hanzi_dictionary_LGPL.txt',
    'Unihan (radicales)': 'assets/licencias/unihan_UNICODE.txt',
    'Lista HSK 3.0 (ivankra/hsk30)': 'assets/licencias/hsk30_MIT.txt',
    'Tatoeba (oraciones de ejemplo)': 'assets/licencias/tatoeba_CC-BY-2.0-FR.txt',
    'Noto Sans SC (tipografía)': 'assets/licencias/noto_sans_sc_OFL.txt',
    'OpenCC (tradicional → simplificado)': 'assets/licencias/opencc_APACHE-2.0.txt',
    'chinese-poetry (textos clásicos de «Leer»)': 'assets/licencias/chinese_poetry_MIT.txt',
    'audio-cmn (grabaciones de pronunciación)': 'assets/licencias/audio_cmn_CC-BY-SA.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entrada in licencias.entries) {
      final texto = await rootBundle.loadString(entrada.value);
      yield LicenseEntryWithLineBreaks([tr(entrada.key)], texto);
    }
  });
}

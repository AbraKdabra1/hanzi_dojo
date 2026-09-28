// ─────────────────────────────────────────────────────────────────────────────
// main.dart — Punto de entrada de Hanzi Dojo
//
// Arranque:
//   1. Se registra el texto de las licencias (pantalla de Créditos).
//   2. Se muestra de inmediato una pantalla de carga (sin esperar a nada).
//   3. Mientras tanto se abren las bases de datos. La primera vez se copia
//      la base de contenido (~1 s); las siguientes es instantáneo.
//   4. Al terminar, se muestra la pantalla de inicio.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datos/base_datos.dart';
import 'datos/datos_app.dart';
import 'datos/repositorio.dart';
import 'screens/pantalla_inicio.dart';
import 'widgets/fondo_tinta.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registrarLicencias();
  runApp(const HanziDojoApp());
}

/// Tema visual de toda la app.
ThemeData temaHanziDojo() => ThemeData(
      fontFamily: 'NotoSansSC',
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
    );

class HanziDojoApp extends StatefulWidget {
  const HanziDojoApp({super.key});

  @override
  State<HanziDojoApp> createState() => _HanziDojoAppState();
}

class _HanziDojoAppState extends State<HanziDojoApp> {
  Repositorio? _repo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _abrirDatos();
  }

  Future<void> _abrirDatos() async {
    try {
      final base = await BaseDatos.abrir();
      if (mounted) setState(() => _repo = Repositorio(base));
    } catch (e, pila) {
      debugPrint('Error al abrir la base de datos: $e\n$pila');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) {
      // Pantalla de carga (o de error) mientras se abre la base.
      return MaterialApp(
        title: 'Hanzi Dojo',
        debugShowCheckedModeBanner: false,
        theme: temaHanziDojo(),
        home: _PantallaCarga(error: _error),
      );
    }
    return DatosApp(
      repo: repo,
      child: MaterialApp(
        title: 'Hanzi Dojo',
        debugShowCheckedModeBanner: false,
        theme: temaHanziDojo(),
        home: const PantallaInicio(),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No se pudo abrir la base de datos.\n\n$error',
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
    'CC-CEDICT (significados)': 'assets/licencias/cc_cedict_CC-BY-SA-4.0.txt',
    'Make Me a Hanzi – graphics.txt (trazos)': 'assets/licencias/make_me_a_hanzi_graphics_ARPHIC.txt',
    'Make Me a Hanzi – dictionary.txt (lecturas)': 'assets/licencias/make_me_a_hanzi_dictionary_LGPL.txt',
    'Unihan (radicales)': 'assets/licencias/unihan_UNICODE.txt',
    'Lista HSK 3.0 (ivankra/hsk30)': 'assets/licencias/hsk30_MIT.txt',
    'Tatoeba (oraciones de ejemplo)': 'assets/licencias/tatoeba_CC-BY-2.0-FR.txt',
    'Noto Sans SC (tipografía)': 'assets/licencias/noto_sans_sc_OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entrada in licencias.entries) {
      final texto = await rootBundle.loadString(entrada.value);
      yield LicenseEntryWithLineBreaks([entrada.key], texto);
    }
  });
}

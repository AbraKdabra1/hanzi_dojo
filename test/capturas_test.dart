// Capturas de las pantallas principales, en tema claro y oscuro.
//
// No compara nada: dibuja cada pantalla con la base real y las fuentes reales
// y guarda un PNG en build/capturas/. Sirve para revisar cómo se ve la app
// sin abrirla en un teléfono (CI las publica en la rama ci-registros).
//
// Solo corre si se pide (para que `flutter test` siga siendo rápido):
//   CAPTURAS=1 flutter test test/capturas_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/painters/rama_ciruelo.dart';
import 'package:hanzi_dojo/screens/pantalla_ajustes.dart';
import 'package:hanzi_dojo/screens/pantalla_bateria.dart';
import 'package:hanzi_dojo/screens/pantalla_biblioteca.dart';
import 'package:hanzi_dojo/screens/pantalla_compartir.dart';
import 'package:hanzi_dojo/screens/pantalla_estadisticas.dart';
import 'package:hanzi_dojo/screens/pantalla_escucha.dart';
import 'package:hanzi_dojo/screens/pantalla_estudio.dart';
import 'package:hanzi_dojo/screens/pantalla_inicio.dart';
import 'package:hanzi_dojo/screens/pantalla_lectura.dart';
import 'package:hanzi_dojo/screens/pantalla_logros.dart';
import 'package:hanzi_dojo/screens/pantalla_modo.dart';
import 'package:hanzi_dojo/screens/pantalla_pinyin.dart';
import 'package:hanzi_dojo/screens/pantalla_practica.dart';
import 'package:hanzi_dojo/screens/pantalla_radicales.dart';
import 'package:hanzi_dojo/screens/pantalla_seleccion.dart';
import 'package:hanzi_dojo/screens/pantalla_tonos.dart';
import 'package:hanzi_dojo/screens/pantalla_vocabulario.dart';
import 'package:hanzi_dojo/idioma.dart';
import 'package:hanzi_dojo/tema.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _pedidas = Platform.environment.containsKey('CAPTURAS');
final _clave = GlobalKey();

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

Future<void> _cargarFuentes() async {
  final noto = FontLoader('NotoSansSC');
  for (final peso in ['Regular', 'Medium', 'Bold']) {
    noto.addFont(rootBundle.load('assets/fonts/NotoSansSC-$peso.ttf'));
  }
  await noto.load();
  // Emojis (en CI: paquete fonts-noto-color-emoji). En el teléfono los pone Android.
  final emojis = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
  if (emojis.existsSync()) {
    final cargador = FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(emojis.readAsBytesSync())));
    await cargador.load();
  }
  // Íconos de Material: vienen con Flutter.
  final artefactos = File(Platform.resolvedExecutable).parent.parent.parent;
  final iconos = File('${artefactos.path}/material_fonts/MaterialIcons-Regular.otf');
  if (iconos.existsSync()) {
    final cargador = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(iconos.readAsBytesSync())));
    await cargador.load();
  }
}

/// El tema de la app con la fuente de emojis como respaldo (solo en pruebas).
ThemeData _conEmojis(ThemeData tema) => tema.copyWith(
      textTheme: tema.textTheme.apply(fontFamilyFallback: const ['NotoColorEmoji']),
    );

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_capturas');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDownAll(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  /// Muestra [pantalla], deja que cargue sus datos (consultas reales) y guarda
  /// la captura como build/capturas/[nombre]_{claro,oscuro}.png.
  Future<void> capturar(WidgetTester tester, String nombre, Widget pantalla,
      {Future<void> Function(WidgetTester)? accion}) async {
    for (final oscuro in [false, true]) {
      await tester.pumpWidget(RepaintBoundary(
        key: _clave,
        child: DatosApp(
          repo: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _conEmojis(temaHanziDojo(oscuro ? Brightness.dark : Brightness.light)),
            home: pantalla,
          ),
        ),
      ));
      // Las consultas a la base son asíncronas de verdad: se les da tiempo.
      Future<void> esperar() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await esperar();
      if (accion != null) {
        await accion(tester);
        await esperar();
      }
      final caja = tester.renderObject<RenderRepaintBoundary>(find.byKey(_clave));
      await tester.runAsync(() async {
        final imagen = await caja.toImage(pixelRatio: 2);
        final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
        final archivo = File('build/capturas/${nombre}_${oscuro ? 'oscuro' : 'claro'}.png');
        archivo.parent.createSync(recursive: true);
        archivo.writeAsBytesSync(png!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox()); // apaga relojes de la pantalla
    }
  }

  testWidgets('capturas de las pantallas principales', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // ~ Huawei Pura 70
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('hanzi_dojo/energia'),
        (llamada) async {
      if (llamada.method == 'bateria') {
        return {'nivel': 64, 'corriente': -380000, 'contador': 3136000, 'cargando': false, 'temperatura': 318, 'tasa': 60.0};
      }
      if (llamada.method == 'ahorro') return false;
      return null;
    });

    Voz.desactivada = true; // en la computadora no hay reproductor de audio
    await tester.runAsync(() async {
      await _cargarFuentes();
      await SpritesCiruelo.cargar();
    });

    // Datos que necesitan algunas pantallas.
    final (libro, capitulos, idHao) = (await tester.runAsync(() async {
      final libros = await repo.libros();
      final libro = libros.first;
      final capitulos = await repo.capitulos(libro);
      final hao = await repo.caracterPorTexto('好');
      return (libro, capitulos, hao!.id);
    }))!;

    await capturar(tester, '01_inicio', const PantallaInicio());
    await capturar(tester, '02_modo', const PantallaModo(),
        accion: (t) => t.tap(find.text('Soy novato'), warnIfMissed: false));
    await capturar(tester, '03_niveles', const PantallaSeleccion(modoNovato: true));
    await capturar(tester, '04_estudio', PantallaEstudio(filtro: FiltroEstudio.unico(idHao), modoNovato: true));
    await capturar(tester, '05_radicales', const PantallaRadicales(modoNovato: true));
    await capturar(tester, '06_biblioteca', const PantallaBiblioteca());
    await capturar(tester, '07_lectura', PantallaLectura(libro: libro, capitulos: capitulos, indice: 0));
    await capturar(tester, '07b_ficha', PantallaLectura(libro: libro, capitulos: capitulos, indice: 0),
        accion: (t) => t.tap(find.text('四').first, warnIfMissed: false));
    await capturar(tester, '08_estadisticas', const PantallaEstadisticas());
    await capturar(tester, '09_ajustes', const PantallaAjustes());
    await capturar(tester, '10_bateria', const PantallaBateria());
    await capturar(tester, '11_practica', const PantallaPractica());
    await capturar(tester, '12_tonos', const PantallaTonos(nivel: 1),
        accion: (t) => t.tap(find.text('3.º tono'), warnIfMissed: false));
    await capturar(tester, '12b_tonos_palabras', const PantallaTonos(nivel: 2),
        accion: (t) => t.tap(find.text('Palabras'), warnIfMissed: false));
    await capturar(tester, '13_escucha', const PantallaEscucha(nivel: 1));
    await capturar(tester, '14_vocabulario', const PantallaVocabulario(nivel: 1),
        accion: (t) => t.tap(find.text('Mostrar'), warnIfMissed: false));
    await capturar(tester, '15_pinyin', const PantallaPinyin(nivel: 1), accion: (t) async {
      await t.enterText(find.byType(TextField), 'ni3hao');
    });
    await capturar(tester, '16_logros', const PantallaLogros());
    await capturar(tester, '17_compartir', const PantallaCompartir());

    // La interfaz en inglés (Ajustes › Idioma).
    Idioma.actual.value = Lengua.ingles;
    await capturar(tester, '20_inicio_en', const PantallaInicio());
    await capturar(tester, '21_estudio_en', PantallaEstudio(filtro: FiltroEstudio.unico(idHao), modoNovato: true));
    await capturar(tester, '22_practica_en', const PantallaPractica());
    await capturar(tester, '23_ajustes_en', const PantallaAjustes());
    Idioma.actual.value = Lengua.espanol;
  }, skip: !_pedidas);
}

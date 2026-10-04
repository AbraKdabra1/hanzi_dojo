// Capturas de las pantallas principales, en tema claro y oscuro.
//
// No compara nada: dibuja cada pantalla con la base real y las fuentes reales
// y guarda un PNG en build/capturas/. Sirve para revisar cómo se ve la app
// sin abrirla en un teléfono (CI las publica en la rama ci-registros).
//
// Solo corre si se pide (para que `flutter test` siga siendo rápido):
//   CAPTURAS=1 flutter test test/capturas_test.dart

import 'dart:io';
import 'dart:typed_data';
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
import 'package:hanzi_dojo/screens/pantalla_estadisticas.dart';
import 'package:hanzi_dojo/screens/pantalla_estudio.dart';
import 'package:hanzi_dojo/screens/pantalla_inicio.dart';
import 'package:hanzi_dojo/screens/pantalla_lectura.dart';
import 'package:hanzi_dojo/screens/pantalla_modo.dart';
import 'package:hanzi_dojo/screens/pantalla_radicales.dart';
import 'package:hanzi_dojo/screens/pantalla_seleccion.dart';
import 'package:hanzi_dojo/tema.dart';
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
  // Íconos de Material: vienen con Flutter.
  final artefactos = File(Platform.resolvedExecutable).parent.parent.parent;
  final iconos = File('${artefactos.path}/material_fonts/MaterialIcons-Regular.otf');
  if (iconos.existsSync()) {
    final cargador = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(iconos.readAsBytesSync())));
    await cargador.load();
  }
}

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
  Future<void> capturar(WidgetTester tester, String nombre, Widget pantalla) async {
    for (final oscuro in [false, true]) {
      await tester.pumpWidget(RepaintBoundary(
        key: _clave,
        child: DatosApp(
          repo: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: temaHanziDojo(oscuro ? Brightness.dark : Brightness.light),
            home: pantalla,
          ),
        ),
      ));
      // Las consultas a la base son asíncronas de verdad: se les da tiempo.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
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
    await capturar(tester, '02_modo', const PantallaModo());
    await capturar(tester, '03_niveles', const PantallaSeleccion(modoNovato: true));
    await capturar(tester, '04_estudio', PantallaEstudio(filtro: FiltroEstudio.unico(idHao), modoNovato: true));
    await capturar(tester, '05_radicales', const PantallaRadicales(modoNovato: true));
    await capturar(tester, '06_biblioteca', const PantallaBiblioteca());
    await capturar(tester, '07_lectura', PantallaLectura(libro: libro, capitulos: capitulos, indice: 0));
    await capturar(tester, '08_estadisticas', const PantallaEstadisticas());
    await capturar(tester, '09_ajustes', const PantallaAjustes());
    await capturar(tester, '10_bateria', const PantallaBateria());
  }, skip: !_pedidas);
}

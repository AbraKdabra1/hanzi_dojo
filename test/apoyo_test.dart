// Apoyar el proyecto: el aviso sale una sola vez, y solo a quien ya lleva
// varios logros; la hoja muestra el botón de PayPal.
//   flutter test test/apoyo_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/widgets/apoyo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('el enlace es de PayPal y no lleva el correo', () {
    expect(Apoyo.enlace.host, 'paypal.me');
    expect(Apoyo.enlace.toString(), isNot(contains('@')));
    expect(Apoyo.disponible, isTrue); // sin --dart-define=TIENDA=play
  });

  testWidgets('el aviso sale una sola vez y con 3 logros o más', (tester) async {
    final (carpeta, base) = (await tester.runAsync(() async {
      final carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_apoyo');
      return (carpeta, await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido));
    }))!;
    final repo = Repositorio(base);

    late BuildContext contexto;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        contexto = c;
        return const SizedBox.expand();
      })),
    ));
    const aviso = '¿Te está sirviendo Meizi Hanzi? Es gratis y sin anuncios; si quieres, puedes apoyarlo.';

    Future<void> logro(String clave) =>
        tester.runAsync(() => base.db.insert('logros', {'clave': clave, 'momento': 1790000000}));
    Future<void> sugerir() async {
      await tester.runAsync(() => Apoyo.sugerirTrasLogro(contexto, repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750)); // que termine de entrar
    }

    // Con dos logros todavía no.
    await logro('primer_caracter');
    await logro('racha_7');
    await sugerir();
    expect(find.text(aviso), findsNothing);

    // Al tercero, sí.
    await logro('nivel_1');
    await sugerir();
    expect(find.text(aviso), findsOneWidget);

    // «Ver cómo» abre la hoja con el botón de PayPal.
    await tester.tap(find.text('Ver cómo'));
    await tester.pumpAndSettle();
    expect(find.text('Donar con PayPal'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.text('Donar con PayPal'), findsNothing);

    // Nunca más.
    ScaffoldMessenger.of(contexto).clearSnackBars();
    await tester.pumpAndSettle();
    await logro('racha_30');
    await sugerir();
    expect(find.text(aviso), findsNothing);

    await tester.runAsync(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });
  });
}

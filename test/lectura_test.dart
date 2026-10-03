// Pruebas de la sección «Leer»: libros en la base real, capítulos leídos,
// respaldo, cortes de línea y toques en el texto.
//   flutter test test/lectura_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/widgets/texto_lectura.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  group('Libros en la base', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_lectura');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('hay libros ordenados por nivel; el de HSK 1 tiene sus capítulos', () async {
      final libros = await repo.libros();
      expect(libros, isNotEmpty);
      final niveles = libros.map((l) => l.nivelHsk).toList();
      expect(niveles, [...niveles]..sort());

      final cuentos = libros.firstWhere((l) => l.clave == 'cuentos-para-ninos');
      expect(cuentos.nivelHsk, 1);
      expect(cuentos.adaptado, isTrue);
      expect(cuentos.capitulos, 5);
      expect(cuentos.capitulosLeidos, 0);
      expect(cuentos.cobertura, greaterThanOrEqualTo(0.9));

      final capitulos = await repo.capitulos(cuentos);
      expect(capitulos.map((c) => c.orden), [1, 2, 3, 4, 5]);
      expect(capitulos.first.titulo, '孔融让梨');
      expect(capitulos.first.palabras.map((p) => p.chino), contains('梨'));
      expect(capitulos.first.palabras.first.pinyin, isNotEmpty);
    });

    test('un libro por nivel: adaptados del 1 al 5, originales en 6 y 7-9', () async {
      final libros = await repo.libros();
      expect(libros.map((l) => l.nivelHsk), [1, 2, 3, 4, 5, 6, 7]);
      for (final l in libros) {
        expect(l.adaptado, l.nivelHsk <= 5, reason: l.clave);
        expect(l.capitulos, greaterThanOrEqualTo(4), reason: l.clave);
        if (l.adaptado) expect(l.cobertura, greaterThanOrEqualTo(0.9), reason: l.clave);
      }
    });

    test('cada párrafo trae una sílaba por carácter y sus nombres propios', () async {
      final cuentos = (await repo.libros()).firstWhere((l) => l.clave == 'cuentos-para-ninos');
      for (final cap in await repo.capitulos(cuentos)) {
        for (final p in await repo.parrafos(cap.id)) {
          expect(p.pinyin, hasLength(p.caracteres.length));
          for (final (i, c) in p.caracteres.indexed) {
            if (esHan(c)) expect(p.pinyin[i], isNotEmpty, reason: '$c en ${p.chino}');
          }
          expect(p.espanol, isNotEmpty);
        }
      }
      final primero = (await repo.parrafos((await repo.capitulos(cuentos)).first.id)).first;
      expect(primero.chino, startsWith('孔融'));
      expect(primero.esNombre(0) && primero.esNombre(1), isTrue);
      expect(primero.esNombre(2), isFalse);
      // El nombre marcado una vez se reconoce también en los demás párrafos.
      final tercero = (await repo.parrafos((await repo.capitulos(cuentos)).first.id))[2];
      expect(tercero.nombres, isNotEmpty);
    });

    test('marcar un capítulo como leído (y desmarcarlo)', () async {
      var cuentos = (await repo.libros()).firstWhere((l) => l.clave == 'cuentos-para-ninos');
      await repo.marcarCapitulo(cuentos.clave, 2);
      cuentos = (await repo.libros()).firstWhere((l) => l.clave == 'cuentos-para-ninos');
      expect(cuentos.capitulosLeidos, 1);
      expect((await repo.capitulos(cuentos)).map((c) => c.leido), [false, true, false, false, false]);

      await repo.marcarCapitulo(cuentos.clave, 2, leido: false);
      cuentos = (await repo.libros()).firstWhere((l) => l.clave == 'cuentos-para-ninos');
      expect(cuentos.capitulosLeidos, 0);
    });

    test('lo leído viaja en el respaldo', () async {
      await repo.marcarCapitulo('cuentos-para-ninos', 1);
      await repo.marcarCapitulo('cuentos-para-ninos', 3);
      final datos = Respaldo.leer(await Respaldo.exportar(base.db));
      expect(datos.lectura, hasLength(2));

      await repo.marcarCapitulo('cuentos-para-ninos', 1, leido: false);
      await Respaldo.importar(base, datos);
      final cuentos = (await repo.libros()).firstWhere((l) => l.clave == 'cuentos-para-ninos');
      expect(cuentos.capitulosLeidos, 2);
    });

    test('ajustes del lector: por defecto y guardados', () async {
      final porDefecto = await repo.ajustesLectura();
      expect(porDefecto.pinyin, isTrue);
      expect(porDefecto.traduccion, isFalse);
      expect(porDefecto.tamano, AjustesLectura.tamanoPorDefecto);

      await repo.guardarAjustesLectura(porDefecto.copia(pinyin: false, traduccion: true, tamano: 30));
      final guardados = await repo.ajustesLectura();
      expect(guardados.pinyin, isFalse);
      expect(guardados.traduccion, isTrue);
      expect(guardados.tamano, 30);
      expect(guardados.siguienteTamano, 34);
      expect(guardados.copia(tamano: 34).siguienteTamano, AjustesLectura.tamanos.first);
    });

    test('consultar un carácter tocado en el texto', () async {
      expect((await repo.caracterPorTexto('梨'))?.nivelHsk, 5);
      expect(await repo.caracterPorTexto('x'), isNull);
    });
  });

  group('Texto del lector', () {
    test('la puntuación no queda al inicio ni al final de una línea', () {
      final c = '他说：“你好！”'.split('');
      // 他 | 说： | “你 | 好！”
      expect(bloquesSinCorte(c), [
        [0],
        [1, 2],
        [3, 4],
        [5, 6, 7],
      ]);
    });

    testWidgets('tocar un carácter avisa su posición; la puntuación no', (tester) async {
      final parrafo = ParrafoLibro(
        chino: '孔融说：“好。”',
        caracteres: '孔融说：“好。”'.split(''),
        pinyin: const ['kǒng', 'róng', 'shuō', '', '', 'hǎo', '', ''],
        nombres: const [(0, 2)],
        espanol: 'Kong Rong dijo: «Bien».',
      );
      final tocados = <int>[];
      var traducir = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ParrafoLectura(
              parrafo: parrafo,
              tamano: 26,
              mostrarPinyin: true,
              mostrarTraduccion: traducir,
              onAlternarTraduccion: () => setState(() => traducir = !traducir),
              onTocarCaracter: tocados.add,
            ),
          ),
        ),
      ));
      expect(find.text('shuō'), findsOneWidget);
      await tester.tap(find.text('说'));
      await tester.tap(find.text('：'));
      await tester.tap(find.text('好'));
      expect(tocados, [2, 5]);

      expect(find.text('Kong Rong dijo: «Bien».'), findsNothing);
      await tester.tap(find.byIcon(Icons.translate_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Kong Rong dijo: «Bien».'), findsOneWidget);
    });
  });
}

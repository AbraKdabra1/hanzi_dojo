// Resumen de la beta y «¿Ese trazo estaba bien?»: qué se guarda, qué se
// cuenta y cómo se ve el texto que el probador comparte.
//   flutter test test/resumen_beta_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart' show MaterialApp, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/registro_errores.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/resumen_beta.dart';
import 'package:hanzi_dojo/painters/geometria.dart';
import 'package:hanzi_dojo/screens/pantalla_resumen_beta.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

int _seg(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

TrazoReportado _trazo(String c, {int indice = 0, bool alReves = false}) => TrazoReportado(
      caracter: c,
      indice: indice,
      alReves: alReves,
      modoNovato: true,
      momento: DateTime(2026, 10, 9, 20),
      puntos: const [Offset(300, 780), Offset(250, 500), Offset(120, 300)],
    );

void main() {
  test('de píxeles a 1024 × 1024 y de regreso', () {
    const tamano = Size(330, 330);
    for (final p in const [Offset(0, 0), Offset(512, 388), Offset(1024, -124), Offset(103.5, 871.25)]) {
      final ida = GeometriaLienzo.aLienzo(p, tamano);
      final vuelta = GeometriaLienzo.deLienzo(ida, tamano);
      expect(vuelta.dx, closeTo(p.dx, 1e-9));
      expect(vuelta.dy, closeTo(p.dy, 1e-9));
    }
  });

  group('TrazoReportado', () {
    test('se guardan a lo más 16 puntos, con los extremos', () {
      final muchos = [for (var i = 0; i <= 100; i++) Offset(i * 10.4, 900 - i * 3.3)];
      final pocos = TrazoReportado.simplificar(muchos);
      expect(pocos, hasLength(TrazoReportado.puntosMaximos));
      expect(pocos.first, const Offset(0, 900));
      expect(pocos.last, Offset(1040, (900 - 330.0).roundToDouble()));
      expect(TrazoReportado.simplificar(const [Offset(1.4, 2.6)]), const [Offset(1, 3)]);
    });

    test('ida y vuelta en JSON', () {
      final t = _trazo('人', indice: 1, alReves: true);
      final otra = TrazoReportado.desdeJson(t.aJson())!;
      expect(otra.caracter, '人');
      expect(otra.indice, 1);
      expect(otra.alReves, isTrue);
      expect(otra.modoNovato, isTrue);
      expect(otra.momento, t.momento);
      expect(otra.puntos, t.puntos);
      expect(otra.textoPuntos, '300,780 250,500 120,300');
      expect(TrazoReportado.desdeJson({'c': 1}), isNull);
      expect(TrazoReportado.desdeJson('nada'), isNull);
    });
  });

  group('con la base', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('meizi_resumen');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('se guardan los últimos 30 trazos reportados', () async {
      expect(await repo.trazosReportados(), isEmpty);
      for (var i = 0; i < 35; i++) {
        await repo.reportarTrazo(_trazo('人', indice: i));
      }
      final guardados = await repo.trazosReportados();
      expect(guardados, hasLength(ResumenBetaRepositorio.trazosMaximos));
      expect(guardados.first.indice, 5);
      expect(guardados.last.indice, 34);
    });

    test('el tutorial guarda solo cómo terminó la primera vez', () async {
      expect(await repo.resultadoTutorial(), isNull);
      await repo.guardarResultadoTutorial('omitido');
      await repo.guardarResultadoTutorial('escrito');
      expect(await repo.resultadoTutorial(), 'omitido');
    });

    test('el resumen cuenta lo que hiciste y se lee bien', () async {
      final d1 = DateTime(2026, 10, 8, 10), d2 = DateTime(2026, 10, 10, 21);
      Future<void> repaso(String c, DateTime t, {int errores = 0, int novato = 1}) => base.db.insert('historial', {
            'caracter': c,
            'momento': _seg(t),
            'duracion_ms': 30000,
            'calificacion': 3,
            'errores': errores,
            'al_reves': 0,
            'modo_novato': novato,
            'nuevo': 1,
            'intervalo': 1,
          });
      await repaso('好', d1);
      await repaso('人', d1, errores: 2);
      await repaso('好', d2, novato: 0);
      await repaso('大', d2);
      for (final tipo in ['tono', 'tono', 'escucha']) {
        await base.db.insert('ejercicios', {'tipo': tipo, 'elemento': 'ma3', 'momento': _seg(d2), 'resultado': 1});
      }
      await base.db.insert('lectura', {'libro': 'cuentos', 'capitulo': 1, 'momento': _seg(d2)});
      await repo.guardarResultadoTutorial('escrito');
      await repo.reportarTrazo(_trazo('人', alReves: true));

      final d = await repo.datosResumen();
      expect(d.dias, [DateTime(2026, 10, 8), DateTime(2026, 10, 10)]);
      expect(d.repasos, 4);
      expect(d.distintos, 3);
      expect(d.sinErrores, 3);
      expect(d.novato, 3);
      expect(d.minutos, 2);
      expect(d.ejercicios, {'escucha': 1, 'tono': 2});
      expect(d.capitulos, 1);
      expect(d.tutorial, 'escrito');
      expect(d.trazos, hasLength(1));

      final texto = ResumenBeta.texto(
        d,
        dispositivo: 'Meizi Hanzi 2.1.0-beta.2 (4) · Prueba · Android 14 (API 34)',
        errores: [
          EntradaError(momento: d2, origen: 'Voz', mensaje: 'No se pudo tocar\nlínea 2', pila: '', veces: 2),
        ],
        comentario: '  El tutorial me gustó  ',
      );
      expect(texto, contains('Meizi Hanzi 2.1.0-beta.2 (4) · Prueba'));
      expect(texto, contains('Tutorial: terminado, escribió 人'));
      expect(texto, contains('💬 El tutorial me gustó'));
      expect(texto, contains('Días con actividad: 2 (8/10 → 10/10)'));
      expect(texto, contains('Repasos: 4 · caracteres distintos: 3'));
      expect(texto, contains('Sin errores: 75 % · en modo novato: 75 %'));
      expect(texto, contains('Práctica: Escucha 1 · Tonos (sílabas) 2'));
      expect(texto, contains('Lectura: 1 capítulos'));
      expect(texto, contains('· 人 #1 (al revés, novato): 300,780 250,500 120,300'));
      expect(texto, contains('Errores de la app: 1'));
      expect(texto, contains('Voz ×2: No se pudo tocar'));
      expect(texto, isNot(contains('línea 2')));
    });

    test('sin actividad tampoco truena', () async {
      final texto = ResumenBeta.texto(await repo.datosResumen(), dispositivo: 'x', errores: const []);
      expect(texto, contains('Días con actividad: 0'));
      expect(texto, contains('Sin errores: — · en modo novato: —'));
      expect(texto, contains('Práctica: —'));
      expect(texto, isNot(contains('Trazos que la app marcó mal')));
    });

    testWidgets('la pantalla muestra lo que se va a compartir', (tester) async {
      RegistroErrores.reiniciarParaPruebas();
      await tester.runAsync(() => repo.reportarTrazo(_trazo('人')));
      await tester.pumpWidget(DatosApp(repo: repo, child: const MaterialApp(home: PantallaResumenBeta())));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Lo que se comparte'), findsOneWidget);
      expect(find.textContaining('Trazos que la app marcó mal (1)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Me encantó');
      await tester.pump();
      expect(find.textContaining('💬 Me encantó'), findsOneWidget);
    });
  });
}

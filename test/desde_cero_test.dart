// «Chino desde cero»: qué lecciones se guardan como terminadas, la pregunta
// de la primera vez (empezar desde cero u omitir), los candados del inicio y
// su desbloqueo, dónde aparece en Ajustes, y que cada lección se recorre
// completa (en pantalla chica y sin errores), con sonidos que la app sí trae.
//   flutter test test/desde_cero_test.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/datos_app.dart';
import 'package:hanzi_dojo/datos/desde_cero.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_habito.dart';
import 'package:hanzi_dojo/helpers/actualizaciones.dart';
import 'package:hanzi_dojo/helpers/sensaciones.dart';
import 'package:hanzi_dojo/screens/pantalla_ajustes.dart';
import 'package:hanzi_dojo/screens/pantalla_biblioteca.dart';
import 'package:hanzi_dojo/screens/pantalla_desde_cero.dart';
import 'package:hanzi_dojo/screens/pantalla_inicio.dart';
import 'package:hanzi_dojo/screens/pantalla_modo.dart';
import 'package:hanzi_dojo/widgets/boton_voz.dart';
import 'package:hanzi_dojo/widgets/lienzo_escritura.dart';
import 'package:hanzi_dojo/widgets/piezas_desde_cero.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;
  final silabas = File('assets/audio/silabas.txt').readAsLinesSync().where((l) => l.isNotEmpty).toSet();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Voz.desactivada = true;
    Sensaciones.desactivadas = true;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('meizi_desde_cero');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  test('las lecciones terminadas se guardan sin repetirse', () async {
    expect(await repo.leccionesTerminadas(), isEmpty);
    await repo.terminarLeccion(2);
    await repo.terminarLeccion(0);
    await repo.terminarLeccion(2);
    expect(await repo.leccionesTerminadas(), {0, 2});
    expect(await base.leerAjuste('desde_cero'), '0,2');
  });

  Future<void> terminarTodas() async {
    for (var i = 0; i < DesdeCeroRepositorio.totalLecciones; i++) {
      await repo.terminarLeccion(i);
    }
  }

  test('empezar desde cero bloquea hasta terminar las seis, y se desbloquea una sola vez', () async {
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.sinElegir);
    await repo.elegirDesdeCero(true);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.enCurso);
    expect(RutaDesdeCero.enCurso.bloquea, isTrue);
    expect(RutaDesdeCero.enCurso.enInicio, isTrue);

    await repo.terminarLeccion(0);
    expect(await repo.desbloquearSiTerminaste(), isFalse);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.enCurso);

    await terminarTodas();
    expect(await repo.desbloquearSiTerminaste(), isTrue);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.terminada);
    expect(await repo.desbloquearSiTerminaste(), isFalse); // el festejo, una vez
    expect(RutaDesdeCero.terminada.bloquea, isFalse);
    expect(RutaDesdeCero.terminada.enInicio, isFalse);
  });

  test('omitirlo no bloquea nada, aunque luego termines las lecciones', () async {
    await repo.elegirDesdeCero(false);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.omitida);
    await terminarTodas();
    expect(await repo.desbloquearSiTerminaste(), isFalse);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.omitida);
    expect(RutaDesdeCero.omitida.bloquea, isFalse);
  });

  test('a quien ya estudia (venía de una versión anterior) no se le pregunta', () async {
    final lote = base.db.batch();
    for (var i = 0; i < DesdeCeroRepositorio.repasosParaOcultar; i++) {
      lote.insert('historial', {
        'caracter': '好',
        'momento': 1790000000 + i,
        'duracion_ms': 3000,
        'calificacion': 3,
        'errores': 0,
        'al_reves': 0,
        'modo_novato': 1,
        'nuevo': 0,
        'intervalo': 1,
      });
    }
    await lote.commit(noResult: true);
    expect(await repo.rutaDesdeCero(), RutaDesdeCero.omitida);
    expect(await base.leerAjuste('desde_cero_ruta'), 'no');
  });

  test('seis lecciones, todas con varios pasos', () {
    final lecciones = leccionesDesdeCero();
    expect(lecciones, hasLength(DesdeCeroRepositorio.totalLecciones));
    for (final l in lecciones) {
      expect(l.pasos.length, inInclusiveRange(4, 6), reason: l.titulo);
    }
  });

  Future<void> mostrar(WidgetTester tester, Widget pantalla, {double alto = 640}) async {
    // Un teléfono chico (360 × 640 dp): nada debe salirse.
    tester.view.physicalSize = Size(1080, alto * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (llamada) async => null);
    await tester.pumpWidget(DatosApp(repo: repo, child: MaterialApp(home: pantalla)));
    await esperar(tester);
  }

  for (var indice = 0; indice < DesdeCeroRepositorio.totalLecciones; indice++) {
    testWidgets('la lección ${indice + 1} se recorre completa y queda terminada', (tester) async {
      await mostrar(tester, PantallaLeccion(indice: indice));
      final total = leccionesDesdeCero()[indice].pasos.length;
      for (var paso = 0; paso < total; paso++) {
        expect(find.text('Paso ${paso + 1} de $total'), findsOneWidget);
        // Los sonidos que se tocan en este paso existen.
        for (final t in tester.widgetList<TablaSonidos>(find.byType(TablaSonidos))) {
          for (final s in t.sonidos) {
            expect(silabas, contains(s.silaba), reason: s.letras);
          }
        }
        for (final a in tester.widgetList<AdivinaSonido>(find.byType(AdivinaSonido))) {
          for (final s in a.grupos.expand((g) => g)) {
            expect(silabas, contains(s));
          }
        }
        if (find.byType(AdivinaTono).evaluate().isNotEmpty) {
          for (final b in AdivinaTono.bases) {
            for (var t = 1; t <= 4; t++) {
              expect(silabas, contains('$b$t'));
            }
          }
        }
        // Los caracteres para escribir traen sus trazos.
        for (final l in tester.widgetList<LienzoEscritura>(find.byType(LienzoEscritura))) {
          expect(l.medianas, isNotEmpty, reason: l.caracter);
        }
        await tester.tap(find.text(paso == total - 1 ? 'Terminar' : 'Siguiente'));
        await esperar(tester);
      }
      expect(await tester.runAsync(repo.leccionesTerminadas), {indice});
      await tester.pump(const Duration(seconds: 3)); // vencen los temporizadores de las animaciones
    });
  }

  testWidgets('la lista marca las terminadas y ofrece Estudiar al acabar', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < DesdeCeroRepositorio.totalLecciones - 1; i++) {
        await repo.terminarLeccion(i);
      }
    });
    // Alta, para que quepan las seis (la lista solo arma lo que se ve).
    await mostrar(tester, const PantallaDesdeCero(), alto: 1600);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(DesdeCeroRepositorio.totalLecciones - 1));
    expect(find.text('Ir a Estudiar'), findsNothing);

    await tester.runAsync(() => repo.terminarLeccion(DesdeCeroRepositorio.totalLecciones - 1));
    await mostrar(tester, const PantallaDesdeCero(key: ValueKey(2)), alto: 1600);
    expect(find.text('Ir a Estudiar'), findsOneWidget);
  });

  /// El inicio hace muchas consultas (y pasa de pantalla en pantalla).
  Future<void> esperarInicio(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox()); // apaga los relojes del inicio
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('tras el tutorial pregunta; desde cero pone candados que se pueden quitar', (tester) async {
    await tester.runAsync(repo.marcarTutorialVisto);
    await mostrar(tester, const PantallaInicio(), alto: 800);
    await esperarInicio(tester);
    expect(find.text('¿Nunca has estudiado chino?'), findsOneWidget);

    await tester.tap(find.text('Empezar desde cero'));
    await esperarInicio(tester);
    // Va directo a las lecciones.
    expect(find.byType(PantallaDesdeCero), findsOneWidget);
    expect(find.text('Al terminarlas se abren Estudiar, Leer y Practicar.'), findsOneWidget);
    expect(await tester.runAsync(repo.rutaDesdeCero), RutaDesdeCero.enCurso);

    Navigator.of(tester.element(find.byType(PantallaDesdeCero))).pop();
    await esperarInicio(tester);
    expect(find.text('Chino desde cero · 0/6'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3)); // Estudiar, Leer, Practicar

    // Con candado no se abre: explica por qué.
    await tester.tap(find.text('Leer'));
    await esperarInicio(tester);
    expect(find.text('Primero, «Chino desde cero»'), findsOneWidget);
    expect(find.byType(PantallaBiblioteca), findsNothing);

    await tester.tap(find.text('Ya sé lo básico: desbloquear todo'));
    await esperarInicio(tester);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.text('Chino desde cero · 0/6'), findsNothing);
    expect(await tester.runAsync(repo.rutaDesdeCero), RutaDesdeCero.omitida);
    await cerrar(tester);
  });

  testWidgets('omitir la pregunta deja todo abierto y sin lecciones en el inicio', (tester) async {
    await tester.runAsync(repo.marcarTutorialVisto);
    await mostrar(tester, const PantallaInicio(), alto: 800);
    await esperarInicio(tester);
    await tester.tap(find.text('Omitir'));
    await esperarInicio(tester);
    expect(find.text('Estudiar'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.textContaining('Chino desde cero'), findsNothing);
    expect(await tester.runAsync(repo.rutaDesdeCero), RutaDesdeCero.omitida);
    await cerrar(tester);
  });

  testWidgets('al terminar las seis, el inicio lo festeja y abre todo', (tester) async {
    await tester.runAsync(() async {
      await repo.marcarTutorialVisto();
      await repo.guardarAvisarVersiones(false); // sin la pregunta de versiones nuevas
      await repo.elegirDesdeCero(true);
      await terminarTodas();
    });
    await mostrar(tester, const PantallaInicio(), alto: 800);
    await esperarInicio(tester);
    expect(find.text('🎉 ¡Terminaste «Chino desde cero»!'), findsOneWidget);
    await tester.tap(find.text('Después'));
    await esperarInicio(tester);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.textContaining('Chino desde cero'), findsNothing);
    expect(await tester.runAsync(repo.rutaDesdeCero), RutaDesdeCero.terminada);
    await cerrar(tester);
  });

  testWidgets('la lista festeja la última lección y lleva a Estudiar', (tester) async {
    await tester.runAsync(() async {
      await repo.elegirDesdeCero(true);
      await terminarTodas();
    });
    await mostrar(tester, const PantallaDesdeCero(), alto: 1600);
    await esperarInicio(tester);
    expect(find.text('🎉 ¡Terminaste «Chino desde cero»!'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ir a Estudiar').last);
    await esperarInicio(tester);
    expect(find.byType(PantallaModo), findsOneWidget);
    expect(await tester.runAsync(repo.rutaDesdeCero), RutaDesdeCero.terminada);
    await cerrar(tester);
  });

  Future<double?> alturaEnAjustes(WidgetTester tester, String texto) async {
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Créditos y licencias'), 400, scrollable: scroll);
    await tester.drag(scroll, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));
    final f = find.text(texto);
    return f.evaluate().isEmpty ? null : tester.getTopLeft(f).dy;
  }

  testWidgets('en Ajustes va al final de la lista, salvo mientras lo cursas', (tester) async {
    await tester.runAsync(() => repo.elegirDesdeCero(true));
    await mostrar(tester, const PantallaAjustes(), alto: 1600);
    await esperarInicio(tester);
    expect(await alturaEnAjustes(tester, 'Chino desde cero'), isNull);
    await cerrar(tester);

    await tester.runAsync(() => repo.elegirDesdeCero(false));
    await mostrar(tester, const PantallaAjustes(key: ValueKey(2)), alto: 1600);
    await esperarInicio(tester);
    final desdeCero = await alturaEnAjustes(tester, 'Chino desde cero');
    final creditos = await alturaEnAjustes(tester, 'Créditos y licencias');
    expect(desdeCero, isNotNull);
    expect(desdeCero!, greaterThan(creditos!));
    await cerrar(tester);
  });

  testWidgets('¿qué tono oíste? cuenta los aciertos y sigue', (tester) async {
    await mostrar(tester, Scaffold(body: Center(child: AdivinaTono(azar: math.Random(7)))));
    expect(find.text('Toca «Escuchar» y elige.'), findsOneWidget);
    // Se elige la primera de las cuatro opciones (sea o no la correcta).
    final opciones = find.descendant(of: find.byType(Wrap), matching: find.byType(Text));
    await tester.tap(opciones.first);
    await tester.pump();
    expect(find.textContaining(' de 1'), findsOneWidget);
    await tester.tap(find.text('Otra'));
    await tester.pump();
    expect(find.text('Toca «Escuchar» y elige.'), findsOneWidget);
  });
}

/// Las consultas a la base (los trazos) son asíncronas de verdad.
Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

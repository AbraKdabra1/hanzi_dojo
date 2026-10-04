// Pruebas de helpers/energia.dart y de la pantalla "Batería y fluidez".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/helpers/energia.dart';
import 'package:hanzi_dojo/screens/pantalla_bateria.dart';

const _canal = MethodChannel('hanzi_dojo/energia');

void main() {
  group('LecturaBateria', () {
    test('la corriente se interpreta en µA o mA y sin importar el signo', () {
      expect(LecturaBateria.interpretarCorriente(-350000), 350);
      expect(LecturaBateria.interpretarCorriente(350000), 350);
      expect(LecturaBateria.interpretarCorriente(420), 420); // teléfono que da mA
      expect(LecturaBateria.interpretarCorriente(null), isNull);
      expect(LecturaBateria.interpretarCorriente(0), isNull);
    });

    test('capacidad a partir de lo que queda y el porcentaje', () {
      expect(LecturaBateria.capacidad(2450000, 50), closeTo(4900, 0.01));
      expect(LecturaBateria.capacidad(null, 50), isNull);
      expect(LecturaBateria.capacidad(100, 50), isNull); // absurdo: no se inventa
    });

    test('desde el mapa de Android; cargando no cuenta la corriente', () {
      final l = LecturaBateria.desdeMapa({
        'nivel': 50,
        'corriente': -490000,
        'contador': 2450000,
        'cargando': false,
        'temperatura': 312,
        'tasa': 120.0,
      });
      expect(l.miliamperios, 490);
      expect(l.porcentajePorHora, closeTo(10, 0.01));
      expect(l.temperatura, closeTo(31.2, 1e-9));
      expect(l.tasaPantalla, 120);

      final cargando = LecturaBateria.desdeMapa({'nivel': 80, 'corriente': 900000, 'cargando': true});
      expect(cargando.miliamperios, isNull);
      expect(cargando.porcentajePorHora, isNull);
    });
  });

  test('la medición acumula y calcula el promedio', () {
    LecturaBateria lectura(int nivel, int ua) =>
        LecturaBateria.desdeMapa({'nivel': nivel, 'corriente': ua, 'contador': nivel * 49000, 'cargando': false});
    final m = MedicionConsumo.nueva().con(lectura(80, 400000), 0).con(lectura(79, 600000), 15);
    expect(m.muestras, 2);
    expect(m.promedioMa, 500);
    expect(m.segundosEnPantalla, 15);
    expect(m.bajo, 1);
    expect(m.huboCarga, isFalse);
  });

  testWidgets('120 Hz al tocar, se suelta al quedarse quieta; máxima y ahorro', (tester) async {
    final pedidos = <bool>[];
    var ahorro = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_canal, (llamada) async {
      if (llamada.method == 'fluidez') pedidos.add((llamada.arguments as Map)['alta'] as bool);
      if (llamada.method == 'ahorro') return ahorro;
      return null;
    });

    await Energia.iniciar(ModoFluidez.automatica);
    expect(pedidos, [false]);
    pedidos.clear();

    // Muchos eventos del dedo = un solo aviso a Android.
    Energia.actividad();
    Energia.actividad();
    expect(pedidos, [true]);

    await tester.pump(const Duration(milliseconds: 1000));
    Energia.actividad(); // sigue tocando
    await tester.pump(const Duration(milliseconds: 600)); // 1.6 s: no se suelta aún
    expect(Energia.pidiendoTasaAlta, isTrue);
    await tester.pump(const Duration(milliseconds: 1600)); // quieta: se suelta
    expect(Energia.pidiendoTasaAlta, isFalse);
    expect(pedidos, [true, false]);

    // Siempre al máximo: se pide una vez y los toques no cambian nada.
    pedidos.clear();
    await Energia.cambiarModo(ModoFluidez.maxima);
    Energia.actividad();
    expect(pedidos, [true]);

    // Con ahorro de batería no se piden 120 Hz ni en modo máximo.
    ahorro = true;
    pedidos.clear();
    await Energia.alVolver();
    expect(Energia.ahorro.value, isTrue);
    expect(pedidos, [false]);
    await Energia.cambiarModo(ModoFluidez.automatica);
    pedidos.clear();
    Energia.actividad();
    expect(pedidos, isEmpty);

    ahorro = false;
    await Energia.alVolver();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_canal, null);
  });

  testWidgets('la pantalla muestra el consumo y las opciones de fluidez', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_canal, (llamada) async {
      if (llamada.method == 'bateria') {
        return {'nivel': 50, 'corriente': -420000, 'contador': 2450000, 'cargando': false, 'temperatura': 312, 'tasa': 60.0};
      }
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: PantallaBateria()));
    await tester.pump();
    await tester.pump();
    expect(find.text('420 mA'), findsOneWidget);
    expect(find.text('−8.6 % por hora'), findsOneWidget);
    expect(find.text('60 Hz'), findsOneWidget);
    expect(find.text('Automática (recomendada)'), findsOneWidget);
    expect(find.text('Siempre al máximo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // apaga el reloj de la pantalla
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_canal, null);
  });
}

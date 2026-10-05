// Buscar dibujando: el reconocedor encuentra el carácter aunque el dibujo
// esté movido, de otro tamaño, tembloroso o con dos trazos en otro orden.
//   flutter test test/reconocedor_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/helpers/reconocedor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

void main() {
  test('remuestrear reparte los puntos a lo largo del trazo', () {
    final r = Reconocedor.remuestrear(const [Offset(0, 0), Offset(10, 0)], 6);
    expect(r.length, 6);
    expect(r.first, const Offset(0, 0));
    expect(r.last, const Offset(10, 0));
    expect(r[1].dx, closeTo(2, 1e-9));
    expect(Reconocedor.remuestrear(const [Offset(3, 4)], 4), List.filled(4, const Offset(3, 4)));
  });

  test('normalizar: mismo resultado sin importar posición ni tamaño', () {
    final a = Reconocedor.normalizar(const [
      [Offset(0, 0), Offset(100, 0)],
      [Offset(50, -50), Offset(50, 50)],
    ]);
    final b = Reconocedor.normalizar(const [
      [Offset(300, 300), Offset(320, 300)],
      [Offset(310, 290), Offset(310, 310)],
    ]);
    for (var t = 0; t < 2; t++) {
      for (var i = 0; i < Reconocedor.puntosPorTrazo; i++) {
        expect((a[t][i] - b[t][i]).distance, lessThan(1e-9));
      }
    }
  });

  group('con los caracteres HSK reales', () {
    late Directory carpeta;
    late BaseDatos base;
    late List<ModeloTrazos> modelos;
    late Map<String, List<List<Offset>>> medianas;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_reconocedor');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      final filas = await Repositorio(base).medianasHsk();
      modelos = [for (final (c, json) in filas) Reconocedor.modeloDeJson(c, json)];
      medianas = {};
      for (final c in ['好', '我', '学', '人', '水', '国']) {
        final (_, json) = filas.firstWhere((f) => f.$1 == c);
        final m = Reconocedor.modeloDeJson(c, json); // solo para saber cuántos trazos
        expect(m.trazos, isNotEmpty);
        medianas[c] = _medianasDe(json);
      }
    });

    tearDownAll(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('hay modelo para los 3,000 caracteres HSK', () {
      expect(modelos.length, 3000);
    });

    test('un dibujo movido, escalado y tembloroso se reconoce primero', () {
      final azar = Random(5);
      for (final MapEntry(key: c, value: m) in medianas.entries) {
        // Pantalla: y hacia abajo, en otro lugar y tamaño, con temblor.
        final dibujo = [
          for (final t in m)
            [for (final p in t) Offset(p.dx * 0.4 + 60 + azar.nextDouble() * 8, -p.dy * 0.4 + 400 + azar.nextDouble() * 8)],
        ];
        final r = Reconocedor.buscar(dibujo, modelos);
        expect(r.first, c, reason: 'candidatos: ${r.take(5).join()}');
      }
    });

    test('con dos trazos en otro orden sigue entre los primeros', () {
      final m = medianas['学']!;
      final dibujo = [for (final t in m) [for (final p in t) Offset(p.dx, -p.dy)]];
      final tmp = dibujo[0];
      dibujo[0] = dibujo[1];
      dibujo[1] = tmp;
      expect(Reconocedor.buscar(dibujo, modelos).take(5), contains('学'));
    });

    test('sin trazos no hay candidatos', () {
      expect(Reconocedor.buscar(const [], modelos), isEmpty);
    });
  });
}

List<List<Offset>> _medianasDe(String json) => [
      for (final t in jsonDecode(json) as List)
        [for (final p in t as List) Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())],
    ];

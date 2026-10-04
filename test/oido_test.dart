// Pruebas de la práctica de oído (datos/oido.dart) y de sus tablas.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/oido.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/helpers/pinyin_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Caracter _c(int id, String caracter, String pinyin, String pinyinNum, {String otras = ''}) => Caracter(
      id: id,
      caracter: caracter,
      pinyin: pinyin,
      pinyinNum: pinyinNum,
      otrasLecturas: otras,
      significadoEs: 'x',
      significadoEn: 'x',
      nivelHsk: 1,
      nivelEscritura: null,
      radical: 1,
      numTrazos: 1,
      esFormaRadical: false,
    );

void main() {
  test('conTono pone el acento donde va', () {
    expect(PinyinHelper.conTono('ma', 3), 'mǎ');
    expect(PinyinHelper.conTono('lv', 4), 'lǜ');
    expect(PinyinHelper.conTono('gui', 4), 'guì');
    expect(PinyinHelper.conTono('liu', 2), 'liú');
    expect(PinyinHelper.conTono('zhou', 1), 'zhōu');
    expect(PinyinHelper.conTono('xue', 2), 'xué');
    expect(PinyinHelper.conTono('ma', 5), 'ma');
  });

  test('partirClave', () {
    expect(partirClave('zhang3'), ('zhang', 3));
    expect(partirClave('ma'), ('ma', 5));
  });

  test('tonos: solo sílabas con los cuatro tonos y de los tonos pedidos', () {
    final silabas = {'ma1', 'ma2', 'ma3', 'ma4', 'ma5', 'zhi1', 'zhi2', 'zhi3', 'zhi4', 'bie2', '_ng2'};
    final g = GeneradorTonos(silabas: silabas, frecuencia: {'ma': 10}, azar: math.Random(1));
    expect(g.bases.toSet(), {'ma', 'zhi'});
    String? anterior;
    for (var i = 0; i < 40; i++) {
      final p = g.siguiente([2, 3]);
      expect(p.opciones, [2, 3]);
      expect([2, 3], contains(p.tono));
      expect(silabas, contains(p.clave));
      expect(p.clave, isNot(anterior)); // no repite la misma seguida
      anterior = p.clave;
    }
  });

  test('escucha: cuatro opciones que suenan distinto, con el correcto', () {
    final candidatos = [
      _c(1, '妈', 'mā', 'ma1'),
      _c(2, '麻', 'má', 'ma2'),
      _c(3, '马', 'mǎ', 'ma3'),
      _c(4, '骂', 'mà', 'ma4'),
      _c(5, '吗', 'ma', 'ma5'),
      _c(6, '八', 'bā', 'ba1'),
      _c(7, '爸', 'bà', 'ba4'),
      _c(8, '他', 'tā', 'ta1'),
      _c(9, '她', 'tā', 'ta1'), // homófono de 他: nunca juntos
    ];
    final silabas = {'ma1', 'ma2', 'ma3', 'ma4', 'ma5', 'ba1', 'ba4', 'ta1'};
    final g = GeneradorEscucha(candidatos: candidatos, silabas: silabas, azar: math.Random(3));
    expect(g.alcanza, isTrue);
    for (var i = 0; i < 30; i++) {
      final p = g.siguiente();
      expect(p.opciones, hasLength(4));
      expect(p.opciones.map((o) => o.id), contains(p.correcto.id));
      expect(p.opciones.map((o) => o.pinyinNum).toSet(), hasLength(4), reason: 'sin homófonos');
      expect(p.silaba, p.correcto.pinyinNum);
    }
  });

  test('pinyin: número, acentos, otras lecturas y tono equivocado', () {
    final hao = _c(1, '好', 'hǎo', 'hao3', otras: 'hào');
    final le = _c(2, '了', 'le', 'le5', otras: 'liǎo');
    final nv = _c(3, '女', 'nǚ', 'nv3');
    expect(revisarPinyin('hao3', hao), ResultadoPinyin.correcto);
    expect(revisarPinyin('hǎo', hao), ResultadoPinyin.correcto);
    expect(revisarPinyin(' hao 4 ', hao), ResultadoPinyin.correcto); // otra lectura
    expect(revisarPinyin('hao1', hao), ResultadoPinyin.tonoEquivocado);
    expect(revisarPinyin('hao', hao), ResultadoPinyin.tonoEquivocado);
    expect(revisarPinyin('gao3', hao), ResultadoPinyin.incorrecto);
    expect(revisarPinyin('le', le), ResultadoPinyin.correcto); // neutro sin número
    expect(revisarPinyin('liao3', le), ResultadoPinyin.correcto);
    expect(revisarPinyin('nü3', nv), ResultadoPinyin.correcto);
    expect(revisarPinyin('nv3', nv), ResultadoPinyin.correcto);
    expect(revisarPinyin('', hao), ResultadoPinyin.incorrecto);
  });

  group('tablas de sesiones y oído', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_oido');
      base = await BaseDatos.abrir(
        carpeta: carpeta.path,
        cargarContenido: () async => ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes()),
      );
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('aciertos por tono se acumulan', () async {
      await repo.registrarOido('tono', '3', true);
      await repo.registrarOido('tono', '3', false);
      await repo.registrarOido('tono', '1', true);
      final e = await repo.estadisticasOido('tono');
      expect(e['3'], (1, 2));
      expect(e['1'], (1, 1));
    });

    test('una sesión cuenta como actividad del día (racha y calendario)', () async {
      final hoy = DateTime.now();
      await repo.guardarSesion(tipo: 'tonos', inicio: hoy, segundos: 120, preguntas: 10, aciertos: 8);
      final dias = await repo.actividadPorDia();
      expect(dias, hasLength(1));
      expect(dias.single.repasos, 10);
      expect(dias.single.segundos, 120);
    });

    test('el respaldo lleva las sesiones y el oído, y se pueden importar', () async {
      await repo.guardarSesion(tipo: 'escucha', inicio: DateTime.now(), segundos: 60, preguntas: 10, aciertos: 6);
      await repo.registrarOido('tono', '2', true);
      final bytes = await Respaldo.exportar(base.db);
      final datos = Respaldo.leer(bytes);
      expect(datos.extras['sesiones'], hasLength(1));
      expect(datos.extras['practica_oido'], hasLength(1));

      await base.db.delete('sesiones');
      await base.db.delete('practica_oido');
      await Respaldo.importar(base, datos);
      expect(await base.db.query('sesiones'), hasLength(1));
      expect((await repo.estadisticasOido('tono'))['2'], (1, 1));
    });

    test('caracteres de niveles y frecuencia de sílabas', () async {
      final hsk1 = await repo.caracteresDeNiveles(1);
      expect(hsk1, hasLength(300));
      final frecuencia = await repo.frecuenciaSilabas();
      expect(frecuencia['shi'], greaterThan(10));
    });
  });
}

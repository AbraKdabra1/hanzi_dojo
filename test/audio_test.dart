// Pruebas de datos/audio.dart: qué grabaciones se tocan para cada texto.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/audio.dart';

void main() {
  group('claveSilaba', () {
    test('marcas de tono y números', () {
      expect(Audio.claveSilaba('zhǎng'), 'zhang3');
      expect(Audio.claveSilaba('Wǒ'), 'wo3');
      expect(Audio.claveSilaba('xiān'), 'xian1');
      expect(Audio.claveSilaba('hao3'), 'hao3');
      expect(Audio.claveSilaba('ma'), 'ma5'); // sin marca = tono neutro
    });

    test('ü se escribe v, salvo después de j, q, x, y', () {
      expect(Audio.claveSilaba('lǜ'), 'lv4');
      expect(Audio.claveSilaba('nǚ'), 'nv3');
      expect(Audio.claveSilaba('lu:4'), 'lv4');
      expect(Audio.claveSilaba('jü'), 'ju5');
      expect(Audio.claveSilaba('yuè'), 'yue4');
    });

    test('erhua: la r final se omite, pero er es sílaba', () {
      expect(Audio.claveSilaba('huàr'), 'hua4');
      expect(Audio.claveSilaba('ér'), 'er2');
    });

    test('vacío', () {
      expect(Audio.claveSilaba(''), isNull);
      expect(Audio.claveSilaba('，'), isNull);
    });
  });

  group('silabaDisponible', () {
    const silabas = {'ma1', 'jv4', '_ng2', 'er2'};

    test('exacta, interjección, jv y tono neutro', () {
      expect(Audio.silabaDisponible('ér', silabas), 'er2');
      expect(Audio.silabaDisponible('ńg', silabas), '_ng2');
      expect(Audio.silabaDisponible('jù', silabas), 'jv4');
      expect(Audio.silabaDisponible('ma', silabas), 'ma1');
      expect(Audio.silabaDisponible('mā', silabas), 'ma1');
      expect(Audio.silabaDisponible('mǎ', silabas), isNull);
    });
  });

  test('nombrePalabra', () {
    expect(Audio.nombrePalabra('图书馆'), '56fe-4e66-9986');
    expect(Audio.nombrePalabra('我'), '6211');
  });

  group('planDeLectura', () {
    const palabras = {'图书馆', '我', '去', '你好', '再见'};
    const silabas = {'wo3', 'qu4', 'tu2'};

    List<String> nombres(PlanLectura p) => [for (final c in p.clips) c.toString()];

    test('sin pinyin: palabras y caracteres grabados', () {
      final plan = Audio.planDeLectura('我去图书馆。', palabras: palabras, silabas: silabas);
      expect(nombres(plan), ['6211.opus', '53bb.opus', '56fe-4e66-9986.opus']);
      expect(plan.completo, isTrue);
      expect(plan.caracteres, 5);
    });

    test('con pinyin: los caracteres sueltos usan su sílaba en el texto', () {
      final plan = Audio.planDeLectura(
        '我去图书馆。',
        pinyin: ['wǒ', 'qù', 'tú', 'shū', 'guǎn', ''],
        palabras: palabras,
        silabas: silabas,
      );
      expect(nombres(plan), ['wo3.opus', 'qu4.opus', '56fe-4e66-9986.opus']);
    });

    test('la puntuación es una pausa (y no al final)', () {
      final plan = Audio.planDeLectura('你好，再见。', palabras: palabras, silabas: silabas);
      expect(nombres(plan), ['4f60-597d.opus', 'pausa(250)', '518d-89c1.opus']);
      expect(plan.grabaciones, 2);
    });

    test('sin grabación', () {
      final plan = Audio.planDeLectura('龘', palabras: palabras, silabas: silabas);
      expect(plan.clips, isEmpty);
      expect(plan.completo, isFalse);
      expect(plan.caracteres, 1);
    });
  });

  group('pinyin por palabras', () {
    const silabas = {'wo3', 'xi3', 'huan1', 'chi1', 'ping2', 'guo3', 'zou3', 'kai1', 'bie2', 'zai4', 'zhe4', 'wan2'};

    test('se parte en sílabas', () {
      expect(Audio.silabasDePinyin('Wǒ xǐhuan chī píngguǒ.', silabas),
          ['Wǒ', 'xǐ', 'huan', 'chī', 'píng', 'guǒ']);
    });

    test('se alinea con el texto, con erhua', () {
      expect(
        Audio.alinearPinyin('走开！别在这儿玩儿。', 'zǒukāi! bié zài zhèr wánr.', silabas),
        ['zǒu', 'kāi', '', 'bié', 'zài', 'zhèr', '', 'wánr', '', ''],
      );
    });

    test('si no cuadra, null', () {
      expect(Audio.alinearPinyin('我吃', 'wǒ', silabas), isNull);
      expect(Audio.alinearPinyin('我', 'wǒ chī', silabas), isNull);
    });
  });

  test('cada grabación de las listas existe con el nombre que espera la app', () {
    final palabras = File('assets/audio/palabras.txt').readAsLinesSync().where((l) => l.isNotEmpty);
    final silabas = File('assets/audio/silabas.txt').readAsLinesSync().where((l) => l.isNotEmpty);
    expect(palabras.length, greaterThan(8000));
    expect(silabas.length, 1707);
    for (final p in palabras) {
      expect(File('assets/audio/palabras/${Audio.nombrePalabra(p)}.opus').existsSync(), isTrue, reason: p);
    }
    for (final s in silabas) {
      expect(File('assets/audio/silabas/$s.opus').existsSync(), isTrue, reason: s);
    }
  });

  test('cada grabación sabe qué parte del texto suena (para resaltarla)', () {
    final plan = Audio.planDeLectura('我去图书馆。',
        palabras: const {'图书馆', '我'}, silabas: const {'qu4'}, pinyin: const ['wǒ', 'qù', 'tú', 'shū', 'guǎn', '']);
    final rangos = [for (final c in plan.clips) if (!c.esPausa) (c.inicio, c.fin)];
    expect(rangos, [(0, 1), (1, 2), (2, 5)]);
  });
}

// Pruebas de datos/audio.dart: qué grabaciones se tocan para cada texto.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/audio.dart';
import 'package:hanzi_dojo/helpers/grabaciones.dart';
import 'package:hanzi_dojo/helpers/ogg_a_caf.dart';

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

  group('Recortes (leer de corrido)', () {
    test('clave de cada grabación en recortes.txt', () {
      expect(Clip.silaba('ma1').claveRecorte, 's/ma1');
      expect(Clip.palabra('56fe-4e66-9986').claveRecorte, 'p/56fe-4e66-9986');
      expect(const Clip.pausa(250).claveRecorte, isNull);
    });

    test('se leen las líneas válidas e ignoran comentarios y basura', () {
      final r = Audio.leerRecortes('# comentario\ns/ma1 31 545\np/4e00 20 800\nmal\ns/x1 9 3\n');
      expect(r, {'s/ma1': (31, 545), 'p/4e00': (20, 800)});
    });

    test('cada grabación tiene su recorte y deja la mayor parte del audio', () {
      final r = Audio.leerRecortes(File('assets/audio/recortes.txt').readAsStringSync());
      final palabras = File('assets/audio/palabras.txt').readAsLinesSync().where((l) => l.isNotEmpty);
      final silabas = File('assets/audio/silabas.txt').readAsLinesSync().where((l) => l.isNotEmpty);
      for (final p in palabras) {
        final recorte = r['p/${Audio.nombrePalabra(p)}'];
        expect(recorte, isNotNull, reason: p);
        expect(recorte!.$2 - recorte.$1, greaterThan(150), reason: p);
      }
      for (final s in silabas) {
        final recorte = r['s/$s'];
        expect(recorte, isNotNull, reason: s);
        expect(recorte!.$2 - recorte.$1, greaterThan(150), reason: s);
      }
    });
  });

  group('Grabaciones en iOS', () {
    test('nombre del CAF reempacado (uno por grabación, sin chocar)', () {
      expect(Grabaciones.nombreCaf('assets/audio/silabas/ma1.opus'), 'audio_silabas_ma1.caf');
      expect(Grabaciones.nombreCaf('assets/audio/palabras/一下.opus'), 'audio_palabras_一下.caf');
      expect(Grabaciones.nombreCaf('assets/sonidos/pincel.opus'), 'sonidos_pincel.caf');
    });

    test('en la computadora (y en Android) no se reempaca nada', () {
      expect(Grabaciones.enIos, isFalse);
    });

    test('reempacar termina, también con dos botones a la vez, y la segunda vez ya está listo', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const ruta = 'assets/audio/silabas/ma1.opus';
      final rutas = await Future.wait([Grabaciones.archivoCaf(ruta), Grabaciones.archivoCaf(ruta)])
          .timeout(const Duration(seconds: 20));
      expect(rutas[0], rutas[1]);
      expect(String.fromCharCodes(File(rutas[0]).readAsBytesSync().take(4)), 'caff');
      expect(await Grabaciones.archivoCaf(ruta).timeout(const Duration(seconds: 5)), rutas[0]);
    });

    test('todas las grabaciones son Ogg (lo que se reempaca en iOS)', () {
      for (final carpeta in ['assets/audio/silabas', 'assets/audio/palabras', 'assets/sonidos']) {
        final archivos = Directory(carpeta).listSync().whereType<File>().where((f) => f.path.endsWith('.opus'));
        for (final f in archivos.take(200)) {
          final cabecera = f.openSync()..setPositionSync(0);
          final bytes = cabecera.readSync(4);
          cabecera.closeSync();
          expect(String.fromCharCodes(bytes), 'OggS', reason: f.path);
        }
      }
    });
  });

  group('Ogg → CAF (iPhone)', () {
    int u32(Uint8List b, int i) => ByteData.sublistView(b).getUint32(i);
    int u64(Uint8List b, int i) => u32(b, i) * 0x100000000 + u32(b, i + 4);
    int i32(Uint8List b, int i) => ByteData.sublistView(b).getInt32(i);

    /// Bloques del CAF: tipo → (inicio del contenido, tamaño).
    Map<String, (int, int)> bloques(Uint8List caf) {
      final r = <String, (int, int)>{};
      var i = 8;
      while (i < caf.length) {
        final tipo = String.fromCharCodes(caf.sublist(i, i + 4));
        final tamano = u64(caf, i + 4);
        r[tipo] = (i + 12, tamano);
        i += 12 + tamano;
      }
      expect(i, caf.length, reason: 'los bloques cubren el archivo exacto');
      return r;
    }

    test('ma1: misma cuenta que una conversión de referencia validada con ffprobe', () {
      final caf = OggACaf.convertir(File('assets/audio/silabas/ma1.opus').readAsBytesSync());
      expect(String.fromCharCodes(caf.sublist(0, 4)), 'caff');
      expect(caf.length, 1584);
      final b = bloques(caf);
      expect(b.keys, ['desc', 'chan', 'pakt', 'data']);
      final (desc, _) = b['desc']!;
      expect(ByteData.sublistView(caf).getFloat64(desc), 48000);
      expect(String.fromCharCodes(caf.sublist(desc + 8, desc + 12)), 'opus');
      expect(u32(caf, desc + 20), 960); // muestras por paquete
      expect(u32(caf, desc + 24), 1); // mono
      final (pakt, _) = b['pakt']!;
      expect(u64(caf, pakt), 29); // paquetes
      expect(u64(caf, pakt + 8), 27360); // muestras válidas
      expect(i32(caf, pakt + 16), 312); // pre-skip
      expect(i32(caf, pakt + 20), 168); // sobrantes
    });

    test('todas las grabaciones se pueden reempacar', () {
      final archivos = [
        ...Directory('assets/audio/silabas').listSync().whereType<File>().take(300),
        ...Directory('assets/audio/palabras').listSync().whereType<File>().take(300),
        File('assets/sonidos/pincel.opus'),
        File('assets/sonidos/silencio.opus'),
      ];
      for (final f in archivos) {
        final caf = OggACaf.convertir(f.readAsBytesSync());
        final b = bloques(caf);
        final (datos, tamano) = b['data']!;
        expect(tamano, greaterThan(4), reason: f.path);
        expect(datos + tamano, caf.length, reason: f.path);
      }
    });

    test('enteros de 7 bits como los pide CAF', () {
      expect(OggACaf.entero7(79), [79]);
      expect(OggACaf.entero7(128), [0x81, 0x00]);
      expect(OggACaf.entero7(300), [0x82, 0x2C]);
    });

    test('muestras por paquete según el primer byte (RFC 6716)', () {
      expect(OggACaf.muestrasDePaquete(Uint8List.fromList([0xF8])), 960); // CELT 20 ms
      expect(OggACaf.muestrasDePaquete(Uint8List.fromList([0x09])), 960 * 2); // SILK 20 ms, 2 tramas iguales
      expect(OggACaf.muestrasDePaquete(Uint8List.fromList([0x03, 0x03])), 480 * 3); // SILK 10 ms, 3 tramas
    });

    test('lo que no es Ogg Opus se rechaza', () {
      expect(() => OggACaf.convertir(Uint8List.fromList(List.filled(40, 1))), throwsFormatException);
    });
  });
}

// Pruebas de «Mis libros»: leer TXT (UTF-8, UTF-16, GBK) y EPUB, partir en
// capítulos, pinyin automático, nivel estimado y guardar/borrar en la base.
//   flutter test test/mis_libros_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/importar_libro.dart';
import 'package:hanzi_dojo/datos/modelos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

Uint8List _archivo(String ruta) => File(ruta).readAsBytesSync();

void main() {
  late Directory carpeta;
  late BaseDatos base;
  late Repositorio repo;
  late String tablaGbk;
  late DiccionarioLectura diccionario;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_mis_libros');
    base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
    repo = Repositorio(base);
    tablaGbk = await repo.tablaGbk();
    diccionario = await repo.diccionarioLectura();
  });

  tearDown(() async {
    await base.cerrar();
    await carpeta.delete(recursive: true);
  });

  group('Texto', () {
    test('UTF-8 con y sin BOM, UTF-16 con BOM y GBK', () {
      const texto = '你好，世界';
      final u8 = Uint8List.fromList(utf8.encode(texto));
      expect(ImportadorLibros.decodificarTexto(u8, tablaGbk), texto);
      expect(ImportadorLibros.decodificarTexto(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...u8]), tablaGbk), texto);
      final u16 = <int>[0xFF, 0xFE];
      for (final c in texto.codeUnits) {
        u16.addAll([c & 0xFF, c >> 8]);
      }
      expect(ImportadorLibros.decodificarTexto(Uint8List.fromList(u16), tablaGbk), texto);

      final gbk = ImportadorLibros.decodificarTexto(_archivo('test/fixtures/gbk.txt'), tablaGbk);
      expect(gbk, contains('第一章 开始'));
      expect(gbk, contains('今天天气很好。我们去公园。'));
    });

    test('un TXT en GBK con encabezados se parte en capítulos', () {
      final libro = ImportadorLibros.leer('cuento.txt', _archivo('test/fixtures/gbk.txt'), tablaGbk: tablaGbk);
      expect(libro.titulo, 'cuento');
      expect(libro.formato, 'txt');
      expect(libro.capitulos.map((c) => c.titulo), ['第一章 开始', '第二章 结束']);
      expect(libro.capitulos.first.parrafos, ['今天天气很好。我们去公园。']);
    });

    test('sin encabezados: partes de unos 3,000 caracteres; párrafos larguísimos por oraciones', () {
      final parrafo = '今天天气很好，我们一起去公园玩。' * 20; // 320 caracteres
      final texto = List.filled(30, parrafo).join('\n'); // ~9,600 caracteres
      final caps = ImportadorLibros.partirEnCapitulos(texto);
      expect(caps.length, greaterThanOrEqualTo(3));
      expect(caps.first.titulo, 'Parte 1');

      final largo = ImportadorLibros.partirEnCapitulos('我们去公园。' * 200); // una sola línea
      expect(largo.single.parrafos.length, greaterThan(1));
      for (final p in largo.single.parrafos) {
        expect(p.length, lessThanOrEqualTo(ImportadorLibros.largoMaximoParrafo));
        expect(p, endsWith('。'));
      }
    });

    test('archivos que no sirven', () {
      expect(() => ImportadorLibros.leer('a.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7')), tablaGbk: tablaGbk),
          throwsA(isA<LibroInvalido>().having((e) => e.mensaje, 'mensaje', contains('PDF'))));
      expect(() => ImportadorLibros.desdeTexto('x', 'Only English here.'),
          throwsA(isA<LibroInvalido>()));
    });
  });

  group('EPUB', () {
    test('sigue el orden de lectura, salta la portada y limpia el HTML', () {
      final libro = ImportadorLibros.leer('muestra.epub', _archivo('test/fixtures/muestra.epub'), tablaGbk: tablaGbk);
      expect(libro.titulo, '小书');
      expect(libro.formato, 'epub');
      expect(libro.capitulos.map((c) => c.titulo), ['第一章 春天', '第二章 夏天']);
      expect(libro.capitulos.first.parrafos, ['春天来了，花开了。', '小鸟在树上&唱歌：你好！', '汉字很有意思。']);
      expect(libro.capitulos.last.parrafos, ['夏天很热。我们去游泳。', '天气很好。']);
    });

    test('con DRM no se puede leer', () {
      expect(() => ImportadorLibros.leer('drm.epub', _archivo('test/fixtures/drm.epub'), tablaGbk: tablaGbk),
          throwsA(isA<LibroInvalido>().having((e) => e.mensaje, 'mensaje', contains('DRM'))));
    });
  });

  group('Pinyin y nivel', () {
    List<String> py(String s) => ImportadorLibros.pinyinDe(s.split(''), diccionario);

    test('lectura principal, partículas y cambios de tono de 一 y 不', () {
      expect(py('我们不是朋友'), ['wǒ', 'men', 'bú', 'shì', 'péng', 'yǒu']);
      expect(py('一个人'), ['yí', 'gè', 'rén']);
      expect(py('受不了'), ['shòu', 'bù', 'liǎo']);
      expect(py('好的。'), ['hǎo', 'de', '']);
      // Tradicional: se consulta como simplificado.
      expect(py('學習'), ['xué', 'xí']);
    });

    test('nivel estimado: un texto sencillo es HSK 1', () {
      final p = prepararLibro(const PeticionLibro.texto(
          '', '我爱我的妈妈。我的妈妈也爱我。我们是一家人。今天我们去学校。', DiccionarioLectura(
              pinyin: {}, nivel: {}, simplificado: {})));
      // Sin diccionario no hay nivel (todo cuenta como fuera de HSK).
      expect(p.nivelEstimado, 0);

      final real = prepararLibro(PeticionLibro.texto(
          'Mi familia', '我爱我的妈妈。我的妈妈也爱我。我们是一家人。今天我们去学校。', diccionario));
      expect(real.nivelEstimado, 1);
      expect(real.cobertura, greaterThanOrEqualTo(0.9));
      expect(real.libro.titulo, 'Mi familia');
      expect(real.pinyin.single.single.length, real.libro.capitulos.single.parrafos.single.runes.length);
    });
  });

  group('Guardar en la base', () {
    test('guardar, leer, marcar leído y borrar', () async {
      final preparado = prepararLibro(PeticionLibro.archivo(
          'cuento.txt', _archivo('test/fixtures/gbk.txt'), tablaGbk, diccionario));
      final id = await repo.guardarLibroPropio(preparado, archivo: 'cuento.txt');

      final mios = await repo.misLibros();
      expect(mios, hasLength(1));
      final libro = mios.single;
      expect(libro.id, id);
      expect(libro.propio, isTrue);
      expect(libro.clave, Libro.clavePropia(id));
      expect(libro.capitulos, 2);
      expect(libro.formato, 'txt');
      expect(libro.nivelHsk, inInclusiveRange(1, 7));

      final capitulos = await repo.capitulos(libro);
      expect(capitulos.map((c) => c.titulo), ['第一章 开始', '第二章 结束']);
      final parrafos = await repo.parrafos(capitulos.first.id, propio: true);
      expect(parrafos.single.chino, '今天天气很好。我们去公园。');
      expect(parrafos.single.pinyin.first, 'jīn');
      expect(parrafos.single.espanol, isEmpty);

      await repo.marcarCapitulo(libro.clave, 1);
      expect((await repo.misLibros()).single.capitulosLeidos, 1);
      // Los libros de la app no cambian.
      expect((await repo.libros()).every((l) => !l.propio), isTrue);

      await repo.borrarLibroPropio(id);
      expect(await repo.misLibros(), isEmpty);
      final restos = await base.db.rawQuery('SELECT count(*) AS n FROM mis_parrafos');
      expect(restos.first['n'], 0);
      final leido = await base.db.rawQuery('SELECT count(*) AS n FROM lectura');
      expect(leido.first['n'], 0);
    });
  });
}

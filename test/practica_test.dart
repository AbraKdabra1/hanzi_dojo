// Pruebas de la práctica con audio (fase 5):
//   · leer el pinyin que escribe el usuario (pinyin_entrada.dart);
//   · armar preguntas, repartir tonos, elegir palabras nuevas (practica.dart);
//   · consultas con la base real: vocabulario, ejercicios, estadísticas y
//     respaldo (repositorio_practica.dart).
//   flutter test test/practica_test.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/estadisticas.dart';
import 'package:hanzi_dojo/datos/practica.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/datos/repositorio_practica.dart';
import 'package:hanzi_dojo/datos/respaldo.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:hanzi_dojo/helpers/pinyin_entrada.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

final _grabadas = {
  for (final l in File('assets/audio/silabas.txt').readAsLinesSync())
    if (l.trim().isNotEmpty) l.trim(),
};
final _bases = PinyinEntrada.basesDe(_grabadas);

Palabra _p(int id, String palabra, String pinyinNum, String significado) => Palabra(
      id: id,
      palabra: palabra,
      forma: palabra,
      pinyin: '',
      pinyinNum: pinyinNum,
      clase: '',
      nivelHsk: 1,
      significadoEs: significado,
      significadoEn: '',
      audio: true,
    );

void main() {
  group('Pinyin escrito', () {
    test('con acentos a partir de números', () {
      expect(['hao3', 'lv4', 'lu:4', 'ma5', 'gou3', 'gui4', 'liu2', 'er4', 'xue2', 'nv3', '_'].map(PinyinEntrada.numAAcentos),
          ['hǎo', 'lǜ', 'lǜ', 'ma', 'gǒu', 'guì', 'liú', 'èr', 'xué', 'nǚ', '']);
    });

    test('se lee con números, acentos, espacios o sin número (neutro)', () {
      List<String>? a(String s) => PinyinEntrada.analizar(s, _bases);
      expect(a('ni3hao3'), ['ni3', 'hao3']);
      expect(a('ni3 hao3'), ['ni3', 'hao3']);
      expect(a('Nǐhǎo'), ['ni3', 'hao3']);
      expect(a('ba4ba'), ['ba4', 'ba5']);
      expect(a('lv4'), ['lv4']);
      expect(a('lü4'), ['lv4']);
      expect(a('ju4zi5'), ['ju4', 'zi5']);
      expect(a("xi'an"), ['xi5', 'an5']);
      expect(a('xi1an1'), ['xi1', 'an1']); // el número cierra la sílaba
      expect(a('xian1'), ['xian1']); // sin separar, una sola sílaba
      expect(a('zhuang4'), ['zhuang4']);
      expect(a('qqq'), isNull);
      expect(a(''), isNull);
    });

    test('veredicto: correcto, solo tonos o incorrecto, sílaba por sílaba', () {
      final bien = PinyinEntrada.comparar(['ba4', 'ba5'], PinyinEntrada.analizar('ba4ba', _bases));
      expect(bien.veredicto, Veredicto.correcto);
      final tonos = PinyinEntrada.comparar(['ni3', 'hao3'], PinyinEntrada.analizar('ni2hao3', _bases));
      expect(tonos.veredicto, Veredicto.tonos);
      expect(tonos.silabasBien, [false, true]);
      final mal = PinyinEntrada.comparar(['ni3', 'hao3'], PinyinEntrada.analizar('wo3hao3', _bases));
      expect(mal.veredicto, Veredicto.incorrecto);
      expect(PinyinEntrada.comparar(['ni3', 'hao3'], null).veredicto, Veredicto.incorrecto);
      expect(PinyinEntrada.comparar(['ni3', 'hao3'], ['ni3']).silabasBien, [false, false]);
    });

    test('vista previa con acentos mientras escribes', () {
      expect(PinyinEntrada.vistaPrevia('ni3hao', _bases), 'nǐ hao');
      expect(PinyinEntrada.vistaPrevia('zzz', _bases), isNull);
    });
  });

  group('Preguntas', () {
    test('Palabra: claves, tonos y pinyin por carácter (con erhua)', () {
      final p = _p(1, '一点儿', 'yi1 dian3 _', 'un poco');
      expect(p.claves, ['yi1', 'dian3']);
      expect(p.tonos, [1, 3]);
      expect(p.tieneErhua, isTrue);
      expect(p.pinyinPorCaracter, ['yī', 'diǎn', '']);
      expect(_p(2, '句子', 'ju4 zi5', 'oración').claves, ['ju4', 'zi5']);
    });

    test('sílabas para tonos: solo con grabación, tono 1-4 y sin repetir', () {
      final lista = SilabaTono.conGrabacion([
        ('妈', 'ma1', 'mā', 'mamá'),
        ('吗', 'ma5', 'ma', 'partícula'), // neutro: fuera
        ('马', 'ma3', 'mǎ', 'caballo'),
        ('码', 'ma3', 'mǎ', 'código'), // misma sílaba: fuera
        ('句', 'ju4', 'jù', 'oración'),
        ('?', 'qqq9', '', ''),
      ], _grabadas);
      expect(lista.map((s) => s.caracter), ['妈', '马', '句']);
      expect(lista.map((s) => s.tono), [1, 3, 4]);
      expect(_grabadas.contains(lista.last.archivo), isTrue);
    });

    test('ronda de tonos pareja', () {
      final muchas = [
        for (var t = 1; t <= 4; t++)
          for (var i = 0; i < 10; i++) SilabaTono(archivo: 'x$t$i', tono: t, caracter: '', pinyin: '', significado: ''),
      ];
      final ronda = SilabaTono.equilibradas(muchas, 10, Random(1));
      expect(ronda.length, 10);
      for (var t = 1; t <= 4; t++) {
        expect(ronda.where((s) => s.tono == t).length, inInclusiveRange(2, 3));
      }
    });

    test('escucha: sin homófonos ni significados repetidos, del mismo largo', () {
      final objetivo = _p(1, '是', 'shi4', 'ser');
      final otras = [
        _p(2, '事', 'shi4', 'asunto'), // suena igual: nunca
        _p(3, '十', 'shi2', 'diez'),
        _p(4, '吃', 'chi1', 'comer'),
        _p(5, '书', 'shu1', 'libro'),
        _p(6, '学生', 'xue2 sheng5', 'estudiante'),
        _p(7, '在', 'zai4', 'ser'), // mismo significado
      ];
      for (var semilla = 0; semilla < 20; semilla++) {
        final q = PreguntaOpciones.armar(objetivo, otras, Random(semilla), porSignificado: true);
        expect(q.opciones.length, 4);
        expect(q.opciones[q.correcta], objetivo);
        expect(q.opciones.map((p) => p.palabra), isNot(contains('事')));
        expect(q.opciones.map((p) => p.palabra), isNot(contains('在')));
        expect(q.opciones.map((p) => p.palabra), isNot(contains('学生'))); // hay de un carácter
      }
    });

    test('palabra nueva: primero la de caracteres que ya estudiaste', () {
      final candidatas = [(1, '爱好'), (2, '爸爸'), (3, '白天')];
      expect(elegirPalabraNueva(candidatas, {}), 1); // nada conocido: la primera
      expect(elegirPalabraNueva(candidatas, {'爸'}), 2);
      expect(elegirPalabraNueva(candidatas, {'白', '爱'}), 1); // empate a ½: la primera
      expect(elegirPalabraNueva(const [], {'爸'}), isNull);
    });

    test('tonos que confundes', () {
      final c = confusionesDeTono([
        ('ma3', '2'),
        ('hao3', '2'),
        ('ni3 hao3', '2 3'),
        ('ma1', '4'), // una sola vez: no sale
        ('ma2', '2'), // acierto
      ]);
      expect(c.map((x) => (x.esperado, x.elegido, x.veces)), [(3, 2, 3)]);
    });
  });

  group('Con la base real', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_practica');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('el vocabulario HSK está completo y con español en 1-6', () async {
      final hsk1 = await repo.palabrasAlAzar(nivel: 1, cantidad: 1000);
      expect(hsk1.length, greaterThan(450));
      expect(hsk1.every((p) => p.tieneEspanol), isTrue);
      expect(hsk1.every((p) => p.silabas.length == p.palabra.length), isTrue);
      final baba = await repo.palabraPorTexto('爸爸');
      expect(baba!.claves, ['ba4', 'ba5']);
      expect(baba.significado, contains('papá'));
    });

    test('filtros: con audio, de dos caracteres y sin erhua', () async {
      final ps = await repo.palabrasAlAzar(nivel: 3, conAudio: true, caracteres: 2, sinErhua: true, cantidad: 30);
      expect(ps, isNotEmpty);
      expect(ps.every((p) => p.audio && p.palabra.length == 2 && !p.tieneErhua && p.nivelHsk == 3), isTrue);
      final hasta2 = await repo.palabrasAlAzar(nivel: 2, soloEseNivel: false, cantidad: 200);
      expect(hasta2.every((p) => p.nivelHsk <= 2), isTrue);
    });

    test('caracteres para el entrenador de tonos', () async {
      final cs = await repo.caracteresParaTonos(nivel: 1, cantidad: 80);
      final silabas = SilabaTono.conGrabacion(cs, _grabadas);
      expect(silabas.length, greaterThan(20));
      expect(silabas.every((s) => s.tono >= 1 && s.tono <= 4), isTrue);
    });

    test('repaso de palabras: sesión, SM-2 y límite diario', () async {
      final hoy = DateTime.now();
      await repo.guardarLimitePalabrasPorDia(2);
      final sesion = SesionPalabras(FuentePalabrasRepositorio(repo), 1);
      final a = await sesion.siguiente();
      expect(a, isNotNull);
      expect(a!.progreso, isNull);
      await sesion.responder(a, Calificacion.facil);
      final b = await sesion.siguiente();
      await sesion.responder(b!, Calificacion.dificil);
      expect(await repo.nuevasPalabrasHoy(), 2);
      // Límite alcanzado: lo "Difícil" de hace un momento ya vence hoy (mañana
      // en SM-2 = inicio de mañana), así que no sale; termina por el límite.
      final c = await sesion.siguiente();
      if (c != null) {
        expect(c.id, b.id); // solo podría volver la difícil
      } else {
        expect(sesion.fin, FinSesionPalabras.limiteDiario);
      }
      final guardada = await repo.palabra(a.id);
      expect(guardada!.progreso!.intervaloDias, 1);
      expect(await repo.palabrasPendientes(ahora: hoy.add(const Duration(days: 2))), 2);
      final avance = await repo.avancePalabras();
      expect(avance.firstWhere((x) => x.nivel == 1).estudiadas, 2);
    });

    test('las nuevas empiezan por palabras con caracteres que ya estudiaste', () async {
      final ba = await repo.caracterPorTexto('爸');
      await repo.registrarRespuesta(ba!, Calificacion.facil);
      final p = await repo.siguientePalabra(nivel: 1, permitirNuevas: true);
      expect(p!.palabra, contains('爸'));
    });

    test('ejercicios: resumen, tonos confundidos y racha', () async {
      final hoy = DateTime.now();
      await repo.registrarEjercicio(TipoEjercicio.tono, 'ma3', correcto: false, respuesta: '2', duracionMs: 3000);
      await repo.registrarEjercicio(TipoEjercicio.tono, 'hao3', correcto: false, respuesta: '2', duracionMs: 3000);
      await repo.registrarEjercicio(TipoEjercicio.tono, 'ma1', correcto: true, respuesta: '1', duracionMs: 3000);
      await repo.registrarEjercicio(TipoEjercicio.escucha, '图书馆', correcto: true, respuesta: '图书馆');
      final resumen = await repo.resumenEjercicios();
      final tonos = resumen.firstWhere((r) => r.tipo == TipoEjercicio.tono);
      expect((tonos.total, tonos.aciertos), (3, 1));
      expect(resumen.firstWhere((r) => r.tipo == TipoEjercicio.escucha).aciertos, 1);
      final conf = await repo.confusionTonos();
      expect(conf.single.esperado, 3);
      expect(conf.single.elegido, 2);
      // Un día solo de práctica con audio también cuenta para la racha.
      final dias = await repo.actividadPorDia();
      expect(dias.single.repasos, 4);
      expect(Estadisticas.racha(dias.map((d) => d.dia), hoy).actual, 1);
    });

    test('el respaldo lleva el vocabulario y los ejercicios', () async {
      final p = await repo.palabraPorTexto('朋友');
      await repo.registrarPalabra(p!, Calificacion.medio);
      await repo.registrarEjercicio(TipoEjercicio.pinyin, '朋友', correcto: true, respuesta: 'peng2 you5');
      final bytes = await Respaldo.exportar(base.db);
      final datos = Respaldo.leer(bytes);
      expect(datos.progresoPalabras.single['palabra'], '朋友');
      expect(datos.ejercicios.length, 2); // el repaso de la palabra + el pinyin

      // Importar en otra instalación.
      final otra = await Directory.systemTemp.createTemp('hanzi_dojo_practica2');
      final base2 = await BaseDatos.abrir(carpeta: otra.path, cargarContenido: _leerContenido);
      try {
        await Respaldo.importar(base2, datos);
        final repo2 = Repositorio(base2);
        expect((await repo2.palabraPorTexto('朋友'))!.progreso, isNotNull);
        expect((await repo2.resumenEjercicios()).firstWhere((r) => r.tipo == TipoEjercicio.pinyin).total, 1);
      } finally {
        await base2.cerrar();
        await otra.delete(recursive: true);
      }
    });
  });
}

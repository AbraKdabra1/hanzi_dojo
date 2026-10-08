// Aviso de versión nueva: orden de versiones, qué versión y qué APK se
// ofrece, y que se consulte a GitHub como mucho una vez al día.
//   flutter test test/actualizaciones_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/base_datos.dart';
import 'package:hanzi_dojo/datos/repositorio.dart';
import 'package:hanzi_dojo/helpers/actualizaciones.dart';
import 'package:hanzi_dojo/helpers/archivos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ByteData> _leerContenido() async =>
    ByteData.sublistView(await File('assets/db/contenido.db').readAsBytes());

Version _v(String s) => Version.leer(s)!;

Map<String, Object?> _version(String etiqueta, {bool previa = false, bool borrador = false}) => {
      'tag_name': etiqueta,
      'prerelease': previa,
      'draft': borrador,
      'html_url': 'https://github.com/AbraKdabra1/hanzi_dojo/releases/tag/$etiqueta',
      'assets': [
        for (final abi in ['arm32', 'arm64', 'universal', 'x86_64'])
          {
            'name': 'Meizi_Hanzi_${etiqueta.substring(1)}_$abi.apk',
            'browser_download_url': 'https://github.com/descarga/$etiqueta/$abi.apk',
          },
      ],
    };

final _lista = [
  _version('v2.2.0-beta.1', previa: true, borrador: true),
  _version('v2.1.0-beta.3', previa: true),
  _version('v2.1.0-beta.2', previa: true),
  _version('v2.1.0-beta.1', previa: true),
  _version('v2.0.0'),
];

void main() {
  group('Version', () {
    test('se lee con o sin "v" y sin el número de compilación', () {
      expect('${_v('v2.1.0-beta.1+3')}', '2.1.0-beta.1');
      expect('${_v('2.1.0')}', '2.1.0');
      expect(_v('2.1.0-beta.1').esPrevia, isTrue);
      expect(_v('2.1.0').esPrevia, isFalse);
      expect(Version.leer('?'), isNull);
      expect(Version.leer('web'), isNull);
      expect(Version.leer(''), isNull);
    });

    test('orden semántico', () {
      final orden = ['2.0.0', '2.1.0-beta.1', '2.1.0-beta.2', '2.1.0-beta.10', '2.1.0', '2.1.1', '2.10.0'];
      for (var i = 0; i + 1 < orden.length; i++) {
        expect(_v(orden[i + 1]) > _v(orden[i]), isTrue, reason: '${orden[i + 1]} > ${orden[i]}');
        expect(_v(orden[i]) > _v(orden[i + 1]), isFalse);
      }
      expect(_v('2.1').compareTo(_v('2.1.0')), 0);
      expect(_v('2.1.0-alpha') > _v('2.1.0-beta'), isFalse);
    });
  });

  test('el APK de cada procesador', () {
    expect(sufijoApk(['arm64-v8a', 'armeabi-v7a', 'armeabi']), '_arm64.apk');
    expect(sufijoApk(['armeabi-v7a', 'armeabi']), '_arm32.apk');
    expect(sufijoApk(['x86_64', 'x86']), '_x86_64.apk');
    expect(sufijoApk(['x86']), '_universal.apk');
    expect(sufijoApk(const []), '_universal.apk');
  });

  group('elegirVersionNueva', () {
    test('una beta ve la beta más nueva (no los borradores) y su APK', () {
      final nueva = elegirVersionNueva(_lista, _v('2.1.0-beta.1'), abis: ['arm64-v8a'])!;
      expect(nueva.version, '2.1.0-beta.3');
      expect('${nueva.descarga}', 'https://github.com/descarga/v2.1.0-beta.3/arm64.apk');
      expect('${nueva.pagina}', 'https://github.com/AbraKdabra1/hanzi_dojo/releases/tag/v2.1.0-beta.3');
    });

    test('con la más reciente instalada no hay nada', () {
      expect(elegirVersionNueva(_lista, _v('2.1.0-beta.3')), isNull);
    });

    test('una versión estable no ve betas', () {
      expect(elegirVersionNueva(_lista, _v('2.0.0')), isNull);
      final conEstable = [_version('v2.1.0'), ..._lista];
      expect(elegirVersionNueva(conEstable, _v('2.0.0'))!.version, '2.1.0');
      // y una beta sí ve la estable que la reemplaza
      expect(elegirVersionNueva(conEstable, _v('2.1.0-beta.3'))!.version, '2.1.0');
    });

    test('sin APK de su procesador: el universal; en iPhone, la página', () {
      expect('${elegirVersionNueva(_lista, _v('2.1.0-beta.1'), abis: ['x86'])!.descarga}',
          'https://github.com/descarga/v2.1.0-beta.3/universal.apk');
      final iphone = elegirVersionNueva(_lista, _v('2.1.0-beta.1'), android: false)!;
      expect(iphone.descarga, iphone.pagina);
    });

    test('datos raros no truenan', () {
      expect(elegirVersionNueva([null, 3, 'x', {'tag_name': 'nada'}], _v('1.0.0')), isNull);
    });
  });

  group('revisar', () {
    late Directory carpeta;
    late BaseDatos base;
    late Repositorio repo;
    var consultas = 0;
    String? respuesta;
    const info = InfoDispositivo(
      version: '2.1.0-beta.1',
      compilacion: '3',
      modelo: 'Prueba',
      android: '14 (API 34)',
      abis: ['arm64-v8a'],
    );

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      Actualizaciones.consultar = (url) async {
        consultas++;
        expect(url.host, 'api.github.com');
        return respuesta;
      };
    });

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('meizi_versiones');
      base = await BaseDatos.abrir(carpeta: carpeta.path, cargarContenido: _leerContenido);
      repo = Repositorio(base);
      consultas = 0;
      respuesta = jsonEncode(_lista);
    });

    tearDown(() async {
      await base.cerrar();
      await carpeta.delete(recursive: true);
    });

    test('la pregunta empieza sin contestar y se guarda', () async {
      expect(await repo.avisarVersiones(), isNull);
      await repo.guardarAvisarVersiones(true);
      expect(await repo.avisarVersiones(), isTrue);
      await repo.guardarAvisarVersiones(false);
      expect(await repo.avisarVersiones(), isFalse);
    });

    test('consulta una vez al día; «Buscar ahora» siempre', () async {
      final hoy = DateTime(2026, 10, 8, 9);
      var r = await Actualizaciones.revisar(repo, ahora: hoy, info: info);
      expect(r.estado, EstadoRevision.nueva);
      expect(r.nueva!.version, '2.1.0-beta.3');
      expect(consultas, 1);

      // Unas horas después: lo guardado, sin preguntar a GitHub.
      r = await Actualizaciones.revisar(repo, ahora: hoy.add(const Duration(hours: 5)), info: info);
      expect(r.nueva!.version, '2.1.0-beta.3');
      expect(consultas, 1);

      // A mano, sí.
      await Actualizaciones.revisar(repo, ahora: hoy.add(const Duration(hours: 5)), info: info, forzar: true);
      expect(consultas, 2);

      // Al día siguiente (más de 20 h después de la última), otra vez.
      await Actualizaciones.revisar(repo, ahora: hoy.add(const Duration(days: 1, hours: 2)), info: info);
      expect(consultas, 3);
    });

    test('ya instalada la que se había ofrecido, queda al día', () async {
      final hoy = DateTime(2026, 10, 8, 9);
      await Actualizaciones.revisar(repo, ahora: hoy, info: info);
      const actualizado = InfoDispositivo(
          version: '2.1.0-beta.3', compilacion: '5', modelo: 'Prueba', android: '14 (API 34)');
      final r = await Actualizaciones.revisar(repo, ahora: hoy.add(const Duration(hours: 1)), info: actualizado);
      expect(r.estado, EstadoRevision.alDia);
      expect(consultas, 1);
    });

    test('sin internet o con una respuesta rara', () async {
      respuesta = null;
      expect((await Actualizaciones.revisar(repo, info: info)).estado, EstadoRevision.sinConexion);
      respuesta = '<html>no</html>';
      expect((await Actualizaciones.revisar(repo, info: info)).estado, EstadoRevision.sinConexion);
      respuesta = '{"message": "rate limit"}';
      expect((await Actualizaciones.revisar(repo, info: info)).estado, EstadoRevision.sinConexion);
    });

    test('sin saber la versión instalada no se consulta', () async {
      final r = await Actualizaciones.revisar(repo, info: InfoDispositivo.desconocida);
      expect(r.estado, EstadoRevision.noDisponible);
      expect(consultas, 0);
    });

    test('«Ahora no» se recuerda', () async {
      expect(await repo.versionDescartada(), isNull);
      await repo.descartarVersion('2.1.0-beta.3');
      expect(await repo.versionDescartada(), '2.1.0-beta.3');
    });
  });
}

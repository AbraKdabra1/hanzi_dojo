// Pruebas del registro local de errores (Ajustes → Informe de errores).
//   flutter test test/registro_errores_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/registro_errores.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory carpeta;

  setUp(() async {
    RegistroErrores.reiniciarParaPruebas();
    carpeta = await Directory.systemTemp.createTemp('hanzi_dojo_errores');
  });

  tearDown(() async {
    RegistroErrores.reiniciarParaPruebas();
    await carpeta.delete(recursive: true);
  });

  test('lo que falla antes de iniciar se guarda al iniciar', () async {
    await RegistroErrores.registrar('Inicio', StateError('sin base'), StackTrace.current);
    expect(File(p.join(carpeta.path, RegistroErrores.archivo)).existsSync(), isFalse);

    await RegistroErrores.iniciar(carpeta.path);
    final errores = await RegistroErrores.leer();
    expect(errores, hasLength(1));
    expect(errores.single.origen, 'Inicio');
    expect(errores.single.mensaje, contains('sin base'));
    expect(errores.single.pila, isNotEmpty);
    expect(File(p.join(carpeta.path, RegistroErrores.archivo)).existsSync(), isTrue);
  });

  test('el más reciente primero, y un error repetido se cuenta en vez de duplicarse', () async {
    await RegistroErrores.iniciar(carpeta.path);
    await RegistroErrores.registrar('App', Exception('primero'), null);
    for (int i = 0; i < 5; i++) {
      await RegistroErrores.registrar('Flutter', Exception('se repite'), null);
    }
    final errores = await RegistroErrores.leer();
    expect(errores, hasLength(2));
    expect(errores.first.mensaje, contains('se repite'));
    expect(errores.first.veces, 5);
    expect(errores.last.mensaje, contains('primero'));
  });

  test('solo se guardan los últimos 50', () async {
    await RegistroErrores.iniciar(carpeta.path);
    for (int i = 0; i < 60; i++) {
      // Sin esperar: las escrituras van en fila y no se pisan.
      RegistroErrores.registrar('App', Exception('error $i'), null);
    }
    final errores = await RegistroErrores.leer();
    expect(errores, hasLength(RegistroErrores.maximo));
    expect(errores.first.mensaje, contains('error 59'));
    expect(errores.last.mensaje, contains('error 10'));
  });

  test('borrar deja el informe vacío; el texto para copiar lleva el encabezado', () async {
    await RegistroErrores.iniciar(carpeta.path);
    await RegistroErrores.registrar('Voz', Exception('sin voz china'), null);
    final texto = RegistroErrores.comoTexto(await RegistroErrores.leer(), 'Hanzi Dojo 2.0.0');
    expect(texto, startsWith('Hanzi Dojo 2.0.0'));
    expect(texto, contains('Voz'));
    expect(texto, contains('sin voz china'));

    await RegistroErrores.borrar();
    expect(await RegistroErrores.leer(), isEmpty);
    expect(RegistroErrores.comoTexto(const [], 'x'), contains('Sin errores'));
  });

  test('una línea dañada en el archivo no impide leer las demás', () async {
    await RegistroErrores.iniciar(carpeta.path);
    await RegistroErrores.registrar('App', Exception('bueno'), null);
    final archivo = File(p.join(carpeta.path, RegistroErrores.archivo));
    await archivo.writeAsString('esto no es json\n', mode: FileMode.append);
    final errores = await RegistroErrores.leer();
    expect(errores.single.mensaje, contains('bueno'));
  });
}

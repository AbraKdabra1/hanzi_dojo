// Pruebas del reporte de problemas (GitHub prellenado o texto para copiar).
//   flutter test test/reporte_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/registro_errores.dart';
import 'package:hanzi_dojo/datos/reporte.dart';

EntradaError _error(int i) => EntradaError(
      momento: DateTime(2026, 10, 2, 21, i),
      origen: 'Flutter',
      mensaje: 'Error número $i ${'x' * 1200}',
      pila: List.filled(20, '#$i  algo (package:hanzi_dojo/archivo.dart:1:1)').join('\n'),
    );

void main() {
  test('error de la app: título, campos y URL del formulario', () {
    final r = Reporte(
      tipo: TipoReporte.error,
      descripcion: 'La app se cierra al importar un respaldo grande',
      dispositivo: 'Meizi Hanzi 2.0.0 (2) · HUAWEI ALN-AL80 · Android 12 (API 31)',
      errores: [_error(1)],
    );
    expect(r.titulo, '[Error] La app se cierra al importar un respaldo grande');
    expect(r.campos.keys, containsAll(['descripcion', 'dispositivo', 'informe']));
    final url = r.urlGitHub;
    expect(url.host, 'github.com');
    expect(url.path, '/AbraKdabra1/hanzi_dojo/issues/new');
    expect(url.queryParameters['template'], 'error.yml');
    expect(url.queryParameters['title'], r.titulo);
    expect(url.queryParameters['informe'], contains('Error número 1'));
    expect(r.texto, contains('HUAWEI'));
  });

  test('error en el contenido: el título dice dónde y qué está mal', () {
    const r = Reporte(
      tipo: TipoReporte.contenido,
      descripcion: 'El significado dice "malo"',
      donde: 'Carácter 好 (hǎo) · HSK 1',
      queEstaMal: 'Significado',
      propuesta: 'bueno',
    );
    expect(r.titulo, '[Contenido] Carácter 好 (hǎo) · HSK 1 · Significado');
    final q = r.urlGitHub.queryParameters;
    expect(q['template'], 'contenido.yml');
    expect(q['donde'], 'Carácter 好 (hǎo) · HSK 1');
    expect(q['que_esta_mal'], 'Significado');
    expect(q['propuesta'], 'bueno');
    expect(q.containsKey('informe'), isFalse);
  });

  test('sugerencia sin datos del teléfono: solo la descripción', () {
    final r = Reporte(tipo: TipoReporte.sugerencia, descripcion: 'Modo oscuro ' * 10);
    expect(r.campos.keys, ['descripcion']);
    expect(r.titulo.length, lessThanOrEqualTo('[Sugerencia] '.length + 71));
    expect(r.titulo, endsWith('…'));
    expect(r.texto, isNot(contains('Android')));
  });

  test('un informe enorme se recorta para que la URL no sea demasiado larga', () {
    final r = Reporte(
      tipo: TipoReporte.error,
      descripcion: 'Muchos errores',
      errores: [for (int i = 0; i < 5; i++) _error(i)],
    );
    expect(r.informe.length, greaterThan(Reporte.largoMaximoUrl));
    final url = r.urlGitHub.toString();
    expect(url.length, lessThanOrEqualTo(Reporte.largoMaximoUrl));
    expect(Uri.parse(url).queryParameters['informe'], endsWith('(recortado)'));
    // El texto para copiar va completo.
    expect(r.texto, contains('Error número 4'));
  });
}

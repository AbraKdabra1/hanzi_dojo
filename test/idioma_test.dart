// La interfaz en inglés: que ningún texto de tr() se quede sin traducir.
//
// Recorre el código de lib/, saca el texto de cada tr('…') y revisa que esté
// en textos_en.dart con los mismos {0}, {1}… Así, al agregar un texto nuevo
// en español, esta prueba avisa si falta su traducción.
//   flutter test test/idioma_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/logros.dart';
import 'package:hanzi_dojo/datos/reporte.dart';
import 'package:hanzi_dojo/datos/srs.dart';
import 'package:hanzi_dojo/idioma.dart';
import 'package:hanzi_dojo/textos_en.dart';

/// Quita las secuencias de escape de un literal de Dart ('\n' → salto).
String _sinEscapes(String crudo) {
  final b = StringBuffer();
  for (var i = 0; i < crudo.length; i++) {
    final c = crudo[i];
    if (c != r'\' || i + 1 >= crudo.length) {
      b.write(c);
      continue;
    }
    final s = crudo[++i];
    b.write(switch (s) { 'n' => '\n', 't' => '\t', 'r' => '\r', _ => s });
  }
  return b.toString();
}

/// Los textos de tr('…') de un archivo (literales seguidos se juntan). Si un
/// texto usa $interpolación, se devuelve con el prefijo "$" para marcarlo.
List<String> _textosDeTr(String fuente) {
  final salida = <String>[];
  final patron = RegExp(r'(?<![A-Za-z0-9_])tr\(');
  for (final m in patron.allMatches(fuente)) {
    var i = m.end;
    final partes = <String>[];
    var interpolado = false;
    while (true) {
      while (i < fuente.length && ' \t\r\n'.contains(fuente[i])) {
        i++;
      }
      if (i >= fuente.length || (fuente[i] != "'" && fuente[i] != '"')) break;
      final comilla = fuente[i];
      final triple = fuente.startsWith(comilla * 3, i);
      final fin = triple ? comilla * 3 : comilla;
      i += fin.length;
      final b = StringBuffer();
      while (i < fuente.length && !fuente.startsWith(fin, i)) {
        if (fuente[i] == r'\') {
          b.write(fuente.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (fuente[i] == r'$') interpolado = true;
        b.write(fuente[i]);
        i++;
      }
      i += fin.length;
      partes.add(b.toString());
    }
    if (partes.isEmpty) continue; // tr(variable): se revisa aparte
    final texto = _sinEscapes(partes.join());
    salida.add(interpolado ? '\$$texto' : texto);
  }
  return salida;
}

Set<String> _marcadores(String s) => {for (final m in RegExp(r'\{\d+\}').allMatches(s)) m.group(0)!};

void main() {
  tearDown(() => Idioma.actual.value = Lengua.espanol);

  test('cada texto de tr() tiene traducción al inglés con los mismos marcadores', () {
    final faltan = <String>[];
    final interpolados = <String>[];
    final marcadores = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!archivo.path.endsWith('.dart')) continue;
      for (final texto in _textosDeTr(archivo.readAsStringSync())) {
        if (texto.startsWith(r'$')) {
          interpolados.add('${archivo.path}: ${texto.substring(1)}');
          continue;
        }
        final en = textosEn[texto];
        if (en == null) {
          faltan.add('${archivo.path}: $texto');
        } else if (!_marcadores(en).containsAll(_marcadores(texto)) ||
            !_marcadores(texto).containsAll(_marcadores(en))) {
          marcadores.add('$texto → $en');
        }
      }
    }
    expect(interpolados, isEmpty, reason: r'usa tr("… {0} …", [valor]) en vez de $valor');
    expect(faltan, isEmpty, reason: 'agrega estos textos a lib/textos_en.dart');
    expect(marcadores, isEmpty, reason: 'los {0}, {1}… deben ser los mismos en los dos idiomas');
  });

  test('los textos que se traducen desde una variable también están', () {
    final dinamicos = <String>[
      for (final l in Logros.todos) ...[l.tituloEs, l.descripcionEs],
      for (final t in TipoReporte.values) t.etiqueta,
      ...queEstaMalOpciones,
      // Secciones del respaldo (mensaje «El respaldo está dañado (…)»).
      ...['progreso', 'historial', 'lectura', 'vocabulario', 'ejercicios', 'logros', 'protecciones'],
    ];
    expect([for (final d in dinamicos) if (!textosEn.containsKey(d)) d], isEmpty);
    Idioma.actual.value = Lengua.ingles;
    expect(Calificacion.values.map((c) => c.etiqueta), ['Hard', 'Good', 'Easy']);
  });

  test('tr() reemplaza los marcadores y en español deja el texto tal cual', () {
    expect(tr('Hoy: {0} de {1}', [3, 20]), 'Hoy: 3 de 20');
    Idioma.actual.value = Lengua.ingles;
    expect(tr('Hoy: {0} de {1}', [3, 20]), 'Today: 3 of 20');
    expect(tr('Un texto que no existe'), 'Un texto que no existe'); // sin traducción: español
    expect(diasLetra.first, 'M');
  });

  test('idioma automático: español si el teléfono está en español; si no, inglés', () {
    expect(Idioma.desdeTexto('auto', delTelefono: 'es'), Lengua.espanol);
    expect(Idioma.desdeTexto('auto', delTelefono: 'fr'), Lengua.ingles);
    expect(Idioma.desdeTexto('en', delTelefono: 'es'), Lengua.ingles);
    expect(Idioma.desdeTexto('es', delTelefono: 'en'), Lengua.espanol);
  });
}

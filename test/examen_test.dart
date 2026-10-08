// Simulacros y examen de ubicación: cómo se arman y cómo se califican.
//   flutter test test/examen_test.dart

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_dojo/datos/examen.dart';
import 'package:hanzi_dojo/datos/practica.dart';

List<Palabra> _palabras(int n, {bool audio = true, int desde = 0}) {
  const consonantes = ['b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'z', 'c', 's'];
  const vocales = ['a', 'o', 'e', 'ai', 'ei', 'ao', 'ou', 'an', 'en', 'ang'];
  return [
    for (var i = desde; i < desde + n; i++)
      Palabra(
        id: i,
        palabra: String.fromCharCode(0x4E00 + i),
        forma: String.fromCharCode(0x4E00 + i),
        pinyin: '',
        pinyinNum: '${consonantes[i % consonantes.length]}${vocales[(i ~/ consonantes.length) % vocales.length]}'
            '${i ~/ (consonantes.length * vocales.length) % 4 + 1}',
        clase: '',
        nivelHsk: 1,
        significadoEs: 'significado $i',
        significadoEn: 'meaning $i',
        audio: audio,
      ),
  ];
}

void main() {
  test('simulacro: 30 preguntas, 10 por sección, sin repetir palabras', () {
    final todas = _palabras(200);
    final conAudio = todas.take(60).toList();
    final preguntas = Examen.simulacro(conAudio, todas, Random(1));
    expect(preguntas.length, 30);
    for (final s in SeccionExamen.values) {
      expect(preguntas.where((q) => q.seccion == s).length, 10);
    }
    final objetivos = preguntas.map((q) => q.pregunta.objetivo.id).toSet();
    expect(objetivos.length, 30);
    for (final q in preguntas) {
      expect(q.pregunta.opciones.length, 4);
      expect(q.pregunta.opciones[q.pregunta.correcta], q.pregunta.objetivo);
    }
    // La escucha solo pregunta palabras con grabación.
    final conGrabacion = conAudio.map((p) => p.id).toSet();
    expect(preguntas.where((q) => q.seccion == SeccionExamen.escucha).every((q) => conGrabacion.contains(q.pregunta.objetivo.id)),
        isTrue);
  });

  test('ubicación: 3 de lectura y 2 de escucha por nivel', () {
    final todas = _palabras(80);
    final preguntas = Examen.ubicacion(todas.take(20).toList(), todas, Random(2));
    expect(preguntas.length, Examen.preguntasUbicacion);
    expect(preguntas.where((q) => q.seccion == SeccionExamen.lectura).length, 3);
    expect(preguntas.where((q) => q.seccion == SeccionExamen.escucha).length, 2);
  });

  test('nivel sugerido: el primero que no pasaste', () {
    expect(Examen.nivelSugerido([2]), 1);
    expect(Examen.nivelSugerido([5, 4, 1]), 3);
    expect(Examen.nivelSugerido([5, 5, 5, 4, 5, 5, 5]), 7); // pasó todos
    expect(Examen.nivelSugerido([5, 5, 5, 5, 5, 5, 3]), 7);
  });

  test('calificación de 0 a 100', () {
    expect(Examen.calificacion(18, 30), 60);
    expect(Examen.calificacion(0, 30), 0);
    expect(Examen.calificacion(30, 30), 100);
    expect(Examen.calificacion(0, 0), 0);
  });
}

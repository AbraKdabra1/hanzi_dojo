// ─────────────────────────────────────────────────────────────────────────────
// examen.dart — Simulacros HSK y examen de ubicación (fase 7)
//
// Simulacro de un nivel: 30 preguntas en tres secciones, como el examen real
// (escuchar, leer y reconocer caracteres), con tiempo y sin decirte si
// acertaste hasta el final. Se aprueba con 60 de 100.
//   · Escucha    (10): suena una palabra → eliges su significado.
//   · Lectura    (10): ves una palabra → eliges su significado.
//   · Caracteres (10): ves el pinyin y el significado → eliges cómo se escribe.
//
// Ubicación: sube de nivel en nivel con 5 preguntas por nivel (3 de lectura
// y 2 de escucha). Si aciertas 4 o más pasas al siguiente; si no, ahí está tu
// nivel para empezar.
//
// Se guarda en la tabla ejercicios (tipo 'examen'): elemento 'simulacro:3' o
// 'ubicacion', respuesta = la calificación (0-100) o el nivel sugerido.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../idioma.dart';
import 'practica.dart';

enum SeccionExamen {
  escucha,
  lectura,
  caracteres;

  String get nombre => switch (this) {
        SeccionExamen.escucha => tr('Escucha'),
        SeccionExamen.lectura => tr('Lectura'),
        SeccionExamen.caracteres => tr('Caracteres'),
      };
}

class PreguntaExamen {
  const PreguntaExamen(this.seccion, this.pregunta);

  final SeccionExamen seccion;
  final PreguntaOpciones pregunta;

  /// En lectura y escucha las opciones son significados; en caracteres, la
  /// palabra escrita.
  bool get opcionesSonSignificados => seccion != SeccionExamen.caracteres;
}

class Examen {
  Examen._();

  static const tipo = 'examen';
  static const porSeccion = 10;
  static const minutosSimulacro = 12;
  static const aprobado = 60;

  /// Preguntas por nivel en la ubicación y cuántas hay que acertar para pasar.
  static const preguntasUbicacion = 5;
  static const aciertosParaPasar = 4;

  static String elementoSimulacro(int nivel) => 'simulacro:$nivel';
  static const elementoUbicacion = 'ubicacion';

  /// Arma un simulacro con [conAudio] (palabras del nivel con grabación) y
  /// [todas] (palabras del nivel, para lectura, caracteres y distractores).
  /// Ninguna palabra se pregunta dos veces.
  static List<PreguntaExamen> simulacro(List<Palabra> conAudio, List<Palabra> todas, Random azar,
      {int porSeccion = porSeccion}) {
    final usadas = <int>{};
    List<Palabra> tomar(List<Palabra> de, int n) {
      final lista = [for (final p in de) if (!usadas.contains(p.id)) p]..shuffle(azar);
      final elegidas = lista.take(n).toList();
      usadas.addAll(elegidas.map((p) => p.id));
      return elegidas;
    }

    final escucha = tomar(conAudio, porSeccion);
    final lectura = tomar(todas, porSeccion);
    final caracteres = tomar(todas, porSeccion);
    return [
      for (final p in escucha)
        PreguntaExamen(SeccionExamen.escucha, PreguntaOpciones.armar(p, todas, azar, porSignificado: true)),
      for (final p in lectura)
        PreguntaExamen(SeccionExamen.lectura, PreguntaOpciones.armar(p, todas, azar, porSignificado: true)),
      for (final p in caracteres)
        PreguntaExamen(SeccionExamen.caracteres, PreguntaOpciones.armar(p, todas, azar)),
    ];
  }

  /// Las preguntas de un nivel en la ubicación: 3 de lectura y 2 de escucha.
  static List<PreguntaExamen> ubicacion(List<Palabra> conAudio, List<Palabra> todas, Random azar) {
    final usadas = <int>{};
    final lista = <PreguntaExamen>[];
    for (final p in ([...todas]..shuffle(azar)).take(3)) {
      usadas.add(p.id);
      lista.add(PreguntaExamen(SeccionExamen.lectura, PreguntaOpciones.armar(p, todas, azar, porSignificado: true)));
    }
    for (final p in ([for (final x in conAudio) if (!usadas.contains(x.id)) x]..shuffle(azar)).take(2)) {
      lista.add(PreguntaExamen(SeccionExamen.escucha, PreguntaOpciones.armar(p, todas, azar, porSignificado: true)));
    }
    return lista;
  }

  /// Calificación de 0 a 100.
  static int calificacion(int aciertos, int total) => total == 0 ? 0 : (aciertos * 100 / total).round();

  /// Nivel sugerido por la ubicación: el primero que no pasaste (o 7 si
  /// pasaste todos). [aciertosPorNivel]: aciertos de cada nivel presentado,
  /// en orden desde HSK 1.
  static int nivelSugerido(List<int> aciertosPorNivel) {
    for (var i = 0; i < aciertosPorNivel.length; i++) {
      if (aciertosPorNivel[i] < aciertosParaPasar) return i + 1;
    }
    return min(aciertosPorNivel.length + 1, 7);
  }
}

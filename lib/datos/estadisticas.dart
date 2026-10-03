// ─────────────────────────────────────────────────────────────────────────────
// estadisticas.dart — Cálculos de la pantalla "Mi progreso" (fase 3)
//
// Todo sale de la tabla `historial` (una fila por repaso, ver base_datos.dart).
// Aquí está la parte que no depende de la base (rachas, trazos que más
// fallas, niveles del calendario) para poder probarla sola.
// ─────────────────────────────────────────────────────────────────────────────

import 'modelos.dart';

/// Lo que estudiaste un día.
class DiaActividad {
  const DiaActividad(this.dia, this.repasos, this.segundos);

  /// Medianoche (hora local) de ese día.
  final DateTime dia;
  final int repasos;
  final int segundos;

  int get minutos => (segundos / 60).round();
}

/// Días seguidos estudiando.
class Racha {
  const Racha({required this.actual, required this.maxima});

  /// Días seguidos hasta hoy (o hasta ayer, si hoy aún no estudias).
  final int actual;

  /// La racha más larga que has tenido.
  final int maxima;
}

/// Un carácter que te cuesta.
class CaracterDificil {
  const CaracterDificil({
    required this.caracter,
    required this.veces,
    required this.erroresPromedio,
    required this.dificiles,
  });

  final Caracter caracter;

  /// Cuántas veces lo has practicado.
  final int veces;

  /// Trazos fallados en promedio por repaso.
  final double erroresPromedio;

  /// Cuántas veces lo calificaste "Difícil".
  final int dificiles;
}

/// Un trazo concreto que fallas seguido.
class TrazoFallado {
  const TrazoFallado({required this.caracter, required this.indice, required this.veces, required this.alReves});

  final String caracter;

  /// Número del trazo (0 = el primero).
  final int indice;

  /// Veces que fallaste ese trazo (incluye las que fue al revés).
  final int veces;

  /// De esas, cuántas fue al revés.
  final int alReves;
}

/// Porcentaje de repasos sin ningún trazo fallado.
class Precision {
  const Precision({required this.repasos, required this.limpios, required this.novato, required this.experto});

  final int repasos;
  final int limpios;

  /// Fracción sin errores en cada modo (null si no hay repasos en ese modo).
  final double? novato;
  final double? experto;

  double? get total => repasos == 0 ? null : limpios / repasos;
}

class Estadisticas {
  Estadisticas._();

  static DateTime _dia(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Racha a partir de los días con actividad.
  static Racha racha(Iterable<DateTime> diasActivos, DateTime hoy) {
    final dias = {for (final d in diasActivos) _dia(d)};
    if (dias.isEmpty) return const Racha(actual: 0, maxima: 0);

    // Actual: hacia atrás desde hoy; si hoy no hay nada, desde ayer (la
    // racha sigue viva hasta que termine el día).
    var cursor = _dia(hoy);
    if (!dias.contains(cursor)) cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    var actual = 0;
    while (dias.contains(cursor)) {
      actual++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    // Máxima: la corrida más larga de días consecutivos.
    final ordenados = dias.toList()..sort();
    var maxima = 1;
    var corrida = 1;
    for (int i = 1; i < ordenados.length; i++) {
      final anterior = ordenados[i - 1];
      final esperado = DateTime(anterior.year, anterior.month, anterior.day + 1);
      corrida = ordenados[i] == esperado ? corrida + 1 : 1;
      if (corrida > maxima) maxima = corrida;
    }
    return Racha(actual: actual, maxima: maxima);
  }

  /// Los trazos que más fallas, a partir de pares (carácter, fallos "0,3r,3").
  static List<TrazoFallado> trazosFallados(Iterable<(String, String)> filas, {int limite = 5}) {
    final veces = <(String, int), int>{};
    final alReves = <(String, int), int>{};
    for (final (caracter, fallos) in filas) {
      for (final f in FalloTrazo.leerLista(fallos)) {
        final clave = (caracter, f.indice);
        veces[clave] = (veces[clave] ?? 0) + 1;
        if (f.alReves) alReves[clave] = (alReves[clave] ?? 0) + 1;
      }
    }
    final lista = [
      for (final MapEntry(key: (caracter, indice), value: n) in veces.entries)
        TrazoFallado(caracter: caracter, indice: indice, veces: n, alReves: alReves[(caracter, indice)] ?? 0),
    ]..sort((a, b) => b.veces != a.veces ? b.veces - a.veces : b.alReves - a.alReves);
    return lista.where((t) => t.veces >= 2).take(limite).toList();
  }

  /// Nivel de color del calendario (0 = nada, 1-4 = de poco a mucho).
  static int nivelCalendario(int repasos) => switch (repasos) {
        0 => 0,
        < 10 => 1,
        < 25 => 2,
        < 50 => 3,
        _ => 4,
      };

  /// Lunes de la semana de [t] (el calendario empieza en lunes).
  static DateTime lunes(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));
}

// ─────────────────────────────────────────────────────────────────────────────
// srs.dart — Repaso espaciado con el algoritmo SM-2
//
// Idea: cada vez que practicas un carácter lo calificas. Si te costó, vuelve
// pronto; si fue fácil, se aleja cada vez más (1 día, 6 días, ~15, ~40…).
//
// SM-2 original (Piotr Woźniak, 1987), tal como se usa aquí:
//   - Calificación q de 0 a 5. Aquí: Difícil = 0, Medio = 3, Fácil = 5.
//   - Si q < 3: se reinicia la racha (siguiente repaso mañana) y el factor
//     NO cambia. Además la sesión lo vuelve a mostrar en unos minutos
//     (ver sesion_estudio.dart).
//   - Si q >= 3: intervalo = 1 día la 1.ª vez, 6 días la 2.ª y después
//     intervalo anterior × factor.
//     factor' = factor + 0.1 − (5 − q) × (0.08 + (5 − q) × 0.02), mínimo 1.3.
//
// Todo aquí es cálculo puro (sin base de datos) para poder probarlo.
// ─────────────────────────────────────────────────────────────────────────────

import '../idioma.dart';

/// Botones que ves al terminar un carácter.
enum Calificacion {
  dificil(0, 'Difícil'),
  medio(3, 'Medio'),
  facil(5, 'Fácil');

  const Calificacion(this.q, this._etiqueta);

  /// Valor q de SM-2.
  final int q;
  final String _etiqueta;

  /// Nombre del botón en el idioma de la interfaz.
  String get etiqueta => tr(_etiqueta);

  /// true si cuenta como "lo recordé".
  bool get aprobado => q >= 3;

  /// Calificación sugerida según los errores de trazo que tuviste.
  static Calificacion sugerida(int errores) => switch (errores) {
        0 => Calificacion.facil,
        1 || 2 => Calificacion.medio,
        _ => Calificacion.dificil,
      };
}

/// Estado de repaso de un carácter.
class EstadoSrs {
  const EstadoSrs({
    this.intervaloDias = 0,
    this.factor = factorInicial,
    this.aciertosSeguidos = 0,
  });

  static const double factorInicial = 2.5;
  static const double factorMinimo = 1.3;

  final int intervaloDias;
  final double factor;
  final int aciertosSeguidos;

  /// Aplica una calificación y devuelve el nuevo estado.
  EstadoSrs calificar(Calificacion c) {
    if (!c.aprobado) {
      // Falló: vuelve a empezar la racha; el factor se conserva (SM-2 original).
      return EstadoSrs(intervaloDias: 1, factor: factor, aciertosSeguidos: 0);
    }
    final int intervalo = switch (aciertosSeguidos) {
      0 => 1,
      1 => 6,
      _ => (intervaloDias * factor).round(),
    };
    final int d = 5 - c.q;
    final double nuevoFactor = factor + 0.1 - d * (0.08 + d * 0.02);
    return EstadoSrs(
      intervaloDias: intervalo,
      factor: nuevoFactor < factorMinimo ? factorMinimo : nuevoFactor,
      aciertosSeguidos: aciertosSeguidos + 1,
    );
  }

  /// Fecha del próximo repaso a partir de [ahora]: el INICIO (00:00, hora
  /// local) del día que toca. Así un carácter con intervalo de 1 día que
  /// practicaste a las 21:00 ya está listo desde temprano al día siguiente,
  /// no hasta las 21:00. (DateTime acomoda solo "día 32" al mes siguiente.)
  DateTime proximoRepaso(DateTime ahora) =>
      DateTime(ahora.year, ahora.month, ahora.day + intervaloDias);
}

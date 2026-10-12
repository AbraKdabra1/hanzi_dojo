// ─────────────────────────────────────────────────────────────────────────────
// desde_cero.dart — Qué lecciones de «Chino desde cero» ya terminaste
//
// Seis lecciones cortas para quien nunca ha estudiado chino (qué es un hanzi,
// de dónde vienen, los trazos, el pinyin, los tonos y las primeras palabras;
// ver screens/pantalla_desde_cero.dart). Se guarda cuáles terminaste en el
// ajuste 'desde_cero' ("0,1,3"), así viaja con el respaldo.
// ─────────────────────────────────────────────────────────────────────────────

import 'repositorio.dart';

extension DesdeCeroRepositorio on Repositorio {
  static const totalLecciones = 6;

  /// A partir de cuántos repasos de escritura ya no se ofrece en el inicio
  /// (quien ya estudia no lo necesita; sigue en Ajustes).
  static const repasosParaOcultar = 100;

  Future<Set<int>> leccionesTerminadas() async {
    final texto = await base.leerAjuste('desde_cero') ?? '';
    return {
      for (final p in texto.split(','))
        if (int.tryParse(p.trim()) case final n? when n >= 0 && n < totalLecciones) n,
    };
  }

  Future<void> terminarLeccion(int leccion) async {
    final hechas = {...await leccionesTerminadas(), leccion}.toList()..sort();
    await base.guardarAjuste('desde_cero', hechas.join(','));
  }

  /// ¿Se ofrece en el inicio? Mientras falte alguna lección y no lleves
  /// muchos repasos.
  Future<bool> ofrecerDesdeCero() async {
    if ((await leccionesTerminadas()).length >= totalLecciones) return false;
    final filas = await base.db.rawQuery('SELECT count(*) AS n FROM historial');
    return (filas.first['n'] as int? ?? 0) < repasosParaOcultar;
  }
}

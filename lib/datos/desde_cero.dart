// ─────────────────────────────────────────────────────────────────────────────
// desde_cero.dart — «Chino desde cero»: qué lecciones terminaste y qué camino
// elegiste
//
// Seis lecciones cortas para quien nunca ha estudiado chino (qué es un hanzi,
// de dónde vienen, los trazos, el pinyin, los tonos y las primeras palabras;
// ver screens/pantalla_desde_cero.dart). Se guarda cuáles terminaste en el
// ajuste 'desde_cero' ("0,1,3"), así viaja con el respaldo.
//
// Al terminar el tutorial, la primera vez, la app pregunta si quieres empezar
// desde cero (ajuste 'desde_cero_ruta'):
//   · 'si'    → las lecciones van en el inicio y Estudiar, Leer y Practicar
//               esperan con candado hasta terminarlas (o desbloquearlas ya).
//   · 'hecho' → las terminaste: todo abierto; las lecciones, al final de Ajustes.
//   · 'no'    → lo omitiste: todo abierto; las lecciones, al final de Ajustes.
// ─────────────────────────────────────────────────────────────────────────────

import 'repositorio.dart';

/// En qué punto de «Chino desde cero» vas.
enum RutaDesdeCero {
  /// Todavía no se pregunta (recién instalada: se pregunta tras el tutorial).
  sinElegir,

  /// Elegiste empezar desde cero y te faltan lecciones: van en el inicio y
  /// lo demás tiene candado.
  enCurso,

  /// Lo omitiste (o desbloqueaste todo antes de terminar).
  omitida,

  /// Terminaste las seis.
  terminada;

  /// Estudiar, Leer y Practicar con candado.
  bool get bloquea => this == enCurso;

  /// Las lecciones se ven en el inicio (si no, al final de Ajustes).
  bool get enInicio => this == enCurso;
}

extension DesdeCeroRepositorio on Repositorio {
  static const totalLecciones = 6;

  /// Con cuántos repasos de escritura ya no se pregunta: quien venía de una
  /// versión anterior y ya estudia no lo necesita (sigue en Ajustes).
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

  Future<RutaDesdeCero> rutaDesdeCero() async {
    switch (await base.leerAjuste('desde_cero_ruta')) {
      case 'si':
        return RutaDesdeCero.enCurso;
      case 'hecho':
        return RutaDesdeCero.terminada;
      case 'no':
        return RutaDesdeCero.omitida;
    }
    final filas = await base.db.rawQuery('SELECT count(*) AS n FROM historial');
    if ((filas.first['n'] as int? ?? 0) >= repasosParaOcultar) {
      await base.guardarAjuste('desde_cero_ruta', 'no');
      return RutaDesdeCero.omitida;
    }
    return RutaDesdeCero.sinElegir;
  }

  /// La respuesta a «¿Nunca has estudiado chino?» (o «desbloquear ya»: false).
  Future<void> elegirDesdeCero(bool empezar) => base.guardarAjuste('desde_cero_ruta', empezar ? 'si' : 'no');

  /// Si ibas desde cero y ya terminaste las seis, se abre todo. true solo la
  /// vez que se desbloquea (para festejarlo una vez).
  Future<bool> desbloquearSiTerminaste() async {
    if (await base.leerAjuste('desde_cero_ruta') != 'si') return false;
    if ((await leccionesTerminadas()).length < totalLecciones) return false;
    await base.guardarAjuste('desde_cero_ruta', 'hecho');
    return true;
  }

  /// Para el resumen de la beta: 'si', 'no', 'hecho' o null (sin elegir).
  Future<String?> rutaDesdeCeroGuardada() => base.leerAjuste('desde_cero_ruta');
}

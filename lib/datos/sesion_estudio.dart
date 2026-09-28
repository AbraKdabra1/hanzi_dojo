// ─────────────────────────────────────────────────────────────────────────────
// sesion_estudio.dart — Decide qué carácter sigue durante una sesión
//
// Reglas:
//   1. Si calificaste un carácter como "Difícil", vuelve a salir en esta
//      misma sesión después de [tarjetasAntesDeReaprender] tarjetas
//      (antes había que esperar al día siguiente).
//   2. Luego van los repasos vencidos (lo que el repaso espaciado dice que
//      toca hoy).
//   3. Luego caracteres nuevos, hasta el límite diario (Ajustes). Al llegar
//      al límite, la sesión termina con la opción de "estudiar más".
//
// La lógica no depende de la base de datos: recibe una FuenteSesion. En la
// app es el Repositorio; en las pruebas, una versión falsa en memoria.
// ─────────────────────────────────────────────────────────────────────────────

import 'modelos.dart';
import 'repositorio.dart';
import 'srs.dart';

/// Lo que la sesión necesita de la base de datos.
abstract class FuenteSesion {
  Future<Caracter?> siguiente(FiltroEstudio filtro,
      {required bool permitirNuevos, required Set<int> excluir});
  Future<Caracter?> caracter(int id);
  Future<void> registrarRespuesta(Caracter c, Calificacion calificacion);
  Future<int> nuevosHoy();
  Future<int> limiteNuevosPorDia();
  Future<bool> quedanNuevos(FiltroEstudio filtro);
}

/// El Repositorio real cumple con FuenteSesion.
class FuenteRepositorio implements FuenteSesion {
  FuenteRepositorio(this.repo);
  final Repositorio repo;

  @override
  Future<Caracter?> siguiente(FiltroEstudio filtro,
          {required bool permitirNuevos, required Set<int> excluir}) =>
      repo.siguiente(filtro, permitirNuevos: permitirNuevos, excluir: excluir);
  @override
  Future<Caracter?> caracter(int id) => repo.caracter(id);
  @override
  Future<void> registrarRespuesta(Caracter c, Calificacion calificacion) =>
      repo.registrarRespuesta(c, calificacion);
  @override
  Future<int> nuevosHoy() => repo.nuevosHoy();
  @override
  Future<int> limiteNuevosPorDia() => repo.limiteNuevosPorDia();
  @override
  Future<bool> quedanNuevos(FiltroEstudio filtro) => repo.quedanNuevos(filtro);
}

/// Por qué terminó la sesión.
enum FinSesion {
  /// No queda nada: ni repasos vencidos ni caracteres nuevos.
  completo,

  /// Llegaste al límite de nuevos por hoy (pero quedan nuevos).
  limiteDiario,

  /// Modo de un solo carácter: ya se practicó.
  unicoTerminado,
}

class SesionEstudio {
  SesionEstudio(this.fuente, this.filtro);

  final FuenteSesion fuente;
  final FiltroEstudio filtro;

  /// Tarjetas que deben pasar antes de repetir una marcada como "Difícil".
  static const tarjetasAntesDeReaprender = 3;

  /// Si es true, se ignora el límite diario de nuevos (botón "Estudiar más").
  bool ignorarLimite = false;

  int _mostradas = 0;
  int _nuevasEnSesion = 0;
  int _repasadasEnSesion = 0;

  /// Caracteres para reaprender: id → número de tarjeta a partir del cual
  /// vuelven a salir.
  final Map<int, int> _reaprender = {};

  /// Cómo terminó la sesión (null mientras siga).
  FinSesion? fin;

  int get nuevasEnSesion => _nuevasEnSesion;
  int get repasadasEnSesion => _repasadasEnSesion;

  /// Devuelve el siguiente carácter, o null si la sesión terminó (ver [fin]).
  Future<Caracter?> siguiente() async {
    // Práctica libre de un solo carácter: se muestra una vez y termina.
    if (filtro.esUnico && _mostradas > 0) {
      fin = FinSesion.unicoTerminado;
      return null;
    }

    // 1. ¿Algún "Difícil" ya esperó lo suficiente?
    final listo = _reaprender.entries
        .where((e) => e.value <= _mostradas)
        .map((e) => e.key)
        .firstOrNull;
    if (listo != null) {
      _reaprender.remove(listo);
      return fuente.caracter(listo);
    }

    // 2 y 3. Repasos vencidos y, si se puede, nuevos.
    final permitirNuevos = filtro.esUnico ||
        ignorarLimite ||
        await fuente.nuevosHoy() < await fuente.limiteNuevosPorDia();
    final c = await fuente.siguiente(filtro,
        permitirNuevos: permitirNuevos, excluir: _reaprender.keys.toSet());
    if (c != null) return c;

    // 4. No hay nada más: si quedan "Difícil" pendientes, se muestran ya.
    if (_reaprender.isNotEmpty) {
      final id = _reaprender.keys.first;
      _reaprender.remove(id);
      return fuente.caracter(id);
    }

    // 5. Fin de la sesión.
    if (filtro.esUnico) {
      fin = FinSesion.unicoTerminado;
    } else if (!permitirNuevos && await fuente.quedanNuevos(filtro)) {
      fin = FinSesion.limiteDiario;
    } else {
      fin = FinSesion.completo;
    }
    return null;
  }

  /// Registra la calificación del carácter que acabas de practicar.
  Future<void> responder(Caracter c, Calificacion calificacion) async {
    if (c.progreso == null) {
      _nuevasEnSesion++;
    } else {
      _repasadasEnSesion++;
    }
    await fuente.registrarRespuesta(c, calificacion);
    _mostradas++;
    if (!calificacion.aprobado && !filtro.esUnico) {
      _reaprender[c.id] = _mostradas + tarjetasAntesDeReaprender;
    }
  }

  /// Continúa después de llegar al límite diario.
  void estudiarMas() {
    ignorarLimite = true;
    fin = null;
  }
}

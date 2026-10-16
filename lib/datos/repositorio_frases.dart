// ─────────────────────────────────────────────────────────────────────────────
// repositorio_frases.dart — Consultas de las frases esenciales
//
// Se agregan al Repositorio como extensión, igual que repositorio_practica.dart.
// Tablas:
//   c.frases         → las frases (contenido, solo lectura)
//   progreso_frases  → repaso espaciado de cada frase (SM-2, por su id fijo)
//   ejercicios       → cada vez que practicas una frase (tipo 'frase')
//
// Son pocas frases (menos de cien), así que se leen todas con su avance y se
// eligen aquí, sin consultas especiales.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'frases.dart';
import 'practica.dart';
import 'repositorio.dart';
import 'srs.dart';

const _columnasFrase = 'f.id, f.situacion, f.orden, f.chino, f.pinyin, f.silabas, f.palabras, '
    'f.espanol, f.ingles, f.nota, f.nivel_hsk';

const _progresoFrase = 'p.intervalo AS p_intervalo, p.factor AS p_factor, '
    'p.aciertos_seguidos AS p_aciertos_seguidos, p.veces_visto AS p_veces_visto, '
    'p.proximo_repaso AS p_proximo_repaso';

const _desdeFrases = 'FROM c.frases f LEFT JOIN progreso_frases p ON p.frase = f.id';

int _segundos(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// Filas → frases en el orden de la app: por situación y luego por su orden.
/// Las de una situación que esta versión de la app no conoce se saltan.
List<Frase> _frasesEnOrden(List<Map<String, Object?>> filas) => [
      for (final f in filas)
        if (Situacion.deClave(f['situacion'] as String) case final s?) Frase.desdeFila(f, s),
    ]..sort((a, b) => a.situacion == b.situacion
        ? a.orden.compareTo(b.orden)
        : a.situacion.index.compareTo(b.situacion.index));

extension FrasesRepositorio on Repositorio {
  Database get _bd => base.db;

  /// Todas las frases (o solo las de [situacion]), con tu avance.
  Future<List<Frase>> frases({Situacion? situacion}) async {
    final filas = await _bd.rawQuery(
      'SELECT $_columnasFrase, $_progresoFrase $_desdeFrases'
      '${situacion == null ? '' : ' WHERE f.situacion = ?'}',
      [if (situacion != null) situacion.clave],
    );
    return _frasesEnOrden(filas);
  }

  Future<Frase?> frase(int id) async {
    final filas =
        await _bd.rawQuery('SELECT $_columnasFrase, $_progresoFrase $_desdeFrases WHERE f.id = ?', [id]);
    return _frasesEnOrden(filas).firstOrNull;
  }

  /// Siguiente frase del repaso: primero la que lleva más tiempo esperando
  /// de las que tocan hoy; después, si [permitirNuevas], la primera que nunca
  /// has practicado. Con [situacion], solo de esa situación.
  Future<Frase?> siguienteFrase({
    Situacion? situacion,
    required bool permitirNuevas,
    Set<int> excluir = const {},
    DateTime? ahora,
  }) async {
    final t = ahora ?? DateTime.now();
    final candidatas = [
      for (final f in await frases(situacion: situacion))
        if (!excluir.contains(f.id)) f,
    ];
    final vencidas = [
      for (final f in candidatas)
        if (f.progreso case final p? when !p.proximoRepaso.isAfter(t)) f,
    ]..sort((a, b) => a.progreso!.proximoRepaso.compareTo(b.progreso!.proximoRepaso));
    if (vencidas.isNotEmpty) return vencidas.first;
    if (!permitirNuevas) return null;
    return candidatas.where((f) => f.progreso == null).firstOrNull;
  }

  /// Guarda cómo te fue con una frase (SM-2) y lo anota en ejercicios.
  /// [respuesta]: lo que contestaste, si el ejercicio lo pide.
  Future<void> registrarFrase(
    Frase f,
    Calificacion calificacion, {
    String respuesta = '',
    int duracionMs = 0,
    DateTime? ahora,
  }) async {
    final t = ahora ?? DateTime.now();
    await _bd.transaction((txn) async {
      final filas = await txn.rawQuery(
          'SELECT intervalo, factor, aciertos_seguidos FROM progreso_frases WHERE frase = ?', [f.id]);
      final anterior = filas.firstOrNull;
      final estado = EstadoSrs(
        intervaloDias: anterior?['intervalo'] as int? ?? 0,
        factor: (anterior?['factor'] as num?)?.toDouble() ?? EstadoSrs.factorInicial,
        aciertosSeguidos: anterior?['aciertos_seguidos'] as int? ?? 0,
      ).calificar(calificacion);
      final proximo = _segundos(estado.proximoRepaso(t));
      if (anterior != null) {
        await txn.rawUpdate('''
          UPDATE progreso_frases SET intervalo = ?, factor = ?, aciertos_seguidos = ?,
                 veces_visto = veces_visto + 1, proximo_repaso = ?, ultima_vez = ?
          WHERE frase = ?
        ''', [estado.intervaloDias, estado.factor, estado.aciertosSeguidos, proximo, _segundos(t), f.id]);
      } else {
        await txn.rawInsert('''
          INSERT INTO progreso_frases (frase, intervalo, factor, aciertos_seguidos, veces_visto,
                                       proximo_repaso, primera_vez, ultima_vez)
          VALUES (?, ?, ?, ?, 1, ?, ?, ?)
        ''', [f.id, estado.intervaloDias, estado.factor, estado.aciertosSeguidos, proximo, _segundos(t), _segundos(t)]);
      }
      await txn.insert('ejercicios', {
        'tipo': TipoEjercicio.frase,
        'elemento': '${f.id}',
        'momento': _segundos(t),
        'resultado': calificacion.q,
        'respuesta': respuesta,
        'duracion_ms': duracionMs.clamp(0, 10 * 60 * 1000),
      });
    });
  }

  /// Frases que tocan hoy (solo las que siguen en el contenido).
  Future<int> frasesPendientes({DateTime? ahora}) async {
    final filas = await _bd.rawQuery(
        'SELECT count(*) AS n FROM progreso_frases p JOIN c.frases f ON f.id = p.frase WHERE p.proximo_repaso <= ?',
        [_segundos(ahora ?? DateTime.now())]);
    return filas.first['n'] as int? ?? 0;
  }

  /// Avance por situación, en el orden de la app.
  Future<List<AvanceFrases>> avanceFrases() async {
    final filas = await _bd.rawQuery('''
      SELECT f.situacion, count(*) AS total, count(p.frase) AS estudiadas,
             sum(CASE WHEN p.intervalo >= 21 THEN 1 ELSE 0 END) AS dominadas
      $_desdeFrases GROUP BY f.situacion
    ''');
    final porClave = {for (final f in filas) f['situacion'] as String: f};
    return [
      for (final s in Situacion.values)
        if (porClave[s.clave] case final f?)
          AvanceFrases(
            situacion: s,
            total: f['total'] as int? ?? 0,
            estudiadas: f['estudiadas'] as int? ?? 0,
            dominadas: f['dominadas'] as int? ?? 0,
          ),
    ];
  }
}

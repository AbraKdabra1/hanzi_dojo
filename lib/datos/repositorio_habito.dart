// ─────────────────────────────────────────────────────────────────────────────
// repositorio_habito.dart — Consultas del hábito (fase 6)
//
//   · Meta diaria: cuántos repasos y ejercicios llevas hoy contra tu meta.
//   · Protector de racha: un día sin práctica por semana no rompe la racha
//     (Estadisticas.diasAProteger); los días cubiertos van a `protecciones`.
//   · Logros: se revisan al volver al inicio; los nuevos se guardan en `logros`.
//   · Recordatorio diario: la hora elegida (el aviso lo programa Android, ver
//     helpers/habito.dart y Recordatorios.kt).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'estadisticas.dart';
import 'logros.dart';
import 'repositorio.dart';

int _segundos(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

DateTime _inicioDelDia(DateTime t) => DateTime(t.year, t.month, t.day);

String _dos(int n) => n.toString().padLeft(2, '0');

/// '2026-10-04' (así se guardan los días protegidos).
String textoDeDia(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

extension HabitoRepositorio on Repositorio {
  Database get _bd => base.db;

  // ═══════════════════════════════════════════════════════════════════════
  // Meta diaria
  // ═══════════════════════════════════════════════════════════════════════

  static const metaPorDefecto = 20;

  /// Opciones de meta (repasos y ejercicios por día) con su nombre.
  static const opcionesMeta = [(10, 'Suave'), (20, 'Normal'), (40, 'Seria'), (60, 'Intensa')];

  Future<int> metaDiaria() async => int.tryParse(await base.leerAjuste('meta_diaria') ?? '') ?? metaPorDefecto;

  Future<void> guardarMetaDiaria(int n) => base.guardarAjuste('meta_diaria', '$n');

  /// Repasos de escritura y ejercicios con audio de hoy.
  Future<int> actividadHoy({DateTime? ahora}) async {
    final inicio = _segundos(_inicioDelDia(ahora ?? DateTime.now()));
    final filas = await _bd.rawQuery(
      'SELECT (SELECT count(*) FROM historial WHERE momento >= ?) + '
      '(SELECT count(*) FROM ejercicios WHERE momento >= ?) AS n',
      [inicio, inicio],
    );
    return filas.first['n'] as int? ?? 0;
  }

  /// ¿Ya se celebró hoy que cumpliste la meta? (Para avisarlo una sola vez.)
  Future<bool> metaCelebradaHoy({DateTime? ahora}) async =>
      await base.leerAjuste('meta_celebrada') == textoDeDia(ahora ?? DateTime.now());

  Future<void> marcarMetaCelebrada({DateTime? ahora}) =>
      base.guardarAjuste('meta_celebrada', textoDeDia(ahora ?? DateTime.now()));

  // ═══════════════════════════════════════════════════════════════════════
  // Racha y protector
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<DateTime>> diasProtegidos() async {
    final filas = await _bd.rawQuery('SELECT dia FROM protecciones ORDER BY dia');
    return [for (final f in filas) ?DateTime.tryParse(f['dia'] as String)];
  }

  /// Si ayer (o los días desde tu última práctica) no practicaste y el
  /// protector de esa semana está libre, lo usa. Devuelve los días que acaba
  /// de cubrir (vacío casi siempre).
  Future<List<DateTime>> aplicarProtector({DateTime? ahora}) async {
    final hoy = ahora ?? DateTime.now();
    final actividad = await actividadPorDia(ahora: hoy);
    final protegidos = await diasProtegidos();
    final nuevos = Estadisticas.diasAProteger(actividad.map((d) => d.dia), protegidos, hoy);
    if (nuevos.isEmpty) return const [];
    final lote = _bd.batch();
    for (final d in nuevos) {
      lote.insert('protecciones', {'dia': textoDeDia(d), 'momento': _segundos(hoy)},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await lote.commit(noResult: true);
    return nuevos;
  }

  /// Racha actual y máxima, contando los días protegidos.
  Future<Racha> rachaConProtector({DateTime? ahora}) async {
    final hoy = ahora ?? DateTime.now();
    final actividad = await actividadPorDia(ahora: hoy);
    final protegidos = await diasProtegidos();
    return Estadisticas.racha([...actividad.map((d) => d.dia), ...protegidos], hoy);
  }

  /// ¿Queda protector esta semana?
  Future<bool> protectorDisponible({DateTime? ahora}) async {
    final lunes = Estadisticas.lunes(ahora ?? DateTime.now());
    final protegidos = await diasProtegidos();
    return !protegidos.any((d) => Estadisticas.lunes(d) == lunes);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Logros
  // ═══════════════════════════════════════════════════════════════════════

  Future<DatosLogros> datosLogros({DateTime? ahora}) async {
    final hoy = ahora ?? DateTime.now();
    final niveles = await avancePorNivel();
    final racha = await rachaConProtector(ahora: hoy);
    final meta = await metaDiaria();
    final actividad = await actividadPorDia(ahora: hoy);
    Future<int> contar(String sql, [List<Object?> args = const []]) async =>
        (await _bd.rawQuery(sql, args)).first['n'] as int? ?? 0;
    final libros = await contar('''
      SELECT count(*) AS n FROM c.libros l
      WHERE (SELECT count(*) FROM c.capitulos k WHERE k.libro_id = l.id) > 0
        AND (SELECT count(*) FROM lectura r JOIN c.capitulos k ON k.libro_id = l.id AND k.orden = r.capitulo
             WHERE r.libro = l.clave) >= (SELECT count(*) FROM c.capitulos k WHERE k.libro_id = l.id)
    ''');
    final tonos = await _bd.rawQuery(
        "SELECT resultado FROM ejercicios WHERE tipo IN ('tono', 'tonos_palabra') ORDER BY id");
    return DatosLogros(
      caracteres: await totalEstudiados(),
      palabras: await contar('SELECT count(*) AS n FROM progreso_palabras'),
      rachaMaxima: racha.maxima,
      estudiadosPorNivel: {for (final n in niveles) n.nivel: n.estudiados},
      totalPorNivel: {for (final n in niveles) n.nivel: n.total},
      librosTerminados: libros,
      totalLibros: await contar('SELECT count(*) AS n FROM c.libros'),
      mejorSerieTonos: Estadisticas.mejorSerie(tonos.map((f) => (f['resultado'] as int? ?? 0) >= 1)),
      repasos: await totalRepasos() + await contar('SELECT count(*) AS n FROM ejercicios'),
      diasConMeta: actividad.where((d) => d.repasos >= meta).length,
    );
  }

  /// Logros desbloqueados → cuándo.
  Future<Map<String, DateTime>> logrosDesbloqueados() async {
    final filas = await _bd.rawQuery('SELECT clave, momento FROM logros');
    return {
      for (final f in filas)
        f['clave'] as String: DateTime.fromMillisecondsSinceEpoch((f['momento'] as int) * 1000),
    };
  }

  /// Revisa los logros: guarda y devuelve los que acabas de desbloquear.
  Future<List<Logro>> revisarLogros({DateTime? ahora}) async {
    final t = ahora ?? DateTime.now();
    final datos = await datosLogros(ahora: t);
    final nuevos = Logros.nuevos(datos, (await logrosDesbloqueados()).keys.toSet());
    if (nuevos.isEmpty) return const [];
    final lote = _bd.batch();
    for (final l in nuevos) {
      lote.insert('logros', {'clave': l.clave, 'momento': _segundos(t)}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await lote.commit(noResult: true);
    return nuevos;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Recordatorio
  // ═══════════════════════════════════════════════════════════════════════

  /// Hora del recordatorio diario (hora, minuto), o null si está apagado.
  Future<(int, int)?> recordatorio() async {
    final texto = await base.leerAjuste('recordatorio') ?? '';
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(texto);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  Future<void> guardarRecordatorio((int, int)? hora) =>
      base.guardarAjuste('recordatorio', hora == null ? '' : '${hora.$1}:${_dos(hora.$2)}');
}

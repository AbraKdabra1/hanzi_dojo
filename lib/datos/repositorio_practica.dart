// ─────────────────────────────────────────────────────────────────────────────
// repositorio_practica.dart — Consultas de la práctica con audio (fase 5)
//
// Se agregan al Repositorio como extensión para no hacer más largo
// repositorio.dart. Tablas:
//   c.palabras         → vocabulario HSK (contenido, solo lectura)
//   c.caracteres       → sílabas para el entrenador de tonos
//   progreso_palabras  → repaso espaciado de cada palabra (SM-2, por texto)
//   ejercicios         → cada respuesta de tonos, escucha, pinyin y vocabulario
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'practica.dart';
import 'repositorio.dart';
import 'srs.dart';

const _columnasPalabra = 'w.id, w.palabra, w.forma, w.pinyin, w.pinyin_num, w.clase, w.nivel_hsk, '
    'w.significado_es, w.significado_en, w.audio';

const _progresoPalabra = 'p.intervalo AS p_intervalo, p.factor AS p_factor, '
    'p.aciertos_seguidos AS p_aciertos_seguidos, p.veces_visto AS p_veces_visto, '
    'p.proximo_repaso AS p_proximo_repaso';

const _desdePalabras = 'FROM c.palabras w LEFT JOIN progreso_palabras p ON p.palabra = w.palabra';

int _segundos(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

DateTime _inicioDelDia(DateTime t) => DateTime(t.year, t.month, t.day);

extension PracticaRepositorio on Repositorio {
  Database get _bd => base.db;

  // ═══════════════════════════════════════════════════════════════════════
  // Material para los ejercicios
  // ═══════════════════════════════════════════════════════════════════════

  /// Caracteres HSK al azar hasta [nivel], como (carácter, pinyin con número,
  /// pinyin con acentos, significado). El entrenador de tonos se queda con
  /// los que tienen grabación (SilabaTono.conGrabacion).
  Future<List<(String, String, String, String)>> caracteresParaTonos({required int nivel, int cantidad = 120}) async {
    final filas = await _bd.rawQuery(
      "SELECT caracter, pinyin_num, pinyin, coalesce(significado_es, significado_en) AS significado "
      "FROM c.caracteres WHERE nivel_hsk BETWEEN 1 AND ? AND pinyin_num != '' ORDER BY random() LIMIT ?",
      [nivel, cantidad],
    );
    return [
      for (final f in filas)
        (f['caracter'] as String, f['pinyin_num'] as String, f['pinyin'] as String, f['significado'] as String? ?? ''),
    ];
  }

  /// Palabras al azar de un nivel ([soloEseNivel]) o hasta ese nivel.
  /// [caracteres]: solo de ese largo. [conAudio]: solo con grabación propia.
  /// [sinErhua]: sin las que terminan en 儿 de erhua (一点儿).
  Future<List<Palabra>> palabrasAlAzar({
    required int nivel,
    int cantidad = 40,
    bool soloEseNivel = true,
    bool conAudio = false,
    int? caracteres,
    bool sinErhua = false,
  }) async {
    final condiciones = <String>[soloEseNivel ? 'w.nivel_hsk = ?' : 'w.nivel_hsk BETWEEN 1 AND ?'];
    final args = <Object>[nivel];
    if (conAudio) condiciones.add('w.audio = 1');
    if (caracteres != null) {
      condiciones.add('length(w.palabra) = ?');
      args.add(caracteres);
    }
    if (sinErhua) condiciones.add("instr(w.pinyin_num, '_') = 0");
    final filas = await _bd.rawQuery(
      'SELECT $_columnasPalabra, $_progresoPalabra $_desdePalabras '
      'WHERE ${condiciones.join(' AND ')} ORDER BY random() LIMIT ?',
      [...args, cantidad],
    );
    return filas.map(Palabra.desdeFila).toList();
  }

  /// Una palabra por su texto (para consultarla desde otras pantallas).
  Future<Palabra?> palabraPorTexto(String texto) async {
    final filas = await _bd.rawQuery(
        'SELECT $_columnasPalabra, $_progresoPalabra $_desdePalabras WHERE w.palabra = ?', [texto]);
    return filas.isEmpty ? null : Palabra.desdeFila(filas.first);
  }

  /// Las palabras HSK que existan entre [textos] (para encontrar en un libro
  /// la palabra a la que pertenece un carácter).
  Future<List<Palabra>> palabrasPorTextos(Iterable<String> textos) async {
    final lista = textos.toSet().toList();
    if (lista.isEmpty) return const [];
    final marcas = List.filled(lista.length, '?').join(', ');
    final filas = await _bd.rawQuery(
        'SELECT $_columnasPalabra, $_progresoPalabra $_desdePalabras WHERE w.palabra IN ($marcas)', lista);
    return filas.map(Palabra.desdeFila).toList();
  }

  /// Agrega una palabra al repaso de vocabulario (fase 7, desde «Leer»):
  /// queda para repasar hoy mismo. Si ya estaba, no cambia nada.
  Future<void> agregarPalabraARepaso(Palabra p, {DateTime? ahora}) async {
    final t = _segundos(ahora ?? DateTime.now());
    await _bd.rawInsert('''
      INSERT OR IGNORE INTO progreso_palabras (palabra, intervalo, factor, aciertos_seguidos, veces_visto,
                                               proximo_repaso, primera_vez, ultima_vez)
      VALUES (?, 0, 2.5, 0, 0, ?, ?, ?)
    ''', [p.palabra, t, t, t]);
  }

  /// Guarda una respuesta de un ejercicio (tabla ejercicios).
  Future<void> registrarEjercicio(
    String tipo,
    String elemento, {
    required bool correcto,
    String respuesta = '',
    int duracionMs = 0,
    DateTime? ahora,
  }) async {
    await _bd.insert('ejercicios', {
      'tipo': tipo,
      'elemento': elemento,
      'momento': _segundos(ahora ?? DateTime.now()),
      'resultado': correcto ? 1 : 0,
      'respuesta': respuesta,
      'duracion_ms': duracionMs.clamp(0, 10 * 60 * 1000),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Repaso de vocabulario (SM-2, igual que los caracteres)
  // ═══════════════════════════════════════════════════════════════════════

  Future<Palabra?> palabra(int id) async {
    final filas =
        await _bd.rawQuery('SELECT $_columnasPalabra, $_progresoPalabra $_desdePalabras WHERE w.id = ?', [id]);
    return filas.isEmpty ? null : Palabra.desdeFila(filas.first);
  }

  /// Siguiente palabra: primero las que tocan hoy (de cualquier nivel: es tu
  /// vocabulario); después una nueva de [nivel], si [permitirNuevas].
  Future<Palabra?> siguientePalabra({
    required int nivel,
    required bool permitirNuevas,
    Set<int> excluir = const {},
    DateTime? ahora,
  }) async {
    final noEn = excluir.isEmpty ? '' : ' AND w.id NOT IN (${excluir.join(',')})';
    final t = _segundos(ahora ?? DateTime.now());
    final vencidas = await _bd.rawQuery(
      'SELECT w.id $_desdePalabras WHERE p.palabra IS NOT NULL AND p.proximo_repaso <= ?$noEn '
      'ORDER BY p.proximo_repaso LIMIT 1',
      [t],
    );
    if (vencidas.isNotEmpty) return palabra(vencidas.first['id'] as int);
    if (!permitirNuevas) return null;

    // Nueva: la que tenga más caracteres que ya estudiaste.
    final candidatas = await _bd.rawQuery(
        'SELECT w.id, w.palabra $_desdePalabras WHERE w.nivel_hsk = ? AND p.palabra IS NULL$noEn ORDER BY w.orden',
        [nivel]);
    if (candidatas.isEmpty) return null;
    final conocidos = {for (final f in await _bd.rawQuery('SELECT caracter FROM progreso')) f['caracter'] as String};
    final id = elegirPalabraNueva(
        [for (final f in candidatas) (f['id'] as int, f['palabra'] as String)], conocidos);
    return id == null ? null : palabra(id);
  }

  Future<bool> quedanPalabrasNuevas(int nivel) async {
    final filas = await _bd.rawQuery(
        'SELECT 1 $_desdePalabras WHERE w.nivel_hsk = ? AND p.palabra IS NULL LIMIT 1', [nivel]);
    return filas.isNotEmpty;
  }

  /// Guarda cómo te fue con una palabra (SM-2) y lo anota en ejercicios.
  Future<void> registrarPalabra(Palabra p, Calificacion calificacion, {int duracionMs = 0, DateTime? ahora}) async {
    final t = ahora ?? DateTime.now();
    await _bd.transaction((txn) async {
      final filas = await txn.rawQuery(
          'SELECT intervalo, factor, aciertos_seguidos FROM progreso_palabras WHERE palabra = ?', [p.palabra]);
      final anterior = filas.isEmpty ? null : filas.first;
      final estado = EstadoSrs(
        intervaloDias: anterior?['intervalo'] as int? ?? 0,
        factor: (anterior?['factor'] as num?)?.toDouble() ?? EstadoSrs.factorInicial,
        aciertosSeguidos: anterior?['aciertos_seguidos'] as int? ?? 0,
      ).calificar(calificacion);
      final proximo = _segundos(estado.proximoRepaso(t));
      if (anterior != null) {
        await txn.rawUpdate('''
          UPDATE progreso_palabras SET intervalo = ?, factor = ?, aciertos_seguidos = ?,
                 veces_visto = veces_visto + 1, proximo_repaso = ?, ultima_vez = ?
          WHERE palabra = ?
        ''', [estado.intervaloDias, estado.factor, estado.aciertosSeguidos, proximo, _segundos(t), p.palabra]);
      } else {
        await txn.rawInsert('''
          INSERT INTO progreso_palabras (palabra, intervalo, factor, aciertos_seguidos, veces_visto,
                                         proximo_repaso, primera_vez, ultima_vez)
          VALUES (?, ?, ?, ?, 1, ?, ?, ?)
        ''', [p.palabra, estado.intervaloDias, estado.factor, estado.aciertosSeguidos, proximo, _segundos(t), _segundos(t)]);
      }
      await txn.insert('ejercicios', {
        'tipo': TipoEjercicio.palabra,
        'elemento': p.palabra,
        'momento': _segundos(t),
        'resultado': calificacion.q,
        'respuesta': '',
        'duracion_ms': duracionMs.clamp(0, 10 * 60 * 1000),
      });
    });
  }

  /// Palabras que tocan hoy.
  Future<int> palabrasPendientes({DateTime? ahora}) async {
    final filas = await _bd.rawQuery('SELECT count(*) AS n FROM progreso_palabras WHERE proximo_repaso <= ?',
        [_segundos(ahora ?? DateTime.now())]);
    return filas.first['n'] as int? ?? 0;
  }

  /// Palabras nuevas que empezaste hoy.
  Future<int> nuevasPalabrasHoy({DateTime? ahora}) async {
    final filas = await _bd.rawQuery('SELECT count(*) AS n FROM progreso_palabras WHERE primera_vez >= ?',
        [_segundos(_inicioDelDia(ahora ?? DateTime.now()))]);
    return filas.first['n'] as int? ?? 0;
  }

  /// Avance del vocabulario por nivel (total, estudiadas, dominadas).
  Future<List<AvancePalabras>> avancePalabras() async {
    final filas = await _bd.rawQuery('''
      SELECT w.nivel_hsk AS nivel, count(*) AS total, count(p.palabra) AS estudiadas,
             sum(CASE WHEN p.intervalo >= 21 THEN 1 ELSE 0 END) AS dominadas
      $_desdePalabras GROUP BY w.nivel_hsk ORDER BY w.nivel_hsk
    ''');
    return [
      for (final f in filas)
        AvancePalabras(
          nivel: f['nivel'] as int,
          total: f['total'] as int? ?? 0,
          estudiadas: f['estudiadas'] as int? ?? 0,
          dominadas: f['dominadas'] as int? ?? 0,
        ),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Estadísticas de la práctica
  // ═══════════════════════════════════════════════════════════════════════

  /// Aciertos por tipo de ejercicio en los últimos [dias] días.
  Future<List<ResumenEjercicio>> resumenEjercicios({int dias = 30, DateTime? ahora}) async {
    final t = ahora ?? DateTime.now();
    final desde = _segundos(DateTime(t.year, t.month, t.day - dias));
    final filas = await _bd.rawQuery('''
      SELECT tipo, count(*) AS n, sum(CASE WHEN resultado >= 1 THEN 1 ELSE 0 END) AS bien
      FROM ejercicios WHERE momento >= ? AND tipo != ? GROUP BY tipo
    ''', [desde, TipoEjercicio.palabra]);
    final porTipo = {for (final f in filas) f['tipo'] as String: f};
    return [
      for (final tipo in [TipoEjercicio.tono, TipoEjercicio.tonosPalabra, TipoEjercicio.escucha, TipoEjercicio.pinyin])
        ResumenEjercicio(
          tipo: tipo,
          total: porTipo[tipo]?['n'] as int? ?? 0,
          aciertos: porTipo[tipo]?['bien'] as int? ?? 0,
        ),
    ];
  }

  /// La mejor calificación de simulacro de cada nivel (nivel → 0-100).
  Future<Map<int, int>> mejoresSimulacros() async {
    final filas = await _bd.rawQuery(
        "SELECT elemento, respuesta FROM ejercicios WHERE tipo = 'examen' AND elemento LIKE 'simulacro:%'");
    final mejores = <int, int>{};
    for (final f in filas) {
      final nivel = int.tryParse((f['elemento'] as String).split(':').last);
      final nota = int.tryParse(f['respuesta'] as String);
      if (nivel == null || nota == null) continue;
      if (nota > (mejores[nivel] ?? -1)) mejores[nivel] = nota;
    }
    return mejores;
  }

  /// Nivel sugerido por el último examen de ubicación (null si nunca lo hiciste).
  Future<int?> ultimaUbicacion() async {
    final filas = await _bd.rawQuery(
        "SELECT respuesta FROM ejercicios WHERE tipo = 'examen' AND elemento = 'ubicacion' ORDER BY momento DESC, id DESC LIMIT 1");
    return filas.isEmpty ? null : int.tryParse(filas.first['respuesta'] as String);
  }

  /// Los tonos que más confundes (de los ejercicios de tonos).
  Future<List<ConfusionTono>> confusionTonos() async {
    final filas = await _bd.rawQuery('SELECT elemento, respuesta FROM ejercicios WHERE tipo IN (?, ?) AND resultado = 0',
        [TipoEjercicio.tono, TipoEjercicio.tonosPalabra]);
    return confusionesDeTono([for (final f in filas) (f['elemento'] as String, f['respuesta'] as String)]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Ajustes de la práctica
  // ═══════════════════════════════════════════════════════════════════════

  static const limitePalabrasPorDefecto = 10;

  Future<int> limitePalabrasPorDia() async =>
      int.tryParse(await base.leerAjuste('palabras_por_dia') ?? '') ?? limitePalabrasPorDefecto;

  Future<void> guardarLimitePalabrasPorDia(int n) => base.guardarAjuste('palabras_por_dia', '$n');

  /// Nivel HSK elegido para practicar (1-7).
  Future<int> nivelPractica() async => (int.tryParse(await base.leerAjuste('practica_nivel') ?? '') ?? 1).clamp(1, 7);

  Future<void> guardarNivelPractica(int nivel) => base.guardarAjuste('practica_nivel', '$nivel');

  /// ¿Las grabaciones suenan más lentas? (Ajustes › Voz lenta.)
  Future<bool> vozLenta() async => await base.leerAjuste('voz_lenta') == '1';

  Future<void> guardarVozLenta(bool lenta) => base.guardarAjuste('voz_lenta', lenta ? '1' : '0');
}

/// Avance del vocabulario en un nivel.
class AvancePalabras {
  const AvancePalabras({required this.nivel, required this.total, required this.estudiadas, required this.dominadas});

  final int nivel;
  final int total;
  final int estudiadas;
  final int dominadas;
}

/// El Repositorio real como fuente de la sesión de vocabulario.
class FuentePalabrasRepositorio implements FuentePalabras {
  FuentePalabrasRepositorio(this.repo);
  final Repositorio repo;

  @override
  Future<Palabra?> siguientePalabra({required int nivel, required bool permitirNuevas, required Set<int> excluir}) =>
      repo.siguientePalabra(nivel: nivel, permitirNuevas: permitirNuevas, excluir: excluir);
  @override
  Future<Palabra?> palabra(int id) => repo.palabra(id);
  @override
  Future<void> registrarPalabra(Palabra p, Calificacion calificacion, {int duracionMs = 0}) =>
      repo.registrarPalabra(p, calificacion, duracionMs: duracionMs);
  @override
  Future<int> nuevasPalabrasHoy() => repo.nuevasPalabrasHoy();
  @override
  Future<int> limitePalabrasPorDia() => repo.limitePalabrasPorDia();
  @override
  Future<bool> quedanPalabrasNuevas(int nivel) => repo.quedanPalabrasNuevas(nivel);
}

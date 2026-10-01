// ─────────────────────────────────────────────────────────────────────────────
// repositorio.dart — Todas las consultas de la app en un solo lugar
//
// Las pantallas nunca escriben SQL: le piden datos al Repositorio.
// Tablas (ver base_datos.dart):
//   c.caracteres, c.radicales, c.ejemplos  → contenido (solo lectura)
//   c.libros, c.capitulos, c.parrafos      → sección «Leer» (solo lectura)
//   progreso, historial, lectura, ajustes   → tu avance
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'base_datos.dart';
import 'modelos.dart';
import 'srs.dart';

/// Qué conjunto de caracteres se está estudiando en una sesión.
class FiltroEstudio {
  const FiltroEstudio._(this.tipo, {this.nivel = 0, this.radical = 0, this.caracterId = 0,
      this.incluirFueraHsk = false});

  /// Caracteres de un nivel HSK (1-6, o 7 = 7-9).
  const FiltroEstudio.nivel(int nivel) : this._(TipoFiltro.nivel, nivel: nivel);

  /// La familia de un radical: todos los caracteres que lo tienen como radical.
  const FiltroEstudio.familia(int radical, {bool incluirFueraHsk = false})
      : this._(TipoFiltro.familia, radical: radical, incluirFueraHsk: incluirFueraHsk);

  /// Los 214 radicales en sí, empezando por los que forman más caracteres HSK.
  const FiltroEstudio.radicales() : this._(TipoFiltro.radicales);

  /// Un solo carácter (al tocarlo en una búsqueda o en una familia).
  const FiltroEstudio.unico(int caracterId) : this._(TipoFiltro.unico, caracterId: caracterId);

  final TipoFiltro tipo;
  final int nivel;
  final int radical;
  final int caracterId;
  final bool incluirFueraHsk;

  /// Condición SQL sobre la tabla c.caracteres (alias `x`).
  (String, List<Object?>) get condicion => switch (tipo) {
        TipoFiltro.nivel => ('x.nivel_hsk = ?', [nivel]),
        TipoFiltro.familia => incluirFueraHsk
            ? ('x.radical = ?', [radical])
            : ('x.radical = ? AND x.nivel_hsk > 0', [radical]),
        TipoFiltro.radicales => ('x.id IN (SELECT caracter_id FROM c.radicales)', []),
        TipoFiltro.unico => ('x.id = ?', [caracterId]),
      };

  /// Orden en que aparecen los caracteres NUEVOS.
  String get ordenNuevos => switch (tipo) {
        // Primero los que aparecen en más palabras HSK: son los más útiles.
        TipoFiltro.nivel => 'x.frecuencia DESC, x.orden_oficial',
        // Familia: por nivel (1 → 7-9, y al final los que no son HSK).
        TipoFiltro.familia => '(x.nivel_hsk = 0), x.nivel_hsk, x.frecuencia DESC, x.id',
        // Radicales: los que forman más caracteres HSK primero.
        TipoFiltro.radicales =>
          '(SELECT max(r.total_hsk) FROM c.radicales r WHERE r.caracter_id = x.id) DESC, x.radical',
        TipoFiltro.unico => 'x.id',
      };

  /// En modo "único" el carácter se muestra aunque ya esté estudiado y
  /// aunque se haya llegado al límite diario.
  bool get esUnico => tipo == TipoFiltro.unico;

  /// Título para la barra superior de la pantalla de estudio.
  String get titulo => switch (tipo) {
        TipoFiltro.nivel => nombreDeNivel(nivel),
        TipoFiltro.familia => 'Familia del radical $radical',
        TipoFiltro.radicales => 'Radicales Kangxi',
        TipoFiltro.unico => 'Práctica libre',
      };
}

enum TipoFiltro { nivel, familia, radicales, unico }

class Repositorio {
  Repositorio(this.base);

  final BaseDatos base;
  Database get _db => base.db;

  // Columnas de c.caracteres sin los trazos (para listas; son ligeras).
  static const _basicas = 'x.id, x.caracter, x.pinyin, x.pinyin_num, x.otras_lecturas, '
      'x.significado_es, x.significado_en, x.nivel_hsk, x.nivel_escritura, x.radical, '
      'x.num_trazos, x.es_forma_radical';

  // Columnas de progreso con prefijo p_ (las lee Progreso.desdeFila).
  static const _progreso = 'p.intervalo AS p_intervalo, p.factor AS p_factor, '
      'p.aciertos_seguidos AS p_aciertos_seguidos, p.veces_visto AS p_veces_visto, '
      'p.proximo_repaso AS p_proximo_repaso';

  static const _desde = 'FROM c.caracteres x LEFT JOIN progreso p ON p.caracter = x.caracter';

  static int _segundos(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  static DateTime _inicioDelDia(DateTime t) => DateTime(t.year, t.month, t.day);

  // ═══════════════════════════════════════════════════════════════════════
  // Caracteres
  // ═══════════════════════════════════════════════════════════════════════

  /// Un carácter completo (con trazos) para estudiarlo.
  Future<Caracter?> caracter(int id) async {
    final filas = await _db.rawQuery(
        'SELECT $_basicas, x.trazos_svg, x.medianas, $_progreso $_desde WHERE x.id = ?', [id]);
    return filas.isEmpty ? null : Caracter.desdeFila(filas.first);
  }

  /// Siguiente carácter a estudiar con este filtro:
  ///   1. primero los repasos que ya vencieron (el más atrasado primero);
  ///   2. después uno nuevo, si [permitirNuevos].
  /// [excluir] son ids que la sesión ya tiene apartados (para reaprender).
  Future<Caracter?> siguiente(
    FiltroEstudio filtro, {
    required bool permitirNuevos,
    Set<int> excluir = const {},
    DateTime? ahora,
  }) async {
    final (condicion, args) = filtro.condicion;
    final noEn = excluir.isEmpty ? '' : ' AND x.id NOT IN (${excluir.join(',')})';
    final t = _segundos(ahora ?? DateTime.now());

    if (filtro.esUnico) {
      return excluir.contains(filtro.caracterId) ? null : caracter(filtro.caracterId);
    }

    final vencidos = await _db.rawQuery(
      'SELECT x.id $_desde WHERE $condicion$noEn '
      'AND p.caracter IS NOT NULL AND p.proximo_repaso <= ? '
      'ORDER BY p.proximo_repaso LIMIT 1',
      [...args, t],
    );
    if (vencidos.isNotEmpty) return caracter(vencidos.first['id'] as int);

    if (!permitirNuevos) return null;
    final nuevos = await _db.rawQuery(
      'SELECT x.id $_desde WHERE $condicion$noEn AND p.caracter IS NULL '
      'ORDER BY ${filtro.ordenNuevos} LIMIT 1',
      args,
    );
    if (nuevos.isNotEmpty) return caracter(nuevos.first['id'] as int);
    return null;
  }

  /// ¿Quedan caracteres nuevos (nunca vistos) con este filtro?
  Future<bool> quedanNuevos(FiltroEstudio filtro) async {
    final (condicion, args) = filtro.condicion;
    final filas = await _db.rawQuery(
        'SELECT 1 $_desde WHERE $condicion AND p.caracter IS NULL LIMIT 1', args);
    return filas.isNotEmpty;
  }

  /// Guarda el resultado de practicar un carácter: actualiza su repaso
  /// espaciado y agrega una fila al historial con [detalle].
  ///
  /// El estado anterior se lee de la base DENTRO de la transacción (no de
  /// [c].progreso, que es una foto de cuando se cargó la tarjeta): si mientras
  /// tanto practicaste el mismo carácter en otra pantalla, no se pisa ese avance.
  Future<void> registrarRespuesta(
    Caracter c,
    Calificacion calificacion, {
    DetallePractica detalle = const DetallePractica(),
    DateTime? ahora,
  }) async {
    final t = ahora ?? DateTime.now();
    await _db.transaction((txn) async {
      final filas = await txn.rawQuery(
        'SELECT intervalo, factor, aciertos_seguidos FROM progreso WHERE caracter = ?',
        [c.caracter],
      );
      final anterior = filas.isEmpty ? null : filas.first;
      final estado = EstadoSrs(
        intervaloDias: anterior?['intervalo'] as int? ?? 0,
        factor: (anterior?['factor'] as num?)?.toDouble() ?? EstadoSrs.factorInicial,
        aciertosSeguidos: anterior?['aciertos_seguidos'] as int? ?? 0,
      ).calificar(calificacion);
      final proximo = _segundos(estado.proximoRepaso(t));

      // Se actualiza la fila si existe; si no, se crea. (No se usa "UPSERT"
      // porque el SQLite de Android anterior a la versión 11 no lo soporta.)
      if (anterior != null) {
        await txn.rawUpdate('''
          UPDATE progreso SET intervalo = ?, factor = ?, aciertos_seguidos = ?,
                 veces_visto = veces_visto + 1, proximo_repaso = ?, ultima_vez = ?
          WHERE caracter = ?
        ''', [
          estado.intervaloDias,
          estado.factor,
          estado.aciertosSeguidos,
          proximo,
          _segundos(t),
          c.caracter,
        ]);
      } else {
        await txn.rawInsert('''
          INSERT INTO progreso (caracter, intervalo, factor, aciertos_seguidos, veces_visto,
                                proximo_repaso, primera_vez, ultima_vez)
          VALUES (?, ?, ?, ?, 1, ?, ?, ?)
        ''', [
          c.caracter,
          estado.intervaloDias,
          estado.factor,
          estado.aciertosSeguidos,
          proximo,
          _segundos(t),
          _segundos(t),
        ]);
      }

      await txn.rawInsert('''
        INSERT INTO historial (caracter, momento, duracion_ms, calificacion, errores, al_reves,
                               fallos, modo_novato, nuevo, intervalo)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        c.caracter,
        _segundos(t),
        detalle.duracionGuardadaMs,
        calificacion.q,
        detalle.errores,
        detalle.alReves,
        FalloTrazo.escribirLista(detalle.fallos),
        detalle.modoNovato ? 1 : 0,
        anterior == null ? 1 : 0,
        estado.intervaloDias,
      ]);
    });
  }

  /// Cuántos repasos hay en el historial.
  Future<int> totalRepasos() async {
    final filas = await _db.rawQuery('SELECT count(*) AS n FROM historial');
    return filas.first['n'] as int? ?? 0;
  }

  /// Búsqueda por carácter, pinyin (con o sin tonos) o significado.
  /// Los caracteres HSK salen primero.
  Future<List<Caracter>> buscar(String texto) async {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return [];
    final plano = _quitarTonos(q);
    final filas = await _db.rawQuery(
      'SELECT $_basicas, $_progreso $_desde '
      'WHERE x.caracter = ? OR x.pinyin_plano = ? OR x.pinyin_plano LIKE ? '
      'OR lower(x.significado_es) LIKE ? OR lower(x.significado_en) LIKE ? '
      'ORDER BY (x.caracter = ?) DESC, (x.nivel_hsk = 0), x.nivel_hsk, '
      '(x.pinyin_plano = ?) DESC, x.frecuencia DESC LIMIT 60',
      [q, plano, '$plano%', '%$q%', '%$q%', q, plano],
    );
    return filas.map(Caracter.desdeFila).toList();
  }

  /// "nǚ" → "nv", "hǎo" → "hao" (igual que pinyin_plano en la base).
  static String _quitarTonos(String s) {
    const mapa = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    };
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(mapa[ch] ?? ch);
    }
    return b.toString().replaceAll(RegExp(r'[1-5\s]'), '');
  }

  Future<List<Ejemplo>> ejemplos(int caracterId) async {
    final filas = await _db.rawQuery(
        'SELECT chino, pinyin, espanol, ingles FROM c.ejemplos WHERE caracter_id = ? ORDER BY orden',
        [caracterId]);
    return filas.map(Ejemplo.desdeFila).toList();
  }

  /// Un carácter por su texto (para consultarlo al tocarlo en un libro).
  /// Sin trazos: solo lo necesario para mostrar su ficha.
  Future<Caracter?> caracterPorTexto(String texto) async {
    final filas =
        await _db.rawQuery('SELECT $_basicas, $_progreso $_desde WHERE x.caracter = ?', [texto]);
    return filas.isEmpty ? null : Caracter.desdeFila(filas.first);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Leer
  // ═══════════════════════════════════════════════════════════════════════

  static const _consultaLibros = '''
    SELECT l.*,
      (SELECT count(*) FROM c.capitulos k WHERE k.libro_id = l.id) AS num_capitulos,
      (SELECT count(*) FROM lectura r JOIN c.capitulos k ON k.libro_id = l.id AND k.orden = r.capitulo
        WHERE r.libro = l.clave) AS leidos
    FROM c.libros l
  ''';

  /// Todos los libros, del nivel más bajo al más alto, con cuánto llevas.
  Future<List<Libro>> libros() async {
    final filas = await _db.rawQuery('$_consultaLibros ORDER BY l.nivel_hsk, l.id');
    return filas.map(Libro.desdeFila).toList();
  }

  Future<Libro?> libro(int id) async {
    final filas = await _db.rawQuery('$_consultaLibros WHERE l.id = ?', [id]);
    return filas.isEmpty ? null : Libro.desdeFila(filas.first);
  }

  /// Capítulos de un libro, en orden, marcando los que ya terminaste.
  Future<List<CapituloLibro>> capitulos(Libro libro) async {
    final filas = await _db.rawQuery('''
      SELECT k.*,
        EXISTS (SELECT 1 FROM lectura r WHERE r.libro = ? AND r.capitulo = k.orden) AS leido
      FROM c.capitulos k WHERE k.libro_id = ? ORDER BY k.orden
    ''', [libro.clave, libro.id]);
    return filas.map(CapituloLibro.desdeFila).toList();
  }

  Future<List<ParrafoLibro>> parrafos(int capituloId) async {
    final filas = await _db.rawQuery(
        'SELECT chino, pinyin, nombres, espanol FROM c.parrafos WHERE capitulo_id = ? ORDER BY orden',
        [capituloId]);
    return filas.map(ParrafoLibro.desdeFila).toList();
  }

  /// Marca un capítulo como leído (o lo desmarca).
  Future<void> marcarCapitulo(String libro, int capitulo, {bool leido = true, DateTime? ahora}) async {
    if (leido) {
      await _db.rawInsert(
        'INSERT OR REPLACE INTO lectura (libro, capitulo, momento) VALUES (?, ?, ?)',
        [libro, capitulo, _segundos(ahora ?? DateTime.now())],
      );
    } else {
      await _db.rawDelete('DELETE FROM lectura WHERE libro = ? AND capitulo = ?', [libro, capitulo]);
    }
  }

  /// Cómo prefieres leer (se recuerda entre sesiones).
  Future<AjustesLectura> ajustesLectura() async => AjustesLectura(
        pinyin: await base.leerAjuste('lectura_pinyin') != '0',
        traduccion: await base.leerAjuste('lectura_traduccion') == '1',
        tamano: double.tryParse(await base.leerAjuste('lectura_tamano') ?? '') ??
            AjustesLectura.tamanoPorDefecto,
      );

  Future<void> guardarAjustesLectura(AjustesLectura a) async {
    await base.guardarAjuste('lectura_pinyin', a.pinyin ? '1' : '0');
    await base.guardarAjuste('lectura_traduccion', a.traduccion ? '1' : '0');
    await base.guardarAjuste('lectura_tamano', '${a.tamano}');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Radicales
  // ═══════════════════════════════════════════════════════════════════════

  static const _consultaRadicales = '''
    SELECT r.*,
      (SELECT count(*) FROM c.caracteres x JOIN progreso p ON p.caracter = x.caracter
        WHERE x.radical = r.numero AND x.nivel_hsk > 0) AS aprendidos_hsk,
      (SELECT count(*) FROM c.caracteres x JOIN progreso p ON p.caracter = x.caracter
        WHERE x.id = r.caracter_id) AS practicado
    FROM c.radicales r
  ''';

  Future<List<Radical>> radicales() async {
    final filas = await _db.rawQuery('$_consultaRadicales ORDER BY r.numero');
    return filas.map(Radical.desdeFila).toList();
  }

  Future<Radical?> radical(int numero) async {
    final filas = await _db.rawQuery('$_consultaRadicales WHERE r.numero = ?', [numero]);
    return filas.isEmpty ? null : Radical.desdeFila(filas.first);
  }

  /// Caracteres de la familia de un radical, del nivel más bajo al más alto.
  Future<List<Caracter>> familia(int numero, {bool incluirFueraHsk = false}) async {
    final filtroHsk = incluirFueraHsk ? '' : ' AND x.nivel_hsk > 0';
    final filas = await _db.rawQuery(
      'SELECT $_basicas, $_progreso $_desde WHERE x.radical = ?$filtroHsk '
      'ORDER BY (x.nivel_hsk = 0), x.nivel_hsk, x.frecuencia DESC, x.num_trazos',
      [numero],
    );
    return filas.map(Caracter.desdeFila).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Estadísticas y ajustes
  // ═══════════════════════════════════════════════════════════════════════

  /// Avance por nivel HSK (1-6 y 7-9).
  Future<List<AvanceNivel>> avancePorNivel() async {
    final filas = await _db.rawQuery('''
      SELECT x.nivel_hsk,
             count(*) AS total,
             count(p.caracter) AS estudiados,
             sum(CASE WHEN p.intervalo >= 21 THEN 1 ELSE 0 END) AS dominados
      $_desde
      WHERE x.nivel_hsk > 0
      GROUP BY x.nivel_hsk
      ORDER BY x.nivel_hsk
    ''');
    return filas.map(AvanceNivel.desdeFila).toList();
  }

  /// Repasos pendientes para hoy (en todos los niveles).
  Future<int> repasosPendientes({DateTime? ahora}) async {
    final t = _segundos(ahora ?? DateTime.now());
    final filas = await _db.rawQuery('SELECT count(*) AS n FROM progreso WHERE proximo_repaso <= ?', [t]);
    return filas.first['n'] as int? ?? 0;
  }

  /// Caracteres nuevos que empezaste hoy.
  Future<int> nuevosHoy({DateTime? ahora}) async {
    final inicio = _segundos(_inicioDelDia(ahora ?? DateTime.now()));
    final filas = await _db.rawQuery('SELECT count(*) AS n FROM progreso WHERE primera_vez >= ?', [inicio]);
    return filas.first['n'] as int? ?? 0;
  }

  /// Total de caracteres estudiados alguna vez.
  Future<int> totalEstudiados() async {
    final filas = await _db.rawQuery('SELECT count(*) AS n FROM progreso');
    return filas.first['n'] as int? ?? 0;
  }

  static const limitePorDefecto = 15;

  /// Cuántos caracteres nuevos por día (ajustable en Ajustes).
  Future<int> limiteNuevosPorDia() async =>
      int.tryParse(await base.leerAjuste('nuevos_por_dia') ?? '') ?? limitePorDefecto;

  Future<void> guardarLimiteNuevosPorDia(int n) => base.guardarAjuste('nuevos_por_dia', '$n');

  /// ¿Los trazos correctos se acomodan en su forma caligráfica? (Activo por defecto.)
  Future<bool> ajusteCaligrafico() async => await base.leerAjuste('ajuste_caligrafico') != '0';

  Future<void> guardarAjusteCaligrafico(bool activo) =>
      base.guardarAjuste('ajuste_caligrafico', activo ? '1' : '0');
}

/// Preferencias del lector.
class AjustesLectura {
  const AjustesLectura({this.pinyin = true, this.traduccion = false, this.tamano = tamanoPorDefecto});

  static const tamanoPorDefecto = 26.0;

  /// Tamaños de letra que se van alternando con el botón "Aa".
  static const tamanos = [22.0, 26.0, 30.0, 34.0];

  /// Pinyin arriba de cada carácter.
  final bool pinyin;

  /// Traducción debajo de cada párrafo.
  final bool traduccion;

  /// Tamaño de los caracteres.
  final double tamano;

  AjustesLectura copia({bool? pinyin, bool? traduccion, double? tamano}) => AjustesLectura(
        pinyin: pinyin ?? this.pinyin,
        traduccion: traduccion ?? this.traduccion,
        tamano: tamano ?? this.tamano,
      );

  /// El siguiente tamaño de [tamanos] (vuelve al primero después del último).
  double get siguienteTamano {
    final i = tamanos.indexWhere((t) => t > tamano);
    return i < 0 ? tamanos.first : tamanos[i];
  }
}

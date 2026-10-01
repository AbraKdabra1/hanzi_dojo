// ─────────────────────────────────────────────────────────────────────────────
// modelos.dart
//
// Clases con los datos que la app muestra. Cada una se construye a partir de
// una fila de la base de datos (un Map<String, Object?> de sqflite).
//
//   Caracter  → un hanzi con su lectura, significado, nivel, radical y trazos.
//   Radical   → uno de los 214 radicales Kangxi y cuánto de su familia llevas.
//   Ejemplo   → una oración de ejemplo con pinyin y traducción.
//   Progreso  → cómo vas con un carácter (repaso espaciado).
//   DetallePractica → cómo te fue al escribirlo (va al historial).
//   Libro, CapituloLibro, ParrafoLibro → la sección «Leer».
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:ui' show Offset;

/// Progreso del usuario con un carácter (tabla `progreso` de progreso.db).
class Progreso {
  const Progreso({
    required this.intervaloDias,
    required this.factor,
    required this.aciertosSeguidos,
    required this.vecesVisto,
    required this.proximoRepaso,
  });

  /// Días que faltaban entre el último repaso y el siguiente.
  final int intervaloDias;

  /// Factor de facilidad de SM-2 (mínimo 1.3). Más alto = el intervalo
  /// crece más rápido porque el carácter te resulta fácil.
  final double factor;

  /// Repasos seguidos calificados como "Medio" o "Fácil".
  final int aciertosSeguidos;

  /// Cuántas veces lo has practicado en total.
  final int vecesVisto;

  /// Cuándo toca volver a repasarlo.
  final DateTime proximoRepaso;

  /// Se considera "dominado" cuando el siguiente repaso está a 3 semanas o más.
  bool get dominado => intervaloDias >= 21;

  /// Lee las columnas `p_*` que agregan las consultas del repositorio.
  /// Devuelve null si el carácter nunca se ha estudiado.
  static Progreso? desdeFila(Map<String, Object?> f) {
    final visto = f['p_veces_visto'] as int?;
    if (visto == null) return null;
    return Progreso(
      intervaloDias: f['p_intervalo'] as int? ?? 0,
      factor: (f['p_factor'] as num?)?.toDouble() ?? 2.5,
      aciertosSeguidos: f['p_aciertos_seguidos'] as int? ?? 0,
      vecesVisto: visto,
      proximoRepaso: DateTime.fromMillisecondsSinceEpoch(
          ((f['p_proximo_repaso'] as int?) ?? 0) * 1000),
    );
  }
}

/// Un carácter chino con todos sus datos.
class Caracter {
  const Caracter({
    required this.id,
    required this.caracter,
    required this.pinyin,
    required this.pinyinNum,
    required this.otrasLecturas,
    required this.significadoEs,
    required this.significadoEn,
    required this.nivelHsk,
    required this.nivelEscritura,
    required this.radical,
    required this.numTrazos,
    required this.esFormaRadical,
    this.trazosSvgJson,
    this.medianasJson,
    this.progreso,
  });

  final int id;

  /// El carácter en sí: "好".
  final String caracter;

  /// Lectura principal con acentos ("hǎo") y con número ("hao3").
  final String pinyin;
  final String pinyinNum;

  /// Otras lecturas oficiales HSK, con acentos ("dì" para 地). Puede estar vacío.
  final String otrasLecturas;

  /// Significado en español (null si aún no hay traducción) y en inglés.
  final String? significadoEs;
  final String significadoEn;

  /// 1-6, 7 (= niveles 7-9) o 0 (fuera de HSK).
  final int nivelHsk;

  /// 1, 2 o 3 si está en la lista oficial de caracteres que se deben saber
  /// escribir a mano (básico, intermedio, avanzado). null si no.
  final int? nivelEscritura;

  /// Número de radical Kangxi (1-214).
  final int radical;

  final int numTrazos;

  /// true si el carácter es un radical o una variante de radical (氵, 亻…).
  final bool esFormaRadical;

  /// Datos de trazo en JSON. Solo vienen cuando se pidió el carácter
  /// completo (para estudiarlo); en listas se omiten para no cargar de más.
  final String? trazosSvgJson;
  final String? medianasJson;

  /// Progreso del usuario (null si nunca lo ha estudiado).
  final Progreso? progreso;

  /// Significado a mostrar: español si existe; si no, inglés.
  String get significado =>
      (significadoEs != null && significadoEs!.isNotEmpty) ? significadoEs! : significadoEn;

  bool get tieneEspanol => significadoEs != null && significadoEs!.isNotEmpty;

  bool get esHsk => nivelHsk > 0;

  /// "HSK 3", "HSK 7-9" o "Fuera de HSK".
  String get nombreNivel => nombreDeNivel(nivelHsk);

  /// Contornos SVG de cada trazo (sistema de coordenadas de 1024×1024).
  List<String> get trazosSvg =>
      trazosSvgJson == null ? const [] : List<String>.from(jsonDecode(trazosSvgJson!) as List);

  /// Línea central de cada trazo, en coordenadas de make-me-a-hanzi
  /// (y hacia arriba). Se usa para evaluar lo que dibujas.
  List<List<Offset>> get medianas {
    if (medianasJson == null) return const [];
    final datos = jsonDecode(medianasJson!) as List;
    return [
      for (final trazo in datos)
        [
          for (final p in trazo as List)
            Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ];
  }

  factory Caracter.desdeFila(Map<String, Object?> f) => Caracter(
        id: f['id'] as int,
        caracter: f['caracter'] as String,
        pinyin: f['pinyin'] as String? ?? '',
        pinyinNum: f['pinyin_num'] as String? ?? '',
        otrasLecturas: f['otras_lecturas'] as String? ?? '',
        significadoEs: f['significado_es'] as String?,
        significadoEn: f['significado_en'] as String? ?? '',
        nivelHsk: f['nivel_hsk'] as int? ?? 0,
        nivelEscritura: f['nivel_escritura'] as int?,
        radical: f['radical'] as int? ?? 0,
        numTrazos: f['num_trazos'] as int? ?? 0,
        esFormaRadical: (f['es_forma_radical'] as int? ?? 0) == 1,
        trazosSvgJson: f['trazos_svg'] as String?,
        medianasJson: f['medianas'] as String?,
        progreso: Progreso.desdeFila(f),
      );
}

/// "HSK 3", "HSK 7-9" o "Fuera de HSK" para un número de nivel.
String nombreDeNivel(int nivel) => switch (nivel) {
      0 => 'Fuera de HSK',
      7 => 'HSK 7-9',
      _ => 'HSK $nivel',
    };

/// Uno de los 214 radicales Kangxi.
class Radical {
  const Radical({
    required this.numero,
    required this.formaPrincipal,
    required this.variantes,
    required this.nombreEs,
    required this.pinyin,
    required this.trazos,
    required this.caracterId,
    required this.totalHsk,
    required this.total,
    required this.aprendidosHsk,
    required this.practicado,
  });

  final int numero;

  /// Forma que se muestra (水) y otras formas del mismo radical (氵 氺).
  final String formaPrincipal;
  final List<String> variantes;

  final String nombreEs;
  final String pinyin;

  /// Trazos del radical.
  final int trazos;

  /// Carácter que se usa para practicar el radical (null si no hay trazos).
  final int? caracterId;

  /// Caracteres HSK de su familia y cuántos de ellos ya estudiaste.
  final int totalHsk;
  final int aprendidosHsk;

  /// Todos los caracteres de su familia (incluye los que no son HSK).
  final int total;

  /// true si ya practicaste el radical en sí.
  final bool practicado;

  /// "水 氵 氺"
  String get todasLasFormas => [formaPrincipal, ...variantes].join(' ');

  factory Radical.desdeFila(Map<String, Object?> f) => Radical(
        numero: f['numero'] as int,
        formaPrincipal: f['forma_principal'] as String,
        variantes: (f['variantes'] as String? ?? '')
            .split(' ')
            .where((v) => v.isNotEmpty)
            .toList(),
        nombreEs: f['nombre_es'] as String? ?? '',
        pinyin: f['pinyin'] as String? ?? '',
        trazos: f['trazos'] as int? ?? 0,
        caracterId: f['caracter_id'] as int?,
        totalHsk: f['total_hsk'] as int? ?? 0,
        total: f['total'] as int? ?? 0,
        aprendidosHsk: f['aprendidos_hsk'] as int? ?? 0,
        practicado: (f['practicado'] as int? ?? 0) > 0,
      );
}

/// Oración de ejemplo.
class Ejemplo {
  const Ejemplo({
    required this.chino,
    required this.pinyin,
    required this.espanol,
    required this.ingles,
  });

  final String chino;
  final String pinyin;
  final String? espanol;
  final String? ingles;

  /// Traducción a mostrar: español si existe; si no, inglés.
  String get traduccion => (espanol != null && espanol!.isNotEmpty) ? espanol! : (ingles ?? '');

  factory Ejemplo.desdeFila(Map<String, Object?> f) => Ejemplo(
        chino: f['chino'] as String,
        pinyin: f['pinyin'] as String? ?? '',
        espanol: f['espanol'] as String?,
        ingles: f['ingles'] as String?,
      );
}

/// Resumen de avance de un nivel HSK (pantalla de estadísticas).
class AvanceNivel {
  const AvanceNivel({
    required this.nivel,
    required this.total,
    required this.estudiados,
    required this.dominados,
  });

  final int nivel;
  final int total;
  final int estudiados;
  final int dominados;

  double get fraccion => total == 0 ? 0 : estudiados / total;

  factory AvanceNivel.desdeFila(Map<String, Object?> f) => AvanceNivel(
        nivel: f['nivel_hsk'] as int,
        total: f['total'] as int? ?? 0,
        estudiados: f['estudiados'] as int? ?? 0,
        dominados: f['dominados'] as int? ?? 0,
      );
}

/// Un trazo que salió mal mientras escribías un carácter.
class FalloTrazo {
  const FalloTrazo(this.indice, {this.alReves = false});

  /// Número del trazo (0 = el primero).
  final int indice;

  /// true si la forma era la correcta pero lo hiciste en sentido contrario.
  final bool alReves;

  /// Cómo se guarda en el historial: "3" (error) o "3r" (al revés).
  String get codigo => alReves ? '${indice}r' : '$indice';

  /// Lee una lista guardada como "0,3r,3".
  static List<FalloTrazo> leerLista(String texto) => [
        for (final parte in texto.split(','))
          if (int.tryParse(parte.replaceAll('r', '')) case final n?)
            FalloTrazo(n, alReves: parte.endsWith('r')),
      ];

  static String escribirLista(List<FalloTrazo> fallos) => fallos.map((f) => f.codigo).join(',');

  @override
  bool operator ==(Object other) =>
      other is FalloTrazo && other.indice == indice && other.alReves == alReves;

  @override
  int get hashCode => Object.hash(indice, alReves);

  @override
  String toString() => codigo;
}

/// Cómo te fue al practicar un carácter. Se guarda en la tabla `historial`
/// (una fila por repaso), que es la base de las estadísticas.
class DetallePractica {
  const DetallePractica({
    this.duracion = Duration.zero,
    this.fallos = const [],
    this.modoNovato = true,
  });

  /// Tiempo desde que apareció la tarjeta hasta que la calificaste.
  final Duration duracion;

  /// Los trazos que fallaste, en orden (un trazo puede aparecer varias veces).
  final List<FalloTrazo> fallos;

  final bool modoNovato;

  int get errores => fallos.length;
  int get alReves => fallos.where((f) => f.alReves).length;

  /// Duración máxima que se guarda: si dejaste la tarjeta abierta y te fuiste,
  /// no se cuenta como una hora de estudio.
  static const duracionMaxima = Duration(minutes: 10);

  int get duracionGuardadaMs =>
      (duracion > duracionMaxima ? duracionMaxima : duracion).inMilliseconds;
}

// ─── Sección «Leer» ──────────────────────────────────────────────────────────

/// Un libro graduado (tabla c.libros) y cuánto llevas leído.
class Libro {
  const Libro({
    required this.id,
    required this.clave,
    required this.titulo,
    required this.tituloPinyin,
    required this.tituloEs,
    required this.nivelHsk,
    required this.adaptado,
    required this.descripcion,
    required this.fuente,
    required this.cobertura,
    required this.caracteres,
    required this.capitulos,
    required this.capitulosLeidos,
  });

  final int id;

  /// Identificador estable (el progreso de lectura se guarda con esta clave).
  final String clave;
  final String titulo;
  final String tituloPinyin;
  final String tituloEs;

  /// 1-6, o 7 = HSK 7-9.
  final int nivelHsk;

  /// true: historia clásica contada de nuevo para la app con vocabulario de
  /// su nivel. false: texto clásico original.
  final bool adaptado;
  final String descripcion;

  /// De dónde viene la historia o el texto, y su licencia.
  final String fuente;

  /// Fracción de caracteres que ya conoce alguien de ese nivel.
  final double cobertura;
  final int caracteres;
  final int capitulos;
  final int capitulosLeidos;

  double get avance => capitulos == 0 ? 0 : capitulosLeidos / capitulos;

  factory Libro.desdeFila(Map<String, Object?> f) => Libro(
        id: f['id'] as int,
        clave: f['clave'] as String,
        titulo: f['titulo'] as String,
        tituloPinyin: f['titulo_pinyin'] as String? ?? '',
        tituloEs: f['titulo_es'] as String,
        nivelHsk: f['nivel_hsk'] as int,
        adaptado: f['tipo'] == 'adaptado',
        descripcion: f['descripcion'] as String? ?? '',
        fuente: f['fuente'] as String? ?? '',
        cobertura: (f['cobertura'] as num?)?.toDouble() ?? 0,
        caracteres: f['caracteres'] as int? ?? 0,
        capitulos: f['num_capitulos'] as int? ?? 0,
        capitulosLeidos: f['leidos'] as int? ?? 0,
      );
}

/// Una palabra del vocabulario que se explica al empezar un capítulo.
class PalabraVocabulario {
  const PalabraVocabulario({required this.chino, required this.pinyin, required this.espanol});
  final String chino;
  final String pinyin;
  final String espanol;
}

/// Un capítulo de un libro.
class CapituloLibro {
  const CapituloLibro({
    required this.id,
    required this.orden,
    required this.titulo,
    required this.tituloPinyin,
    required this.tituloEs,
    required this.origen,
    required this.palabras,
    required this.leido,
  });

  final int id;

  /// 1, 2, 3…
  final int orden;
  final String titulo;
  final String tituloPinyin;
  final String tituloEs;

  /// De qué obra o época viene la historia.
  final String origen;
  final List<PalabraVocabulario> palabras;
  final bool leido;

  factory CapituloLibro.desdeFila(Map<String, Object?> f) => CapituloLibro(
        id: f['id'] as int,
        orden: f['orden'] as int,
        titulo: f['titulo'] as String,
        tituloPinyin: f['titulo_pinyin'] as String? ?? '',
        tituloEs: f['titulo_es'] as String? ?? '',
        origen: f['origen'] as String? ?? '',
        palabras: [
          for (final p in jsonDecode(f['palabras'] as String? ?? '[]') as List)
            PalabraVocabulario(
              chino: p['chino'] as String,
              pinyin: p['pinyin'] as String? ?? '',
              espanol: p['espanol'] as String? ?? '',
            ),
        ],
        leido: (f['leido'] as int? ?? 0) == 1,
      );
}

/// Un párrafo: el texto chino, una sílaba de pinyin por carácter, dónde hay
/// nombres propios y la traducción.
class ParrafoLibro {
  const ParrafoLibro({
    required this.chino,
    required this.caracteres,
    required this.pinyin,
    required this.nombres,
    required this.espanol,
  });

  final String chino;

  /// [chino] partido en caracteres (por código Unicode, no por unidades
  /// UTF-16: así cuadra con el pinyin aunque haya caracteres poco comunes).
  final List<String> caracteres;

  /// Una entrada por cada uno de [caracteres] ("" para puntuación).
  final List<String> pinyin;

  /// Rangos [inicio, fin) de nombres propios, en posiciones de [caracteres].
  final List<(int, int)> nombres;
  final String espanol;

  bool esNombre(int indice) => nombres.any((n) => indice >= n.$1 && indice < n.$2);

  factory ParrafoLibro.desdeFila(Map<String, Object?> f) {
    final chino = f['chino'] as String;
    final caracteres = [for (final r in chino.runes) String.fromCharCode(r)];
    final pinyin = [for (final s in jsonDecode(f['pinyin'] as String) as List) s as String];
    return ParrafoLibro(
      chino: chino,
      caracteres: caracteres,
      // Se protege contra datos desalineados: sin pinyin antes que uno equivocado.
      pinyin: pinyin.length == caracteres.length ? pinyin : List.filled(caracteres.length, ''),
      nombres: [
        for (final n in jsonDecode(f['nombres'] as String? ?? '[]') as List)
          ((n as List)[0] as int, n[1] as int),
      ],
      espanol: f['espanol'] as String? ?? '',
    );
  }
}

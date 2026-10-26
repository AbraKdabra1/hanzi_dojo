// ─────────────────────────────────────────────────────────────────────────────
// logros.dart — Logros (fase 6)
//
// Metas que se desbloquean solas al practicar: rachas de 7, 30 y 100 días,
// completar un nivel HSK, cantidad de caracteres y palabras, el primer libro,
// diez tonos seguidos sin fallar… Cada logro sabe cuánto llevas (para la
// barra de avance) a partir de DatosLogros, que arma el repositorio.
//
// Los desbloqueados se guardan con su fecha (tabla logros de progreso.db):
// aunque después bajes (p. ej. se rompe la racha), el logro se queda.
// ─────────────────────────────────────────────────────────────────────────────

import '../idioma.dart';
import 'modelos.dart';

/// Lo que hace falta para saber cuánto llevas de cada logro.
class DatosLogros {
  const DatosLogros({
    this.caracteres = 0,
    this.palabras = 0,
    this.rachaMaxima = 0,
    this.estudiadosPorNivel = const {},
    this.totalPorNivel = const {},
    this.librosTerminados = 0,
    this.totalLibros = 7,
    this.mejorSerieTonos = 0,
    this.repasos = 0,
    this.diasConMeta = 0,
  });

  /// Caracteres estudiados alguna vez.
  final int caracteres;

  /// Palabras del vocabulario estudiadas alguna vez.
  final int palabras;

  /// La racha más larga (con días protegidos).
  final int rachaMaxima;

  /// Nivel HSK (1-7) → caracteres estudiados / total de ese nivel.
  final Map<int, int> estudiadosPorNivel;
  final Map<int, int> totalPorNivel;

  /// Libros de «Leer» con todos sus capítulos marcados.
  final int librosTerminados;
  final int totalLibros;

  /// Más tonos seguidos acertados en el entrenador.
  final int mejorSerieTonos;

  /// Repasos y ejercicios en total.
  final int repasos;

  /// Días en que cumpliste la meta diaria.
  final int diasConMeta;
}

class Logro {
  const Logro({
    required this.clave,
    required this.emoji,
    required String titulo,
    required String descripcion,
    required this.meta,
    required this.valor,
    this.argumentos = const [],
  })  : tituloEs = titulo,
        descripcionEs = descripcion;

  /// Identificador fijo (es lo que se guarda en la base).
  final String clave;
  final String emoji;

  /// Textos en español ({0} = argumentos[0]); se muestran con tr().
  final String tituloEs;
  final String descripcionEs;
  final List<Object> argumentos;

  String get titulo => tr(tituloEs, argumentos);
  String get descripcion => tr(descripcionEs, argumentos);

  /// Cuánto hace falta.
  final int meta;

  /// Cuánto llevas.
  final int Function(DatosLogros) valor;

  bool cumplido(DatosLogros d) => valor(d) >= meta;

  /// De 0 a 1, para la barra de avance.
  double avance(DatosLogros d) => meta == 0 ? 1 : (valor(d) / meta).clamp(0.0, 1.0).toDouble();
}

class Logros {
  Logros._();

  static Logro _nivel(int n) => Logro(
        clave: 'nivel_$n',
        emoji: n == 7 ? '🐉' : '🎓',
        titulo: '{0} completo',
        descripcion: 'Estudia todos los caracteres de {0}',
        argumentos: [nombreDeNivel(n)],
        meta: 1,
        valor: (d) {
          final total = d.totalPorNivel[n] ?? 0;
          return total > 0 && (d.estudiadosPorNivel[n] ?? 0) >= total ? 1 : 0;
        },
      );

  /// Todos los logros, en el orden en que se muestran.
  static final todos = <Logro>[
    Logro(
      clave: 'primer_caracter',
      emoji: '🖌️',
      titulo: 'Primer trazo',
      descripcion: 'Estudia tu primer carácter',
      meta: 1,
      valor: (d) => d.caracteres,
    ),
    Logro(
      clave: 'racha_7',
      emoji: '🔥',
      titulo: 'Una semana',
      descripcion: 'Practica 7 días seguidos',
      meta: 7,
      valor: (d) => d.rachaMaxima,
    ),
    Logro(
      clave: 'racha_30',
      emoji: '🌙',
      titulo: 'Un mes',
      descripcion: 'Practica 30 días seguidos',
      meta: 30,
      valor: (d) => d.rachaMaxima,
    ),
    Logro(
      clave: 'racha_100',
      emoji: '🏮',
      titulo: 'Cien días',
      descripcion: 'Practica 100 días seguidos',
      meta: 100,
      valor: (d) => d.rachaMaxima,
    ),
    Logro(
      clave: 'meta_7',
      emoji: '🎯',
      titulo: 'Constancia',
      descripcion: 'Cumple tu meta diaria 7 días',
      meta: 7,
      valor: (d) => d.diasConMeta,
    ),
    Logro(
      clave: 'caracteres_100',
      emoji: '🌱',
      titulo: 'Cien caracteres',
      descripcion: 'Estudia 100 caracteres',
      meta: 100,
      valor: (d) => d.caracteres,
    ),
    Logro(
      clave: 'caracteres_500',
      emoji: '🎋',
      titulo: 'Quinientos caracteres',
      descripcion: 'Estudia 500 caracteres',
      meta: 500,
      valor: (d) => d.caracteres,
    ),
    Logro(
      clave: 'caracteres_1000',
      emoji: '🌳',
      titulo: 'Mil caracteres',
      descripcion: 'Estudia 1,000 caracteres',
      meta: 1000,
      valor: (d) => d.caracteres,
    ),
    Logro(
      clave: 'caracteres_3000',
      emoji: '🏯',
      titulo: 'Los 3,000',
      descripcion: 'Estudia los 3,000 caracteres HSK',
      meta: 3000,
      valor: (d) => d.caracteres,
    ),
    for (var n = 1; n <= 7; n++) _nivel(n),
    Logro(
      clave: 'palabras_100',
      emoji: '💬',
      titulo: 'Cien palabras',
      descripcion: 'Aprende 100 palabras del vocabulario',
      meta: 100,
      valor: (d) => d.palabras,
    ),
    Logro(
      clave: 'palabras_1000',
      emoji: '📚',
      titulo: 'Mil palabras',
      descripcion: 'Aprende 1,000 palabras del vocabulario',
      meta: 1000,
      valor: (d) => d.palabras,
    ),
    Logro(
      clave: 'oido_10',
      emoji: '👂',
      titulo: 'Oído fino',
      descripcion: 'Acierta 10 tonos seguidos',
      meta: 10,
      valor: (d) => d.mejorSerieTonos,
    ),
    Logro(
      clave: 'libro_1',
      emoji: '📖',
      titulo: 'Primer libro',
      descripcion: 'Termina un libro de «Leer»',
      meta: 1,
      valor: (d) => d.librosTerminados,
    ),
    Logro(
      clave: 'libros_todos',
      emoji: '🏛️',
      titulo: 'Biblioteca completa',
      descripcion: 'Termina los libros de «Leer»',
      meta: 7,
      valor: (d) => d.librosTerminados,
    ),
    Logro(
      clave: 'repasos_1000',
      emoji: '⛰️',
      titulo: 'Mil repasos',
      descripcion: 'Haz 1,000 repasos y ejercicios',
      meta: 1000,
      valor: (d) => d.repasos,
    ),
  ];

  static Logro? porClave(String clave) => todos.where((l) => l.clave == clave).firstOrNull;

  /// Los logros que ya cumples pero aún no estaban desbloqueados.
  static List<Logro> nuevos(DatosLogros datos, Set<String> desbloqueados) =>
      [for (final l in todos) if (!desbloqueados.contains(l.clave) && l.cumplido(datos)) l];
}

// ─────────────────────────────────────────────────────────────────────────────
// frases.dart — Frases esenciales (Practicar → Frases esenciales)
//
//   Situacion     → saludos, cortesía, compras… en el orden en que se muestran
//                   (el mismo que SITUACIONES en construir_db.py).
//   Frase         → una frase de la tabla c.frases, con tu avance.
//   AvanceFrases  → cuántas frases de una situación llevas.
//   Ejercicios    → qué frases entran en una ronda (elegirRonda), las
//                   opciones de «Escuchar y elegir» (PreguntaFrase) y las
//                   fichas de «Armar la frase» (ArmarFrase).
//
// Las frases vienen de herramientas_datos/fuentes/frases/frases_esenciales.tsv.
// Las consultas están en repositorio_frases.dart; las pantallas, en
// screens/pantalla_frases.dart y screens/pantalla_ejercicio_frases.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';

import 'modelos.dart';
import 'srs.dart';
import '../idioma.dart';

/// En qué situación se usa una frase.
enum Situacion {
  saludos('saludos'),
  cortesia('cortesia'),
  presentarse('presentarse'),
  comunicarse('comunicarse'),
  compras('compras'),
  comida('comida'),
  transporte('transporte'),
  emergencias('emergencias');

  const Situacion(this.clave);

  /// Como viene en la base ('saludos').
  final String clave;

  /// Nombre en el idioma de la interfaz.
  String get nombre => switch (this) {
        saludos => tr('Saludos'),
        cortesia => tr('Cortesía'),
        presentarse => tr('Presentarse'),
        comunicarse => tr('Para comunicarte'),
        compras => tr('Compras'),
        comida => tr('Comida'),
        transporte => tr('Direcciones y transporte'),
        emergencias => tr('Emergencias'),
      };

  /// null si la base trae una situación que esta versión de la app no conoce.
  static Situacion? deClave(String clave) {
    for (final s in values) {
      if (s.clave == clave) return s;
    }
    return null;
  }
}

/// Una palabra de una frase: una ficha del ejercicio de ordenar.
typedef PalabraFrase = ({String chino, String pinyin});

class Frase {
  const Frase({
    required this.id,
    required this.situacion,
    required this.orden,
    required this.chino,
    required this.pinyin,
    required this.silabas,
    required this.palabras,
    required this.espanol,
    required this.ingles,
    required this.nota,
    required this.nivelHsk,
    this.progreso,
  });

  /// Número fijo de la frase (no es un número de fila: el archivo de frases
  /// nunca lo cambia ni lo reutiliza). Tu avance se guarda con él.
  final int id;

  final Situacion situacion;

  /// Posición dentro de su situación: 1, 2, 3…
  final int orden;

  /// "这个多少钱？"
  final String chino;

  /// Por palabras, como se muestra: "zhège duōshao qián?".
  final String pinyin;

  /// Una sílaba con acentos por carácter de [chino] ('' en la puntuación; 'r'
  /// en el 儿 del erhua), para que BotonVoz lea cada carácter con su lectura
  /// en esta frase.
  final List<String> silabas;

  /// Las palabras de la frase, en orden.
  final List<PalabraFrase> palabras;

  final String espanol;
  final String ingles;

  /// Cuándo se usa o qué se puede cambiar (en español); null si no hay.
  final String? nota;

  /// El nivel HSK más alto de sus caracteres.
  final int nivelHsk;

  /// Tu avance con esta frase (null si nunca la has practicado).
  final Progreso? progreso;

  /// Traducción en el idioma de la interfaz.
  String get traduccion => Idioma.ingles ? ingles : espanol;

  factory Frase.desdeFila(Map<String, Object?> f, Situacion situacion) => Frase(
        id: f['id'] as int,
        situacion: situacion,
        orden: f['orden'] as int,
        chino: f['chino'] as String,
        pinyin: f['pinyin'] as String,
        silabas: (jsonDecode(f['silabas'] as String) as List).cast<String>(),
        palabras: [
          for (final p in (jsonDecode(f['palabras'] as String) as List).cast<Map<String, Object?>>())
            (chino: p['chino'] as String, pinyin: p['pinyin'] as String),
        ],
        espanol: f['espanol'] as String,
        ingles: f['ingles'] as String,
        nota: f['nota'] as String?,
        nivelHsk: f['nivel_hsk'] as int,
        progreso: Progreso.desdeFila(f),
      );

  @override
  bool operator ==(Object other) => other is Frase && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Avance de las frases de una situación.
class AvanceFrases {
  const AvanceFrases({
    required this.situacion,
    required this.total,
    required this.estudiadas,
    required this.dominadas,
  });

  final Situacion situacion;
  final int total;
  final int estudiadas;
  final int dominadas;
}

// ═══════════════════════════════════════════════════════════════════════════
// Ejercicios
// ═══════════════════════════════════════════════════════════════════════════

/// Las frases de una ronda: primero las que tocan hoy (la que lleva más
/// tiempo esperando primero), después las que nunca has practicado, en orden,
/// y si aún faltan, otras que ya practicaste, al azar.
List<Frase> elegirRonda(List<Frase> frases, Random azar, {required DateTime ahora, int cantidad = 10}) {
  bool toca(Frase f) => f.progreso != null && !f.progreso!.proximoRepaso.isAfter(ahora);
  final vencidas = [for (final f in frases) if (toca(f)) f]
    ..sort((a, b) => a.progreso!.proximoRepaso.compareTo(b.progreso!.proximoRepaso));
  final nuevas = [for (final f in frases) if (f.progreso == null) f];
  final otras = [for (final f in frases) if (f.progreso != null && !toca(f)) f]..shuffle(azar);
  return [...vencidas, ...nuevas, ...otras].take(cantidad).toList();
}

/// Cómo se califica una respuesta: bien a la primera, Fácil; si no, Difícil
/// (vuelve mañana).
Calificacion calificacionFrase({required bool bien}) => bien ? Calificacion.facil : Calificacion.dificil;

/// «Escuchar y elegir»: suena la frase y se elige qué significa.
class PreguntaFrase {
  const PreguntaFrase(this.objetivo, this.opciones);

  final Frase objetivo;
  final List<Frase> opciones;

  int get correcta => opciones.indexOf(objetivo);

  /// [objetivo] más 3 distractores de [otras]: primero de su misma situación
  /// (así no basta con reconocer el tema) y nunca con la misma traducción.
  static PreguntaFrase armar(Frase objetivo, List<Frase> otras, Random azar, {int cantidad = 4}) {
    final candidatas = [for (final f in otras) if (f.id != objetivo.id) f];
    final misma = [for (final f in candidatas) if (f.situacion == objetivo.situacion) f]..shuffle(azar);
    final resto = [for (final f in candidatas) if (f.situacion != objetivo.situacion) f]..shuffle(azar);
    final elegidas = <Frase>[];
    final traducciones = {objetivo.traduccion};
    for (final f in [...misma, ...resto]) {
      if (elegidas.length >= cantidad - 1) break;
      if (traducciones.add(f.traduccion)) elegidas.add(f);
    }
    return PreguntaFrase(objetivo, [objetivo, ...elegidas]..shuffle(azar));
  }
}

/// «Armar la frase»: se ve la traducción y se tocan las fichas en orden.
class ArmarFrase {
  const ArmarFrase(this.objetivo, this.fichas);

  final Frase objetivo;

  /// Las piezas de la frase y algunas que sobran, revueltas.
  final List<PalabraFrase> fichas;

  /// ¿Las fichas elegidas, en ese orden, dicen la frase? Se compara el texto:
  /// dos fichas iguales (谢 y 谢) dan lo mismo.
  bool esCorrecta(List<PalabraFrase> elegidas) =>
      elegidas.map((p) => p.chino).join() == objetivo.palabras.map((p) => p.chino).join();

  /// Las piezas de [objetivo] son sus palabras; si es una sola (谢谢, 服务员),
  /// sus caracteres. Se agregan [sobrantes] palabras de [otras] que no estén
  /// en la frase, y se revuelven sin dejarlas ya en orden.
  static ArmarFrase armar(Frase objetivo, List<Frase> otras, Random azar, {int sobrantes = 2}) {
    final piezas = objetivo.palabras.length > 1
        ? objetivo.palabras
        : [
            for (var i = 0; i < objetivo.chino.length; i++)
              if (objetivo.silabas[i].isNotEmpty) (chino: objetivo.chino[i], pinyin: objetivo.silabas[i]),
          ];
    final usadas = {for (final p in piezas) p.chino};
    final candidatas = [
      for (final f in otras)
        if (f.id != objetivo.id) ...f.palabras,
    ]..shuffle(azar);
    final extra = <PalabraFrase>[];
    for (final p in candidatas) {
      if (extra.length >= sobrantes) break;
      if (usadas.add(p.chino)) extra.add(p);
    }
    final fichas = [...piezas, ...extra];
    bool enOrden() =>
        fichas.take(piezas.length).map((p) => p.chino).join() == piezas.map((p) => p.chino).join();
    for (var intento = 0; intento < 20 && (intento == 0 || enOrden()); intento++) {
      fichas.shuffle(azar);
    }
    return ArmarFrase(objetivo, fichas);
  }
}

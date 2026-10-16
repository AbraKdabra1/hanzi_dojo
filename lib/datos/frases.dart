// ─────────────────────────────────────────────────────────────────────────────
// frases.dart — Frases esenciales (Practicar → Frases esenciales)
//
//   Situacion     → saludos, cortesía, compras… en el orden en que se muestran
//                   (el mismo que SITUACIONES en construir_db.py).
//   Frase         → una frase de la tabla c.frases, con tu avance.
//   AvanceFrases  → cuántas frases de una situación llevas.
//
// Las frases vienen de herramientas_datos/fuentes/frases/frases_esenciales.tsv.
// Las consultas están en repositorio_frases.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'modelos.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// resumen_beta.dart — Lo que un probador nos cuenta de la app, sin espiarlo
//
// La app no envía nada por su cuenta. Este resumen se arma en el teléfono con
// lo que ya está guardado (historial, ejercicios, lectura, ajustes) y el
// probador lo lee completo antes de compartirlo (WhatsApp, correo…) desde
// Ajustes → Enviar mi opinión (pantalla_resumen_beta.dart).
//
// Trazos reportados: cuando la app marca mal un trazo que hiciste bien, el
// botón «¿Ese trazo estaba bien?» guarda el carácter, qué trazo era y tu
// trazo (unos pocos puntos en coordenadas de 1024 × 1024, las mismas de las
// medianas). Con eso se puede repetir la evaluación en la computadora y
// ajustar evaluacion_trazo.dart. Se guardan los últimos [trazosMaximos].
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:sqflite/sqflite.dart';

import '../idioma.dart';
import 'estadisticas.dart';
import 'registro_errores.dart';
import 'repositorio.dart';
import 'repositorio_habito.dart';

/// Un trazo que la app rechazó y el usuario dice que estaba bien.
class TrazoReportado {
  const TrazoReportado({
    required this.caracter,
    required this.indice,
    required this.alReves,
    required this.modoNovato,
    required this.momento,
    required this.puntos,
  });

  /// Puntos que se guardan de cada trazo (repartidos a lo largo).
  static const puntosMaximos = 16;

  final String caracter;

  /// Qué trazo tocaba (0 = el primero).
  final int indice;

  /// La app dijo «al revés» (si no, solo «incorrecto»).
  final bool alReves;
  final bool modoNovato;
  final DateTime momento;

  /// Tu trazo en coordenadas de make-me-a-hanzi (1024 × 1024, Y hacia arriba).
  final List<Offset> puntos;

  /// Deja a lo más [puntosMaximos] puntos, repartidos de principio a fin, y
  /// los redondea (un píxel de 1024 no cambia la evaluación).
  static List<Offset> simplificar(List<Offset> puntos) {
    Offset redondo(Offset p) => Offset(p.dx.roundToDouble(), p.dy.roundToDouble());
    if (puntos.length <= puntosMaximos) return [for (final p in puntos) redondo(p)];
    return [
      for (var i = 0; i < puntosMaximos; i++)
        redondo(puntos[(i * (puntos.length - 1) / (puntosMaximos - 1)).round()]),
    ];
  }

  Map<String, Object> aJson() => {
        'c': caracter,
        'i': indice,
        'r': alReves ? 1 : 0,
        'n': modoNovato ? 1 : 0,
        't': momento.millisecondsSinceEpoch ~/ 1000,
        'p': [for (final p in puntos) [p.dx.round(), p.dy.round()]],
      };

  static TrazoReportado? desdeJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final c = j['c'], i = j['i'], t = j['t'], p = j['p'];
    if (c is! String || i is! int || t is! int || p is! List) return null;
    final puntos = <Offset>[];
    for (final par in p) {
      if (par is List && par.length == 2 && par[0] is num && par[1] is num) {
        puntos.add(Offset((par[0] as num).toDouble(), (par[1] as num).toDouble()));
      }
    }
    return TrazoReportado(
      caracter: c,
      indice: i,
      alReves: j['r'] == 1,
      modoNovato: j['n'] == 1,
      momento: DateTime.fromMillisecondsSinceEpoch(t * 1000),
      puntos: puntos,
    );
  }

  /// "312,770 300,600 …"
  String get textoPuntos => puntos.map((p) => '${p.dx.round()},${p.dy.round()}').join(' ');
}

/// Lo que se cuenta en el resumen (todo sale de la base del teléfono).
class DatosResumen {
  const DatosResumen({
    required this.dias,
    required this.repasos,
    required this.distintos,
    required this.sinErrores,
    required this.novato,
    required this.minutos,
    required this.ejercicios,
    required this.capitulos,
    required this.misLibros,
    required this.logros,
    required this.racha,
    required this.metaDiaria,
    required this.recordatorio,
    required this.caracterDia,
    required this.tutorial,
    required this.trazos,
  });

  /// Días con actividad (fecha local, sin repetir, del primero al último).
  final List<DateTime> dias;

  /// Repasos de escritura y de cuántos caracteres distintos.
  final int repasos;
  final int distintos;

  /// Repasos sin ningún trazo fallado / hechos en modo novato.
  final int sinErrores;
  final int novato;

  /// Minutos escribiendo (de que aparece la tarjeta a calificarla).
  final int minutos;

  /// Ejercicios de Practicar por tipo (tono, escucha, palabra…).
  final Map<String, int> ejercicios;
  final int capitulos;
  final int misLibros;
  final int logros;
  final Racha racha;
  final int metaDiaria;
  final bool recordatorio;
  final bool caracterDia;

  /// 'escrito' | 'terminado' | 'omitido', o null si no se sabe (beta.1).
  final String? tutorial;
  final List<TrazoReportado> trazos;
}

extension ResumenBetaRepositorio on Repositorio {
  Database get _bd => base.db;

  static const trazosMaximos = 30;

  Future<List<TrazoReportado>> trazosReportados() async {
    final texto = await base.leerAjuste('trazos_reportados');
    if (texto == null || texto.isEmpty) return [];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return [];
      return [for (final j in lista) ?TrazoReportado.desdeJson(j)];
    } on FormatException {
      return [];
    }
  }

  Future<void> reportarTrazo(TrazoReportado trazo) async {
    final lista = [...await trazosReportados(), trazo];
    final ultimos = lista.length > trazosMaximos ? lista.sublist(lista.length - trazosMaximos) : lista;
    await base.guardarAjuste('trazos_reportados', jsonEncode([for (final t in ultimos) t.aJson()]));
  }

  /// Cómo terminó el tutorial la PRIMERA vez (si lo vuelves a ver desde
  /// Ajustes no cambia): 'escrito' (escribió 人), 'terminado' u 'omitido'.
  Future<String?> resultadoTutorial() => base.leerAjuste('tutorial_resultado');

  Future<void> guardarResultadoTutorial(String resultado) async {
    if (await resultadoTutorial() == null) await base.guardarAjuste('tutorial_resultado', resultado);
  }

  Future<DatosResumen> datosResumen() async {
    Future<int> contar(String sql) async => (await _bd.rawQuery(sql)).first.values.first as int? ?? 0;

    final momentos = await _bd.rawQuery(
      'SELECT momento FROM historial UNION ALL SELECT momento FROM ejercicios UNION ALL SELECT momento FROM lectura',
    );
    DateTime diaDe(int segundos) {
      final t = DateTime.fromMillisecondsSinceEpoch(segundos * 1000);
      return DateTime(t.year, t.month, t.day);
    }

    final dias = {for (final f in momentos) diaDe(f['momento'] as int)}.toList()..sort();

    final h = (await _bd.rawQuery('''
      SELECT count(*) AS repasos, count(DISTINCT caracter) AS distintos,
             coalesce(sum(errores = 0), 0) AS sin_errores, coalesce(sum(modo_novato), 0) AS novato,
             coalesce(sum(duracion_ms), 0) AS ms
      FROM historial
    ''')).first;

    final ejercicios = <String, int>{
      for (final f in await _bd.rawQuery('SELECT tipo, count(*) AS n FROM ejercicios GROUP BY tipo ORDER BY tipo'))
        f['tipo'] as String: f['n'] as int,
    };

    return DatosResumen(
      dias: dias,
      repasos: h['repasos'] as int,
      distintos: h['distintos'] as int,
      sinErrores: h['sin_errores'] as int,
      novato: h['novato'] as int,
      minutos: ((h['ms'] as int) / 60000).round(),
      ejercicios: ejercicios,
      capitulos: await contar('SELECT count(*) FROM lectura'),
      misLibros: await contar('SELECT count(*) FROM mis_libros'),
      logros: await contar('SELECT count(*) FROM logros'),
      racha: await rachaConProtector(),
      metaDiaria: await metaDiaria(),
      recordatorio: await recordatorio() != null,
      caracterDia: await caracterDia() != null,
      tutorial: await resultadoTutorial(),
      trazos: await trazosReportados(),
    );
  }
}

class ResumenBeta {
  ResumenBeta._();

  /// Errores de la app que se incluyen (los más recientes, en una línea).
  static const erroresMaximos = 3;

  /// El texto que el probador ve y comparte.
  static String texto(
    DatosResumen d, {
    required String dispositivo,
    required List<EntradaError> errores,
    String comentario = '',
  }) {
    String pct(int parte, int total) => total == 0 ? '—' : '${(parte * 100 / total).round()} %';
    String dia(DateTime t) => '${t.day}/${t.month}';
    String siNo(bool v) => v ? tr('sí') : tr('no');

    final b = StringBuffer()
      ..writeln('📋 ${tr('Resumen de la beta')} · Meizi Hanzi')
      ..writeln(dispositivo)
      ..writeln('${tr('Idioma: {0}', [Idioma.ingles ? 'English' : 'español'])} · '
          '${tr('Tutorial: {0}', [switch (d.tutorial) {
            'escrito' => tr('terminado, escribió 人'),
            'terminado' => tr('terminado'),
            'omitido' => tr('omitido'),
            _ => '—',
          }])}');

    final comentarioLimpio = comentario.trim();
    if (comentarioLimpio.isNotEmpty) {
      b
        ..writeln()
        ..writeln('💬 $comentarioLimpio');
    }

    b
      ..writeln()
      ..writeln('✍️ ${tr('Escritura')}')
      ..writeln('· ${tr('Días con actividad: {0}', [d.dias.length])}'
          '${d.dias.isEmpty ? '' : ' (${dia(d.dias.first)} → ${dia(d.dias.last)})'}')
      ..writeln('· ${tr('Repasos: {0} · caracteres distintos: {1}', [d.repasos, d.distintos])}')
      ..writeln('· ${tr('Sin errores: {0} · en modo novato: {1}', [pct(d.sinErrores, d.repasos), pct(d.novato, d.repasos)])}')
      ..writeln('· ${tr('Tiempo escribiendo: {0} min', [d.minutos])}');

    final nombres = {
      'tono': tr('tonos'),
      'tonos_palabra': tr('tonos en palabras'),
      'escucha': tr('escucha'),
      'pinyin': 'pinyin',
      'palabra': tr('vocabulario'),
    };
    final practica = d.ejercicios.isEmpty
        ? '—'
        : [for (final e in d.ejercicios.entries) '${nombres[e.key] ?? e.key} ${e.value}'].join(' · ');
    b
      ..writeln('🎧 ${tr('Práctica: {0}', [practica])}')
      ..writeln('📖 ${tr('Lectura: {0} capítulos · libros propios: {1}', [d.capitulos, d.misLibros])}')
      ..writeln('🔥 ${tr('Racha: {0} días (máxima {1}) · meta diaria: {2}', [d.racha.actual, d.racha.maxima, d.metaDiaria])}')
      ..writeln('🔔 ${tr('Recordatorio: {0} · carácter del día: {1} · logros: {2}', [siNo(d.recordatorio), siNo(d.caracterDia), d.logros])}');

    if (d.trazos.isNotEmpty) {
      b
        ..writeln()
        ..writeln('✋ ${tr('Trazos que la app marcó mal ({0})', [d.trazos.length])}');
      for (final t in d.trazos) {
        final como = [
          if (t.alReves) tr('al revés'),
          t.modoNovato ? tr('novato') : tr('experto'),
        ].join(', ');
        b.writeln('· ${t.caracter} #${t.indice + 1} ($como): ${t.textoPuntos}');
      }
    }

    b
      ..writeln()
      ..writeln('⚠️ ${tr('Errores de la app: {0}', [errores.length])}');
    for (final e in errores.take(erroresMaximos)) {
      final linea = e.mensaje.split('\n').first;
      final corta = linea.length > 120 ? '${linea.substring(0, 120)}…' : linea;
      b.writeln('· [${RegistroErrores.fechaCorta(e.momento)}] ${e.origen}${e.veces > 1 ? ' ×${e.veces}' : ''}: $corta');
    }
    return b.toString().trimRight();
  }
}

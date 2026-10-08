// ─────────────────────────────────────────────────────────────────────────────
// reporte.dart — Arma un reporte de problema para GitHub (o para copiarlo)
//
// El reporte se envía abriendo en el navegador el formulario de "issue" del
// repositorio ya lleno: GitHub permite rellenar cada campo de un formulario
// (.github/ISSUE_TEMPLATE/*.yml) con parámetros en la URL usando su `id`.
// Así no hace falta ningún servidor y la app no envía nada por su cuenta.
//
// El usuario ve exactamente lo que se va a enviar antes de enviarlo. Si no
// tiene cuenta de GitHub, puede copiar el mismo texto y mandarlo como quiera.
// ─────────────────────────────────────────────────────────────────────────────

import 'registro_errores.dart';

enum TipoReporte {
  error('Un error de la app', 'error.yml', '[Error] '),
  contenido('Un error en el contenido', 'contenido.yml', '[Contenido] '),
  sugerencia('Una sugerencia', 'sugerencia.yml', '[Sugerencia] ');

  const TipoReporte(this.etiqueta, this.plantilla, this.prefijoTitulo);

  final String etiqueta;

  /// Archivo del formulario en .github/ISSUE_TEMPLATE/.
  final String plantilla;
  final String prefijoTitulo;
}

/// Qué puede estar mal en el contenido.
const queEstaMalOpciones = [
  'Significado',
  'Pinyin',
  'Ejemplo',
  'Orden o forma de los trazos',
  'Texto o traducción de un libro',
  'Otro',
];

class Reporte {
  const Reporte({
    required this.tipo,
    required this.descripcion,
    this.donde = '',
    this.queEstaMal = '',
    this.propuesta = '',
    this.dispositivo = '',
    this.errores = const [],
  });

  static const repositorio = 'https://github.com/AbraKdabra1/hanzi_dojo';

  /// GitHub y los navegadores aceptan URLs largas, pero no infinitas.
  static const largoMaximoUrl = 7500;

  /// Errores que se adjuntan como máximo (los más recientes).
  static const erroresMaximos = 5;

  final TipoReporte tipo;
  final String descripcion;

  /// Carácter, libro o pantalla (contenido).
  final String donde;
  final String queEstaMal;
  final String propuesta;

  /// Versión de la app y modelo del teléfono ('' si el usuario no lo adjunta).
  final String dispositivo;

  /// Informe de errores ([] si el usuario no lo adjunta).
  final List<EntradaError> errores;

  /// Título del issue: el prefijo y el inicio de la descripción.
  String get titulo {
    final base = tipo == TipoReporte.contenido && donde.isNotEmpty
        ? '$donde${queEstaMal.isEmpty ? '' : ' · $queEstaMal'}'
        : descripcion.replaceAll(RegExp(r'\s+'), ' ').trim();
    final corto = base.length > 70 ? '${base.substring(0, 70)}…' : base;
    return '${tipo.prefijoTitulo}$corto';
  }

  String get informe => errores.isEmpty
      ? ''
      : RegistroErrores.comoTexto(errores.take(erroresMaximos).toList(), 'Últimos errores registrados:');

  /// Campos del formulario (id del campo → valor), sin los vacíos.
  Map<String, String> get campos {
    final c = <String, String>{'descripcion': descripcion.trim()};
    if (dispositivo.isNotEmpty) c['dispositivo'] = dispositivo;
    switch (tipo) {
      case TipoReporte.error:
        if (informe.isNotEmpty) c['informe'] = informe;
      case TipoReporte.contenido:
        if (donde.isNotEmpty) c['donde'] = donde;
        if (queEstaMal.isNotEmpty) c['que_esta_mal'] = queEstaMal;
        if (propuesta.trim().isNotEmpty) c['propuesta'] = propuesta.trim();
      case TipoReporte.sugerencia:
        break;
    }
    return c;
  }

  /// URL del formulario de GitHub ya lleno. Si quedara demasiado larga, se
  /// recorta el informe de errores (y en último caso la descripción).
  Uri get urlGitHub {
    Uri armar(Map<String, String> campos) => Uri.parse('$repositorio/issues/new').replace(
          queryParameters: {'template': tipo.plantilla, 'title': titulo, ...campos},
        );
    final c = campos;
    var url = armar(c);
    for (final campo in ['informe', 'propuesta', 'descripcion']) {
      while (url.toString().length > largoMaximoUrl && (c[campo]?.length ?? 0) > 200) {
        final v = c[campo]!;
        c[campo] = '${v.substring(0, (v.length * 0.7).floor())}\n…(recortado)';
        url = armar(c);
      }
    }
    return url;
  }

  /// El mismo reporte como texto, para verlo antes de enviarlo o copiarlo.
  String get texto {
    final b = StringBuffer()
      ..writeln(titulo)
      ..writeln()
      ..writeln('Tipo: ${tipo.etiqueta}');
    if (donde.isNotEmpty) b.writeln('Dónde: $donde');
    if (queEstaMal.isNotEmpty) b.writeln('Qué está mal: $queEstaMal');
    b
      ..writeln()
      ..writeln(descripcion.trim());
    if (propuesta.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Cómo debería decir: ${propuesta.trim()}');
    }
    if (dispositivo.isNotEmpty) {
      b
        ..writeln()
        ..writeln(dispositivo);
    }
    if (informe.isNotEmpty) {
      b
        ..writeln()
        ..write(informe);
    }
    return b.toString().trimRight();
  }
}

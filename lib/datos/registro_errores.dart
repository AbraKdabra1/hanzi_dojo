// ─────────────────────────────────────────────────────────────────────────────
// registro_errores.dart — Los errores de la app, guardados en el teléfono
//
// Si algo falla (un error de dibujo, una consulta, la voz…), se guarda aquí
// en vez de perderse. Ajustes → "Informe de errores" los muestra y permite
// copiarlos para reportar el problema.
//
// Privacidad: NADA se envía solo. La app ni siquiera tiene permiso de
// internet; el usuario decide si copia el informe y a quién se lo manda.
//
// Detalles:
//   · Se guardan los últimos [maximo] en errores.jsonl (un JSON por línea),
//     junto a las bases de datos.
//   · Si el mismo error se repite seguido (por ejemplo, en cada cuadro), se
//     guarda una vez con un contador en vez de llenar la lista.
//   · Lo que falle ANTES de saber dónde guardar (al arrancar) se queda en
//     memoria y se escribe en cuanto se llama a [iniciar].
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class EntradaError {
  const EntradaError({
    required this.momento,
    required this.origen,
    required this.mensaje,
    required this.pila,
    this.veces = 1,
  });

  final DateTime momento;

  /// Dónde se atrapó: "Flutter" (interfaz), "App" (código asíncrono),
  /// "Inicio", "Voz"…
  final String origen;
  final String mensaje;

  /// Primeras líneas de la pila de llamadas (dónde ocurrió).
  final String pila;

  /// Cuántas veces seguidas ocurrió.
  final int veces;

  bool mismoQue(EntradaError otra) => otra.origen == origen && otra.mensaje == mensaje;

  EntradaError otraVez(DateTime cuando) =>
      EntradaError(momento: cuando, origen: origen, mensaje: mensaje, pila: pila, veces: veces + 1);

  Map<String, Object> aJson() => {
        'momento': momento.toIso8601String(),
        'origen': origen,
        'mensaje': mensaje,
        'pila': pila,
        'veces': veces,
      };

  static EntradaError? desdeJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final momento = DateTime.tryParse(j['momento'] as String? ?? '');
    if (momento == null) return null;
    return EntradaError(
      momento: momento,
      origen: j['origen'] as String? ?? '?',
      mensaje: j['mensaje'] as String? ?? '',
      pila: j['pila'] as String? ?? '',
      veces: j['veces'] as int? ?? 1,
    );
  }
}

class RegistroErrores {
  RegistroErrores._();

  static const maximo = 50;
  static const archivo = 'errores.jsonl';
  static const _largoMensaje = 1000;
  static const _lineasPila = 20;

  static String? _ruta;
  static final List<EntradaError> _pendientes = [];

  /// Las escrituras van en fila, una tras otra, para no pisarse.
  static Future<void> _cola = Future.value();

  /// Atrapa los errores de toda la app. Se llama en main(), antes de runApp.
  static void instalar() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalles) {
      anterior?.call(detalles); // sigue mostrándose en la consola
      registrar('Flutter', detalles.exception, detalles.stack,
          contexto: detalles.context?.toDescription());
    };
    PlatformDispatcher.instance.onError = (error, pila) {
      debugPrint('Error no atrapado: $error\n$pila');
      registrar('App', error, pila);
      return true; // atendido: la app sigue
    };
  }

  /// Indica dónde guardar. Lo que se haya atrapado antes se escribe ahora.
  static Future<void> iniciar(String carpeta) {
    _ruta = p.join(carpeta, archivo);
    final pendientes = List.of(_pendientes);
    _pendientes.clear();
    for (final e in pendientes) {
      _encolar(e);
    }
    return _cola;
  }

  /// Guarda un error. Nunca lanza: si no se puede guardar, solo se ignora.
  static Future<void> registrar(String origen, Object error, StackTrace? pila, {String? contexto}) {
    var mensaje = contexto == null ? '$error' : '$error\n($contexto)';
    if (mensaje.length > _largoMensaje) mensaje = '${mensaje.substring(0, _largoMensaje)}…';
    final lineas = (pila?.toString() ?? '').trimRight().split('\n');
    final entrada = EntradaError(
      momento: DateTime.now(),
      origen: origen,
      mensaje: mensaje,
      pila: lineas.take(_lineasPila).join('\n'),
    );
    if (_ruta == null) {
      _pendientes.add(entrada);
      if (_pendientes.length > maximo) _pendientes.removeAt(0);
      return Future.value();
    }
    return _encolar(entrada);
  }

  static Future<void> _encolar(EntradaError entrada) {
    _cola = _cola.then((_) => _escribir(entrada)).catchError((Object e) {
      debugPrint('No se pudo guardar el error: $e');
    });
    return _cola;
  }

  static Future<void> _escribir(EntradaError entrada) async {
    final ruta = _ruta;
    if (ruta == null) return;
    final lista = await _leerArchivo(ruta);
    if (lista.isNotEmpty && lista.last.mismoQue(entrada)) {
      lista[lista.length - 1] = lista.last.otraVez(entrada.momento);
    } else {
      lista.add(entrada);
    }
    final ultimos = lista.length > maximo ? lista.sublist(lista.length - maximo) : lista;
    final temporal = File('$ruta.tmp');
    await temporal.writeAsString(ultimos.map((e) => '${jsonEncode(e.aJson())}\n').join(), flush: true);
    await temporal.rename(ruta);
  }

  static Future<List<EntradaError>> _leerArchivo(String ruta) async {
    final f = File(ruta);
    if (!await f.exists()) return [];
    final lista = <EntradaError>[];
    for (final linea in await f.readAsLines()) {
      if (linea.trim().isEmpty) continue;
      try {
        final e = EntradaError.desdeJson(jsonDecode(linea));
        if (e != null) lista.add(e);
      } catch (_) {
        // Una línea dañada no impide leer las demás.
      }
    }
    return lista;
  }

  /// Los errores guardados, del más reciente al más antiguo.
  static Future<List<EntradaError>> leer() async {
    await _cola;
    final ruta = _ruta;
    final guardados = ruta == null ? <EntradaError>[] : await _leerArchivo(ruta);
    return [...guardados, ..._pendientes].reversed.toList();
  }

  /// Borra todos los errores guardados.
  static Future<void> borrar() async {
    await _cola;
    _pendientes.clear();
    final ruta = _ruta;
    if (ruta != null && await File(ruta).exists()) await File(ruta).delete();
  }

  /// Texto listo para pegar en un reporte.
  static String comoTexto(List<EntradaError> errores, String encabezado) {
    final b = StringBuffer('$encabezado\n');
    if (errores.isEmpty) b.writeln('Sin errores registrados.');
    for (final e in errores) {
      b
        ..writeln()
        ..writeln('[${fechaCorta(e.momento)}] ${e.origen}${e.veces > 1 ? ' ×${e.veces}' : ''}')
        ..writeln(e.mensaje);
      if (e.pila.isNotEmpty) b.writeln(e.pila);
    }
    return b.toString();
  }

  /// "30/09/2026 21:40"
  static String fechaCorta(DateTime t) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(t.day)}/${dos(t.month)}/${t.year} ${dos(t.hour)}:${dos(t.minute)}';
  }

  /// Solo para las pruebas: olvida la carpeta y lo pendiente.
  @visibleForTesting
  static void reiniciarParaPruebas() {
    _ruta = null;
    _pendientes.clear();
    _cola = Future.value();
  }
}

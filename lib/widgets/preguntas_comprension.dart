// ─────────────────────────────────────────────────────────────────────────────
// preguntas_comprension.dart — Preguntas al final de cada capítulo (fase 7)
//
// Van al pie del lector, antes de "Terminé este capítulo". Tocas una opción y
// enseguida se ve si acertaste (verde) o cuál era la buena (rojo y verde).
// Al contestar todas aparece cuántas acertaste.
//
// Las respuestas las guarda la pantalla del lector (que también las anota en
// la tabla ejercicios); este widget solo las muestra.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/modelos.dart';
import '../idioma.dart';
import '../tema.dart';
import 'ejercicio.dart';
import 'tarjeta_vidrio.dart';

class PreguntasComprension extends StatelessWidget {
  const PreguntasComprension({
    super.key,
    required this.preguntas,
    required this.respuestas,
    required this.onResponder,
    this.color,
  });

  final List<PreguntaComprension> preguntas;

  /// Pregunta (posición en [preguntas]) → opción que elegiste.
  final Map<int, int> respuestas;

  final void Function(int pregunta, int opcion) onResponder;

  /// Color del ícono (el del nivel del libro).
  final Color? color;

  int get aciertos =>
      respuestas.entries.where((e) => e.key < preguntas.length && preguntas[e.key].correcta == e.value).length;

  bool get terminadas => respuestas.length >= preguntas.length;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final total = preguntas.length;
    final String resumen;
    if (!terminadas) {
      resumen = tr('{0} preguntas sobre lo que leíste', [total]);
    } else if (aciertos == total) {
      resumen = tr('{0} de {1} correctas · ¡entendiste todo!', [aciertos, total]);
    } else {
      resumen = tr('{0} de {1} correctas', [aciertos, total]);
    }
    return TarjetaVidrio(
      relleno: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.quiz_outlined, size: 20, color: color ?? c.icono),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr('¿Qué entendiste?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              resumen,
              key: ValueKey(resumen),
              style: TextStyle(
                fontSize: 12.5,
                color: terminadas ? ColoresRespuesta.bien(context) : c.tenue,
                fontWeight: terminadas ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          for (var i = 0; i < total; i++)
            _Pregunta(
              numero: i + 1,
              pregunta: preguntas[i],
              elegida: respuestas[i],
              onElegir: (o) => onResponder(i, o),
            ),
        ],
      ),
    );
  }
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.numero, required this.pregunta, required this.elegida, required this.onElegir});

  final int numero;
  final PreguntaComprension pregunta;
  final int? elegida;
  final ValueChanged<int> onElegir;

  EstadoOpcion _estado(int i) {
    final e = elegida;
    if (e == null) return EstadoOpcion.normal;
    if (i == pregunta.correcta) return EstadoOpcion.correcta;
    if (i == e) return EstadoOpcion.incorrecta;
    return EstadoOpcion.apagada;
  }

  @override
  Widget build(BuildContext context) {
    final opciones = pregunta.opciones;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$numero. ${pregunta.pregunta}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
          const SizedBox(height: 8),
          for (var i = 0; i < opciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: BotonOpcion(
                alto: 44,
                estado: _estado(i),
                onTap: () => onElegir(i),
                child: Row(children: [
                  Expanded(child: Text(opciones[i], style: const TextStyle(fontSize: 14.5, height: 1.25))),
                  if (elegida != null && i == pregunta.correcta)
                    Icon(Icons.check_rounded, size: 18, color: ColoresRespuesta.bien(context))
                  else if (elegida == i)
                    Icon(Icons.close_rounded, size: 18, color: ColoresRespuesta.mal(context)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// boton_reportar.dart — La bandera «Reportar un error» de la barra superior
//
// Abre el reporte de contenido (screens/pantalla_reporte.dart) con el
// «¿Dónde?» ya lleno con lo que está en pantalla: la lección y el paso, la
// frase, la palabra o la pregunta. Así quien prueba la app puede avisar de una
// pronunciación, un pinyin, una traducción o un trazo que está mal sin tener
// que explicar dónde lo vio.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/reporte.dart';
import '../idioma.dart';
import '../screens/pantalla_reporte.dart';
import '../tema.dart';

class BotonReportar extends StatelessWidget {
  const BotonReportar({super.key, required this.donde, this.queEstaMal = '', this.pequeno = false});

  /// Qué hay en pantalla al tocar la bandera (se calcula en ese momento).
  final String Function() donde;

  /// Una de [queEstaMalOpciones] (en español) o ''.
  final String queEstaMal;

  /// Dentro de una tarjeta (una frase de la lista), en vez de en la barra.
  final bool pequeno;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: pequeno ? VisualDensity.compact : null,
        icon: Icon(Icons.flag_outlined, size: pequeno ? 18 : 24, color: pequeno ? context.colores.tenue : context.colores.icono),
        tooltip: tr('Reportar un error'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PantallaReporte(tipo: TipoReporte.contenido, donde: donde(), queEstaMal: queEstaMal),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// aviso_version.dart — La pregunta y el aviso de versión nueva
//
//   preguntarAvisoVersiones  la única vez que se pregunta si quieres el aviso
//                            (después se cambia en Ajustes).
//   TarjetaVersionNueva      el aviso en el inicio: «Descargar» o «Ahora no».
//
// La consulta y sus reglas están en helpers/actualizaciones.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../helpers/actualizaciones.dart';
import '../helpers/archivos.dart';
import '../idioma.dart';
import '../tema.dart';
import 'tarjeta_vidrio.dart';

/// true = sí, false = no; null si se cerró sin elegir (se vuelve a preguntar
/// otro día).
Future<bool?> preguntarAvisoVersiones(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(tr('¿Te aviso cuando haya una versión nueva?')),
        content: Text(tr(
            'Una vez al día, la app puede revisar en GitHub si salió una versión nueva y avisarte aquí. Solo consulta el número de versión: no envía nada sobre ti ni sobre tu progreso. Puedes cambiarlo en Ajustes.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: Text(tr('No, gracias'))),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: Text(tr('Sí, avísame'))),
        ],
      ),
    );

/// Abre la descarga de [nueva] (el APK de este teléfono o la página).
Future<void> descargarVersion(BuildContext context, VersionNueva nueva) async {
  final aviso = ScaffoldMessenger.of(context);
  final ok = await Archivos.abrirEnlace(nueva.descarga).catchError((Object _) => false);
  aviso.showSnackBar(SnackBar(
    duration: const Duration(seconds: 8),
    content: Text(ok
        ? tr('Cuando termine de bajar, ábrelo e instálalo: se instala encima, sin perder tu progreso.')
        : tr('No encontré un navegador para descargarla.')),
  ));
}

class TarjetaVersionNueva extends StatelessWidget {
  const TarjetaVersionNueva({super.key, required this.nueva, required this.onDescartar});

  final VersionNueva nueva;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TarjetaVidrio(
      relleno: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Hay una versión nueva: {0}', [nueva.version]),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => Archivos.abrirEnlace(nueva.pagina),
                  child: Text(tr('Novedades'), style: TextStyle(color: c.suave)),
                ),
                TextButton(onPressed: onDescartar, child: Text(tr('Ahora no'), style: TextStyle(color: c.suave))),
                TextButton(onPressed: () => descargarVersion(context, nueva), child: Text(tr('Descargar'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

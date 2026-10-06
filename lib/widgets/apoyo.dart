// ─────────────────────────────────────────────────────────────────────────────
// apoyo.dart — Apoyar el proyecto (donativos voluntarios)
//
// Hanzi Dojo es gratis, sin anuncios y de código abierto, y así se queda: el
// donativo no desbloquea nada. Aparece en tres lugares, siempre discreto:
//   · Ajustes → «Apoyar el proyecto».
//   · Créditos, al final.
//   · Una sola vez en la vida de la app, después de celebrar un logro (cuando
//     ya llevas 3 o más): un aviso abajo que se puede ignorar.
//
// El enlace se abre en el navegador; la app sigue sin permiso de internet.
//
// Google Play solo permite enlaces de donativos dentro de la app a
// organizaciones sin fines de lucro. Para esa tienda se compila con
//   flutter build apk --dart-define=TIENDA=play
// y todo lo de este archivo se oculta (el enlace queda en la ficha).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/repositorio.dart';
import '../datos/repositorio_habito.dart';
import '../helpers/archivos.dart';
import '../idioma.dart';
import '../tema.dart';

class Apoyo {
  Apoyo._();

  /// Donativo con PayPal (paypal.me del autor). Para cambiar de plataforma
  /// basta con cambiar esta línea.
  static final enlace = Uri.parse('https://paypal.me/simbadelmarino');

  /// Tienda para la que se compiló (`--dart-define=TIENDA=play`).
  static const _tienda = String.fromEnvironment('TIENDA');

  /// ¿Se muestran los donativos en esta versión?
  static bool get disponible => _tienda != 'play';

  /// Ajuste que recuerda que ya se sugirió una vez.
  static const _ajusteSugerido = 'apoyo_sugerido';

  /// Logros desbloqueados a partir de los cuales se sugiere (alguien que ya
  /// usa la app de verdad, no el primer día).
  static const logrosParaSugerir = 3;

  /// Después de celebrar logros nuevos: si es la primera vez que se cumple,
  /// un aviso discreto con «Ver cómo». Nunca vuelve a salir.
  static Future<void> sugerirTrasLogro(BuildContext context, Repositorio repo) async {
    if (!disponible) return;
    if (await repo.base.leerAjuste(_ajusteSugerido) != null) return;
    if ((await repo.logrosDesbloqueados()).length < logrosParaSugerir) return;
    await repo.base.guardarAjuste(_ajusteSugerido, '1');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('¿Te está sirviendo Hanzi Dojo? Es gratis y sin anuncios; si quieres, puedes apoyarlo.')),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: tr('Ver cómo'), onPressed: () => mostrar(context)),
    ));
  }

  /// La hoja con el porqué, el botón de PayPal y otras formas de ayudar.
  static Future<void> mostrar(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colores.hoja,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => const _HojaApoyo(),
      );
}

/// Renglón para Ajustes y Créditos: corazón, «Apoyar el proyecto» y flecha.
/// Quien lo usa lo pone dentro de algo tocable que llame a [Apoyo.mostrar].
class FilaApoyo extends StatelessWidget {
  const FilaApoyo({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      children: [
        Icon(Icons.favorite_border_rounded, color: c.icono),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Apoyar el proyecto'), style: const TextStyle(fontSize: 15)),
              Text(tr('Voluntario: la app es gratis y completa para todos'),
                  style: TextStyle(fontSize: 12, color: c.tenue)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 14, color: c.tenue),
      ],
    );
  }
}

class _HojaApoyo extends StatelessWidget {
  const _HojaApoyo();

  Future<void> _donar(BuildContext context) async {
    final aviso = ScaffoldMessenger.of(context);
    final ok = await Archivos.abrirEnlace(Apoyo.enlace).catchError((Object _) => false);
    if (!ok) aviso.showSnackBar(SnackBar(content: Text(tr('No se pudo abrir el navegador.'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = TextStyle(fontSize: 14.5, height: 1.45, color: c.suave);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.separador, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text('心', textAlign: TextAlign.center, style: TextStyle(fontSize: 44, color: c.icono)),
            const SizedBox(height: 6),
            Text(tr('Apoyar Hanzi Dojo'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(
              tr('Hanzi Dojo es gratis, sin anuncios ni cuentas, y de código abierto. Así va a seguir.'),
              style: texto,
            ),
            const SizedBox(height: 8),
            Text(
              tr('Si te está ayudando a aprender y quieres apoyar su desarrollo (más libros, grabaciones y ejercicios), puedes dejar un donativo voluntario. No desbloquea nada: la app es igual para todos.'),
              style: texto,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.boton,
                foregroundColor: c.textoBoton,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: Text(tr('Donar con PayPal')),
              onPressed: () => _donar(context),
            ),
            const SizedBox(height: 6),
            Text(tr('Se abre en el navegador. Tú eliges la cantidad.'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.tenue)),
            const SizedBox(height: 20),
            Text(tr('Otras formas de ayudar'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              tr('Recomiéndala a alguien que estudie chino, cuéntanos qué mejorar (Ajustes → Reportar un problema) o corrige una traducción en GitHub.'),
              style: texto.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Ahora no'))),
          ],
        ),
      ),
    );
  }
}

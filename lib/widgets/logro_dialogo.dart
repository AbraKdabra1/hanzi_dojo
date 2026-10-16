// ─────────────────────────────────────────────────────────────────────────────
// logro_dialogo.dart — Aviso de logro desbloqueado
//
// Al volver al inicio, si desbloqueaste uno o varios logros, aparece este
// aviso (una sola vez por logro). Desde aquí se puede compartir la tarjeta
// del logro (pantalla_compartir.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/logros.dart';
import '../screens/pantalla_compartir.dart';
import '../tema.dart';
import '../idioma.dart';

Future<void> mostrarLogrosNuevos(BuildContext context, List<Logro> logros) async {
  if (logros.isEmpty) return;
  final compartir = await showDialog<Logro>(
    context: context,
    builder: (contexto) => _DialogoLogros(logros: logros),
  );
  if (compartir != null && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PantallaCompartir(logro: compartir)),
    );
  }
}

class _DialogoLogros extends StatelessWidget {
  const _DialogoLogros({required this.logros});

  final List<Logro> logros;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final principal = logros.first;
    return AlertDialog(
      backgroundColor: c.hoja,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(principal.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            logros.length == 1 ? tr('¡Logro desbloqueado!') : tr('¡{0} logros nuevos!', [logros.length]),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.tenue, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          if (logros.length == 1) ...[
            Text(principal.titulo,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(principal.descripcion, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.suave)),
          ] else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final l in logros)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(l.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                  Text(l.descripcion, style: TextStyle(fontSize: 12, color: c.suave)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context, principal),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text(tr('Compartir')),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('¡Seguir!'))),
      ],
    );
  }
}

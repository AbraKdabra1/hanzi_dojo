// ─────────────────────────────────────────────────────────────────────────────
// pantalla_errores.dart — Informe de errores (Ajustes → Informe de errores)
//
// Muestra los errores que la app guardó en el teléfono (registro_errores.dart),
// del más reciente al más antiguo. Desde aquí se pueden copiar (para pegarlos
// en un reporte) o borrar. No se envía nada a ningún lado.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/registro_errores.dart';
import '../helpers/archivos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_reporte.dart';

class PantallaErrores extends StatefulWidget {
  const PantallaErrores({super.key});

  @override
  State<PantallaErrores> createState() => _PantallaErroresState();
}

class _PantallaErroresState extends State<PantallaErrores> {
  List<EntradaError>? _errores;
  InfoDispositivo _info = InfoDispositivo.desconocida;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final errores = await RegistroErrores.leer();
    final info = await Archivos.info();
    if (mounted) {
      setState(() {
        _errores = errores;
        _info = info;
      });
    }
  }

  Future<void> _copiar() async {
    final texto = RegistroErrores.comoTexto(_errores ?? const [], _info.toString());
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Informe copiado. Pégalo en tu reporte.')),
    );
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar el informe?'),
        content: const Text('Se borrarán todos los errores guardados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await RegistroErrores.borrar();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final errores = _errores;
    final hay = errores != null && errores.isNotEmpty;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(
          titulo: 'Informe de errores',
          acciones: [
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.black54),
              tooltip: 'Reportar un problema',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PantallaReporte()),
              ),
            ),
            if (errores != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.black54),
                tooltip: 'Copiar informe',
                onPressed: _copiar,
              ),
            if (hay)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                tooltip: 'Borrar',
                onPressed: _borrar,
              ),
          ],
        ),
        body: errores == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black54))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TarjetaVidrio(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Si algo falla, la app guarda aquí los detalles. Nada se envía '
                          'solo: si quieres reportarlo, cópialo y pégalo en tu reporte.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        Text(_info.toString(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!hay)
                    const MensajeCentrado(
                      emoji: '✅',
                      titulo: 'Sin errores registrados',
                      texto: 'Todo ha funcionado bien hasta ahora.',
                    )
                  else
                    for (final e in errores) ...[
                      _TarjetaError(error: e),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
      ),
    );
  }
}

class _TarjetaError extends StatelessWidget {
  const _TarjetaError({required this.error});

  final EntradaError error;

  @override
  Widget build(BuildContext context) {
    final veces = error.veces > 1 ? ' · ×${error.veces}' : '';
    return TarjetaVidrio(
      child: Theme(
        // Sin las líneas que ExpansionTile dibuja al abrirse.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Text(
            error.mensaje,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${RegistroErrores.fechaCorta(error.momento)} · ${error.origen}$veces',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                error.pila.isEmpty ? error.mensaje : '${error.mensaje}\n\n${error.pila}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

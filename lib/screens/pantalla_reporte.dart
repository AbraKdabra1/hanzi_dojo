// ─────────────────────────────────────────────────────────────────────────────
// pantalla_reporte.dart — "Reportar un problema"
//
// Se llega desde Ajustes, desde el Informe de errores, desde la pantalla de
// estudio (error en el carácter que estás escribiendo) y desde la ficha de un
// carácter en «Leer». En esos dos últimos casos el "¿Dónde?" ya viene lleno.
//
// Al final, el usuario ve el reporte tal cual y elige:
//   · Abrir en GitHub: el formulario del repositorio se abre en el navegador
//     ya lleno (ver reporte.dart). Hace falta una cuenta de GitHub (gratis).
//   · Copiar: para mandarlo por correo, WhatsApp o donde prefiera.
// Nada se envía sin que el usuario toque uno de esos botones.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/registro_errores.dart';
import '../datos/reporte.dart';
import '../helpers/archivos.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';
import '../tema.dart';
import '../idioma.dart';

class PantallaReporte extends StatefulWidget {
  const PantallaReporte({super.key, this.tipo = TipoReporte.error, this.donde = '', this.queEstaMal = ''});

  final TipoReporte tipo;

  /// Carácter o libro del que se reporta algo (ya lleno si se viene de ahí).
  final String donde;
  final String queEstaMal;

  @override
  State<PantallaReporte> createState() => _PantallaReporteState();
}

class _PantallaReporteState extends State<PantallaReporte> {
  late TipoReporte _tipo = widget.tipo;
  late final TextEditingController _donde = TextEditingController(text: widget.donde);
  final TextEditingController _descripcion = TextEditingController();
  final TextEditingController _propuesta = TextEditingController();
  late String _queEstaMal = widget.queEstaMal;
  bool _adjuntarDispositivo = true;
  bool _adjuntarErrores = true;

  InfoDispositivo _info = InfoDispositivo.desconocida;
  List<EntradaError> _errores = const [];

  @override
  void initState() {
    super.initState();
    for (final c in [_donde, _descripcion, _propuesta]) {
      c.addListener(() => setState(() {}));
    }
    _cargar();
  }

  Future<void> _cargar() async {
    final info = await Archivos.info();
    final errores = await RegistroErrores.leer();
    if (mounted) {
      setState(() {
        _info = info;
        _errores = errores;
      });
    }
  }

  @override
  void dispose() {
    _donde.dispose();
    _descripcion.dispose();
    _propuesta.dispose();
    super.dispose();
  }

  Reporte get _reporte => Reporte(
        tipo: _tipo,
        descripcion: _descripcion.text,
        donde: _tipo == TipoReporte.contenido ? _donde.text.trim() : '',
        queEstaMal: _tipo == TipoReporte.contenido ? _queEstaMal : '',
        propuesta: _tipo == TipoReporte.contenido ? _propuesta.text : '',
        dispositivo: _adjuntarDispositivo ? _info.toString() : '',
        errores: _tipo == TipoReporte.error && _adjuntarErrores ? _errores : const [],
      );

  bool get _listo => _descripcion.text.trim().length >= 5;

  void _aviso(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _abrirGitHub() async {
    final ok = await Archivos.abrirEnlace(_reporte.urlGitHub).catchError((Object _) => false);
    if (!mounted) return;
    if (!ok) {
      await _copiar(motivo: tr('No se pudo abrir el navegador. '));
    }
  }

  Future<void> _copiar({String motivo = ''}) async {
    await Clipboard.setData(ClipboardData(text: _reporte.texto));
    if (mounted) _aviso(tr('{0}Reporte copiado: pégalo donde quieras enviarlo.', [motivo]));
  }

  @override
  Widget build(BuildContext context) {
    final r = _reporte;
    final gris = TextStyle(fontSize: 13, color: context.colores.suave, height: 1.35);
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Reportar un problema')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('¿Qué quieres contarnos?'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in TipoReporte.values)
                        ChoiceChip(
                          label: Text(tr(t.etiqueta)),
                          selected: _tipo == t,
                          onSelected: (_) => setState(() => _tipo = t),
                        ),
                    ],
                  ),
                  if (_tipo == TipoReporte.contenido) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _donde,
                      decoration: InputDecoration(
                        labelText: tr('¿Dónde?'),
                        hintText: tr('El carácter, o el libro y capítulo'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(tr('¿Qué está mal?'), style: gris),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final o in queEstaMalOpciones)
                          ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(tr(o), style: const TextStyle(fontSize: 12.5)),
                            selected: _queEstaMal == o,
                            onSelected: (s) => setState(() => _queEstaMal = s ? o : ''),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descripcion,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: switch (_tipo) {
                        TipoReporte.error => tr('¿Qué pasó? ¿Qué esperabas?'),
                        TipoReporte.contenido => tr('¿Qué dice ahora y por qué está mal?'),
                        TipoReporte.sugerencia => tr('¿Qué te gustaría?'),
                      },
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_tipo == TipoReporte.contenido) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _propuesta,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: tr('¿Cómo debería decir? (opcional)')),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(tr('Adjuntar versión de la app y modelo del teléfono')),
                    subtitle: Text(_info.toString(), style: const TextStyle(fontSize: 11.5)),
                    value: _adjuntarDispositivo,
                    onChanged: (v) => setState(() => _adjuntarDispositivo = v),
                  ),
                  if (_tipo == TipoReporte.error)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(tr('Adjuntar el informe de errores')),
                      subtitle: Text(
                        _errores.isEmpty
                            ? tr('No hay errores registrados')
                            : tr('Los {0} más recientes', [_errores.length < Reporte.erroresMaximos ? _errores.length : Reporte.erroresMaximos]),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      value: _adjuntarErrores && _errores.isNotEmpty,
                      onChanged: _errores.isEmpty ? null : (v) => setState(() => _adjuntarErrores = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Esto es lo que se enviará'), style: gris.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(
                    _listo ? r.texto : tr('Escribe una descripción para ver el reporte.'),
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.colores.boton,
                    foregroundColor: context.colores.textoBoton,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr('Abrir en GitHub')),
              onPressed: _listo ? _abrirGitHub : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.copy_rounded),
              label: Text(tr('Copiar el reporte')),
              onPressed: _listo ? _copiar : null,
            ),
            const SizedBox(height: 10),
            Text(
              tr('GitHub abre el formulario del proyecto ya lleno; para enviarlo necesitas una cuenta (es gratis). Si no tienes, copia el reporte y mándalo como prefieras.'),
              style: gris.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

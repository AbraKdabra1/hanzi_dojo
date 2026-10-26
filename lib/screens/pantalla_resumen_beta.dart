// ─────────────────────────────────────────────────────────────────────────────
// pantalla_resumen_beta.dart — Enviar mi opinión (resumen de uso)
//
// Muestra el resumen que arma datos/resumen_beta.dart con lo que hiciste en
// la app, un cuadro para escribir tu comentario y los botones para
// compartirlo (WhatsApp, correo…) o copiarlo. Nada sale del teléfono si no lo
// compartes tú, y ves exactamente lo que se comparte.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/datos_app.dart';
import '../datos/registro_errores.dart';
import '../datos/resumen_beta.dart';
import '../helpers/archivos.dart';
import '../idioma.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaResumenBeta extends StatefulWidget {
  const PantallaResumenBeta({super.key});

  @override
  State<PantallaResumenBeta> createState() => _PantallaResumenBetaState();
}

class _PantallaResumenBetaState extends State<PantallaResumenBeta> {
  final _comentario = TextEditingController();
  DatosResumen? _datos;
  InfoDispositivo _info = InfoDispositivo.desconocida;
  List<EntradaError> _errores = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final datos = await repo.datosResumen();
    final info = await Archivos.info();
    final errores = await RegistroErrores.leer();
    if (!mounted) return;
    setState(() {
      _datos = datos;
      _info = info;
      _errores = errores;
    });
  }

  String get _texto => _datos == null
      ? ''
      : ResumenBeta.texto(_datos!, dispositivo: _info.toString(), errores: _errores, comentario: _comentario.text);

  Future<void> _compartir() async {
    final ok = await Archivos.compartirTexto(_texto, titulo: tr('Resumen de la beta · Meizi Hanzi'))
        .catchError((Object _) => false);
    if (!ok) await _copiar();
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Resumen copiado. Pégalo en un mensaje a quien te invitó.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final datos = _datos;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Enviar mi opinión')),
        body: datos == null
            ? Center(child: CircularProgressIndicator(color: c.icono))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TarjetaVidrio(
                    child: Text(
                      tr('Este resumen se arma en tu teléfono con lo que has hecho en la app. Nada se envía solo: léelo y, si estás de acuerdo, compártelo con quien te invitó.'),
                      style: TextStyle(fontSize: 13, color: c.suave, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TarjetaVidrio(
                    child: TextField(
                      controller: _comentario,
                      minLines: 3,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: tr('Tu comentario (opcional)'),
                        hintText: tr('¿Qué te confundió? ¿Qué te gustó? ¿Qué le falta?'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _compartir,
                          icon: const Icon(Icons.share_rounded),
                          label: Text(tr('Compartir')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _copiar,
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(tr('Copiar')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(tr('Lo que se comparte'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TarjetaVidrio(
                    child: SelectableText(
                      _texto,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: c.tinta),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

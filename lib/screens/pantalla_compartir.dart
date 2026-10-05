// ─────────────────────────────────────────────────────────────────────────────
// pantalla_compartir.dart — Tarjeta de progreso para compartir
//
// Una imagen de 1080 × 1350 (formato de publicación vertical) con tu racha o
// el logro que acabas de desbloquear, tus cifras y el avance por nivel, sobre
// el papel y la rama de ciruelo de la app. «Compartir» abre el menú de
// Android (WhatsApp, Instagram…); «Guardar» la deja donde elijas.
// No sale nada del teléfono si no lo compartes tú.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../datos/datos_app.dart';
import '../datos/logros.dart';
import '../datos/modelos.dart';
import '../datos/registro_errores.dart';
import '../datos/repositorio_habito.dart';
import '../datos/repositorio_practica.dart';
import '../helpers/archivos.dart';
import '../helpers/habito.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../idioma.dart';

/// Lo que muestra la tarjeta.
class DatosTarjeta {
  const DatosTarjeta({
    required this.racha,
    required this.caracteres,
    required this.palabras,
    required this.dominados,
    required this.niveles,
  });

  final int racha;
  final int caracteres;
  final int palabras;
  final int dominados;
  final List<AvanceNivel> niveles;
}

class PantallaCompartir extends StatefulWidget {
  const PantallaCompartir({super.key, this.logro});

  /// Si se da, la tarjeta celebra este logro; si no, muestra tu racha.
  final Logro? logro;

  @override
  State<PantallaCompartir> createState() => _PantallaCompartirState();
}

class _PantallaCompartirState extends State<PantallaCompartir> {
  final _clave = GlobalKey();
  DatosTarjeta? _datos;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final racha = await repo.rachaConProtector();
    final niveles = await repo.avancePorNivel();
    final palabras = await repo.avancePalabras();
    final caracteres = await repo.totalEstudiados();
    if (!mounted) return;
    setState(() {
      _datos = DatosTarjeta(
        racha: racha.actual,
        caracteres: caracteres,
        palabras: palabras.fold(0, (s, p) => s + p.estudiadas),
        dominados: niveles.fold(0, (s, n) => s + n.dominados),
        niveles: niveles,
      );
    });
  }

  /// La tarjeta como PNG de 1080 × 1350.
  Future<Uint8List?> _imagen() async {
    final caja = _clave.currentContext?.findRenderObject();
    if (caja is! RenderRepaintBoundary) return null;
    final imagen = await caja.toImage(pixelRatio: 3);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> _hacer(Future<void> Function(Uint8List png) accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final png = await _imagen();
      if (png != null) await accion(png);
    } catch (e, pila) {
      RegistroErrores.registrar('Compartir', e, pila);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No se pudo preparar la imagen: {0}', [e]))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _compartir() => _hacer((png) async {
        final ok = await Habito.compartirImagen(png, texto: tr('Aprendo chino con Hanzi Dojo · 汉字道场'));
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No se pudo abrir el menú para compartir.'))));
        }
      });

  Future<void> _guardar() => _hacer((png) async {
        final nombre = await Archivos.guardar(nombre: 'hanzi_dojo_progreso.png', bytes: png, tipo: 'image/png');
        if (nombre != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Imagen guardada: {0}', [nombre]))));
        }
      });

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Compartir mi progreso')),
        body: datos == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Center(
                        child: FittedBox(
                          child: RepaintBoundary(
                            key: _clave,
                            child: TarjetaProgreso(datos: datos, logro: widget.logro),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _ocupado ? null : _guardar,
                            icon: const Icon(Icons.save_alt_rounded),
                            label: Text(tr('Guardar')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _ocupado ? null : _compartir,
                            icon: const Icon(Icons.share_rounded),
                            label: Text(tr('Compartir')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// La tarjeta en sí: 360 × 450 puntos (× 3 = 1080 × 1350 píxeles).
class TarjetaProgreso extends StatelessWidget {
  const TarjetaProgreso({super.key, required this.datos, this.logro});

  final DatosTarjeta datos;
  final Logro? logro;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final logro = this.logro;
    final conAvance = [for (final n in datos.niveles) if (n.estudiados > 0) n];
    final niveles = (conAvance.isEmpty ? datos.niveles.take(1) : conAvance.take(3)).toList();
    final hoy = DateTime.now();
    return SizedBox(
      width: 360,
      height: 450,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FondoTintaChina(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A la derecha: a la izquierda arriba está la rama de ciruelo.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('汉字道场', style: TextStyle(fontSize: 22, letterSpacing: 2)),
                    Text('Hanzi Dojo', style: TextStyle(fontSize: 11, color: c.tenue, letterSpacing: 1.5)),
                  ],
                ),
                const Spacer(),
                if (logro != null) ...[
                  Text(logro.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 4),
                  Text(tr('Logro desbloqueado'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.tenue, letterSpacing: 1)),
                  Text(logro.titulo,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  Text(logro.descripcion, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.suave)),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 48)),
                      const SizedBox(width: 8),
                      Text('${datos.racha}', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w700, height: 1)),
                    ],
                  ),
                  Text(datos.racha == 1 ? tr('día seguido practicando') : tr('días seguidos practicando'),
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: c.suave)),
                ],
                const Spacer(),
                Row(
                  children: [
                    _Cifra(valor: datos.caracteres, etiqueta: 'caracteres'),
                    _Cifra(valor: datos.palabras, etiqueta: 'palabras'),
                    _Cifra(valor: datos.dominados, etiqueta: 'dominados'),
                  ],
                ),
                const SizedBox(height: 14),
                for (final n in niveles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 64, child: EtiquetaNivel(nivel: n.nivel)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: n.fraccion,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: c.separador,
                            color: EtiquetaNivel.colorPara(context, n.nivel),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('${(n.fraccion * 100).round()} %',
                              textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: c.suave)),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(tr('{0} de {1} de {2}', [hoy.day, mesesLargos[hoy.month - 1], hoy.year]),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.tenue)),
                Text(tr('Aprende a escribir chino · gratis y de código abierto'),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.tenue)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          Text(etiqueta, style: TextStyle(fontSize: 11, color: context.colores.tenue)),
        ],
      ),
    );
  }
}

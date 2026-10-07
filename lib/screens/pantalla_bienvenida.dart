// ─────────────────────────────────────────────────────────────────────────────
// pantalla_bienvenida.dart — El tutorial de la primera vez
//
// Cinco pantallas cortas que se deslizan, con "Omitir" siempre a la vista:
//   1. Qué es 梅字.
//   2. Escribir: la app revisa cada trazo (el 永 se dibuja solo: los ocho
//      trazos básicos de la caligrafía viven en ese carácter).
//   3. Un poco cada día: repasos, meta diaria y racha.
//   4. Más allá de escribir: Practicar y Leer.
//   5. Escribe tu primer carácter (人) en el lienzo de verdad.
//
// Sale sola la primera vez que se abre la app (PantallaInicio). A quien ya
// tenía progreso al actualizar no se le muestra. Se puede volver a ver desde
// Ajustes → Ver el tutorial.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/modelos.dart';
import '../datos/repositorio_habito.dart';
import '../helpers/sensaciones.dart';
import '../idioma.dart';
import '../tema.dart';
import '../widgets/animacion_trazos.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/lienzo_escritura.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  /// Cuántas pantallas tiene (para las pruebas).
  static const paginas = 5;

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  final _paginas = PageController();
  int _pagina = 0;

  /// Los caracteres de las pantallas 2 (永) y 5 (人), de la base.
  Caracter? _yong;
  Caracter? _ren;

  /// Ya escribiste tu primer carácter.
  bool _escrito = false;

  bool get _ultima => _pagina == PantallaBienvenida.paginas - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = DatosApp.de(context);
      final yong = await repo.caracterPorTexto('永');
      final ren = await repo.caracterPorTexto('人');
      if (mounted) {
        setState(() {
          _yong = yong;
          _ren = ren;
        });
      }
    });
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  /// "Omitir" o "Empezar": queda visto y se cierra.
  Future<void> _terminar() async {
    await DatosApp.de(context).marcarTutorialVisto();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _siguiente() {
    if (_ultima) {
      _terminar();
      return;
    }
    _paginas.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Arriba: en qué pantalla vas y "Omitir".
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < PantallaBienvenida.paginas; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _pagina ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _pagina ? c.tinta : c.separador,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const Spacer(),
                    if (!_ultima)
                      TextButton(
                        onPressed: _terminar,
                        child: Text(tr('Omitir'), style: TextStyle(fontSize: 15, color: c.suave)),
                      )
                    else
                      const SizedBox(height: 48),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  // En la última se escribe con el dedo: deslizar no debe
                  // cambiar de pantalla.
                  physics: _ultima ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() => _pagina = i),
                  children: [
                    _Pagina(
                      dibujo: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('梅字', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w400, letterSpacing: 12)),
                          Text('Meizi Hanzi', style: TextStyle(fontSize: 15, color: c.tenue, letterSpacing: 2)),
                        ],
                      ),
                      titulo: tr('Aprende a escribir chino, trazo a trazo'),
                      texto: tr('Los 3,000 caracteres del HSK 3.0, con grabaciones de hablantes nativos. Gratis, sin anuncios y sin internet.'),
                    ),
                    _Pagina(
                      dibujo: SizedBox(
                        height: 230,
                        child: _yong == null
                            ? const SizedBox()
                            : AnimacionTrazos(
                                caracter: _yong!.caracter,
                                trazosSvg: _yong!.trazosSvg,
                                medianas: _yong!.medianas,
                              ),
                      ),
                      titulo: tr('Escribe con el dedo'),
                      texto: tr('La app revisa cada trazo: la forma, el orden y la dirección. En modo novato ves la silueta y, si te equivocas, cómo va el trazo; en modo experto escribes de memoria.'),
                    ),
                    _Pagina(
                      dibujo: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Etiqueta(emoji: '🔁', texto: tr('Repasos a tiempo')),
                          _Etiqueta(emoji: '🎯', texto: tr('Meta diaria')),
                          _Etiqueta(emoji: '🔥', texto: tr('Racha')),
                        ],
                      ),
                      titulo: tr('Un poco cada día'),
                      texto: tr('La app te dice qué repasar y cuándo, justo antes de que lo olvides. Ponte una meta diaria y cuida tu racha: diez minutos bastan.'),
                    ),
                    _Pagina(
                      dibujo: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Tarjeta(
                            emoji: '🎧',
                            titulo: tr('Practicar'),
                            texto: tr('Tonos, escucha, vocabulario, pinyin y simulacros del examen HSK.'),
                          ),
                          const SizedBox(height: 10),
                          _Tarjeta(
                            emoji: '📖',
                            titulo: tr('Leer'),
                            texto: tr('Cuentos y leyendas por nivel, con pinyin, traducción y audio.'),
                          ),
                        ],
                      ),
                      titulo: tr('Más allá de escribir'),
                      texto: tr('Todo se queda en tu teléfono: tu progreso es tuyo.'),
                    ),
                    _PrimerCaracter(
                      caracter: _ren,
                      escrito: _escrito,
                      onEscrito: () {
                        Sensaciones.respuesta(true);
                        setState(() => _escrito = true);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.boton,
                      foregroundColor: c.textoBoton,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _siguiente,
                    child: Text(_ultima ? tr('Empezar') : tr('Siguiente')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una pantalla del tutorial: dibujo arriba, título y explicación.
class _Pagina extends StatelessWidget {
  const _Pagina({required this.dibujo, required this.titulo, required this.texto});

  final Widget dibujo;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: restricciones.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  dibujo,
                  const SizedBox(height: 32),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: c.suave, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.emoji, required this.texto});

  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      radio: 24,
      relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.emoji, required this.titulo, required this.texto});

  final String emoji;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      relleno: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: TextStyle(fontSize: 14, color: context.colores.suave, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La última pantalla: escribir 人 en el lienzo de verdad, en modo novato.
class _PrimerCaracter extends StatelessWidget {
  const _PrimerCaracter({required this.caracter, required this.escrito, required this.onEscrito});

  final Caracter? caracter;
  final bool escrito;
  final VoidCallback onEscrito;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final ren = caracter;
    return LayoutBuilder(builder: (context, restricciones) {
      // El lienzo, lo más grande que quepa con los textos.
      final lado = math.min(restricciones.maxWidth - 64, restricciones.maxHeight - 190).clamp(160.0, 340.0);
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              tr('Escribe tu primer carácter'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              tr('人 · rén · persona'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: c.suave),
            ),
            const SizedBox(height: 16),
            SizedBox.square(
              dimension: lado,
              child: ren == null
                  ? const SizedBox()
                  : LienzoEscritura(
                      caracter: ren.caracter,
                      trazosSvg: ren.trazosSvg,
                      medianas: ren.medianas,
                      modoNovato: true,
                      onCompletado: (_) => onEscrito(),
                    ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                escrito
                    ? tr('¡Muy bien! Así se escribe con Meizi Hanzi. Toca «Empezar».')
                    : tr('Dos trazos: primero el de la izquierda, de arriba hacia abajo. Sigue la silueta.'),
                key: ValueKey(escrito),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: escrito ? c.tinta : c.suave,
                  fontWeight: escrito ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// pantalla_creditos.dart — De dónde vienen los datos y bajo qué licencia
//
// Mostrar esto es obligatorio para publicar la app: varias fuentes exigen
// atribución (CC-CEDICT, Tatoeba) y otras que se incluya su licencia
// (Arphic, LGPL, Unicode, OFL). Los textos completos se ven con el botón
// "Ver licencias completas" (se registran en main.dart).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/tarjeta_vidrio.dart';

class PantallaCreditos extends StatelessWidget {
  const PantallaCreditos({super.key});

  static const _fuentes = [
    (
      'Código de Hanzi Dojo',
      'Software libre: puedes usarlo, estudiarlo, modificarlo y compartirlo. Las versiones '
          'modificadas que se distribuyan deben seguir siendo libres y publicar su código. '
          'Código fuente: github.com/AbraKdabra1/hanzi_dojo.',
      'GPL-3.0',
    ),
    (
      'Niveles HSK 3.0',
      'Lista oficial de caracteres del estándar GF 0025-2021 (Ministerio de Educación de China), '
          'tomada de github.com/ivankra/hsk30.',
      'MIT',
    ),
    (
      'Trazos y orden de trazos',
      'Make Me a Hanzi (github.com/skishore/makemeahanzi), derivado de las fuentes Arphic PL KaitiM GB y UKai.',
      'Arphic Public License',
    ),
    (
      'Lecturas',
      'Lista HSK 3.0 y Make Me a Hanzi (dictionary.txt, basado en Unihan y CJKlib).',
      'LGPL 3',
    ),
    (
      'Significados',
      'CC-CEDICT (cc-cedict.org). Los significados en español son una traducción de esos datos, '
          'generada con ayuda de IA y revisable.',
      'CC BY-SA 4.0',
    ),
    (
      'Radicales',
      'Unihan (Unicode), campo kRSUnicode: radical Kangxi de cada carácter.',
      'Unicode License v3',
    ),
    (
      'Oraciones de ejemplo',
      'Tatoeba (tatoeba.org), vía github.com/krmanik/chinese-example-sentences. '
          'Traducción al español generada con ayuda de IA a partir del chino.',
      'CC BY 2.0 FR',
    ),
    (
      'Libros de «Leer»',
      'Historias clásicas chinas de dominio público, contadas de nuevo para Hanzi Dojo (HSK 1 a 5). '
          'Textos originales del Zengguang Xianwen y poemas Tang tomados de '
          'github.com/chinese-poetry/chinese-poetry. Traducciones al español escritas para la app.',
      'MIT (textos clásicos)',
    ),
    (
      'Tradicional → simplificado',
      'OpenCC (github.com/BYVoid/OpenCC): para consultar los caracteres de libros propios '
          'escritos en caracteres tradicionales.',
      'Apache 2.0',
    ),
    (
      'Tipografía',
      'Noto Sans SC (Google), recortada a los caracteres de la app.',
      'SIL Open Font License 1.1',
    ),
    (
      'Ilustración de inicio',
      'Salón de Oración por la Buena Cosecha (祈年殿) del Templo del Cielo, Pekín. '
          'Ilustración original hecha para Hanzi Dojo (herramientas_arte/templo_del_cielo.py).',
      'Original',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: const BarraSuperior(titulo: 'Créditos y licencias'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final (titulo, texto, licencia) in _fuentes) ...[
              TarjetaVidrio(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Text(licencia, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                    const SizedBox(height: 6),
                    Text(texto, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Hanzi Dojo',
                  applicationLegalese: 'Código: GPL-3.0 o posterior.\n'
                      'Datos: CC-CEDICT, Make Me a Hanzi, Unihan, HSK 3.0, Tatoeba.',
                ),
                child: const Text('Ver licencias completas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

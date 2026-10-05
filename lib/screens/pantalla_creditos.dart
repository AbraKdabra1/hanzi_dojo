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
import '../tema.dart';
import '../idioma.dart';

class PantallaCreditos extends StatelessWidget {
  const PantallaCreditos({super.key});

  static List<(String, String, String)> get _fuentes => [
    (
      tr('Código de Hanzi Dojo'),
      tr('Software libre: puedes usarlo, estudiarlo, modificarlo y compartirlo. Las versiones modificadas que se distribuyan deben seguir siendo libres y publicar su código. Código fuente: github.com/AbraKdabra1/hanzi_dojo.'),
      'GPL-3.0',
    ),
    (
      tr('Niveles HSK 3.0'),
      tr('Lista oficial de caracteres del estándar GF 0025-2021 (Ministerio de Educación de China), tomada de github.com/ivankra/hsk30.'),
      'MIT',
    ),
    (
      tr('Trazos y orden de trazos'),
      tr('Make Me a Hanzi (github.com/skishore/makemeahanzi), derivado de las fuentes Arphic PL KaitiM GB y UKai.'),
      tr('Arphic Public License'),
    ),
    (
      tr('Lecturas'),
      tr('Lista HSK 3.0 y Make Me a Hanzi (dictionary.txt, basado en Unihan y CJKlib).'),
      'LGPL 3',
    ),
    (
      tr('Significados'),
      tr('CC-CEDICT (cc-cedict.org). Los significados en español son una traducción de esos datos, generada con ayuda de IA y revisable.'),
      'CC BY-SA 4.0',
    ),
    (
      tr('Radicales'),
      tr('Unihan (Unicode), campo kRSUnicode: radical Kangxi de cada carácter.'),
      tr('Unicode License v3'),
    ),
    (
      tr('Oraciones de ejemplo'),
      tr('Tatoeba (tatoeba.org), vía github.com/krmanik/chinese-example-sentences. Traducción al español generada con ayuda de IA a partir del chino.'),
      'CC BY 2.0 FR',
    ),
    (
      tr('Libros de «Leer»'),
      tr('Historias clásicas chinas de dominio público, contadas de nuevo para Hanzi Dojo (HSK 1 a 5). Textos originales del Zengguang Xianwen y poemas Tang tomados de github.com/chinese-poetry/chinese-poetry. Traducciones al español escritas para la app.'),
      tr('MIT (textos clásicos)'),
    ),
    (
      tr('Tradicional → simplificado'),
      tr('OpenCC (github.com/BYVoid/OpenCC): para consultar los caracteres de libros propios escritos en caracteres tradicionales.'),
      tr('Apache 2.0'),
    ),
    (
      tr('Pronunciación (audio)'),
      tr('Grabaciones de hablantes nativos del proyecto audio-cmn (github.com/hugolpz/audio-cmn): sílabas con la voz de Chen Wang y palabras HSK con la voz de Yue Tan (Shtooka). Recortadas, con volumen igualado y convertidas a Opus para la app.'),
      'CC BY-SA',
    ),
    (
      tr('Tipografía'),
      tr('Noto Sans SC (Google), recortada a los caracteres de la app.'),
      tr('SIL Open Font License 1.1'),
    ),
    (
      tr('Rama de ciruelo (梅花)'),
      tr('Ilustración original al estilo de la pintura china a tinta, dibujada por código para Hanzi Dojo (lib/painters/rama_ciruelo.dart).'),
      'GPL-3.0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Créditos y licencias')),
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
                      Text(licencia, style: TextStyle(fontSize: 11, color: context.colores.tenue)),
                    ]),
                    const SizedBox(height: 6),
                    Text(texto, style: TextStyle(fontSize: 13, color: context.colores.suave, height: 1.35)),
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
                  applicationLegalese: tr('Código: GPL-3.0 o posterior.\nDatos: CC-CEDICT, Make Me a Hanzi, Unihan, HSK 3.0, Tatoeba.'),
                ),
                child: Text(tr('Ver licencias completas')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

"""Capturas para las tiendas (AppGallery, F-Droid): marco, título y rama.

Toma las capturas «tienda_*» que hace test/capturas_test.dart (1080 × 2400,
tema claro, sin el aviso de versión) y las deja de 1080 × 1920 (9:16, lo que
piden las tiendas), con un título arriba y la rama de ciruelo de la página de
descarga, en fastlane/metadata/android/<idioma>/images/phoneScreenshots/.

Uso (las capturas salen de la rama ci-registros, carpeta capturas/):
  python herramientas/capturas_tienda.py <carpeta con tienda_*_claro.png>
Necesita Playwright para Python con Chromium (pip install playwright).
"""

import base64
import pathlib
import subprocess
import sys

from playwright.sync_api import sync_playwright

RAIZ = pathlib.Path(__file__).resolve().parent.parent

TITULOS = {
    'es': {
        '1_inicio': 'Lo que te toca hoy, de un vistazo',
        '2_estudio': 'Escribe con el dedo, trazo a trazo',
        '3_tonos': 'Entrena el oído con los tonos',
        '4_lectura': 'Lee cuentos con pinyin y audio',
        '5_desde_cero': '¿Nunca has estudiado chino? Empieza desde cero',
        '6_estadisticas': 'Mira cuánto has avanzado',
    },
    'en': {
        '1_inicio': 'What’s due today, at a glance',
        '2_estudio': 'Write with your finger, stroke by stroke',
        '3_tonos': 'Train your ear for tones',
        '4_lectura': 'Read stories with pinyin and audio',
        '5_desde_cero': 'Never studied Chinese? Start from zero',
        '6_estadisticas': 'See how far you’ve come',
    },
}
CARPETAS = {'es': 'es-MX', 'en': 'en-US'}

PLANTILLA = """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Noto; src: url({fuente}); font-weight: 500; }}
html, body {{ margin: 0; width: 1080px; height: 1920px; overflow: hidden; }}
body {{ font-family: Noto, sans-serif; position: relative;
  background: radial-gradient(50% 35% at 85% 80%, rgba(60,40,20,.07), transparent 70%),
              linear-gradient(#F8F4EE, #F2EDE5); }}
.tinta1 {{ stop-color: #241D19; }} .tinta2 {{ stop-color: #463C35; }}
.rama {{ position: absolute; top: -18px; left: -60px; width: 820px; opacity: .95; }}
h1 {{ position: absolute; left: 90px; right: 90px; top: 250px; margin: 0; text-align: center;
  font-size: 64px; line-height: 1.22; font-weight: 500; color: rgba(0,0,0,.84); }}
.telefono {{ position: absolute; left: 50%; bottom: 0; transform: translateX(-50%);
  width: 680px; height: 1360px; border-radius: 56px 56px 0 0; overflow: hidden;
  border: 14px solid #1F1B18; border-bottom: 0; box-shadow: 0 30px 70px rgba(0,0,0,.22); background: #fff; }}
.telefono img {{ width: 100%; display: block; }}
</style></head><body>{rama}<h1>{titulo}</h1>
<div class="telefono"><img src="data:image/png;base64,{captura}"></div></body></html>"""


def main(origen: str) -> None:
    rama = subprocess.run([sys.executable, str(RAIZ / 'herramientas/rama_descarga.py')],
                          capture_output=True, text=True, check=True).stdout
    # La letra de la app, incrustada (la página no es un archivo: no puede leer otros).
    fuente = 'data:font/ttf;base64,' + base64.b64encode((RAIZ / 'assets/fonts/NotoSansSC-Medium.ttf').read_bytes()).decode()
    with sync_playwright() as p:
        navegador = p.chromium.launch()
        pagina = navegador.new_page(viewport={'width': 1080, 'height': 1920})
        for idioma, titulos in TITULOS.items():
            destino = RAIZ / 'fastlane/metadata/android' / CARPETAS[idioma] / 'images/phoneScreenshots'
            destino.mkdir(parents=True, exist_ok=True)
            for numero, (clave, titulo) in enumerate(titulos.items(), start=1):
                captura = pathlib.Path(origen) / f'tienda_{idioma}_{clave}_claro.png'
                datos = base64.b64encode(captura.read_bytes()).decode()
                pagina.set_content(PLANTILLA.format(fuente=fuente, rama=rama, titulo=titulo, captura=datos))
                pagina.wait_for_timeout(300)
                salida = destino / f'{numero}.png'
                pagina.screenshot(path=str(salida))
                print(salida.relative_to(RAIZ))
        navegador.close()


if __name__ == '__main__':
    main(sys.argv[1])

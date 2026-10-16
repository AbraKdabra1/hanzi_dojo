"""Convierte docs/privacidad.md en una página web con el estilo de la app.

Las tiendas (Huawei AppGallery, Google Play) piden el aviso de privacidad en
una dirección web. Lo corre .github/workflows/web.yml después de compilar, y
queda en https://abrakdabra1.github.io/hanzi_dojo/privacidad/ (siempre igual
al .md del repositorio: no hay dos copias que mantener).

Uso: python herramientas/pagina_privacidad.py docs/privacidad.md build/web/privacidad/index.html
Necesita el paquete «markdown» (pip install markdown).
"""

import html
import pathlib
import re
import sys

import markdown

REPO = 'https://github.com/AbraKdabra1/hanzi_dojo/blob/v2/docs/'

PLANTILLA = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{titulo}</title>
<meta name="description" content="Meizi Hanzi no recopila, no envía y no vende ningún dato.">
<meta name="theme-color" content="#F8F4EE" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#151311" media="(prefers-color-scheme: dark)">
<link rel="icon" type="image/png" href="../favicon.png">
<style>
  :root {{ --arriba: #F8F4EE; --abajo: #F2EDE5; --tinta: rgba(0,0,0,.87); --suave: #555; --tenue: #757575;
          --cristal: rgba(255,255,255,.6); --borde: rgba(255,255,255,.95); --sep: rgba(0,0,0,.08); }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --arriba: #151311; --abajo: #0E0D0B; --tinta: #EDE6DB; --suave: #BDB4A8; --tenue: #948B80;
            --cristal: rgba(255,255,255,.07); --borde: rgba(255,255,255,.14); --sep: rgba(255,255,255,.1); }}
  }}
  * {{ box-sizing: border-box; }}
  html {{ background: var(--abajo); -webkit-text-size-adjust: 100%; }}
  body {{ margin: 0; color: var(--tinta); line-height: 1.6; font-size: 16px;
         font-family: "Noto Sans SC", "PingFang SC", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         background: linear-gradient(var(--arriba), var(--abajo) 60vh); }}
  main {{ max-width: 720px; margin: 0 auto; padding: 32px 20px 56px; }}
  .marca {{ text-align: center; margin-bottom: 18px; }}
  .marca a {{ text-decoration: none; color: inherit; }}
  .marca b {{ display: block; font-size: 44px; font-weight: 400; letter-spacing: 8px; margin-left: 8px; }}
  .marca span {{ font-size: 14px; letter-spacing: 3px; color: var(--tenue); }}
  article {{ background: var(--cristal); border: 1.2px solid var(--borde); border-radius: 24px; padding: 8px 24px 20px; }}
  h1 {{ font-size: 26px; line-height: 1.3; margin: 18px 0 4px; }}
  h2 {{ font-size: 19px; margin: 28px 0 6px; padding-top: 18px; border-top: 1px solid var(--sep); }}
  p, li {{ color: var(--suave); }}
  strong {{ color: var(--tinta); }}
  a {{ color: inherit; }}
  ul {{ padding-left: 22px; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 15px; margin: 10px 0; }}
  th, td {{ text-align: left; vertical-align: top; padding: 8px 10px; border-bottom: 1px solid var(--sep); color: var(--suave); }}
  th {{ color: var(--tinta); }}
  footer {{ text-align: center; font-size: 13px; color: var(--tenue); margin-top: 20px; }}
  footer a {{ color: var(--suave); }}
</style>
</head>
<body>
<main>
  <div class="marca"><a href="../descargar/"><b>梅字</b><span>Meizi Hanzi</span></a></div>
  <article>
{cuerpo}
  </article>
  <footer><a href="../descargar/">Descargar Meizi Hanzi</a> · <a href="https://github.com/AbraKdabra1/hanzi_dojo">Código</a></footer>
</main>
</body>
</html>
"""


def main(origen: str, destino: str) -> None:
    texto = pathlib.Path(origen).read_text(encoding='utf-8')
    # Los enlaces a otros documentos del repositorio (web.md) van a GitHub.
    texto = re.sub(r'\]\(([\w-]+\.md)\)', lambda m: f']({REPO}{m.group(1)})', texto)
    cuerpo = markdown.markdown(texto, extensions=['tables'], output_format='html')
    titulo = re.search(r'^# (.+)$', texto, re.M)
    salida = pathlib.Path(destino)
    salida.parent.mkdir(parents=True, exist_ok=True)
    salida.write_text(
        PLANTILLA.format(titulo=html.escape(titulo.group(1) if titulo else 'Aviso de privacidad'), cuerpo=cuerpo),
        encoding='utf-8',
    )
    print(f'{destino}: {salida.stat().st_size} bytes')


if __name__ == '__main__':
    main(*sys.argv[1:3])

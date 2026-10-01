"""
templo_del_cielo.py
───────────────────
Ilustración original del Salón de Oración por la Buena Cosecha (祈年殿) del
Templo del Cielo (天坛, Pekín) en estilo de tinta china, para el fondo de la
pantalla de inicio.

Cómo funciona:
  1. Arma un SVG de 1080 × 2400 (proporción 20:9, la del Pura 70) con la
     geometría del templo calculada aquí: tres techos cónicos azules con
     aleros curvos, muros rojos con columnas y celosías, la terraza de
     mármol de tres niveles, montañas a la aguada, sol rojo, grullas y
     nubes auspiciosas (祥云).
  2. Lo dibuja con Chromium (Playwright) a PNG.
  3. Lo difumina un poco y le agrega grano de papel (Pillow).
  4. Guarda assets/imagenes/fondo_templo.jpg (~100-200 KB).

El difuminado va "horneado" en la imagen: en la app no se calcula en vivo
(eso era lo que hacía sentir la app lenta).

Requisitos (solo para este script):  pip install playwright pillow numpy
                                     python -m playwright install chromium
Uso:  python herramientas_arte/templo_del_cielo.py
"""

import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "assets", "imagenes", "fondo_templo.jpg")

ANCHO, ALTO = 1080, 2400
CX = ANCHO / 2

# ── Paleta (colores apagados, como pigmento sobre papel de arroz) ──────────
PAPEL_ARRIBA = "#F8F4EE"     # igual al degradado de la app
PAPEL_ABAJO = "#F2EDE5"
TEJA_OSCURA = "#22405F"      # techos de teja vidriada azul
TEJA_CLARA = "#4A6F96"
TEJA_LINEA = "#6C8FB3"
ROJO_MURO = "#A4452F"
ROJO_COLUMNA = "#7F2F22"
ORO = "#C9A04A"
VERDE_MENSULA = "#3D6B64"    # ménsulas pintadas (dougong) azul-verde
MARMOL = "#EEE9E0"
MARMOL_SOMBRA = "#CFC6B8"
TINTA = "#3B4650"


def f(x):
    return f"{x:.1f}"


# ── Piezas del templo ──────────────────────────────────────────────────────

def techo(y_arriba, mitad_arriba, y_alero, mitad_alero, conico=False):
    """Techo redondo visto de frente: perfil cóncavo y aleros con la punta
    levantada. Si [conico], termina en punta (techo superior)."""
    dy = y_alero - y_arriba
    dx = mitad_alero - mitad_arriba
    levanta = 11            # cuánto sube la punta del alero
    sale = 10               # cuánto sale la punta hacia afuera
    # Control de la curva: sale casi vertical arriba y se aplana en el alero.
    ctrl_x = mitad_arriba + dx * 0.22
    ctrl_y = y_alero - dy * 0.12
    partes = []
    partes.append(f"M {f(CX - mitad_alero - sale)} {f(y_alero - levanta)}")
    partes.append(f"Q {f(CX - mitad_alero + 6)} {f(y_alero + 3)} {f(CX - mitad_alero + 46)} {f(y_alero + 5)}")
    partes.append(f"L {f(CX + mitad_alero - 46)} {f(y_alero + 5)}")
    partes.append(f"Q {f(CX + mitad_alero - 6)} {f(y_alero + 3)} {f(CX + mitad_alero + sale)} {f(y_alero - levanta)}")
    # Lado derecho subiendo (pasa por el borde del alero y sube cóncavo).
    partes.append(f"Q {f(CX + mitad_alero - 8)} {f(y_alero - 8)} {f(CX + mitad_alero - 18)} {f(y_alero - 9)}")
    if conico:
        partes.append(f"Q {f(CX + ctrl_x)} {f(ctrl_y)} {f(CX + 10)} {f(y_arriba + 4)}")
        partes.append(f"Q {f(CX)} {f(y_arriba - 2)} {f(CX - 10)} {f(y_arriba + 4)}")
        partes.append(f"Q {f(CX - ctrl_x)} {f(ctrl_y)} {f(CX - mitad_alero + 18)} {f(y_alero - 9)}")
    else:
        partes.append(f"Q {f(CX + ctrl_x)} {f(ctrl_y)} {f(CX + mitad_arriba)} {f(y_arriba)}")
        partes.append(f"L {f(CX - mitad_arriba)} {f(y_arriba)}")
        partes.append(f"Q {f(CX - ctrl_x)} {f(ctrl_y)} {f(CX - mitad_alero + 18)} {f(y_alero - 9)}")
    partes.append(f"Q {f(CX - mitad_alero + 8)} {f(y_alero - 8)} {f(CX - mitad_alero - sale)} {f(y_alero - levanta)} Z")
    figura = f'<path d="{" ".join(partes)}" fill="url(#teja)"/>'

    # Hileras de tejas: líneas que bajan siguiendo la curva del techo.
    lineas = []
    n = 26
    for i in range(1, n):
        t = i / n * 2 - 1                     # -1 … 1 de izquierda a derecha
        xa = CX + t * (mitad_arriba if not conico else 8)
        xe = CX + t * (mitad_alero - 20)
        xc = CX + t * (mitad_arriba + dx * 0.22 if not conico else ctrl_x)
        ya = y_arriba + (6 if conico else 1)
        ancho = 1.6 if abs(t) < 0.9 else 1.0
        lineas.append(
            f'<path d="M {f(xa)} {f(ya)} Q {f(xc)} {f(ctrl_y)} {f(xe)} {f(y_alero + 2)}" '
            f'stroke="{TEJA_LINEA}" stroke-width="{ancho}" fill="none" opacity="0.45"/>')
    # Borde del alero (línea de tejas finales) y brillo.
    borde = (f'<path d="M {f(CX - mitad_alero + 30)} {f(y_alero + 4)} L {f(CX + mitad_alero - 30)} {f(y_alero + 4)}" '
             f'stroke="#16304A" stroke-width="5" stroke-linecap="round"/>')
    return f'<g clip-path="none">{figura}<g clip-path="url(#c{int(y_alero)})">{"".join(lineas)}</g>{borde}</g>', \
        f'<clipPath id="c{int(y_alero)}"><path d="{" ".join(partes)}"/></clipPath>'


def mensulas(y, mitad):
    """Banda de ménsulas pintadas bajo el alero (azul-verde con oro)."""
    partes = [f'<rect x="{f(CX - mitad)}" y="{f(y)}" width="{f(2 * mitad)}" height="14" fill="{VERDE_MENSULA}"/>']
    n = int(2 * mitad / 16)
    for i in range(n + 1):
        x = CX - mitad + i * (2 * mitad / n)
        partes.append(f'<circle cx="{f(x)}" cy="{f(y + 7)}" r="2.6" fill="{ORO}" opacity="0.85"/>')
    partes.append(f'<rect x="{f(CX - mitad)}" y="{f(y + 14)}" width="{f(2 * mitad)}" height="3" fill="{ORO}" opacity="0.6"/>')
    return "".join(partes)


def muro(y_arriba, y_abajo, mitad, puerta=False):
    """Muro rojo con columnas y celosías."""
    alto = y_abajo - y_arriba
    partes = [f'<rect x="{f(CX - mitad)}" y="{f(y_arriba)}" width="{f(2 * mitad)}" height="{f(alto)}" fill="url(#muro)"/>']
    n = max(6, int(2 * mitad / 34))
    paso = 2 * mitad / n
    for i in range(n + 1):
        x = CX - mitad + i * paso
        partes.append(f'<rect x="{f(x - 4)}" y="{f(y_arriba)}" width="8" height="{f(alto)}" fill="{ROJO_COLUMNA}"/>')
    # Celosías: rejilla fina dorada en cada panel.
    for i in range(n):
        x0 = CX - mitad + i * paso + 8
        x1 = x0 + paso - 16
        for k in range(1, 4):
            xx = x0 + (x1 - x0) * k / 4
            partes.append(f'<line x1="{f(xx)}" y1="{f(y_arriba + 10)}" x2="{f(xx)}" y2="{f(y_abajo - 8)}" stroke="{ORO}" stroke-width="1" opacity="0.45"/>')
        filas = max(2, int(alto / 16))
        for k in range(1, filas):
            yy = y_arriba + 8 + (alto - 16) * k / filas
            partes.append(f'<line x1="{f(x0)}" y1="{f(yy)}" x2="{f(x1)}" y2="{f(yy)}" stroke="{ORO}" stroke-width="1" opacity="0.35"/>')
    if puerta:
        partes.append(f'<rect x="{f(CX - 44)}" y="{f(y_arriba + 14)}" width="88" height="{f(alto - 14)}" fill="#6E261C"/>')
        partes.append(f'<line x1="{f(CX)}" y1="{f(y_arriba + 14)}" x2="{f(CX)}" y2="{f(y_abajo)}" stroke="{ORO}" stroke-width="1.5" opacity="0.7"/>')
        for fila in range(4):
            for col in (-1, 1):
                for j in range(3):
                    partes.append(f'<circle cx="{f(CX + col * (12 + j * 10))}" cy="{f(y_arriba + 30 + fila * (alto - 40) / 4)}" r="1.8" fill="{ORO}"/>')
    # Viga superior pintada.
    partes.append(f'<rect x="{f(CX - mitad)}" y="{f(y_arriba)}" width="{f(2 * mitad)}" height="9" fill="{VERDE_MENSULA}"/>')
    partes.append(f'<rect x="{f(CX - mitad)}" y="{f(y_arriba + 9)}" width="{f(2 * mitad)}" height="2" fill="{ORO}" opacity="0.7"/>')
    # Sombra bajo el alero.
    partes.append(f'<rect x="{f(CX - mitad)}" y="{f(y_arriba)}" width="{f(2 * mitad)}" height="{f(alto)}" fill="url(#sombraMuro)"/>')
    return "".join(partes)


def terraza():
    """Altar de mármol blanco de tres niveles (祈谷坛) con barandales."""
    niveles = [  # (y_arriba, y_abajo, mitad)
        (2118, 2154, 330),
        (2154, 2192, 405),
        (2192, 2234, 480),
    ]
    partes = []
    for y0, y1, m in niveles:
        partes.append(f'<rect x="{f(CX - m)}" y="{y0}" width="{2 * m}" height="{y1 - y0}" fill="url(#marmol)"/>')
        partes.append(f'<rect x="{f(CX - m)}" y="{y1 - 6}" width="{2 * m}" height="6" fill="{MARMOL_SOMBRA}" opacity="0.8"/>')
        # Barandal: pasamanos + balaustres con remate.
        partes.append(f'<rect x="{f(CX - m)}" y="{y0 - 16}" width="{2 * m}" height="3" fill="{MARMOL}" stroke="{MARMOL_SOMBRA}" stroke-width="0.8"/>')
        n = int(2 * m / 22)
        for i in range(n + 1):
            x = CX - m + i * (2 * m / n)
            if abs(x - CX) < 50:
                continue  # hueco de la escalera
            partes.append(f'<rect x="{f(x - 2)}" y="{y0 - 22}" width="4" height="22" fill="{MARMOL}" stroke="{MARMOL_SOMBRA}" stroke-width="0.7"/>')
            partes.append(f'<circle cx="{f(x)}" cy="{y0 - 23}" r="3" fill="{MARMOL}" stroke="{MARMOL_SOMBRA}" stroke-width="0.7"/>')
    # Escalinata central.
    partes.append(f'<path d="M {CX - 44} 2102 L {CX + 44} 2102 L {CX + 60} 2234 L {CX - 60} 2234 Z" fill="#F4F0E8"/>')
    for k in range(14):
        y = 2106 + k * 9.2
        partes.append(f'<line x1="{f(CX - 46 - k * 1.1)}" y1="{f(y)}" x2="{f(CX + 46 + k * 1.1)}" y2="{f(y)}" stroke="{MARMOL_SOMBRA}" stroke-width="1"/>')
    partes.append(f'<rect x="{CX - 8}" y="2102" width="16" height="132" fill="#E6E0D4" opacity="0.9"/>')
    return "".join(partes)


def remate():
    """Pináculo dorado (宝顶) en la punta del techo."""
    return (
        f'<rect x="{CX - 13}" y="1652" width="26" height="14" rx="3" fill="url(#oro)"/>'
        f'<circle cx="{CX}" cy="1634" r="19" fill="url(#oroEsfera)"/>'
        f'<path d="M {CX - 5} 1618 Q {CX} 1560 {CX + 5} 1618 Z" fill="url(#oro)"/>'
        f'<circle cx="{CX}" cy="1586" r="5" fill="{ORO}"/>'
    )


def montanas():
    """Dos capas de montañas a la aguada, que se pierden en la niebla."""
    def cordillera(base, picos, semilla):
        rng = np.random.default_rng(semilla)
        puntos = [(-40, base + 120)]
        x = -40
        while x < ANCHO + 60:
            x += rng.uniform(60, 130)
            altura = rng.uniform(*picos)
            puntos.append((x, base - altura))
        d = f"M -40 {ALTO} L -40 {f(puntos[0][1])} "
        for i in range(1, len(puntos)):
            x0, y0 = puntos[i - 1]
            x1, y1 = puntos[i]
            d += f"Q {f((x0 + x1) / 2)} {f(min(y0, y1) - 25)} {f(x1)} {f(y1)} "
        d += f"L {ANCHO + 60} {ALTO} Z"
        return d
    lejos = cordillera(1740, (20, 120), 7)
    cerca = cordillera(1880, (10, 90), 11)
    return (
        f'<path d="{lejos}" fill="url(#montanaLejos)" filter="url(#aguada)"/>'
        f'<path d="{cerca}" fill="url(#montanaCerca)" filter="url(#aguada)"/>'
    )


def nubes():
    """Nubes auspiciosas (祥云): bancos de nube con remates en espiral."""
    def nube(cx, cy, escala, opacidad):
        s = escala
        cuerpo = []
        for dx, dy, r in [(-70, 8, 34), (-30, -10, 44), (20, -16, 50), (68, -2, 40), (100, 12, 28), (-100, 16, 24)]:
            cuerpo.append(f'<circle cx="{f(cx + dx * s)}" cy="{f(cy + dy * s)}" r="{f(r * s)}"/>')
        base = f'<rect x="{f(cx - 124 * s)}" y="{f(cy + 6 * s)}" width="{f(248 * s)}" height="{f(30 * s)}" rx="{f(15 * s)}"/>'
        espirales = ""
        for ex, ey, r, sentido in [(-30, -10, 22, 1), (20, -16, 26, -1), (68, -2, 18, 1)]:
            x0, y0 = cx + ex * s, cy + ey * s
            rr = r * s
            espirales += (
                f'<path d="M {f(x0 - rr)} {f(y0 + rr * 0.3)} '
                f'A {f(rr)} {f(rr)} 0 1 {1 if sentido > 0 else 0} {f(x0 + rr * 0.6)} {f(y0 - rr * 0.6)} '
                f'A {f(rr * 0.55)} {f(rr * 0.55)} 0 1 {1 if sentido > 0 else 0} {f(x0)} {f(y0 + rr * 0.1)}" '
                f'fill="none" stroke="#B5A998" stroke-width="{f(2.0 * s)}" stroke-linecap="round" opacity="0.6"/>')
        return (f'<g opacity="{opacidad}"><g fill="#FCFAF5" stroke="#C9BFB1" stroke-width="{f(1.8 * s)}">'
                f'{"".join(cuerpo)}{base}</g>'
                f'<g fill="#FCFAF5">{"".join(c.replace("/>", " />") for c in cuerpo)}{base}</g>{espirales}</g>')
    return (
        nube(170, 2230, 1.15, 0.95) + nube(905, 2215, 1.05, 0.95) + nube(540, 2300, 1.5, 0.98)
        + nube(-20, 2330, 1.3, 0.9) + nube(1100, 2340, 1.3, 0.9)
    )


def grullas():
    """Tres grullas lejanas (símbolo de longevidad) cerca del sol."""
    partes = []
    for x, y, s in [(760, 1420, 1.0), (812, 1452, 0.8), (700, 1466, 0.7)]:
        partes.append(
            f'<path d="M {f(x - 22 * s)} {f(y - 4 * s)} Q {f(x - 10 * s)} {f(y - 14 * s)} {f(x)} {f(y)} '
            f'Q {f(x + 12 * s)} {f(y - 16 * s)} {f(x + 26 * s)} {f(y - 8 * s)}" '
            f'fill="none" stroke="{TINTA}" stroke-width="{f(2.6 * s)}" stroke-linecap="round" opacity="0.55"/>')
    return "".join(partes)


def svg():
    defs = []
    techos = []
    # (y_arriba, mitad_arriba, y_alero, mitad_alero, cónico)
    for args in [(1990, 205, 2040, 330, False), (1872, 165, 1924, 272, False), (1668, 0, 1786, 222, True)]:
        dibujo, clip = techo(*args)
        techos.append(dibujo)
        defs.append(clip)
    # Orden: muros de abajo hacia arriba, después techos de abajo hacia arriba
    # (cada techo tapa la base del muro de arriba).
    edificio = (
        muro(2040, 2118, 252, puerta=True) + mensulas(2040, 262) + techos[0]
        + muro(1924, 1990, 200) + mensulas(1924, 210) + techos[1]
        + muro(1786, 1872, 156) + mensulas(1786, 166) + techos[2] + remate()
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{ANCHO}" height="{ALTO}" viewBox="0 0 {ANCHO} {ALTO}">
<defs>
  <linearGradient id="papel" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{PAPEL_ARRIBA}"/><stop offset="1" stop-color="{PAPEL_ABAJO}"/>
  </linearGradient>
  <radialGradient id="sol" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#C9563E" stop-opacity="0.34"/>
    <stop offset="0.8" stop-color="#C9563E" stop-opacity="0.26"/>
    <stop offset="1" stop-color="#C9563E" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="montanaLejos" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#7F8E9C" stop-opacity="0.30"/>
    <stop offset="0.18" stop-color="#7F8E9C" stop-opacity="0.14"/>
    <stop offset="0.35" stop-color="#7F8E9C" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="montanaCerca" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#55657A" stop-opacity="0.30"/>
    <stop offset="0.15" stop-color="#55657A" stop-opacity="0.12"/>
    <stop offset="0.3" stop-color="#55657A" stop-opacity="0"/>
  </linearGradient>
  <filter id="aguada" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.012 0.03" numOctaves="3" seed="4"/>
    <feDisplacementMap in="SourceGraphic" scale="26"/>
    <feGaussianBlur stdDeviation="2.5"/>
  </filter>
  <linearGradient id="teja" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="{TEJA_OSCURA}"/>
    <stop offset="0.38" stop-color="{TEJA_CLARA}"/>
    <stop offset="0.6" stop-color="#3A5D82"/>
    <stop offset="1" stop-color="{TEJA_OSCURA}"/>
  </linearGradient>
  <linearGradient id="muro" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#8C3826"/><stop offset="0.4" stop-color="{ROJO_MURO}"/>
    <stop offset="1" stop-color="#86331F"/>
  </linearGradient>
  <linearGradient id="sombraMuro" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#000" stop-opacity="0.35"/><stop offset="0.45" stop-color="#000" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="marmol" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#E2DCD0"/><stop offset="0.45" stop-color="#F6F2EA"/>
    <stop offset="1" stop-color="#DDD6C9"/>
  </linearGradient>
  <linearGradient id="oro" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#9E7A2E"/><stop offset="0.45" stop-color="#E4C772"/>
    <stop offset="1" stop-color="#A27F33"/>
  </linearGradient>
  <radialGradient id="oroEsfera" cx="0.38" cy="0.35" r="0.7">
    <stop offset="0" stop-color="#F3DD95"/><stop offset="0.6" stop-color="#C9A04A"/>
    <stop offset="1" stop-color="#8A6824"/>
  </radialGradient>
  <linearGradient id="niebla" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{PAPEL_ABAJO}" stop-opacity="0"/>
    <stop offset="1" stop-color="{PAPEL_ABAJO}" stop-opacity="0.85"/>
  </linearGradient>
  {"".join(defs)}
</defs>
<rect width="{ANCHO}" height="{ALTO}" fill="url(#papel)"/>
<circle cx="742" cy="1560" r="150" fill="url(#sol)"/>
{montanas()}
{grullas()}
<rect x="0" y="1980" width="{ANCHO}" height="160" fill="url(#niebla)"/>
<g>{edificio}</g>
{terraza()}
<rect x="0" y="2170" width="{ANCHO}" height="230" fill="url(#niebla)"/>
{nubes()}
</svg>'''


def dibujar(svg_texto):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        navegador = p.chromium.launch()
        pagina = navegador.new_page(viewport={"width": ANCHO, "height": ALTO}, device_scale_factor=1)
        pagina.set_content(f'<html><body style="margin:0">{svg_texto}</body></html>')
        png = pagina.screenshot(full_page=False)
        navegador.close()
    return Image.open(io.BytesIO(png)).convert("RGB")


def acabado(img, radio_difuminado):
    """Difumina un poco y agrega grano de papel (fijo, siempre el mismo)."""
    img = img.filter(ImageFilter.GaussianBlur(radio_difuminado))
    arr = np.asarray(img).astype(np.float32)
    rng = np.random.default_rng(2026)
    grano = rng.normal(0, 2.2, arr.shape[:2])[..., None]
    arr = np.clip(arr + grano, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def main():
    radio = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
    base = dibujar(svg())
    final = acabado(base, radio)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    final.save(SALIDA, "JPEG", quality=84, optimize=True, progressive=True)
    base.save(os.path.splitext(SALIDA)[0] + "_nitido.png") if "--nitido" in sys.argv else None
    print(f"{SALIDA}  {os.path.getsize(SALIDA) / 1024:.0f} KB")


if __name__ == "__main__":
    main()

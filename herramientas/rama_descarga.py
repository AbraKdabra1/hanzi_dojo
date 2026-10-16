# Genera la rama de ciruelo (SVG) de la página de descarga (web/descargar/).
# Uso: python herramientas/rama_descarga.py > rama.svg  y pegarla en index.html.
import math, random, sys

random.seed(8)

def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return (u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
            u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1])

def tangente(p0, p1, p2, p3, t):
    a = bez(p0, p1, p2, p3, max(0, t - 0.01)); b = bez(p0, p1, p2, p3, min(1, t + 0.01))
    return math.atan2(b[1] - a[1], b[0] - a[0])

# Ramas: (puntos de control, grosor al inicio, grosor al final)
ramas = [
    (((-30, 70), (60, 40), (150, 95), (250, 70)), 13, 5),       # principal
    (((250, 70), (300, 58), (340, 30), (385, 22)), 5, 1.6),     # punta
    (((95, 62), (120, 110), (115, 150), (138, 190)), 6, 1.6),   # baja
    (((170, 82), (185, 50), (210, 35), (228, 8)), 4.5, 1.4),    # sube
    (((250, 70), (272, 95), (300, 105), (330, 128)), 4, 1.3),   # cuelga
    (((30, 58), (40, 30), (62, 18), (70, -4)), 5, 1.6),         # izquierda
    (((120, 135), (100, 150), (92, 170), (70, 182)), 2.6, 1.0), # ramita
]

def trazo(r):
    """La rama como una sola figura que se adelgaza (sin uniones visibles)."""
    (p0, p1, p2, p3), g0, g1 = r
    n = 40
    izq, der = [], []
    for i in range(n + 1):
        t = i / n
        x, y = bez(p0, p1, p2, p3, t)
        a = tangente(p0, p1, p2, p3, t)
        g = (g0 + (g1 - g0) * t ** 0.8) / 2 * (1 + 0.08 * math.sin(t * 17 + g0))  # nudos suaves
        nx, ny = -math.sin(a), math.cos(a)
        izq.append((x + nx * g, y + ny * g)); der.append((x - nx * g, y - ny * g))
    pts = izq + der[::-1]
    d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + 'Z'
    fin = bez(p0, p1, p2, p3, 1)
    return f'<path d="{d}"/><circle cx="{fin[0]:.1f}" cy="{fin[1]:.1f}" r="{g1/2:.2f}"/>'

def flor(x, y, r, giro, abierta=True):
    petalos = []
    for k in range(5):
        ang = giro + k * 72
        petalos.append(
            f'<ellipse cx="0" cy="{-r*0.55:.2f}" rx="{r*0.46:.2f}" ry="{r*0.56:.2f}" transform="rotate({ang:.0f})" fill="url(#petalo)"/>')
    estambres = []
    for k in range(9):
        ang = math.radians(giro + k * 40)
        rr = r * (0.32 + 0.08 * (k % 2))
        estambres.append(f'<circle cx="{math.cos(ang)*rr:.2f}" cy="{math.sin(ang)*rr:.2f}" r="{r*0.07:.2f}" fill="#E7C45A"/>')
    return (f'<g transform="translate({x:.1f} {y:.1f})">' + ''.join(petalos) +
            f'<circle r="{r*0.2:.2f}" fill="#8E1830"/>' + ''.join(estambres) +
            f'<circle r="{r*0.09:.2f}" fill="#3A1D14"/></g>')

def boton(x, y, r):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="url(#boton)"/>'

flores, botones = [], []
for idx, r in enumerate(ramas):
    (p0, p1, p2, p3), g0, g1 = r
    cuantas = {0: 6, 1: 3, 2: 3, 3: 2, 4: 3, 5: 2, 6: 1}[idx]
    for j in range(cuantas):
        t = 0.15 + 0.8 * (j + random.random() * 0.6) / cuantas
        x, y = bez(p0, p1, p2, p3, min(t, 0.98))
        ang = tangente(p0, p1, p2, p3, t) + (math.pi / 2) * random.choice([-1, 1])
        d = (g0 + (g1 - g0) * t) / 2 + random.uniform(2, 6)
        x += math.cos(ang) * d; y += math.sin(ang) * d
        tam = random.uniform(8, 12.5) * (0.85 if idx else 1)
        flores.append(flor(x, y, tam, random.uniform(0, 72)))
    for j in range(2 if idx < 5 else 1):
        t = random.uniform(0.3, 1.0)
        x, y = bez(p0, p1, p2, p3, t)
        ang = tangente(p0, p1, p2, p3, t) - math.pi / 2
        x += math.cos(ang) * 4; y += math.sin(ang) * 4
        botones.append(boton(x, y, random.uniform(2.6, 3.8)))

svg = f'''<svg class="rama" viewBox="0 0 400 210" aria-hidden="true" focusable="false">
<defs>
<radialGradient id="petalo" cx="50%" cy="85%" r="80%"><stop offset="0" stop-color="#C92F49"/><stop offset=".55" stop-color="#E7798A"/><stop offset="1" stop-color="#F2A2AE"/></radialGradient>
<radialGradient id="boton" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="#CF4A60"/><stop offset="1" stop-color="#8E1830"/></radialGradient>
<linearGradient id="tinta" x1="0" y1="0" x2="1" y2="0"><stop offset="0" class="tinta1"/><stop offset="1" class="tinta2"/></linearGradient>
</defs>
<g class="tronco" fill="url(#tinta)">{''.join(trazo(r) for r in ramas)}</g>
{''.join(botones)}{''.join(flores)}
</svg>'''
sys.stdout.write(svg)

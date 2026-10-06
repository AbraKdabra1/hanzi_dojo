"""
generar_icono.py
────────────────
Dibuja el ícono de la app a partir de los trazos de Make Me a Hanzi (los
mismos contornos de pincel que se usan para escribir en la app):

    字 en tinta sobre papel de arroz, con un sello rojo (印章) con 汉.

Genera:
  android/app/src/main/res/mipmap-*/ic_launcher.png        ícono clásico (cuadrado redondeado)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png   capa del ícono adaptable
  android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png   ícono temático (Android 13+)
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  android/app/src/main/res/values/ic_launcher_fondo.xml
  fastlane/metadata/android/es-MX/images/icon.png (512 × 512, tiendas)
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png       íconos de iPhone/iPad (sin transparencia)
  ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png     字 de la pantalla de arranque (claro y oscuro)
  web/favicon.png, web/icons/*.png                          versión web: pestaña, "Agregar a inicio" y arranque

Requiere Pillow:  pip install pillow
Uso:  python herramientas_datos/generar_icono.py
"""

import json
import os
import re
import sqlite3

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(RAIZ, "assets", "db", "contenido.db")
RES = os.path.join(RAIZ, "android", "app", "src", "main", "res")
TIENDA = os.path.join(RAIZ, "fastlane", "metadata", "android", "es-MX", "images", "icon.png")
IOS_ICONO = os.path.join(RAIZ, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
IOS_ARRANQUE = os.path.join(RAIZ, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
WEB = os.path.join(RAIZ, "web")

PAPEL = (246, 240, 230, 255)
PAPEL_SOMBRA = (233, 224, 210, 255)
TINTA = (24, 22, 20, 255)
SELLO = (190, 38, 38, 255)
DENSIDADES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# La capa adaptable mide 108 dp; el sistema la recorta a una forma de ~72 dp.
ADAPTABLE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def trazos(caracter):
    con = sqlite3.connect(DB)
    fila = con.execute("SELECT trazos_svg FROM caracteres WHERE caracter = ?", (caracter,)).fetchone()
    return json.loads(fila[0])


def poligonos(ruta, pasos=12):
    """Contorno SVG de Make Me a Hanzi (M, L, Q, C, Z) → listas de puntos."""
    fichas = re.findall(r"[MLQCZ]|-?\d+(?:\.\d+)?", ruta)
    i, actual, salida, punto = 0, [], [], (0.0, 0.0)

    def num():
        nonlocal i
        v = float(fichas[i])
        i += 1
        return v

    while i < len(fichas):
        cmd = fichas[i]
        i += 1
        if cmd == "M":
            if actual:
                salida.append(actual)
            punto = (num(), num())
            actual = [punto]
        elif cmd == "L":
            punto = (num(), num())
            actual.append(punto)
        elif cmd == "Q":
            c1, p = (num(), num()), (num(), num())
            for k in range(1, pasos + 1):
                t = k / pasos
                x = (1 - t) ** 2 * punto[0] + 2 * (1 - t) * t * c1[0] + t * t * p[0]
                y = (1 - t) ** 2 * punto[1] + 2 * (1 - t) * t * c1[1] + t * t * p[1]
                actual.append((x, y))
            punto = p
        elif cmd == "C":
            c1, c2, p = (num(), num()), (num(), num()), (num(), num())
            for k in range(1, pasos + 1):
                t = k / pasos
                a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
                actual.append((a * punto[0] + b * c1[0] + c * c2[0] + d * p[0],
                               a * punto[1] + b * c1[1] + c * c2[1] + d * p[1]))
            punto = p
        elif cmd == "Z":
            if actual:
                salida.append(actual)
            actual = []
    if actual:
        salida.append(actual)
    return salida


def dibujar_caracter(dibujo, caracter, x0, y0, lado, color):
    """Dibuja el carácter en el cuadrado (x0, y0, lado). Make Me a Hanzi usa
    1024 × 1024 con el eje y hacia arriba y la línea base en y = 900."""
    escala = lado / 1024
    for ruta in trazos(caracter):
        for pol in poligonos(ruta):
            puntos = [(x0 + x * escala, y0 + (900 - y) * escala) for x, y in pol]
            if len(puntos) >= 3:
                dibujo.polygon(puntos, fill=color)


def capa_frente(lado, monocromo=False, tinta_propia=None):
    """Capa del ícono adaptable (lado = 108 dp). Todo cabe en el círculo
    seguro de 66 dp del centro (los teléfonos recortan en círculo, gota,
    cuadrado redondeado…)."""
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tinta = tinta_propia or ((255, 255, 255, 255) if monocromo else TINTA)
    zona = lado * 66 / 108
    centro = lado / 2
    lado_caracter = zona * 0.72
    cx, cy = centro - zona * 0.05, centro - zona * 0.04
    dibujar_caracter(d, "字", cx - lado_caracter / 2, cy - lado_caracter / 2, lado_caracter, tinta)
    if not monocromo:
        s = zona * 0.22
        sx = sy = centro + zona * 0.23 - s / 2
        d.rounded_rectangle([sx, sy, sx + s, sy + s], radius=s * 0.12, fill=SELLO)
        dibujar_caracter(d, "汉", sx + s * 0.12, sy + s * 0.10, s * 0.76, PAPEL)
    return img


def fondo(lado):
    """Papel de arroz: degradado suave y una mancha de tinta muy tenue."""
    img = Image.new("RGBA", (lado, lado), PAPEL)
    d = ImageDraw.Draw(img)
    for k in range(lado):
        t = k / lado
        c = tuple(int(PAPEL[j] * (1 - t * 0.5) + PAPEL_SOMBRA[j] * t * 0.5) for j in range(3)) + (255,)
        d.line([(0, k), (lado, k)], fill=c)
    mancha = Image.new("L", (lado, lado), 0)
    ImageDraw.Draw(mancha).ellipse([lado * 0.45, lado * 0.5, lado * 1.25, lado * 1.3], fill=26)
    mancha = mancha.filter(ImageFilter.GaussianBlur(lado / 10))
    tono = Image.new("RGBA", (lado, lado), (60, 40, 20, 255))
    img = Image.composite(tono, img, mancha)
    return img


def legado(lado):
    """Ícono clásico: cuadrado redondeado con papel, 字 y sello."""
    grande = lado * 4
    base = fondo(grande)
    frente = capa_frente(int(grande * 108 / 70))
    desplaza = (frente.width - grande) // 2
    base.alpha_composite(frente.crop((desplaza, desplaza, desplaza + grande, desplaza + grande)))
    mascara = Image.new("L", (grande, grande), 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, grande - 1, grande - 1], radius=grande * 0.22, fill=255)
    base.putalpha(mascara)
    return base.resize((lado, lado), Image.LANCZOS)


def cuadrado(lado):
    """Cuadrado completo sin esquinas redondeadas (tiendas e iOS: cada
    sistema aplica su propia forma)."""
    grande = fondo(2048)
    frente = capa_frente(int(2048 * 108 / 70))
    d = (frente.width - 2048) // 2
    grande.alpha_composite(frente.crop((d, d, d + 2048, d + 2048)))
    return grande.resize((lado, lado), Image.LANCZOS)


def iconos_ios():
    """Llena AppIcon.appiconset según su Contents.json. Apple no acepta
    transparencia en el ícono: se guarda en RGB."""
    with open(os.path.join(IOS_ICONO, "Contents.json"), encoding="utf-8") as f:
        imagenes = json.load(f)["images"]
    base = cuadrado(1024).convert("RGB")
    hechos = set()
    for im in imagenes:
        nombre = im.get("filename")
        if not nombre or nombre in hechos:
            continue
        puntos = float(im["size"].split("x")[0])
        lado = round(puntos * float(im["scale"].rstrip("x")))
        guardar(base.resize((lado, lado), Image.LANCZOS), os.path.join(IOS_ICONO, nombre))
        hechos.add(nombre)


def arranque_ios():
    """字 con su sello, sin fondo, para el centro de la pantalla de arranque
    (120 pt). En modo oscuro el carácter va en color papel."""
    for sufijo, tinta in (("", TINTA), ("-oscuro", (240, 232, 218, 255))):
        frente = capa_frente(120 * 3 * 108 // 66, tinta_propia=tinta)
        d = (frente.width - 360) // 2
        img = frente.crop((d, d, d + 360, d + 360))
        for escala in (1, 2, 3):
            nombre = f"LaunchImage{sufijo}{'' if escala == 1 else f'@{escala}x'}.png"
            guardar(img.resize((120 * escala, 120 * escala), Image.LANCZOS), os.path.join(IOS_ARRANQUE, nombre))


def arranque(tinta):
    """字 con su sello, sin fondo, 360 × 360 (pantalla de arranque)."""
    frente = capa_frente(360 * 108 // 66, tinta_propia=tinta)
    d = (frente.width - 360) // 2
    return frente.crop((d, d, d + 360, d + 360))


def iconos_web():
    """Versión web (PWA). "maskable": a todo color hasta el borde, con el
    dibujo dentro del círculo seguro (Android lo recorta a su forma).
    apple-touch-icon sin transparencia (iPhone pone sus propias esquinas)."""
    iconos = os.path.join(WEB, "icons")
    guardar(legado(64), os.path.join(WEB, "favicon.png"))
    for lado in (192, 512):
        guardar(legado(lado), os.path.join(iconos, f"Icon-{lado}.png"))
        # El círculo seguro de capa_frente (66 de 108) queda en el 78 % del
        # ícono: dentro del 80 % que garantiza "maskable".
        grande = fondo(lado * 4)
        frente = capa_frente(lado * 4 * 108 // 85)
        d = (frente.width - lado * 4) // 2
        grande.alpha_composite(frente.crop((d, d, d + lado * 4, d + lado * 4)))
        guardar(grande.resize((lado, lado), Image.LANCZOS), os.path.join(iconos, f"Icon-maskable-{lado}.png"))
    guardar(cuadrado(180).convert("RGB"), os.path.join(iconos, "apple-touch-icon.png"))
    guardar(arranque(TINTA).resize((240, 240), Image.LANCZOS), os.path.join(iconos, "arranque.png"))
    guardar(arranque((240, 232, 218, 255)).resize((240, 240), Image.LANCZOS),
            os.path.join(iconos, "arranque-oscuro.png"))


def guardar(img, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    img.save(ruta, optimize=True)


def main():
    for nombre, lado in DENSIDADES.items():
        carpeta = os.path.join(RES, f"mipmap-{nombre}")
        guardar(legado(lado), os.path.join(carpeta, "ic_launcher.png"))
    for nombre, lado in ADAPTABLE.items():
        carpeta = os.path.join(RES, f"mipmap-{nombre}")
        guardar(capa_frente(lado * 4).resize((lado, lado), Image.LANCZOS),
                os.path.join(carpeta, "ic_launcher_foreground.png"))
        guardar(capa_frente(lado * 4, monocromo=True).resize((lado, lado), Image.LANCZOS),
                os.path.join(carpeta, "ic_launcher_monochrome.png"))
        guardar(fondo(lado), os.path.join(carpeta, "ic_launcher_background.png"))
    os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
    with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                "<!-- Generado por herramientas_datos/generar_icono.py -->\n"
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
                "</adaptive-icon>\n")
    # Tiendas: 512 × 512 cuadrado completo (cada tienda aplica su propia forma).
    guardar(cuadrado(512), TIENDA)
    iconos_ios()
    arranque_ios()
    iconos_web()
    print("Ícono generado.")


if __name__ == "__main__":
    main()

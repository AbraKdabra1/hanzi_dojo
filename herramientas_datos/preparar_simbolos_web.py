"""
preparar_simbolos_web.py
────────────────────────
Fuentes con los emoji y símbolos de la interfaz (🔥 🎯 📚 ✓ ↺ …) para la
versión web.

En Android e iOS esos caracteres los dibuja la fuente del sistema. En el
navegador, Flutter los pediría a Google Fonts (fonts.gstatic.com) la primera
vez que aparecen: sin internet se verían como cuadros y, con internet, el
navegador avisaría a Google. Así que se recortan de Noto Color Emoji y Noto
Sans Math solo los que usa la app (unos KB) y viajan con ella.

Qué se conserva: cada carácter de lib/**/*.dart (fuera de comentarios) que no
esté en NotoSansSC-Regular.ttf.

Genera:
  assets/fonts/simbolos/SimbolosHanzi<N>.ttf   (una por archivo de origen)
  lib/simbolos_web.dart                        (la lista de familias, para el tema)
y muestra el bloque que va en pubspec.yaml.

Requisitos (solo para correr este script):
    pip install fonttools
    npm pack @fontsource/noto-color-emoji @fontsource/noto-sans-math
    (y descomprimir cada .tgz en su propia carpeta)
Uso:
    python herramientas_datos/preparar_simbolos_web.py carpeta_emoji/package carpeta_math/package
"""

import glob
import os
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE_APP = os.path.join(RAIZ, "assets", "fonts", "NotoSansSC-Regular.ttf")
SALIDA = os.path.join(RAIZ, "assets", "fonts", "simbolos")
DART = os.path.join(RAIZ, "lib", "simbolos_web.dart")
# Selector de variante (️) y unión (ZWJ): van con los emoji que los usan.
INVISIBLES = {0xFE0F, 0x200D}


def caracteres_de_la_interfaz():
    usados = set()
    for ruta in glob.glob(os.path.join(RAIZ, "lib", "**", "*.dart"), recursive=True):
        with open(ruta, encoding="utf-8") as f:
            for linea in f:
                if re.match(r"\s*//", linea):
                    continue
                usados.update(ord(c) for c in linea if ord(c) > 0x7F)
    tiene = TTFont(FUENTE_APP).getBestCmap()
    # Las expresiones regulares de importar_libro.dart nombran capítulos (楔子…):
    # son texto de libros, no de la interfaz.
    return {c for c in usados if c not in tiene and not (0x3400 <= c <= 0x9FFF)}


def main(carpetas):
    faltan = caracteres_de_la_interfaz()
    origenes = []
    for carpeta in carpetas:
        origenes += sorted(glob.glob(os.path.join(carpeta, "files", "*-400-normal.woff")))
    reparto = {}
    for ruta in origenes:
        mapa = TTFont(ruta).getBestCmap()
        propios = {c for c in faltan if c in mapa and c not in INVISIBLES}
        if propios:
            reparto[ruta] = propios | {c for c in INVISIBLES if c in mapa}
            faltan -= propios
    sin_fuente = faltan - INVISIBLES
    if sin_fuente:
        print("Sin fuente para:", " ".join(f"{chr(c)} U+{c:04X}" for c in sorted(sin_fuente)))

    os.makedirs(SALIDA, exist_ok=True)
    for viejo in glob.glob(os.path.join(SALIDA, "*.ttf")):
        os.remove(viejo)
    familias = []
    for n, (ruta, cps) in enumerate(reparto.items()):
        opciones = subset.Options()
        opciones.layout_features = ["*"]
        opciones.name_IDs = ["*"]
        opciones.flavor = None
        fuente = TTFont(ruta)
        recorte = subset.Subsetter(opciones)
        recorte.populate(unicodes=cps)
        recorte.subset(fuente)
        if "SVG " in fuente and "COLR" in fuente:
            del fuente["SVG "]  # con COLR basta
        familia = f"SimbolosHanzi{n}"
        destino = os.path.join(SALIDA, f"{familia}.ttf")
        fuente.save(destino)
        familias.append(familia)
        print(f"{familia}: {os.path.getsize(destino) // 1024} KB  "
              f"{''.join(chr(c) for c in sorted(cps - INVISIBLES))}  ← {os.path.basename(ruta)}")

    with open(DART, "w", encoding="utf-8") as f:
        f.write("// Generado por herramientas_datos/preparar_simbolos_web.py: no editar a mano.\n"
                "//\n"
                "// Emoji y símbolos de la interfaz para la versión web (en el teléfono los\n"
                "// dibuja la fuente del sistema). Ver tema.dart.\n\n"
                "const familiasSimbolosWeb = [\n")
        f.writelines(f"  '{fam}',\n" for fam in familias)
        f.write("];\n")
    print("\npubspec.yaml (en flutter: fonts:):")
    for fam in familias:
        print(f"    - family: {fam}\n      fonts:\n        - asset: assets/fonts/simbolos/{fam}.ttf")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])

"""
recortar_fuente.py
──────────────────
Genera las fuentes Noto Sans SC que usa la app, recortadas a los caracteres
que realmente se muestran. La fuente completa pesa 17.8 MB; recortada, unos
pocos MB por peso.

Qué caracteres se conservan:
    - latín básico y extendido (español, pinyin con tonos, signos)
    - todos los caracteres HSK 3.0 y todas las formas de radical
    - todos los caracteres que aparecen en las oraciones de ejemplo
Si la app muestra un carácter que no está aquí (p. ej. uno raro en una
búsqueda), Flutter usa automáticamente la fuente china del teléfono.

Pesos generados: 400 (Regular), 500 (Medium) y 700 (Bold).
Flutter elige el más cercano para los demás pesos (w300 → 400, w600 → 700).

Requisitos (solo para correr este script, no para la app):
    pip install fonttools brotli
Uso:
    python herramientas_datos/recortar_fuente.py ruta/a/NotoSansSC[wght].ttf
La fuente variable se descarga de:
    https://github.com/google/fonts/tree/main/ofl/notosanssc
"""

import os
import sqlite3
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(RAIZ, "assets", "db", "contenido.db")
SALIDA = os.path.join(RAIZ, "assets", "fonts")
PESOS = {"Regular": 400, "Medium": 500, "Bold": 700}

# Rangos latinos: ASCII, Latin-1, Latin Extended-A/B (ǎ ǐ ǒ ǔ ǖ ǘ ǚ ǜ),
# diacríticos combinantes, puntuación general y símbolos comunes.
RANGOS = [(0x20, 0x7E), (0xA0, 0xFF), (0x100, 0x24F), (0x300, 0x36F),
          (0x1E00, 0x1EFF), (0x2000, 0x206F), (0x20A0, 0x20BF), (0x2190, 0x21FF),
          (0x3000, 0x303F), (0xFF00, 0xFFEF)]


def caracteres_necesarios():
    texto = set()
    for inicio, fin in RANGOS:
        texto.update(chr(c) for c in range(inicio, fin + 1))
    con = sqlite3.connect(DB)
    for (c,) in con.execute("SELECT caracter FROM caracteres WHERE nivel_hsk > 0 OR es_forma_radical = 1"):
        texto.add(c)
    for forma, variantes in con.execute("SELECT forma_principal, variantes FROM radicales"):
        texto.update(forma + variantes.replace(" ", ""))
    for (chino,) in con.execute("SELECT chino FROM ejemplos"):
        texto.update(chino)
    # Texto de la interfaz y significados (por si algún signo no está en los rangos).
    for (s,) in con.execute("SELECT significado_es FROM caracteres WHERE significado_es IS NOT NULL"):
        texto.update(s)
    for (s,) in con.execute("SELECT nombre_es FROM radicales"):
        texto.update(s)
    con.close()
    return texto


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    variable = sys.argv[1]
    texto = caracteres_necesarios()
    print(f"{len(texto)} caracteres a conservar")
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, peso in PESOS.items():
        fuente = instancer.instantiateVariableFont(TTFont(variable), {"wght": peso})
        opciones = subset.Options()
        opciones.layout_features = ["*"]
        opciones.name_IDs = ["*"]
        opciones.notdef_outline = True
        recortador = subset.Subsetter(options=opciones)
        recortador.populate(text="".join(sorted(texto)))
        recortador.subset(fuente)
        destino = os.path.join(SALIDA, f"NotoSansSC-{nombre}.ttf")
        fuente.save(destino)
        print(f"  {destino}  {os.path.getsize(destino) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()

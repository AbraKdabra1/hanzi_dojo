"""
preparar_libros.py
──────────────────
Agrega el pinyin a los libros de la sección «Leer» y muestra qué tan
difícil es cada uno. Hay que correrlo cada vez que se edita un libro
(validar_db.py avisa si se te olvidó).

Uso (desde la raíz del proyecto):
    pip install pypinyin
    python herramientas_datos/preparar_libros.py
    python herramientas_datos/construir_db.py
    python herramientas_datos/validar_db.py

Escribe herramientas_datos/fuentes/libros/libros_generado.json con, para cada
libro, su huella (para saber si cambió) y el pinyin de cada carácter de cada
párrafo, título y palabra del vocabulario.

Cómo se decide el pinyin de cada carácter (en este orden):
    1. pypinyin, usando las palabras alrededor (长 = "zhǎng" en 长大 y
       "cháng" en 很长).
    2. Si el carácter es parte de una palabra de la lista oficial HSK con
       una sola lectura, manda la lectura oficial (así salen los tonos
       neutros: 爸爸 bàba, 朋友 péngyou, 东西 dōngxi).
    3. Partículas 得/地 según el contexto (高兴地说 = de, 地上 = dì), con las
       mismas reglas que las oraciones de ejemplo.
    4. Cambios de tono de 一 y 不, como se pronuncian y como los marcan los
       libros de texto: 一个 yí ge, 一点 yì diǎn, 不是 bú shì, 看一看 kàn yi kàn.
    5. Las correcciones a mano del libro: 长[zhǎng].
"""

import json
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import libros as L  # noqa: E402
from construir_db import leer_cedict, partir_pinyin, silabas_validas  # noqa: E402
from pinyin_util import num_a_acentos  # noqa: E402
from seleccionar_ejemplos import _lectura_particula, cargar_pinyin_hsk  # noqa: E402

try:
    from pypinyin import Style, pinyin
except ImportError:
    sys.exit("Falta pypinyin:  pip install pypinyin")

DB = os.path.join(L.RAIZ, "assets", "db", "contenido.db")


_VALIDAS = None
_HSK = None
_NUMEROS = set("零一二三四五六七八九十百千万两几第")


def _hsk():
    """Palabra HSK (2-4 caracteres) → sílabas con acento, una por carácter."""
    global _VALIDAS, _HSK
    if _HSK is None:
        _VALIDAS = silabas_validas(leer_cedict())
        _HSK = {}
        for palabra, py in cargar_pinyin_hsk().items():
            if 2 <= len(palabra) <= 4:
                silabas = partir_pinyin(py, len(palabra), _VALIDAS)
                if silabas:
                    _HSK[palabra] = [_acentos(x) for x in silabas]
    return _HSK


def _acentos(silaba_num):
    """'ba5' → 'ba', 'hao3' → 'hǎo', 'r5' → 'r'."""
    if silaba_num.endswith("5"):
        return silaba_num[:-1]
    return num_a_acentos(silaba_num)


def _tono(silaba):
    for c in silaba:
        for tono, letras in ((1, "āēīōūǖ"), (2, "áéíóúǘ"), (3, "ǎěǐǒǔǚ"), (4, "àèìòùǜ")):
            if c in letras:
                return tono
    return 5


def _sandhi(texto, salida):
    """Cambios de tono de 一 y 不 (sobre la lectura ya decidida)."""
    for k, c in enumerate(texto):
        if c not in "一不" or not salida[k]:
            continue
        antes = texto[k - 1] if k > 0 else ""
        despues = texto[k + 1] if k + 1 < len(texto) else ""
        sig = salida[k + 1] if k + 1 < len(texto) else ""
        # 看一看, 是不是 (pero no 一点一点 ni 一块一块: ahí cada 一 es un número)
        antes2 = texto[k - 2] if k > 1 else ""
        if antes and antes == despues and L.es_han(antes) and antes2 != c:
            salida[k] = "yi" if c == "一" else "bu"
            continue
        if c == "不":
            if salida[k] == "bu":                         # 对不起: neutro, se queda
                continue
            salida[k] = "bú" if sig and _tono(sig) == 4 else "bù"
            continue
        # 一: número suelto, en cifras, ordinal o fechas → yī
        if (not sig or antes in _NUMEROS or despues in _NUMEROS or despues in "月号"):
            salida[k] = "yī"
        else:
            salida[k] = "yí" if _tono(sig) in (4, 5) else "yì"


def pinyin_de(texto, lecturas=None):
    """Una sílaba por carácter de [texto] ('' para lo que no es chino)."""
    salida = [""] * len(texto)
    hsk = _hsk()
    # 1. pypinyin por tramos de caracteres chinos (con su contexto).
    i = 0
    while i < len(texto):
        if not L.es_han(texto[i]):
            i += 1
            continue
        j = i
        while j < len(texto) and L.es_han(texto[j]):
            j += 1
        for k, silabas in enumerate(pinyin(texto[i:j], style=Style.TONE, heteronym=False)):
            salida[i + k] = silabas[0]
        i = j
    # 2. Palabras HSK (la más larga primero).
    en_palabra = set()
    i = 0
    while i < len(texto):
        for largo in (4, 3, 2):
            palabra = texto[i:i + largo]
            if len(palabra) == largo and palabra in hsk:
                salida[i:i + largo] = hsk[palabra]
                en_palabra.update(range(i, i + largo))
                i += largo
                break
        else:
            i += 1
    # 3. Partículas 得 / 地 sueltas.
    for k, c in enumerate(texto):
        if c in "得地" and k not in en_palabra:
            antes = texto[k - 1] if k > 0 else ""
            despues = texto[k + 1] if k + 1 < len(texto) else ""
            salida[k] = _lectura_particula(c, antes, despues)
    # 4. 一 y 不.
    _sandhi(texto, salida)
    # 5. Correcciones a mano.
    for k, lectura in (lecturas or {}).items():
        salida[int(k)] = lectura
    return salida


def main():
    libros = L.todos_los_libros()
    con = sqlite3.connect(DB)
    nivel_de = dict(con.execute("SELECT caracter, nivel_hsk FROM caracteres"))
    existentes = set(nivel_de)

    generado = {}
    for libro in libros:
        capitulos = []
        for cap in libro["capitulos"]:
            capitulos.append({
                "titulo": pinyin_de(cap["titulo"]),
                "palabras": [pinyin_de(p["chino"]) for p in cap["palabras"]],
                "parrafos": [pinyin_de(p["chino"], p["lecturas"]) for p in cap["parrafos"]],
            })
        generado[libro["clave"]] = {
            "huella": libro["huella"],
            "titulo": pinyin_de(libro["titulo"]),
            "capitulos": capitulos,
        }

        # ── Informe de dificultad ──
        fraccion, arriba = L.cobertura(libro, nivel_de)
        contables = [c for c, _ in L.caracteres_contables(libro)]
        total, distintos = len(contables), len(set(contables))
        nivel = "7-9" if libro["nivel"] == 7 else libro["nivel"]
        marca = "✓" if libro["tipo"] == "original" or fraccion >= L.COBERTURA_MINIMA else "✗"
        print(f"{marca} HSK {nivel}  {libro['titulo']} ({libro['tipo']}): "
              f"{total} caracteres, {distintos} distintos, {fraccion:.1%} de tu nivel o menor")
        if arriba:
            lista = ", ".join(f"{c}{'·' + str(nivel_de.get(c, 0) or '–')}×{n}"
                              for c, n in arriba.most_common(25))
            print(f"    por encima del nivel (carácter·nivel×veces): {lista}")
        faltan = sorted({c for cap in libro["capitulos"] for p in cap["parrafos"]
                         for c in p["chino"] if L.es_han(c) and c not in existentes})
        if faltan:
            print(f"    ⚠ no están en la base (no se podrán consultar): {''.join(faltan)}")

    with open(L.GENERADO, "w", encoding="utf-8") as f:
        json.dump(generado, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"→ {os.path.relpath(L.GENERADO, L.RAIZ)}")


if __name__ == "__main__":
    main()

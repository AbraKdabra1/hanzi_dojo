"""
seleccionar_ejemplos.py
───────────────────────
Elige oraciones de ejemplo para cada carácter HSK (2 en los niveles 1-6,
1 en 7-9), tomadas de fuentes/oraciones/cmn_sen_db_2.tsv (Tatoeba).

Criterios (en orden):
  1. Que el alumno pueda leerla: todos los demás caracteres de la oración son
     de su mismo nivel HSK o de uno más bajo. Si no hay, se permite un nivel
     más; si tampoco, cualquier oración.
  2. Que sea corta (4 a 14 caracteres), sin letras latinas ni números. Si un
     carácter no tiene ninguna así, se acepta una de hasta 24 caracteres.
  3. Reutilizar oraciones: si una oración ya se eligió para otro carácter y
     también sirve para este, se prefiere (así hay menos que traducir).
  4. Nunca usar las de fuentes/traducciones/ejemplos_excluidos.tsv (erratas,
     frases confusas o temas poco adecuados, revisadas a mano).

Pinyin: el del corpus es automático y trae errores (很好 = "hěn hào"). Se
regenera así: las palabras que están en la lista oficial HSK usan el pinyin
oficial (喜欢 = xǐhuan); el resto, pypinyin con su segmentador de palabras.

Salidas (en fuentes/traducciones/):
  ejemplos_seleccion.tsv     caracter · orden · id_oracion
  ejemplos_pinyin.tsv        id_oracion · pinyin (regenerado)
  ejemplos_por_traducir.tsv  id_oracion · chino · inglés  (las que aún no tienen español)

Entradas escritas a mano (en fuentes/traducciones/):
  ejemplos_es.tsv            id_oracion · español
  ejemplos_excluidos.tsv     id_oracion · motivo

Requisitos (solo para este script):  pip install pypinyin
Uso:  python herramientas_datos/seleccionar_ejemplos.py
"""

import csv
import os
import re
from collections import defaultdict

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTES = os.path.join(RAIZ, "herramientas_datos", "fuentes")
HSK = os.path.join(FUENTES, "hsk30", "hsk30-chars.csv")
HSK_PALABRAS = os.path.join(FUENTES, "hsk30", "hsk30.csv")
ORACIONES = os.path.join(FUENTES, "oraciones", "cmn_sen_db_2.tsv")
SALIDA = os.path.join(FUENTES, "traducciones")

HAN = re.compile("[㐀-鿿]")
SOLO_HAN = re.compile("[㐀-鿿]+")
PUNTUACION = str.maketrans({
    "，": ",", "。": ".", "？": "?", "！": "!", "：": ":", "；": ";", "、": ",",
    "“": '"', "”": '"', "‘": "'", "’": "'", "（": "(", "）": ")", "《": "«", "》": "»",
})


LARGO_NORMAL = 14    # caracteres chinos por oración, lo normal
LARGO_MAXIMO = 24    # solo si el carácter no tiene ninguna oración corta


def ejemplos_para(nivel):
    """Cuántos ejemplos se buscan para un carácter de ese nivel."""
    return 2 if nivel <= 6 else 1


def cargar_pinyin_hsk():
    """Palabra HSK → pinyin oficial (solo palabras con una única lectura)."""
    lecturas = defaultdict(set)
    with open(HSK_PALABRAS, encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            palabras = fila["Simplified"].split("|")
            pinyins = fila["Pinyin"].split("|")
            if len(palabras) != len(pinyins):
                continue
            for palabra, py in zip(palabras, pinyins):
                palabra = re.sub(r"[（(].*?[)）]|\d|…", "", palabra).strip()
                py = re.split(r"[\s(（/]", py.strip())[0]
                if palabra and SOLO_HAN.fullmatch(palabra) and py:
                    lecturas[palabra].add(py)
    return {palabra: next(iter(p)) for palabra, p in lecturas.items() if len(p) == 1}


def generar_pinyin(texto, pinyin_hsk):
    """Pinyin por palabras: primero palabras HSK (la más larga), luego pypinyin."""
    from pypinyin import Style, pinyin
    from pypinyin.seg.mmseg import seg

    def por_pypinyin(fragmento):
        partes = []
        for palabra in seg.cut(fragmento):
            if HAN.search(palabra):
                partes.append("".join(s[0] for s in pinyin(palabra, style=Style.TONE, heteronym=False)))
            elif palabra.strip():
                partes.append(palabra.strip().translate(PUNTUACION))
        return partes

    salida, pendiente, i = [], "", 0
    while i < len(texto):
        encontrada = None
        for largo in (4, 3, 2):  # palabras de 2+ caracteres; los sueltos los resuelve pypinyin en contexto
            candidato = texto[i:i + largo]
            if len(candidato) == largo and candidato in pinyin_hsk:
                encontrada = candidato
                break
        if encontrada:
            if pendiente:
                salida += por_pypinyin(pendiente)
                pendiente = ""
            salida.append(pinyin_hsk[encontrada])
            i += len(encontrada)
        else:
            pendiente += texto[i]
            i += 1
    if pendiente:
        salida += por_pypinyin(pendiente)
    frase = " ".join(salida)
    frase = re.sub(r"\s+([,.!?:;…)\"»])", r"\1", frase)
    return re.sub(r"\s+", " ", frase).strip()


def main():
    niveles, orden_hsk = {}, []
    with open(HSK, encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            niveles[fila["Hanzi"]] = 7 if fila["Level"] == "7-9" else int(fila["Level"])
            orden_hsk.append(fila["Hanzi"])
    posicion = {c: i for i, c in enumerate(orden_hsk)}

    excluidas = set()
    ruta_excluidas = os.path.join(SALIDA, "ejemplos_excluidos.tsv")
    if os.path.exists(ruta_excluidas):
        with open(ruta_excluidas, encoding="utf-8") as f:
            excluidas = {linea.split("\t")[0] for linea in f if linea[:1].isdigit()}

    # id → (chino, inglés, caracteres, nivel máximo, largo)
    oraciones, vistas = {}, set()
    with open(ORACIONES, encoding="utf-8") as f:
        for linea in f:
            p = linea.rstrip("\n").split("\t")
            if len(p) < 5:
                continue
            id_, chino, ingles = p[0], p[1].strip(), p[4].strip()
            if chino in vistas or id_ in excluidas:
                continue
            vistas.add(chino)
            caracteres = HAN.findall(chino)
            if not 4 <= len(caracteres) <= LARGO_MAXIMO or re.search(r"[A-Za-z0-9０-９]", chino):
                continue
            nivel = max(niveles.get(c, 99) for c in caracteres)
            oraciones[id_] = (chino, ingles, set(caracteres), nivel, len(caracteres))

    por_caracter = defaultdict(list)
    for id_, o in oraciones.items():
        for c in o[2]:
            if c in niveles:
                por_caracter[c].append(id_)

    elegidas, seleccion = set(), []
    # Primero los caracteres con menos oraciones disponibles (los difíciles).
    cortas = {c: sum(1 for i in ids if oraciones[i][4] <= LARGO_NORMAL) for c, ids in por_caracter.items()}
    for c in sorted(orden_hsk, key=lambda c: cortas.get(c, 0)):
        nivel, meta, tomadas = niveles[c], ejemplos_para(niveles[c]), []
        # (nivel de vocabulario permitido, largo máximo)
        pasadas = ((nivel, LARGO_NORMAL), (min(7, nivel + 1), LARGO_NORMAL),
                   (99, LARGO_NORMAL), (99, LARGO_MAXIMO))
        for tolerancia, largo in pasadas:
            if largo > LARGO_NORMAL and tomadas:
                break   # las largas solo si no hay ninguna corta
            aptas = [i for i in por_caracter[c]
                     if oraciones[i][3] <= tolerancia and oraciones[i][4] <= largo and i not in tomadas]
            aptas.sort(key=lambda i: (
                i not in elegidas,          # reutilizar primero
                abs(oraciones[i][4] - 8),   # cerca de 8 caracteres
                oraciones[i][3],            # vocabulario más fácil
                int(i),
            ))
            tomadas += aptas[:meta - len(tomadas)]
            if len(tomadas) >= meta:
                break
        for orden, i in enumerate(tomadas, start=1):
            seleccion.append((c, orden, i))
            elegidas.add(i)

    os.makedirs(SALIDA, exist_ok=True)
    seleccion.sort(key=lambda s: (posicion[s[0]], s[1]))
    with open(os.path.join(SALIDA, "ejemplos_seleccion.tsv"), "w", encoding="utf-8") as f:
        f.write("# Generado por seleccionar_ejemplos.py\n")
        f.write("caracter\torden\tid_oracion\n")
        for c, orden, i in seleccion:
            f.write(f"{c}\t{orden}\t{i}\n")

    pinyin_hsk = cargar_pinyin_hsk()
    with open(os.path.join(SALIDA, "ejemplos_pinyin.tsv"), "w", encoding="utf-8") as f:
        f.write("# Generado por seleccionar_ejemplos.py (pinyin HSK oficial + pypinyin)\n")
        f.write("id_oracion\tpinyin\n")
        for i in sorted(elegidas, key=int):
            f.write(f"{i}\t{generar_pinyin(oraciones[i][0], pinyin_hsk)}\n")

    ya_traducidas = set()
    ruta_es = os.path.join(SALIDA, "ejemplos_es.tsv")
    if os.path.exists(ruta_es):
        with open(ruta_es, encoding="utf-8") as f:
            for linea in f:
                partes = linea.rstrip("\n").split("\t")
                if len(partes) >= 2 and partes[1].strip() and partes[0].isdigit():
                    ya_traducidas.add(partes[0])
    pendientes = sorted(elegidas - ya_traducidas, key=int)
    with open(os.path.join(SALIDA, "ejemplos_por_traducir.tsv"), "w", encoding="utf-8") as f:
        f.write("id_oracion\tchino\tingles\n")
        for i in pendientes:
            f.write(f"{i}\t{oraciones[i][0]}\t{oraciones[i][1]}\n")

    con = len({c for c, _, _ in seleccion})
    print(f"{len(seleccion)} ejemplos para {con} de {len(niveles)} caracteres HSK; "
          f"{len(elegidas)} oraciones distintas; {len(pendientes)} por traducir")


if __name__ == "__main__":
    main()

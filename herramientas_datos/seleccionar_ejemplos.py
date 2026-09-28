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
    "（": "(", "）": ")", "《": "«", "》": "»",   # las comillas “ ” ‘ ’ se quedan igual
})


# Caracteres que en Tatoeba aparecen casi siempre dentro de nombres propios
# transcritos. Una oración no cuenta como ejemplo de ese carácter si solo lo
# trae dentro de uno de estos nombres (贝蒂 "Betty" no enseña qué es 蒂).
NOMBRES = {
    "蒂": ["贝蒂", "史蒂", "狄蒂", "蒂丝", "蒂亚", "蒂芬", "蒂娜", "蒂姆", "蒂米", "马蒂", "凯蒂", "克里斯蒂"],
    "藤": ["佐藤", "加藤", "伊藤", "后藤", "斋藤", "藤原", "藤田", "藤井", "近藤", "远藤", "安藤", "工藤"],
    "戈": ["戈登", "戈尔", "萨拉戈萨", "英戈", "芝加哥", "圣地亚戈"],
    "兹": ["利兹", "兹卡", "卡兹", "兹沃"],
}


def solo_en_nombres(caracter, chino):
    """True si [caracter] aparece en [chino] únicamente dentro de nombres propios."""
    for nombre in NOMBRES.get(caracter, ()):
        chino = chino.replace(nombre, "")
    return caracter not in chino


LARGO_NORMAL = 14    # caracteres chinos por oración, lo normal
LARGO_MAXIMO = 24    # solo si el carácter no tiene ninguna oración corta


def ejemplos_para(nivel):
    """Cuántos ejemplos se buscan para un carácter de ese nivel."""
    return 2 if nivel <= 6 else 1


def cargar_pinyin_hsk():
    """
    Palabra HSK → pinyin oficial (solo palabras con una única lectura).

    Se conserva el pinyin completo aunque traiga espacios ("huí jiā" para
    回家) y se comprueba que tenga una sílaba por carácter; si no cuadra, esa
    palabra la resuelve pypinyin.
    """
    from construir_db import leer_cedict, partir_pinyin, silabas_validas
    validas = silabas_validas(leer_cedict())

    lecturas = defaultdict(set)
    with open(HSK_PALABRAS, encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            palabras = fila["Simplified"].split("|")
            pinyins = fila["Pinyin"].split("|")
            if len(palabras) != len(pinyins):
                continue
            for palabra, py in zip(palabras, pinyins):
                palabra = re.sub(r"[（(].*?[)）]|\d|…", "", palabra).strip()
                py = re.split(r"[(（/]", py.strip())[0].strip()
                if not (palabra and SOLO_HAN.fullmatch(palabra) and py):
                    continue
                if partir_pinyin(py, len(palabra), validas) is None:
                    continue
                lecturas[palabra].add(py)
    return {palabra: next(iter(p)) for palabra, p in lecturas.items() if len(p) == 1}


# ── Partículas 得 y 地 ───────────────────────────────────────────────────────
# pypinyin lee 得 y 地 sueltos como "dé" y "dì", pero casi siempre son las
# partículas "de" (说得很好, 高兴地笑). Estas reglas deciden por el contexto.

# 地 sí es "dì" (tierra, suelo) antes o después de estos caracteres.
_DI_DESPUES = set("底上下面里方区图球板毯铁址震位带形势质道主狱窖摊基段皮价铺")
_DI_ANTES = set("随拖扫土田草种耕遍满落天陆园场基境各该原当本外异两盆工产属空墓高低平内山洼腹领宝胜营阵驻重要")
# 得 como "dé" (obtener) en palabras y nombres; "de" neutro en 记得, 懂得…
_DE2_ANTES = set("彼哈求兼获取赢难应")
_DE5_ANTES = set("记懂舍晓免省值觉认")
# 得 como "děi" (tener que) después de un sujeto o un adverbio.
_DEI_ANTES = set("我你他她它们您咱的在就也还都又总须")


def _lectura_particula(caracter, antes, despues):
    """Lectura de 得/地 según el carácter anterior y el siguiente ('' si no hay)."""
    han_antes = bool(antes and HAN.match(antes))
    han_despues = bool(despues and HAN.match(despues))
    if caracter == "地":
        if not han_antes or not han_despues:
            return "dì"
        if despues in _DI_DESPUES or antes in _DI_ANTES:
            return "dì"
        return "de"
    # 得
    if not han_antes or not han_despues or antes in _DE2_ANTES or despues == "标":
        return "dé"
    if antes in _DE5_ANTES:
        return "de"
    if antes in _DEI_ANTES:
        return "děi"
    return "de"


def generar_pinyin(texto, pinyin_hsk):
    """Pinyin por palabras: primero palabras HSK (la más larga), luego pypinyin."""
    from pypinyin import Style, pinyin
    from pypinyin.seg.mmseg import seg

    def por_pypinyin(fragmento, inicio):
        partes, pos = [], inicio
        for palabra in seg.cut(fragmento):
            if palabra in ("得", "地"):
                antes = texto[pos - 1] if pos > 0 else ""
                despues = texto[pos + 1] if pos + 1 < len(texto) else ""
                partes.append(_lectura_particula(palabra, antes, despues))
            elif HAN.search(palabra):
                partes.append("".join(s[0] for s in pinyin(palabra, style=Style.TONE, heteronym=False)))
            elif palabra.strip():
                partes.append(palabra.strip().translate(PUNTUACION))
            pos += len(palabra)
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
                salida += por_pypinyin(pendiente, i - len(pendiente))
                pendiente = ""
            salida.append(pinyin_hsk[encontrada])
            i += len(encontrada)
        else:
            pendiente += texto[i]
            i += 1
    if pendiente:
        salida += por_pypinyin(pendiente, len(texto) - len(pendiente))
    frase = " ".join(salida)
    frase = re.sub(r"\s+([,.!?:;…)»”’])", r"\1", frase)     # sin espacio antes de cierres
    frase = re.sub(r"([(«“‘])\s+", r"\1", frase)             # ni después de aperturas
    frase = re.sub(r"([”’])([“‘])", r"\1 \2", frase)         # ”“ → ” “
    frase = re.sub(r"([,.!?:;])([“‘«(])", r"\1 \2", frase)   # :“ → : “
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
            if c in niveles and not solo_en_nombres(c, o[0]):
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

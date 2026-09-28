"""
construir_db.py
───────────────
Arma la base de datos de CONTENIDO de la app (assets/db/contenido.db) a
partir de las fuentes originales que están en herramientas_datos/fuentes/.

La app ya no lee JSON al arrancar: copia este archivo .db una sola vez y lo
consulta directamente. Por eso el arranque es inmediato.

Uso (desde la raíz del proyecto):
    python herramientas_datos/construir_db.py
    python herramientas_datos/validar_db.py      ← siempre después

Qué fuente aporta qué:
    make-me-a-hanzi  graphics.txt    → contornos SVG de cada trazo y "medianas"
                                       (la línea central, para evaluar el trazo)
                     dictionary.txt  → lectura más usual (Unihan kMandarin)
    CC-CEDICT        cedict_ts.u8    → significados en inglés
    HSK 3.0          hsk30-chars.csv → nivel oficial (GF 0025-2021), nivel de
                                       escritura a mano y cuántas palabras HSK
                                       usan el carácter (orden de estudio)
                     hsk30.csv       → lectura oficial de los caracteres que
                                       son palabra por sí solos (了 = le)
    Unihan           kRSUnicode      → radical Kangxi de cada carácter
    Propias          radicales_kangxi.tsv, traducciones/*.tsv

Solo usa la biblioteca estándar de Python.
"""

import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pinyin_util import acentos_a_num, normalizar_num, num_a_acentos, sin_tono  # noqa: E402

# ─── Rutas ────────────────────────────────────────────────────────────────────
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTES = os.path.join(RAIZ, "herramientas_datos", "fuentes")
SALIDA_DB = os.path.join(RAIZ, "assets", "db", "contenido.db")
SALIDA_VERSION = os.path.join(RAIZ, "lib", "datos", "version_contenido.dart")

GRAPHICS = os.path.join(FUENTES, "makemeahanzi", "graphics.txt")
DICTIONARY = os.path.join(FUENTES, "makemeahanzi", "dictionary.txt")
CEDICT = os.path.join(FUENTES, "cedict", "cedict_ts.u8")
HSK_CARACTERES = os.path.join(FUENTES, "hsk30", "hsk30-chars.csv")
HSK_PALABRAS = os.path.join(FUENTES, "hsk30", "hsk30.csv")
UNIHAN = os.path.join(FUENTES, "unihan", "unihan_krsunicode.txt")
RADICALES = os.path.join(FUENTES, "radicales_kangxi.tsv")
SIGNIFICADOS_ES = os.path.join(FUENTES, "traducciones", "significados_es.tsv")
ORACIONES = os.path.join(FUENTES, "oraciones", "cmn_sen_db_2.tsv")
EJEMPLOS_SELECCION = os.path.join(FUENTES, "traducciones", "ejemplos_seleccion.tsv")
EJEMPLOS_ES = os.path.join(FUENTES, "traducciones", "ejemplos_es.tsv")
EJEMPLOS_PINYIN = os.path.join(FUENTES, "traducciones", "ejemplos_pinyin.tsv")

# Caracteres del bloque "CJK Radicals Supplement" (formas de radical sin
# código propio en Unihan): se asignan a mano a su radical Kangxi.
RADICAL_SUPLEMENTO = {
    "⺀": 15, "⺈": 18, "⺊": 25, "⺌": 42, "⺍": 42, "⺗": 61,
    "⺮": 118, "⺳": 122, "⺼": 130,
}

# Significados de CC-CEDICT que NO sirven como definición principal.
NO_SIRVE = re.compile(
    r"^(variant of|old variant of|japanese variant of|archaic variant of|"
    r"erhua variant of|see |used in|surname|\(archaic\)|\(old\)|abbr\. for|"
    r"also pr\.|taiwan pr\.|cl:)",
    re.IGNORECASE,
)
MAX_ACEPCIONES_EN = 6


# ═════════════════════════════════════════════════════════════════════════════
# 1. LECTURA DE FUENTES
# ═════════════════════════════════════════════════════════════════════════════

def leer_graphics():
    """carácter → (lista de contornos SVG, lista de medianas)."""
    datos = {}
    with open(GRAPHICS, encoding="utf-8") as f:
        for linea in f:
            if linea.strip():
                e = json.loads(linea)
                datos[e["character"]] = (e["strokes"], e["medians"])
    return datos


def leer_dictionary():
    """carácter → entrada de make-me-a-hanzi (pinyin, definition, ...)."""
    datos = {}
    with open(DICTIONARY, encoding="utf-8") as f:
        for linea in f:
            if linea.strip():
                e = json.loads(linea)
                datos[e["character"]] = e
    return datos


def leer_cedict():
    """carácter simplificado → lista de (orden, pinyin_num, acepciones)."""
    patron = re.compile(r"^(\S+) (\S+) \[([^\]]+)\] /(.*)/\s*$")
    datos = defaultdict(list)
    with open(CEDICT, encoding="utf-8") as f:
        for i, linea in enumerate(f):
            if linea.startswith("#"):
                continue
            m = patron.match(linea.rstrip("\n"))
            if not m:
                continue
            _trad, simp, pinyin, acepciones = m.groups()
            if len(simp) == 1:
                datos[simp].append((i, pinyin, [a.strip() for a in acepciones.split("/")]))
    return datos


def leer_hsk_caracteres():
    """carácter → dict(nivel, nivel_escritura, frecuencia, orden_oficial)."""
    datos = {}
    with open(HSK_CARACTERES, encoding="utf-8") as f:
        for orden, fila in enumerate(csv.DictReader(f)):
            nivel = 7 if fila["Level"] == "7-9" else int(fila["Level"])
            escritura = int(fila["WritingLevel"]) if fila["WritingLevel"] else None
            datos[fila["Hanzi"]] = {
                "nivel": nivel,
                "nivel_escritura": escritura,
                "frecuencia": int(fila["Freq"] or 0),
                "orden": orden,
            }
    return datos


def leer_lecturas_hsk():
    """
    carácter → lecturas oficiales (con números) cuando el carácter aparece
    como palabra por sí solo en la lista de vocabulario HSK 3.0, ordenadas por
    nivel (la del nivel más bajo primero). Ej.: 地 → ['de5', 'di4'].
    """
    lecturas = defaultdict(list)
    with open(HSK_PALABRAS, encoding="utf-8") as f:
        filas = list(csv.DictReader(f))

    def nivel(fila):
        return 7 if fila["Level"] == "7-9" else int(fila["Level"])

    for fila in sorted(filas, key=nivel):
        palabras = fila["Simplified"].split("|")
        pinyins = fila["Pinyin"].split("|")
        if len(palabras) != len(pinyins):
            continue
        for palabra, py in zip(palabras, pinyins):
            palabra = re.sub(r"[（(].*?[)）]|\d", "", palabra).strip()
            # Algunas lecturas traen un ejemplo o una alternativa:
            # "dì (dì-èr)" → "dì";  "shéi/shuí" → "shéi".
            py = re.split(r"[\s(（/]", py.strip())[0]
            if len(palabra) == 1 and py:
                num = acentos_a_num(py)
                if num not in lecturas[palabra]:
                    lecturas[palabra].append(num)
    return dict(lecturas)


def leer_unihan():
    """carácter → (número de radical Kangxi, trazos además del radical)."""
    datos = {}
    with open(UNIHAN, encoding="utf-8") as f:
        for linea in f:
            if linea.startswith("#") or not linea.strip():
                continue
            _cp, c, valor = linea.rstrip("\n").split("\t")
            primero = valor.split()[0]                 # p. ej. "149'.7"
            m = re.match(r"(\d+)'*\.(-?\d+)", primero)
            if m:
                datos[c] = (int(m.group(1)), int(m.group(2)))
    return datos


def leer_radicales():
    """Lista de dicts con las columnas de radicales_kangxi.tsv."""
    with open(RADICALES, encoding="utf-8") as f:
        lineas = [l for l in f if not l.startswith("#")]
    return list(csv.DictReader(lineas, delimiter="\t"))


def leer_tsv_simple(ruta, columnas):
    """Lee un TSV con encabezado; si no existe devuelve lista vacía."""
    if not os.path.exists(ruta):
        return []
    with open(ruta, encoding="utf-8") as f:
        lineas = [l for l in f if not l.startswith("#")]
    filas = list(csv.DictReader(lineas, delimiter="\t", quoting=csv.QUOTE_NONE))
    for fila in filas:
        for col in columnas:
            if col not in fila:
                raise SystemExit(f"{ruta}: falta la columna '{col}'")
    return filas


def leer_oraciones():
    """id → (chino, pinyin, inglés) de cmn_sen_db_2.tsv."""
    datos = {}
    with open(ORACIONES, encoding="utf-8") as f:
        for linea in f:
            partes = linea.rstrip("\n").split("\t")
            if len(partes) >= 5:
                datos[partes[0]] = (partes[1].strip(), partes[3].strip(), partes[4].strip())
    return datos


# ═════════════════════════════════════════════════════════════════════════════
# 2. DECISIONES POR CARÁCTER
# ═════════════════════════════════════════════════════════════════════════════

def limpiar_acepciones(acepciones):
    """Quita acepciones que no sirven (variantes, clasificadores, notas)."""
    buenas = []
    for a in acepciones:
        a = a.strip()
        if not a or NO_SIRVE.match(a):
            continue
        a = re.sub(r"\s*\(Tw\)|\s*\(Taiwan pr\.[^)]*\)", "", a).strip()
        if a and a not in buenas:
            buenas.append(a)
    return buenas


def elegir_lectura(c, lecturas_hsk, mmh, cedict):
    """
    Lectura principal del carácter (con números), en este orden de confianza:
      1. la que da la lista oficial HSK cuando el carácter es palabra sola;
      2. la más usual según Unihan (primer pinyin de make-me-a-hanzi);
      3. la mejor entrada de CC-CEDICT (minúscula, no variante).
    """
    if c in lecturas_hsk:
        return lecturas_hsk[c][0]
    pys = mmh.get(c, {}).get("pinyin") or []
    if pys:
        return acentos_a_num(pys[0])
    candidatos = sorted(
        cedict.get(c, []),
        key=lambda e: (e[1][:1].isupper(), not limpiar_acepciones(e[2]), e[0]))
    if candidatos:
        return normalizar_num(candidatos[0][1])
    return ""


def significado_ingles(c, lectura, mmh, cedict):
    """Acepciones de CC-CEDICT para esa lectura; si no hay, las de Unihan."""
    entradas = cedict.get(c, [])
    iguales = [e for e in entradas if normalizar_num(e[1]) == lectura]
    # Primero las entradas en minúscula (las mayúsculas son apellidos/nombres).
    iguales.sort(key=lambda e: (e[1][:1].isupper(), e[0]))
    acepciones = []
    for _orden, _py, acs in iguales:
        for a in limpiar_acepciones(acs):
            if a not in acepciones:
                acepciones.append(a)
    if not acepciones:
        for _orden, _py, acs in sorted(entradas, key=lambda e: (e[1][:1].isupper(), e[0])):
            acepciones = limpiar_acepciones(acs)
            if acepciones:
                break
    if not acepciones and mmh.get(c, {}).get("definition"):
        acepciones = [mmh[c]["definition"]]
    return "; ".join(acepciones[:MAX_ACEPCIONES_EN])


def significado_por_lecturas(c, lectura, lecturas_hsk, mmh, cedict):
    """
    Si el carácter tiene varias lecturas oficiales (地: de / dì), etiqueta los
    significados de cada una: "de: …  |  dì: …". Si tiene una sola, devuelve
    los significados de esa lectura.
    """
    todas = lecturas_hsk.get(c, [])
    if len(todas) < 2:
        return significado_ingles(c, lectura, mmh, cedict)
    partes = []
    for r in todas:
        sig = significado_ingles(c, r, mmh, cedict)
        if sig:
            partes.append(f"{num_a_acentos(r)}: {sig}")
    return "  |  ".join(partes)


# ═════════════════════════════════════════════════════════════════════════════
# 3. ESQUEMA
# ═════════════════════════════════════════════════════════════════════════════

ESQUEMA = """
-- Datos generales de esta versión del contenido.
CREATE TABLE meta (
    clave TEXT PRIMARY KEY,
    valor TEXT NOT NULL
);

-- Los 214 radicales Kangxi.
CREATE TABLE radicales (
    numero          INTEGER PRIMARY KEY,   -- 1 a 214
    forma_principal TEXT    NOT NULL,      -- la que se muestra (水)
    variantes       TEXT    NOT NULL,      -- otras formas, separadas por espacio (氵 氺)
    nombre_es       TEXT    NOT NULL,      -- "agua"
    pinyin          TEXT    NOT NULL,      -- con acentos
    trazos          INTEGER NOT NULL,      -- trazos del radical
    caracter_id     INTEGER,               -- id en `caracteres` para practicarlo (NULL si no hay trazos)
    total_hsk       INTEGER NOT NULL,      -- caracteres HSK de su familia
    total           INTEGER NOT NULL       -- todos los caracteres de su familia
);

-- Un renglón por carácter con datos de trazo.
CREATE TABLE caracteres (
    id               INTEGER PRIMARY KEY,
    caracter         TEXT    NOT NULL UNIQUE,
    pinyin           TEXT    NOT NULL,     -- con acentos: "hǎo"
    pinyin_num       TEXT    NOT NULL,     -- con número:  "hao3" (color por tono)
    pinyin_plano     TEXT    NOT NULL,     -- sin tono:    "hao"  (búsqueda)
    otras_lecturas   TEXT    NOT NULL,     -- otras lecturas oficiales HSK, con acentos ("dì"), separadas por espacio
    significado_es   TEXT,                 -- NULL si aún no hay traducción
    significado_en   TEXT    NOT NULL,
    nivel_hsk        INTEGER NOT NULL,     -- 1-6; 7 = niveles 7-9; 0 = fuera de HSK
    nivel_escritura  INTEGER,              -- 1, 2 o 3 si está en la lista oficial de escritura a mano
    radical          INTEGER NOT NULL,     -- número Kangxi (1-214)
    trazos_extra     INTEGER NOT NULL,     -- trazos además del radical
    num_trazos       INTEGER NOT NULL,     -- trazos totales
    es_forma_radical INTEGER NOT NULL,     -- 1 si el carácter ES un radical o una de sus variantes
    frecuencia       INTEGER NOT NULL,     -- cuántas palabras HSK lo usan (orden de estudio)
    orden_oficial    INTEGER NOT NULL,     -- posición en la lista oficial HSK (9999 si no es HSK)
    trazos_svg       TEXT    NOT NULL,     -- JSON: lista de contornos SVG (sistema de 1024×1024)
    medianas         TEXT    NOT NULL      -- JSON: lista de trazos; cada uno, lista de puntos [x, y]
);
CREATE INDEX idx_caracteres_nivel   ON caracteres (nivel_hsk, frecuencia DESC);
CREATE INDEX idx_caracteres_radical ON caracteres (radical, nivel_hsk);

-- Oraciones de ejemplo para cada carácter.
CREATE TABLE ejemplos (
    id          INTEGER PRIMARY KEY,
    caracter_id INTEGER NOT NULL REFERENCES caracteres (id),
    orden       INTEGER NOT NULL,
    chino       TEXT    NOT NULL,
    pinyin      TEXT    NOT NULL,
    espanol     TEXT,
    ingles      TEXT
);
CREATE INDEX idx_ejemplos_caracter ON ejemplos (caracter_id, orden);
"""


# ═════════════════════════════════════════════════════════════════════════════
# 4. CONSTRUCCIÓN
# ═════════════════════════════════════════════════════════════════════════════

def construir():
    graficos = leer_graphics()
    mmh = leer_dictionary()
    cedict = leer_cedict()
    hsk = leer_hsk_caracteres()
    lecturas_hsk = leer_lecturas_hsk()
    unihan = leer_unihan()
    radicales = leer_radicales()
    significados_es = {f["caracter"]: f["significado_es"].strip()
                       for f in leer_tsv_simple(SIGNIFICADOS_ES, ["caracter", "significado_es"])
                       if f["significado_es"].strip()}

    # Formas de radical: carácter → números de radical que representa.
    formas_radical = defaultdict(set)
    pinyin_de_forma = {}
    for r in radicales:
        for forma in [r["forma_principal"]] + r["variantes"].split():
            formas_radical[forma].add(int(r["numero"]))
            pinyin_de_forma.setdefault(forma, r["pinyin"])
    # Las formas del bloque "suplemento de radicales" (⺈, ⺼…) no tienen
    # lectura propia: se leen como su radical.
    for forma, numero in RADICAL_SUPLEMENTO.items():
        formas_radical[forma].add(numero)
        principal = next(r for r in radicales if int(r["numero"]) == numero)
        pinyin_de_forma.setdefault(forma, principal["pinyin"])

    # Orden de los caracteres: primero HSK (en orden oficial), luego el resto
    # por número de radical. Así los id son estables y fáciles de leer.
    def orden(c):
        if c in hsk:
            return (0, hsk[c]["orden"])
        return (1, unihan.get(c, (RADICAL_SUPLEMENTO.get(c, 999), 0)), c)

    filas, problemas = [], []
    for id_, c in enumerate(sorted(graficos, key=orden), start=1):
        trazos, medianas = graficos[c]

        lectura = elegir_lectura(c, lecturas_hsk, mmh, cedict)
        if not lectura and c in pinyin_de_forma:
            lectura = acentos_a_num(pinyin_de_forma[c])
        if not lectura:
            problemas.append(f"{c}: sin lectura (componente sin pronunciación propia)")

        if c in unihan:
            radical, extra = unihan[c]
        elif c in RADICAL_SUPLEMENTO:
            radical, extra = RADICAL_SUPLEMENTO[c], 0
        else:
            problemas.append(f"{c}: sin radical")
            radical, extra = 0, 0

        datos_hsk = hsk.get(c)
        filas.append({
            "id": id_,
            "caracter": c,
            "pinyin": num_a_acentos(lectura) if lectura else "",
            "pinyin_num": lectura,
            "pinyin_plano": sin_tono(lectura) if lectura else "",
            "significado_es": significados_es.get(c),
            "otras_lecturas": " ".join(num_a_acentos(x) for x in lecturas_hsk.get(c, [])[1:]),
            "significado_en": significado_por_lecturas(c, lectura, lecturas_hsk, mmh, cedict),
            "nivel_hsk": datos_hsk["nivel"] if datos_hsk else 0,
            "nivel_escritura": datos_hsk["nivel_escritura"] if datos_hsk else None,
            "radical": radical,
            "trazos_extra": extra,
            "num_trazos": len(trazos),
            "es_forma_radical": 1 if c in formas_radical else 0,
            "frecuencia": datos_hsk["frecuencia"] if datos_hsk else 0,
            "orden_oficial": datos_hsk["orden"] if datos_hsk else 9999,
            "trazos_svg": json.dumps(trazos, ensure_ascii=False, separators=(",", ":")),
            "medianas": json.dumps(medianas, separators=(",", ":")),
        })

    id_por_caracter = {f["caracter"]: f["id"] for f in filas}

    # Familias de radicales.
    total, total_hsk = defaultdict(int), defaultdict(int)
    for f in filas:
        total[f["radical"]] += 1
        if f["nivel_hsk"] > 0:
            total_hsk[f["radical"]] += 1

    filas_radicales = []
    for r in radicales:
        n = int(r["numero"])
        formas = [r["forma_principal"]] + r["variantes"].split()
        practica = next((id_por_caracter[x] for x in formas if x in id_por_caracter), None)
        if practica is None:
            problemas.append(f"radical {n}: ninguna forma tiene datos de trazo")
        filas_radicales.append({
            "numero": n, "forma_principal": r["forma_principal"], "variantes": r["variantes"],
            "nombre_es": r["nombre_es"], "pinyin": r["pinyin"], "trazos": int(r["trazos"]),
            "caracter_id": practica, "total_hsk": total_hsk[n], "total": total[n],
        })

    # Ejemplos (si ya existen la selección y las traducciones).
    filas_ejemplos = []
    seleccion = leer_tsv_simple(EJEMPLOS_SELECCION, ["caracter", "orden", "id_oracion"])
    if seleccion:
        oraciones = leer_oraciones()
        traducciones = {f["id_oracion"]: f["espanol"].strip()
                        for f in leer_tsv_simple(EJEMPLOS_ES, ["id_oracion", "espanol"])}
        # Pinyin regenerado (oficial HSK + pypinyin); el del corpus solo de respaldo.
        pinyin_nuevo = {f["id_oracion"]: f["pinyin"].strip()
                        for f in leer_tsv_simple(EJEMPLOS_PINYIN, ["id_oracion", "pinyin"])}
        for s in seleccion:
            c, id_or = s["caracter"], s["id_oracion"]
            if c not in id_por_caracter or id_or not in oraciones:
                problemas.append(f"ejemplo {id_or} para {c}: no encontrado")
                continue
            chino, pinyin, ingles = oraciones[id_or]
            pinyin = pinyin_nuevo.get(id_or) or pinyin
            filas_ejemplos.append({
                "caracter_id": id_por_caracter[c], "orden": int(s["orden"]),
                "chino": chino, "pinyin": pinyin,
                "espanol": traducciones.get(id_or) or None, "ingles": ingles or None,
            })

    # ── Escribir la base ───────────────────────────────────────────────────
    os.makedirs(os.path.dirname(SALIDA_DB), exist_ok=True)
    temporal = SALIDA_DB + ".tmp"
    if os.path.exists(temporal):
        os.remove(temporal)
    con = sqlite3.connect(temporal)
    con.executescript(ESQUEMA)

    def insertar(tabla, registros):
        if not registros:
            return
        columnas = list(registros[0])
        con.executemany(
            f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES ({', '.join('?' * len(columnas))})",
            [tuple(r[k] for k in columnas) for r in registros])

    insertar("caracteres", filas)
    insertar("radicales", filas_radicales)
    insertar("ejemplos", filas_ejemplos)

    # Versión = huella del contenido: si cambia cualquier dato, cambia la
    # versión y la app sabe que debe copiar la base nueva.
    huella = hashlib.sha1()
    for tabla, orden_sql in (("caracteres", "id"), ("radicales", "numero"), ("ejemplos", "id")):
        for fila in con.execute(f"SELECT * FROM {tabla} ORDER BY {orden_sql}"):
            huella.update(repr(fila).encode("utf-8"))
    version = huella.hexdigest()[:12]
    insertar("meta", [
        {"clave": "version", "valor": version},
        {"clave": "fuentes", "valor": "make-me-a-hanzi, CC-CEDICT, HSK 3.0 (GF 0025-2021), Unihan 12.1"},
    ])
    con.commit()
    con.execute("VACUUM")
    con.close()
    os.replace(temporal, SALIDA_DB)

    os.makedirs(os.path.dirname(SALIDA_VERSION), exist_ok=True)
    with open(SALIDA_VERSION, "w", encoding="utf-8") as f:
        f.write(
            "// ARCHIVO GENERADO por herramientas_datos/construir_db.py — no editar a mano.\n"
            "//\n"
            "// Huella del contenido de assets/db/contenido.db. Cuando cambia, la app\n"
            "// reemplaza la copia local de la base de contenido (el progreso del\n"
            "// usuario vive en otra base y no se toca).\n"
            f"const String kVersionContenido = '{version}';\n")

    # ── Resumen ────────────────────────────────────────────────────────────
    por_nivel = defaultdict(int)
    for f in filas:
        por_nivel[f["nivel_hsk"]] += 1
    tam = os.path.getsize(SALIDA_DB) / 1e6
    print(f"contenido.db  versión {version}  ({tam:.1f} MB)")
    print(f"  caracteres: {len(filas)}  | por nivel: " +
          ", ".join(f"{('fuera' if k == 0 else ('7-9' if k == 7 else k))}={v}"
                    for k, v in sorted(por_nivel.items())))
    hsk_es = sum(1 for f in filas if f["nivel_hsk"] > 0 and f["significado_es"])
    print(f"  significados en español (HSK): {hsk_es} de {len(hsk)}")
    print(f"  radicales: {len(filas_radicales)}  | ejemplos: {len(filas_ejemplos)}")
    if problemas:
        print(f"  avisos ({len(problemas)}):")
        for p in problemas[:30]:
            print("   -", p)


if __name__ == "__main__":
    construir()

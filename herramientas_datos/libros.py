"""
libros.py
─────────
Los libros de la sección «Leer»: cómo se leen sus archivos y qué tan
difíciles son para cada nivel HSK.

Cada libro es un archivo de texto en herramientas_datos/fuentes/libros/.
Lo usan:
    preparar_libros.py → agrega el pinyin (requiere pypinyin) y escribe
                         libros_generado.json
    construir_db.py    → mete los libros en contenido.db (sin pypinyin)
    validar_db.py      → revisa cobertura HSK y que el pinyin esté al día

Formato de un libro (UTF-8):

    clave: cuentos-para-ninos
    titulo: 中国小故事
    titulo_es: Cuentos chinos para niños
    nivel: 1                  1-6, o 7 = HSK 7-9
    tipo: adaptado            adaptado (escrito para la app) | original (texto clásico)
    descripcion: …
    fuente: …                 de dónde viene la historia o el texto, y su licencia

    ## 孔融让梨               ← empieza un capítulo
    titulo_es: Kong Rong cede las peras
    origen: …
    palabras: 梨 = pera; 让 = ceder      vocabulario que se explica al empezar

    {孔融}四岁。他家……       ← un párrafo en chino (una o varias líneas)
    > Kong Rong tenía…        ← su traducción al español (líneas con ">")

Se pueden escribir comillas rectas ("…"): se convierten en comillas chinas “…”.

Marcas dentro del chino:
    {孔融}      nombre propio: se subraya y no cuenta para la dificultad. Basta
                marcarlo una vez: se reconoce en todo el libro.
    重[zhòng]   lectura para un carácter con varias (si el pinyin automático
                se equivoca)

Dificultad ("cobertura"): de los caracteres del libro, sin contar nombres
propios, qué fracción ya conoce alguien de ese nivel: los de su nivel HSK o
menor, más los que se explican en el vocabulario ("palabras:") del capítulo
o de capítulos anteriores.

Solo usa la biblioteca estándar de Python.
"""

import glob
import hashlib
import os
import re
from collections import Counter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARPETA = os.path.join(RAIZ, "herramientas_datos", "fuentes", "libros")
GENERADO = os.path.join(CARPETA, "libros_generado.json")

TIPOS = ("adaptado", "original")
CAMPOS_LIBRO = ("clave", "titulo", "titulo_es", "nivel", "tipo", "descripcion", "fuente")

# Fracción mínima de caracteres (sin contar nombres propios) que deben ser del
# nivel del libro o de uno menor, en los libros ADAPTADOS. Los originales
# solo se reportan: su texto no se puede cambiar.
COBERTURA_MINIMA = 0.90


def es_han(c):
    return "一" <= c <= "鿿" or "㐀" <= c <= "䶿"


class ErrorLibro(Exception):
    pass


def _parsear_chino(texto, donde):
    """'{孔融}四岁。重[zhòng]' → ('孔融四岁。重', [[0, 2]], {5: 'zhòng'})"""
    limpio, nombres, lecturas = [], [], {}
    inicio_nombre = None
    i = 0
    while i < len(texto):
        c = texto[i]
        if c == "{":
            if inicio_nombre is not None:
                raise ErrorLibro(f"{donde}: '{{' sin cerrar")
            inicio_nombre = len(limpio)
        elif c == "}":
            if inicio_nombre is None:
                raise ErrorLibro(f"{donde}: '}}' sin abrir")
            nombres.append([inicio_nombre, len(limpio)])
            inicio_nombre = None
        elif c == "[":
            fin = texto.find("]", i)
            if fin < 0 or not limpio or not es_han(limpio[-1]):
                raise ErrorLibro(f"{donde}: lectura [..] mal puesta")
            lecturas[len(limpio) - 1] = texto[i + 1:fin].strip()
            i = fin
        else:
            limpio.append(c)
        i += 1
    if inicio_nombre is not None:
        raise ErrorLibro(f"{donde}: '{{' sin cerrar")
    # Comillas rectas "…" → comillas chinas “…” (se alternan apertura y cierre).
    abiertas = False
    for k, c in enumerate(limpio):
        if c == '"':
            limpio[k] = "”" if abiertas else "“"
            abiertas = not abiertas
    if abiertas:
        raise ErrorLibro(f"{donde}: comillas sin cerrar")
    return "".join(limpio), nombres, lecturas


def _parsear_palabras(texto, donde):
    palabras = []
    for parte in texto.split(";"):
        if not parte.strip():
            continue
        if "=" not in parte:
            raise ErrorLibro(f"{donde}: palabra sin '=': {parte!r}")
        chino, es = (x.strip() for x in parte.split("=", 1))
        palabras.append({"chino": chino, "espanol": es})
    return palabras


def leer_libro(ruta):
    """Devuelve el libro como diccionario (sin pinyin)."""
    nombre = os.path.basename(ruta)
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    libro = {"archivo": nombre, "huella": hashlib.sha1(texto.encode("utf-8")).hexdigest()[:16],
             "capitulos": []}
    capitulo = None
    parrafo = None  # {"chino": [...líneas], "espanol": [...]}

    def cerrar_parrafo():
        nonlocal parrafo
        if parrafo is None:
            return
        donde = f"{nombre}, capítulo «{capitulo['titulo']}»"
        if not parrafo["espanol"]:
            raise ErrorLibro(f"{donde}: párrafo sin traducción: {''.join(parrafo['chino'])[:20]}…")
        chino, nombres, lecturas = _parsear_chino("".join(parrafo["chino"]), donde)
        capitulo["parrafos"].append({
            "chino": chino, "nombres": nombres, "lecturas": lecturas,
            "espanol": " ".join(parrafo["espanol"]),
        })
        parrafo = None

    for n, linea in enumerate(texto.splitlines(), 1):
        linea = linea.strip()
        donde = f"{nombre}:{n}"
        if not linea:
            cerrar_parrafo()
            continue
        if linea.startswith("## "):
            cerrar_parrafo()
            titulo, _, lecturas_titulo = _parsear_chino(linea[3:].strip(), donde)
            capitulo = {"titulo": titulo, "lecturas_titulo": lecturas_titulo, "titulo_es": "",
                        "origen": "", "palabras": [], "parrafos": []}
            libro["capitulos"].append(capitulo)
            continue
        campo = re.match(r"^([a-z_]+):\s*(.*)$", linea)
        if campo and parrafo is None:
            clave, valor = campo.groups()
            if capitulo is None:
                if clave not in CAMPOS_LIBRO:
                    raise ErrorLibro(f"{donde}: campo de libro desconocido '{clave}'")
                libro[clave] = valor
            elif clave == "palabras":
                capitulo["palabras"] = _parsear_palabras(valor, donde)
            elif clave in ("titulo_es", "origen"):
                capitulo[clave] = valor
            else:
                raise ErrorLibro(f"{donde}: campo de capítulo desconocido '{clave}'")
            continue
        if capitulo is None:
            raise ErrorLibro(f"{donde}: texto antes del primer capítulo (## …)")
        if linea.startswith(">"):
            if parrafo is None:
                raise ErrorLibro(f"{donde}: traducción sin párrafo en chino")
            parrafo["espanol"].append(linea[1:].strip())
        else:
            if parrafo is not None and parrafo["espanol"]:
                cerrar_parrafo()  # empieza otro párrafo sin línea en blanco
            if parrafo is None:
                parrafo = {"chino": [], "espanol": []}
            parrafo["chino"].append(linea)
    cerrar_parrafo()

    _marcar_nombres(libro)
    for campo in CAMPOS_LIBRO:
        if not libro.get(campo):
            raise ErrorLibro(f"{nombre}: falta el campo '{campo}'")
    libro["nivel"] = int(libro["nivel"])
    if not 1 <= libro["nivel"] <= 7:
        raise ErrorLibro(f"{nombre}: nivel debe ser 1-7")
    if libro["tipo"] not in TIPOS:
        raise ErrorLibro(f"{nombre}: tipo debe ser {' o '.join(TIPOS)}")
    if not libro["capitulos"]:
        raise ErrorLibro(f"{nombre}: no tiene capítulos")
    for cap in libro["capitulos"]:
        if not cap["titulo_es"] or not cap["parrafos"]:
            raise ErrorLibro(f"{nombre}: capítulo «{cap['titulo']}» sin titulo_es o sin párrafos")
    return libro


def _marcar_nombres(libro):
    """Un nombre marcado una vez con {…} se marca en todo el libro."""
    nombres = {p["chino"][a:b] for cap in libro["capitulos"] for p in cap["parrafos"]
               for a, b in p["nombres"]}
    for cap in libro["capitulos"]:
        for p in cap["parrafos"]:
            marcados = set()
            for a, b in p["nombres"]:
                marcados.update(range(a, b))
            for nombre in sorted(nombres, key=len, reverse=True):
                inicio = p["chino"].find(nombre)
                while inicio >= 0:
                    rango = set(range(inicio, inicio + len(nombre)))
                    if not rango & marcados:
                        p["nombres"].append([inicio, inicio + len(nombre)])
                        marcados |= rango
                    inicio = p["chino"].find(nombre, inicio + 1)
            p["nombres"].sort()


def todos_los_libros():
    libros = [leer_libro(r) for r in sorted(glob.glob(os.path.join(CARPETA, "*.txt")))]
    claves = Counter(l["clave"] for l in libros)
    repetidas = [c for c, n in claves.items() if n > 1]
    if repetidas:
        raise ErrorLibro(f"claves de libro repetidas: {repetidas}")
    return sorted(libros, key=lambda l: (l["nivel"], l["clave"]))


def caracteres_contables(libro):
    """
    (carácter, explicados) por cada carácter chino del libro que no es parte
    de un nombre propio. [explicados] = caracteres del vocabulario de ese
    capítulo y de los anteriores.
    """
    explicados = set()
    for cap in libro["capitulos"]:
        for palabra in cap["palabras"]:
            explicados.update(c for c in palabra["chino"] if es_han(c))
        for p in cap["parrafos"]:
            en_nombre = set()
            for a, b in p["nombres"]:
                en_nombre.update(range(a, b))
            for i, c in enumerate(p["chino"]):
                if es_han(c) and i not in en_nombre:
                    yield c, explicados


def cobertura(libro, nivel_de):
    """
    (fracción conocida, Counter de caracteres por encima del nivel que NO se
    explican en el vocabulario). [nivel_de]: carácter → nivel HSK (0 = fuera).
    """
    total, conocidos, arriba = 0, 0, Counter()
    for c, explicados in caracteres_contables(libro):
        total += 1
        n = nivel_de.get(c, 0)
        if 1 <= n <= libro["nivel"] or c in explicados:
            conocidos += 1
        else:
            arriba[c] += 1
    return (conocidos / total if total else 1.0), arriba

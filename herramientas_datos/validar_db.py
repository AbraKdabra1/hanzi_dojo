"""
validar_db.py
─────────────
Revisa que assets/db/contenido.db cumpla lo que la app promete.
Si algo falla, termina con código 1 (la integración continua lo marca en rojo).

Uso:
    python herramientas_datos/validar_db.py
    python herramientas_datos/validar_db.py --permitir-incompleto
        (no exige traducciones al español ni ejemplos; útil mientras se traduce)

Qué comprueba:
    1. Niveles HSK 3.0 oficiales (GF 0025-2021): 300 caracteres en cada nivel
       del 1 al 6 y 1,200 en 7-9, idénticos a hsk30-chars.csv.
    2. Lista oficial de escritura a mano: 300 / 400 / 500.
    3. Cada carácter tiene radical Kangxi (1-214) y los 214 radicales existen
       y se pueden practicar.
    4. Pinyin con formato válido; significados no vacíos en los caracteres HSK.
    5. Trazos y medianas se pueden leer y tienen la misma cantidad.
    6. Español: todos los caracteres HSK tienen significado en español.
    7. Ejemplos: cada ejemplo contiene su carácter, su pinyin tiene una sílaba
       por carácter chino y hay cobertura mínima en HSK.
    8. La versión de la base coincide con lib/datos/version_contenido.dart.
    9. Libros de «Leer»: el pinyin está al día (preparar_libros.py), cada
       carácter chino tiene una sílaba válida, los caracteres se pueden
       consultar en la app y los libros ADAPTADOS cumplen la cobertura
       mínima de su nivel (libros.COBERTURA_MINIMA).
"""

import csv
import json
import os
import re
import sqlite3
import sys
from collections import Counter

from construir_db import leer_cedict, silabas_validas
from pinyin_util import acentos_a_num

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(RAIZ, "assets", "db", "contenido.db")
HSK = os.path.join(RAIZ, "herramientas_datos", "fuentes", "hsk30", "hsk30-chars.csv")
VERSION_DART = os.path.join(RAIZ, "lib", "datos", "version_contenido.dart")

PERMITIR_INCOMPLETO = "--permitir-incompleto" in sys.argv
COBERTURA_MINIMA_EJEMPLOS = 0.90   # fracción de caracteres HSK con al menos 1 ejemplo

errores, avisos = [], []


def error(msg):
    errores.append(msg)


def aviso(msg):
    avisos.append(msg)


def contar_silabas(pinyin, validas):
    """
    Cuántas sílabas tiene un texto en pinyin con acentos ("wǒ xǐhuan chá." → 4).
    Cada palabra se parte en el MENOR número de sílabas válidas; None si no
    se puede partir.
    """
    total = 0
    for trozo in re.split(r"[\s'’\-·]+", pinyin.lower()):
        planas = "".join(acentos_a_num(ch)[:-1] for ch in trozo if ch.isalpha())
        if not planas:
            continue
        infinito = 10 ** 9
        mejor = [0] + [infinito] * len(planas)
        for i in range(len(planas)):
            if mejor[i] == infinito:
                continue
            for j in range(i + 1, min(len(planas), i + 6) + 1):
                if planas[i:j] in validas and mejor[i] + 1 < mejor[j]:
                    mejor[j] = mejor[i] + 1
        if mejor[-1] == infinito:
            return None
        total += mejor[-1]
    return total


def main():
    if not os.path.exists(DB):
        print(f"No existe {DB}. Corre primero construir_db.py")
        sys.exit(1)
    con = sqlite3.connect(DB)
    q = lambda sql, *a: con.execute(sql, a).fetchall()  # noqa: E731

    # 1. Niveles oficiales ────────────────────────────────────────────────
    oficial = {}
    escritura_oficial = {}
    with open(HSK, encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            oficial[fila["Hanzi"]] = 7 if fila["Level"] == "7-9" else int(fila["Level"])
            if fila["WritingLevel"]:
                escritura_oficial[fila["Hanzi"]] = int(fila["WritingLevel"])

    en_db = {c: n for c, n in q("SELECT caracter, nivel_hsk FROM caracteres WHERE nivel_hsk > 0")}
    conteo = Counter(en_db.values())
    esperado = {1: 300, 2: 300, 3: 300, 4: 300, 5: 300, 6: 300, 7: 1200}
    for nivel, n in esperado.items():
        if conteo.get(nivel, 0) != n:
            error(f"Nivel {nivel}: {conteo.get(nivel, 0)} caracteres (se esperaban {n})")
    distintos = [c for c in oficial if en_db.get(c) != oficial[c]]
    if distintos:
        error(f"{len(distintos)} caracteres con nivel distinto al oficial: {''.join(distintos[:20])}")
    sobrantes = [c for c in en_db if c not in oficial]
    if sobrantes:
        error(f"Caracteres marcados como HSK que no están en la lista oficial: {''.join(sobrantes)}")

    # 2. Escritura a mano ─────────────────────────────────────────────────
    esc = dict(q("SELECT caracter, nivel_escritura FROM caracteres WHERE nivel_escritura IS NOT NULL"))
    if esc != escritura_oficial:
        error("La lista de escritura a mano no coincide con la oficial")
    c_esc = Counter(esc.values())
    if c_esc != Counter({1: 300, 2: 400, 3: 500}):
        error(f"Escritura a mano por nivel: {dict(c_esc)} (se esperaba 300/400/500)")

    # 3. Radicales ────────────────────────────────────────────────────────
    sin_radical = q("SELECT caracter FROM caracteres WHERE radical NOT BETWEEN 1 AND 214")
    if sin_radical:
        error(f"{len(sin_radical)} caracteres sin radical válido: {sin_radical[:10]}")
    numeros = [n for (n,) in q("SELECT numero FROM radicales ORDER BY numero")]
    if numeros != list(range(1, 215)):
        error("La tabla de radicales no tiene exactamente los números 1 a 214")
    sin_practica = q("SELECT numero FROM radicales WHERE caracter_id IS NULL")
    if sin_practica:
        error(f"Radicales sin trazos para practicar: {sin_practica}")
    hsk_sin_familia = q("SELECT count(*) FROM radicales WHERE total_hsk = 0")[0][0]
    if hsk_sin_familia:
        aviso(f"{hsk_sin_familia} radicales no tienen ningún carácter HSK en su familia (normal en radicales raros)")

    # 4. Pinyin y significados ────────────────────────────────────────────
    malos = [(c, p) for c, p, n in q("SELECT caracter, pinyin_num, nivel_hsk FROM caracteres")
             if not re.fullmatch(r"[a-zv]+[1-5]", p) and n > 0]
    if malos:
        error(f"Pinyin con formato inválido en caracteres HSK: {malos[:10]}")
    vacios = q("SELECT caracter FROM caracteres WHERE nivel_hsk > 0 AND significado_en = ''")
    if vacios:
        error(f"Caracteres HSK sin significado en inglés: {vacios[:10]}")

    # 5. Trazos ───────────────────────────────────────────────────────────
    for c, s, m, n in q("SELECT caracter, trazos_svg, medianas, num_trazos FROM caracteres"):
        try:
            ls, lm = json.loads(s), json.loads(m)
        except json.JSONDecodeError:
            error(f"{c}: trazos o medianas no son JSON válido")
            continue
        if not (len(ls) == len(lm) == n > 0):
            error(f"{c}: {len(ls)} trazos, {len(lm)} medianas, num_trazos={n}")

    # 6. Español ──────────────────────────────────────────────────────────
    sin_es = [c for (c,) in q("SELECT caracter FROM caracteres WHERE nivel_hsk > 0 "
                               "AND (significado_es IS NULL OR significado_es = '')")]
    if sin_es:
        msg = f"{len(sin_es)} de 3000 caracteres HSK sin significado en español"
        (aviso if PERMITIR_INCOMPLETO else error)(msg)

    # 7. Ejemplos ─────────────────────────────────────────────────────────
    for c, chino in q("SELECT c.caracter, e.chino FROM ejemplos e JOIN caracteres c ON c.id = e.caracter_id"):
        if c not in chino:
            error(f"El ejemplo «{chino}» no contiene {c}")
    validas = silabas_validas(leer_cedict())
    han = re.compile("[\u3400-\u9fff]")
    desparejos = [(chino, pinyin) for chino, pinyin in q("SELECT DISTINCT chino, pinyin FROM ejemplos")
                  if contar_silabas(pinyin, validas) != len(han.findall(chino))]
    if desparejos:
        error(f"{len(desparejos)} ejemplos con pinyin incompleto o de más, p. ej.: {desparejos[:3]}")
    con_ejemplo = q("SELECT count(DISTINCT e.caracter_id) FROM ejemplos e "
                    "JOIN caracteres c ON c.id = e.caracter_id WHERE c.nivel_hsk > 0")[0][0]
    cobertura = con_ejemplo / 3000
    sin_traducir = q("SELECT count(*) FROM ejemplos WHERE espanol IS NULL OR espanol = ''")[0][0]
    if cobertura < COBERTURA_MINIMA_EJEMPLOS:
        msg = f"Solo {con_ejemplo} de 3000 caracteres HSK tienen ejemplos ({cobertura:.0%})"
        (aviso if PERMITIR_INCOMPLETO else error)(msg)
    if sin_traducir:
        msg = f"{sin_traducir} ejemplos sin traducción al español"
        (aviso if PERMITIR_INCOMPLETO else error)(msg)

    # 9. Libros ──────────────────────────────────────────────────────────
    import libros as L
    existentes = {c for (c,) in q("SELECT caracter FROM caracteres")}
    try:
        fuentes_libros = {l["clave"]: l for l in L.todos_los_libros()}
    except L.ErrorLibro as e:
        error(f"Libro mal escrito: {e}")
        fuentes_libros = {}
    generado = json.load(open(L.GENERADO, encoding="utf-8")) if os.path.exists(L.GENERADO) else {}
    for clave, libro in fuentes_libros.items():
        if generado.get(clave, {}).get("huella") != libro["huella"]:
            error(f"El pinyin de {libro['archivo']} no está al día: corre preparar_libros.py")
    en_db_libros = {clave: (nivel, tipo, cob) for clave, nivel, tipo, cob in
                    q("SELECT clave, nivel_hsk, tipo, cobertura FROM libros")}
    if set(en_db_libros) != set(fuentes_libros):
        error("Los libros de la base no coinciden con las fuentes (vuelve a correr construir_db.py)")
    for clave, (nivel, tipo, cob) in en_db_libros.items():
        if tipo == "adaptado" and cob < L.COBERTURA_MINIMA:
            error(f"Libro {clave} (HSK {nivel}): cobertura {cob:.1%} < {L.COBERTURA_MINIMA:.0%}")
    total_parrafos = 0
    for clave, chino, pinyin_json in q(
            "SELECT l.clave, p.chino, p.pinyin FROM parrafos p "
            "JOIN capitulos c ON c.id = p.capitulo_id JOIN libros l ON l.id = c.libro_id"):
        total_parrafos += 1
        silabas = json.loads(pinyin_json)
        if len(silabas) != len(chino):
            error(f"Libro {clave}: pinyin desalineado en «{chino[:15]}…»")
            continue
        for c, sil in zip(chino, silabas):
            if not L.es_han(c):
                continue
            plana = re.sub(r"\d", "", acentos_a_num(sil)) if sil else ""
            if plana not in validas:
                error(f"Libro {clave}: «{c}» con pinyin inválido {sil!r} en «{chino[:15]}…»")
            if c not in existentes:
                (aviso if en_db_libros.get(clave, (0, "original"))[1] == "original" else error)(
                    f"Libro {clave}: «{c}» no está en la base (no se podrá consultar)")

    # 9b. Preguntas de comprensión: tres por capítulo, cuatro opciones
    # distintas en cada idioma y la correcta dentro de rango.
    sin_preguntas = [f"{clave} {orden}" for clave, orden in q(
        "SELECT l.clave, c.orden FROM capitulos c JOIN libros l ON l.id = c.libro_id "
        "WHERE (SELECT count(*) FROM preguntas p WHERE p.capitulo_id = c.id) < 3")]
    if sin_preguntas:
        error(f"Capítulos con menos de 3 preguntas de comprensión: {sin_preguntas[:5]}")
    total_preguntas = 0
    for pid, pes, pen, oes, oen, correcta in q(
            "SELECT id, pregunta_es, pregunta_en, opciones_es, opciones_en, correcta FROM preguntas"):
        total_preguntas += 1
        oes, oen = json.loads(oes), json.loads(oen)
        if not pes.strip() or not pen.strip():
            error(f"Pregunta {pid}: texto vacío")
        if len(oes) != 4 or len(oen) != 4 or len(set(oes)) != 4 or len(set(oen)) != 4:
            error(f"Pregunta {pid}: se esperaban cuatro opciones distintas por idioma")
        if not 0 <= correcta < 4:
            error(f"Pregunta {pid}: respuesta correcta fuera de rango ({correcta})")

    # 10. Vocabulario ─────────────────────────────────────────────────────
    por_nivel = dict(q("SELECT nivel_hsk, count(*) FROM palabras GROUP BY nivel_hsk"))
    if sum(por_nivel.values()) < 10500:
        error(f"Solo {sum(por_nivel.values())} palabras HSK en la tabla palabras (se esperaban ~10,900)")
    sin_es_pal = q("SELECT count(*) FROM palabras WHERE nivel_hsk <= 6 AND (significado_es IS NULL OR significado_es = '')")[0][0]
    if sin_es_pal:
        msg = f"{sin_es_pal} palabras de HSK 1-6 sin significado en español"
        (aviso if PERMITIR_INCOMPLETO else error)(msg)
    malas = []
    for palabra, pinyin_num in q("SELECT palabra, pinyin_num FROM palabras"):
        silabas = pinyin_num.split()
        if len(silabas) != len(palabra):
            malas.append(palabra)
            continue
        for c, sil in zip(palabra, silabas):
            if sil == "_":
                if c != "儿":
                    malas.append(palabra)
            elif re.sub(r"\d", "", sil) not in validas or not re.search(r"[1-5]$", sil):
                malas.append(palabra)
    if malas:
        error(f"{len(malas)} palabras con pinyin_num mal alineado, p. ej.: {malas[:5]}")
    total_palabras = sum(por_nivel.values())

    # 8. Versión ──────────────────────────────────────────────────────────
    version_db = q("SELECT valor FROM meta WHERE clave = 'version'")[0][0]
    texto = open(VERSION_DART, encoding="utf-8").read() if os.path.exists(VERSION_DART) else ""
    if f"'{version_db}'" not in texto:
        error("lib/datos/version_contenido.dart no coincide con la base (vuelve a correr construir_db.py)")

    # ── Resultado ────────────────────────────────────────────────────────
    total = q("SELECT count(*) FROM caracteres")[0][0]
    print(f"contenido.db versión {version_db}: {total} caracteres, "
          f"{len(en_db)} HSK, {con_ejemplo} con ejemplos, {3000 - len(sin_es)} con español, "
          f"{len(en_db_libros)} libros ({total_parrafos} párrafos, {total_preguntas} preguntas), "
          f"{total_palabras} palabras")
    for a in avisos:
        print("  AVISO:", a)
    for e in errores:
        print("  ERROR:", e)
    if errores:
        print(f"✗ {len(errores)} errores")
        sys.exit(1)
    print("✓ La base cumple con todo lo revisado")


if __name__ == "__main__":
    main()

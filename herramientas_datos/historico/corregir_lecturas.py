"""
corregir_lecturas.py
────────────────────
Corrige pinyin y significados mal elegidos al fusionar CC-CEDICT.

Problema: CC-CEDICT tiene varias entradas por carácter simplificado
(p. ej. 吃 viene de 吃 y de 喫). Al eliminar el tradicional, se quedó la
ÚLTIMA entrada, que muchas veces es "variant of...", "see...", un apellido
o una lectura arcaica. Ejemplos antes de corregir:
    吃  chi1  "variant of 吃[chi1]"
    大  dai4  "see 大夫[dai4 fu5]"
    女  ru3   "old variant of 汝[ru3]"

Qué hace:
1. Marca como "sospechosa" una entrada si su significado está vacío o empieza
   con variant/see/surname/used in..., o si su pinyin es de apellido (mayúscula).
2. Para esas entradas elige la mejor lectura de CC-CEDICT (minúscula, no
   variante, con más acepciones) y reemplaza pinyin y significado.
3. Normaliza "u:" → "v" en el pinyin (el helper de la app lo muestra como ü).
4. Corrige el radical de 月: es el 74 (luna), no el 130 (carne, 肉/⺼).

Solo toca las entradas sospechosas; el resto queda igual.

Uso (desde la raíz del proyecto):
    python herramientas_datos/corregir_lecturas.py
Después: desinstala la app del teléfono para que la base de datos se regenere.
"""

import json
import os
import re
import sys
from collections import defaultdict

RUTA_JSON = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_CEDICT = os.path.join("herramientas_datos", "cedict_ts.u8")
RUTA_REPORTE = os.path.join("herramientas_datos", "reporte_corregir_lecturas.txt")

MALO = re.compile(
    r"^(variant of|old variant of|japanese variant of|archaic variant of|"
    r"erhua variant of|see |used in|surname|\(archaic\)|\(old\)|abbr\. for)",
    re.IGNORECASE,
)
LINEA = re.compile(r"^(\S+) (\S+) \[([^\]]+)\] /(.*)/\s*$")


def es_malo(pinyin: str, significado: str) -> bool:
    if not significado or not significado.strip():
        return True
    if MALO.match(significado.strip()):
        return True
    if pinyin and pinyin[:1].isupper():
        return True
    return False


def formatear_significado(crudo: str) -> str:
    partes = []
    for p in crudo.split("/"):
        p = p.strip()
        if not p or p.startswith("CL:"):
            continue
        partes.append(p.replace("; ", ", "))
    return ", ".join(partes)


def normalizar_pinyin(p: str) -> str:
    return p.replace("u:", "v").replace("U:", "V").strip()


def cargar_cedict(ruta):
    entradas = defaultdict(list)
    with open(ruta, encoding="utf-8") as f:
        for i, linea in enumerate(f):
            if linea.startswith("#"):
                continue
            m = LINEA.match(linea.rstrip("\n"))
            if not m:
                continue
            trad, simp, pinyin, sig = m.groups()
            if len(simp) != 1:  # solo caracteres sueltos
                continue
            entradas[simp].append((i, pinyin, sig))
    return entradas


def puntaje(entrada):
    """Menor es mejor."""
    orden, pinyin, sig = entrada
    s = 0
    if pinyin[:1].isupper():
        s += 100
    if MALO.match(sig):
        s += 50
    return (s, -len(sig), orden)


def main():
    if not os.path.exists(RUTA_JSON) or not os.path.exists(RUTA_CEDICT):
        sys.exit("Ejecuta este script desde la raíz del proyecto hanzi_dojo.")

    with open(RUTA_JSON, encoding="utf-8") as f:
        datos = json.load(f)
    cedict = cargar_cedict(RUTA_CEDICT)

    cambios, sin_solucion, uv = [], [], 0
    for item in datos:
        c = item.get("caracter", "")
        pin = item.get("pinyin", "") or ""
        sig = item.get("significado", "") or ""

        if "u:" in pin or "U:" in pin:
            item["pinyin"] = normalizar_pinyin(pin)
            uv += 1

        if not es_malo(pin, sig):
            continue
        candidatos = sorted(cedict.get(c, []), key=puntaje)
        if not candidatos:
            sin_solucion.append((c, pin, sig))
            continue
        _, mejor_pin, mejor_sig = candidatos[0]
        if es_malo(mejor_pin, mejor_sig):
            sin_solucion.append((c, pin, sig))
            continue
        nuevo_pin = normalizar_pinyin(mejor_pin)
        nuevo_sig = formatear_significado(mejor_sig)
        cambios.append((item.get("nivel_hsk", 7), c, pin, sig, nuevo_pin, nuevo_sig))
        item["pinyin"] = nuevo_pin
        item["significado"] = nuevo_sig

    # 月 = radical 74 (luna). 肉 (130) se queda como está.
    radical_74 = False
    for item in datos:
        if item.get("caracter") == "月":
            item["es_radical"] = True
            item["numero_radical"] = 74
            radical_74 = True

    # indent=2 conserva el formato original, así el diff de git solo muestra
    # las líneas que cambiaron.
    with open(RUTA_JSON, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)

    cambios.sort()
    lineas = [
        "REPORTE corregir_lecturas.py",
        f"Entradas totales: {len(datos)}",
        f"Corregidas (pinyin + significado): {len(cambios)}",
        f"Pinyin con u: normalizado a v: {uv}",
        f"Sospechosas sin mejor opción en CC-CEDICT: {len(sin_solucion)}",
        f"月 marcado como radical 74: {'sí' if radical_74 else 'no encontrado'}",
        "",
        "Por nivel HSK:",
    ]
    por_nivel = defaultdict(int)
    for n, *_ in cambios:
        por_nivel[n] += 1
    for n in sorted(por_nivel):
        lineas.append(f"  HSK {n}: {por_nivel[n]}")
    lineas += ["", "CAMBIOS (nivel | carácter | antes → después)"]
    for n, c, p0, s0, p1, s1 in cambios:
        lineas.append(f"{n} | {c} | {p0} «{s0[:50]}» → {p1} «{s1[:60]}»")
    lineas += ["", "SIN SOLUCIÓN AUTOMÁTICA (revisar a mano)"]
    for c, p, s in sin_solucion:
        lineas.append(f"{c} | {p} «{s[:70]}»")

    with open(RUTA_REPORTE, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas) + "\n")
    print("\n".join(lineas[:15]))
    print(f"\nReporte completo: {RUTA_REPORTE}")


if __name__ == "__main__":
    main()

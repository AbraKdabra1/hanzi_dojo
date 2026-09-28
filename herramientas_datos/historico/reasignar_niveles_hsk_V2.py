"""
reasignar_niveles_hsk_v2.py
───────────────────────────
Versión corregida que maneja:
- Términos con variantes separadas por | (ej: 爸爸|爸)
- Palabras compuestas (extrae cada carácter individual)
- Caracteres sin nivel HSK → se mueven a nivel 7
- Actualiza campo tradicional donde está vacío

Uso:
    python reasignar_niveles_hsk_v2.py
"""

import json
import csv
import os

# ─── Rutas ────────────────────────────────────────────────────────────────────
RUTA_CSV     = "hsk30.csv"
RUTA_JSON    = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_SALIDA  = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_REPORTE = "reporte_niveles_hsk_v2.txt"

# ─── Helpers ──────────────────────────────────────────────────────────────────
def es_hanzi(c):
    """Devuelve True si el carácter es un hanzi CJK."""
    return '\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf'

def extraer_hanzi(texto):
    """Extrae todos los hanzi individuales de un string."""
    return [c for c in texto if es_hanzi(c)]

def parsear_nivel(nivel_raw):
    """Convierte el nivel del CSV a int. '7-9' → 7."""
    if nivel_raw.strip() == "7-9":
        return 7
    try:
        return int(nivel_raw.strip())
    except ValueError:
        return None

# ─── Leer CSV ─────────────────────────────────────────────────────────────────
def leer_hsk_csv(ruta):
    """
    Construye:
    - char_a_nivel:      hanzi → nivel más bajo en que aparece
    - char_a_tradicional: hanzi simplificado → tradicional (solo 1 char)
    """
    char_a_nivel       = {}
    char_a_tradicional = {}

    with open(ruta, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            simplified  = row.get("Simplified", "").strip()
            traditional = row.get("Traditional", "").strip()
            nivel_raw   = row.get("Level", "").strip()
            variants    = row.get("Variants", "").strip()

            nivel = parsear_nivel(nivel_raw)
            if nivel is None:
                continue

            # ── Manejar variantes separadas por | ─────────────────────────
            # Ej: "爸爸|爸" → procesar "爸爸" y "爸" por separado
            terminos_simp = [t.strip() for t in simplified.split("|") if t.strip()]
            terminos_trad = [t.strip() for t in traditional.split("|") if t.strip()]

            # También parsear variantes del campo JSON Variants si existe
            if variants:
                try:
                    import json as _json
                    vars_list = _json.loads(variants)
                    for v in vars_list:
                        vs = v.get("Simplified", "").strip()
                        vt = v.get("Traditional", "").strip()
                        if vs:
                            terminos_simp.append(vs)
                        if vt:
                            terminos_trad.append(vt)
                except Exception:
                    pass

            # ── Registrar cada hanzi individual ───────────────────────────
            for termino in terminos_simp:
                for char in extraer_hanzi(termino):
                    # Guardamos el nivel más bajo (más fácil) si aparece en varios
                    if char not in char_a_nivel or nivel < char_a_nivel[char]:
                        char_a_nivel[char] = nivel

            # ── Registrar tradicional (solo términos de 1 carácter) ────────
            for i, ts in enumerate(terminos_simp):
                if len(ts) == 1 and es_hanzi(ts):
                    if i < len(terminos_trad):
                        tt = terminos_trad[i]
                        if len(tt) == 1 and tt != ts:
                            char_a_tradicional[ts] = tt

    return char_a_nivel, char_a_tradicional

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("📖 Leyendo hsk30.csv...")
    char_a_nivel, char_a_tradicional = leer_hsk_csv(RUTA_CSV)
    print(f"   → {len(char_a_nivel)} hanzi individuales con nivel HSK 3.0")
    print(f"   → {len(char_a_tradicional)} con forma tradicional distinta")

    print("\n📖 Leyendo JSON...")
    with open(RUTA_JSON, "r", encoding="utf-8") as f:
        datos = json.load(f)
    print(f"   → {len(datos)} entradas")

    # Contadores
    conteo_antes   = {}
    conteo_despues = {}
    reasignados    = 0
    a_nivel_7      = 0
    trad_actualizados = 0

    for entrada in datos:
        simp         = entrada.get("simplificado", "")
        nivel_actual = entrada.get("nivel", 10)

        conteo_antes[nivel_actual] = conteo_antes.get(nivel_actual, 0) + 1

        # ── Reasignar nivel ───────────────────────────────────────────────
        if nivel_actual == 10:
            if simp in char_a_nivel:
                nuevo_nivel = char_a_nivel[simp]
                entrada["nivel"] = nuevo_nivel
                entrada["hsk_nivel_oficial"] = str(nuevo_nivel)
                reasignados += 1
            else:
                # Sin nivel HSK → nivel 7 (avanzado/clásico)
                entrada["nivel"] = 7
                entrada["hsk_nivel_oficial"] = "7"
                a_nivel_7 += 1

        # ── Actualizar tradicional ────────────────────────────────────────
        trad_actual = entrada.get("tradicional", "")
        if simp in char_a_tradicional:
            nuevo_trad = char_a_tradicional[simp]
            if not trad_actual or trad_actual == simp:
                entrada["tradicional"] = nuevo_trad
                trad_actualizados += 1

        nivel_final = entrada.get("nivel", 7)
        conteo_despues[nivel_final] = conteo_despues.get(nivel_final, 0) + 1

    # ── Guardar ───────────────────────────────────────────────────────────────
    print(f"\n💾 Guardando JSON...")
    with open(RUTA_SALIDA, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)

    # ── Reporte ───────────────────────────────────────────────────────────────
    lineas = []
    lineas.append("=" * 60)
    lineas.append("REPORTE DE REASIGNACIÓN HSK 3.0 — v2")
    lineas.append("=" * 60)
    lineas.append(f"Total entradas:             {len(datos)}")
    lineas.append(f"Reasignados a nivel HSK:    {reasignados}")
    lineas.append(f"Movidos a HSK 7 (clásicos): {a_nivel_7}")
    lineas.append(f"Tradicional actualizado:    {trad_actualizados}")
    lineas.append(f"Nivel 10 restantes:         0 ✅")
    lineas.append("")
    lineas.append("Distribución ANTES:")
    for n in sorted(conteo_antes.keys()):
        label = f"HSK {n}" if n < 10 else "Sin nivel (10)"
        lineas.append(f"  {label:22} {conteo_antes[n]:>5}")
    lineas.append("")
    lineas.append("Distribución DESPUÉS:")
    for n in sorted(conteo_despues.keys()):
        label = f"HSK {n}" if n < 10 else "Sin nivel (10)"
        lineas.append(f"  {label:22} {conteo_despues[n]:>5}")
    lineas.append("=" * 60)

    reporte = "\n".join(lineas)
    print("\n" + reporte)

    with open(RUTA_REPORTE, "w", encoding="utf-8") as f:
        f.write(reporte)

    print(f"\n📁 Reporte: {RUTA_REPORTE}")
    print(f"📁 JSON:    {RUTA_SALIDA}")
    print("\n⚠️  Pasos siguientes:")
    print("   1. python marcar_radicales.py")
    print("   2. Desinstalar app del teléfono")
    print("   3. flutter run")

if __name__ == "__main__":
    main()
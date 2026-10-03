"""
reasignar_niveles_hsk.py
────────────────────────
Usa hsk30.csv (ivankra/hsk30) para reasignar correctamente los niveles
HSK 3.0 a todos los caracteres del diccionario de Hanzi Dojo.

Pasos:
1. Lee hsk30.csv y construye mapa carácter → nivel
2. Lee el JSON actual
3. Reasigna nivel a los que están en nivel 10 y aparecen en el CSV
4. También actualiza tradicional si el CSV lo tiene
5. Guarda JSON actualizado
6. Genera reporte

Uso:
    python reasignar_niveles_hsk.py
Coloca este script en la raíz junto a hsk30.csv y la carpeta assets/
"""

import json
import csv
import os

# ─── Rutas ────────────────────────────────────────────────────────────────────
RUTA_CSV    = "hsk30.csv"
RUTA_JSON   = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_SALIDA = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_REPORTE = "reporte_niveles_hsk.txt"

# ─── Leer hsk30.csv ───────────────────────────────────────────────────────────
def leer_hsk_csv(ruta):
    """
    Devuelve dos diccionarios:
    - char_a_nivel:      carácter simplificado → nivel (int, 7 para 7-9)
    - char_a_tradicional: carácter simplificado → tradicional
    """
    char_a_nivel       = {}
    char_a_tradicional = {}

    with open(ruta, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            simplified   = row.get("Simplified", "").strip()
            traditional  = row.get("Traditional", "").strip()
            nivel_raw    = row.get("Level", "").strip()

            if not simplified:
                continue

            # Convertir nivel: "7-9" → 7, resto → int
            if nivel_raw == "7-9":
                nivel = 7
            else:
                try:
                    nivel = int(nivel_raw)
                except ValueError:
                    continue

            # Algunos términos son palabras (多个字), tomamos cada carácter
            for char in simplified:
                if '\u4e00' <= char <= '\u9fff' or '\u3400' <= char <= '\u4dbf':
                    if char not in char_a_nivel:
                        char_a_nivel[char] = nivel

            # Para el tradicional, solo si el término es un solo carácter
            if len(simplified) == 1 and traditional and traditional != simplified:
                char_a_tradicional[simplified] = traditional

    return char_a_nivel, char_a_tradicional

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("📖 Leyendo hsk30.csv...")
    char_a_nivel, char_a_tradicional = leer_hsk_csv(RUTA_CSV)
    print(f"   → {len(char_a_nivel)} caracteres con nivel HSK 3.0")
    print(f"   → {len(char_a_tradicional)} caracteres con tradicional conocido")

    print("\n📖 Leyendo JSON...")
    with open(RUTA_JSON, "r", encoding="utf-8") as f:
        datos = json.load(f)
    print(f"   → {len(datos)} entradas en el JSON")

    # Contadores
    reasignados       = 0
    tradicional_actualizado = 0
    conteo_antes      = {}
    conteo_despues    = {}
    sin_nivel_hsk     = 0

    for entrada in datos:
        simp  = entrada.get("simplificado", "")
        nivel_actual = entrada.get("nivel", 10)

        # Contar distribución antes
        conteo_antes[nivel_actual] = conteo_antes.get(nivel_actual, 0) + 1

        # Reasignar nivel si está en nivel 10 y el CSV lo conoce
        if nivel_actual == 10 and simp in char_a_nivel:
            nuevo_nivel = char_a_nivel[simp]
            entrada["nivel"] = nuevo_nivel
            entrada["hsk_nivel_oficial"] = str(nuevo_nivel)
            reasignados += 1
        elif nivel_actual == 10:
            sin_nivel_hsk += 1

        # Actualizar tradicional si lo tenemos y está vacío o igual al simplificado
        trad_actual = entrada.get("tradicional", "")
        if simp in char_a_tradicional:
            nuevo_trad = char_a_tradicional[simp]
            if trad_actual == "" or trad_actual == simp:
                entrada["tradicional"] = nuevo_trad
                tradicional_actualizado += 1

        # Contar distribución después
        nivel_final = entrada.get("nivel", 10)
        conteo_despues[nivel_final] = conteo_despues.get(nivel_final, 0) + 1

    # ─── Guardar ──────────────────────────────────────────────────────────────
    print(f"\n💾 Guardando JSON actualizado...")
    with open(RUTA_SALIDA, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)

    # ─── Reporte ──────────────────────────────────────────────────────────────
    lineas = []
    lineas.append("=" * 60)
    lineas.append("REPORTE DE REASIGNACIÓN DE NIVELES HSK 3.0")
    lineas.append("=" * 60)
    lineas.append(f"Total de entradas:          {len(datos)}")
    lineas.append(f"Reasignados a nivel correcto: {reasignados}")
    lineas.append(f"Tradicional actualizado:    {tradicional_actualizado}")
    lineas.append(f"Sin nivel HSK (nivel 10):   {sin_nivel_hsk}")
    lineas.append("")
    lineas.append("Distribución ANTES:")
    for nivel in sorted(conteo_antes.keys()):
        label = f"HSK {nivel}" if nivel < 10 else "Sin nivel (10)"
        lineas.append(f"  {label:20} {conteo_antes[nivel]:>5}")
    lineas.append("")
    lineas.append("Distribución DESPUÉS:")
    for nivel in sorted(conteo_despues.keys()):
        label = f"HSK {nivel}" if nivel < 10 else "Sin nivel (10)"
        lineas.append(f"  {label:20} {conteo_despues[nivel]:>5}")
    lineas.append("=" * 60)

    reporte = "\n".join(lineas)
    print("\n" + reporte)

    with open(RUTA_REPORTE, "w", encoding="utf-8") as f:
        f.write(reporte)

    print(f"\n📁 Reporte guardado en: {RUTA_REPORTE}")
    print(f"📁 JSON guardado en:    {RUTA_SALIDA}")
    print("\n⚠️  Recuerda:")
    print("   1. Correr marcar_radicales.py de nuevo")
    print("   2. Desinstalar la app del teléfono")
    print("   3. Correr flutter run para reconstruir la DB")

if __name__ == "__main__":
    main()
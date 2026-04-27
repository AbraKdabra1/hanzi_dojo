import json, csv, os

# Cargar hanzi_dojo.json
with open(os.path.join("assets", "hanzi_dojo.json"), "r", encoding="utf-8") as f:
    datos = json.load(f)

chars_en_db = {e["caracter"] for e in datos}

# Cargar hsk30.csv
faltantes_por_nivel = {}
with open("hsk30.csv", "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        nivel_raw = row.get("Level", "").strip()
        nivel = 7 if nivel_raw == "7-9" else int(nivel_raw) if nivel_raw.isdigit() else None
        if nivel is None or nivel > 6:
            continue
        simplified = row.get("Simplified", "").strip()
        for variante in simplified.split("|"):
            for char in variante.strip():
                if '\u4e00' <= char <= '\u9fff':
                    if char not in chars_en_db:
                        if nivel not in faltantes_por_nivel:
                            faltantes_por_nivel[nivel] = set()
                        faltantes_por_nivel[nivel].add(char)

for nivel in sorted(faltantes_por_nivel.keys()):
    chars = faltantes_por_nivel[nivel]
    print(f"HSK {nivel} — faltan {len(chars)}: {''.join(sorted(chars))}")
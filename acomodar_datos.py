import json, csv, os

with open(os.path.join("assets", "hanzi_dojo.json"), "r", encoding="utf-8") as f:
    datos = json.load(f)

# Índice: caracter → entrada
char_a_entrada = {e["caracter"]: e for e in datos}

# Leer nivel correcto del CSV
char_a_nivel_correcto = {}
with open("hsk30.csv", "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        nivel_raw = row.get("Level", "").strip()
        nivel = 7 if nivel_raw == "7-9" else int(nivel_raw) if nivel_raw.isdigit() else None
        if nivel is None:
            continue
        simplified = row.get("Simplified", "").strip()
        for variante in simplified.split("|"):
            for char in variante.strip():
                if '\u4e00' <= char <= '\u9fff':
                    if char not in char_a_nivel_correcto or nivel < char_a_nivel_correcto[char]:
                        char_a_nivel_correcto[char] = nivel

# Encontrar mal asignados
mal_asignados = {}
for char, nivel_correcto in char_a_nivel_correcto.items():
    if char in char_a_entrada:
        nivel_actual = char_a_entrada[char]["nivel_hsk"]
        if nivel_actual != nivel_correcto:
            if nivel_correcto not in mal_asignados:
                mal_asignados[nivel_correcto] = []
            mal_asignados[nivel_correcto].append((char, nivel_actual, nivel_correcto))

print("Caracteres con nivel incorrecto:")
total = 0
for nivel in sorted(mal_asignados.keys()):
    chars = mal_asignados[nivel]
    total += len(chars)
    print(f"\nDeberían ser HSK {nivel} ({len(chars)} caracteres):")
    print("".join(c[0] for c in chars))

print(f"\nTotal mal asignados: {total}")

# Corregir automáticamente
print("\n¿Corregir niveles en hanzi_dojo.json? (s/n): ", end="")
respuesta = input().strip().lower()
if respuesta == "s":
    corregidos = 0
    for char, nivel_actual, nivel_correcto in [item for lista in mal_asignados.values() for item in lista]:
        if char in char_a_entrada:
            char_a_entrada[char]["nivel_hsk"] = nivel_correcto
            corregidos += 1
    
    with open(os.path.join("assets", "hanzi_dojo.json"), "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)
    
    # Verificar resultado
    from collections import Counter
    niveles = Counter(e["nivel_hsk"] for e in datos)
    print(f"\n✅ Corregidos: {corregidos}")
    print("\nDistribución final:")
    for n in sorted(niveles.keys()):
        print(f"  HSK {n}: {niveles[n]}")
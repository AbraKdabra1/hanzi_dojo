import json, os

with open(os.path.join("assets", "hanzi_dojo.json"), "r", encoding="utf-8") as f:
    datos = json.load(f)

# Mostrar todos los caracteres HSK 2
hsk2 = [e for e in datos if e.get("nivel_hsk") == 2]
print(f"Total HSK 2: {len(hsk2)}")
print("Caracteres:", "".join(e["caracter"] for e in hsk2))

# También verificar HSK 1
hsk1 = [e for e in datos if e.get("nivel_hsk") == 1]
print(f"\nTotal HSK 1: {len(hsk1)}")
print("Caracteres:", "".join(e["caracter"] for e in hsk1))
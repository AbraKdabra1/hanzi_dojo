import json, os
with open(os.path.join("assets",
    "diccionario_supercargado_completo.json"), "r",
    encoding="utf-8") as f:
    datos = json.load(f)

print(json.dumps(datos[0], ensure_ascii=False, indent=2))
import json, os

ruta = os.path.join("assets", "diccionario_supercargado_completo.json")

with open(ruta, "r", encoding="utf-8") as f:
    datos = json.load(f)

corregidos = 0
for entrada in datos:
    nivel = entrada.get("nivel", 10)
    hsk_oficial = entrada.get("hsk_nivel_oficial")
    
    # Si nivel es 10 o hsk_nivel_oficial es null/None → mover a 7
    if nivel == 10 or hsk_oficial is None or hsk_oficial == "null":
        entrada["nivel"] = 7
        entrada["hsk_nivel_oficial"] = "7"
        corregidos += 1

with open(ruta, "w", encoding="utf-8") as f:
    json.dump(datos, f, ensure_ascii=False, indent=2)

print(f"✅ Corregidos: {corregidos}")
print(f"✅ Total: {len(datos)}")
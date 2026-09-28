import json, os

ruta = os.path.join("assets", "diccionario_supercargado_completo.json")

with open(ruta, "r", encoding="utf-8") as f:
    datos = json.load(f)

# Mapa de hsk_nivel_oficial → nivel correcto
corregidos = 0
for entrada in datos:
    hsk = entrada.get("hsk_nivel_oficial")
    nivel = entrada.get("nivel", 7)
    
    # Si hsk_nivel_oficial tiene valor válido, úsalo como fuente de verdad
    if hsk is not None and str(hsk).strip() not in ["", "null", "None", "10"]:
        try:
            nivel_correcto = int(str(hsk).replace("7-9", "7").strip())
            if nivel_correcto != nivel:
                entrada["nivel"] = nivel_correcto
                corregidos += 1
        except ValueError:
            # hsk_nivel_oficial inválido → dejar nivel como está
            pass
    
    # Si nivel sigue en 10, mover a 7
    if entrada.get("nivel", 7) == 10:
        entrada["nivel"] = 7
        corregidos += 1

with open(ruta, "w", encoding="utf-8") as f:
    json.dump(datos, f, ensure_ascii=False, indent=2)

# Verificar distribución final
from collections import Counter
niveles = Counter(e.get("nivel", 7) for e in datos)
print(f"✅ Corregidos: {corregidos}")
for n in sorted(niveles.keys()):
    print(f"   Nivel {n}: {niveles[n]}")
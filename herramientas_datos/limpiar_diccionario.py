import json

archivo_entrada = "cedict_ts.u8"
archivo_salida = "diccionario_limpio.json"

hanzi_procesados = []

print("Iniciando la limpieza del diccionario...")

# Abrimos el archivo crudo para leer y uno nuevo para guardar los datos limpios
with open(archivo_entrada, "r", encoding="utf-8") as f_in:
    for linea in f_in:
        # Saltamos las líneas de comentarios y copyright que empiezan con '#'
        if linea.startswith("#"):
            continue
        
        try:
            # Separamos las partes usando los corchetes y las diagonales
            partes = linea.split(" [")
            caracteres = partes[0].split(" ")
            
            # Extraemos el tradicional, el simplificado, el pinyin y el significado
            hanzi_tradicional = caracteres[0]
            hanzi_simplificado = caracteres[1]
            pinyin_y_resto = partes[1].split("] /")
            
            pinyin = pinyin_y_resto[0]
            # Limpiamos los saltos de línea y separamos los significados
            significados = pinyin_y_resto[1].replace("/\n", "").split("/")
            
            # Guardamos todo en un formato estructurado (Diccionario de Python)
            hanzi_data = {
                "simplificado": hanzi_simplificado,
                "tradicional": hanzi_tradicional,
                "pinyin": pinyin,
                "significado": significados
            }
            
            hanzi_procesados.append(hanzi_data)
            
        except Exception as e:
            # Si una línea viene rara y falla, la ignoramos y seguimos
            continue

# Guardamos el resultado en un archivo JSON ordenado
with open(archivo_salida, "w", encoding="utf-8") as f_out:
    json.dump(hanzi_procesados, f_out, ensure_ascii=False, indent=4)

print(f"¡Limpieza terminada! Se extrajeron {len(hanzi_procesados)} caracteres.")
print(f"Datos guardados en {archivo_salida}")
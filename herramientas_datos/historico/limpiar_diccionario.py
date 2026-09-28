import json
# Definimos el nombre del archivo exacto que queremos leer
archivo_entrada = "cedict_ts.u8"
archivo_de_salida = "diccionario_clean.json"
#aquí guardaremos los 120 000 "empaques"
hanzi_procesados = []
print("Iniciando depuración del diccionario...")
# Usamos 'with open' para abrir el archivo de forma segura
# La 'r' significa Read y el encoding 'utf-8' es vital para que entienda los caracteres chinos.
with open(archivo_entrada, "r", encoding="utf-8") as archivo:
    # Le decimos a Python que lea el archivo línea por línea
    for linea in archivo:
        # 1. El filtro. Si la línea comienza con '#', sáltala y ve la siguiente línea
        if linea.startswith("#"):
            continue
        try:
            # 2. El cuchillo: Cortamos la línea justo donde está el espacio y el corchete
            partes = linea.split(" [")
            bloque_caracteres = partes[0]
            bloque_resto = partes[1]
            # Al cortar, Python crea una lista. 
            # La posición [0] tiene lo que estaba antes del corte (Los caracteres)
            # La posición [1] tiene lo que estaba después (El Pinyin y el significado)
            # 3. El segundo corte: Cortamos el bloque de caracteres por el espacio en blanco
            caracteres_separados = bloque_caracteres.split(" ")
            tradicional = caracteres_separados[0]
            simplificado = caracteres_separados[1]
            # Tercer corte: Separar pinyn de los significados
            pinyin_y_significados =bloque_resto.split("] /")
            pinyin = pinyin_y_significados[0]
            #Limpieza final de los significados
            bloque_ingles = pinyin_y_significados[1]
            bloque_ingles_limpio = bloque_ingles.replace("/\n", "")
            lista_significados = bloque_ingles_limpio.split("/")
            # Empaquetado final
            # Aquí convertimos las variables sueltas en una estructura de datos real
            hanzi_final = {
                "simplificado": simplificado,
                "tradicional": tradicional,
                "pinyin": pinyin,
                "significados": lista_significados,
            }
            #en lugar de imprimirlos los meteremos a una lita gigante
            hanzi_procesados.append(hanzi_final)
        except Exception as e:
            #Usamos 'try/except' por si hay alguna línea mal escrita en el archivo
            #así el programa simplemente la ignora y no crashea a la mitad
            continue
#al terminar el ciclo, guardamos la lista en un archivo .json real
with open(archivo_de_salida, "w", encoding="utf-8") as f_out:
    #dump convierte la lista de Python al formato estandar de JSON
    json.dump(hanzi_procesados, f_out, ensure_ascii=False, indent=4)
    print(f"¡Limpieza terminada! Se extrajeron {len(hanzi_procesados)} caracteres.")
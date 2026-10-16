import json
import os

def auditar_y_fusionar():
    ruta_json = 'diccionario_limpio.json'
    ruta_graphics = 'graphics.txt'
    ruta_salida_json = 'diccionario_supercargado.json'
    ruta_salida_txt = 'hanzi_sin_mapeo.txt'

    print("1. Extrayendo vectores geométricos de graphics.txt...")
    graficos = {}
    with open(ruta_graphics, 'r', encoding='utf-8') as f:
        for linea in f:
            if linea.strip():
                # Cada línea de graphics.txt es un mini-diccionario JSON
                dato = json.loads(linea)
                graficos[dato['character']] = {
                    'strokes': dato['strokes'],
                    'medians': dato['medians']
                }
    print(f"   -> ¡Se cargaron {len(graficos)} mapas vectoriales!")

    print("2. Leyendo tu diccionario principal...")
    with open(ruta_json, 'r', encoding='utf-8') as f:
        diccionario = json.load(f)

    supercargado = []
    sin_mapeo = []

    print("3. Iniciando la auditoría de coincidencias...")
    for item in diccionario:
        # Usamos el simplificado como llave principal de búsqueda
        caracter = item.get('simplificado', '')
        
        # Si el Hanzi existe en nuestra bóveda de vectores...
        if caracter in graficos:
            # Le inyectamos su ADN geométrico
            item['strokes'] = graficos[caracter]['strokes']
            item['medians'] = graficos[caracter]['medians']
            supercargado.append(item)
        else:
            # Si no tiene trazos, lo anotamos en la lista negra
            sin_mapeo.append(caracter)

    print("4. Escribiendo archivos de salida...")
    
    # Guardamos el nuevo diccionario élite (con identación para que sea legible)
    with open(ruta_salida_json, 'w', encoding='utf-8') as f:
        json.dump(supercargado, f, ensure_ascii=False, indent=2)

    # Guardamos el reporte de los descartados
    with open(ruta_salida_txt, 'w', encoding='utf-8') as f:
        f.write("Hanzi eliminados por no tener mapa de trazos:\n")
        f.write("-" * 50 + "\n")
        for char in sin_mapeo:
            f.write(char + '\n')

    print("\n" + "="*30)
    print("      REPORTE DE AUDITORÍA")
    print("="*30)
    print(f"Total de Hanzis procesados: {len(diccionario)}")
    print(f"Aprobados (Supercargados):  {len(supercargado)}")
    print(f"Descartados (En el .txt):   {len(sin_mapeo)}")
    print("="*30)
    print("¡Generación exitosa! Tu nueva base de datos premium está lista.")

if __name__ == '__main__':
    auditar_y_fusionar()
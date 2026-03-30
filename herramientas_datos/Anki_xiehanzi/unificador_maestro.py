import json
import csv
import os
import glob
import re

# Nombres de archivos
ARCHIVO_JSON_ENTRADA = 'diccionario_supercargado.json'
ARCHIVO_JSON_SALIDA = 'diccionario_supercargado_completo.json'
ARCHIVO_ORACIONES = 'cmn_sen_db_2.tsv'
MAX_EJEMPLOS_PER_HANZI = 3

def unificar_datos():
    print("=== INICIANDO PIPELINE DE DATOS HANZI DOJO ===")

    # ---------------------------------------------------------
    # FASE 0: CARGAR EL DICCIONARIO BASE
    # ---------------------------------------------------------
    if not os.path.exists(ARCHIVO_JSON_ENTRADA):
        print(f"❌ Error: No se encontró {ARCHIVO_JSON_ENTRADA}.")
        return

    with open(ARCHIVO_JSON_ENTRADA, 'r', encoding='utf-8') as f:
        diccionario_actual = json.load(f)

    mapa_hanzi = {}
    for item in diccionario_actual:
        if 'simplificado' in item:
            # Inicializamos las listas vacías para evitar errores de llave después
            item['ejemplos_anki'] = []
            item['vocabulario_relacionado'] = []
            item['oraciones_ejemplo'] = []
            mapa_hanzi[item['simplificado']] = item

    print(f"✅ Diccionario base cargado: {len(mapa_hanzi)} caracteres encontrados.")

    # ---------------------------------------------------------
    # FASE 1: INYECTAR NIVELES Y DEFINICIONES (Archivos .txt)
    # ---------------------------------------------------------
    print("\n[Fase 1] Procesando niveles HSK y definiciones Anki...")
    archivos_txt = glob.glob('HSK_Level_*.txt')
    
    for archivo in archivos_txt:
        with open(archivo, 'r', encoding='utf-8') as f:
            lector = csv.reader(f, delimiter='\t')
            for fila in lector:
                if len(fila) < 8: continue
                
                hanzi_txt = fila[0].strip()
                nivel_limpio = fila[4].strip().split('（')[0] if '（' in fila[4] else fila[4].strip()
                html_content = fila[7]

                if hanzi_txt in mapa_hanzi:
                    nodo = mapa_hanzi[hanzi_txt]
                    nodo['hsk_nivel_oficial'] = nivel_limpio
                    nodo['audio_config'] = {
                        "metodo": "tts",
                        "texto_tts": hanzi_txt,
                        "ruta_futura_local": f"assets/audio/cmn-{hanzi_txt}.mp3"
                    }

                    extracciones = re.findall(r'<li>(.*?)</li>', html_content)
                    for extraccion in extracciones:
                        texto_limpio = re.sub(r'<[^>]+>', '', extraccion).strip()
                        if texto_limpio and not any(e.get('texto') == texto_limpio for e in nodo['ejemplos_anki']):
                            nodo['ejemplos_anki'].append({"texto": texto_limpio})

    # ---------------------------------------------------------
    # FASE 2: INYECTAR VOCABULARIO RELACIONADO (Archivos .tsv)
    # ---------------------------------------------------------
    print("[Fase 2] Procesando red de vocabulario cruzado...")
    archivos_tsv_vocab = glob.glob('HSK *.tsv')
    palabras_inyectadas = 0

    for archivo in archivos_tsv_vocab:
        with open(archivo, 'r', encoding='utf-8') as f:
            lector = csv.reader(f, delimiter='\t')
            for fila in lector:
                if len(fila) < 4: continue
                
                palabra_trad = fila[0].strip()
                palabra_simp = fila[1].strip()
                pinyin = fila[2].strip()
                definicion = fila[3].strip()

                if not palabra_simp: continue

                for caracter in palabra_simp:
                    if caracter in mapa_hanzi:
                        nodo = mapa_hanzi[caracter]
                        es_duplicado = any(v.get('palabra') == palabra_simp for v in nodo['vocabulario_relacionado'])
                        
                        if palabra_simp != caracter and not es_duplicado:
                            nodo['vocabulario_relacionado'].append({
                                "palabra": palabra_simp,
                                "tradicional": palabra_trad if palabra_trad != palabra_simp else None,
                                "pinyin": pinyin,
                                "definicion_ingles": definicion
                            })
                            palabras_inyectadas += 1

    print(f"  -> {palabras_inyectadas} conexiones de vocabulario creadas.")

    # ---------------------------------------------------------
    # FASE 3: INYECTAR ORACIONES DE CONTEXTO (cmn_sen_db_2.tsv)
    # ---------------------------------------------------------
    print(f"[Fase 3] Procesando oraciones reales desde {ARCHIVO_ORACIONES}...")
    if os.path.exists(ARCHIVO_ORACIONES):
        with open(ARCHIVO_ORACIONES, 'r', encoding='utf-8') as f:
            lector = csv.reader(f, delimiter='\t')
            oraciones_inyectadas = 0

            for fila in lector:
                if len(fila) < 5: continue
                
                oracion_simp = fila[1].strip()
                oracion_trad = fila[2].strip()
                pinyin_oracion = fila[3].strip()
                traduccion = fila[4].strip()

                caracteres_vistos = set()
                for caracter in oracion_simp:
                    if caracter in mapa_hanzi and caracter not in caracteres_vistos:
                        caracteres_vistos.add(caracter)
                        nodo = mapa_hanzi[caracter]
                        
                        if len(nodo['oraciones_ejemplo']) < MAX_EJEMPLOS_PER_HANZI:
                            nodo['oraciones_ejemplo'].append({
                                "oracion_simp": oracion_simp,
                                "oracion_trad": oracion_trad,
                                "pinyin": pinyin_oracion,
                                "traduccion_ingles": traduccion
                            })
                            oraciones_inyectadas += 1
        print(f"  -> {oraciones_inyectadas} oraciones distribuidas en los Hanzi.")
    else:
        print(f"⚠️ Advertencia: No se encontró {ARCHIVO_ORACIONES}. Se omitió la Fase 3.")

    # ---------------------------------------------------------
    # FASE 4: GUARDAR EL ARCHIVO FINAL
    # ---------------------------------------------------------
    print("\n[Fase 4] Empaquetando y guardando JSON final...")
    diccionario_final = list(mapa_hanzi.values())

    with open(ARCHIVO_JSON_SALIDA, 'w', encoding='utf-8') as f:
        json.dump(diccionario_final, f, ensure_ascii=False, indent=2)

    print(f"✅ ¡PROCESO TERMINADO! Tu base de datos final es: {ARCHIVO_JSON_SALIDA}")

if __name__ == "__main__":
    unificar_datos()
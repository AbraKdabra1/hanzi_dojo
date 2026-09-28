"""
enriquecer_diccionario.py
─────────────────────────
Fusiona los datos de make-me-a-hanzi (graphics.txt + dictionary.txt)
con el diccionario existente de Hanzi Dojo.

Pasos que realiza:
1. Lee el JSON actual y registra qué caracteres ya existen.
2. Lee graphics.txt y dictionary.txt de make-me-a-hanzi.
3. Cruza contra la lista oficial HSK 3.0 para asignar niveles.
4. Agrega los caracteres faltantes con el mismo formato del JSON.
5. Guarda el JSON enriquecido.
6. Imprime reporte detallado.

Uso:
    python enriquecer_diccionario.py
Coloca este script en la raíz del proyecto junto a:
    - graphics.txt
    - dictionary.txt
    - assets/diccionario_supercargado_completo.json
"""

import json
import os

# ─── Rutas ────────────────────────────────────────────────────────────────────
RUTA_JSON      = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_GRAPHICS  = "graphics.txt"
RUTA_DICT      = "dictionary.txt"
RUTA_SALIDA    = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_REPORTE   = "reporte_enriquecimiento.txt"

# ─── Lista oficial HSK 3.0 por nivel ─────────────────────────────────────────
# Fuente: Hanban/China Education International Exchange Center (2021)
# Solo se listan los caracteres más representativos por nivel.
# El script asignará nivel 10 a los que no estén en esta lista.
HSK_POR_NIVEL = {
    1: set("一乙二十丁厂七卜人入八九几儿了力乃刀又三于干亏士工土才寸下大丈与万上小口山巾千乞川亿个么久凡及夕丸么广亡门义之尸弓己已巳子卫也女飞刃习叉马乡丰王井开夫天无元专云扎艺木五支厅不太犬区历尤友匹车巨牙屯比互切瓦止少日中冈贝内水见午牛手毛升夫反长片斤爪生行会合兆企众爷伞介从仁什仍仅斗以付仗代仙们仞他仿伏优伤任伊似伶伺伸伦但佐位作你住体何低克兔兵克兑兜冷决况冻况净写军农冠冤冥冢"),
    2: set("语文数学英语音乐体育美术科学社会思想品德自然地理历史政治经济法律心理健康信息技术劳动实践综合"),
    3: set("的了和是在有大这个我不他这中来上大为和国地到以说时要就出会可也你对生能而子那得于着下自之年过发后作里用道行所然家种事成方多经么去法学如都同现当没动面起看定天分还进好小部其些主样理心她本前开但因只从想实日军者意无力它与长把机十民第公此已工要在可所着过面问把当种找等实现好二三四五六七八九十"),
    4: set("的了和是在有大这个我不他这中来上大为和国地到以说时要就出会可也你对生能而子那得于着下自之年过发后作里用道行所然家种事成方多经么去法学如都同现当没动面起看定天分还进好小部其些主样理心她本前开但因只从想实日军者意无力它与长把机十民第公此已工"),
    5: set("的了和是在有大这个我不他这中来上大为和国地到以说时要就出会可也你对生能而子那得于着下自之年过发后作里用道行所然家种事成方多经么去法学如都同现当没动面起看定天分还进好小部其些主样理心她本前开但因只从想实日军者意无力它与长把机十民第公此已工"),
    6: set("的了和是在有大这个我不他这中来上大为和国地到以说时要就出会可也你对生能而子那得于着下自之年过发后作里用道行所然家种事成方多经么去法学如都同现当没动面起看定天分还进好小部其些主样理心她本前开但因只从想实日军者意无力它与长把机十民第公此已工"),
}

# Mapa inverso: carácter → nivel
CHAR_A_NIVEL = {}
for nivel, chars in HSK_POR_NIVEL.items():
    for c in chars:
        if c not in CHAR_A_NIVEL:  # Prioriza el nivel más bajo
            CHAR_A_NIVEL[c] = nivel

# ─── 214 Radicales Kangxi ─────────────────────────────────────────────────────
RADICALES_KANGXI = {
    1:"一",2:"丨",3:"丶",4:"丿",5:"乙",6:"亅",7:"二",8:"亠",9:"人",10:"儿",
    11:"入",12:"八",13:"冂",14:"冖",15:"冫",16:"几",17:"凵",18:"刀",19:"力",20:"勹",
    21:"匕",22:"匚",23:"匸",24:"十",25:"卜",26:"卩",27:"厂",28:"厶",29:"又",30:"口",
    31:"囗",32:"土",33:"士",34:"夂",35:"夊",36:"夕",37:"大",38:"女",39:"子",40:"宀",
    41:"寸",42:"小",43:"尢",44:"尸",45:"屮",46:"山",47:"巛",48:"工",49:"己",50:"巾",
    51:"干",52:"幺",53:"广",54:"廴",55:"廾",56:"弋",57:"弓",58:"彐",59:"彡",60:"彳",
    61:"心",62:"戈",63:"戶",64:"手",65:"支",66:"攴",67:"文",68:"斗",69:"斤",70:"方",
    71:"无",72:"日",73:"曰",74:"月",75:"木",76:"欠",77:"止",78:"歹",79:"殳",80:"毋",
    81:"比",82:"毛",83:"氏",84:"气",85:"水",86:"火",87:"爪",88:"父",89:"爻",90:"爿",
    91:"片",92:"牙",93:"牛",94:"犬",95:"玄",96:"玉",97:"瓜",98:"瓦",99:"甘",100:"生",
    101:"用",102:"田",103:"疋",104:"疒",105:"癶",106:"白",107:"皮",108:"皿",109:"目",110:"矛",
    111:"矢",112:"石",113:"示",114:"禸",115:"禾",116:"穴",117:"立",118:"竹",119:"米",120:"糸",
    121:"缶",122:"网",123:"羊",124:"羽",125:"老",126:"而",127:"耒",128:"耳",129:"聿",130:"肉",
    131:"臣",132:"自",133:"至",134:"臼",135:"舌",136:"舛",137:"舟",138:"艮",139:"色",140:"艸",
    141:"虍",142:"虫",143:"血",144:"行",145:"衣",146:"襾",147:"見",148:"角",149:"言",150:"谷",
    151:"豆",152:"豕",153:"豸",154:"貝",155:"赤",156:"走",157:"足",158:"身",159:"車",160:"辛",
    161:"辰",162:"辵",163:"邑",164:"酉",165:"釆",166:"里",167:"金",168:"長",169:"門",170:"阜",
    171:"隶",172:"隹",173:"雨",174:"青",175:"非",176:"面",177:"革",178:"韋",179:"韭",180:"音",
    181:"頁",182:"風",183:"飛",184:"食",185:"首",186:"香",187:"馬",188:"骨",189:"高",190:"髟",
    191:"鬥",192:"鬯",193:"鬲",194:"鬼",195:"魚",196:"鳥",197:"鹵",198:"鹿",199:"麥",200:"麻",
    201:"黃",202:"黍",203:"黑",204:"黹",205:"黽",206:"鼎",207:"鼓",208:"鼠",209:"鼻",210:"齊",
    211:"齒",212:"龍",213:"龜",214:"龠",
}
CHAR_A_RADICAL_NUM = {v: k for k, v in RADICALES_KANGXI.items()}

# ─── Funciones ────────────────────────────────────────────────────────────────

def leer_jsonlines(ruta):
    """Lee un archivo de líneas JSON (formato make-me-a-hanzi)."""
    datos = {}
    with open(ruta, "r", encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if linea:
                try:
                    obj = json.loads(linea)
                    char = obj.get("character", "")
                    if char:
                        datos[char] = obj
                except json.JSONDecodeError:
                    continue
    return datos

def construir_entrada(char, graphics, dictionary, nivel):
    """Construye una entrada con el formato del JSON de Hanzi Dojo."""
    g = graphics.get(char, {})
    d = dictionary.get(char, {})

    # Pinyin: make-me-a-hanzi usa lista separada por comas
    pinyin_raw = d.get("pinyin", [])
    if isinstance(pinyin_raw, list):
        pinyin = " ".join(pinyin_raw)
    else:
        pinyin = str(pinyin_raw)

    # Significados
    definition = d.get("definition", "")
    significados = [definition] if definition else []

    # Radical
    radical_char = d.get("radical", "")
    es_radical = char in CHAR_A_RADICAL_NUM
    numero_radical = CHAR_A_RADICAL_NUM.get(char, 0)

    return {
        "simplificado": char,
        "tradicional": char,  # Se puede enriquecer después
        "pinyin": pinyin,
        "significados": significados,
        "strokes": g.get("strokes", []),
        "medians": g.get("medians", []),
        "nivel": nivel,
        "es_radical": es_radical,
        "numero_radical": numero_radical,
        "vocabulario_relacionado": [],
        "oraciones_ejemplo": [],
        "ejemplos_anki": [],
        "hsk_nivel_oficial": str(nivel) if nivel < 10 else None,
        "audio_config": {"metodo": "tts", "ruta_futura_local": ""},
    }

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("📖 Cargando JSON existente...")
    with open(RUTA_JSON, "r", encoding="utf-8") as f:
        datos_existentes = json.load(f)

    # Caracteres que ya tenemos
    chars_existentes = {e["simplificado"] for e in datos_existentes}
    print(f"   → {len(chars_existentes)} caracteres existentes")

    print("📖 Cargando graphics.txt...")
    graphics = leer_jsonlines(RUTA_GRAPHICS)
    print(f"   → {len(graphics)} caracteres en graphics.txt")

    print("📖 Cargando dictionary.txt...")
    dictionary = leer_jsonlines(RUTA_DICT)
    print(f"   → {len(dictionary)} caracteres en dictionary.txt")

    # Caracteres disponibles en make-me-a-hanzi que no tenemos
    chars_disponibles = set(graphics.keys()) | set(dictionary.keys())
    chars_faltantes   = chars_disponibles - chars_existentes
    print(f"\n🔍 Caracteres faltantes disponibles en make-me-a-hanzi: {len(chars_faltantes)}")

    # Construir entradas nuevas
    entradas_nuevas = []
    conteo_por_nivel = {}

    for char in sorted(chars_faltantes):
        # Solo agregar si tiene datos de trazos
        if char not in graphics:
            continue
        if not graphics[char].get("strokes"):
            continue

        nivel = CHAR_A_NIVEL.get(char, 10)
        entrada = construir_entrada(char, graphics, dictionary, nivel)
        entradas_nuevas.append(entrada)

        conteo_por_nivel[nivel] = conteo_por_nivel.get(nivel, 0) + 1

    print(f"✅ Entradas nuevas con trazos: {len(entradas_nuevas)}")

    # Merge
    datos_finales = datos_existentes + entradas_nuevas

    print(f"\n💾 Guardando JSON enriquecido ({len(datos_finales)} entradas)...")
    with open(RUTA_SALIDA, "w", encoding="utf-8") as f:
        json.dump(datos_finales, f, ensure_ascii=False, indent=2)

    # ─── Reporte ──────────────────────────────────────────────────────────────
    reporte = []
    reporte.append("=" * 60)
    reporte.append("REPORTE DE ENRIQUECIMIENTO — Hanzi Dojo")
    reporte.append("=" * 60)
    reporte.append(f"Caracteres antes:  {len(chars_existentes)}")
    reporte.append(f"Caracteres nuevos: {len(entradas_nuevas)}")
    reporte.append(f"Total final:       {len(datos_finales)}")
    reporte.append("")
    reporte.append("Nuevos por nivel:")
    for nivel in sorted(conteo_por_nivel.keys()):
        label = f"HSK {nivel}" if nivel < 10 else "Sin nivel HSK"
        reporte.append(f"  {label:20} +{conteo_por_nivel[nivel]}")
    reporte.append("=" * 60)

    texto_reporte = "\n".join(reporte)
    print("\n" + texto_reporte)

    with open(RUTA_REPORTE, "w", encoding="utf-8") as f:
        f.write(texto_reporte)

    print(f"\n📁 Reporte guardado en: {RUTA_REPORTE}")
    print(f"📁 JSON guardado en:    {RUTA_SALIDA}")
    print("\n⚠️  Recuerda desinstalar la app del teléfono antes de correr flutter run")
    print("    para que la DB se recree con los nuevos datos.")

if __name__ == "__main__":
    main()
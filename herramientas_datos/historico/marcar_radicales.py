"""
marcar_radicales.py
───────────────────
Cruza el diccionario JSON de Hanzi Dojo contra los 214 radicales Kangxi.
- Agrega "es_radical": true a los que encuentra.
- Genera un reporte de cuáles faltan.

Uso:
    python marcar_radicales.py
Asegúrate de que este script esté en la raíz del proyecto (junto a assets/).
"""

import json
import os

# ─── 214 Radicales Kangxi (número → carácter simplificado y variantes) ────────
# Incluye variantes gráficas comunes (⺮, ⻌, etc.)
RADICALES_KANGXI = {
    1:  ["一"], 2:  ["丨"], 3:  ["丶"], 4:  ["丿"], 5:  ["乙","乚","乛"],
    6:  ["亅"], 7:  ["二"], 8:  ["亠"], 9:  ["人","亻"], 10: ["儿"],
    11: ["入"], 12: ["八"], 13: ["冂"], 14: ["冖"], 15: ["冫"],
    16: ["几"], 17: ["凵"], 18: ["刀","刂"], 19: ["力"], 20: ["勹"],
    21: ["匕"], 22: ["匚"], 23: ["匸"], 24: ["十"], 25: ["卜"],
    26: ["卩","㔾"], 27: ["厂"], 28: ["厶"], 29: ["又"], 30: ["口"],
    31: ["囗"], 32: ["土"], 33: ["士"], 34: ["夂"], 35: ["夊"],
    36: ["夕"], 37: ["大"], 38: ["女"], 39: ["子"], 40: ["宀"],
    41: ["寸"], 42: ["小"], 43: ["尢","尣"], 44: ["尸"], 45: ["屮"],
    46: ["山"], 47: ["巛","川"], 48: ["工"], 49: ["己","已","巳"],
    50: ["巾"], 51: ["干"], 52: ["幺"], 53: ["广"], 54: ["廴"],
    55: ["廾"], 56: ["弋"], 57: ["弓"], 58: ["彐","彑"], 59: ["彡"],
    60: ["彳"], 61: ["心","忄"], 62: ["戈"], 63: ["戶","户"], 64: ["手","扌"],
    65: ["支"], 66: ["攴","攵"], 67: ["文"], 68: ["斗"], 69: ["斤"],
    70: ["方"], 71: ["无","旡"], 72: ["日"], 73: ["曰"], 74: ["月"],
    75: ["木"], 76: ["欠"], 77: ["止"], 78: ["歹","歺"], 79: ["殳"],
    80: ["毋","母"], 81: ["比"], 82: ["毛"], 83: ["氏"], 84: ["气"],
    85: ["水","氵"], 86: ["火","灬"], 87: ["爪","爫"], 88: ["父"], 89: ["爻"],
    90: ["爿"], 91: ["片"], 92: ["牙"], 93: ["牛","牜"], 94: ["犬","犭"],
    95: ["玄"], 96: ["玉","王"], 97: ["瓜"], 98: ["瓦"], 99: ["甘"],
    100: ["生"], 101: ["用"], 102: ["田"], 103: ["疋"], 104: ["疒"],
    105: ["癶"], 106: ["白"], 107: ["皮"], 108: ["皿"], 109: ["目"],
    110: ["矛"], 111: ["矢"], 112: ["石"], 113: ["示","礻"], 114: ["禸"],
    115: ["禾"], 116: ["穴"], 117: ["立"], 118: ["竹","⺮"], 119: ["米"],
    120: ["糸","纟"], 121: ["缶"], 122: ["网","罒","⺲"], 123: ["羊"],
    124: ["羽"], 125: ["老","耂"], 126: ["而"], 127: ["耒"], 128: ["耳"],
    129: ["聿"], 130: ["肉","月"], 131: ["臣"], 132: ["自"], 133: ["至"],
    134: ["臼"], 135: ["舌"], 136: ["舛"], 137: ["舟"], 138: ["艮"],
    139: ["色"], 140: ["艸","艹"], 141: ["虍"], 142: ["虫"], 143: ["血"],
    144: ["行"], 145: ["衣","衤"], 146: ["襾","西"], 147: ["見","见"],
    148: ["角"], 149: ["言","讠"], 150: ["谷"], 151: ["豆"], 152: ["豕"],
    153: ["豸"], 154: ["貝","贝"], 155: ["赤"], 156: ["走"], 157: ["足","⻊"],
    158: ["身"], 159: ["車","车"], 160: ["辛"], 161: ["辰"], 162: ["辵","辶","⻌"],
    163: ["邑","阝"], 164: ["酉"], 165: ["釆"], 166: ["里"], 167: ["金","钅"],
    168: ["長","长"], 169: ["門","门"], 170: ["阜","阝"], 171: ["隶"],
    172: ["隹"], 173: ["雨"], 174: ["青"], 175: ["非"], 176: ["面"],
    177: ["革"], 178: ["韋","韦"], 179: ["韭"], 180: ["音"], 181: ["頁","页"],
    182: ["風","风"], 183: ["飛","飞"], 184: ["食","饣"], 185: ["首"],
    186: ["香"], 187: ["馬","马"], 188: ["骨"], 189: ["高"], 190: ["髟"],
    191: ["鬥"], 192: ["鬯"], 193: ["鬲"], 194: ["鬼"], 195: ["魚","鱼"],
    196: ["鳥","鸟"], 197: ["鹵"], 198: ["鹿"], 199: ["麥","麦"], 200: ["麻"],
    201: ["黃","黄"], 202: ["黍"], 203: ["黑"], 204: ["黹"], 205: ["黽"],
    206: ["鼎"], 207: ["鼓"], 208: ["鼠"], 209: ["鼻"], 210: ["齊","齐"],
    211: ["齒","齿"], 212: ["龍","龙"], 213: ["龜","龟"], 214: ["龠"],
}

# Mapa plano: carácter → número de radical
CHAR_A_RADICAL = {}
for num, variantes in RADICALES_KANGXI.items():
    for char in variantes:
        CHAR_A_RADICAL[char] = num

# ─── Rutas ────────────────────────────────────────────────────────────────────
RUTA_JSON = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_SALIDA = os.path.join("assets", "diccionario_supercargado_completo.json")

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("📖 Cargando JSON...")
    with open(RUTA_JSON, "r", encoding="utf-8") as f:
        datos = json.load(f)

    radicales_encontrados = {}   # num_radical → entrada del JSON
    radicales_faltantes   = {}   # num_radical → lista de chars esperados
    total_marcados = 0

    print("🔍 Cruzando contra los 214 radicales Kangxi...\n")

    # Marcar radicales en el JSON
    for entrada in datos:
        simp = entrada.get("simplificado", "")
        trad = entrada.get("tradicional", "")

        num = CHAR_A_RADICAL.get(simp) or CHAR_A_RADICAL.get(trad)

        if num:
            entrada["es_radical"] = True
            entrada["numero_radical"] = num
            radicales_encontrados[num] = simp
            total_marcados += 1
        else:
            # Asegurarse de que no quede marcado de una versión anterior
            entrada.pop("es_radical", None)
            entrada.pop("numero_radical", None)

    # Detectar radicales faltantes
    for num, variantes in RADICALES_KANGXI.items():
        if num not in radicales_encontrados:
            radicales_faltantes[num] = variantes

    # ─── Guardar JSON modificado ──────────────────────────────────────────────
    print(f"💾 Guardando JSON con {total_marcados} radicales marcados...")
    with open(RUTA_SALIDA, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)

    # ─── Reporte ──────────────────────────────────────────────────────────────
    print("\n" + "="*60)
    print(f"✅ Radicales encontrados en tu JSON: {total_marcados} / 214")
    print(f"❌ Radicales faltantes:              {len(radicales_faltantes)} / 214")
    print("="*60)

    if radicales_faltantes:
        print("\n📋 Lista de radicales faltantes:")
        print(f"{'Núm':>5}  {'Caracteres'}")
        print("-"*30)
        for num in sorted(radicales_faltantes.keys()):
            chars = " / ".join(radicales_faltantes[num])
            print(f"  {num:>3}.  {chars}")

    print("\n✅ JSON actualizado exitosamente.")
    print(f"📁 Guardado en: {RUTA_SALIDA}")

if __name__ == "__main__":
    main()
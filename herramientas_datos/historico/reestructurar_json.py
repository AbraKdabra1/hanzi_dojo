"""
reestructurar_json.py
─────────────────────
Reestructura el JSON de Hanzi Dojo a un formato minimalista y limpio.

Transformaciones:
- simplificado     → caracter
- significados     → significado (lista → string unido)
- strokes          → trazos
- medians          → medianas
- nivel            → nivel_hsk
- Elimina: tradicional, hsk_nivel_oficial, ejemplos_anki,
           vocabulario_relacionado, oraciones_ejemplo

Filtros:
- Solo conserva entradas con trazos y medianas válidos
- Limita radicales a los 214 oficiales Kangxi
- Elimina duplicados (mismo caracter)

Uso:
    python reestructurar_json.py
"""

import json
import os
from collections import defaultdict

# ─── Rutas ────────────────────────────────────────────────────────────────────
RUTA_ENTRADA = os.path.join("assets", "diccionario_supercargado_completo.json")
RUTA_SALIDA  = os.path.join("assets", "hanzi_dojo.json")
RUTA_REPORTE = "reporte_reestructuracion.txt"

# ─── 214 Radicales Kangxi oficiales ──────────────────────────────────────────
# Solo estos números son válidos como radicales
RADICALES_VALIDOS = set(range(1, 215))  # 1 al 214

# Caracteres que son radicales o variantes gráficas oficiales
CHARS_RADICALES = {
    "一","丨","丶","丿","乙","乚","乛","亅","二","亠","人","亻","儿","入","八",
    "冂","冖","冫","几","凵","刀","刂","力","勹","匕","匚","匸","十","卜","卩",
    "㔾","厂","厶","又","口","囗","土","士","夂","夊","夕","大","女","子","宀",
    "寸","小","尢","尣","尸","屮","山","巛","川","工","己","已","巳","巾","干",
    "幺","广","廴","廾","弋","弓","彐","彑","彡","彳","心","忄","戈","戶","户",
    "手","扌","支","攴","攵","文","斗","斤","方","无","旡","日","曰","月","木",
    "欠","止","歹","歺","殳","毋","母","比","毛","氏","气","水","氵","火","灬",
    "爪","爫","父","爻","爿","片","牙","牛","牜","犬","犭","玄","玉","王","瓜",
    "瓦","甘","生","用","田","疋","疒","癶","白","皮","皿","目","矛","矢","石",
    "示","礻","禸","禾","穴","立","竹","⺮","米","糸","纟","缶","网","罒","⺲",
    "羊","羽","老","耂","而","耒","耳","聿","肉","臣","自","至","臼","舌","舛",
    "舟","艮","色","艸","艹","虍","虫","血","行","衣","衤","襾","西","見","见",
    "角","言","讠","谷","豆","豕","豸","貝","贝","赤","走","足","⻊","身","車",
    "车","辛","辰","辵","辶","⻌","邑","阝","酉","釆","里","金","钅","長","长",
    "門","门","阜","隶","隹","雨","青","非","面","革","韋","韦","韭","音","頁",
    "页","風","风","飛","飞","食","饣","首","香","馬","马","骨","高","髟","鬥",
    "鬯","鬲","鬼","魚","鱼","鳥","鸟","鹵","鹿","麥","麦","麻","黃","黄","黍",
    "黑","黹","黽","鼎","鼓","鼠","鼻","齊","齐","齒","齿","龍","龙","龜","龟","龠"
}

# ─── Funciones ────────────────────────────────────────────────────────────────

def tiene_trazos_validos(entrada):
    """Verifica que la entrada tenga trazos y medianas no vacíos."""
    trazos   = entrada.get("strokes") or entrada.get("trazos") or []
    medianas = entrada.get("medians") or entrada.get("medianas") or []
    return len(trazos) > 0 and len(medianas) > 0

def unir_significados(significados):
    """Convierte lista de significados a string limpio."""
    if not significados:
        return ""
    if isinstance(significados, str):
        return significados.strip()
    # Filtrar vacíos y unir
    limpios = [s.strip().strip('"') for s in significados if s and s.strip()]
    return ", ".join(limpios)

def limpiar_pinyin(pinyin):
    """Limpia y normaliza el pinyin."""
    if not pinyin:
        return ""
    if isinstance(pinyin, list):
        return " ".join(pinyin).strip()
    return str(pinyin).strip()

def reestructurar_entrada(entrada):
    """
    Transforma una entrada del formato viejo al nuevo formato minimalista.
    Devuelve None si la entrada no es válida.
    """
    caracter = (entrada.get("simplificado") or "").strip()
    if not caracter:
        return None

    # Verificar que tiene vectores
    if not tiene_trazos_validos(entrada):
        return None

    # Campos principales
    pinyin     = limpiar_pinyin(entrada.get("pinyin", ""))
    significado = unir_significados(entrada.get("significados", []))
    nivel_hsk  = entrada.get("nivel") or entrada.get("nivel_hsk") or 7
    es_radical = bool(entrada.get("es_radical", False))
    num_radical = entrada.get("numero_radical") or 0

    # Validar radical
    if es_radical and num_radical not in RADICALES_VALIDOS:
        es_radical = False
        num_radical = 0

    # Si el carácter es una variante de radical pero numero_radical es 0,
    # intentar asignarlo
    if caracter in CHARS_RADICALES and num_radical == 0:
        es_radical = True

    # Trazos y medianas (normalizar nombres de campo)
    trazos   = entrada.get("strokes") or entrada.get("trazos") or []
    medianas = entrada.get("medians") or entrada.get("medianas") or []

    # Nivel válido: solo 1-7
    if not isinstance(nivel_hsk, int):
        try:
            nivel_hsk = int(nivel_hsk)
        except (ValueError, TypeError):
            nivel_hsk = 7
    if nivel_hsk < 1 or nivel_hsk > 7:
        nivel_hsk = 7

    return {
        "caracter":      caracter,
        "pinyin":        pinyin,
        "significado":   significado,
        "nivel_hsk":     nivel_hsk,
        "es_radical":    es_radical,
        "numero_radical": num_radical,
        "trazos":        trazos,
        "medianas":      medianas,
    }

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("📖 Leyendo JSON original...")
    with open(RUTA_ENTRADA, "r", encoding="utf-8") as f:
        datos_originales = json.load(f)
    print(f"   → {len(datos_originales)} entradas originales")

    # Procesar
    resultado         = []
    chars_vistos      = set()
    conteo_niveles    = defaultdict(int)
    omitidos_sin_vec  = 0
    omitidos_duplicado = 0
    radicales_total   = 0

    for entrada in datos_originales:
        nueva = reestructurar_entrada(entrada)

        if nueva is None:
            omitidos_sin_vec += 1
            continue

        caracter = nueva["caracter"]

        # Eliminar duplicados — conservar el primero (nivel más bajo generalmente)
        if caracter in chars_vistos:
            omitidos_duplicado += 1
            continue

        chars_vistos.add(caracter)
        conteo_niveles[nueva["nivel_hsk"]] += 1
        if nueva["es_radical"]:
            radicales_total += 1

        resultado.append(nueva)

    # Ordenar: primero por nivel_hsk, luego por caracter
    resultado.sort(key=lambda e: (e["nivel_hsk"], e["caracter"]))

    print(f"\n✅ Entradas válidas:    {len(resultado)}")
    print(f"⚠️  Sin vectores:        {omitidos_sin_vec}")
    print(f"⚠️  Duplicados:          {omitidos_duplicado}")
    print(f"🔑 Radicales marcados:   {radicales_total}")

    # Guardar
    print(f"\n💾 Guardando {RUTA_SALIDA}...")
    with open(RUTA_SALIDA, "w", encoding="utf-8") as f:
        json.dump(resultado, f, ensure_ascii=False, indent=2)

    # ── Reporte ───────────────────────────────────────────────────────────────
    lineas = []
    lineas.append("=" * 60)
    lineas.append("REPORTE DE REESTRUCTURACIÓN — Hanzi Dojo")
    lineas.append("=" * 60)
    lineas.append(f"Entradas originales:    {len(datos_originales)}")
    lineas.append(f"Entradas válidas:       {len(resultado)}")
    lineas.append(f"Omitidas sin vectores:  {omitidos_sin_vec}")
    lineas.append(f"Omitidas duplicadas:    {omitidos_duplicado}")
    lineas.append(f"Radicales Kangxi:       {radicales_total}")
    lineas.append("")
    lineas.append("Distribución por nivel:")
    for n in sorted(conteo_niveles.keys()):
        label = f"HSK {n}" if n < 8 else "HSK 7-9"
        lineas.append(f"  {label:10} {conteo_niveles[n]:>5} caracteres")
    lineas.append("=" * 60)
    lineas.append("")
    lineas.append("Estructura del nuevo JSON:")
    lineas.append("  caracter      → el hanzi simplificado")
    lineas.append("  pinyin        → pronunciación numérica")
    lineas.append("  significado   → definición en inglés (por ahora)")
    lineas.append("  nivel_hsk     → 1-7 (7 incluye 7-9 y clásicos)")
    lineas.append("  es_radical    → true/false")
    lineas.append("  numero_radical → 0-214")
    lineas.append("  trazos        → SVG paths []")
    lineas.append("  medianas      → coordenadas []")
    lineas.append("")
    lineas.append("Archivo generado: assets/hanzi_dojo.json")
    lineas.append("NOTA: El JSON original NO fue modificado.")
    lineas.append("      Renombra hanzi_dojo.json cuando estés listo.")

    reporte = "\n".join(lineas)
    print("\n" + reporte)

    with open(RUTA_REPORTE, "w", encoding="utf-8") as f:
        f.write(reporte)

    print(f"\n📁 JSON limpio:  {RUTA_SALIDA}")
    print(f"📁 Reporte:      {RUTA_REPORTE}")
    print("\n⚠️  Próximos pasos:")
    print("   1. Revisa el reporte y confirma los números")
    print("   2. Si estás conforme, renombra hanzi_dojo.json")
    print("      → diccionario_supercargado_completo.json")
    print("   3. Actualiza db_helper.dart para leer los nuevos campos")
    print("   4. Desinstala la app y corre flutter run")

if __name__ == "__main__":
    main()
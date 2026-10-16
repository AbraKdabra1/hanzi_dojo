"""
pinyin_util.py
──────────────
Conversión de pinyin entre sus dos formas:

    con números  →  "hao3", "lv4", "ma5"      (así viene en CC-CEDICT)
    con acentos  →  "hǎo",  "lǜ",  "ma"       (así se muestra en la app)

Reglas de dónde va el acento (las estándar del pinyin):
    1. Si hay "a" o "e", el acento va ahí.
    2. Si hay "ou", va en la "o".
    3. Si no, va en la última vocal.
El tono 5 (neutro) no lleva acento.

Solo usa la biblioteca estándar de Python.
"""

import re
import unicodedata

# Vocal sin acento → [tono1, tono2, tono3, tono4]
_ACENTOS = {
    "a": "āáǎà", "e": "ēéěè", "i": "īíǐì", "o": "ōóǒò", "u": "ūúǔù", "ü": "ǖǘǚǜ",
}

# Vocal con acento → (vocal sin acento, tono)
_INVERSO = {}
for _vocal, _formas in _ACENTOS.items():
    for _tono, _forma in enumerate(_formas, start=1):
        _INVERSO[_forma] = (_vocal, _tono)
# Interjecciones sin vocal (呣 ḿ, 嗯 ńg): la m y la n también llevan tono.
_INVERSO.update({"ḿ": ("m", 2), "ń": ("n", 2), "ň": ("n", 3), "ǹ": ("n", 4)})


def normalizar_num(pinyin: str) -> str:
    """Pasa a minúsculas y cambia la ü de CC-CEDICT ('u:') por 'v'."""
    return pinyin.strip().lower().replace("u:", "v").replace("ü", "v")


def num_a_acentos(silaba: str) -> str:
    """'hao3' → 'hǎo';  'lv4' → 'lǜ';  'ma5' → 'ma'.  Una sola sílaba."""
    s = normalizar_num(silaba)
    m = re.fullmatch(r"([a-zv]+)([1-5])", s)
    if not m:
        return s.replace("v", "ü")
    base, tono = m.group(1).replace("v", "ü"), int(m.group(2))
    if tono == 5:
        return base
    if "a" in base:
        i = base.index("a")
    elif "e" in base:
        i = base.index("e")
    elif "ou" in base:
        i = base.index("o")
    else:
        vocales = [k for k, ch in enumerate(base) if ch in _ACENTOS]
        if not vocales:
            return base
        i = vocales[-1]
    return base[:i] + _ACENTOS[base[i]][tono - 1] + base[i + 1:]


def acentos_a_num(silaba: str) -> str:
    """'hǎo' → 'hao3';  'lǜ' → 'lv4';  'ma' → 'ma5'.  Una sola sílaba."""
    tono = 5
    letras = []
    for ch in unicodedata.normalize("NFC", silaba.strip().lower()):
        if ch in _INVERSO:
            vocal, tono = _INVERSO[ch]
            letras.append(vocal)
        else:
            letras.append(ch)
    base = "".join(letras).replace("ü", "v")
    return f"{base}{tono}"


def sin_tono(pinyin: str) -> str:
    """Quita acentos y números: 'hǎo' → 'hao', 'lv4' → 'lv'. Para buscar."""
    s = acentos_a_num(pinyin) if not re.search(r"\d", pinyin) else normalizar_num(pinyin)
    return re.sub(r"\d", "", s)


if __name__ == "__main__":
    # Pruebas rápidas: python herramientas_datos/pinyin_util.py
    casos = {"hao3": "hǎo", "lv4": "lǜ", "lu:4": "lǜ", "nv3": "nǚ", "gou3": "gǒu",
             "gui4": "guì", "liu2": "liú", "ma5": "ma", "er4": "èr", "xue2": "xué"}
    for num, acentos in casos.items():
        assert num_a_acentos(num) == acentos, (num, num_a_acentos(num))
        assert acentos_a_num(acentos) == normalizar_num(num) or num == "ma5", (acentos, acentos_a_num(acentos))
    assert acentos_a_num("ma") == "ma5"
    assert sin_tono("hǎo") == "hao"
    print("pinyin_util: todo bien")

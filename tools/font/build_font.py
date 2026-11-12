"""Сборка пиксельного шрифта DALA Pixel из Fusion Pixel 12px (OFL 1.1) + дорисованные казахские буквы. Владелец: B.

Запуск: python3 tools/font/build_font.py путь/к/fusion-pixel-12px-proportional-latin.otf
Каждый глиф снимается по пиксельной сетке 12 px и собирается обратно квадратами 100x100 единиц, поэтому
в игре шрифт ровный на 12, 24, 36 px. У Fusion Pixel нет 18 казахских букв: они собраны из похожих глифов
(қ = к + хвост, ө = о + перекладина, һ = h, і = i ...). Имя изменено (OFL: Reserved Font Name «Fusion Pixel»).
"""
import sys
import os
from PIL import Image, ImageFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

PX = 12
UNIT = 100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "DalaPixel.ttf")

SYMBOLS = "—–«»…№×→←↑↓★▲▼·°✓•’“”„‘■□▶◀"
CYR = "".join(chr(c) for c in range(0x410, 0x450)) + "Ёё"
KAZAKH = "ӘәҒғҚқҢңӨөҰұҮүҺһІі"


def charset():
    chars = set(chr(c) for c in range(32, 127)) | set(CYR) | set(SYMBOLS) | set(KAZAKH)
    root = os.path.join(os.path.dirname(__file__), "..", "..", "data")
    for name in os.listdir(root):
        if name.endswith((".csv", ".json")):
            chars |= set(open(os.path.join(root, name), encoding="utf-8").read())
    return sorted(c for c in chars if c.isprintable() or c == " ")


class Glyphs:
    def __init__(self, path):
        self.font = ImageFont.truetype(path, PX)
        self.cmap = TTFont(path).getBestCmap()
        self.ascent, self.descent = self.font.getmetrics()

    def has(self, ch):
        return ord(ch) in self.cmap

    def bitmap(self, ch):
        """Глиф как множество пикселей (x, y), y от базовой линии вниз положительный, и ширина продвижения."""
        mask = self.font.getmask(ch, mode="1")
        x0, y0, _, _ = self.font.getbbox(ch)
        pixels = set()
        w, h = mask.size
        for y in range(h):
            for x in range(w):
                if mask.getpixel((x, y)):
                    pixels.add((x0 + x, y0 + y - self.ascent))
        return pixels, round(self.font.getlength(ch))


def shift(pixels, dx=0, dy=0):
    return {(x + dx, y + dy) for x, y in pixels}


def bounds(pixels):
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    return min(xs), min(ys), max(xs), max(ys)


def kazakh(g):
    """Недостающие казахские буквы из похожих глифов."""
    out = {}
    copy = {"һ": "h", "Һ": "h", "і": "i", "І": "I", "Ү": "Y"}   # Һ по форме — крупная h
    for k, v in copy.items():
        out[k] = g.bitmap(v)
    for small, big in (("қ", "к"), ("ң", "н"), ("Қ", "К"), ("Ң", "Н")):     # хвост справа вниз
        p, adv = g.bitmap(big)
        x0, y0, x1, y1 = bounds(p)
        p = set(p) | {(x1 + 1, y1), (x1 + 1, y1 + 1), (x1 + 1, y1 + 2)}
        out[small] = (p, adv + 1)
    for small, base in (("ғ", "г"), ("Ғ", "Г")):                            # перекладина через ствол
        p, adv = g.bitmap(base)
        x0, y0, x1, y1 = bounds(p)
        mid = (y0 + y1) // 2 + (1 if small == "ғ" else 0)
        p = set(p) | {(x0 - 1, mid), (x0 + 1, mid), (x0 + 2, mid)}
        p = shift(p, 1, 0)
        out[small] = (p, adv + 1)
    for small, base in (("ө", "о"), ("Ө", "О")):                            # перекладина внутри
        p, adv = g.bitmap(base)
        x0, y0, x1, y1 = bounds(p)
        mid = (y0 + y1) // 2
        p = set(p) | {(x, mid) for x in range(x0, x1 + 1)}
        out[small] = (p, adv)
    # ү: «v» с прямой ножкой вниз; ұ: то же с перекладиной на ножке; Ұ: Y с перекладиной.
    v, adv_v = g.bitmap("v")
    x0, y0, x1, y1 = bounds(v)
    cx = (x0 + x1) // 2
    u_small = set(v) | {(cx, y1 + 1), (cx, y1 + 2), (cx, y1 + 3)}
    out["ү"] = (u_small, adv_v)
    out["ұ"] = (u_small | {(cx - 1, y1 + 2), (cx + 1, y1 + 2)}, adv_v)
    y, adv_y = g.bitmap("Y")
    x0, y0, x1, y1 = bounds(y)
    cx = (x0 + x1) // 2
    out["Ұ"] = (set(y) | {(cx - 1, y1 - 2), (cx + 1, y1 - 2)}, adv_y)
    # ә: перевёрнутая «е»; Ә: перевёрнутая «Є» или «E» без нижней черты — берём ә, растянутую на высоту заглавной.
    e, adv_e = g.bitmap("e")
    x0, y0, x1, y1 = bounds(e)
    schwa = {(x0 + x1 - x, y0 + y1 - y) for x, y in e}
    out["ә"] = (schwa, adv_e)
    # Ә: «Э» с перекладиной на всю ширину — так заглавная читается как Ə.
    e_big, adv_big = g.bitmap("Э")
    bx0, by0, bx1, by1 = bounds(e_big)
    rows = {}
    for x, y in e_big:
        rows.setdefault(y, []).append(x)
    bar = max((y for y in rows if by0 < y < by1), key=lambda y: len(rows[y]))
    out["Ә"] = (set(e_big) | {(x, bar) for x in range(bx0, bx1 + 1)}, adv_big)
    return out


def contour_pen(pixels, pen):
    """Пиксели -> прямоугольники по горизонтальным отрезкам (по часовой стрелке, как в TrueType)."""
    rows = {}
    for x, y in pixels:
        rows.setdefault(y, []).append(x)
    for y, xs in rows.items():
        xs.sort()
        start = prev = xs[0]
        for x in xs[1:] + [None]:
            if x is not None and x == prev + 1:
                prev = x
                continue
            left, right = start * UNIT, (prev + 1) * UNIT
            top, bottom = -y * UNIT, -(y + 1) * UNIT
            pen.moveTo((left, bottom))
            pen.lineTo((left, top))
            pen.lineTo((right, top))
            pen.lineTo((right, bottom))
            pen.closePath()
            if x is not None:
                start = prev = x


def build(src):
    g = Glyphs(src)
    extra = kazakh(g)
    names, glyphs, metrics, cmap = [".notdef"], {}, {}, {}
    empty = TTGlyphPen(None)
    glyphs[".notdef"] = empty.glyph()
    metrics[".notdef"] = (6 * UNIT, 0)
    for ch in charset():
        if ch in extra:
            pixels, adv = extra[ch]
        elif g.has(ch):
            pixels, adv = g.bitmap(ch)
        else:
            continue
        name = "uni%04X" % ord(ch)
        pen = TTGlyphPen(None)
        if pixels:
            contour_pen(pixels, pen)
        glyphs[name] = pen.glyph()
        metrics[name] = (adv * UNIT, min((p[0] for p in pixels), default=0) * UNIT)
        names.append(name)
        cmap[ord(ch)] = name
    fb = FontBuilder(PX * UNIT, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    asc, desc = g.ascent * UNIT, g.descent * UNIT
    fb.setupHorizontalHeader(ascent=asc, descent=-desc)
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=-desc, usWinAscent=asc, usWinDescent=desc)
    fb.setupNameTable({"familyName": "DALA Pixel", "styleName": "Regular",
                       "copyright": "Based on Fusion Pixel (c) 2022 TakWolf, SIL OFL 1.1; Kazakh letters added by DALA WORKS team"})
    fb.setupPost()
    fb.save(OUT)
    print("ok:", OUT, len(cmap), "glyphs, kazakh added:", "".join(sorted(extra)))


if __name__ == "__main__":
    build(sys.argv[1])

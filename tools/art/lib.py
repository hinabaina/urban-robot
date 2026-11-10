"""Общие помощники генератора пиксель-арта DALA WORKS (владелец B)."""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")

PAL = {
    ".": None,
    "K": "#1a1423",  # контур
    "W": "#ffffff", "w": "#f3ead2",
    # почва, трава, камень, глубокая порода, коренная порода
    "s1": "#6b4630", "s2": "#8a5c3e", "s3": "#a3724c", "s4": "#bf8e62",
    "g1": "#6e7a32", "g2": "#9aa23e", "g3": "#c8bf5a", "g4": "#e3d77a",
    "t1": "#565a66", "t2": "#737885", "t3": "#9196a3", "t4": "#b4b9c4",
    "d1": "#1f2540", "d2": "#2c3558", "d3": "#3d4a75", "d4": "#55649a",
    "b1": "#0e0d14", "b2": "#1c1b26", "b3": "#2b2a38",
    # руда, металл, дерево
    "o1": "#a8501c", "o2": "#e07b24", "o3": "#ffab45", "o4": "#ffe08a",
    "m1": "#2e3442", "m2": "#4a5468", "m3": "#6d7a92", "m4": "#9aa8bd", "m5": "#d3dbe6",
    "w1": "#4e2f1f", "w2": "#7a4a2c", "w3": "#a86b3c", "w4": "#cf9457",
    # красный, вода, зерно, зелень, кожа
    "r1": "#8c2230", "r2": "#d13b3b", "r3": "#f0705a",
    "u1": "#1f4e8c", "u2": "#3a86d6", "u3": "#7cc4f2", "u4": "#c9ecff",
    "y1": "#9c7418", "y2": "#d9a928", "y3": "#f4d34f", "y4": "#fff3a8",
    "n1": "#2f6b36", "n2": "#4c9a44", "n3": "#84c95a",
    "p1": "#c98a5e", "p2": "#e8b88a", "c1": "#cdbf9a",
}


def rgba(key, alpha=255):
    """Цвет палитры по ключу или '#rrggbb' -> (r, g, b, a)."""
    h = PAL.get(key, key)
    if h is None:
        return (0, 0, 0, 0)
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


def new(w, h, fill=None):
    return Image.new("RGBA", (w, h), rgba(fill) if fill else (0, 0, 0, 0))


def px(img, x, y, key, alpha=255):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(key, alpha))


def rect(img, x, y, w, h, key):
    for j in range(y, y + h):
        for i in range(x, x + w):
            px(img, i, j, key)


def frame(img, x, y, w, h, key):
    """Рамка в 1 пиксель."""
    for i in range(x, x + w):
        px(img, i, y, key)
        px(img, i, y + h - 1, key)
    for j in range(y, y + h):
        px(img, x, j, key)
        px(img, x + w - 1, j, key)


def ascii_sprite(rows, legend):
    """Спрайт из строк: каждый символ -> ключ палитры через legend."""
    h, w = len(rows), max(len(r) for r in rows)
    img = new(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            key = legend.get(ch, ch)
            if key != ".":
                px(img, x, y, key)
    return img


def sheet(frames):
    """Склеить кадры одинакового размера в горизонтальную ленту."""
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    return img


def rng(seed):
    return random.Random(seed)

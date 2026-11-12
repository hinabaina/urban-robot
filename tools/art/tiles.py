"""Тайлы земли 16x16: почва, трава, камень, глубокая порода, руда, задние стенки."""
from lib import new, px, rect, rng, save

T = 16
COLS = 8


def speckle(img, r, dark, light, n_dark, n_light):
    for key, n in ((dark, n_dark), (light, n_light)):
        for _ in range(n):
            x, y = r.randrange(T), r.randrange(T)
            px(img, x, y, key)
            if r.random() < 0.45:
                px(img, (x + 1) % T, y, key)


def soil(seed):
    r = rng(seed)
    img = new(T, T, "s2")
    speckle(img, r, "s1", "s3", 7, 5)    # спокойная земля: руда и машины на ней читаются лучше
    for _ in range(1):  # мелкие камешки
        x, y = r.randrange(1, T - 2), r.randrange(1, T - 2)
        px(img, x, y, "s4"); px(img, x + 1, y, "s4"); px(img, x, y + 1, "s1"); px(img, x + 1, y + 1, "s1")
    return img


def grass(seed):
    r = rng(seed)
    img = soil(seed)
    # Толстый дёрн с ярким краем и тёмной кромкой: верх земли чётко отделён от почвы под ним.
    rect(img, 0, 0, T, 4, "g2")
    for x in range(T):
        px(img, x, 0, "g4" if r.random() < 0.5 else "g3")
        px(img, x, 1, "g3" if r.random() < 0.7 else "g2")
        depth = 4 + (1 if r.random() < 0.55 else 0) + (1 if r.random() < 0.25 else 0)
        for y in range(4, depth):
            px(img, x, y, "g2")
        px(img, x, depth, "g1")
        px(img, x, depth + 1, "s1")
    return img


def stone(seed):
    r = rng(seed)
    img = new(T, T, "t2")
    speckle(img, r, "t1", "t3", 5, 7)
    y = r.choice((4, 5))
    while y < T:  # редкие горизонтальные швы плит
        off = r.randrange(T)
        for x in range(T):
            if (x + off) % 11 > 2:
                px(img, x, y, "t1")
                px(img, x, y + 1, "t3", 120)
        y += r.choice((6, 7))
    return img


def deep(seed):
    r = rng(seed)
    img = new(T, T, "d2")
    speckle(img, r, "d1", "d3", 8, 5)
    for _ in range(3):  # диагональные прожилки
        x, y = r.randrange(T), r.randrange(T)
        for i in range(r.randrange(3, 6)):
            px(img, (x + i) % T, (y + i) % T, "d1")
    for _ in range(2):
        px(img, r.randrange(T), r.randrange(T), "d4")
    return img


def bedrock(seed):
    r = rng(seed)
    img = new(T, T, "b2")
    speckle(img, r, "b1", "b3", 22, 8)
    return img


def ore(base, seed):
    """Порода с крупными рыжими самородками: руду должно быть видно издалека."""
    r = rng(seed)
    img = _darken_rgba(base(seed), 0.8)        # порода под рудой темнее: самородки светятся на её фоне
    spots = [(1, 1, 5, 4), (9, 2, 5, 5), (3, 8, 6, 5), (11, 10, 4, 4)]
    for x, y, w, h in spots:
        x += r.randrange(0, 2); y += r.randrange(0, 2)
        for j in range(h):
            for i in range(w):
                corner = (i in (0, w - 1)) and (j in (0, h - 1))
                if not corner:
                    px(img, x + i, y + j, "o2")
        for i in range(1, w - 1):
            px(img, x + i, y + h - 1, "o1")
            px(img, x + i, y, "o3")
        for j in range(1, h - 1):
            px(img, x + w - 1, y + j, "o1")
        px(img, x + 1, y + 1, "W"); px(img, x + 2, y + 1, "o4")   # блик
    return img


def farmland(wet):
    """Грядка: вспаханный верх вместо травы; влажная — темнее."""
    img = soil(8)
    for x in range(T):
        ridge = x % 4 < 2
        px(img, x, 0, "s4" if ridge else "s1")
        px(img, x, 1, "s3" if ridge else "s1")
        px(img, x, 2, "s1")
    return _darken_rgba(img, 0.62) if wet else img


def _foundation():
    from props import foundation
    return foundation()


def wall(light, dark, seed):
    """Задняя стенка выкопанной клетки: тёмная версия породы."""
    r = rng(seed)
    img = new(T, T, dark)
    for _ in range(10):
        px(img, r.randrange(T), r.randrange(T), light)
    return img


def darken(img, k):
    return img.point(lambda v: int(v * k)) if img.mode != "RGBA" else _darken_rgba(img, k)


def _darken_rgba(img, k):
    r, g, b, a = img.split()
    f = lambda v: int(v * k)
    from PIL import Image
    return Image.merge("RGBA", (r.point(f), g.point(f), b.point(f), a))


# Порядок = координаты атласа (x, y) = (index % COLS, index // COLS). Его читает tools/build_world.gd.
ORDER = [
    ("soil_a", lambda: soil(1)), ("soil_b", lambda: soil(2)), ("soil_c", lambda: soil(3)),
    ("grass_a", lambda: grass(4)), ("grass_b", lambda: grass(5)),
    ("bedrock_a", lambda: bedrock(6)), ("bedrock_b", lambda: bedrock(7)), ("farm_dry", lambda: farmland(False)),
    ("stone_a", lambda: stone(11)), ("stone_b", lambda: stone(12)), ("stone_c", lambda: stone(13)),
    ("deep_a", lambda: deep(21)), ("deep_b", lambda: deep(22)), ("deep_c", lambda: deep(23)),
    ("farm_wet", lambda: farmland(True)), ("foundation", lambda: _foundation()),
    ("ore_soil_a", lambda: ore(soil, 31)), ("ore_soil_b", lambda: ore(soil, 32)),
    ("ore_stone_a", lambda: ore(stone, 33)), ("ore_stone_b", lambda: ore(stone, 34)),
    ("ore_deep_a", lambda: ore(deep, 35)), ("ore_deep_b", lambda: ore(deep, 36)),
    ("_", lambda: new(T, T)), ("_", lambda: new(T, T)),
    ("wall_soil", lambda: darken(soil(41), 0.42)), ("wall_stone", lambda: darken(stone(42), 0.42)),
    ("wall_deep", lambda: darken(deep(43), 0.5)),
]


def build():
    rows = (len(ORDER) + COLS - 1) // COLS
    atlas = new(COLS * T, rows * T)
    for i, (_, fn) in enumerate(ORDER):
        atlas.paste(fn(), ((i % COLS) * T, (i // COLS) * T))
    save(atlas, "tiles.png")


if __name__ == "__main__":
    build()

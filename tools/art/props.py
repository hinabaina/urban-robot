"""Объекты карты и фон: колодец, юрта, копёр шахты, ракета, дрон, холмы, облака."""
import math
from lib import new, px, rect, frame, sheet, save, rgba
from tiles import stone, soil, T
from machines import disc


def well():
    img = new(32, 32)
    for y in range(0, 8):  # двускатная крыша
        half = 4 + y * 2
        rect(img, 16 - half, y, half * 2, 1, "r2" if y % 2 else "r1")
        px(img, 16 - half, y, "K"); px(img, 15 + half, y, "K")
    rect(img, 12, 0, 8, 1, "K"); rect(img, 1, 8, 30, 1, "K")
    for x in (6, 24):
        rect(img, x - 1, 9, 4, 11, "K"); rect(img, x, 9, 2, 11, "w2"); rect(img, x, 9, 1, 11, "w3")
    rect(img, 15, 9, 1, 6, "c1")
    rect(img, 13, 14, 6, 5, "K"); rect(img, 14, 15, 4, 3, "m3"); rect(img, 14, 15, 4, 1, "m5")
    rect(img, 3, 19, 26, 13, "K")
    img.paste(stone(61).crop((0, 0, 12, 11)), (4, 20)); img.paste(stone(62).crop((0, 0, 12, 11)), (16, 20))
    rect(img, 4, 20, 24, 2, "u2"); rect(img, 6, 20, 5, 1, "u4"); rect(img, 4, 22, 24, 1, "t4")
    return img


def yurt():
    """Юрта 64x48: купол, орнаментальный пояс, решётчатая стена, дверь."""
    img = new(64, 48)
    for y in range(2, 24):
        half = int(30 * math.sqrt(max(0.0, 1 - ((23 - y) / 22.0) ** 2)))
        rect(img, 32 - half, y, half * 2, 1, "w")
        rect(img, 32 + half - max(2, half // 4), y, max(2, half // 4), 1, "c1")
        px(img, 32 - half - 1, y, "K"); px(img, 32 + half, y, "K")
        if y > 2:
            px(img, 32 - half, y, "W")
    rect(img, 20, 1, 24, 1, "K")
    rect(img, 26, 0, 12, 4, "K"); rect(img, 27, 1, 10, 2, "w2"); rect(img, 27, 1, 10, 1, "w4")
    for k in (-2, -1, 1, 2):  # верёвки купола
        for y in range(4, 23):
            px(img, 32 + int(k * (y - 2) * 0.62), y, "c1")
    rect(img, 1, 23, 62, 25, "K"); rect(img, 2, 24, 60, 23, "w")
    rect(img, 2, 24, 60, 6, "r2"); rect(img, 2, 24, 60, 1, "r3"); rect(img, 2, 29, 60, 1, "r1")
    for x in range(2, 62):  # орнамент-зигзаг
        px(img, x, 26 + (1 if (x // 2) % 2 else 0), "y3")
        if x % 8 == 3:
            px(img, x, 25, "y4"); px(img, x, 28, "y4")
    for x in range(2, 62):  # решётка кереге
        for y in range(31, 47):
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                px(img, x, y, "c1")
    rect(img, 50, 30, 12, 17, "c1")
    rect(img, 24, 26, 16, 22, "K"); rect(img, 25, 27, 14, 21, "w2")
    rect(img, 27, 29, 10, 19, "w1"); rect(img, 28, 30, 8, 17, "r1")
    rect(img, 29, 31, 6, 2, "y3"); px(img, 34, 39, "y4")
    for y in range(34, 46, 3):
        px(img, 30, y, "y2"); px(img, 33, y, "y2")
    return img


def headframe():
    """Копёр над стволом старой шахты, 48x40 (ствол посередине)."""
    img = new(48, 40)
    for x0 in (5, 39):
        rect(img, x0 - 1, 8, 5, 32, "K"); rect(img, x0, 8, 3, 32, "w2"); rect(img, x0, 8, 1, 32, "w3")
    for i in range(16):  # раскосы
        px(img, 8 + i, 26 - i, "w1"); px(img, 39 - i, 26 - i, "w1")
    rect(img, 2, 5, 44, 6, "K"); rect(img, 3, 6, 42, 4, "w3"); rect(img, 3, 6, 42, 1, "w4"); rect(img, 3, 9, 42, 1, "w1")
    disc(img, 24, 5, 5, "K"); disc(img, 24, 5, 4, "m3"); disc(img, 24, 5, 2, "m1"); px(img, 23, 4, "m5")
    rect(img, 24, 10, 1, 30, "c1")
    return img


def cyl(img, y, h, x0=8, w=16, body="w", shade="c1"):
    rect(img, x0 - 1, y, w + 2, h, "K")
    rect(img, x0, y, w, h, body)
    rect(img, x0, y, 2, h, "W"); rect(img, x0 + w - 4, y, 4, h, shade); rect(img, x0 + w - 1, y, 1, h, "m4")


def rocket_parts():
    """Пять частей ракеты снизу вверх; каждая 32 px шириной. Высоты — в HEIGHTS."""
    base = new(32, 12)
    rect(img := base, 2, 0, 28, 3, "K"); rect(img, 3, 1, 26, 1, "m4")
    for x in (4, 14, 24):
        rect(img, x, 3, 4, 9, "K"); rect(img, x + 1, 3, 2, 8, "m3")
    for i in range(8):
        px(img, 8 + i, 4 + i, "m2"); px(img, 23 - i, 4 + i, "m2")
    px(img, 3, 1, "o3"); px(img, 28, 1, "o3")
    engine = new(32, 20)
    cyl(engine, 0, 10, body="m3", shade="m2")
    for y in range(10, 20):
        half = 5 + (y - 10) // 2
        rect(engine, 16 - half, y, half * 2, 1, "m1"); px(engine, 16 - half, y, "K"); px(engine, 15 + half, y, "K")
        px(engine, 17 - half, y, "m3")
    rect(engine, 6, 19, 20, 1, "K")
    for y in range(2, 14):  # стабилизаторы
        w = min(6, (y - 1) // 2 + 1)
        rect(engine, 7 - w, y, w, 1, "r2"); px(engine, 7 - w, y, "K")
        rect(engine, 25, y, w, 1, "r1"); px(engine, 24 + w, y, "K")
    rect(engine, 1, 14, 6, 1, "K"); rect(engine, 25, 14, 6, 1, "K")
    tank = new(32, 28)
    cyl(tank, 0, 28)
    rect(tank, 8, 4, 16, 3, "o2"); rect(tank, 8, 4, 2, 3, "o3"); rect(tank, 8, 22, 16, 1, "c1")
    for y in range(10, 20, 3):
        px(tank, 12, y, "m4"); px(tank, 13, y, "m4")
    hull = new(32, 28)
    cyl(hull, 0, 28)
    rect(hull, 8, 18, 16, 4, "u2"); rect(hull, 8, 18, 2, 4, "u3")
    disc(hull, 16, 9, 5, "K"); disc(hull, 16, 9, 4, "u3"); disc(hull, 16, 9, 2, "u2"); px(hull, 14, 7, "u4")
    nose = new(32, 28)
    for y in range(0, 28):
        half = 1 + int(7 * math.sin(min(1.0, y / 22.0) * math.pi / 2))
        key = "r2" if y < 12 else "w"
        rect(nose, 16 - half, y, half * 2, 1, key)
        px(nose, 16 - half, y, "r3" if y < 12 else "W"); px(nose, 15 + half, y, "r1" if y < 12 else "c1")
        px(nose, 16 - half - 1, y, "K"); px(nose, 16 + half, y, "K")
    rect(nose, 15, 0, 2, 1, "K"); rect(nose, 9, 12, 14, 1, "K")
    for name, im in (("base", base), ("engine", engine), ("tank", tank), ("hull", hull), ("nose", nose)):
        save(im, "rocket_%s.png" % name)
    patch = new(10, 10)
    rect(patch, 0, 0, 10, 10, "K"); rect(patch, 1, 1, 8, 8, "w3"); rect(patch, 1, 1, 8, 1, "w4")
    for i in range(2, 8, 2):
        px(patch, i, 3, "K"); px(patch, i, 6, "K")
    save(patch, "rocket_patch.png")


def drone(f):
    img = new(32, 16)
    rect(img, 4, 4, 24, 1, "K")
    for cx in (5, 26):
        rect(img, cx, 2, 1, 3, "K")
        if f == 0:
            rect(img, cx - 5, 1, 11, 1, "m5"); rect(img, cx - 5, 2, 11, 1, "m3")
        else:
            rect(img, cx - 2, 1, 5, 1, "m5"); rect(img, cx - 2, 2, 5, 1, "m3")
    rect(img, 9, 4, 14, 8, "K"); rect(img, 10, 5, 12, 6, "m4"); rect(img, 10, 5, 12, 1, "m5"); rect(img, 10, 10, 12, 1, "m3")
    rect(img, 13, 6, 6, 3, "K"); rect(img, 14, 7, 4, 1, "u3")
    px(img, 11, 8, "o3" if f == 0 else "r2")
    for x in (11, 20):
        rect(img, x, 12, 1, 3, "K")
    rect(img, 9, 15, 5, 1, "K"); rect(img, 18, 15, 5, 1, "K")
    return img


def hills(color, seed, h=40, w=256, amp=10):
    img = new(w, h)
    for x in range(w):
        t = x / w * 2 * math.pi
        top = h * 0.45 + amp * math.sin(t + seed) + amp * 0.5 * math.sin(3 * t + seed * 2) + amp * 0.25 * math.sin(7 * t + seed * 3)
        for y in range(int(top), h):
            img.putpixel((x, y), rgba(color))
    return img


def cloud(seed):
    img = new(48, 16)
    for cx, cy, r in ((12, 10, 5), (22, 8, 7), (33, 10, 5), (40, 11, 3))[: 3 + seed]:
        disc(img, cx, cy, r, "W")
    rect(img, 8, 13, 35, 2, "W"); rect(img, 9, 14, 33, 1, "u4")
    return img


def foundation():
    """Тайл-плита под постройками и площадкой дрона (не копается)."""
    img = soil(71)
    rect(img, 0, 0, T, 5, "m2"); rect(img, 0, 0, T, 1, "m4"); rect(img, 0, 4, T, 1, "K")
    for x in range(T):
        if (x // 4) % 2 == 0:
            rect(img, x, 1, 1, 3, "y3")
        else:
            rect(img, x, 1, 1, 3, "m1")
    return img


def build():
    save(well(), "well.png")
    save(yurt(), "yurt.png")
    save(headframe(), "headframe.png")
    rocket_parts()
    save(sheet([drone(0), drone(1)]), "drone.png")
    save(hills("#b7c394", 0.7, amp=7), "hills_far.png")
    save(hills("#cdbb6e", 2.9, amp=5), "hills_near.png")
    save(sheet([cloud(0), cloud(1)]), "clouds.png")


if __name__ == "__main__":
    build()

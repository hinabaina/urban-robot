"""Машины и постройки сетки: конвейер, бур, печь, поливалка, сборщик, склад, костёр, лестница, посевы."""
import math
from lib import new, px, rect, frame, sheet, save, ascii_sprite
from sprites import ITEMS, LEG
from tiles import stone


def conveyor(f):
    """Кадр ленты, движение вправо. Остальные направления получаются поворотом в игре."""
    img = new(16, 16)
    rect(img, 0, 1, 16, 14, "K")
    rect(img, 0, 2, 16, 12, "m1")
    rect(img, 0, 2, 16, 1, "m4"); rect(img, 0, 3, 16, 1, "m3")
    rect(img, 0, 12, 16, 1, "m3"); rect(img, 0, 13, 16, 1, "m2")
    for cx in range(-8, 24, 8):
        x0 = cx + f * 2
        for i, y in enumerate((5, 6, 7, 8, 9, 10)):
            dx = i if i < 3 else 5 - i
            px(img, x0 + dx, y, "o1"); px(img, x0 + dx + 1, y, "o2"); px(img, x0 + dx + 2, y, "o3")
    return img


def disc(img, cx, cy, r, key):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r:
                px(img, x, y, key)


def drill(f):
    img = new(32, 32)
    rect(img, 10, 0, 12, 6, "K"); rect(img, 11, 1, 10, 4, "m3"); rect(img, 11, 1, 10, 1, "m5")
    rect(img, 14, 2, 4, 2, "o3" if f % 2 == 0 else "o2")
    rect(img, 2, 5, 28, 26, "K"); rect(img, 3, 6, 26, 24, "m2")
    rect(img, 3, 6, 26, 1, "m4"); rect(img, 3, 7, 1, 22, "m3"); rect(img, 28, 7, 1, 23, "m1")
    for x, y in ((4, 8), (27, 8), (4, 21), (27, 21)):
        px(img, x, y, "m5")
    for x in range(3, 29):  # полоса «осторожно»
        for y in range(24, 29):
            px(img, x, y, "y3" if ((x + y) // 3) % 2 == 0 else "K")
    rect(img, 3, 23, 26, 1, "K"); rect(img, 3, 29, 26, 1, "m1")
    disc(img, 16, 15, 9, "K"); disc(img, 16, 15, 8, "m1")
    for k in range(3):  # три лопасти шнека
        a = f * math.pi / 6 + k * 2 * math.pi / 3
        for r in range(1, 8):
            x = 16 + math.cos(a) * r - 0.5; y = 15 + math.sin(a) * r - 0.5
            px(img, round(x), round(y), "m5" if r > 2 else "m4")
            px(img, round(x + math.cos(a + 1.57)), round(y + math.sin(a + 1.57)), "m3")
    rect(img, 15, 14, 2, 2, "o2")
    return img


def furnace(mode):
    """mode 0 — холодная, 1 и 2 — огонь (два кадра мерцания)."""
    img = new(32, 32)
    rect(img, 19, 0, 8, 10, "K"); rect(img, 20, 1, 6, 9, "t1"); rect(img, 20, 1, 6, 1, "t3"); rect(img, 20, 3, 6, 1, "K")
    rect(img, 2, 8, 28, 23, "K")
    for ty in (0, 1):
        for tx in (0, 1):
            img.paste(stone(50 + tx + ty * 2).crop((0, 0, 13, 11 if ty else 10)), (3 + tx * 13, 9 + ty * 10))
    rect(img, 3, 9, 26, 1, "t4"); rect(img, 2, 7, 28, 2, "K"); rect(img, 3, 7, 26, 1, "m4")
    rect(img, 8, 15, 16, 13, "K")
    rect(img, 9, 16, 14, 11, "b1")
    px(img, 9, 16, "K"); px(img, 22, 16, "K")
    if mode == 0:
        for x in (12, 15, 18):
            rect(img, x, 17, 1, 10, "m1")
        rect(img, 10, 24, 12, 2, "b3")
    else:
        rect(img, 9, 19, 14, 8, "o1"); rect(img, 10, 21, 12, 6, "o2")
        tips = ((11, 18), (15, 17), (19, 19)) if mode == 1 else ((12, 19), (16, 18), (20, 17))
        for x, y in tips:
            rect(img, x, y, 2, 27 - y, "o3"); rect(img, x, y + 3, 2, 24 - y, "y4")
        rect(img, 10, 26, 12, 1, "y4")
        for x in (7, 24):
            for y in range(17, 27, 3):
                px(img, x, y, "o1")
    rect(img, 3, 30, 26, 1, "t1")
    return img


def sprinkler(f):
    img = new(16, 16)
    rect(img, 3, 12, 10, 4, "K"); rect(img, 4, 13, 8, 2, "m2"); rect(img, 4, 13, 8, 1, "m4")
    rect(img, 6, 5, 4, 8, "K"); rect(img, 7, 6, 2, 7, "m3"); px(img, 7, 6, "m5")
    rect(img, 3, 2, 10, 5, "K"); rect(img, 4, 3, 8, 3, "u2"); rect(img, 4, 3, 8, 1, "u3"); rect(img, 7, 4, 2, 1, "u4")
    drops = ((1, 5), (14, 5), (0, 8), (15, 8)) if f == 0 else ((1, 7), (14, 7), (2, 10), (13, 10), (0, 11), (15, 11))
    for x, y in drops:
        px(img, x, y, "u3"); px(img, x, y + 1, "u2")
    return img


def harvester(f):
    img = new(16, 16)
    rect(img, 2, 5, 12, 9, "K"); rect(img, 3, 6, 10, 7, "y2"); rect(img, 3, 6, 10, 1, "y4"); rect(img, 3, 12, 10, 1, "y1")
    rect(img, 5, 8, 6, 3, "K"); rect(img, 6, 9, 4, 1, "u3")
    for cx in (4, 11):
        rect(img, cx - 1, 13, 3, 3, "K"); px(img, cx, 14, "m3")
    rect(img, 1, 1, 14, 4, "K"); rect(img, 2, 2, 12, 2, "m3")
    for x in range(2 + f, 14, 2):  # зубья мотовила
        px(img, x, 2, "m5"); px(img, x, 3, "m1")
    return img


def storage():
    img = new(32, 32)
    for y in range(0, 7):  # крыша
        rect(img, 6 - y, y, 20 + y * 2, 1, "m2" if y else "K")
        px(img, 6 - y, y, "K"); px(img, 25 + y, y, "K")
    rect(img, 7, 1, 18, 1, "m4"); rect(img, 0, 7, 32, 1, "K")
    rect(img, 1, 8, 30, 23, "K"); rect(img, 2, 8, 28, 22, "w2")
    for x in range(2, 30):
        if x % 5 == 1:
            rect(img, x, 8, 1, 22, "w1")
        elif x % 5 == 2:
            rect(img, x, 8, 1, 22, "w3")
    for y in (9, 27):
        rect(img, 2, y, 28, 2, "m2"); rect(img, 2, y, 28, 1, "m4")
        for x in (4, 15, 27):
            px(img, x, y + 1, "m5")
    rect(img, 9, 13, 14, 12, "K"); rect(img, 10, 14, 12, 10, "w")
    ingot = ascii_sprite(ITEMS["ingot"], LEG)
    img.paste(ingot, (12, 15), ingot)
    rect(img, 2, 30, 28, 1, "w1")
    return img


def campfire(f):
    img = new(16, 16)
    for x, y, k in ((1, 13, "t2"), (4, 14, "t3"), (9, 14, "t2"), (12, 13, "t3")):
        rect(img, x, y, 3, 2, k); px(img, x, y, "t4")
    for i in range(8):  # два скрещённых полена
        px(img, 4 + i, 12 - i // 3, "w2"); px(img, 4 + i, 13 - i // 3, "w1")
        px(img, 11 - i, 12 - i // 3, "w3"); px(img, 11 - i, 13 - i // 3, "w1")
    if f > 0:
        sway = (0, -1, 1)[f - 1]; top = (3, 2, 4)[f - 1]
        for y in range(top, 12):
            t = (y - top) / (11 - top)
            half = 1 + int(3 * math.sin(t * 2.4) + 0.3)
            cx = 8 + (sway if y < 7 else 0)
            rect(img, cx - half, y, half * 2, 1, "o2")
            if half > 1:
                rect(img, cx - half + 1, y + 1, half * 2 - 2, 1, "o3")
            if half > 2 and y > top + 3:
                rect(img, cx - 1, y, 2, 1, "y4")
        px(img, 8 + sway * 2, top - 1, "o3")
    else:
        rect(img, 6, 11, 4, 1, "b3")
    return img


def ladder():
    img = new(16, 16)
    for x in (3, 11):
        rect(img, x, 0, 2, 16, "w2"); rect(img, x, 0, 1, 16, "w3")
    for y in (1, 5, 9, 13):
        rect(img, 2, y, 12, 2, "w3"); rect(img, 2, y + 1, 12, 1, "w1"); rect(img, 2, y, 12, 1, "w4")
    return img


def crop(stage):
    """Стадии 1..4: росток, зелёный колос, желтеет, зрелый."""
    img = new(16, 16)
    for sx, lean in ((3, 0), (8, 1), (12, 0)):
        h = (4, 9, 11, 12)[stage - 1] - lean
        stem = "n2" if stage < 4 else "y1"
        for y in range(16 - h, 16):
            px(img, sx, y, stem)
        if stage == 1:
            px(img, sx - 1, 16 - h, "n3"); px(img, sx + 1, 16 - h + 1, "n3")
            continue
        px(img, sx - 1, 12, "n2" if stage < 4 else "y2"); px(img, sx + 1, 10, "n3" if stage < 4 else "y2")
        ear, hi = (("n3", "n2"), ("y2", "n3"), ("y3", "y4"))[stage - 2]
        top = 16 - h
        rect(img, sx - 1, top, 3, 5 if stage > 2 else 4, ear)
        px(img, sx, top - 1, ear); px(img, sx - 1, top + 1, hi); px(img, sx + 1, top + 3, "y1" if stage > 2 else "n1")
    return img


def build():
    save(sheet([conveyor(f) for f in range(4)]), "conveyor.png")
    save(sheet([drill(f) for f in range(4)]), "drill.png")
    save(sheet([furnace(m) for m in range(3)]), "furnace.png")
    save(sheet([sprinkler(f) for f in range(2)]), "sprinkler.png")
    save(sheet([harvester(f) for f in range(2)]), "harvester.png")
    save(storage(), "storage.png")
    save(sheet([campfire(f) for f in range(4)]), "campfire.png")
    save(ladder(), "ladder.png")
    save(sheet([crop(s) for s in range(1, 5)]), "crops.png")


if __name__ == "__main__":
    build()

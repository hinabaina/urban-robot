"""Элементы интерфейса: панели и слоты (9-patch, поля 4 px), полоса прогресса, стрелка выхода."""
from lib import new, px, rect, frame, save, rgba

FILL = "#20263a"
FILL_HI = "#2b3350"


def box(border, fill=FILL, inner=None, size=16):
    img = new(size, size)
    rect(img, 1, 0, size - 2, size, "K"); rect(img, 0, 1, size, size - 2, "K")
    rect(img, 1, 1, size - 2, size - 2, border)
    rect(img, 2, 2, size - 4, size - 4, fill)
    rect(img, 2, 2, size - 4, 1, inner or FILL_HI)
    for x, y in ((1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)):
        px(img, x, y, "K")
    return img


def wood_box(fill, fill_hi, size=16):
    """Уютная рамка в духе Stardew Valley: тёмный контур, деревянный борт со светлой гранью, светлое поле."""
    img = new(size, size)
    rect(img, 1, 0, size - 2, size, "K"); rect(img, 0, 1, size, size - 2, "K")
    rect(img, 1, 1, size - 2, size - 2, "w2")
    rect(img, 1, 1, size - 2, 1, "w4"); rect(img, 1, 1, 1, size - 2, "w3")
    rect(img, 1, size - 2, size - 2, 1, "w1"); rect(img, size - 2, 1, 1, size - 2, "w1")
    rect(img, 3, 3, size - 6, size - 6, "w1")
    rect(img, 4, 4, size - 8, size - 8, fill)
    rect(img, 4, 4, size - 8, 1, fill_hi)
    for x, y in ((1, 1), (size - 2, 1), (1, size - 2), (size - 2, size - 2)):
        px(img, x, y, "K")
    return img


def arrow():
    """Стрелка «выход машины», смотрит вправо, 8x8."""
    img = new(8, 8)
    for i, w in enumerate((1, 2, 3, 4, 4, 3, 2, 1)):
        rect(img, 2, i, w, 1, "o3")
        px(img, 1, i, "K"); px(img, 2 + w, i, "K")
    return img


def cracks():
    """Три стадии трещин при копании, 16x16 каждая."""
    from lib import sheet
    paths = [((7, 6), (8, 7), (8, 8), (9, 9)), ((6, 5), (5, 4), (10, 10), (11, 11), (7, 9), (6, 10)),
             ((4, 3), (12, 12), (5, 11), (4, 12), (10, 6), (11, 5), (12, 4), (9, 8))]
    frames, pts = [], []
    for p in paths:
        pts += p
        img = new(16, 16)
        for x, y in pts:
            px(img, x, y, "K", 210); px(img, x + 1, y, "W", 90)
        frames.append(img)
    return sheet(frames)


def save2x(img, name):
    """Интерфейс рисуется в экранных пикселях, а мир — с зумом 2: увеличиваем, чтобы пиксель был одного размера."""
    from PIL import Image
    save(img.resize((img.width * 2, img.height * 2), Image.NEAREST), name)


def build():
    save2x(box("m3"), "ui_panel.png")
    save2x(box("m2", "#171b2b", "#171b2b"), "ui_slot.png")
    save2x(box("o3", "#2a2338", "#3a2f45"), "ui_slot_selected.png")
    save2x(box("m4", "#35405e", "#4a5880"), "ui_button.png")
    save2x(box("o3", "#4a5880", "#6373a3"), "ui_button_hover.png")
    save2x(box("m2", "#171b2b", "#101320"), "ui_button_pressed.png")
    save2x(box("m2", "#101320", "#101320", 12), "ui_bar_bg.png")
    bar = new(8, 8); rect(bar, 0, 0, 8, 8, "y2"); rect(bar, 0, 0, 8, 2, "y4"); rect(bar, 0, 6, 8, 2, "y1")
    save2x(bar, "ui_bar_fill.png")
    gold = new(8, 8); rect(gold, 0, 0, 8, 8, "n2"); rect(gold, 0, 0, 8, 2, "n3"); rect(gold, 0, 6, 8, 2, "n1")
    save2x(gold, "ui_bar_fill_done.png")
    save2x(wood_box("#efe2bf", "#f8efd6"), "ui_dialog.png")
    save2x(wood_box("#7fa7c4", "#9cc0d8"), "ui_portrait.png")
    save2x(wood_box("#e3d2a6", "#efe2bf"), "ui_choice.png")
    save2x(wood_box("#f6d27a", "#fbe6a8"), "ui_choice_hover.png")
    save(arrow(), "arrow_out.png")
    save(cracks(), "cracks.png")


if __name__ == "__main__":
    build()

"""Презентация DALA WORKS для защиты (трек Gambit «AUTOMATE IT!»): 10 слайдов в графике игры. Владелец: B.

Запуск: python3 tools/deck/build_deck.py <папка с кадрами из игры>
Кадры снимаются автопроверкой: tools/b_smoke/shot.sh <папка>/bg_dawn.png 1.2 clean 7.0 26 11 1 и т. д.
Результат: docs/presentation.pdf (сдача по ТЗ) и docs/presentation.pptx (слайды-картинки с заметками для питча).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SPR = os.path.join(ROOT, "assets", "sprites")
FONTS = os.path.join(ROOT, "assets", "fonts")
W, H = 2560, 1440
PX = 4                                   # кадры 1280x720 растягиваем ровно вдвое, спрайты — в PX раз
CREAM = (243, 234, 210)
INK = (59, 42, 31)
ACCENT = (255, 171, 69)
RED = (168, 67, 47)
GREEN = (132, 201, 90)
MUTED = (196, 178, 150)
SHADOW = (20, 14, 10)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


TITLE = lambda s: font("PressStart2P-Regular.ttf", s)
BODY = lambda s: font("DalaPixel.ttf", s)


def sprite(name, frame=0, frames=1, scale=PX):
    im = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
    w = im.width // frames
    im = im.crop((frame * w, 0, frame * w + w, im.height))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def item(index, scale=PX * 2):
    return sprite("items", index, 3, scale)


def icon(index, scale=PX * 2):
    return sprite("icons", index, 11, scale)


def nine(name, w, h, scale=4):
    """Девять частей рамки из текстуры интерфейса игры (поля 4 px исходника)."""
    src = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
    src = src.resize((src.width // 2, src.height // 2), Image.NEAREST)   # исходник уже увеличен вдвое
    m = 4
    s = src.width
    out = Image.new("RGBA", (w, h))
    cm = m * scale
    parts = {
        "tl": (0, 0, m, m), "t": (m, 0, s - m, m), "tr": (s - m, 0, s, m),
        "l": (0, m, m, s - m), "c": (m, m, s - m, s - m), "r": (s - m, m, s, s - m),
        "bl": (0, s - m, m, s), "b": (m, s - m, s - m, s), "br": (s - m, s - m, s, s),
    }
    def piece(key, size):
        return src.crop(parts[key]).resize(size, Image.NEAREST)
    out.paste(piece("c", (w - 2 * cm, h - 2 * cm)), (cm, cm))
    out.paste(piece("t", (w - 2 * cm, cm)), (cm, 0)); out.paste(piece("b", (w - 2 * cm, cm)), (cm, h - cm))
    out.paste(piece("l", (cm, h - 2 * cm)), (0, cm)); out.paste(piece("r", (cm, h - 2 * cm)), (w - cm, cm))
    for key, pos in (("tl", (0, 0)), ("tr", (w - cm, 0)), ("bl", (0, h - cm)), ("br", (w - cm, h - cm))):
        out.paste(piece(key, (cm, cm)), pos)
    return out


class Slide:
    def __init__(self, bg, dim=0.55):
        im = Image.open(os.path.join(SHOTS, bg)).convert("RGBA").resize((W, H), Image.NEAREST)
        shade = Image.new("RGBA", (W, H), (16, 11, 8, int(255 * dim)))
        self.im = Image.alpha_composite(im, shade)
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"                    # без сглаживания: пиксельный шрифт остаётся чётким

    def paste(self, im, xy):
        self.im.alpha_composite(im, (int(xy[0]), int(xy[1])))

    def panel(self, x, y, w, h, kind="ui_panel"):
        self.paste(nine(kind, w, h), (x, y))

    def text(self, xy, s, f, fill=CREAM, shadow=True, anchor="la"):
        if shadow:
            self.d.text((xy[0] + 6, xy[1] + 6), s, font=f, fill=SHADOW, anchor=anchor)
        self.d.text(xy, s, font=f, fill=fill, anchor=anchor)

    def wrap(self, x, y, w, s, f, fill=CREAM, gap=18, shadow=True):
        """Текст с переносом по ширине; возвращает y под последней строкой."""
        for para in s.split("\n"):
            line = ""
            for word in para.split(" "):
                probe = (line + " " + word).strip()
                if self.d.textlength(probe, font=f) > w and line:
                    self.text((x, y), line, f, fill, shadow)
                    y += f.size + gap
                    line = word
                else:
                    line = probe
            self.text((x, y), line, f, fill, shadow)
            y += f.size + gap
        return y

    def title(self, s, sub=None, n=None):
        self.text((120, 110), s, TITLE(64), ACCENT)
        if sub:
            self.text((124, 220), sub, BODY(48), MUTED)
        if n is not None:
            self.panel(W - 230, 90, 130, 110)
            self.text((W - 165, 147), str(n), TITLE(40), CREAM, anchor="mm")

    def bullets(self, x, y, w, items, f=None, mark=None):
        f = f or BODY(48)
        for s in items:
            self.paste(mark or item(2, PX * 2), (x, y + 6))
            y = self.wrap(x + 96, y, w - 96, s, f) + 22
        return y

    def shot(self, name, x, y, w, frame=True):
        im = Image.open(os.path.join(SHOTS, name)).convert("RGBA")
        h = int(w * im.height / im.width)
        im = im.resize((w, h), Image.NEAREST)
        if frame:
            self.panel(x - 28, y - 28, w + 56, h + 56)
        self.paste(im, (x, y))
        return h

    def save(self, path):
        self.im.convert("RGB").save(path)


def face(who, px=16):
    """Портрет героя рации — те же пиксели, что в игре (ui/Radio.gd)."""
    rows = {"aisha": ["....rrrr....", "...rrrrrr...", "..rrssssrr..", "..rhsssshr..", "..rsesseshr.", "..rsssssshr.",
                      "..hssmmsshh.", "..hhsssshh..", ".hh.bbbb.hh.", ".h.bbwwbb.h.", "...bbbbbb...", "...bbbbbb..."],
            "erzhan": ["...kkkkkk...", "..kykykyk...", "..kkkkkkkk..", ".wssssssssw.", ".wsessssesw.", "..ssssssss..",
                       "..swwwwwws..", "..wwwmmwww..", "...wwwwww...", "..ccwwwwcc..", ".cccccccccc.", ".cccccccccc."],
            "dispatcher": ["...gggggg...", "..gggggggg..", "..gggyyggg..", "..hhhhhhhh..", "..ssssssss..", "..sllsslls..",
                           "..ssssssss..", "..sssmmsss..", "...ssssss...", "..ddwrrwdd..", ".dddwrrwddd.", ".ddddrrdddd."]}[who]
    pal = {"r": "#d9483b", "s": "#e8b48a", "h": "#2b2233", "e": "#1a1423", "m": "#a8443c", "b": "#3f6fb5",
           "w": "#f3ead2", "k": "#2f6b4f", "y": "#f4d34f", "c": "#7a5230", "g": "#5b6478", "d": "#2e3445", "l": "#9fd4e8"}
    im = Image.new("RGBA", (12 * px, 12 * px), "#7fa7c4")
    d = ImageDraw.Draw(im)
    for y, row in enumerate(rows):
        for x, k in enumerate(row):
            if k in pal:
                d.rectangle((x * px, y * px, x * px + px - 1, y * px + px - 1), fill=pal[k])
    return im


def rocket(scale=PX * 2):
    parts = ["rocket_nose", "rocket_hull", "rocket_tank", "rocket_engine", "rocket_base"]
    ims = [sprite(p, scale=scale) for p in parts]
    w = max(i.width for i in ims)
    out = Image.new("RGBA", (w, sum(i.height for i in ims)))
    y = 0
    for i in ims:
        out.alpha_composite(i, ((w - i.width) // 2, y)); y += i.height
    return out


NOTES = {}


def s1(out):
    s = Slide("bg_dawn.png", 0.15)
    s.panel(110, 120, 1640, 540)
    s.text((190, 220), "DALA WORKS", TITLE(112), ACCENT)
    s.text((196, 390), "Автоматизируй себя", BODY(60), CREAM)
    s.text((196, 470), "и запусти спутник из степи", BODY(60), CREAM)
    s.text((196, 575), "2D-игра про фабрику  ·  Godot 4.7  ·  Web и Windows", BODY(36), MUTED)
    s.panel(110, 1210, 1180, 130)
    s.text((160, 1250), "GAMBIT Hackathon 2026  ·  трек AUTOMATE IT!", BODY(48), CREAM)
    s.save(out)
    NOTES[1] = "Привет! Мы команда ... Наша игра называется DALA WORKS. Это 2D-игра про то, как превратить ручной труд в фабрику."


def s2(out):
    s = Slide("bg_dusk.png", 0.6)
    s.title("Проблема", "Аул Қарасу остаётся без воды", 2)
    s.panel(100, 340, 1420, 640)
    y = s.bullets(160, 400, 1300, [
        "Колодцы пересыхают: воды осталось на пять дней.",
        "На заброшенной станции в степи стоит ракета с метеоспутником, который находит дождь.",
        "Ракету надо собрать за 5 дней. Руками не успеть: нужен завод.",
    ])
    s.panel(1600, 330, 260, 260, "ui_portrait")
    s.paste(face("aisha", 18), (1622, 352))
    s.text((1610, 620), "Айша, аул Қарасу", BODY(36), ACCENT)
    s.paste(rocket(PX * 3), (2120, 300))
    s.save(out)
    NOTES[2] = "Игрок - молодой инженер. По рации выходит Айша: в ауле сохнут колодцы. Спасти может только метеоспутник, но ракету нужно собрать за пять дней."


def s3(out):
    s = Slide("bg_noon.png", 0.6)
    s.title("Идея", "Знакомые жанры, свой поворот", 3)
    cols = [(icon(0), "Копаешь вглубь", "как в Terraria: почва, камень, бесконечная глубина"),
            (icon(5), "Живёшь днями", "как в Stardew Valley: утро, работа, вечер, сон и отчёт"),
            (sprite("conveyor", 0, 4, PX * 2), "Строишь линии", "как в Factorio: бур, лента, печь, склад, узкие места")]
    for i, (pic, head, text) in enumerate(cols):
        x = 140 + i * 790
        s.panel(x, 380, 740, 760)
        s.paste(pic, (x + 370 - pic.width // 2, 440))
        s.text((x + 60, 640), head, BODY(60), ACCENT)
        s.wrap(x + 60, 740, 620, text, BODY(48))
    s.wrap(140, 1200, 2300, "Наш поворот: степь под Актобе, сюжет по рации и выбор, куда смотрит спутник.", BODY(48), MUTED)
    s.save(out)
    NOTES[3] = "Мы взяли знакомые механики: копание из Terraria, ритм дня из Stardew Valley и линии из Factorio. Свой поворот - казахская степь, сюжет по рации и моральный выбор в конце."


def s4(out):
    s = Slide("bg_noon.png", 0.7)
    s.title("Игровой цикл", "Один день - около 2,5 минут, вся игра 12-15 минут", 4)
    steps = [(item(0, PX * 4), "Копай руду"), (sprite("furnace", 1, 3, PX * 2), "Плавь слитки"),
             (sprite("drill", 0, 4, PX * 2), "Строй линию"), (sprite("drone", 0, 2, PX * 3), "18:00 дрон\nзабирает норму"),
             (icon(6), "Ночь x20,\nутром отчёт")]
    xs = [180, 650, 1120, 1590, 2060]
    for (pic, label), x in zip(steps, xs):
        s.panel(x, 450, 360, 360)
        s.paste(pic, (x + 180 - pic.width // 2, 630 - pic.height // 2))
        yy = 850
        for line in label.split("\n"):
            s.text((x + 180, yy), line, BODY(48), CREAM, anchor="ma"); yy += 64
    for x in xs[:-1]:
        s.text((x + 410, 610), ">", TITLE(56), ACCENT, anchor="mm")
    s.wrap(180, 1110, 2200, "Каждый день норма растёт: 8, 15, 25, 35, 50 слитков. Не сдал - минус одно доверие из трёх.", BODY(48))
    s.save(out)
    NOTES[4] = "Цикл простой: копаешь, плавишь, строишь линию. В 18:00 прилетает дрон и забирает норму. Ночью игрок спит, а фабрика работает в двадцать раз быстрее. Утром отчёт с узким местом."


def s5(out):
    s = Slide("bg_noon.png", 0.75)
    s.title("Что автоматизирует игрок", None, 5)
    h = s.shot("ui_line.png", 140, 300, 1400)
    s.bullets(1660, 300, 780, [
        "Бур добывает руду сам.",
        "Лента везёт её в печь, вверх - это лифт из шахты.",
        "Печь плавит слитки и отдаёт их на склад.",
        "Поливалка и сборщик кормят печь зерном.",
        "Q поворачивает выход любой машины.",
    ], BODY(44))
    s.wrap(140, 300 + h + 80, 2300, "Игрок перестаёт копать руками и начинает думать как инженер: где поставить бур, куда пустить ленту, что тормозит.", BODY(44), MUTED)
    s.save(out)
    NOTES[5] = "Вот линия первого дня: бур на выходе руды, лента, печь, склад. Дальше ферма кормит печь зерном, а лифт поднимает руду из глубины."


def s6(out):
    s = Slide("bg_dawn.png", 0.7)
    s.title("Тест на автоматизацию из ТЗ", None, 6)
    qa = [("Сломается ли игра без автоматизации?", "Да. Руками выходит 8-10 слитков в день, а нормы растут до 50."),
          ("Можно ли улучшать систему после запуска?", "Да. Больше буров и печей, перестройка линий, рентген (X) показывает узкие места."),
          ("Работает ли она без ручного ввода?", "Да. Ночью игрок спит, фабрика работает, утром отчёт.")]
    y = 330
    for q, a in qa:
        s.panel(140, y, 1420, 290)
        s.text((200, y + 50), q, BODY(48), ACCENT)
        s.wrap(200, y + 130, 1300, a, BODY(44))
        y += 330
    # Нормы против ручного потолка.
    base, left, bw = 1260, 1700, 120
    s.panel(1620, 300, 840, 1060)
    s.text((1680, 350), "Нормы и руки", BODY(48), ACCENT)
    for i, q in enumerate([8, 15, 25, 35, 50]):
        x = left + i * 150
        h = q * 15
        s.d.rectangle((x, base - h, x + bw, base), fill=(224, 123, 36))
        s.d.rectangle((x, base - h, x + bw, base - h + 12), fill=(255, 171, 69))
        s.text((x + bw // 2, base - h - 60), str(q), BODY(48), CREAM, anchor="ma")
        s.text((x + bw // 2, base + 20), "д%d" % (i + 1), BODY(36), MUTED, anchor="ma")
    hy = base - 10 * 15
    s.d.rectangle((left - 20, hy - 4, left + 4 * 150 + bw + 20, hy + 4), fill=GREEN)
    s.d.rectangle((1680, 448, 1740, 456), fill=GREEN)          # легенда: зелёная черта — ручной потолок
    s.text((1760, 430), "руками ~10 в день", BODY(36), GREEN)
    s.save(out)
    NOTES[6] = "Три вопроса из ТЗ. Без машин игра ломается уже на втором дне: руками больше десяти слитков не сделать. Систему можно улучшать, и она работает без игрока - ночью."


def s7(out):
    s = Slide("bg_dusk.png", 0.65)
    s.title("Сюжет и выборы", "Рация, три героя, пять концовок", 7)
    h = s.shot("radio_reply.png", 140, 360, 1360)
    x = 1620
    for i, (who, name, role) in enumerate([("aisha", "Айша", "аул Қарасу"), ("erzhan", "Ержан-ата", "старик из аула"),
                                           ("dispatcher", "Сабит", "диспетчер комбината")]):
        y = 340 + i * 260
        s.panel(x, y, 200, 200, "ui_portrait")
        s.paste(face(who, 13), (x + 22, y + 22))
        s.text((x + 240, y + 40), name, BODY(48), ACCENT)
        s.text((x + 240, y + 110), role, BODY(36), MUTED)
    s.panel(1590, 1110, 880, 240)
    s.wrap(1640, 1150, 800, "Герои запоминают ответы. В последний день игрок решает, над кем повиснет спутник.", BODY(40))
    s.save(out)
    NOTES[7] = "Чтобы было ради чего играть, мы добавили сюжет по рации. Трое героев, ответы меняют отношения. В конце диспетчер требует спутник над городом, Айша просит оставить над степью."


def s8(out):
    s = Slide("bg_mine.png", 0.72)
    s.title("Как это сделано", "Godot 4.7, GDScript", 8)
    s.panel(100, 310, 1400, 1060)
    s.bullets(160, 370, 1280, [
        "Симуляция отдельно от картинки: тик 0,25 с, обратное давление на лентах, у машин состояния (работает, стоит, нет топлива).",
        "Ночь x20 даёт тот же результат, что x1: проверено тестом.",
        "Сохранение каждое утро, три языка: русский, қазақша, English.",
        "180 тестов движка и автопроверки игры. CI сам собирает Web и Windows.",
        "Пиксель-арт, звуки и пиксельный шрифт с казахскими буквами сделаны кодом.",
    ], BODY(44))
    s.shot("ui_xray.png", 1560, 380, 880)
    s.text((1540, 940), "Рентген (X): что работает, что стоит", BODY(36), MUTED)
    s.save(out)
    NOTES[8] = "Главная техническая часть - симуляция без графики. Она тикает четыре раза в секунду и не зависит от FPS. Ленты знают про затор. На всё это 180 тестов, а сборки собирает CI."


def s9(out):
    s = Slide("bg_noon.png", 0.75)
    s.title("Демо и результат", "hinabaina.github.io/urban-robot", 9)
    s.shot("ui_line.png", 140, 360, 720)
    s.shot("report_bonds.png", 940, 360, 720)
    s.shot("win_launch.png", 1740, 360, 720)
    s.panel(100, 820, 2360, 540)
    y = s.bullets(160, 880, 1100, ["Пять дней от кирки до запуска ракеты.", "Обучение, книжка подсказок (B), ночной отчёт.",
                                   "Играется в браузере без установки."], BODY(44))
    s.text((1340, 880), "Честно о минусах", BODY(48), ACCENT)
    s.bullets(1340, 960, 1060, ["Баланс проверяли ботом и сами, большого плейтеста не было.",
                                "Озвучен только вступительный ролик.", "Казахский текст стоит вычитать носителю."], BODY(40),
              mark=item(0, PX * 2))
    s.save(out)
    NOTES[9] = "Сейчас покажем живое демо: линия первого дня, ночной отчёт и запуск ракеты. Игра открывается в браузере по ссылке на слайде."


def s10(out):
    s = Slide("bg_dawn.png", 0.55)
    s.title("Чему научились и что дальше", None, 10)
    s.panel(100, 300, 1160, 800)
    s.panel(1300, 300, 1160, 800)
    s.text((160, 340), "Научились", BODY(56), ACCENT)
    s.bullets(160, 430, 1060, ["Делить игру на движок и картинку и договариваться через контракт.",
                               "Проверять баланс ботом, а не на глаз.", "Слушать игрока: после каждого плейтеста что-то переделывали."],
              BODY(44))
    s.text((1360, 340), "Дальше", BODY(56), ACCENT)
    s.bullets(1360, 430, 1060, ["Разветвитель ленты и вторая руда.", "Прогноз погоды от спутника: засуха, дождь, буря.",
                                "Бесконечный режим «Станция» после запуска."], BODY(44))
    s.panel(760, 1150, 1040, 170)
    s.text((1280, 1235), "Спасибо!", TITLE(72), ACCENT, anchor="mm")
    s.save(out)
    NOTES[10] = "Мы научились работать вдвоём через контракт и проверять баланс автоматикой. Дальше хотим разветвитель, прогноз погоды и бесконечный режим. Спасибо!"


if __name__ == "__main__":
    SHOTS = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SHOTS, "slides")
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for i, make in enumerate([s1, s2, s3, s4, s5, s6, s7, s8, s9, s10], 1):
        p = os.path.join(out_dir, "slide%02d.png" % i)
        make(p)
        paths.append(p)
    print("slides:", len(paths))
    pdf = os.path.join(ROOT, "docs", "presentation.pdf")
    pages = [Image.open(p).convert("RGB").resize((1920, 1080), Image.LANCZOS) for p in paths]
    pages[0].save(pdf, save_all=True, append_images=pages[1:], resolution=144, quality=90)
    print("pdf:", pdf)
    from pptx import Presentation
    from pptx.util import Emu, Pt
    from pptx.dml.color import RGBColor
    deck = Presentation()
    deck.slide_width, deck.slide_height = Emu(12192000), Emu(6858000)
    for i, p in enumerate(paths, 1):
        slide = deck.slides.add_slide(deck.slide_layouts[6])
        slide.shapes.add_picture(p, 0, 0, deck.slide_width, deck.slide_height)
        slide.notes_slide.notes_text_frame.text = NOTES.get(i, "")
        if i == 1:      # редактируемое поле: название команды и состав
            box = slide.shapes.add_textbox(Emu(6600000), Emu(5950000), Emu(5200000), Emu(500000))
            run = box.text_frame.paragraphs[0].add_run()
            run.text = "Команда: название, школа, состав"
            run.font.size = Pt(20)
            run.font.color.rgb = RGBColor(243, 234, 210)
    pptx = os.path.join(ROOT, "docs", "presentation.pptx")
    deck.save(pptx)
    print("pptx:", pptx)

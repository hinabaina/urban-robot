"""Контактный лист: увеличенный просмотр спрайтов (для проверки глазами, в игру не идёт)."""
import os
import sys
from PIL import Image
from lib import OUT

def main(names, scale=4, out="/tmp/preview.png"):
    imgs = [Image.open(os.path.join(OUT, n)).convert("RGBA") for n in names]
    w = max(i.width for i in imgs) * scale + 16
    h = sum(i.height * scale + 8 for i in imgs) + 8
    sheet = Image.new("RGBA", (w, h), (120, 170, 210, 255))
    y = 8
    for i in imgs:
        sheet.paste(i.resize((i.width * scale, i.height * scale), Image.NEAREST), (8, y),
                    i.resize((i.width * scale, i.height * scale), Image.NEAREST))
        y += i.height * scale + 8
    sheet.save(out)

if __name__ == "__main__":
    main(sys.argv[2:], int(sys.argv[1]), os.environ.get("PREVIEW_OUT", "/tmp/preview.png"))

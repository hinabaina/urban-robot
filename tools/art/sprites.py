"""Спрайты, нарисованные вручную символами: игрок, предметы, иконки."""
from lib import ascii_sprite, new, px, sheet, save

LEG = {
    "K": "K", "W": "W", "w": "w", "H": "o2", "h": "o3", "j": "o1", "J": "o4",
    "S": "p2", "s": "p1", "B": "u2", "b": "u1", "L": "u3", "l": "u4", "C": "w", "c": "c1",
    "T": "m1", "M": "m2", "m": "m3", "N": "m4", "n": "m5", "D": "w1", "d": "w2", "E": "w3", "e": "w4",
    "R": "r2", "r": "r1", "Q": "r3", "Y": "y3", "y": "y2", "X": "y1", "Z": "y4",
    "G": "n2", "g": "n1", "F": "n3", "P": "t2", "p": "t1", "O": "t3", "o": "t4",
}

BODY = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....KhhHHHHK....",
    "...KhHHHHHHjK...",
    "...KHHHHHHHjKK..",
    "..KKKKKKKKKKKKK.",
    "...KSSSSSSSSK...",
    "...KSSSKSSKSK...",
    "...KsSSSSSSSK...",
    "....KsSSSSSK....",
    "...KKCCCCCCKK...",
    "..KCCBCCCCBCCK..",
    "..KCcBBBBBBcCK..",
    "..KSKBBBBBBKSK..",
    "..KSKBBBBBBKSK..",
    "...KKBBBBBBKK...",
]
BODY_BACK = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....KHHHHHHK....",
    "...KHHHHHHHHK...",
    "...KjHHHHHHjK...",
    "...KKKKKKKKKK...",
    "...KDDDDDDDDK...",
    "..KKDDDDDDDDKK..",
    ".KSKKSSSSSSKKSK.",
    ".KSKKKSSSSKKKSK.",
    ".KCCKCCCCCCKCCK.",
    "..KCCCBCCBCCCK..",
    "...KCCBBBBCCK...",
    "....KcBBBBcK....",
    "....KBBBBBBK....",
    "....KBBBBBBK....",
]
LEGS_STAND = [
    "....KBBBBBBK....",
    "....KBBKKBBK....",
    "....KBBKKBBK....",
    "....KbbKKbbK....",
    "...KTTTKKTTTK...",
    "...KTTTKKTTTK...",
    "...KKKKKKKKKK...",
]
LEGS_APART = [
    "....KBBBBBBK....",
    "...KBBBKKBBBK...",
    "..KBBBK..KBBBK..",
    "..KbbK....KbbK..",
    ".KTTTK....KTTTK.",
    ".KTTTK....KTTTTK",
    ".KKKKK....KKKKKK",
]
LEGS_PASS = [
    "....KBBBBBBK....",
    "....KBBBBBBK....",
    ".....KBBBBK.....",
    ".....KbbBBK.....",
    ".....KTTbbK.....",
    ".....KKKTTTK....",
    "........KKKK....",
]
LEGS_CLIMB_A = [
    "....KBBBBBBK....",
    "....KBBKKBBK....",
    "....KBBK.KbbK...",
    "....KbbK.KTTK...",
    "...KTTTK.KKKK...",
    "...KTTTK........",
    "...KKKKK........",
]
LEGS_CLIMB_B = [row[::-1] for row in LEGS_CLIMB_A]


def player_frame(body, legs, bob=0):
    img = new(16, 24)
    img.paste(ascii_sprite(body, LEG), (0, bob))
    legs_img = ascii_sprite(legs, LEG)
    img.paste(legs_img, (0, 17), legs_img)
    return img


def player():
    """Кадры: 0-1 стоит, 2-5 идёт, 6 прыжок, 7-8 лезет по лестнице."""
    frames = [
        player_frame(BODY, LEGS_STAND), player_frame(BODY, LEGS_STAND, 1),
        player_frame(BODY, LEGS_APART), player_frame(BODY, LEGS_PASS, 1),
        player_frame(BODY, LEGS_APART), player_frame(BODY, LEGS_PASS, 1),
        player_frame(BODY, LEGS_APART, 0),
        player_frame(BODY_BACK, LEGS_CLIMB_A), player_frame(BODY_BACK, LEGS_CLIMB_B, 1),
    ]
    save(sheet(frames), "player.png")


ITEMS = {
    "ore": [
        "........",
        "..KKKK..",
        ".KOPHhK.",
        "KOPPHHjK",
        "KPHhPPpK",
        "KpHjPppK",
        ".KpppKK.",
        "..KKK...",
    ],
    "grain": [
        "...KK...",
        "..KYZK..",
        ".KYZYXK.",
        ".KXYZYK.",
        ".KYXYXK.",
        "..KXXK..",
        "..KGgK..",
        "...KK...",
    ],
    "ingot": [
        "........",
        "..KKKKK.",
        ".KnnnnNK",
        "KnWnnNmK",
        "KNNNNmMK",
        "KmmmmMK.",
        ".KKKKK..",
        "........",
    ],
}

ICONS = {
    "pickaxe": [
        "................",
        "...KKKKKKK......",
        "..KNnnnnNmKK....",
        ".KNmKKKKKNNmK...",
        ".KmK....KeKNmK..",
        "..K....KedKKNmK.",
        "......KedK.KNmK.",
        ".....KedK...KmK.",
        "....KedK....KmK.",
        "...KedK......K..",
        "..KedK..........",
        ".KedK...........",
        "KedK............",
        "KdK.............",
        ".K..............",
        "................",
    ],
    "can": [
        "................",
        "................",
        "......KKKKK.....",
        ".....K.....K....",
        ".KK..KKKKKKKK...",
        "KLLK.KLBBBBBK...",
        "KLlLKKLBBBBBK.K.",
        ".KLLLKLBBBBBKKLK",
        "..KKLKLBBBBBBBK.",
        "....KKLBBBBBbK..",
        ".....KBBBBBBbK..",
        ".....KBBBBBbbK..",
        ".....KbbbbbbbK..",
        "......KKKKKKK...",
        "................",
        "................",
    ],
    "seed": [
        "................",
        "....KK...KK.....",
        "...KccK.KccK....",
        "....KccKccK.....",
        "....KKdddKK.....",
        "...KCCCCCCCK....",
        "..KCCCCCCCCCK...",
        "..KCCCKKCCCcK...",
        "..KCCKYZKCCcK...",
        "..KCKYZYXKCcK...",
        "..KCKXYXYKccK...",
        "..KCCKXXKCccK...",
        "..KCCCKKCcccK...",
        "...KcccccccK....",
        "....KKKKKKK.....",
        "................",
    ],
    "wrench": [
        "................",
        "..........KKK...",
        ".........KmmmK..",
        "........KmK.KmK.",
        "........KmK..K..",
        ".......KmmmK....",
        "......KmmmK.....",
        ".....KmmmK......",
        "....KmmmK.......",
        "...KmmmK........",
        "..KeddK.........",
        ".KeddK..........",
        "KeddK...........",
        "KddK............",
        ".KK.............",
        "................",
    ],
    "block": [
        "................",
        ".KKKKKKKKKKKKKK.",
        ".KeeeeeeeeeeedK.",
        ".KeddddddddddDK.",
        ".KedeedddddeeDK.",
        ".KeddddddddddDK.",
        ".KKKKKKKKKKKKKK.",
        ".KeeeeeedeeeedK.",
        ".KedddddKdddddK.",
        ".KedeeddKdedddK.",
        ".KDDDDDDKDDDDDK.",
        ".KKKKKKKKKKKKKK.",
        ".KeeedeeeeeedeK.",
        ".KeddKdddddKddK.",
        ".KDDDKDDDDDKDDK.",
        ".KKKKKKKKKKKKKK.",
    ],
    "lock": [
        "................",
        ".....KKKKKK.....",
        "....KNnnnnNK....",
        "...KNNKKKKNNK...",
        "...KNK....KNK...",
        "...KNK....KNK...",
        "..KKKKKKKKKKKK..",
        "..KYZZYYYYYYXK..",
        "..KYZYYYYYYYXK..",
        "..KYYYYKKYYYXK..",
        "..KYYYYKKYYYXK..",
        "..KYYYYYKYYYXK..",
        "..KYYYYYYYYXXK..",
        "..KXXXXXXXXXXK..",
        "..KKKKKKKKKKKK..",
        "................",
    ],
    "heart": [
        "................",
        "..KKKK...KKKK...",
        ".KRRRRK.KRRRRK..",
        "KRQQRRRKRRRRRRK.",
        "KRQRRRRRRRRRRRK.",
        "KRRRRRRRRRRRRrK.",
        "KRRRRRRRRRRRRrK.",
        ".KRRRRRRRRRRrK..",
        "..KRRRRRRRRrK...",
        "...KRRRRRRrK....",
        "....KRRRRrK.....",
        ".....KRRrK......",
        "......KrK.......",
        ".......K........",
        "................",
        "................",
    ],
    "star": [
        "................",
        ".......KK.......",
        "......KZYK......",
        "......KZYK......",
        ".....KZYYYK.....",
        "KKKKKKZYYYKKKKKK",
        "KZZZZZYYYYYYYYXK",
        ".KYYYYYYYYYYYXK.",
        "..KYYYYYYYYYXK..",
        "...KYYYYYYYXK...",
        "...KYYYYYYYXK...",
        "..KYYYYXKYYYXK..",
        "..KYYXXK.KYYXK..",
        ".KYXXKK...KKXXK.",
        ".KKKK.......KKK.",
        "................",
    ],
    "sun": [
        ".......Y........",
        "..Y....Y....Y...",
        "...Y.......Y....",
        ".....KKKKKK.....",
        "....KZZYYYYK....",
        "...KZZYYYYYYK...",
        "...KZYYYYYYYK...",
        "YY.KYYYYYYYYK.YY",
        "...KYYYYYYYyK...",
        "...KYYYYYYyyK...",
        "...KYYYYYyyyK...",
        "....KYYyyyyK....",
        ".....KKKKKK.....",
        "...Y.......Y....",
        "..Y....Y....Y...",
        ".......Y........",
    ],
    "moon": [
        "................",
        "......KKKKK.....",
        "....KKnnnnK.....",
        "...KnnnnKK......",
        "..KnnnnK........",
        "..KnnnK.........",
        ".KnnnnK.........",
        ".KnnnnK.........",
        ".KnnnnK.........",
        ".KnnnnnK........",
        "..KnnnnnK....K..",
        "..KNnnnnnKKKKNK.",
        "...KNnnnnnnnNK..",
        "....KKNNNNNKK...",
        "......KKKKK.....",
        "................",
    ],
}

STATE_ICONS = {  # 8x8, висят над машиной
    "stop": [
        "..KKKK..",
        ".KRRRRK.",
        "KRRRRRRK",
        "KWWWWWWK",
        "KWWWWWWK",
        "KRRRRRRK",
        ".KRRRRK.",
        "..KKKK..",
    ],
    "no_fuel": ITEMS["grain"],
    "no_water": [
        "...KK...",
        "..KLLK..",
        "..KLBK..",
        ".KLBBBK.",
        "KLlBBBbK",
        "KLBBBBbK",
        ".KBBBbK.",
        "..KKKK..",
    ],
    "exhausted": [
        "KKKKKKKK",
        "KmmmmmmK",
        "KmKmmKmK",
        "KmmKKmmK",
        "KmKmmKmK",
        "KmmmmmmK",
        "KKKKKKKK",
        "...KK...",
    ],
}


def recolor(img, mapping):
    from lib import rgba
    out = img.copy()
    table = {rgba(a): rgba(b) for a, b in mapping.items()}
    for y in range(out.height):
        for x in range(out.width):
            p = out.getpixel((x, y))
            if p in table:
                out.putpixel((x, y), table[p])
    return out


def build():
    player()
    save(sheet([ascii_sprite(ITEMS[k], LEG) for k in ("ore", "grain", "ingot")]), "items.png")
    heart = ascii_sprite(ICONS["heart"], LEG)
    empty = recolor(heart, {"r2": "m2", "r3": "m3", "r1": "m1"})
    order = ["pickaxe", "can", "seed", "lock", "star", "sun", "moon"]
    extra = ["wrench", "block"]          # новые иконки только в конец: номера старых не сдвигаются
    save(sheet([ascii_sprite(ICONS[k], LEG) for k in order] + [heart, empty] + [ascii_sprite(ICONS[k], LEG) for k in extra]), "icons.png")
    save(sheet([ascii_sprite(STATE_ICONS[k], LEG) for k in ("stop", "no_fuel", "no_water", "exhausted")]),
         "state_icons.png")


if __name__ == "__main__":
    build()

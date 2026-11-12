# Доступ к спрайтам по именам: машины, предметы, иконки. Владелец: B.
class_name Sprites

const DIR := "res://assets/sprites/"
const MACHINE_FRAMES := {"conveyor": 4, "drill": 4, "furnace": 3, "sprinkler": 2, "harvester": 2,
	"storage": 1, "campfire": 4, "ladder": 1}
const ICONS := ["pickaxe", "can", "seed", "lock", "star", "sun", "moon", "heart", "heart_empty", "wrench", "block"]
const ITEMS := ["ore", "grain", "ingot"]
const STATE_ICONS := ["stop", "no_fuel", "no_water", "exhausted"]
const ICON_SIZE := 16
const ITEM_SIZE := 8

static var _cache := {}


## Текстура по имени файла. Держим ссылку в кеше: иначе текстура, взятая только на время _draw(),
## освобождается раньше, чем кадр дойдёт до отрисовки, и вместо неё выходит белый прямоугольник.
static func tex(file_name: String) -> Texture2D:
	if not _cache.has(file_name):
		_cache[file_name] = load(DIR + file_name + ".png")
	return _cache[file_name]


static func icon(icon_name: String) -> Texture2D:
	return _region("icons", ICONS.find(icon_name), ICON_SIZE, ICON_SIZE)


static func item(type: String) -> Texture2D:
	return _region("items", ITEMS.find(type), ITEM_SIZE, ITEM_SIZE)


static func state_icon(icon_name: String) -> Texture2D:
	return _region("state_icons", STATE_ICONS.find(icon_name), ITEM_SIZE, ITEM_SIZE)


## Кадр анимации машины (лента кадров слева направо).
static func machine(type: String, frame: int = 0) -> Texture2D:
	var sheet := tex(type)
	var count: int = MACHINE_FRAMES.get(type, 1)
	return _region(type, frame % count, sheet.get_width() / count, sheet.get_height())


## Картинка для слота хотбара: инструмент или первая картинка машины.
static func slot(id: String) -> Texture2D:
	return icon(id) if ICONS.has(id) else machine(id)


static func _region(file_name: String, index: int, w: int, h: int) -> Texture2D:
	var key := "%s:%d" % [file_name, index]
	if not _cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex(file_name)
		atlas.region = Rect2(maxi(index, 0) * w, 0, w, h)
		_cache[key] = atlas
	return _cache[key]

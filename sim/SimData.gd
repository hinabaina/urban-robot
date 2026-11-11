class_name SimData
extends RefCounted
## Загрузка чисел баланса из JSON. Владелец: A.
## Правило проекта: ни одного «магического числа» в коде, всё здесь.

const MACHINES_PATH := "res://data/machines.json"
const WORLD_PATH := "res://data/world.json"

var machines: Dictionary = {}
var world: Dictionary = {}


func load_all() -> bool:
	machines = load_json(MACHINES_PATH)
	world = load_json(WORLD_PATH)
	return not machines.is_empty() and not world.is_empty()


func machine(type: String) -> Dictionary:
	return machines.get(type, {})


func tick_seconds() -> float:
	return float(world.get("tick_seconds", 0.25))


func farm() -> Dictionary:
	return world.get("farm", {})


## Время копания тайла данного вида в секундах; 0, если тайл не копается.
func dig_time(kind: int) -> float:
	var layer: Dictionary = world.get("tiles", {}).get(Tiles.key_of(kind), {})
	return float(layer.get("dig_time", 0.0))


## Запас жилы, верхний тайл которой лежит в строке y. -1 = бесконечная.
func vein_reserve(y: int) -> int:
	for layer in world.get("tiles", {}).values():
		var rows: Array = layer.get("rows", [])
		if rows.size() == 2 and y >= int(rows[0]) and y <= int(rows[1]) and layer.has("vein_reserve"):
			return int(layer["vein_reserve"])
	return -1


## Сколько тиков занимает seconds секунд (не меньше одного).
func ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds / tick_seconds()))


static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SimData: не удалось открыть %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SimData: %s должен быть JSON-объектом" % path)
		return {}
	return parsed


## JSON хранит размеры и клетки как [x, y].
static func to_vec2i(value, fallback := Vector2i.ONE) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func from_vec2i(value: Vector2i) -> Array:
	return [value.x, value.y]

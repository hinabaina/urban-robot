# Чтение data/machines.json (файл A): цена и размер машин, поиск машины по клетке. Владелец: B.
class_name MachineCatalog

const PATH := "res://data/machines.json"
const WORLD_PATH := "res://data/world.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameConfig.load_json(PATH)
	return _data


## Сколько клеток конвейера предмет проезжает за один тик симуляции (для сглаживания отрисовки).
static func conveyor_cells_per_tick() -> float:
	var tick := float(GameConfig.load_json(WORLD_PATH)["tick_seconds"])
	return tick / float(data()["conveyor"]["cell_seconds"])


static func is_machine(id: String) -> bool:
	return data().has(id)


static func cost(type: String) -> Dictionary:
	return data().get(type, {}).get("cost", {})


static func size(type: String) -> Vector2i:
	var s: Array = data().get(type, {}).get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


## Все клетки, которые займёт машина с левым верхним углом anchor.
static func cells(type: String, anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := size(type)
	for y in s.y:
		for x in s.x:
			out.append(anchor + Vector2i(x, y))
	return out


## Центр машины в пикселях мира.
static func center(type: String, anchor: Vector2i) -> Vector2:
	return (Vector2(anchor) + Vector2(size(type)) * 0.5) * TileCatalog.TILE


## Машина, занимающая клетку (учитывает машины 2x2). Пустой словарь, если клетка свободна.
static func find(cell: Vector2i) -> Dictionary:
	for machine in Sim.get_machines():
		var anchor: Vector2i = machine.get("cell")
		var type: String = machine.get("type")
		if Rect2i(anchor, size(type)).has_point(cell):
			return {"cell": anchor, "type": type, "dir": machine.get("dir"), "state": machine.get("state")}
	return {}

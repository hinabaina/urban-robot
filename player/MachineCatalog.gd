# Чтение data/machines.json (файл A): цена и размер машин, поиск машины по клетке. Владелец: B.
class_name MachineCatalog

const PATHS := ["res://data/machines.json", "res://dev_stub/machines.json"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		for path in PATHS:
			if FileAccess.file_exists(path):
				_data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
				break
	return _data


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

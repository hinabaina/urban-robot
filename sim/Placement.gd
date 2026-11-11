class_name Placement
extends RefCounted
## Постановка и снос машин. GDD «Машины». Владелец: A.
## Здесь только правила сетки. Цену, радиус 4 тайла и открытые чертежи проверяет B.

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
## Причины отказа: ключи перевода в data/translations.csv.
const UNKNOWN := "REASON_UNKNOWN"
const NOT_EMPTY := "REASON_NOT_EMPTY"
const OCCUPIED := "REASON_OCCUPIED"
const NEED_VEIN := "REASON_NEED_VEIN"

var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## {"ok": bool, "reason": String}; reason пустой, если ставить можно.
func can_place(type: String, cell: Vector2i, dir: Vector2i) -> Dictionary:
	var config: Dictionary = _sim.data.machine(type)
	if config.is_empty() or not DIRS.has(dir):
		return _fail(UNKNOWN)
	var cells := Grid.rect_cells(cell, SimData.to_vec2i(config.get("size")))
	for c in cells:
		if _sim.grid.get_tile(c) != Tiles.Kind.AIR:
			return _fail(NOT_EMPTY)
		if _sim.grid.machine_at(c) != null:
			return _fail(OCCUPIED)
	if type == "drill" and not _sim.veins.touches(cells):
		return _fail(NEED_VEIN)
	return {"ok": true, "reason": ""}


func place(type: String, cell: Vector2i, dir: Vector2i) -> bool:
	if not can_place(type, cell, dir)["ok"]:
		return false
	add(MachineRegistry.create(type, cell, dir, _sim.data.machine(type), _sim))
	return true


## Зарегистрировать готовую машину (постановка и загрузка сохранения).
func add(machine: Machine) -> void:
	_sim.grid.add_machine(machine)
	_sim.machine_placed.emit(machine.cell, machine.type, machine.dir)


## Снести машину в клетке (любой из её клеток). Возвращает предметы, лежавшие внутри.
func remove(cell: Vector2i) -> Array[Item]:
	var machine: Machine = _sim.grid.machine_at(cell)
	if machine == null:
		return []
	_sim.grid.remove_machine(machine)
	_sim.machine_removed.emit(machine.cell)
	var items := machine.contents()
	for item in items:
		item.by_hand = true
	return items


func clear() -> void:
	for machine in _sim.grid.machines().duplicate():
		_sim.grid.remove_machine(machine)
		_sim.machine_removed.emit(machine.cell)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

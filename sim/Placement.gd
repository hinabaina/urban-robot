class_name Placement
extends RefCounted
## Постановка и снос машин. GDD «Машины». Владелец: A.
## Здесь только правила сетки. Цена, радиус 4 тайла и открытые чертежи проверяет B.

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## {"ok": bool, "reason": String}. Причины: unknown_type, not_buildable,
## bad_direction, out_of_bounds, tile_solid, occupied.
func can_place(type: String, cell: Vector2i, dir: Vector2i, prebuilt := false) -> Dictionary:
	var config: Dictionary = _sim.data.machine(type)
	if config.is_empty():
		return _fail("unknown_type")
	if not prebuilt and not config.get("buildable", true):
		return _fail("not_buildable")
	if not DIRS.has(dir):
		return _fail("bad_direction")
	for c in Grid.rect_cells(cell, SimData.to_vec2i(config.get("size"))):
		if not _sim.grid.in_bounds(c):
			return _fail("out_of_bounds")
		if Tiles.is_solid(_sim.grid.get_tile(c)):
			return _fail("tile_solid")
		if _sim.grid.machine_at(c) != null:
			return _fail("occupied")
	# TODO(A4): бур должен касаться жилы стороной (причина needs_vein).
	return {"ok": true, "reason": ""}


func place(type: String, cell: Vector2i, dir: Vector2i, prebuilt := false) -> bool:
	if not can_place(type, cell, dir, prebuilt)["ok"]:
		return false
	var machine := MachineRegistry.create(type, cell, dir, _sim.data.machine(type), _sim)
	_sim.grid.add_machine(machine)
	_sim.machine_placed.emit(cell, type, dir)
	return true


## Снос машины в клетке (любой из её клеток).
## {"ok", "reason", "type", "refund": цена на 100%, "items": что лежало внутри}.
func remove(cell: Vector2i) -> Dictionary:
	var machine: Machine = _sim.grid.machine_at(cell)
	if machine == null:
		return _fail("no_machine")
	if not machine.config.get("buildable", true):
		return _fail("not_removable")
	_sim.grid.remove_machine(machine)
	_sim.machine_removed.emit(machine.cell, machine.type)
	return {
		"ok": true, "reason": "", "type": machine.type,
		"refund": machine.config.get("cost", {}).duplicate(),
		"items": machine.contents(),
	}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

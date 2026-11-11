class_name Farm
extends RefCounted
## Грядки: посадка, полив, сбор. GDD «Ферма». Владелец: A.

var well := Vector2i.ZERO
var _plots: Dictionary = {}  # Vector2i -> Crop
var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


func clear() -> void:
	_plots.clear()
	well = Vector2i.ZERO


func add_plot(cell: Vector2i) -> void:
	if not _plots.has(cell):
		_plots[cell] = Crop.new(cell)
		_emit(_plots[cell])


func remove_plot(cell: Vector2i) -> void:
	_plots.erase(cell)


## Зона колодца: квадрат со стороной 2 * radius + 1 вокруг колодца.
func in_water_zone(cell: Vector2i) -> bool:
	var radius: int = int(_sim.data.world.get("well", {}).get("radius", 0))
	return absi(cell.x - well.x) <= radius and absi(cell.y - well.y) <= radius


## Можно ли посадить зерно в клетку: в пустую грядку или создав новую на почве.
func can_plant(cell: Vector2i) -> Dictionary:
	if _plots.has(cell):
		var is_empty: bool = _plots[cell].stage == Crop.Stage.EMPTY
		return _result(is_empty, "already_planted")
	if _sim.grid.get_tile(cell) != Tiles.Kind.SOIL:
		return _result(false, "not_soil")
	var above := cell + Vector2i.UP
	if _sim.grid.get_tile(above) != Tiles.Kind.AIR or _sim.grid.machine_at(above) != null:
		return _result(false, "blocked_above")
	if not in_water_zone(cell):
		return _result(false, "no_water")
	if _plots.size() >= int(_sim.data.world.get("farm", {}).get("max_plots", 0)):
		return _result(false, "too_many_plots")
	return _result(true, "")


## Сажает зерно. Цену (1 зерно) списывает вызывающий.
func plant(cell: Vector2i) -> bool:
	if not can_plant(cell)["ok"]:
		return false
	add_plot(cell)
	var crop: Crop = _plots[cell]
	crop.stage = Crop.Stage.SPROUT
	crop.growth = 0.0
	_emit(crop)
	return true


func water(cell: Vector2i) -> bool:
	if not _plots.has(cell):
		return false
	var crop: Crop = _plots[cell]
	crop.wet_left = float(_sim.data.world.get("farm", {}).get("wet_seconds", 0.0))
	_emit(crop)
	return true


## Собирает зрелую грядку. Возвращает, сколько зерна получено (0, если не зрелая).
func harvest(cell: Vector2i) -> int:
	if not _plots.has(cell) or _plots[cell].stage != Crop.Stage.RIPE:
		return 0
	var crop: Crop = _plots[cell]
	crop.stage = Crop.Stage.EMPTY
	crop.growth = 0.0
	_emit(crop)
	return int(_sim.data.world.get("farm", {}).get("yield", 0))


func tick() -> void:
	# TODO(A7): высыхание и рост грядок. В каркасе грядки не растут и не сохнут,
	# поэтому harvest() пока всегда возвращает 0.
	pass


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for crop in _plots.values():
		result.append(crop.describe())
	return result


func _emit(crop: Crop) -> void:
	_sim.crop_changed.emit(crop.cell, crop.stage, crop.is_wet())


static func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": "" if ok else reason}

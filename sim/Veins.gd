class_name Veins
extends RefCounted
## Все жилы мира: поиск по тайлам руды, добыча киркой и буром, исчерпание. Владелец: A.

const SIDES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var list: Array[Vein] = []
var _by_cell: Dictionary = {}  # Vector2i -> Vein
var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## Объединить соседние тайлы ORE в жилы. Порядок обхода фиксирован, поэтому
## номера жил одинаковы при каждой загрузке одной и той же карты.
func build() -> void:
	list.clear()
	_by_cell.clear()
	var ore_cells: Array = _sim.grid.tiles.keys().filter(
		func(cell: Vector2i) -> bool: return _sim.grid.tiles[cell] == Tiles.Kind.ORE)
	ore_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for start in ore_cells:
		if _by_cell.has(start):
			continue
		var vein := Vein.new()
		vein.id = list.size()
		vein.reserve = _sim.data.vein_reserve(start.y)
		list.append(vein)
		var queue: Array[Vector2i] = [start]
		_by_cell[start] = vein
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			vein.cells.append(cell)
			for side in SIDES:
				var next := cell + side
				if _sim.grid.get_tile(next) == Tiles.Kind.ORE and not _by_cell.has(next):
					_by_cell[next] = vein
					queue.append(next)


func at(cell: Vector2i) -> Vein:
	return _by_cell.get(cell)


## Первая неисчерпанная жила, которой клетки машины касаются стороной. null, если такой нет.
func first_alive(machine_cells: Array[Vector2i]) -> Vein:
	for cell in machine_cells:
		for side in SIDES:
			var vein: Vein = _by_cell.get(cell + side)
			if vein != null and vein.is_alive():
				return vein
	return null


## Касаются ли клетки жилы (живой или уже пустой).
func touches(machine_cells: Array[Vector2i]) -> bool:
	for cell in machine_cells:
		for side in SIDES:
			if _by_cell.has(cell + side):
				return true
	return false


## Взять 1 руду. Когда запас кончился, все тайлы жилы становятся обычной породой.
func take_ore(vein: Vein) -> bool:
	if not vein.is_alive():
		return false
	if vein.reserve != Vein.INFINITE:
		vein.reserve -= 1
		if vein.reserve == 0:
			_exhaust(vein)
	return true


func _exhaust(vein: Vein) -> void:
	var kind: int = Tiles.KEYS.get(_sim.data.world.get("exhausted_vein_tile", ""), Tiles.Kind.STONE)
	for cell in vein.cells:
		_sim.grid.set_tile(cell, kind)
		_by_cell.erase(cell)
		_sim.tile_changed.emit(cell, kind)
	_sim.vein_exhausted.emit(vein.id)

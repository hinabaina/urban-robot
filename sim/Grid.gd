class_name Grid
extends RefCounted
## Сетка мира: тайлы и занятость клеток машинами. Владелец: A.

var size := Vector2i.ZERO
## Vector2i -> Tiles.Kind. Клетки без записи считаются воздухом.
var tiles: Dictionary = {}
## Vector2i -> Machine. Машина 2x2 записана во все свои клетки.
var _occupancy: Dictionary = {}
var _machines: Array[Machine] = []


func clear() -> void:
	size = Vector2i.ZERO
	tiles.clear()
	_occupancy.clear()
	_machines.clear()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## За границами мира всё считается коренной породой.
func get_tile(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return Tiles.Kind.BEDROCK
	return tiles.get(cell, Tiles.Kind.AIR)


func set_tile(cell: Vector2i, kind: int) -> void:
	if kind == Tiles.Kind.AIR:
		tiles.erase(cell)
	else:
		tiles[cell] = kind


func machine_at(cell: Vector2i) -> Machine:
	return _occupancy.get(cell)


func machines() -> Array[Machine]:
	return _machines


func add_machine(machine: Machine) -> void:
	_machines.append(machine)
	for cell in machine.cells():
		_occupancy[cell] = machine


func remove_machine(machine: Machine) -> void:
	_machines.erase(machine)
	for cell in machine.cells():
		_occupancy.erase(cell)


## Клетки прямоугольника size с левым верхним углом в cell.
static func rect_cells(cell: Vector2i, rect_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in rect_size.y:
		for dx in rect_size.x:
			result.append(cell + Vector2i(dx, dy))
	return result

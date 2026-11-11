# Рисует предметы на конвейерах: каждый кадр читает Sim.get_items() и сглаживает ход между тиками. Владелец: B.
extends Node2D

const HALF := Vector2(Sprites.ITEM_SIZE, Sprites.ITEM_SIZE) * 0.5

var _per_tick := MachineCatalog.conveyor_cells_per_tick()


func _ready() -> void:
	z_index = 2


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Доля текущего тика: предмет, который ещё едет по клетке, рисуем чуть впереди, чтобы не дёргался.
	var ahead := Sim.tick_alpha() * _per_tick
	for item in Sim.get_items():
		var progress: float = item.get("progress")
		if progress < 1.0:
			progress = minf(1.0, progress + ahead)
		var dir := Vector2(item.get("dir"))
		var pos := TileCatalog.cell_center(item.get("cell")) + dir * (progress - 0.5) * TileCatalog.TILE
		draw_texture(Sprites.item(item.get("type")), (pos - HALF).round())

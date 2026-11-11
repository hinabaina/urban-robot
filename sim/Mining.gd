class_name Mining
extends RefCounted
## Ручное копание тайлов и руды. GDD «Ручные действия». Владелец: A.

var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## Сколько секунд держать ЛКМ на тайле; -1, если копать нельзя (воздух, коренная порода).
func dig_time(cell: Vector2i) -> float:
	var kind: int = _sim.grid.get_tile(cell)
	if kind == Tiles.Kind.AIR:
		return -1.0
	return _sim.data.dig_time(kind)


## Игрок докопал тайл. removed: тайл исчез; ore: игрок получил 1 руду.
func dig(cell: Vector2i) -> Dictionary:
	if dig_time(cell) < 0.0:
		return {"removed": false, "ore": false}
	if _sim.grid.get_tile(cell) == Tiles.Kind.ORE:
		# TODO(A4): списывать запас жилы и превращать её в камень при исчерпании.
		# В каркасе жила бесконечна: тайл остаётся, руда выдаётся каждый раз.
		return {"removed": false, "ore": true}
	_sim.grid.set_tile(cell, Tiles.Kind.AIR)
	_sim.farm.remove_plot(cell)
	_sim.tile_changed.emit(cell, Tiles.Kind.AIR)
	return {"removed": true, "ore": false}

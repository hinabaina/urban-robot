class_name SimSave
extends RefCounted
## Сохранение и восстановление симуляции. GDD «Сохранение». Владелец: A.
## При загрузке рассылает те же сигналы, что и обычная игра, поэтому вид обновляется сам.

const VERSION := 1

var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


func to_dict() -> Dictionary:
	var tiles := {}
	for cell: Vector2i in _sim.grid.tiles.keys():
		tiles["%d,%d" % [cell.x, cell.y]] = _sim.grid.tiles[cell]
	return {
		"version": VERSION,
		"tick": _sim.tick_count,
		"size": SimData.from_vec2i(_sim.grid.size),
		"tiles": tiles,
		"veins": _sim.veins.list.map(func(vein: Vein) -> int: return vein.reserve),
		"machines": _sim.grid.machines().map(func(machine: Machine) -> Dictionary: return machine.save()),
		"crops": _sim.farm.save(),
		"made": _sim.report.made.duplicate(),
	}


## false, если сохранение другой версии или повреждено: тогда мир не меняется.
func from_dict(saved: Dictionary) -> bool:
	if int(saved.get("version", -1)) != VERSION or not saved.has("tiles"):
		return false
	_sim.placement.clear()
	_restore_tiles(saved["tiles"])
	_sim.veins.build()
	var reserves: Array = saved.get("veins", [])
	for i in mini(reserves.size(), _sim.veins.list.size()):
		_sim.veins.list[i].reserve = int(reserves[i])
	_sim.farm.restore(saved.get("crops", []))
	for entry: Dictionary in saved.get("machines", []):
		var type: String = entry.get("type", "")
		var machine := MachineRegistry.create(type, SimData.to_vec2i(entry.get("cell")),
			SimData.to_vec2i(entry.get("dir")), _sim.data.machine(type), _sim)
		machine.restore(entry)
		_sim.placement.add(machine)
		_sim.machine_state_changed.emit(machine.cell, machine.state)
	_sim.tick_count = int(saved.get("tick", 0))
	_sim.report.made = saved.get("made", {}).duplicate()
	return true


## Заменить тайлы и сообщить виду о каждой клетке, которая изменилась.
func _restore_tiles(saved: Dictionary) -> void:
	var loaded := {}
	for key: String in saved.keys():
		var parts := key.split(",")
		loaded[Vector2i(int(parts[0]), int(parts[1]))] = int(saved[key])
	var old: Dictionary = _sim.grid.tiles
	_sim.grid.tiles = loaded
	for cell: Vector2i in loaded.keys():
		if old.get(cell, Tiles.Kind.AIR) != loaded[cell]:
			_sim.tile_changed.emit(cell, loaded[cell])
	for cell: Vector2i in old.keys():
		if not loaded.has(cell):
			_sim.tile_changed.emit(cell, Tiles.Kind.AIR)

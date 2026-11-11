class_name Sprinkler
extends Machine
## Поливалка 1x1: раз в 5 с поливает грядки в радиусе, только в зоне колодца. GDD «Поливалка».
## Владелец: A.

var _ticks := -1


func tick() -> void:
	if not sim.farm.in_water_zone(cell):
		set_state(State.NO_WATER)
		return
	set_state(State.WORKING)
	var interval: int = sim.data.ticks(float(config.get("interval_seconds", 1.0)))
	# Первый полив сразу после постановки, дальше по интервалу.
	_ticks = interval if _ticks < 0 else _ticks + 1
	if _ticks >= interval:
		_ticks = 0
		for crop in sim.farm.around(cell, int(config.get("radius", 0))):
			sim.farm.water(crop.cell)


func save() -> Dictionary:
	var saved := super()
	saved["ticks"] = _ticks
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_ticks = int(saved.get("ticks", -1))

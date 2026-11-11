class_name Harvester
extends Machine
## Сборщик 1x1: раз в 2 с собирает зрелые грядки в радиусе и сразу пересаживает. GDD «Сборщик».
## Владелец: A. Зерно из сборщика всегда by_hand = false.

var _ticks := 0


func tick() -> void:
	var crops: Array = sim.farm.around(cell, int(config.get("radius", 0)))
	var gain: int = int(sim.data.farm().get("yield", 0)) - int(config.get("replant", 0))
	if crops.is_empty():
		set_state(State.IDLE)
		return
	# Если урожай не влезет в выход, сборщик ждёт, а зерно остаётся на грядке.
	if out.size() + gain > int(config.get("output_buffer", 0)):
		set_state(State.BLOCKED)
		return
	set_state(State.WORKING)
	_ticks += 1
	if _ticks < sim.data.ticks(float(config.get("interval_seconds", 1.0))):
		return
	_ticks = 0
	for crop in crops:
		if out.size() + gain > int(config.get("output_buffer", 0)):
			break
		if sim.farm.harvest(crop.cell) > 0:
			sim.farm.plant(crop.cell)
			for i in gain:
				produce(Item.new(Item.GRAIN, false))


func save() -> Dictionary:
	var saved := super()
	saved["ticks"] = _ticks
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_ticks = int(saved.get("ticks", 0))

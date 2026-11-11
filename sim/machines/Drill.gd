class_name Drill
extends Machine
## Бур 2x2: добывает руду из жилы, которой касается стороной. GDD «Бур».
## Владелец: A. Руда из бура всегда by_hand = false.

var _ticks := 0


func tick() -> void:
	var vein: Vein = sim.veins.first_alive(cells())
	if vein == null:
		set_state(State.EXHAUSTED)
		return
	if output_full():
		set_state(State.BLOCKED)
		return
	set_state(State.WORKING)
	_ticks += 1
	if _ticks >= sim.data.ticks(float(config.get("cycle_seconds", 1.0))):
		_ticks = 0
		sim.veins.take_ore(vein)
		produce(Item.new(Item.ORE, false))


func save() -> Dictionary:
	var saved := super()
	saved["ticks"] = _ticks
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_ticks = int(saved.get("ticks", 0))

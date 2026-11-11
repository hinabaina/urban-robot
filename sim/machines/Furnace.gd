class_name Furnace
extends Machine
## Печь 2x2: 2 руды + 1 зерно -> 1 слиток за 6 с. GDD «Печь».
## Владелец: A. Слиток получает by_hand, если хотя бы одно сырьё было тронуто руками.

## Тип сырья -> список флагов by_hand в порядке поступления.
var _input: Dictionary = {}
var _ticks := 0


## Принимает сырьё по рецепту с любой стороны, кроме стороны выхода.
func can_accept(item: Item, from_dir: Vector2i) -> bool:
	if not _recipe().has(item.type) or from_dir == -dir:
		return false
	return _count(item.type) < int(config.get("input_buffer", {}).get(item.type, 0))


func accept(item: Item, _from_dir: Vector2i) -> void:
	if not _input.has(item.type):
		_input[item.type] = []
	_input[item.type].append(item.by_hand)


func tick() -> void:
	if output_full():
		set_state(State.BLOCKED)
		return
	if not _has_recipe():
		_ticks = 0
		set_state(State.NO_FUEL if _waits_for_fuel() else State.IDLE)
		return
	set_state(State.WORKING)
	_ticks += 1
	if _ticks >= sim.data.ticks(float(config.get("cycle_seconds", 1.0))):
		_ticks = 0
		produce(Item.new(Item.INGOT, _consume()))


func contents() -> Array[Item]:
	var result := out.duplicate()
	for item_type in _input.keys():
		for by_hand in _input[item_type]:
			result.append(Item.new(item_type, by_hand))
	return result


func save() -> Dictionary:
	var saved := super()
	saved["input"] = _input.duplicate(true)
	saved["ticks"] = _ticks
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_input = saved.get("input", {}).duplicate(true)
	_ticks = int(saved.get("ticks", 0))


func _recipe() -> Dictionary:
	return config.get("recipe_in", {})


func _count(item_type: String) -> int:
	return _input.get(item_type, []).size()


func _has_recipe() -> bool:
	for item_type in _recipe().keys():
		if _count(item_type) < int(_recipe()[item_type]):
			return false
	return true


## Руда есть, а зерна (топлива) не хватает.
func _waits_for_fuel() -> bool:
	return _count(Item.ORE) > 0 and _count(Item.GRAIN) < int(_recipe().get(Item.GRAIN, 0))


## Списать сырьё на один слиток. true, если что-то из него было тронуто руками.
func _consume() -> bool:
	var touched := false
	for item_type in _recipe().keys():
		for i in int(_recipe()[item_type]):
			touched = _input[item_type].pop_front() or touched
	return touched

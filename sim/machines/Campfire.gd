class_name Campfire
extends Machine
## Костёр 1x1: ручная плавка, работает только пока игрок держит ЛКМ. GDD «Костёр».
## Владелец: A. Слиток из костра всегда by_hand = true и сразу идёт в карманы.

var _input: Dictionary = {}
var _seconds := 0.0


## Принимает ровно один набор сырья по рецепту.
func can_accept(item: Item, _from_dir: Vector2i) -> bool:
	return int(_input.get(item.type, 0)) < int(_recipe().get(item.type, 0))


func accept(item: Item, _from_dir: Vector2i) -> void:
	_input[item.type] = int(_input.get(item.type, 0)) + 1


func has_recipe() -> bool:
	for item_type in _recipe().keys():
		if int(_input.get(item_type, 0)) < int(_recipe()[item_type]):
			return false
	return not _recipe().is_empty()


## Игрок раздувает огонь dt секунд. true в тот вызов, когда слиток готов.
func work(dt: float) -> bool:
	if not has_recipe():
		_seconds = 0.0
		set_state(State.IDLE)
		return false
	set_state(State.WORKING)
	_seconds += dt
	if _seconds < float(config.get("cycle_seconds", 0.0)):
		return false
	_seconds = 0.0
	_input.clear()
	set_state(State.IDLE)
	return true


func take_by_hand() -> Array[Item]:
	var taken := contents()
	_input.clear()
	_seconds = 0.0
	return taken


func contents() -> Array[Item]:
	var result: Array[Item] = []
	for item_type in _input.keys():
		result.append_array(Item.many(item_type, int(_input[item_type]), true))
	return result


func save() -> Dictionary:
	var saved := super()
	saved["input"] = _input.duplicate()
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_input = saved.get("input", {}).duplicate()


func _recipe() -> Dictionary:
	return config.get("recipe_in", {})

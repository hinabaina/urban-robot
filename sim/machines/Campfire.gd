class_name Campfire
extends Machine
## Костёр 1x1: ручная плавка, работает только пока игрок держит ЛКМ. GDD «Костёр».
## Владелец: A. Слиток из костра всегда by_hand = true.

var _input: Dictionary = {}
var _progress := 0.0


func can_accept(item: Item, _from_dir: Vector2i) -> bool:
	var need: int = int(_recipe().get(item.type, 0))
	return int(_input.get(item.type, 0)) < need


func accept(item: Item, _from_dir: Vector2i) -> void:
	_input[item.type] = int(_input.get(item.type, 0)) + 1


## Игрок раздувает огонь dt секунд. true в тот момент, когда слиток готов
## (слиток сразу идёт в карманы, это делает вызывающий).
func work(dt: float) -> bool:
	if not _has_recipe():
		set_state(State.IDLE)
		_progress = 0.0
		return false
	set_state(State.WORKING)
	_progress += dt
	if _progress < float(config.get("cycle_seconds", 0.0)):
		return false
	_progress = 0.0
	_input.clear()
	set_state(State.IDLE)
	return true


func take_by_hand(room: Dictionary) -> Dictionary:
	var taken := {}
	for item_type in _input.keys():
		var amount: int = mini(int(_input[item_type]), int(room.get(item_type, 0)))
		if amount > 0:
			_input[item_type] -= amount
			taken[item_type] = amount
	_progress = 0.0
	return taken


func contents() -> Dictionary:
	var result := {}
	for item_type in _input.keys():
		if int(_input[item_type]) > 0:
			result[item_type] = int(_input[item_type])
	return result


func _recipe() -> Dictionary:
	return config.get("recipe_in", {})


func _has_recipe() -> bool:
	var recipe := _recipe()
	if recipe.is_empty():
		return false
	for item_type in recipe.keys():
		if int(_input.get(item_type, 0)) < int(recipe[item_type]):
			return false
	return true

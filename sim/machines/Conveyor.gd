class_name Conveyor
extends Machine
## Конвейер 1x1: везёт один предмет в своём направлении, вверх = лифт. GDD «Конвейер».
## Владелец: A.

var item: Item


## Принимает с любой стороны, кроме встречной. Рукой на конвейер не кладут.
func can_accept(_item: Item, from_dir: Vector2i) -> bool:
	return item == null and from_dir != BY_HAND and from_dir != -dir


func accept(new_item: Item, _from_dir: Vector2i) -> void:
	item = new_item
	item.progress = 0.0
	item.cell = cell
	item.dir = dir


## Фаза движения: предмет едет по клетке cell_seconds секунд.
func tick() -> void:
	if item != null and item.progress < 1.0:
		var step: float = sim.data.tick_seconds() / float(config.get("cell_seconds", 1.0))
		item.progress = minf(1.0, item.progress + step)


## После переходов: предмет, который доехал до края и не ушёл дальше, стоит в заторе.
func end_tick() -> void:
	if item == null:
		set_state(State.IDLE)
	else:
		set_state(State.BLOCKED if item.progress >= 1.0 else State.WORKING)
	super()


func peek_output() -> Item:
	return item if item != null and item.progress >= 1.0 else null


func take_output() -> Item:
	var taken := item
	item = null
	return taken


func take_by_hand() -> Array[Item]:
	var taken := contents()
	item = null
	return taken


func contents() -> Array[Item]:
	var result: Array[Item] = []
	if item != null:
		result.append(item)
	return result


func save() -> Dictionary:
	var saved := super()
	if item != null:
		saved["item"] = item.save()
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	if saved.has("item"):
		var loaded := Item.load_from(saved["item"])
		var progress := loaded.progress
		accept(loaded, dir)
		item.progress = progress

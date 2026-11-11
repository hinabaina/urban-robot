class_name Storage
extends Machine
## Склад 2x2: принимает любые предметы, отсюда дрон забирает слитки. GDD «Склад».
## Владелец: A.

## Тип предмета -> очередь флагов by_hand в порядке поступления (FIFO).
var _queues: Dictionary = {}


func can_accept(_item: Item, _from_dir: Vector2i) -> bool:
	return true


func accept(item: Item, _from_dir: Vector2i) -> void:
	if not _queues.has(item.type):
		_queues[item.type] = []
	_queues[item.type].append(item.by_hand)
	sim.item_delivered.emit(item.type, item.by_hand)
	sim.storage_changed.emit(item.type, count(item.type))


func count(item_type: String) -> int:
	return _queues.get(item_type, []).size()


## Игрок берёт руду и зерно. Слитки взять нельзя, чтобы не ломать подсчёт квоты.
func take_by_hand(room: Dictionary) -> Dictionary:
	var taken := {}
	for item_type in _queues.keys():
		if item_type == Item.INGOT:
			continue
		var amount: int = mini(count(item_type), int(room.get(item_type, 0)))
		if amount > 0:
			_remove(item_type, amount)
			taken[item_type] = amount
	return taken


## Дрон забирает до amount слитков, самые старые первыми.
## Возвращает {"taken": сколько забрал, "by_hand": сколько из них тронуты руками}.
func take_for_drone(amount: int) -> Dictionary:
	var taken: int = mini(amount, count(Item.INGOT))
	var flags: Array = _remove(Item.INGOT, taken)
	return {"taken": taken, "by_hand": flags.count(true)}


func contents() -> Dictionary:
	var result := {}
	for item_type in _queues.keys():
		if count(item_type) > 0:
			result[item_type] = count(item_type)
	return result


func _remove(item_type: String, amount: int) -> Array:
	if amount <= 0:
		return []
	var queue: Array = _queues[item_type]
	var removed := queue.slice(0, amount)
	_queues[item_type] = queue.slice(amount)
	sim.storage_changed.emit(item_type, count(item_type))
	return removed

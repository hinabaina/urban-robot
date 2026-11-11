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


func count(item_type: String) -> int:
	return _queues.get(item_type, []).size()


## Игрок берёт руду и зерно. Слитки взять нельзя, чтобы не ломать подсчёт квоты.
func take_by_hand() -> Array[Item]:
	var taken: Array[Item] = []
	for item_type in _queues.keys():
		if item_type != Item.INGOT:
			taken.append_array(_remove(item_type, count(item_type)))
	return taken


## Дрон забирает до amount слитков, самые старые первыми.
func take_for_drone(amount: int) -> Array[Item]:
	return _remove(Item.INGOT, mini(amount, count(Item.INGOT)))


func contents() -> Array[Item]:
	var result: Array[Item] = []
	for item_type in _queues.keys():
		for by_hand in _queues[item_type]:
			result.append(Item.new(item_type, by_hand))
	return result


func save() -> Dictionary:
	var saved := super()
	saved["queues"] = _queues.duplicate(true)
	return saved


func restore(saved: Dictionary) -> void:
	super(saved)
	_queues = saved.get("queues", {}).duplicate(true)


func _remove(item_type: String, amount: int) -> Array[Item]:
	var removed: Array[Item] = []
	for i in amount:
		removed.append(Item.new(item_type, _queues[item_type].pop_front()))
	return removed

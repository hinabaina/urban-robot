class_name Item
extends RefCounted
## Предмет симуляции: руда, зерно или слиток. Владелец: A.
## Вода предметом не является (это зона колодца).

const ORE := "ore"
const GRAIN := "grain"
const INGOT := "ingot"
const TYPES: Array[String] = [ORE, GRAIN, INGOT]

var type: String
## true, если на любом шаге пути предмета участвовал игрок (GDD «Флаг тронуто руками»).
var by_hand: bool
## Положение на клетке конвейера вдоль его направления, 0..1. Вид рисует спрайт по этому числу.
var progress := 0.0
## Клетка и направление конвейера, на котором лежит предмет (заполняет конвейер).
var cell := Vector2i.ZERO
var dir := Vector2i.RIGHT


func _init(p_type: String = ORE, p_by_hand: bool = false) -> void:
	type = p_type
	by_hand = p_by_hand


func save() -> Dictionary:
	return {"type": type, "by_hand": by_hand, "progress": progress}


static func load_from(d: Dictionary) -> Item:
	var item := Item.new(d.get("type", ORE), d.get("by_hand", false))
	item.progress = float(d.get("progress", 0.0))
	return item


static func save_list(items: Array) -> Array:
	return items.map(func(item: Item) -> Dictionary: return item.save())


static func load_list(saved: Array) -> Array[Item]:
	var result: Array[Item] = []
	for d in saved:
		result.append(load_from(d))
	return result


## Список из count одинаковых предметов.
static func many(p_type: String, count: int, p_by_hand: bool) -> Array[Item]:
	var result: Array[Item] = []
	for i in count:
		result.append(Item.new(p_type, p_by_hand))
	return result

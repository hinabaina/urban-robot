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
## Положение внутри клетки конвейера, 0..1. Вид рисует спрайт по этому числу.
var progress: float = 0.0


func _init(p_type: String = ORE, p_by_hand: bool = false) -> void:
	type = p_type
	by_hand = p_by_hand


func to_dict() -> Dictionary:
	return {"type": type, "by_hand": by_hand, "progress": progress}


static func from_dict(d: Dictionary) -> Item:
	var item := Item.new(d.get("type", ORE), d.get("by_hand", false))
	item.progress = d.get("progress", 0.0)
	return item

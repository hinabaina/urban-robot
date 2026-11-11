class_name Machine
extends RefCounted
## Базовый класс всех машин. Владелец: A.
## Каждая машина это наследник со своим tick(). Общий интерфейс описан в docs/CONTRACT.md.

enum State { IDLE, WORKING, BLOCKED, NO_FUEL, NO_WATER, EXHAUSTED }

## Направление «положено рукой игрока» для can_accept()/accept().
const BY_HAND := Vector2i.ZERO

var type: String
## Левая верхняя клетка машины.
var cell: Vector2i
## Направление выхода: RIGHT, LEFT, UP или DOWN.
var dir := Vector2i.RIGHT
var size := Vector2i.ONE
var state: int = State.IDLE
## Запись этой машины из data/machines.json.
var config: Dictionary = {}
## Simulation, которой принадлежит машина (нужна для сигналов).
var sim: Node


func setup(p_type: String, p_cell: Vector2i, p_dir: Vector2i, p_config: Dictionary, p_sim: Node) -> void:
	type = p_type
	cell = p_cell
	dir = p_dir
	config = p_config
	size = SimData.to_vec2i(p_config.get("size"), Vector2i.ONE)
	sim = p_sim


func cells() -> Array[Vector2i]:
	return Grid.rect_cells(cell, size)


## Может ли машина прямо сейчас принять предмет, пришедший со стороны from_dir.
func can_accept(_item: Item, _from_dir: Vector2i) -> bool:
	return false


## Принять предмет. Вызывать только после can_accept() == true.
func accept(_item: Item, _from_dir: Vector2i) -> void:
	pass


## Один шаг симуляции (0,25 с). Наследники обновляют таймеры и состояние.
func tick() -> void:
	pass


## Предмет, готовый к выдаче, без изъятия. null, если выдавать нечего.
func peek_output() -> Item:
	return null


## Изъять готовый предмет. null, если выдавать нечего.
func take_output() -> Item:
	return null


## Игрок забирает предметы клавишей E. room: сколько ещё влезет в карманы по типам.
func take_by_hand(_room: Dictionary) -> Dictionary:
	return {}


## Всё, что лежит внутри, по типам: {"ore": 2, ...}. Нужно при сносе.
func contents() -> Dictionary:
	return {}


func set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	if sim != null:
		sim.machine_state_changed.emit(cell, state)


## Снимок для вида и UI.
func describe() -> Dictionary:
	return {
		"type": type, "cell": cell, "dir": dir, "size": size,
		"state": state, "contents": contents(),
	}


func to_dict() -> Dictionary:
	return {
		"type": type, "cell": [cell.x, cell.y], "dir": [dir.x, dir.y], "state": state,
	}

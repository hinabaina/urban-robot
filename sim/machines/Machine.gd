class_name Machine
extends RefCounted
## Базовый класс всех машин. Владелец: A.
## Каждая машина это наследник со своим tick(). Лестница пассивна и использует этот класс как есть.

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
## Simulation, которой принадлежит машина.
var sim: Node
## Выходной буфер: готовые предметы ждут здесь перехода дальше.
var out: Array[Item] = []
## От кого машина приняла предмет в прошлый раз (для слияния потоков по очереди).
## Храним номер объекта, а не ссылку, чтобы машины не удерживали друг друга в памяти.
var last_source_id := 0
var stats := MachineStats.new()
var _made_this_tick := 0


func setup(p_type: String, p_cell: Vector2i, p_dir: Vector2i, p_config: Dictionary, p_sim: Node) -> void:
	type = p_type
	cell = p_cell
	dir = p_dir
	config = p_config
	size = SimData.to_vec2i(p_config.get("size"), Vector2i.ONE)
	sim = p_sim


func cells() -> Array[Vector2i]:
	return Grid.rect_cells(cell, size)


## Клетка, куда машина отдаёт предметы: соседняя по направлению выхода,
## в строке (или столбце) левой верхней клетки.
func output_cell() -> Vector2i:
	var dx := size.x if dir.x > 0 else (-1 if dir.x < 0 else 0)
	var dy := size.y if dir.y > 0 else (-1 if dir.y < 0 else 0)
	return cell + Vector2i(dx, dy)


## Может ли машина прямо сейчас принять предмет, который движется в направлении from_dir.
func can_accept(_item: Item, _from_dir: Vector2i) -> bool:
	return false


## Принять предмет. Вызывать только после can_accept() == true.
func accept(_item: Item, _from_dir: Vector2i) -> void:
	pass


## Один шаг симуляции (0,25 с): таймеры, производство, состояние.
func tick() -> void:
	pass


## Конец тика, после всех переходов предметов: запись статистики.
func end_tick() -> void:
	stats.record(state, _made_this_tick, sim.stats_window)
	_made_this_tick = 0


## Предмет, готовый к выдаче, без изъятия. null, если выдавать нечего.
func peek_output() -> Item:
	return out[0] if not out.is_empty() else null


func take_output() -> Item:
	return out.pop_front()


func output_full() -> bool:
	return out.size() >= int(config.get("output_buffer", 0))


## Игрок забирает предметы клавишей E.
func take_by_hand() -> Array[Item]:
	var taken := out.duplicate()
	out.clear()
	return taken


## Всё, что лежит внутри (возвращается игроку при сносе).
func contents() -> Array[Item]:
	return out.duplicate()


func set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	sim.machine_state_changed.emit(cell, state)


## Положить произведённый предмет в выходной буфер.
func produce(item: Item) -> void:
	out.append(item)
	_made_this_tick += 1
	sim.report.note_made(item.type)


func save() -> Dictionary:
	return {
		"type": type, "cell": SimData.from_vec2i(cell), "dir": SimData.from_vec2i(dir),
		"state": state, "out": Item.save_list(out),
	}


func restore(saved: Dictionary) -> void:
	state = int(saved.get("state", State.IDLE))
	out = Item.load_list(saved.get("out", []))

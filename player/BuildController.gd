# Хотбар 1–9, призрак постройки, Q — поворот, ПКМ — поставить машину или посадить зерно. Владелец: B.
extends Node2D

signal selection_changed(index: int)

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const OK_COLOR := Color(0.45, 1.0, 0.45)
const BAD_COLOR := Color(1.0, 0.35, 0.3)
const ARROW_INSET := 4.0

var slots: Array = []
var selected := 0
var dir_index := 0
var ghost := {}              # {type, cell, dir, ok, reason} или пусто

var _placing := false
var _last_cell := Vector2i(-999, -999)

@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	top_level = true          # рисуем призрак в координатах мира, а не игрока
	z_index = 4
	slots = GameState.player_config["hotbar"]


func selected_id() -> String:
	return slots[selected]


func direction() -> Vector2i:
	return DIRS[dir_index]


func select(index: int) -> void:
	index = posmod(index, slots.size())
	if not GameState.is_unlocked(slots[index]):
		GameState.notify("NOTICE_LOCKED")
		Audio.play("error")
		return
	selected = index
	selection_changed.emit(selected)
	Audio.play("select")


## Колесо мыши: следующий или предыдущий открытый слот.
func _cycle(step: int) -> void:
	for i in range(1, slots.size()):
		var index := posmod(selected + step * i, slots.size())
		if GameState.is_unlocked(slots[index]):
			select(index)
			return


func _unhandled_input(event: InputEvent) -> void:
	if player.frozen:
		return
	for i in slots.size():
		if event.is_action_pressed(Actions.slot(i)):
			select(i)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cycle(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	if event.is_action_pressed(Actions.ROTATE):
		dir_index = (dir_index + 1) % DIRS.size()
		Audio.play("select")
	elif event.is_action_pressed(Actions.PLACE):
		_placing = true
		_last_cell = Vector2i(-999, -999)
		_try_place(true)


func _process(_delta: float) -> void:
	_update_ghost()
	if _placing and not Input.is_action_pressed(Actions.PLACE):
		_placing = false
	# Протяжка с зажатой ПКМ: удобно тянуть конвейеры и лестницы.
	if _placing and not ghost.is_empty() and ghost["cell"] != _last_cell and MachineCatalog.size(ghost["type"]) == Vector2i.ONE:
		_try_place(false)
	queue_redraw()


func _update_ghost() -> void:
	ghost = {}
	var id := selected_id()
	if player.frozen or not MachineCatalog.is_machine(id):
		return
	var size := MachineCatalog.size(id)
	var cell := TileCatalog.cell_at(get_global_mouse_position() - Vector2(size - Vector2i.ONE) * TileCatalog.TILE * 0.5)
	var reason := ""
	if not player.in_reach(MachineCatalog.center(id, cell)):
		reason = "REASON_TOO_FAR"
	elif not GameState.can_afford(MachineCatalog.cost(id)):
		reason = "REASON_NO_RESOURCES"
	else:
		reason = Sim.can_place(id, cell, direction()).get("reason", "")
	ghost = {"type": id, "cell": cell, "dir": direction(), "ok": reason == "", "reason": reason}


func _try_place(loud: bool) -> void:
	if selected_id() == "seed":
		_plant()
		return
	_update_ghost()   # клик мог прийти раньше, чем _process успел пересчитать призрак
	if ghost.is_empty():
		return
	_last_cell = ghost["cell"]
	if ghost["ok"] and Sim.place_machine(ghost["type"], ghost["cell"], ghost["dir"]):
		GameState.pay(MachineCatalog.cost(ghost["type"]))
		GameState.report("placed:" + ghost["type"])
		Audio.play("place")
	elif loud:
		GameState.notify(ghost["reason"])
		Audio.play("error")


## Посадить зерно: клик по грядке или по воздуху прямо над ней.
func _plant() -> void:
	var cost: Dictionary = GameState.player_config["plant_cost"]
	var cell := TileCatalog.cell_at(get_global_mouse_position())
	if not player.in_reach(TileCatalog.cell_center(cell)) or not GameState.can_afford(cost):
		return
	for target in [cell, cell + Vector2i.DOWN]:
		if Sim.plant(target):
			GameState.pay(cost)
			Audio.play("plant")
			return


func _draw() -> void:
	if ghost.is_empty():
		return
	var type: String = ghost["type"]
	var color := OK_COLOR if ghost["ok"] else BAD_COLOR
	var rect := Rect2(Vector2(ghost["cell"]) * TileCatalog.TILE, Vector2(MachineCatalog.size(type)) * TileCatalog.TILE)
	draw_rect(rect, Color(color, 0.22))
	draw_rect(rect, Color(color, 0.9), false, 1.0)
	var center := rect.get_center()
	var dir := Vector2(ghost["dir"])
	var directional: bool = GameState.player_config["directional"].has(type)
	draw_set_transform(center, dir.angle() if type == "conveyor" else 0.0)
	draw_texture(Sprites.machine(type), -rect.size * 0.5, Color(color, 0.75))
	if directional and type != "conveyor":
		var arrow := Sprites.tex("arrow_out")
		draw_set_transform(center + dir * (rect.size.x * 0.5 - ARROW_INSET), dir.angle())
		draw_texture(arrow, -arrow.get_size() * 0.5, Color(1, 1, 1, 0.95))
	draw_set_transform(Vector2.ZERO)

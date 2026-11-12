# Хотбар 1–9, призрак постройки, Q — поворот, ПКМ — поставить машину или посадить зерно. Владелец: B.
extends Node2D

signal selection_changed(index: int)

const BLOCK := "block"            # ставится как блок земли, а не как машина
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const OK_COLOR := Color(0.45, 1.0, 0.45)
const BAD_COLOR := Color(1.0, 0.35, 0.3)
const ARROW_INSET := 4.0

var slots: Array = []
var selected := 0
var dir_index := 0
var ghost := {}              # {type, cell, dir, ok, reason} или пусто

var _placing := false
var _place_action := Actions.PLACE   # какой кнопкой тянем постройку
var _last_plant_warn := Vector2i(-999, -999)
var _last_cell := Vector2i(-999, -999)

@onready var player: CharacterBody2D = get_parent()


func _ready() -> void:
	top_level = true          # рисуем призрак в координатах мира, а не игрока
	z_index = 4
	slots = GameConfig.player()["hotbar"]


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
		_start_placing(Actions.PLACE, true)
	elif event.is_action_pressed(Actions.USE) and _left_click_builds():
		# На Mac правую кнопку нажать неудобно: с семенами или машиной в руке ЛКМ тоже ставит и сажает.
		_start_placing(Actions.USE, MachineCatalog.find(TileCatalog.cell_at(get_global_mouse_position())).is_empty())


func _start_placing(action: StringName, loud: bool) -> void:
	_placing = true
	_place_action = action
	_last_cell = Vector2i(-999, -999)
	_try_place(loud)


## ЛКМ ставит, если в руке семена или машина. Исключение одно: под курсором спелая грядка — её ЛКМ собирает.
func _left_click_builds() -> bool:
	var id := selected_id()
	if id != "seed" and id != BLOCK and not MachineCatalog.is_machine(id):
		return false
	var cell := TileCatalog.cell_at(get_global_mouse_position())
	var ripe := int(GameConfig.player()["ripe_stage"])
	for crop in Sim.get_crops():
		if crop.get("cell") in [cell, cell + Vector2i.DOWN] and int(crop.get("stage")) >= ripe:
			return false
	return true


func _process(_delta: float) -> void:
	_update_ghost()
	if _placing and not Input.is_action_pressed(_place_action):
		_placing = false
	# Протяжка с зажатой ПКМ: удобно тянуть конвейеры и лестницы.
	if _placing and not ghost.is_empty() and ghost["cell"] != _last_cell and MachineCatalog.size(ghost["type"]) == Vector2i.ONE:
		_try_place(false)
	elif _placing and selected_id() == "seed":
		_plant()          # протяжкой можно засеять всю пашню
	queue_redraw()


func _update_ghost() -> void:
	ghost = {}
	var id := selected_id()
	if id == BLOCK and not player.frozen:
		_update_block_ghost()
		return
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


## Блок земли: клетка пустая, рядом, и не там, где стоит сам герой (иначе застрянет).
func _update_block_ghost() -> void:
	var cell := TileCatalog.cell_at(get_global_mouse_position())
	var tile := Rect2(Vector2(cell) * TileCatalog.TILE, Vector2.ONE * TileCatalog.TILE)
	var body := Rect2(player.global_position - Vector2(5, 10), Vector2(10, 20))
	var reason := ""
	if not player.in_reach(TileCatalog.cell_center(cell)):
		reason = "REASON_TOO_FAR"
	elif not MachineCatalog.find(cell).is_empty():
		reason = "REASON_OCCUPIED"
	elif Sim.get_tile(cell) != Sim.Tile.AIR or Sim.get_tile(cell + Vector2i.DOWN) == Sim.Tile.FARMLAND:
		reason = "REASON_NOT_EMPTY"
	elif tile.intersects(body):
		reason = "REASON_PLAYER_HERE"
	ghost = {"type": BLOCK, "cell": cell, "dir": direction(), "ok": reason == "", "reason": reason}


func _try_place(loud: bool) -> void:
	if selected_id() == "seed":
		_plant(loud)
		return
	_update_ghost()   # клик мог прийти раньше, чем _process успел пересчитать призрак
	if ghost.is_empty():
		return
	_last_cell = ghost["cell"]
	if ghost["type"] == BLOCK:
		if ghost["ok"] and Sim.place_block(ghost["cell"]):
			GameState.report("placed:block")
			Audio.play("place")
		elif loud:
			GameState.notify(ghost["reason"])
			Audio.play("error")
		return
	if ghost["ok"] and Sim.place_machine(ghost["type"], ghost["cell"], ghost["dir"]):
		GameState.pay(MachineCatalog.cost(ghost["type"]))
		GameState.report("placed:" + ghost["type"])
		if ghost["type"] == "conveyor":   # лента упёрлась в машину: обучение ждёт «лента дошла до печи / до склада»
			var next := MachineCatalog.find(ghost["cell"] + ghost["dir"])
			if not next.is_empty():
				GameState.report("belt_into:" + next["type"])
		Audio.play("place")
	elif loud:
		GameState.notify(ghost["reason"])
		Audio.play("error")


## Посадить зерно: клик по грядке или по воздуху прямо над ней.
func _plant(loud: bool = false) -> void:
	var cost: Dictionary = GameConfig.player()["plant_cost"]
	var cell := TileCatalog.cell_at(get_global_mouse_position())
	if not player.in_reach(TileCatalog.cell_center(cell)) or not GameState.can_afford(cost):
		return
	for target in [cell, cell + Vector2i.DOWN]:
		if Sim.plant(target):
			GameState.pay(cost)
			GameState.report("planted")
			Audio.play("plant")
			return
	var on_plot := false
	for crop in Sim.get_crops():
		on_plot = on_plot or crop.get("cell") in [cell, cell + Vector2i.DOWN]
	if loud and not on_plot and _last_plant_warn != cell:
		_last_plant_warn = cell
		GameState.notify("NOTICE_PLANT_WHERE")


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
	var directional: bool = GameConfig.player()["directional"].has(type)
	if type == BLOCK:
		draw_texture(Sprites.icon(BLOCK), rect.position, Color(color, 0.75))
		return
	draw_set_transform(center, dir.angle() if type == "conveyor" else 0.0)
	draw_texture(Sprites.machine(type), -rect.size * 0.5, Color(color, 0.75))
	if directional and type != "conveyor":
		var arrow := Sprites.tex("arrow_out")
		draw_set_transform(center + dir * (rect.size.x * 0.5 - ARROW_INSET), dir.angle())
		draw_texture(arrow, -arrow.get_size() * 0.5, Color(1, 1, 1, 0.95))
	draw_set_transform(Vector2.ZERO)

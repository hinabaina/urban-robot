# ЛКМ (удержание): копать киркой, раздувать костёр. Полив и сбор урожая добавятся в B8. Владелец: B.
extends Node

signal dig_progress(cell: Vector2i, ratio: float)
signal dig_stopped()
signal dug(cell: Vector2i, got_ore: bool)
signal campfire_blown(cell: Vector2i)

const NO_CELL := Vector2i(-999, -999)

var world: Node2D            # WorldLoader, задаёт Main
var build: Node              # BuildController: какой инструмент выбран

var _held := false
var _cell := NO_CELL
var _time := 0.0

@onready var player: CharacterBody2D = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.USE):
		_held = true


func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed(Actions.USE):
		_held = false
	var mouse := player.get_global_mouse_position()
	var cell := TileCatalog.cell_at(mouse)
	var active := false
	if _held and not player.frozen and player.in_reach(TileCatalog.cell_center(cell)):
		active = _use(cell, delta)
	if not active and _cell != NO_CELL:
		_cell = NO_CELL
		_time = 0.0
		dig_stopped.emit()
	var icons: Dictionary = GameState.player_config["tool_icons"]
	player.set_working(active, mouse, int(icons.get(build.selected_id(), 0)))


func _use(cell: Vector2i, delta: float) -> bool:
	var machine := MachineCatalog.find(cell)
	if machine.get("type", "") == "campfire":
		return _blow_campfire(machine["cell"], delta)
	if build.selected_id() == "pickaxe":
		return _dig(cell, delta)
	return false


func _blow_campfire(cell: Vector2i, delta: float) -> bool:
	campfire_blown.emit(cell)
	if Sim.campfire_work(delta):
		if GameState.add_pocket("ingot") == 0:
			GameState.notify("NOTICE_POCKETS_FULL")
		Audio.play("ingot")
	return true


func _dig(cell: Vector2i, delta: float) -> bool:
	var need := Sim.dig_time(cell)
	if need <= 0.0:
		return false
	var is_ore: bool = world.kind_at(cell) == "ore"
	if is_ore and GameState.pockets["ore"] >= GameState.pocket_limit("ore"):
		if _cell != cell:
			GameState.notify("NOTICE_POCKETS_FULL")
		_cell = cell
		return false
	if cell != _cell:
		_cell = cell
		_time = 0.0
	_time += delta
	dig_progress.emit(cell, clampf(_time / need, 0.0, 1.0))
	if _time >= need:
		_time = 0.0
		var result: Dictionary = Sim.dig(cell)
		if result.get("ore", false):
			GameState.add_pocket("ore")
		dug.emit(cell, result.get("ore", false))
		Audio.play("ore" if result.get("ore", false) else "dig")
	return true

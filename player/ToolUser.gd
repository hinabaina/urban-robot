# ЛКМ (удержание): копать, раздувать костёр, набирать воду, поливать, собирать урожай. Владелец: B.
extends Node

signal progress(cell: Vector2i, ratio: float, action: String)   # идёт действие с удержанием
signal stopped()
signal dug(cell: Vector2i, got_ore: bool)
signal campfire_blown(cell: Vector2i)
signal harvested(cell: Vector2i, count: int)
signal watered(cell: Vector2i)

var world: Node2D            # WorldLoader, задаёт Main
var build: Node              # BuildController: какой инструмент выбран

var _held := false
var _key := ""               # действие + клетка, на которых копится время
var _time := 0.0
var _warned := ""            # предупреждение уже показано за это нажатие

@onready var player: CharacterBody2D = get_parent()
@onready var _cfg: Dictionary = GameConfig.player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.USE):
		_held = true


func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed(Actions.USE):
		_held = false
		_warned = ""
	var mouse := player.get_global_mouse_position()
	var cell := TileCatalog.cell_at(mouse)
	var action := {}
	if _held and not player.frozen and player.in_reach(TileCatalog.cell_center(cell)):
		action = _pick_action(cell)
	if action.is_empty():
		if _key != "":
			_key = ""
			stopped.emit()
	else:
		_run(action, delta)
	player.set_working(not action.is_empty(), mouse, int(_cfg["tool_icons"].get(build.selected_id(), 0)))


## Что делает ЛКМ по этой клетке: {id, cell, time, done} или пусто. time 0 — действие непрерывное.
func _pick_action(cell: Vector2i) -> Dictionary:
	var tool: String = build.selected_id()
	var machine := MachineCatalog.find(cell)
	if machine.get("type", "") == "campfire":
		return {"id": "campfire", "cell": machine["cell"], "time": 0.0, "done": _blow_campfire}
	var plot: Vector2i = world.plot_at(cell)
	if plot != world.NO_CELL and _crop_stage(plot) >= int(_cfg["ripe_stage"]):
		return {"id": "harvest", "cell": plot, "time": float(_cfg["harvest_time"]), "done": _harvest.bind(plot)}
	if tool == "can" and world.is_well(cell) and GameState.water < int(_cfg["can_capacity"]):
		return {"id": "fill", "cell": cell, "time": float(_cfg["can_fill_time"]), "done": _fill_can}
	if tool == "can" and plot != world.NO_CELL:
		if GameState.water <= 0:
			_warn("NOTICE_CAN_EMPTY")
			return {}
		return {"id": "water", "cell": plot, "time": float(_cfg["water_time"]), "done": _water.bind(plot)}
	if tool == "pickaxe" and Sim.dig_time(cell) > 0.0:
		if world.kind_at(cell) == "ore" and GameState.pockets["ore"] >= GameConfig.pocket_limit("ore"):
			_warn("NOTICE_POCKETS_FULL")
			return {}
		return {"id": "dig", "cell": cell, "time": Sim.dig_time(cell), "done": _dig.bind(cell)}
	return {}


func _warn(key: String) -> void:
	if _warned != key:
		_warned = key
		GameState.notify(key)


func _run(action: Dictionary, delta: float) -> void:
	var key := "%s %s" % [action["id"], action["cell"]]
	if key != _key:
		_key = key
		_time = 0.0
	if action["time"] <= 0.0:
		action["done"].call(action["cell"], delta)
		return
	_time += delta
	progress.emit(action["cell"], clampf(_time / action["time"], 0.0, 1.0), action["id"])
	if _time >= action["time"]:
		_time = 0.0
		action["done"].call()


func _crop_stage(plot: Vector2i) -> int:
	for crop in Sim.get_crops():
		if crop.get("cell") == plot:
			return int(crop.get("stage"))
	return 0


## ЛКМ по костру: если он пуст, сам кладёт сырьё из карманов (как E), затем раздувает. Над костром полоска готовности.
func _blow_campfire(cell: Vector2i, delta: float) -> void:
	if not Sim.campfire_loaded() and not _load_campfire(cell):
		_warn("NOTICE_CAMPFIRE_NEED")
		stopped.emit()
		return
	campfire_blown.emit(cell)
	var ready: bool = Sim.campfire_work(delta)
	progress.emit(cell, 1.0 if ready else Sim.campfire_progress(), "campfire")
	if ready:
		if GameState.add_pocket("ingot") == 0:
			GameState.notify("NOTICE_POCKETS_FULL")
		GameState.report("campfire_ingot")
		Audio.play("ingot")


func _load_campfire(cell: Vector2i) -> bool:
	var recipe: Dictionary = _cfg["campfire_recipe"]
	if not GameState.can_afford(recipe):
		return false
	for type in recipe:
		for i in int(recipe[type]):
			if Sim.insert(cell, type):
				GameState.pay({type: 1})
	GameState.report("campfire_loaded")
	return Sim.campfire_loaded()


func _dig(cell: Vector2i) -> void:
	var result: Dictionary = Sim.dig(cell)
	var got_ore: bool = result.get("ore", false)
	if got_ore:
		GameState.add_pocket("ore")
	dug.emit(cell, got_ore)
	Audio.play("ore" if got_ore else "dig")


func _fill_can() -> void:
	GameState.set_water(int(_cfg["can_capacity"]))
	Audio.play("water")


func _water(plot: Vector2i) -> void:
	if Sim.water(plot):
		GameState.set_water(GameState.water - 1)
		GameState.report("watered")
		watered.emit(plot)
		Audio.play("water")


func _harvest(plot: Vector2i) -> void:
	var count := Sim.harvest(plot)
	if count > 0:
		if GameState.add_pocket("grain", count) < count:
			GameState.notify("NOTICE_POCKETS_FULL")
		harvested.emit(plot, count)
		Audio.play("harvest")

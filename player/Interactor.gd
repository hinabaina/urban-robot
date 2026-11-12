# E — положить в машину / взять из машины; F или ЛКМ с ключом (держать) — снести машину с возвратом цены. Владелец: B.
extends Node

signal demolish_progress(cell: Vector2i, type: String, ratio: float)
signal demolish_stopped()

const NO_CELL := Vector2i(-999, -999)
const NEARBY_SKIP := ["ladder", "conveyor"]   # их E «рядом» не выбирает, только под курсором

var _hold := 0.0
var _hold_cell := NO_CELL

@onready var player: CharacterBody2D = get_parent()


func _physics_process(delta: float) -> void:
	if player.frozen:
		return
	if Input.is_action_just_pressed(Actions.INTERACT):
		_interact(_target(true))
	_demolish(delta)


## Машина под курсором (если дотягиваемся); иначе, при nearby, ближайшая к игроку.
func _target(nearby: bool) -> Dictionary:
	var cell := TileCatalog.cell_at(player.get_global_mouse_position())
	var machine := MachineCatalog.find(cell)
	if not machine.is_empty() and player.in_reach(MachineCatalog.center(machine["type"], machine["cell"])):
		return machine
	var best := {}
	var best_dist := float(GameConfig.player()["interact_tiles"]) * TileCatalog.TILE
	for m in Sim.get_machines() if nearby else []:
		var type: String = m.get("type")
		var dist := player.global_position.distance_to(MachineCatalog.center(type, m.get("cell")))
		if dist <= best_dist and not NEARBY_SKIP.has(type):
			best_dist = dist
			best = {"cell": m.get("cell"), "type": type}
	return best


func _interact(machine: Dictionary) -> void:
	if machine.is_empty():
		return
	var cell: Vector2i = machine["cell"]
	match machine["type"]:
		"storage":
			_give(cell, "ingot", GameState.pockets["ingot"])
			_collect(Sim.take(cell), cell)
		"campfire":
			var recipe: Dictionary = GameConfig.player()["campfire_recipe"]
			if GameState.can_afford(recipe):
				for type in recipe:
					_give(cell, type, int(recipe[type]))
				GameState.report("campfire_loaded")
			else:
				GameState.notify("NOTICE_CAMPFIRE_NEED")
		"furnace":
			# Сначала топливо. Руду из карманов кладём, только если зерна дать не вышло: иначе E «портит»
			# слитки линии ручной рудой, и автоматизация не растёт.
			_collect(Sim.take(cell), cell)
			var grain_before: int = GameState.pockets["grain"]
			_give(cell, "grain", grain_before)
			if GameState.pockets["grain"] == grain_before:
				_give(cell, "ore", GameState.pockets["ore"])
		_:
			_collect(Sim.take(cell), cell)
	Audio.play("interact")


## Переложить из карманов в машину до count штук (сколько примет).
func _give(cell: Vector2i, type: String, count: int) -> void:
	for i in count:
		if not Sim.insert(cell, type):
			break
		GameState.pay({type: 1})


## Забрать предметы в карманы; что не влезло — вернуть в машину, если она примет.
func _collect(items: Array, cell: Vector2i) -> void:
	var lost := false
	for item in items:
		var type: String = item.get("type")
		if GameState.add_pocket(type) == 0 and not Sim.insert(cell, type):
			lost = true
	if lost:
		GameState.notify("NOTICE_POCKETS_FULL")


func _demolish(delta: float) -> void:
	# Разобрать: держать F или ЛКМ с ключом в руке.
	var wrench: bool = player.get_node("Build").selected_id() == "wrench" and Input.is_action_pressed(Actions.USE)
	var machine := _target(false) if Input.is_action_pressed(Actions.DEMOLISH) or wrench else {}
	# Склад и костёр стоят на карте с начала игры: чертежа у них нет, сносить нельзя.
	if machine.is_empty() or GameConfig.unlock_day(machine["type"]) < 0:
		_stop_demolish()
		return
	if machine["cell"] != _hold_cell:
		_hold = 0.0
		_hold_cell = machine["cell"]
	_hold += delta
	var need := float(GameConfig.player()["demolish_hold"])
	demolish_progress.emit(machine["cell"], machine["type"], minf(_hold / need, 1.0))
	if _hold < need:
		return
	_stop_demolish()
	_collect(Sim.remove_machine(machine["cell"]), machine["cell"])
	var cost := MachineCatalog.cost(machine["type"])
	for type in cost:
		GameState.add_pocket(type, int(cost[type]))   # возврат 100%
	Audio.play("demolish")


func _stop_demolish() -> void:
	if _hold > 0.0:
		demolish_stopped.emit()
	_hold = 0.0
	_hold_cell = NO_CELL

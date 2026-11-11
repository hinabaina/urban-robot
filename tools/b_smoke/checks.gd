# Автопроверки части B на настоящем движке (в билд не входит). Запуск: tools/b_smoke/shot.sh out.png 0.2 checks
extends "res://tools/b_smoke/shot.gd"

var failed := 0
var player: CharacterBody2D
var world: Node2D


func check(name: String, ok: bool, info = "") -> void:
	if not ok:
		failed += 1
	print("PASS " if ok else "FAIL ", name, "  ", info)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Ждать фазу дня не дольше limit секунд.
func wait_phase(phase: int, limit: float) -> void:
	var left := limit
	while DayCycle.phase != phase and left > 0.0:
		await wait(0.1)
		left -= 0.1


func teleport(cell: Vector2i) -> void:
	player.global_position = TileCatalog.cell_center(cell) - Vector2(0, 2)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	player.camera.reset_smoothing()
	await wait(0.25)


func scenario_checks() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	await _movement()
	await _digging()
	await _hands()
	await _farming()
	await _building()
	await _pause()
	await _day_end()
	for part in [_save, _tutorial]:   # каждая часть начинает с чистой партии
		await relaunch(false)
		await part.call()
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


func _movement() -> void:
	var x0 := player.global_position.x
	await hold(Actions.RIGHT, 1.0)
	check("walk 120 px/s", absf(player.global_position.x - x0 - 120.0) < 8.0, player.global_position.x - x0)
	var y0 := player.global_position.y
	var top := y0
	Input.action_press(Actions.JUMP)
	for i in 50:
		await get_tree().physics_frame
		top = minf(top, player.global_position.y)
	Input.action_release(Actions.JUMP)
	check("jump ~3 tiles", absf((y0 - top) - 52.0) < 5.0, y0 - top)
	await teleport(Vector2i(30, 11))
	y0 = player.global_position.y
	await hold(Actions.RIGHT, 0.5)
	check("walk over shaft top without falling", absf(player.global_position.y - y0) < 1.5 and player.global_position.x > 34 * 16 - 20,
		[player.global_position, y0])
	await teleport(Vector2i(32, 11))
	await hold(Actions.DOWN, 1.4)
	check("climb down ladder to shaft bottom", TileCatalog.cell_at(player.global_position).y == 17, player.global_position)
	await hold(Actions.UP, 1.6)
	check("climb up and stand on ladder top", absf(player.feet_y() - 192.0) < 2.0, player.feet_y())
	await wait(0.3)
	check("stays on ladder top", absf(player.feet_y() - 192.0) < 2.0, player.feet_y())


func _digging() -> void:
	await teleport(Vector2i(32, 17))
	mouse_to_cell(Vector2i(31, 17))
	await click(Actions.USE, 0.6)
	check("dig soil tile", Sim.get_tile(Vector2i(31, 17)) == Sim.Tile.AIR and world.kind_at(Vector2i(31, 17)) == "")
	mouse_to_cell(Vector2i(33, 17))
	await click(Actions.USE, 2.6)
	check("mine 2 ore in 2.6 s", GameState.pockets["ore"] == 2, GameState.pockets)
	mouse_to_cell(Vector2i(38, 17))
	await click(Actions.USE, 0.8)
	check("no digging beyond reach", Sim.get_tile(Vector2i(38, 17)) != Sim.Tile.AIR)
	await press(Actions.slot(1))
	mouse_to_cell(Vector2i(31, 16))
	await click(Actions.USE, 0.8)
	check("no digging without pickaxe", Sim.get_tile(Vector2i(31, 16)) != Sim.Tile.AIR)
	await press(Actions.slot(0))


func _hands() -> void:
	var fire: Vector2i = world.marker_cell("Campfire")
	await teleport(fire + Vector2i(-1, 0))
	mouse_to_cell(fire)
	await press(Actions.INTERACT)
	check("campfire takes 2 ore + 1 grain", GameState.pockets["ore"] == 0 and GameState.pockets["grain"] == 9, GameState.pockets)
	await click(Actions.USE, 3.2)
	check("campfire gives ingot after 3 s", GameState.pockets["ingot"] == 1, GameState.pockets)
	await press(Actions.INTERACT)
	check("campfire refuses without ore", GameState.pockets["grain"] == 9)
	var storage: Vector2i = world.marker_cell("Storage")
	await teleport(storage + Vector2i(-1, 1))
	mouse_to_cell(storage + Vector2i(-6, -4))
	await press(Actions.INTERACT)
	check("E near storage delivers ingot", Sim.storage_count("ingot") == 1 and GameState.pockets["ingot"] == 0,
		[Sim.storage_count("ingot"), GameState.pockets])


func _farming() -> void:
	var plot := Vector2i(18, 12)
	await teleport(Vector2i(17, 11))
	await press(Actions.slot(2))
	mouse_to_cell(plot + Vector2i.UP)
	await press(Actions.PLACE)
	check("plant seed costs 1 grain", GameState.pockets["grain"] == 8 and _stage(plot) == 1, [GameState.pockets, _stage(plot)])
	await press(Actions.slot(1))
	await click(Actions.USE, 0.5)
	check("empty can does not water", not _wet(plot))
	await teleport(Vector2i(7, 11))
	mouse_to_cell(Vector2i(6, 11))
	await click(Actions.USE, 1.2)
	check("fill can at well", GameState.water == 10, GameState.water)
	await teleport(Vector2i(17, 11))
	mouse_to_cell(plot)
	await click(Actions.USE, 0.45)
	check("water plot", _wet(plot) and GameState.water == 9, [_wet(plot), GameState.water])
	for i in 2:   # влажность держится 15 с, рост идёт 30 с: поливаем ещё дважды
		Sim.advance(14.0)
		await click(Actions.USE, 0.45)
	Sim.advance(4.0)
	check("crop is ripe after 30 s wet", _stage(plot) == 4, _stage(plot))
	await press(Actions.slot(0))
	await click(Actions.USE, 0.45)
	check("harvest gives 3 grain", GameState.pockets["grain"] == 11 and _stage(plot) == 0, [GameState.pockets, _stage(plot)])
	check("farmland is not diggable", world.kind_at(plot) == "farmland")


func _stage(plot: Vector2i) -> int:
	for crop in Sim.get_crops():
		if crop["cell"] == plot:
			return crop["stage"]
	return -1


func _wet(plot: Vector2i) -> bool:
	for crop in Sim.get_crops():
		if crop["cell"] == plot:
			return crop["wet"]
	return false


func _building() -> void:
	await press(Actions.slot(4))
	check("locked slot is not selectable", main.get_node("Player/Build").selected == 0)
	GameState.unlocked.assign(GameConfig.player()["hotbar"])
	GameState.unlocked_changed.emit()
	GameState.pockets["ore"] = 10
	GameState.pockets_changed.emit()
	await teleport(Vector2i(44, 11))
	await press(Actions.slot(4))
	mouse_to_cell(Vector2i(45, 10))
	await get_tree().process_frame
	var event := InputEventAction.new()
	event.action = Actions.PLACE
	event.pressed = true
	Input.parse_input_event(event)
	Input.action_press(Actions.PLACE)
	for x in [46, 47]:
		await wait(0.1)
		mouse_to_cell(Vector2i(x, 10))
	await wait(0.1)
	Input.action_release(Actions.PLACE)
	var conveyors := Sim.get_machines().filter(func(m): return m["type"] == "conveyor").size()
	check("drag-place 3 conveyors, pay 3 ore", conveyors == 3 and GameState.pockets["ore"] == 7, [conveyors, GameState.pockets])
	mouse_to_cell(Vector2i(46, 10))
	await hold(Actions.DEMOLISH, 0.7)
	conveyors = Sim.get_machines().filter(func(m): return m["type"] == "conveyor").size()
	check("hold F removes conveyor with refund", conveyors == 2 and GameState.pockets["ore"] == 8, [conveyors, GameState.pockets])
	mouse_to_cell(world.marker_cell("Storage"))
	await hold(Actions.DEMOLISH, 0.7)
	check("storage cannot be demolished", not MachineCatalog.find(world.marker_cell("Storage")).is_empty())
	await press(Actions.slot(5))
	mouse_to_cell(Vector2i(46, 9))
	await press(Actions.PLACE)
	check("drill refused away from vein", MachineCatalog.find(Vector2i(46, 9)).is_empty())
	await press(Actions.slot(0))


func _pause() -> void:
	await press(Actions.PAUSE)
	check("Esc pauses", get_tree().paused and main.get_node("UI/PauseMenu").visible)
	await press(Actions.PAUSE)
	check("Esc resumes", not get_tree().paused and not main.get_node("UI/PauseMenu").visible)


func _day_end() -> void:
	GameState.trust = 1
	DayCycle.hour = 17.95
	await wait(8.0)
	check("missed quota at last trust -> game over (lost)", DayCycle.phase == DayCycle.Phase.OVER and GameState.trust == 0
		and main.get_node("UI/EndScreen").visible and player.frozen, [DayCycle.phase, GameState.trust])


## Обучение дня 1 настоящим вводом от первого шага до последнего.
func scenario_tutorial() -> void:
	await _tutorial()
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


func _tutorial() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	var tutorial: Control = main.get_node("UI/Tutorial")
	var step := func() -> int: return tutorial._index
	await hold(Actions.RIGHT, 0.5)
	check("step 1 done after walking", step.call() == 1, step.call())
	await teleport(Vector2i(32, 11))
	await hold(Actions.DOWN, 1.4)
	check("step 2 done at shaft bottom", step.call() == 2, step.call())
	mouse_to_cell(Vector2i(33, 17))
	await click(Actions.USE, 5.0)
	check("step 3 done with 4 ore", step.call() == 3, [step.call(), GameState.pockets])
	var fire: Vector2i = world.marker_cell("Campfire")
	await teleport(fire + Vector2i(-1, 0))
	mouse_to_cell(fire)
	await press(Actions.INTERACT)
	check("step 4 done after loading campfire", step.call() == 4, step.call())
	await click(Actions.USE, 3.2)
	check("step 5 done with ingot", step.call() == 5, step.call())
	await teleport(world.marker_cell("Storage") + Vector2i(-1, 1))
	await press(Actions.INTERACT)
	await wait(0.1)
	check("step 6 done after storage", step.call() == 6, step.call())
	GameState.set_water(3)
	await teleport(Vector2i(13, 11))
	await press(Actions.slot(1))
	mouse_to_cell(Vector2i(14, 12))
	await click(Actions.USE, 0.5)
	check("step 7 done after watering", step.call() == 7, step.call())
	check("clock is slowed during tutorial", is_equal_approx(DayCycle.clock_scale, 0.5))
	await wait(8.3)
	check("tutorial finished, clock back to normal", not tutorial.is_active() and is_equal_approx(DayCycle.clock_scale, 1.0))


## Сохранение: утро после отчёта пишется на диск, «Продолжить» возвращает это утро целиком.
func scenario_save() -> void:
	await _save()
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


func _save() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	check("new game saves day 1 morning", SaveManager.has_save() and int(SaveManager.read()["game"]["day"]) == 1)
	GameState.unlocked.assign(GameConfig.player()["hotbar"])
	GameState.pockets = {"ore": 30, "grain": 12, "ingot": 4}
	GameState.pockets_changed.emit()
	for x in range(44, 48):
		Sim.place_machine("conveyor", Vector2i(x, 10), Vector2i.RIGHT)
	Sim.dig(Vector2i(20, 14))
	var storage: Vector2i = world.marker_cell("Storage")
	for i in 7:
		Sim.insert(storage, "ingot")
	DayCycle.hour = 17.95
	await wait_phase(DayCycle.Phase.EVENING, 10.0)
	DayCycle.sleep()
	await wait_phase(DayCycle.Phase.REPORT, 10.0)
	check("night ends with report", DayCycle.phase == DayCycle.Phase.REPORT, DayCycle.phase)
	main.get_node("UI/NightReport")._on_morning()
	await wait(0.2)
	var saved: Dictionary = SaveManager.read()
	check("morning of day 2 saved", int(saved.get("game", {}).get("day", 0)) == 2, saved.get("game", {}).get("day"))
	var expect := _snapshot()
	Sim.place_machine("conveyor", Vector2i(48, 10), Vector2i.RIGHT)
	Sim.dig(Vector2i(21, 14))
	GameState.pockets["ore"] = 1
	GameState.day = 4
	await relaunch(true)
	player = main.get_node("Player")
	world = main.get_node("World")
	var got := _snapshot()
	for key in expect:
		check("restored " + key, JSON.stringify(expect[key], "", true) == JSON.stringify(got[key], "", true), [expect[key], got[key]])
	check("rocket view shows saved parts", main.get_node("Rocket")._built == 1, main.get_node("Rocket")._built)
	check("tile view matches sim after load", world.kind_at(Vector2i(20, 14)) == "" and world.kind_at(Vector2i(21, 14)) == "soil")
	check("day starts at 06:00 after load", DayCycle.phase == DayCycle.Phase.DAY and DayCycle.clock_text() == "06:00")
	FileAccess.open("user://save.json", FileAccess.WRITE).store_string("{broken")
	await relaunch(true)
	check("broken save starts a new game", GameState.day == 1 and Sim.storage_count("ingot") == 0)
	GameState.trust = 1
	DayCycle.hour = 17.95
	await wait(8.0)
	var end: Control = main.get_node("UI/EndScreen")
	var texts: Array = end.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check("lose screen offers retry day", texts.has(tr("END_RETRY")), texts)


func _snapshot() -> Dictionary:
	var machines := Sim.get_machines().map(func(m: Variant) -> String: return "%s%s" % [m.get("type"), m.get("cell")])
	machines.sort()
	return {"day": GameState.day, "trust": GameState.trust, "pockets": GameState.pockets.duplicate(), "unlocked": GameState.unlocked.duplicate(),
		"rocket": GameState.rocket.duplicate(true), "delivered": GameState.delivered_total, "storage": Sim.storage_count("ingot"),
		"machines": machines, "dug": Sim.get_tile(Vector2i(20, 14)), "undug": Sim.get_tile(Vector2i(21, 14))}

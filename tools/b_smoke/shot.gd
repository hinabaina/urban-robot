# Снимок игры для проверки глазами (в билд не входит):
#   godot --path . res://tools/b_smoke/Shot.tscn -- out.png [секунды] [сценарий]
extends Node

var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "shot.png"
	var wait := float(args[1]) if args.size() > 1 else 1.0
	get_tree().create_timer(100.0).timeout.connect(func() -> void:
		print("WATCHDOG: сценарий не завершился")
		get_tree().quit(1))
	var scenario: String = args[2] if args.size() > 2 else ""
	load("res://main/Main.gd").skip_menu = not scenario.begins_with("menu")
	main = load("res://main/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.3).timeout
	if args.size() > 2:
		await call("scenario_" + args[2])
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()


func hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)


func mouse_to_cell(cell: Vector2i) -> void:
	mouse_to_world(TileCatalog.cell_center(cell))


func mouse_to_world(world_pos: Vector2) -> void:
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * world_pos
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)


func click(action: StringName, seconds: float = 0.05) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(seconds).timeout
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


## Дойти до шахты, спуститься и покопать руду.
func scenario_mine() -> void:
	await hold(Actions.RIGHT, 0.55)
	await hold(Actions.DOWN, 1.2)
	mouse_to_cell(Vector2i(33, 16))
	await click(Actions.USE, 2.6)
	mouse_to_cell(Vector2i(31, 16))
	await click(Actions.USE, 0.3)


func scenario_ui() -> void:
	var hotbar: Control = main.get_node("UI/Hotbar")
	print("hotbar root ", hotbar.get_global_rect())
	for child in hotbar.get_children():
		print("  ", child.get_class(), " ", child.get_global_rect(), " visible=", child.visible)


func press(action: StringName) -> void:
	await click(action, 0.05)


## Поставить машину. Для 2x2 курсор целим в общий угол четырёх клеток: cell — правая нижняя из них.
func place(slot_index: int, cell: Vector2i) -> void:
	await press(Actions.slot(slot_index))
	var id: String = GameState.player_config["hotbar"][slot_index]
	if MachineCatalog.size(id) == Vector2i.ONE:
		mouse_to_cell(cell)
	else:
		mouse_to_world(Vector2(cell) * TileCatalog.TILE)
	await get_tree().process_frame
	await press(Actions.PLACE)


## Камера под землёй: открыть чертежи, выдать ресурсы, собрать линию бур -> конвейер -> печь -> конвейер.
func scenario_factory() -> void:
	var player: CharacterBody2D = main.get_node("Player")
	GameState.unlocked.assign(GameState.player_config["hotbar"])
	GameState.unlocked_changed.emit()
	GameState.pockets = {"ore": 40, "grain": 10, "ingot": 15}
	GameState.pockets_changed.emit()
	for x in range(33, 42):
		for y in [14, 15]:
			Sim.dig(Vector2i(x, y))
	player.global_position = TileCatalog.cell_center(Vector2i(36, 15)) - Vector2(0, 2)
	await get_tree().create_timer(0.3).timeout
	await place(5, Vector2i(34, 15))          # бур 2x2, якорь (33,14)
	await place(4, Vector2i(35, 14))          # конвейеры
	await place(4, Vector2i(36, 14))
	await place(6, Vector2i(38, 15))          # печь, якорь (37,14)
	await place(4, Vector2i(39, 14))
	await place(4, Vector2i(40, 14))
	print("machines: ", Sim.get_machines().map(func(m): return [m["type"], m["cell"]]))
	print("pockets after build: ", GameState.pockets)
	DayCycle.set_user_speed(2.0)
	await get_tree().create_timer(9.0).timeout
	print("items: ", Sim.get_items().size(), " furnace: ", MachineCatalog.find(Vector2i(37, 14)))
	mouse_to_cell(Vector2i(41, 13))           # призрак «нельзя»: земля


## Сутки целиком: слитки на склад, дрон, вечер, сон, ночь, отчёт, утро.
func scenario_day() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0].get_base_dir()
	var storage: Vector2i = main.get_node("World").marker_cell("Storage")
	for i in 7:
		Sim.insert(storage, "ingot")
	DayCycle.hour = 17.9
	await get_tree().create_timer(3.6).timeout
	print("phase=", DayCycle.phase, " drone_t=", DayCycle.drone_t, " rocket=", GameState.rocket, " storage=", Sim.storage_count("ingot"))
	main.get_node("Player").global_position = TileCatalog.cell_center(Vector2i(47, 11))
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(out_dir + "/day_drone.png")
	await get_tree().create_timer(3.0).timeout
	print("phase=", DayCycle.phase, " hour=", DayCycle.hour, " can_sleep=", DayCycle.can_sleep())
	get_viewport().get_texture().get_image().save_png(out_dir + "/day_evening.png")
	await press(Actions.SLEEP)
	await get_tree().create_timer(1.0).timeout
	print("phase=", DayCycle.phase, " hour=", DayCycle.hour, " speed=", DayCycle.speed)
	get_viewport().get_texture().get_image().save_png(out_dir + "/day_night.png")
	await get_tree().create_timer(6.0).timeout
	print("phase=", DayCycle.phase, " hour=", DayCycle.hour, " day=", GameState.day)
	get_viewport().get_texture().get_image().save_png(out_dir + "/day_report.png")
	DayCycle.next_morning()
	await get_tree().create_timer(0.5).timeout
	print("phase=", DayCycle.phase, " day=", GameState.day, " unlocked=", GameState.unlocked, " pockets=", GameState.pockets)


## Вид фермы: посадить и полить несколько грядок на разных стадиях.
func scenario_farm() -> void:
	for x in range(9, 21):
		Sim.plant(Vector2i(x, 12))
	for x in range(9, 18):
		Sim.water(Vector2i(x, 12))
	Sim.advance(12.0)
	for x in range(12, 18):
		Sim.water(Vector2i(x, 12))
	Sim.advance(10.0)
	for x in range(15, 18):
		Sim.water(Vector2i(x, 12))
	Sim.advance(9.0)
	main.get_node("Player").global_position = TileCatalog.cell_center(Vector2i(13, 11))
	GameState.set_water(6)
	await press(Actions.slot(1))
	mouse_to_cell(Vector2i(12, 11))


func scenario_menu() -> void:
	pass


func scenario_menu_howto() -> void:
	main.get_node("UI/InfoPage").open("howto")


func scenario_menu_settings() -> void:
	main.get_node("UI/SettingsPanel").open()


## Победа: последний день, квота на складе, дрон, взлёт, итог со звёздами.
func scenario_win() -> void:
	GameState.day = 5
	for i in 4:
		GameState.rocket.append({"part": GameState.config["days"][i]["rocket_part"], "patched": i == 2})
	main.get_node("Rocket")._sync(false)
	var storage: Vector2i = main.get_node("World").marker_cell("Storage")
	for i in 50:
		Sim.insert(storage, "ingot")
	DayCycle.hour = 17.95
	await get_tree().create_timer(8.2).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir() + "/win_launch.png")
	await get_tree().create_timer(5.5).timeout
	print("stars=", GameState.stars(), " phase=", DayCycle.phase)


func scenario_xray() -> void:
	await scenario_factory()
	await press(Actions.XRAY)

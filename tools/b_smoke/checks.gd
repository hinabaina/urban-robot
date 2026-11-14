# Автопроверки части B на заглушке Sim (в билд не входит). Запуск: tools/b_smoke/shot.sh out.png 0.2 checks
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


func teleport(cell: Vector2i) -> void:
	player.global_position = TileCatalog.cell_center(cell) - Vector2(0, 2)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	player.camera.snap()
	await wait(0.25)


func scenario_checks() -> void:
	Moment.enabled = false   # отдельные проверки двигают время сами; моменты и рацию проверяет scenario_tutorial
	Radio.enabled = false
	player = main.get_node("Player")
	world = main.get_node("World")
	GameState.early_gift_given = true   # посылку дня 1 проверяет scenario_tutorial; здесь она мешала бы счёту карманов
	await _movement()
	await _digging()
	await _hands()
	await _farming()
	await _building()
	await _tools()
	await _pause()
	await _saving()
	await _day_end()
	_retry_button()
	await _intro()
	await _languages()
	await _info_page()
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


## Инструменты 10 и 11: блок земли ставится в пустую клетку и не туда, где стоит герой; ключ разбирает машину.
func _tools() -> void:
	await teleport(Vector2i(44, 11))
	await press(Actions.slot(10))
	check("block slot selected with the minus key slot", main.get_node("Player/Build").selected_id() == "block")
	mouse_to_cell(Vector2i(46, 11))
	await get_tree().process_frame
	await press(Actions.PLACE)
	check("block placed in empty air", Sim.get_tile(Vector2i(46, 11)) == Sim.Tile.SOIL, Sim.get_tile(Vector2i(46, 11)))
	mouse_to_cell(Vector2i(44, 11))
	await get_tree().process_frame
	await press(Actions.PLACE)
	check("no block where the player stands", Sim.get_tile(Vector2i(44, 11)) == Sim.Tile.AIR)
	GameState.pockets["ore"] = 5
	GameState.pockets_changed.emit()
	await press(Actions.slot(4))
	mouse_to_cell(Vector2i(46, 10))
	await get_tree().process_frame
	await press(Actions.PLACE)
	check("conveyor stands on the block", MachineCatalog.find(Vector2i(46, 10)).get("type") == "conveyor" and GameState.pockets["ore"] == 4)
	await press(Actions.slot(9))
	mouse_to_cell(Vector2i(46, 10))
	await get_tree().process_frame
	await hold(Actions.USE, 0.8)
	check("wrench + LMB dismantles with refund", MachineCatalog.find(Vector2i(46, 10)).is_empty() and GameState.pockets["ore"] == 5,
		[MachineCatalog.find(Vector2i(46, 10)), GameState.pockets])
	await press(Actions.slot(0))
	mouse_to_cell(Vector2i(46, 11))
	await get_tree().process_frame
	await click(Actions.USE, 0.7)
	check("pickaxe digs the block out", Sim.get_tile(Vector2i(46, 11)) == Sim.Tile.AIR)


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
	var right_edge := float(TileCatalog.MAP_SIZE.x * TileCatalog.TILE)
	await teleport(Vector2i(1, 11))
	await hold(Actions.LEFT, 1.0)
	check("invisible wall at the left edge", player.global_position.x >= 5.0 and absf(player.feet_y() - 192.0) < 2.0, player.global_position)
	await teleport(Vector2i(TileCatalog.MAP_SIZE.x - 2, 11))
	await hold(Actions.RIGHT, 1.0)
	check("invisible wall at the right edge", player.global_position.x <= right_edge - 5.0 and absf(player.feet_y() - 192.0) < 2.0, player.global_position)


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
	GameState.add_pocket("ore", 2)
	await click(Actions.USE, 1.5)
	check("LMB alone loads the campfire and shows progress", GameState.pockets["ore"] == 0 and Sim.campfire_loaded()
		and Sim.campfire_progress() > 0.3, [GameState.pockets, Sim.campfire_progress()])
	await click(Actions.USE, 1.8)
	check("LMB alone smelts an ingot (no E needed)", GameState.pockets["ingot"] == 2 and GameState.pockets["grain"] == 8, GameState.pockets)
	GameState.pay({"ingot": 1})
	GameState.add_pocket("grain")
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
	await click(Actions.USE)      # левой кнопкой: на Mac правую нажать неудобно
	check("LMB plants a seed, seeds are free", GameState.pockets["grain"] == 9 and _stage(plot) == 1, [GameState.pockets, _stage(plot)])
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
	check("harvest gives 3 grain", GameState.pockets["grain"] == 12 and _stage(plot) == 0, [GameState.pockets, _stage(plot)])
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


## Утро сохраняется само; «Продолжить» поднимает день, карманы и машины из файла.
func _saving() -> void:
	SaveManager.delete_save()
	DayCycle.day_started.emit(GameState.day)
	check("morning autosave written", SaveManager.has_save() and not SaveManager.read().is_empty())
	var saved := SaveManager.read()
	saved["game"]["day"] = 3
	saved["game"]["pockets"]["ore"] = 7
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var machines: int = Sim.get_machines().size()
	var campfire: Vector2i = world.marker_cell("Campfire")
	Sim.remove_machine(campfire)
	GameState.day = 1
	GameState.pockets["ore"] = 0
	main._load_morning()
	await wait(0.2)
	check("continue restores the day", GameState.day == 3, GameState.day)
	check("continue restores pockets", int(GameState.pockets.get("ore", 0)) == 7, GameState.pockets)
	check("continue restores machines and their sprites", Sim.get_machines().size() == machines
		and main.get_node("MachineView")._nodes.has(campfire), [Sim.get_machines().size(), machines])


## После поражения можно переиграть день с утреннего сохранения.
func _retry_button() -> void:
	var found := false
	for node in main.get_node("UI/EndScreen").find_children("*", "Button", true, false):
		found = found or (node as Button).text == tr("END_RETRY")
	check("lost game offers retry of the day", found)
	SaveManager.delete_save()


func _day_end() -> void:
	GameState.trust = 1
	DayCycle.hour = 17.95
	await wait(8.0)
	check("missed quota at last trust -> game over (lost)", DayCycle.phase == DayCycle.Phase.OVER and GameState.trust == 0
		and main.get_node("UI/EndScreen").visible and player.frozen, [DayCycle.phase, GameState.trust])


## Обучение дня 1 настоящим вводом от первого шага до последнего: руками один слиток, потом своя линия.
func scenario_tutorial() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	var tutorial: Control = main.get_node("UI/Tutorial")
	var step := func() -> int: return tutorial._index
	var radio: Radio = main.get_node("UI/Radio")
	await wait(0.2)
	check("the game opens with Aisha's radio call, player is held", radio.is_open() and player.frozen)
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir() + "/radio_hello.png")
	await _radio_through(radio)
	check("after the call the player is free", not radio.is_open() and not player.frozen and DayCycle.running)
	check("tutorial hint is shown", tutorial._panel.visible and tutorial._panel.modulate.a > 0.9)
	tutorial._fade_panel(tutorial.SHOW_TIME + tutorial.FADE_TIME + 0.1)
	check("tutorial hint fades away by itself", not tutorial._panel.visible)
	await hold(Actions.RIGHT, 0.5)
	check("step 1 done after walking", step.call() == 1, step.call())
	check("next step shows the hint again", tutorial._panel.visible and tutorial._panel.modulate.a > 0.9)
	await teleport(Vector2i(32, 11))
	await hold(Actions.DOWN, 1.4)
	check("step 2 done at shaft bottom", step.call() == 2, step.call())
	mouse_to_cell(Vector2i(33, 17))
	await click(Actions.USE, 5.0)
	check("step 3 done with 4 ore", step.call() == 3, [step.call(), GameState.pockets])
	var fire: Vector2i = world.marker_cell("Campfire")
	await teleport(fire + Vector2i(-1, 0))
	mouse_to_cell(fire)
	await click(Actions.USE, 3.2)
	check("step 4 done: LMB on campfire gives an ingot", step.call() == 4, [step.call(), GameState.pockets])
	check("machines are still locked", not GameState.is_unlocked("drill"))
	await teleport(world.marker_cell("Storage") + Vector2i(-1, 1))
	await press(Actions.INTERACT)
	await wait(0.1)
	check("step 5 done: first ingot in storage brings the parcel", step.call() == 5 and GameState.is_unlocked("drill")
		and GameState.is_unlocked("furnace") and GameState.is_unlocked("conveyor"), [step.call(), GameState.unlocked])
	var moment: Moment = main.get_node("UI/Moment")
	check("parcel plays a cinematic moment that freezes the player", moment.is_playing() and player.frozen)
	await wait(1.6)
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir() + "/moment_parcel.png")
	while moment.is_playing():
		await wait(0.1)
	check("after the moment the player can move again", not player.frozen and DayCycle.running)
	check("after the moment its title is gone from the screen", moment._title.text == "" and moment._subtitle.text == "", moment._title.text)
	check("parcel has parts for the first line", GameState.pockets["ingot"] == 5 and GameState.pockets["ore"] >= 24, GameState.pockets)
	await teleport(Vector2i(41, 11))
	await _radio_through(main.get_node("UI/Radio"))
	await press(Actions.slot(5))
	mouse_to_world(TileCatalog.cell_center(Vector2i(38, 10)) + Vector2(4, 4))   # не на границе клеток призрака 2x2
	await get_tree().process_frame     # живая мышь тоже приходит раньше клика: призрак успевает встать под курсор
	await press(Actions.PLACE)
	check("step 6 done: drill stands on the surface outcrop", step.call() == 6 and MachineCatalog.find(Vector2i(38, 10)).get("type") == "drill",
		[step.call(), Sim.can_place("drill", Vector2i(38, 10), Vector2i.RIGHT)])
	await _radio_through(main.get_node("UI/Radio"))   # звонок по часам мог прийти прямо сейчас: игрок сначала дослушает
	await press(Actions.slot(6))
	mouse_to_world(TileCatalog.cell_center(Vector2i(44, 10)) + Vector2(4, 4))
	await get_tree().process_frame
	await press(Actions.PLACE)
	check("step 7 done: furnace placed", step.call() == 7, step.call())
	await press(Actions.slot(4))
	await _drag_belt(40, 43)
	check("step 8 done when the belt reaches the furnace", step.call() == 8, step.call())
	await teleport(Vector2i(47, 11))
	await _drag_belt(46, 49)
	check("step 9 done when the belt reaches the storage", step.call() == 9, step.call())
	mouse_to_cell(Vector2i(45, 11))
	await press(Actions.INTERACT)
	check("E puts grain into the furnace", GameState.pockets["grain"] < 9, GameState.pockets)
	check("clock is slowed during tutorial", is_equal_approx(DayCycle.clock_scale, 0.5))
	var seconds := 0.0
	while Sim.storage_count("ingot") < 2 and seconds < 40.0:
		await wait(1.0)
		seconds += 1.0
	check("step 10 done: the line delivers an ingot by itself within 40 s", step.call() == 10 and Sim.storage_count("ingot") >= 2,
		[step.call(), Sim.storage_count("ingot"), seconds])
	check("first automatic ingot plays its moment", GameState.moments_seen.has("auto"), GameState.moments_seen)
	check("automation bar is live", GameState.live_automation() > 0.0, [GameState.made_auto, GameState.made_total])
	while moment.is_playing():
		await wait(0.1)
	await wait(0.3)
	check("Aisha reacts to the first hands-free ingot", radio.is_open())
	await _radio_through(radio)
	check("then the dispatcher introduces himself", GameState.bonds.has("dispatcher"), GameState.bonds)
	await wait(10.3)
	check("tutorial finished, clock back to normal", not tutorial.is_active() and is_equal_approx(DayCycle.clock_scale, 1.0))
	mouse_to_cell(Vector2i(45, 11))
	await press(Actions.INTERACT)      # нормы 8 одной закладки зерна не хватает: подкидываем ещё
	while Sim.storage_count("ingot") < GameState.quota() and seconds < 120.0:
		await wait(1.0)
		seconds += 1.0
	check("day 1 quota is met by the line", Sim.storage_count("ingot") >= GameState.quota(), [Sim.storage_count("ingot"), seconds, DayCycle.clock_text()])
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


## Протянуть ленту по земле от клетки x0 до x1 зажатой ПКМ.
## Сюжет по рации: ответы меняют отношения, выбор с насосом забирает слитки и меняет следующее утро,
## буря рвёт ленты, развилка с орбитой открывает третий ответ только при доверии обоих и задаёт концовку.
func scenario_story() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	Moment.enabled = false
	main.get_node("UI/Tutorial")._finish()
	var radio: Radio = main.get_node("UI/Radio")
	var shots: String = OS.get_cmdline_user_args()[0].get_base_dir()
	await wait(0.2)
	radio.press(-1)                      # первая реплика Айши: допечатать и дальше
	await wait(0.1)
	radio.press(-1)
	await wait(0.1)
	radio.press(-1)                      # вторая реплика допечатана, под ней три ответа
	await wait(0.1)
	get_viewport().get_texture().get_image().save_png(shots + "/radio_reply.png")
	radio.press(0)                       # «Подниму. Обещаю.»
	await wait(0.5)
	check("a reply is remembered by Aisha", GameState.bonds.get("aisha", 0) == 1 and radio.is_open(), GameState.bonds)
	get_viewport().get_texture().get_image().save_png(shots + "/radio_remember.png")
	await _radio_through(radio)
	radio._on_event("auto_ingot")        # первый слиток без рук: Айша радуется, следом выходит на связь диспетчер
	await wait(0.3)
	await _radio_through(radio)          # диспетчеру: «Норма будет.»
	check("the dispatcher calls after the first automatic ingot", GameState.story_done.has("disp"), GameState.story_done)
	check("the dispatcher is met and pleased", GameState.bonds.get("dispatcher", 0) == 1, GameState.bonds)
	var storage: Vector2i = world.marker_cell("Storage")
	for i in 4:
		Sim.insert(storage, "ingot")
	GameState.day = 2
	DayCycle.hour = 6.5
	await wait(0.3)
	await _radio_through(radio)          # утренний звонок дня 2
	DayCycle.hour = 10.0
	await wait(0.3)
	check("pump dilemma is on air", radio.is_open() and GameState.story_done.has("pump"), GameState.story_done)
	for i in 3:                          # Айша просит, диспетчер вмешивается
		radio.press(-1)
		await wait(0.1)
	get_viewport().get_texture().get_image().save_png(shots + "/radio_choice.png")
	radio.press(0)                       # отдать 3 слитка
	await wait(0.1)
	check("helping costs 3 ingots from storage and is remembered", Sim.storage_count("ingot") == 1 and GameState.story_flags.has("pump"),
		[Sim.storage_count("ingot"), GameState.story_flags])
	check("helping the village pleases Aisha and angers the dispatcher",
		GameState.bonds["aisha"] == 3 and GameState.bonds["dispatcher"] == 0, GameState.bonds)
	await _radio_through(radio)
	var grain: int = GameState.pockets["grain"]
	GameState.day = 3
	DayCycle.hour = 6.5
	await wait(0.3)
	check("next morning the village thanks with grain", radio.is_open() and GameState.pockets["grain"] == grain + 8
		and not GameState.story_done.has("day3_bad"), [GameState.pockets, GameState.story_done])
	await _radio_through(radio)
	DayCycle.hour = 8.6
	await wait(0.3)
	await _radio_through(radio)          # диспетчер перед бурей: «Будет. Линия держит.»
	check("an honest promise wins the dispatcher back", GameState.bonds["dispatcher"] == 1, GameState.bonds)
	for x in range(40, 46):
		Sim.place_machine("conveyor", Vector2i(x, 11), Vector2i.RIGHT)
	DayCycle.hour = 11.0
	await wait(0.3)
	radio.press(-1)
	await wait(0.1)
	radio.press(1)                       # работать в бурю
	await wait(0.1)
	var belts := Sim.get_machines().filter(func(m): return m.get("type") == "conveyor").size()
	check("working through the storm tears 3 belts", belts == 3, belts)
	await _radio_through(radio)
	check("game runs again after the call", DayCycle.running and not player.frozen)
	main.get_node("UI/NightReport")._show(3)
	await wait(0.2)
	get_viewport().get_texture().get_image().save_png(shots + "/report_bonds.png")
	main.get_node("UI/NightReport").visible = false
	var ore: int = GameState.pockets["ore"]
	GameState.day = 4
	DayCycle.hour = 8.1
	await wait(0.3)
	await _radio_through(radio)          # утро дня 4, затем посылка от довольного диспетчера
	await wait(0.3)
	await _radio_through(radio)
	check("a pleased dispatcher sends ore, no audit", GameState.pockets["ore"] == ore + 8 and GameState.story_done.has("disp_gift")
		and not GameState.story_done.has("disp_audit"), [GameState.pockets, GameState.story_done])
	GameState.story_done.append("erzhan")
	GameState.day = 5
	DayCycle.hour = 6.5
	await wait(0.3)
	await _radio_through(radio)
	check("a trusted engineer gets help from the village on the last day", GameState.story_done.has("day5_help")
		and not GameState.story_done.has("day5"), GameState.story_done)
	DayCycle.hour = 9.0
	await wait(0.3)
	for i in 5:                          # приказ диспетчера и ответ Айши
		radio.press(-1)
		await wait(0.1)
	var third: Button = radio._buttons.get_child(2)
	check("splitting the orbit is open when both sides trust you", radio._buttons.get_child_count() == 3 and not third.disabled,
		[radio._buttons.get_child_count(), GameState.bonds])
	get_viewport().get_texture().get_image().save_png(shots + "/radio_orbit.png")
	radio.press(2)
	await wait(0.1)
	await _radio_through(radio)
	check("the orbit choice is remembered for the ending", GameState.story_flags.has("orbit_both")
		and main.get_node("UI/EndScreen")._epilogue() == ["END_EPILOGUE_BOTH"], GameState.story_flags)
	GameState.bonds["dispatcher"] = 0
	check("without trust the third answer is locked", not radio._can({"bonds": {"aisha": 2, "dispatcher": 1}}))
	main.get_node("UI/EndScreen").open(true)
	await wait(0.2)
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


## Дослушать рацию до конца, нажимая «дальше» (в выборе — первый вариант).
func _radio_through(radio: Radio) -> void:
	var guard := 0
	while radio.is_open() and guard < 40:
		radio.press(0)
		await wait(0.1)
		guard += 1


func _drag_belt(x0: int, x1: int) -> void:
	mouse_to_cell(Vector2i(x0, 11))
	await get_tree().process_frame
	var event := InputEventAction.new()
	event.action = Actions.PLACE
	event.pressed = true
	Input.parse_input_event(event)
	Input.action_press(Actions.PLACE)
	for x in range(x0 + 1, x1 + 1):
		await wait(0.1)
		mouse_to_cell(Vector2i(x, 11))
	await wait(0.1)
	Input.action_release(Actions.PLACE)


## Вступительный ролик (часть A): идёт, синхронизирован с голосом, пропускается и сообщает об окончании.
func _intro() -> void:
	var intro := Intro.new()
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	main.get_node("UI").add_child(intro)
	await wait(0.5)
	check("intro: 7 scenes, 25-70 s", intro._starts.size() == 7 and intro.length() > 25.0 and intro.length() < 70.0, intro.length())
	check("intro: every line has a voice clip", intro._voices.all(func(v: AudioStream) -> bool: return v != null))
	check("intro: each scene outlasts its voice line",
		range(7).all(func(i: int) -> bool: return intro._lengths[i] > intro._voices[i].get_length() + intro.VOICE_DELAY))
	check("intro: subtitle shown", intro._subtitle.text == tr("INTRO_1"), intro._subtitle.text)
	var screen := Rect2(Vector2.ZERO, intro.get_viewport_rect().size)
	check("intro: picture covers the whole screen", intro._view_box.get_global_rect().encloses(screen),
		[intro._view_box.get_global_rect(), screen])
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.6)
	check("intro: a single key press does not skip", not done[0] and is_instance_valid(intro))
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await wait(1.3)                          # держим Пробел дольше HoldSkip.HOLD
	space = space.duplicate()
	space.pressed = false
	Input.parse_input_event(space)
	await wait(2.8)
	check("intro: holding Space skips and emits finished", done[0])
	check("intro: removed after skip", not is_instance_valid(intro))
	check("intro: game music volume restored", Audio.music_volume > 0.0, Audio.music_volume)


## Три языка: английский перевод полный, у английского и русского свой голос, казахский слышит русский.
func _languages() -> void:
	var file := FileAccess.open(Loc.PATH, FileAccess.READ)
	var header := file.get_csv_line()
	var empty: Array[String] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1 and row[0] != "" and (row.size() < header.size() or row[header.size() - 1] == ""):
			empty.append(row[0])
	check("languages: csv has ru, kk, en", header == PackedStringArray(["keys", "ru", "kk", "en"]), header)
	check("languages: every key translated to English", empty.is_empty(), empty)
	check("languages: picker offers ru, kk, en", LanguagePicker.LOCALES.keys() == ["ru", "kk", "en"])
	check("languages: voice per locale", Intro.voice_language("en") == "en" and Intro.voice_language("ru") == "ru"
		and Intro.voice_language("kk") == "ru", [Intro.voice_language("en"), Intro.voice_language("kk")])
	TranslationServer.set_locale("en")
	var intro := Intro.new()
	main.get_node("UI").add_child(intro)
	await wait(0.3)
	check("languages: English intro has English voice and subtitles",
		intro._voices.all(func(v: AudioStream) -> bool: return v != null) and intro._subtitle.text.begins_with("The steppe"),
		intro._subtitle.text)
	check("languages: English intro 25-70 s", intro.length() > 25.0 and intro.length() < 70.0, intro.length())
	intro.skip()
	await wait(2.8)
	TranslationServer.set_locale("ru")


## «Как играть»: окно влезает в экран, текст прокручивается, Esc закрывает.
func _info_page() -> void:
	var page: Control = main.get_node("UI/InfoPage")
	page.open("howto")
	await wait(0.6)
	var screen := Rect2(Vector2.ZERO, page.get_viewport_rect().size)
	check("info page: window fits the screen", screen.encloses(page._panel.get_global_rect()), [page._panel.get_global_rect(), screen])
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(0.5)
	check("info page: Esc closes it", not page.visible and not get_tree().paused)
	page.open("credits")
	await wait(0.4)
	check("credits: team name", tr("CREDITS_TEAM").contains("Hack Larp"))
	page.close()
	await wait(0.4)
	check("credits: closes with the button", not page.visible)

# Главная сцена: собирает мир, игрока, отрисовку и интерфейс, связывает их сигналами, ведёт ход партии. Владелец: B.
extends Node2D

const LAUNCH_CAMERA_TIME := 1.0
const LAUNCH_CAMERA_RISE := 60.0
const INTRO_FADE := 0.6          # меню уходит в темноту перед роликом

static var skip_menu := false    # после «Начать сначала» меню не показываем

var _won := false

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var world_view: Node2D = $WorldView
@onready var machine_view: Node2D = $MachineView
@onready var rocket: Node2D = $Rocket
@onready var drone: Node2D = $Drone
@onready var tool_user: Node = $Player/ToolUser
@onready var interactor: Node = $Player/Interactor
@onready var build: Node2D = $Player/Build
@onready var menu: Control = $UI/MainMenu
@onready var pause_menu: Control = $UI/PauseMenu
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var info_page: Control = $UI/InfoPage


func _enter_tree() -> void:
	Actions.ensure()
	Loc.setup(Settings.get_value("locale"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	Settings.apply()
	world_view.world = world
	$CropView.world = world
	tool_user.world = world
	tool_user.build = build
	tool_user.progress.connect(world_view.show_progress)
	tool_user.stopped.connect(world_view.hide_progress)
	tool_user.dug.connect(world_view.show_dug)
	tool_user.campfire_blown.connect(machine_view.light_campfire)
	interactor.demolish_progress.connect(machine_view.show_demolish)
	interactor.demolish_stopped.connect(machine_view.clear_demolish)
	$UI/Hotbar.setup(build)
	$UI/Messages.setup(build)
	$UI/HUD.pause_pressed.connect(pause_menu.toggle)
	_connect_menus()
	GameState.game_over.connect(func(won: bool) -> void: _won = won)
	DayCycle.phase_changed.connect(_on_phase)
	DayCycle.day_started.connect(func(_day: int) -> void: _wake_up())
	DayCycle.day_started.connect(func(_day: int) -> void: Audio.start_music())
	DayCycle.evening.connect(func() -> void: Audio.play("drone"))
	world.start_new()
	$CropView.refresh()
	rocket.position = world.marker_pos("Rocket") + Vector2(TileCatalog.TILE, TileCatalog.TILE) * 0.5
	drone.hover_point = MachineCatalog.center("storage", world.marker_cell("Storage")) - Vector2(0, drone.HOVER_ABOVE)
	player.limit_camera(world.world_rect())
	$Juice.setup(player, world, machine_view, tool_user)
	$Decor.setup(world)
	$Lights.setup(player, world)
	$Darkness.setup(player, machine_view)
	var moment := Moment.new()
	moment.name = "Moment"
	$UI.add_child(moment)
	$UI.move_child(moment, $UI/PauseMenu.get_index())   # над HUD и подсказками, под паузой и меню
	moment.setup(player, world)
	var guide := GuideBook.new()
	guide.name = "GuideBook"
	$UI.add_child(guide)
	$UI.move_child(guide, $UI/PauseMenu.get_index())
	$UI/HUD.guide_pressed.connect(guide.toggle)
	var radio := Radio.new()
	radio.name = "Radio"
	$UI.add_child(radio)
	$UI.move_child(radio, $UI/PauseMenu.get_index())
	radio.setup(player, moment)
	_wake_up()
	GameState.emit_quota()
	DayCycle.reset()
	player.frozen = true
	if skip_menu:
		_start_playing()
	elif not Settings.get_value("locale_chosen"):
		_pick_language()
	else:
		menu.open()


func _connect_menus() -> void:
	menu.new_game_pressed.connect(_on_new_game)
	menu.intro_pressed.connect(_play_intro.bind(menu.open))
	menu.settings_pressed.connect(func() -> void: _open_settings(true))
	menu.page_pressed.connect(info_page.open)
	pause_menu.settings_pressed.connect(func() -> void: _open_settings(false))
	pause_menu.page_pressed.connect(info_page.open)
	pause_menu.restart_pressed.connect(restart.bind(false))
	pause_menu.menu_pressed.connect(restart.bind(true))
	settings_panel.locale_changed.connect(restart.bind(true))
	$UI/EndScreen.restart_pressed.connect(restart.bind(false))


## Самый первый запуск: выбор языка, потом меню на этом языке.
func _pick_language() -> void:
	var picker := LanguagePicker.new()
	picker.chosen.connect(func(code: String) -> void:
		Settings.set_value("locale", code)
		Settings.set_value("locale_chosen", true)
		restart(true))
	$UI.add_child(picker)


func _open_settings(allow_locale: bool) -> void:
	settings_panel.allow_locale = allow_locale
	settings_panel.open()


## «Новая игра»: всегда сначала вступительный ролик (пропуск удержанием Пробела), потом игра и звонок по рации.
func _on_new_game() -> void:
	_play_intro(_start_playing)


## Показать ролик поверх мира; after вызывается, когда экран уже тёмный.
func _play_intro(after: Callable) -> void:
	# Меню плавно уходит в темноту вместе с музыкой, ролик начинается из той же темноты.
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	$UI.add_child(black)
	get_tree().create_tween().tween_property(Audio, "music_volume", 0.0, INTRO_FADE)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, INTRO_FADE).set_trans(Tween.TRANS_SINE)
	await tween.finished
	menu.visible = false
	var intro: Control = Intro.new()
	intro.finished.connect(func() -> void:
		Settings.set_value("intro_seen", true)
		after.call())
	$UI.add_child(intro)
	# Убираем шторку не сразу: в первом кадре ролик ещё не нарисован, и сквозь него мелькнул бы HUD.
	get_tree().create_timer(0.2).timeout.connect(black.queue_free)


func _start_playing() -> void:
	if GameState.day == 1 and DayCycle.hour <= 6.5:
		GameState.notify.call_deferred("NOTICE_GUIDE")    # где искать подсказки, если что-то непонятно
	menu.visible = false
	player.frozen = false
	DayCycle.running = true
	$UI/Tutorial.setup(player, world)
	Audio.start_music()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.SLEEP) and DayCycle.can_sleep():
		DayCycle.sleep()


## Начать партию заново; to_menu — вернуться в главное меню.
func restart(to_menu: bool) -> void:
	skip_menu = not to_menu
	get_tree().paused = false
	DayCycle.running = false
	GameState.new_game()
	get_tree().reload_current_scene()


func _on_phase(phase: int) -> void:
	player.frozen = phase in [DayCycle.Phase.NIGHT, DayCycle.Phase.REPORT, DayCycle.Phase.OVER]
	if phase == DayCycle.Phase.OVER:
		if _won:
			await _play_launch()
		$UI/EndScreen.open(_won)


## Победа: камера переезжает к площадке, ракета взлетает.
func _play_launch() -> void:
	# Смещение камеры не знает о границах мира, поэтому центр кадра ограничиваем сами.
	var camera: Camera2D = player.camera
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var bounds: Rect2 = world.world_rect()
	var center: Vector2 = (rocket.global_position - Vector2(0, LAUNCH_CAMERA_RISE)).clamp(bounds.position + half, bounds.end - half)
	var look: Vector2 = center - camera.get_screen_center_position()
	await create_tween().tween_property(camera, "offset", look, LAUNCH_CAMERA_TIME).finished
	await rocket.launch()


## Утро: игрок просыпается у дома, где бы ни уснул.
func _wake_up() -> void:
	player.global_position = world.marker_pos("Spawn") + Vector2(0, TileCatalog.TILE * 0.5 - player.HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	player.camera.snap()

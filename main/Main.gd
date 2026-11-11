# Главная сцена: собирает мир, игрока, отрисовку и интерфейс, связывает их сигналами, ведёт ход партии. Владелец: B.
extends Node2D

const LAUNCH_CAMERA_TIME := 1.0
const LAUNCH_CAMERA_RISE := 60.0

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
	tool_user.harvested.connect(world_view.show_harvest)
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
	_wake_up()
	GameState.emit_quota()
	DayCycle.reset()
	player.frozen = true
	if skip_menu:
		_start_playing()
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


func _open_settings(allow_locale: bool) -> void:
	settings_panel.allow_locale = allow_locale
	settings_panel.open()


## «Новая игра»: в первый раз сначала вступительный ролик, потом игра.
func _on_new_game() -> void:
	if Settings.get_value("intro_seen"):
		_start_playing()
	else:
		_play_intro(_start_playing)


## Показать ролик поверх мира; after вызывается, когда экран уже тёмный.
func _play_intro(after: Callable) -> void:
	menu.visible = false
	var intro: Control = Intro.new()
	intro.finished.connect(func() -> void:
		Settings.set_value("intro_seen", true)
		after.call())
	$UI.add_child(intro)


func _start_playing() -> void:
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
	player.camera.reset_smoothing()

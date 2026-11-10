# Главная сцена: собирает мир, игрока, отрисовку и интерфейс, связывает их сигналами. Владелец: B.
extends Node2D

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var world_view: Node2D = $WorldView
@onready var machine_view: Node2D = $MachineView
@onready var drone: Node2D = $Drone
@onready var tool_user: Node = $Player/ToolUser
@onready var interactor: Node = $Player/Interactor
@onready var build: Node2D = $Player/Build


func _enter_tree() -> void:
	Actions.ensure()
	Loc.setup()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	world_view.world = world
	tool_user.world = world
	tool_user.build = build
	tool_user.dig_progress.connect(world_view.show_dig)
	tool_user.dig_stopped.connect(world_view.hide_dig)
	tool_user.dug.connect(func(cell: Vector2i, ore: bool) -> void: world_view.show_dug(cell, ore, _dug_kind))
	tool_user.dig_progress.connect(func(cell: Vector2i, _r: float) -> void: _dug_kind = world.kind_at(cell))
	tool_user.campfire_blown.connect(machine_view.light_campfire)
	interactor.demolish_progress.connect(machine_view.show_demolish)
	interactor.demolish_stopped.connect(machine_view.clear_demolish)
	$UI/Hotbar.setup(build)
	$UI/Messages.setup(build)
	$UI/HUD.pause_pressed.connect($UI/PauseMenu.toggle)
	$UI/PauseMenu.restart_pressed.connect(restart)
	$UI/EndScreen.restart_pressed.connect(restart)
	DayCycle.phase_changed.connect(_on_phase)
	DayCycle.day_started.connect(func(_day: int) -> void: _wake_up())
	world.start_new()
	$Rocket.position = world.marker_pos("Rocket") + Vector2(TileCatalog.TILE, TileCatalog.TILE) * 0.5
	drone.hover_point = MachineCatalog.center("storage", world.marker_cell("Storage")) - Vector2(0, drone.HOVER_ABOVE)
	player.limit_camera(world.world_rect())
	_wake_up()
	GameState.emit_quota()
	DayCycle.reset()
	DayCycle.running = true


var _dug_kind := "soil"   # вид тайла, который сейчас копают (к моменту сигнала dug клетка уже пустая)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.SLEEP) and DayCycle.can_sleep():
		DayCycle.sleep()


func restart() -> void:
	get_tree().paused = false
	DayCycle.running = false
	GameState.new_game()
	get_tree().reload_current_scene()


func _on_phase(phase: int) -> void:
	player.frozen = phase in [DayCycle.Phase.NIGHT, DayCycle.Phase.REPORT, DayCycle.Phase.OVER]


## Утро: игрок просыпается у дома, где бы ни уснул.
func _wake_up() -> void:
	player.global_position = world.marker_pos("Spawn") + Vector2(0, TileCatalog.TILE * 0.5 - player.HALF_HEIGHT)
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()

# Игрок: ходьба, прыжок, лестницы, камера, анимация. Инструменты и постройка — в соседних скриптах. Владелец: B.
extends CharacterBody2D

const HALF_HEIGHT := 10.0   # половина высоты фигуры столкновений (Shape в Player.tscn)
const PERCH_LIFT := 0.5
const FRAMES := {"idle": [0, 1], "walk": [2, 3, 4, 5], "jump": [6], "climb": [7, 8]}

var frozen := false          # игрок спит или идёт заставка
var climbing := false
var facing := 1
var working := false         # держит инструмент в деле (ставит ToolUser)

var _cfg: Dictionary = {}
var _ladders := {}           # клетка -> true
var _coyote := 0.0
var _jump_buffer := 0.0
var _anim_time := 0.0
var _jump_speed := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var tool_sprite: Sprite2D = $Tool
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	_cfg = GameConfig.player()
	_jump_speed = sqrt(2.0 * float(_cfg["gravity"]) * float(_cfg["jump_height_px"]))
	Sim.machine_placed.connect(_on_machine_placed)
	Sim.machine_removed.connect(func(cell: Vector2i) -> void: _ladders.erase(cell))


func limit_camera(world: Rect2) -> void:
	camera.set_bounds(world)


func in_reach(point: Vector2, tiles: float = -1.0) -> bool:
	var reach := tiles if tiles > 0.0 else float(_cfg["reach_tiles"])
	return global_position.distance_to(point) <= reach * TileCatalog.TILE


func feet_y() -> float:
	return global_position.y + HALF_HEIGHT


## Показать инструмент в руке (иконка — номер кадра в icons.png) или убрать его.
func set_working(active: bool, target: Vector2 = Vector2.ZERO, icon: int = 0) -> void:
	working = active
	tool_sprite.visible = active
	if active:
		facing = 1 if target.x >= global_position.x else -1
		(tool_sprite.texture as AtlasTexture).region.position.x = icon * 16.0


func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		_animate(delta, true)
		return
	var side := Input.get_axis(Actions.LEFT, Actions.RIGHT)
	var up := Input.is_action_pressed(Actions.UP)
	var down := Input.is_action_pressed(Actions.DOWN)
	if Input.is_action_just_pressed(Actions.JUMP):
		_jump_buffer = float(_cfg["jump_buffer"])
	var on_ladder := _ladder_at(global_position) or _ladder_at(Vector2(global_position.x, feet_y() - 1.0))
	var perch := _perch_top(delta)
	if climbing and not on_ladder:
		climbing = false
	elif not climbing and on_ladder and (up or down):
		climbing = true
	elif not climbing and not is_nan(perch) and down:
		climbing = true          # с верхушки лестницы вниз
		perch = NAN
		global_position.y += 2.0
	var supported := is_on_floor() or climbing
	if climbing:
		velocity.y = Input.get_axis(Actions.UP, Actions.DOWN) * float(_cfg["climb_speed"])
		side *= float(_cfg["ladder_side_factor"])
	elif not is_nan(perch) and velocity.y >= 0.0:
		# Верх лестницы держит как пол. Стоим на волосок выше земли, чтобы не цепляться за край соседнего тайла.
		global_position.y = perch - HALF_HEIGHT - PERCH_LIFT
		velocity.y = 0.0
		supported = true
	else:
		velocity.y = minf(velocity.y + float(_cfg["gravity"]) * delta, float(_cfg["max_fall_speed"]))
	_coyote = float(_cfg["coyote_time"]) if supported else maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_speed
		climbing = false
		_jump_buffer = 0.0
		_coyote = 0.0
	velocity.x = side * float(_cfg["walk_speed"])
	if side != 0.0 and not working:
		facing = 1 if side > 0.0 else -1
	move_and_slide()
	_animate(delta, supported)


func _ladder_at(point: Vector2) -> bool:
	return _ladders.has(TileCatalog.cell_at(point))


## Y верхнего края лестницы прямо под ногами (на неё можно встать) или NAN.
func _perch_top(delta: float) -> float:
	var feet := feet_y()
	var probe := Vector2(global_position.x, feet + maxf(velocity.y * delta, 1.0))
	var cell := TileCatalog.cell_at(probe)
	if not _ladders.has(cell) or _ladders.has(cell + Vector2i.UP):
		return NAN
	var top := float(cell.y * TileCatalog.TILE)
	return top if feet <= top + 2.0 else NAN


func _on_machine_placed(cell: Vector2i, type: String, _dir: Vector2i) -> void:
	if type == "ladder":
		_ladders[cell] = true


func _animate(delta: float, supported: bool) -> void:
	var anim := "idle"
	if climbing:
		anim = "climb"
	elif not supported:
		anim = "jump"
	elif absf(velocity.x) > 1.0:
		anim = "walk"
	var moving := anim != "climb" or velocity.length() > 1.0
	if moving:
		_anim_time += delta * float(_cfg["anim_fps"].get(anim, 1.0))
	var frames: Array = FRAMES[anim]
	sprite.frame = frames[int(_anim_time) % frames.size()]
	sprite.flip_h = facing < 0 and anim != "climb"
	if tool_sprite.visible:
		tool_sprite.scale.x = facing
		tool_sprite.position.x = 4.0 * facing
		tool_sprite.rotation = (0.2 + 0.7 * absf(sin(Time.get_ticks_msec() * 0.012))) * facing

# Обновляет тайлы по сигналам симуляции и показывает копание: трещины и крошки. Владелец: B.
extends Node2D

const CRACK_FRAMES := 3
const DEBRIS_COUNT := 6
const BAR_SIZE := Vector2(12, 2)
const BAR_OFFSET := Vector2(-6, -12)
const DEBRIS_COLOR := {"soil": Color("8a5c3e"), "stone": Color("737885"), "deep": Color("3d4a75"), "ore": Color("e07b24")}

var world: Node2D     # WorldLoader, задаёт Main

var _cracks: Sprite2D
var _dug_kind := "soil"   # вид тайла, который копают (к моменту сигнала dug клетка уже пустая)
var _bar_ratio := -1.0
var _bar_pos := Vector2.ZERO


func _ready() -> void:
	z_index = 3
	_cracks = Sprite2D.new()
	_cracks.texture = Sprites.tex("cracks")
	_cracks.hframes = CRACK_FRAMES
	_cracks.visible = false
	add_child(_cracks)
	Sim.tile_changed.connect(func(cell: Vector2i, kind: int) -> void: world.apply_tile(cell, kind))


## Ход действия с удержанием: трещины для копания, полоска для остального.
func show_progress(cell: Vector2i, ratio: float, action: String) -> void:
	_cracks.visible = action == "dig"
	_bar_ratio = -1.0 if action == "dig" else ratio
	_bar_pos = TileCatalog.cell_center(cell) + BAR_OFFSET
	if action == "dig":
		_dug_kind = world.kind_at(cell)
		_cracks.position = TileCatalog.cell_center(cell)
		_cracks.frame = mini(int(ratio * CRACK_FRAMES), CRACK_FRAMES - 1)
	queue_redraw()


func hide_progress() -> void:
	_cracks.visible = false
	_bar_ratio = -1.0
	queue_redraw()


func _draw() -> void:
	if _bar_ratio < 0.0:
		return
	draw_rect(Rect2(_bar_pos - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color("1a1423"))
	draw_rect(Rect2(_bar_pos, Vector2(BAR_SIZE.x * _bar_ratio, BAR_SIZE.y)), Color("f4d34f"))


## Тайл выкопан или добыта руда: крошки. «+1» и полёт предмета в карман показывает Juice.
func show_dug(cell: Vector2i, got_ore: bool) -> void:
	_debris(TileCatalog.cell_center(cell), DEBRIS_COLOR.get("ore" if got_ore else _dug_kind, DEBRIS_COLOR["soil"]))


func _debris(pos: Vector2, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.amount = DEBRIS_COUNT
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.45
	particles.direction = Vector2.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.emitting = true
	add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

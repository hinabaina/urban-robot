# Грузовой дрон: в 18:00 спускается к складу, лучом забирает слитки и улетает. Ход задаёт DayCycle.drone_t. Владелец: B.
extends Node2D

const HOVER_ABOVE := 34.0                 # высота зависания над центром склада
const ENTER_FROM := Vector2(260, -230)    # откуда прилетает, относительно точки зависания
const LEAVE_TO := Vector2(-80, -260)
const ARRIVE := 0.35                      # доли визита: прилёт, погрузка, улёт
const DEPART := 0.65
const ROTOR_FPS := 14.0
const BEAM_COLOR := Color(1.0, 0.9, 0.5, 0.35)

var hover_point := Vector2.ZERO           # задаёт Main: точка над складом

var _sprite := Sprite2D.new()


func _ready() -> void:
	z_index = 6
	_sprite.texture = Sprites.tex("drone")
	_sprite.hframes = 2
	add_child(_sprite)
	visible = false


func _process(_delta: float) -> void:
	visible = DayCycle.phase == DayCycle.Phase.DRONE
	if not visible:
		return
	var t := DayCycle.drone_t
	var offset := Vector2.ZERO
	if t < ARRIVE:
		offset = ENTER_FROM * (1.0 - ease(t / ARRIVE, 0.4))
	elif t > DEPART:
		offset = LEAVE_TO * ease((t - DEPART) / (1.0 - DEPART), 2.5)
	_sprite.position = hover_point + offset + Vector2(0, sin(Time.get_ticks_msec() * 0.006) * 1.5)
	_sprite.frame = int(Time.get_ticks_msec() * 0.001 * ROTOR_FPS) % 2
	queue_redraw()


func _draw() -> void:
	var t := DayCycle.drone_t
	if t < ARRIVE or t > DEPART:
		return
	var from := _sprite.position + Vector2(0, 7)
	var to := hover_point + Vector2(0, HOVER_ABOVE)
	draw_colored_polygon(PackedVector2Array([from + Vector2(-3, 0), from + Vector2(3, 0),
		to + Vector2(14, 0), to + Vector2(-14, 0)]), BEAM_COLOR)

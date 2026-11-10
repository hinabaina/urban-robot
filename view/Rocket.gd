# Ракета на площадке: силуэт цели и части, которые добавляются после каждой сдачи дрону. Владелец: B.
extends Node2D

const GHOST_ALPHA := 0.16
const DROP_HEIGHT := 40.0
const DROP_TIME := 0.5
const PATCH_OFFSET := Vector2(-5, 6)
const LAUNCH_TIME := 5.5
const LAUNCH_HEIGHT := 620.0
const SHAKE_PIXELS := 1.0

var _parts: Array = []      # имена частей снизу вверх, из days.json
var _built := 0


func _ready() -> void:
	z_index = -4
	for day in GameConfig.days()["days"]:
		_parts.append(day["rocket_part"])
	GameState.day_settled.connect(func(_result: Dictionary) -> void: _sync(true))
	_sync(false)


## Привести картинку к GameState.rocket (после загрузки или новой игры — без анимации).
func _sync(animate: bool) -> void:
	if GameState.rocket.size() < _built:
		for child in get_children():
			child.queue_free()
		_built = 0
	while _built < GameState.rocket.size():
		_add_part(_built, GameState.rocket[_built]["patched"], animate)
		_built += 1
	queue_redraw()


func _part_y(index: int) -> float:
	var y := 0.0
	for i in index + 1:
		y -= Sprites.tex("rocket_" + _parts[i]).get_height()
	return y


func _add_part(index: int, patched: bool, animate: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = Sprites.tex("rocket_" + _parts[index])
	sprite.centered = false
	sprite.position = Vector2(-sprite.texture.get_width() * 0.5, _part_y(index))
	add_child(sprite)
	if patched:
		var patch := Sprite2D.new()
		patch.texture = Sprites.tex("rocket_patch")
		patch.position = sprite.texture.get_size() * 0.5 + PATCH_OFFSET
		sprite.add_child(patch)
	if animate:
		var target := sprite.position.y
		sprite.position.y -= DROP_HEIGHT
		sprite.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(sprite, "position:y", target, DROP_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate:a", 1.0, DROP_TIME * 0.5)


func _draw() -> void:
	for i in range(_built, _parts.size()):   # ещё не построенное — полупрозрачным силуэтом
		var tex := Sprites.tex("rocket_" + _parts[i])
		draw_texture(tex, Vector2(-tex.get_width() * 0.5, _part_y(i)), Color(1, 1, 1, GHOST_ALPHA))


## Заставка победы: дым, тряска, ракета уходит вверх. Корутина — ждать через await.
func launch() -> void:
	Audio.play("rocket")
	var flame := CPUParticles2D.new()
	flame.position = Vector2(0, -Sprites.tex("rocket_" + _parts[0]).get_height())
	flame.amount = 60
	flame.lifetime = 0.9
	flame.direction = Vector2.DOWN
	flame.spread = 28.0
	flame.initial_velocity_min = 40.0
	flame.initial_velocity_max = 110.0
	flame.gravity = Vector2(0, -30)
	flame.scale_amount_min = 2.0
	flame.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color("fff3a8"), Color("e07b24"), Color(0.6, 0.6, 0.65, 0.0)])
	flame.color_ramp = ramp
	add_child(flame)
	var start := position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var shake := Vector2(randf_range(-1, 1), 0) * SHAKE_PIXELS
		position = start + shake - Vector2(0, LAUNCH_HEIGHT * t * t * t), 0.0, 1.0, LAUNCH_TIME)
	await tween.finished

# Ракета на площадке: силуэт цели и части, которые добавляются после каждой сдачи дрону. Владелец: B.
extends Node2D

const GHOST_ALPHA := 0.16
const DROP_HEIGHT := 40.0
const DROP_TIME := 0.5
const PATCH_OFFSET := Vector2(-5, 6)

var _parts: Array = []      # имена частей снизу вверх, из days.json
var _built := 0


func _ready() -> void:
	z_index = -4
	for day in GameState.config["days"]:
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

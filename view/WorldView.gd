# Обновляет тайлы по сигналам симуляции и показывает копание: трещины, крошки, «+1». Владелец: B.
extends Node2D

const CRACK_FRAMES := 3
const POPUP_RISE := 14.0
const POPUP_TIME := 0.7
const DEBRIS_COUNT := 6
const DEBRIS_COLOR := {"soil": Color("8a5c3e"), "stone": Color("737885"), "deep": Color("3d4a75"), "ore": Color("e07b24")}

var world: Node2D     # WorldLoader, задаёт Main

var _cracks: Sprite2D


func _ready() -> void:
	z_index = 3
	_cracks = Sprite2D.new()
	_cracks.texture = Sprites.tex("cracks")
	_cracks.hframes = CRACK_FRAMES
	_cracks.visible = false
	add_child(_cracks)
	Sim.tile_changed.connect(func(cell: Vector2i, kind: int) -> void: world.apply_tile(cell, kind))


func show_dig(cell: Vector2i, ratio: float) -> void:
	_cracks.visible = true
	_cracks.position = TileCatalog.cell_center(cell)
	_cracks.frame = mini(int(ratio * CRACK_FRAMES), CRACK_FRAMES - 1)


func hide_dig() -> void:
	_cracks.visible = false


## Тайл выкопан или добыта руда: крошки и всплывающая иконка.
func show_dug(cell: Vector2i, got_ore: bool, kind: String) -> void:
	var pos := TileCatalog.cell_center(cell)
	_debris(pos, DEBRIS_COLOR.get("ore" if got_ore else kind, DEBRIS_COLOR["soil"]))
	if got_ore:
		popup_item(pos, "ore")


func popup_item(pos: Vector2, type: String) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = Sprites.item(type)
	sprite.position = pos
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", pos.y - POPUP_RISE, POPUP_TIME).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, POPUP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(sprite.queue_free)


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

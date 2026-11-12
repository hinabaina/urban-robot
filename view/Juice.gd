# Отдача на каждое действие: всплывающие «+1», предметы летят в карман, искры, пыль, лёгкая тряска камеры,
# посылка на парашюте. Только картинка: состояние игры здесь не меняется. Владелец: A.
extends Node2D

const TEXT_RISE := 20.0
const TEXT_TIME := 0.9
const FLY_TIME := 0.32
const FLY_ARC := 14.0
const CHIP_EVERY := 0.14          # крошки из-под кирки, пока копаем
const SHAKE_FADE := 10.0          # затухание тряски, px/с
const SHAKE_MAX := 3.0
const LAND_SPEED := 150.0         # с какой скорости падения приземление поднимает пыль
const STEP_EVERY := 0.22
const CRATE_FROM := Vector2(40, -170)
const CRATE_TIME := 1.3
const OUTLINE := Color("1a1423")
const DUST := Color("cdbb9c")
const SPARK := Color("ffd166")
const WATER := Color("7cc4f2")
const ITEM_COLOR := {"ore": Color("ffab45"), "grain": Color("f4d34f"), "ingot": Color("e6edf7")}
const CHIP_COLOR := {"soil": Color("8a5c3e"), "stone": Color("9096a3"), "deep": Color("5b6aa0"), "ore": Color("ffab45")}

var _player: CharacterBody2D
var _world: Node2D
var _machines: Node2D
var _shake := 0.0
var _chip_timer := 0.0
var _step_timer := 0.0
var _was_floor := true
var _fall_speed := 0.0
var _delivered := 0               # слитки, пришедшие на склад за этот кадр


## Посылка дрона: ящик на парашюте.
class Crate extends Node2D:
	var chute := true

	func _draw() -> void:
		if chute:
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -15), Vector2(-7, -20), Vector2(0, -22),
				Vector2(7, -20), Vector2(10, -15)]), Color("f0705a"))
			draw_rect(Rect2(-3, -22, 6, 7), Color("f3ead2"))
			draw_line(Vector2(-10, -15), Vector2(-4, -4), Color("f3ead2"), 1.0)
			draw_line(Vector2(10, -15), Vector2(4, -4), Color("f3ead2"), 1.0)
		draw_rect(Rect2(-6, -5, 12, 10), Color("5a3a22"))
		draw_rect(Rect2(-5, -4, 10, 8), Color("b07a45"))
		draw_rect(Rect2(-5, -1, 10, 2), Color("7a5230"))
		draw_rect(Rect2(-1, -4, 2, 8), Color("ffab45"))


func _ready() -> void:
	z_index = 8


## Main зовёт после загрузки карты: постройки, стоящие с самого начала, пыль не поднимают.
func setup(player: CharacterBody2D, world: Node2D, machines: Node2D, tool_user: Node) -> void:
	_player = player
	_world = world
	_machines = machines
	tool_user.progress.connect(_on_progress)
	tool_user.dug.connect(_on_dug)
	tool_user.harvested.connect(_on_harvested)
	tool_user.watered.connect(func(plot: Vector2i) -> void:
		burst(TileCatalog.cell_center(plot) - Vector2(0, 6), WATER, 8, 55.0, 50.0))
	Sim.item_delivered.connect(func(type: String, _by_hand: bool) -> void: _delivered += 1 if type == "ingot" else 0)
	Sim.machine_placed.connect(_on_placed)
	Sim.machine_removed.connect(func(cell: Vector2i) -> void: burst(TileCatalog.cell_center(cell), DUST, 8, 50.0, 180.0))
	GameState.happened.connect(_on_happened)
	GameState.gift_arrived.connect(func(_gift: Dictionary) -> void: _drop_crate())


func _process(delta: float) -> void:
	_chip_timer = maxf(0.0, _chip_timer - delta)
	if _delivered > 0:
		_show_delivery(_delivered)
		_delivered = 0
	if _player == null:
		return
	_feet(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - SHAKE_FADE * delta)
		_player.camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.0 else Vector2.ZERO


## Короткая тряска камеры; strength — размах в пикселях мира.
func shake(strength: float) -> void:
	if _player and not _player.frozen:
		_shake = minf(maxf(_shake, strength), SHAKE_MAX)


## Разовый выброс частиц: пыль, искры, брызги.
func burst(pos: Vector2, color: Color, amount: int, speed: float, spread: float, gravity: float = 260.0,
		lifetime: float = 0.5) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = lifetime
	particles.direction = Vector2.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, gravity)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	particles.emitting = true
	add_child(particles)
	get_tree().create_timer(lifetime + 0.6).timeout.connect(particles.queue_free)


## Всплывающая надпись («+1») с картинкой предмета: выскакивает, поднимается и тает.
func float_text(pos: Vector2, text: String, type: String = "", color: Color = Color.WHITE) -> void:
	var root := Node2D.new()
	root.position = pos.round()
	add_child(root)
	var font := UiKit.title_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var left := -(width + (Sprites.ITEM_SIZE + 2 if type != "" else 0)) * 0.5
	if type != "":
		var sprite := Sprite2D.new()
		sprite.texture = Sprites.item(type)
		sprite.position = Vector2(left + Sprites.ITEM_SIZE * 0.5, 0)
		root.add_child(sprite)
		left += Sprites.ITEM_SIZE + 2
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", ITEM_COLOR.get(type, color))
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(left, -5)
	root.add_child(label)
	root.scale = Vector2.ONE * 0.5
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector2.ONE * 1.25, 0.08)
	tween.tween_property(root, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(root, "position:y", root.position.y - TEXT_RISE, TEXT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(root, "modulate:a", 0.0, TEXT_TIME * 0.4).set_delay(TEXT_TIME * 0.6)
	tween.tween_callback(root.queue_free)


## Предмет дугой летит к игроку: видно, что он попал в карман.
func fly_to_player(from: Vector2, type: String) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = Sprites.item(type)
	sprite.position = from
	add_child(sprite)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		sprite.position = from.lerp(_player.global_position, t) - Vector2(0, sin(t * PI) * FLY_ARC), 0.0, 1.0, FLY_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(sprite.queue_free)


func _on_progress(cell: Vector2i, _ratio: float, action: String) -> void:
	if _chip_timer > 0.0:
		return
	_chip_timer = CHIP_EVERY
	var pos := TileCatalog.cell_center(cell)
	match action:
		"dig":
			burst(pos, CHIP_COLOR.get(_world.kind_at(cell), CHIP_COLOR["soil"]), 2, 60.0, 80.0, 300.0, 0.35)
		"campfire":
			burst(pos - Vector2(0, 2), SPARK, 2, 45.0, 35.0, -40.0, 0.6)
		"water", "fill":
			burst(pos - Vector2(0, 4), WATER, 2, 40.0, 40.0, 300.0, 0.35)
		"harvest":
			burst(pos - Vector2(0, 8), ITEM_COLOR["grain"], 1, 40.0, 60.0, 200.0, 0.4)


func _on_dug(cell: Vector2i, got_ore: bool) -> void:
	var pos := TileCatalog.cell_center(cell)
	shake(1.6 if got_ore else 0.8)
	if got_ore:
		burst(pos, SPARK, 6, 80.0, 180.0, 200.0, 0.4)
		float_text(pos - Vector2(0, 6), "+1", "ore")
		fly_to_player(pos, "ore")


func _on_harvested(plot: Vector2i, count: int) -> void:
	var pos := TileCatalog.cell_center(plot + Vector2i.UP)
	burst(pos, ITEM_COLOR["grain"], 8, 70.0, 70.0)
	float_text(pos - Vector2(0, 6), "+%d" % count, "grain")
	fly_to_player(pos, "grain")


func _on_happened(event: String) -> void:
	if event == "campfire_ingot":
		var pos := TileCatalog.cell_center(_world.marker_cell("Campfire"))
		burst(pos, SPARK, 14, 90.0, 60.0, 120.0, 0.6)
		float_text(pos - Vector2(0, 10), "+1", "ingot")
		fly_to_player(pos, "ingot")
		shake(1.2)


func _show_delivery(count: int) -> void:
	var cell: Vector2i = _world.marker_cell("Storage")
	var pos := MachineCatalog.center("storage", cell)
	float_text(pos - Vector2(0, 22), "+%d" % count, "ingot")
	burst(pos - Vector2(0, 12), ITEM_COLOR["ingot"], 6, 70.0, 60.0, 220.0, 0.45)
	_machines.bump(cell)


func _on_placed(cell: Vector2i, type: String, _dir: Vector2i) -> void:
	var size := MachineCatalog.size(type)
	var big := size.x > 1
	var base := MachineCatalog.center(type, cell) + Vector2(0, size.y * TileCatalog.TILE * 0.5 - 1.0)
	burst(base, DUST, 12 if big else 5, 70.0 if big else 40.0, 85.0, 120.0, 0.45)
	if big:
		shake(1.5)


func _drop_crate() -> void:
	var crate := Crate.new()
	var target := Vector2(_player.global_position.x + 20.0 * _player.facing, _player.feet_y() - 5.0)
	crate.position = target + CRATE_FROM
	add_child(crate)
	var tween := create_tween()
	tween.tween_property(crate, "position", target, CRATE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_method(func(t: float) -> void: crate.rotation = sin(t * 9.0) * 0.18 * (1.0 - t), 0.0, 1.0, CRATE_TIME)
	tween.tween_callback(func() -> void:
		crate.chute = false
		crate.queue_redraw()
		burst(target, DUST, 14, 80.0, 85.0, 120.0, 0.5)
		burst(target, SPARK, 16, 120.0, 70.0, 160.0, 0.7)
		shake(2.2))
	tween.tween_property(crate, "scale", Vector2(1.3, 0.7), 0.07)
	tween.tween_property(crate, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(2.0)
	tween.tween_property(crate, "modulate:a", 0.0, 0.5)
	tween.tween_callback(crate.queue_free)


## Пыль из-под ног: при приземлении и на ходу.
func _feet(delta: float) -> void:
	var on_floor := _player.is_on_floor()
	var feet := Vector2(_player.global_position.x, _player.feet_y())
	if on_floor and not _was_floor and _fall_speed > LAND_SPEED:
		burst(feet, DUST, 6, 45.0, 80.0, 100.0, 0.35)
	_was_floor = on_floor
	_fall_speed = _player.velocity.y
	_step_timer -= delta
	if on_floor and absf(_player.velocity.x) > 1.0 and _step_timer <= 0.0:
		_step_timer = STEP_EVERY
		burst(feet - Vector2(_player.facing * 3.0, 0), DUST, 1, 22.0, 40.0, 60.0, 0.3)

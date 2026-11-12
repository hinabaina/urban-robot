# Кинематографичный момент после важного события: чёрные полосы сверху и снизу, камера наезжает на место события,
# время замирает, заголовок печатается по буквам. Каждый момент показывается один раз за партию. Владелец: A.
class_name Moment
extends Control

const BAR := 96.0                 # высота чёрных полос
const IN_TIME := 0.45
const HOLD := 2.8
const OUT_TIME := 0.5
const LETTER := 0.035             # секунд на букву заголовка
const UI_FADE := 0.3              # остальной интерфейс прячется, кадр чистый

static var enabled := true        # автопроверки выключают моменты, где они мешают

var _player: CharacterBody2D
var _world: Node2D
var _top := ColorRect.new()
var _bottom := ColorRect.new()
var _title: Label
var _subtitle: Label
var _playing := false
var _queue: Array = []            # [id, позиция в мире]
var _skip := false
var _hold: HoldSkip


func setup(player: CharacterBody2D, world: Node2D) -> void:
	_player = player
	_world = world
	UiKit.setup_root(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bar in [_top, _bottom]:
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_title = UiKit.title("", 24, UiKit.ACCENT)
	_subtitle = UiKit.label("", UiKit.FONT_SIZE, UiKit.TEXT)
	for label in [_title, _subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		add_child(label)
	_title.offset_top = -BAR + 14.0
	_title.offset_bottom = -BAR + 44.0
	_subtitle.offset_top = -BAR + 50.0
	_subtitle.offset_bottom = -BAR + 80.0
	_set_bars(0.0)
	GameState.gift_arrived.connect(func(_gift: Dictionary) -> void: play("parcel", _player.global_position))
	Sim.item_delivered.connect(func(type: String, by_hand: bool) -> void:
		if type == "ingot" and not by_hand:
			play("auto", MachineCatalog.center("storage", _world.marker_cell("Storage"))))
	Sim.vein_exhausted.connect(func(_vein: int) -> void: play("exhausted", _player.global_position))


## Показать момент id, если его ещё не было в этой партии.
	_hold = HoldSkip.new()
	_hold.at_top = true
	_hold.visible = false
	_hold.skipped.connect(func() -> void: _skip = true)
	add_child(_hold)


func play(id: String, at: Vector2) -> void:
	if not enabled or GameState.moments_seen.has(id) or DayCycle.phase != DayCycle.Phase.DAY:
		return
	GameState.moments_seen.append(id)
	_queue.append([id, at])
	if not _playing:
		_next()


func is_playing() -> bool:
	return _playing


func _next() -> void:
	if _queue.is_empty():
		return
	var item: Array = _queue.pop_front()
	var id: String = item[0]
	_playing = true
	_skip = false
	_hold.reset()
	_hold.visible = true
	var was_running := DayCycle.running
	DayCycle.running = false
	_player.frozen = true
	var camera: Camera2D = _player.camera
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var bounds: Rect2 = _world.world_rect()
	var center: Vector2 = item[1].clamp(bounds.position + half, bounds.end - half)
	var look: Vector2 = center - camera.get_screen_center_position()
	_title.text = tr("MOMENT_%s_T" % id.to_upper())
	_title.visible_characters = 0
	_subtitle.text = tr("MOMENT_%s_S" % id.to_upper())
	_subtitle.modulate.a = 0.0
	Audio.play("hint")
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_bars, 0.0, 1.0, IN_TIME)
	tween.tween_property(camera, "offset", look, IN_TIME * 1.6)
	var hidden := _hide_ui()
	tween.tween_property(_title, "visible_characters", _title.text.length(), _title.text.length() * LETTER).set_delay(IN_TIME)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.4).set_delay(IN_TIME + _title.text.length() * LETTER)
	var wait := IN_TIME + _title.text.length() * LETTER + HOLD
	while wait > 0.0 and not _skip:
		await get_tree().process_frame
		wait -= get_process_delta_time()
	tween.kill()
	var back := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_method(_set_bars, _top.size.y / BAR, 0.0, OUT_TIME)
	back.tween_property(camera, "offset", Vector2.ZERO, OUT_TIME)
	for node: CanvasItem in hidden:
		back.tween_property(node, "modulate:a", 1.0, OUT_TIME)
	back.tween_property(_title, "modulate:a", 0.0, OUT_TIME * 0.6)
	back.tween_property(_subtitle, "modulate:a", 0.0, OUT_TIME * 0.6)
	_hold.visible = false
	await back.finished
	_title.modulate.a = 1.0
	_player.frozen = DayCycle.phase in [DayCycle.Phase.NIGHT, DayCycle.Phase.REPORT, DayCycle.Phase.OVER]
	DayCycle.running = was_running
	_playing = false
	_next()


## Плавно спрятать HUD, хотбар и подсказки на время момента. Возвращает спрятанные узлы.
func _hide_ui() -> Array:
	var hidden := []
	for node in get_parent().get_children():
		if node == self:
			break        # всё, что выше момента (рация, пауза, меню), не трогаем
		if node is CanvasItem and node.visible:
			hidden.append(node)
			create_tween().tween_property(node, "modulate:a", 0.0, UI_FADE)
	return hidden


func _set_bars(t: float) -> void:
	_top.offset_bottom = BAR * t
	_bottom.offset_top = -BAR * t


## Клавиши во время момента до игры не доходят; пропуск — удержанием Пробела (полоска справа внизу).
func _input(event: InputEvent) -> void:
	if _playing and (event is InputEventKey or event is InputEventMouseButton) and not _hold.get_global_rect().has_point(get_global_mouse_position()):
		get_viewport().set_input_as_handled()

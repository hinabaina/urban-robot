# Обучение: плашка с подсказкой и стрелка на цель. Шаги из data/tutorial.json, следующий — после выполнения текущего. Владелец: B.
extends Control

const PATH := "res://data/tutorial.json"
const PANEL_BOTTOM := 112.0        # плашка сидит над хотбаром
const PANEL_HEIGHT := 56.0
const ARROW_SCALE := 3.0
const ARROW_GAP := 26.0            # стрелка висит над целью
const ARROW_BOB := 5.0
const EDGE := 40.0                 # отступ стрелки от края экрана, если цель не видна

var _player: CharacterBody2D
var _world: Node2D
var _data: Dictionary = {}
var _steps: Array = []
var _index := 0
var _events := {}                  # события, случившиеся за текущий день
var _walked := 0.0
var _timer := 0.0
var _last_x := 0.0
var _panel: PanelContainer
var _text: Label
var _arrow: TextureRect


func setup(player: CharacterBody2D, world: Node2D) -> void:
	_player = player
	_world = world
	_data = GameState.load_json(PATH)
	UiKit.setup_root(self)
	var center := CenterContainer.new()     # сам центрирует плашку при любой длине текста
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -PANEL_BOTTOM - PANEL_HEIGHT
	center.offset_bottom = -PANEL_BOTTOM
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var row := UiKit.hbox(16)
	_panel.add_child(row)
	_text = UiKit.label("", UiKit.FONT_SIZE, UiKit.TEXT)
	row.add_child(_text)
	var skip := UiKit.button(tr("TUT_SKIP"), _finish)
	skip.add_theme_font_size_override("font_size", UiKit.SMALL_SIZE)
	row.add_child(skip)
	_arrow = UiKit.icon(Sprites.tex("arrow_out"), int(Sprites.ITEM_SIZE * ARROW_SCALE))
	_arrow.pivot_offset = _arrow.custom_minimum_size * 0.5
	_arrow.rotation = PI * 0.5      # спрайт смотрит вправо, поворачиваем вниз
	add_child(_arrow)
	GameState.happened.connect(func(event: String) -> void: _events[event] = true)
	DayCycle.day_started.connect(start_day)
	start_day(GameState.day)


func start_day(day: int) -> void:
	var day_data: Dictionary = _data.get(str(day), {})
	_steps = day_data.get("steps", [])
	_index = 0
	_events.clear()
	DayCycle.clock_scale = float(day_data.get("clock_scale", 1.0)) if not _steps.is_empty() else 1.0
	_begin_step()


func is_active() -> bool:
	return _index < _steps.size()


func _begin_step() -> void:
	_walked = 0.0
	_timer = 0.0
	_last_x = _player.global_position.x
	visible = is_active()
	if is_active():
		_text.text = tr(_steps[_index]["text"])
		Audio.play("hint")
	else:
		DayCycle.clock_scale = 1.0


func _finish() -> void:
	_index = _steps.size()
	_begin_step()


func _process(delta: float) -> void:
	if not is_active() or DayCycle.phase != DayCycle.Phase.DAY:
		visible = false
		return
	visible = true
	_walked += absf(_player.global_position.x - _last_x)
	_last_x = _player.global_position.x
	_timer += delta
	var step: Dictionary = _steps[_index]
	if _is_done(step["done"]):
		_index += 1
		_begin_step()
		return
	_place_arrow(step.get("target", {}))


func _is_done(done: Dictionary) -> bool:
	if done.has("walked_tiles"):
		return _walked >= float(done["walked_tiles"]) * TileCatalog.TILE
	if done.has("below_row"):
		return TileCatalog.cell_at(_player.global_position).y >= int(done["below_row"])
	if done.has("pocket"):
		return GameState.can_afford(done["pocket"])
	if done.has("storage"):
		for type in done["storage"]:
			if Sim.storage_count(type) < int(done["storage"][type]):
				return false
		return true
	if done.has("event"):
		return _events.has(done["event"])
	return _timer >= float(done.get("timer", 0.0))


## Стрелка над целью; если цель за экраном — у края экрана со стороны цели.
func _place_arrow(target: Dictionary) -> void:
	_arrow.visible = not target.is_empty()
	if target.is_empty():
		return
	var world_pos: Vector2
	if target.has("marker"):
		world_pos = _world.marker_pos(target["marker"])
	else:
		world_pos = TileCatalog.cell_center(Vector2i(int(target["cell"][0]), int(target["cell"][1])))
	var screen: Vector2 = _player.get_viewport().get_canvas_transform() * world_pos
	screen.y -= ARROW_GAP + absf(sin(Time.get_ticks_msec() * 0.006)) * ARROW_BOB
	var inside := Rect2(Vector2(EDGE, EDGE * 2.5), size - Vector2(EDGE * 2.0, EDGE * 2.5 + PANEL_BOTTOM + EDGE))
	var clamped := screen.clamp(inside.position, inside.end)
	_arrow.rotation = PI * 0.5 if clamped.is_equal_approx(screen) else (screen - clamped).angle()
	_arrow.position = clamped - _arrow.custom_minimum_size * 0.5

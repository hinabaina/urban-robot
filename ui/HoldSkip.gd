# Пропуск ролика удержанием Пробела (или кнопки мыши на полоске): случайное нажатие больше ничего не пропускает.
# Полоска в углу заполняется, пока держишь, и быстро сбегает обратно, если отпустить. Владелец: B.
class_name HoldSkip
extends PanelContainer

signal skipped()

const HOLD := 0.9                 # сколько секунд держать
const DRAIN := 3.0                # во сколько раз быстрее полоска сбегает
const IDLE_ALPHA := 0.55
const EDGE := 18.0
const BAR := Vector2(150, 12)

var at_top := false                # в кино-моменте внизу субтитры: полоска уходит в верхнюю чёрную полосу

var _held := 0.0
var _done := false
var _mouse := false
var _bar := ProgressBar.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.box("ui_panel", 8))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if at_top else Control.PRESET_BOTTOM_RIGHT,
		Control.PRESET_MODE_MINSIZE, EDGE)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END if at_top else Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse = event.pressed)
	var row := UiKit.hbox(10)
	add_child(row)
	row.add_child(UiKit.label(tr("SKIP_HOLD"), UiKit.SMALL_SIZE, UiKit.TEXT))
	_bar.custom_minimum_size = BAR
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.max_value = 1.0
	row.add_child(_bar)
	modulate.a = IDLE_ALPHA


func _process(delta: float) -> void:
	if _done or not is_visible_in_tree():
		return
	var holding := Input.is_physical_key_pressed(KEY_SPACE) or (_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	_held = clampf(_held + delta if holding else _held - delta * DRAIN, 0.0, HOLD)
	_bar.value = _held / HOLD
	modulate.a = 1.0 if _held > 0.0 else IDLE_ALPHA
	if _held >= HOLD:
		_done = true
		skipped.emit()


## Ролик закончился сам или начался заново: полоска пуста и снова работает.
func reset() -> void:
	_held = 0.0
	_done = false
	_bar.value = 0.0

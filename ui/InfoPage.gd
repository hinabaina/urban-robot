# Страница с текстом: «Как играть» и «Авторы». Строки берутся из переводов по списку ключей. Владелец: B.
# Окно выезжает снизу, длинный текст прокручивается колесом мыши внутри окна.
# Закрыть: кнопка «Назад», Esc или клик мимо окна.
extends Control

signal closed()

const PAGES := {
	"howto": {"title": "HOWTO_TITLE", "lines": ["HOWTO_GOAL", "HOWTO_MOVE", "HOWTO_TOOLS", "HOWTO_BUILD", "HOWTO_HANDS",
		"HOWTO_DAY", "HOWTO_AUTOMATION"]},
	"credits": {"title": "CREDITS_TITLE", "lines": ["CREDITS_TEAM", "CREDITS_ENGINE", "CREDITS_ART", "CREDITS_SOUND",
		"CREDITS_FONTS", "CREDITS_AI", "CREDITS_EVENT"]},
}
const WIDTH := 860
const MARGIN := 48.0          # окно не подходит к краям экрана ближе этого
const SLIDE := 60.0           # на сколько пикселей окно выезжает снизу
const OPEN_TIME := 0.22

var _panel: PanelContainer
var _dim: ColorRect
var _closing := false


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(page: String) -> void:
	for child in get_children():
		child.queue_free()
	_closing = false
	_dim = UiKit.dim()
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.box("ui_panel", 24))
	add_child(_panel)
	var column := UiKit.vbox(14)
	_panel.add_child(column)
	var title := UiKit.title(tr(PAGES[page]["title"]), UiKit.TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := UiKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for key in PAGES[page]["lines"]:
		var line := UiKit.label(tr(key), UiKit.SMALL_SIZE)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(line)
	var back := UiKit.button(tr("BTN_BACK"), close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 180
	column.add_child(back)     # кнопка вне прокрутки: видна всегда
	visible = true
	_layout.call_deferred(scroll, list)


## Размер окна: по тексту, но не выше экрана; лишнее уходит в прокрутку.
func _layout(scroll: ScrollContainer, list: VBoxContainer) -> void:
	var screen := get_viewport_rect().size
	var width := minf(WIDTH, screen.x - MARGIN * 2.0)
	list.custom_minimum_size.x = width - 48.0 - 16.0     # поля окна и место под полосу прокрутки
	await get_tree().process_frame
	var chrome: float = _panel.get_combined_minimum_size().y      # заголовок, кнопка и поля без текста
	var height := minf(chrome + list.get_combined_minimum_size().y, screen.y - MARGIN * 2.0)
	scroll.custom_minimum_size.y = maxf(height - chrome, 80.0)
	_panel.size = Vector2(width, 0.0)
	_panel.reset_size()
	var rest := ((screen - _panel.size) * 0.5).floor()
	_panel.position = rest + Vector2(0.0, SLIDE)
	_panel.modulate.a = 0.0
	_dim.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position", rest, OPEN_TIME)
	tween.tween_property(_panel, "modulate:a", 1.0, OPEN_TIME * 0.7)
	tween.tween_property(_dim, "modulate:a", 1.0, OPEN_TIME)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "position:y", _panel.position.y + SLIDE, OPEN_TIME)
	tween.tween_property(_panel, "modulate:a", 0.0, OPEN_TIME)
	tween.tween_property(_dim, "modulate:a", 0.0, OPEN_TIME)
	await tween.finished
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(Actions.PAUSE) or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

# Записная книжка инженера: короткие подсказки по главам. B или кнопка «?» в панели; игра на паузе, пока открыта.
# Главы и тексты — ключи GUIDE_* в data/translations.csv. Владелец: B.
class_name GuideBook
extends Control

const CHAPTERS := ["GOAL", "KEYS", "OUT", "BELT", "FURNACE", "FARM", "TOOLS", "NIGHT"]
const WIDTH := 900
const PAGE_HEIGHT := 380
const TAB_WIDTH := 250
const INK := Color("3b2a1f")
const INK_SOFT := Color("7a5a3c")

var _page: Label
var _title: Label
var _tabs: Array[Button] = []
var _current := 0


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dim(0.5))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var book := PanelContainer.new()
	book.add_theme_stylebox_override("panel", UiKit.box("ui_dialog", 20))
	book.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(book)
	var column := UiKit.vbox(12)
	book.add_child(column)
	var head := UiKit.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_child(head)
	var heading := _ink(UiKit.title(tr("GUIDE_TITLE"), UiKit.TITLE_SIZE, Color("a8432f")))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	head.add_child(_ink(UiKit.label(tr("GUIDE_HINT"), UiKit.TINY_SIZE, INK_SOFT)))
	var row := UiKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_child(row)
	var tabs := UiKit.vbox(4)
	tabs.custom_minimum_size.x = TAB_WIDTH
	row.add_child(tabs)
	for i in CHAPTERS.size():
		var tab := UiKit.button(tr("GUIDE_%s_T" % CHAPTERS[i]), open_chapter.bind(i))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_paper_button(tab)
		tabs.add_child(tab)
		_tabs.append(tab)
	var page := UiKit.vbox(10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size.y = PAGE_HEIGHT
	row.add_child(page)
	_title = _ink(UiKit.label("", UiKit.FONT_SIZE, Color("a8432f")))
	page.add_child(_title)
	_page = _ink(UiKit.label("", UiKit.FONT_SIZE, INK))
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.custom_minimum_size.x = WIDTH - TAB_WIDTH - 80
	page.add_child(_page)
	var close := UiKit.button(tr("BTN_BACK"), toggle)
	_paper_button(close)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.GUIDE) or (visible and event.is_action_pressed(Actions.PAUSE)):
		toggle()
		get_viewport().set_input_as_handled()


## Открыть или закрыть. Во время отчёта, финала и меню книжка не нужна: там игра и так стоит.
func toggle() -> void:
	if not visible and (not DayCycle.running or DayCycle.phase in [DayCycle.Phase.REPORT, DayCycle.Phase.OVER]):
		return
	visible = not visible
	get_tree().paused = visible
	Audio.play("select")
	if visible:
		open_chapter(_current)


func open_chapter(index: int) -> void:
	_current = index
	_title.text = tr("GUIDE_%s_T" % CHAPTERS[index])
	_page.text = tr("GUIDE_" + CHAPTERS[index])
	for i in _tabs.size():
		_tabs[i].button_pressed = i == index


func _ink(label: Label) -> Label:
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	return label


func _paper_button(button: Button) -> void:
	button.toggle_mode = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiKit.box("ui_choice_hover" if state in ["hover", "pressed"] else "ui_choice", 4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)

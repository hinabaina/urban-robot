# Общий стиль интерфейса: шрифты, цвета, тема и маленькие фабрики виджетов. Владелец: B.
class_name UiKit

const TEXT := Color("f3ead2")
const ACCENT := Color("ffab45")
const MUTED := Color("9aa8bd")
const GOOD := Color("84c95a")
const BAD := Color("f0705a")
const SHADOW := Color(0.06, 0.05, 0.1, 0.9)
const FONT_SIZE := 22
const SMALL_SIZE := 18
const FONT_WEIGHT := 600
const FONT_WIDTH := 82
const TITLE_SIZE := 16
const BOX_MARGIN := 8          # поля 9-patch (в текстуре 4 px, увеличено вдвое)
const ICON := 32

static var _theme: Theme
static var _font: Font
static var _title_font: Font


static func font() -> Font:
	if _font == null:
		var variation := FontVariation.new()
		variation.base_font = load("res://assets/fonts/Tektur.ttf")
		var server := TextServerManager.get_primary_interface()
		variation.variation_opentype = {server.name_to_tag("wght"): FONT_WEIGHT, server.name_to_tag("wdth"): FONT_WIDTH}
		_font = variation
	return _font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	return _title_font


static func box(texture_name: String, content := 10) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = Sprites.tex(texture_name)
	style.set_texture_margin_all(BOX_MARGIN)
	style.set_content_margin_all(content)
	return style


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_stylebox("panel", "PanelContainer", box("ui_panel"))
	t.set_stylebox("normal", "Button", box("ui_button", 8))
	t.set_stylebox("hover", "Button", box("ui_button", 8))
	t.set_stylebox("pressed", "Button", box("ui_button_hover", 8))   # нажатая/включённая — с яркой рамкой
	t.set_stylebox("disabled", "Button", box("ui_button_pressed", 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_stylebox("background", "ProgressBar", box("ui_bar_bg", 0))
	var fill := box("ui_bar_fill", 0)
	fill.set_texture_margin_all(4)
	t.set_stylebox("fill", "ProgressBar", fill)
	_theme = t
	return t


## Общая настройка корневого узла экрана интерфейса: на весь экран, тема, чёткие пиксели.
static func setup_root(root: Control) -> void:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Затемнение экрана под окном (ловит клики, чтобы они не уходили в игру).
static func dim(alpha := 0.6) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color(0.03, 0.03, 0.08, alpha)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node


## Окно по центру экрана с вертикальным списком внутри. Возвращает этот список.
static func window(parent: Control, width := 620) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box("ui_panel", 24))
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var list := vbox(14)
	panel.add_child(list)
	return list


static func label(text: String, size := FONT_SIZE, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func title(text: String, size := TITLE_SIZE, color := TEXT) -> Label:
	var node := label(text, size, color)
	node.add_theme_font_override("font", title_font())
	return node


## Пиксельная картинка фиксированного размера (спрайт 16 px показываем как 32 px).
static func icon(texture: Texture2D, size := ICON) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = Vector2(size, size)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Кнопка без фокуса клавиатуры: Пробел и Enter остаются игре.
static func button(text: String, on_press: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(on_press)
	return node


static func hbox(separation := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.alignment = BoxContainer.ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func vbox(separation := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

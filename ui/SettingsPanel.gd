# Окно настроек: громкость музыки и звуков, язык, полный экран. Открывается из главного меню и из паузы. Владелец: B.
extends Control

signal closed()
signal locale_changed()

const LOCALES := {"ru": "Русский", "kk": "Қазақша"}
const SLIDER_WIDTH := 240

var allow_locale := true     # в паузе язык не меняем: это пересобирает весь интерфейс


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	for child in get_children():
		child.queue_free()
	add_child(UiKit.dim())
	var list := UiKit.window(self, 460)
	list.add_child(_centered(UiKit.title(tr("SETTINGS_TITLE"), UiKit.TITLE_SIZE, UiKit.ACCENT)))
	list.add_child(_slider("SETTINGS_MUSIC", "music"))
	list.add_child(_slider("SETTINGS_SFX", "sfx"))
	if allow_locale:
		var row := _row("SETTINGS_LANGUAGE")
		for code in LOCALES:
			var button := UiKit.button(LOCALES[code], _set_locale.bind(code))
			button.toggle_mode = true
			button.button_pressed = Settings.get_value("locale") == code
			row.add_child(button)
		list.add_child(row)
	if not OS.has_feature("web"):
		var row := _row("SETTINGS_FULLSCREEN")
		var toggle := CheckButton.new()
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.button_pressed = Settings.get_value("fullscreen")
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_value("fullscreen", on))
		row.add_child(toggle)
		list.add_child(row)
	var back := UiKit.button(tr("BTN_BACK"), close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 180
	list.add_child(back)
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _row(title_key: String) -> HBoxContainer:
	var row := UiKit.hbox(12)
	var title := UiKit.label(tr(title_key))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	return row


func _slider(title_key: String, setting: String) -> HBoxContainer:
	var row := _row(title_key)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get_value(setting)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(setting, value))
	if setting == "sfx":
		slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play("ore"))
	row.add_child(slider)
	return row


func _set_locale(code: String) -> void:
	if Settings.get_value("locale") != code:
		Settings.set_value("locale", code)
		locale_changed.emit()

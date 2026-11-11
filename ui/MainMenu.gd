# Главное меню поверх мира: название, три строки сюжета, кнопки. Владелец: B.
extends Control

signal new_game_pressed()
signal continue_pressed()
signal settings_pressed()
signal page_pressed(page: String)
signal intro_pressed()

const TITLE_SIZE := 44
const BUTTON_WIDTH := 300
const STORY := ["MENU_STORY_1", "MENU_STORY_2", "MENU_STORY_3"]

var can_continue := false    # Main включает, если есть сохранение


func _ready() -> void:
	UiKit.setup_root(self)
	visible = false


func open() -> void:
	for child in get_children():
		child.queue_free()
	add_child(UiKit.dim(0.55))
	var list := UiKit.window(self, 640)
	var title := UiKit.title("DALA WORKS", TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	for key in STORY:
		var line := UiKit.label(tr(key), UiKit.SMALL_SIZE + 2, UiKit.TEXT)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(line)
	if can_continue:
		_button(list, "MENU_CONTINUE", func() -> void: continue_pressed.emit())
	_button(list, "MENU_NEW_GAME", func() -> void: new_game_pressed.emit())
	_button(list, "MENU_SETTINGS", func() -> void: settings_pressed.emit())
	_button(list, "MENU_HOWTO", func() -> void: page_pressed.emit("howto"))
	if Settings.get_value("intro_seen"):
		_button(list, "MENU_INTRO", func() -> void: intro_pressed.emit())
	_button(list, "MENU_CREDITS", func() -> void: page_pressed.emit("credits"))
	if not OS.has_feature("web"):
		_button(list, "MENU_QUIT", func() -> void: get_tree().quit())
	var best := int(Settings.get_value("best_stars"))
	if best > 0:
		var record := UiKit.label(tr("MENU_RECORD") % [best, int(round(float(Settings.get_value("best_automation")) * 100.0))],
			UiKit.SMALL_SIZE, UiKit.MUTED)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(record)
	visible = true


func _button(list: VBoxContainer, key: String, on_press: Callable) -> void:
	var button := UiKit.button(tr(key), on_press)
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(button)

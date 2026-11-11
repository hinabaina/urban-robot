# Пауза по Esc или кнопке HUD: продолжить, настройки, как играть, заново, в меню. Работает, пока дерево на паузе. Владелец: B.
extends Control

signal restart_pressed()
signal menu_pressed()
signal settings_pressed()
signal page_pressed(page: String)

const BUTTON_WIDTH := 280


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dim())
	var list := UiKit.window(self, 380)
	var title := UiKit.title(tr("PAUSE_TITLE"), UiKit.TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	_button(list, "PAUSE_CONTINUE", toggle)
	_button(list, "MENU_SETTINGS", func() -> void: settings_pressed.emit())
	_button(list, "MENU_HOWTO", func() -> void: page_pressed.emit("howto"))
	_button(list, "PAUSE_RESTART", func() -> void: restart_pressed.emit())
	_button(list, "PAUSE_MENU", func() -> void: menu_pressed.emit())


func _button(list: VBoxContainer, key: String, on_press: Callable) -> void:
	var button := UiKit.button(tr(key), on_press)
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.PAUSE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	# В меню, отчёте и финале игра и так стоит — пауза там не нужна.
	if not visible and (not DayCycle.running or DayCycle.phase in [DayCycle.Phase.REPORT, DayCycle.Phase.OVER]):
		return
	visible = not visible
	get_tree().paused = visible

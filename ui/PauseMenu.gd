# Пауза по Esc или кнопке HUD: продолжить или начать сначала. Работает, пока дерево на паузе. Владелец: B.
extends Control

signal restart_pressed()


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dim())
	var list := UiKit.window(self, 360)
	var title := UiKit.title(tr("PAUSE_TITLE"), UiKit.TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	list.add_child(UiKit.button(tr("PAUSE_CONTINUE"), toggle))
	list.add_child(UiKit.button(tr("PAUSE_RESTART"), func() -> void: restart_pressed.emit()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.PAUSE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	# Во время отчёта и финала игра и так стоит — пауза там не нужна.
	if not visible and DayCycle.phase in [DayCycle.Phase.REPORT, DayCycle.Phase.OVER]:
		return
	visible = not visible
	get_tree().paused = visible

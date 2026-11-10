# Экран конца игры: победа (ракета запущена) или поражение (доверие кончилось). Владелец: B.
extends Control

signal restart_pressed()

var _list: VBoxContainer
var _won := false


func _ready() -> void:
	UiKit.setup_root(self)
	visible = false
	add_child(UiKit.dim())
	_list = UiKit.window(self)
	GameState.game_over.connect(func(won: bool) -> void: _won = won)
	DayCycle.phase_changed.connect(_on_phase)


func _on_phase(phase: int) -> void:
	if phase != DayCycle.Phase.OVER:
		visible = false
		return
	for child in _list.get_children():
		child.queue_free()
	var title_key := "END_WIN_TITLE" if _won else "END_LOSE_TITLE"
	_add(UiKit.title(tr(title_key), UiKit.TITLE_SIZE, UiKit.GOOD if _won else UiKit.BAD))
	_add(UiKit.label(tr("END_WIN_TEXT" if _won else "END_LOSE_TEXT")))
	_add(UiKit.label(tr("END_STATS") % [GameState.delivered_total, int(round(GameState.automation() * 100.0))]))
	var button := UiKit.button(tr("END_RESTART"), func() -> void: restart_pressed.emit())
	button.custom_minimum_size.x = 220
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(button)
	visible = true


func _add(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(label)

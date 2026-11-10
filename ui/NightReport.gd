# Ночной отчёт («газета»): что сделала фабрика, сколько сдано, что привёз дрон. Кнопка «Утро». Владелец: B.
extends Control

var _list: VBoxContainer
var _last_result := {}


func _ready() -> void:
	UiKit.setup_root(self)
	visible = false
	add_child(UiKit.dim(0.35))
	_list = UiKit.window(self)
	GameState.day_settled.connect(func(result: Dictionary) -> void: _last_result = result)
	DayCycle.day_ended.connect(_show)


func _show(day: int) -> void:
	for child in _list.get_children():
		child.queue_free()
	_add(UiKit.title(tr("REPORT_TITLE") % day, UiKit.TITLE_SIZE, UiKit.ACCENT))
	var made: Dictionary = Sim.night_summary().get("made", {})
	if not made.is_empty():
		_add(UiKit.label(tr("REPORT_MADE") % [made.get("ingot", 0), made.get("ore", 0), made.get("grain", 0)]))
	if not _last_result.is_empty():
		var color := UiKit.GOOD if _last_result["ok"] else UiKit.BAD
		_add(UiKit.label(tr("REPORT_DELIVERED") % [_last_result["taken"], _last_result["quota"]], UiKit.FONT_SIZE, color))
	_add(UiKit.label(tr("REPORT_AUTOMATION") % int(round(GameState.automation() * 100.0))))
	var gift: Array = GameState.day_config(day).get("gift", {}).get("unlock", [])
	if not gift.is_empty():
		var names := gift.map(func(id: String) -> String: return tr("SLOT_" + id))
		_add(UiKit.label(tr("REPORT_GIFT") % ", ".join(names), UiKit.FONT_SIZE, UiKit.ACCENT))
	_add(UiKit.label(tr("REPORT_NEXT_QUOTA") % int(GameState.day_config(day + 1)["quota"])))
	var button := UiKit.button(tr("REPORT_BUTTON"), _on_morning)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 180
	_add(button)
	visible = true


func _add(node: Control) -> void:
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(node)


func _on_morning() -> void:
	visible = false
	DayCycle.next_morning()

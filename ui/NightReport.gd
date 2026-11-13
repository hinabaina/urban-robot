# Ночной отчёт («газета»): что сделала фабрика, сколько сдано, что привёз дрон. Кнопка «Утро». Владелец: B.
extends Control

const BOTTLENECK_MIN_SHARE := 0.1   # простой меньше 10% ночи не показываем

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
	_add_bottleneck()
	if not GameState.bonds.is_empty():   # отношения с героями рации (ui/Radio.gd)
		var bonds := []
		for who in GameState.bonds:
			var value := int(GameState.bonds[who])
			bonds.append(tr("BOND_UP" if value >= 2 else ("BOND_DOWN" if value < 0 else "BOND_MID")) % tr("BOND_NAME_" + who.to_upper()))
		_add(UiKit.label(tr("REPORT_BONDS") % ", ".join(bonds), UiKit.SMALL_SIZE, UiKit.WATER))
	var gift: Array = GameConfig.day(day).get("gift", {}).get("unlock", [])
	if not gift.is_empty():
		var names := gift.map(func(id: String) -> String: return tr("SLOT_" + id))
		_add(UiKit.label(tr("REPORT_GIFT") % ", ".join(names), UiKit.FONT_SIZE, UiKit.ACCENT))
	var fact: String = GameConfig.day(day).get("fact", "")
	if fact != "":
		_add(UiKit.label(tr("REPORT_FACT") % tr(fact), UiKit.SMALL_SIZE, UiKit.MUTED))
	_add(UiKit.label(tr("REPORT_NEXT_QUOTA") % int(GameConfig.day(day + 1)["quota"])))
	var button := UiKit.button(tr("REPORT_BUTTON"), _on_morning)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 180
	_add(button)
	visible = true


## Узкое место ночи: машина, которая дольше всех простояла, и почему. Подсказка, что улучшать утром.
func _add_bottleneck() -> void:
	var worst: Dictionary = Sim.night_summary().get("bottleneck", {})
	if worst.is_empty() or float(worst["share"]) < BOTTLENECK_MIN_SHARE:
		return
	var why := {Sim.State.BLOCKED: "REPORT_WHY_BLOCKED", Sim.State.NO_FUEL: "REPORT_WHY_NO_FUEL",
		Sim.State.NO_WATER: "REPORT_WHY_NO_WATER", Sim.State.EXHAUSTED: "REPORT_WHY_EXHAUSTED"}
	var text := tr("REPORT_BOTTLENECK") % [tr("SLOT_" + str(worst["type"])).to_lower(), int(round(float(worst["share"]) * 100.0)),
		tr(why.get(int(worst["state"]), "REPORT_WHY_BLOCKED"))]
	_add(UiKit.label(text, UiKit.FONT_SIZE, UiKit.BAD))


func _add(node: Control) -> void:
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(node)


func _on_morning() -> void:
	visible = false
	DayCycle.next_morning()

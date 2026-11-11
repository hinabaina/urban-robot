# Ночной отчёт («газета»): что сделала фабрика, сколько сдано, что привёз дрон. Кнопка «Утро». Владелец: B.
extends Control

const BOTTLENECK_TYPES := ["drill", "furnace", "sprinkler", "harvester"]

var _list: VBoxContainer
@onready var _reason_of_state := {Sim.State.BLOCKED: "REPORT_WHY_BLOCKED", Sim.State.NO_FUEL: "REPORT_WHY_NO_FUEL",
	Sim.State.NO_WATER: "REPORT_WHY_NO_WATER", Sim.State.EXHAUSTED: "REPORT_WHY_EXHAUSTED"}
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
	var summary: Dictionary = Sim.night_summary()
	var made: Dictionary = summary.get("made", {})
	if not made.is_empty():
		_add(UiKit.label(tr("REPORT_MADE") % [made.get("ingot", 0), made.get("ore", 0), made.get("grain", 0)]))
	_add_bottleneck(summary.get("bottleneck", {}))
	if not _last_result.is_empty():
		var color := UiKit.GOOD if _last_result["ok"] else UiKit.BAD
		_add(UiKit.label(tr("REPORT_DELIVERED") % [_last_result["taken"], _last_result["quota"]], UiKit.FONT_SIZE, color))
	_add(UiKit.label(tr("REPORT_AUTOMATION") % int(round(GameState.automation() * 100.0))))
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


## «Узкое место: печь — 60% ночи без зерна» или «простоев не было», если фабрика есть.
func _add_bottleneck(worst: Dictionary) -> void:
	if worst.is_empty():
		var has_factory := Sim.get_machines().any(func(m: Variant) -> bool: return BOTTLENECK_TYPES.has(m.get("type")))
		if has_factory:
			_add(UiKit.label(tr("REPORT_NO_BOTTLENECK"), UiKit.FONT_SIZE, UiKit.GOOD))
		return
	var reason: String = _reason_of_state.get(int(worst["state"]), "REPORT_WHY_BLOCKED")
	var text := tr("REPORT_BOTTLENECK") % [tr("SLOT_" + str(worst["type"])).to_lower(), int(round(float(worst["share"]) * 100.0)), tr(reason)]
	_add(UiKit.label(text, UiKit.FONT_SIZE, UiKit.BAD))


func _add(node: Control) -> void:
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(node)


func _on_morning() -> void:
	visible = false
	DayCycle.next_morning()

# Нижняя панель: 9 слотов с картинкой, клавишей и ценой; замок на закрытых; подсказка под курсором. Владелец: B.
extends Control

const SLOT := 62
const COST_ICON := 16
const LOCKED_TINT := Color(0.35, 0.37, 0.45)
const EDGE := 8

var _build: Node              # BuildController
var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _locks: Array[TextureRect] = []
var _costs: Array[HBoxContainer] = []
var _tip: PanelContainer
var _tip_title: Label
var _tip_text: Label
var _normal := UiKit.box("ui_slot", 4)
var _selected := UiKit.box("ui_slot_selected", 4)


func setup(build: Node) -> void:
	_build = build
	UiKit.setup_root(self)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", UiKit.box("ui_panel", 6))
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, EDGE)
	back.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(back)
	var row := UiKit.hbox(6)
	back.add_child(row)
	for i in _build.slots.size():
		row.add_child(_make_slot(i))
	_make_tip()
	_build.selection_changed.connect(func(_i: int) -> void: _refresh())
	GameState.unlocked_changed.connect(_refresh)
	GameState.pockets_changed.connect(_refresh)
	_refresh()


func _make_slot(index: int) -> Control:
	var id: String = _build.slots[index]
	var column := UiKit.vbox(2)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_input.bind(index))
	panel.mouse_entered.connect(_show_tip.bind(index))
	panel.mouse_exited.connect(func() -> void: _tip.visible = false)
	column.add_child(panel)
	var icon := UiKit.icon(Sprites.slot(id))
	panel.add_child(icon)
	var key := UiKit.label(str(index + 1), UiKit.SMALL_SIZE, UiKit.MUTED)
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(key)
	var lock := UiKit.icon(Sprites.icon("lock"))
	panel.add_child(lock)
	var cost := UiKit.hbox(0)
	cost.custom_minimum_size = Vector2(SLOT, COST_ICON + 4)
	column.add_child(cost)
	_panels.append(panel)
	_icons.append(icon)
	_locks.append(lock)
	_costs.append(cost)
	return column


func _make_tip() -> void:
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)
	var list := UiKit.vbox(2)
	_tip.add_child(list)
	_tip_title = UiKit.label("", UiKit.FONT_SIZE, UiKit.ACCENT)
	_tip_text = UiKit.label("", UiKit.SMALL_SIZE)
	list.add_child(_tip_title)
	list.add_child(_tip_text)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_build.select(index)


func _show_tip(index: int) -> void:
	var id: String = _build.slots[index]
	_tip_title.text = tr("SLOT_" + id)
	if GameState.is_unlocked(id):
		_tip_text.text = tr("DESC_" + id)
	else:
		_tip_text.text = tr("SLOT_LOCKED") % GameState.unlock_day(id)
	_tip.visible = true
	_tip.reset_size()
	var slot_rect := _panels[index].get_global_rect()
	var x := clampf(slot_rect.get_center().x - _tip.size.x * 0.5, EDGE, size.x - _tip.size.x - EDGE)
	_tip.global_position = Vector2(x, slot_rect.position.y - _tip.size.y - EDGE)


func _refresh() -> void:
	for i in _panels.size():
		var id: String = _build.slots[i]
		var open := GameState.is_unlocked(id)
		_panels[i].add_theme_stylebox_override("panel", _selected if i == _build.selected else _normal)
		_icons[i].modulate = Color.WHITE if open else LOCKED_TINT
		_locks[i].visible = not open
		_fill_cost(_costs[i], MachineCatalog.cost(id) if open else {})


func _fill_cost(row: HBoxContainer, cost: Dictionary) -> void:
	for child in row.get_children():
		child.queue_free()
	for type in cost:
		var enough: bool = GameState.pockets.get(type, 0) >= int(cost[type])
		var count := UiKit.label(" %d" % int(cost[type]), UiKit.SMALL_SIZE, UiKit.TEXT if enough else UiKit.BAD)
		row.add_child(count)
		row.add_child(UiKit.icon(Sprites.item(type), COST_ICON))

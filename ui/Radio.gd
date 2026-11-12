# Рация: сюжет, разговоры и выборы с последствиями. На связи трое: Айша из аула, Ержан-ата и диспетчер
# комбината. Ответы игрока меняют отношения с каждым (GameState.bonds), ход партии и концовку.
# Сценарий в data/story.json: реплика — ключ перевода или {who, text, choices}. Владелец: A.
class_name Radio
extends Control

signal pressed(index: int)        # -1 — «дальше», 0.. — номер выбора

const PATH := "res://data/story.json"
const LETTERS_PER_SECOND := 60.0
const WIDTH := 860.0
const BOTTOM := 130.0
const FACE_PX := 6                # размер «пикселя» портрета
const FACES := {
	"aisha": ["....rrrr....", "...rrrrrr...", "..rrssssrr..", "..rhsssshr..", "..rsesseshr.", "..rsssssshr.",
		"..hssmmsshh.", "..hhsssshh..", ".hh.bbbb.hh.", ".h.bbwwbb.h.", "...bbbbbb...", "...bbbbbb..."],
	"erzhan": ["...kkkkkk...", "..kykykyk...", "..kkkkkkkk..", ".wssssssssw.", ".wsessssesw.", "..ssssssss..",
		"..swwwwwws..", "..wwwmmwww..", "...wwwwww...", "..ccwwwwcc..", ".cccccccccc.", ".cccccccccc."],
	"dispatcher": ["...gggggg...", "..gggggggg..", "..gggyyggg..", "..hhhhhhhh..", "..ssssssss..", "..sllsslls..",
		"..ssssssss..", "..sssmmsss..", "...ssssss...", "..ddwrrwdd..", ".dddwrrwddd.", ".ddddrrdddd."],
}
const PALETTE := {"r": Color("d9483b"), "s": Color("e8b48a"), "h": Color("2b2233"), "e": Color("1a1423"), "m": Color("a8443c"),
	"b": Color("3f6fb5"), "w": Color("f3ead2"), "k": Color("2f6b4f"), "y": Color("f4d34f"), "c": Color("7a5230"),
	"g": Color("5b6478"), "d": Color("2e3445"), "l": Color("9fd4e8")}
const NAME_COLORS := {"aisha": Color("f4d34f"), "erzhan": Color("8fd694"), "dispatcher": Color("9fb4d8")}
const BOND_UP := Color("8fd694")
const BOND_DOWN := Color("e0685c")

static var enabled := true        # автопроверки выключают рацию там, где она мешает

var _player: CharacterBody2D
var _moment: Moment
var _calls: Array = []
var _queue: Array = []
var _open := false
var _typing: Tween
var _dim: ColorRect
var _panel: PanelContainer
var _face: Control
var _who := "aisha"
var _name: Label
var _note: Label                  # «Айша это запомнит»
var _text: Label
var _buttons: BoxContainer


func setup(player: CharacterBody2D, moment: Moment) -> void:
	_player = player
	_moment = moment
	_calls = GameConfig.load_json(PATH).get("calls", [])
	UiKit.setup_root(self)
	_dim = UiKit.dim(0.35)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -BOTTOM - 190.0
	center.offset_bottom = -BOTTOM
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = WIDTH
	center.add_child(_panel)
	var row := UiKit.hbox(16)
	_panel.add_child(row)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(12, 12) * FACE_PX
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_face.draw.connect(_draw_face)
	row.add_child(_face)
	var column := UiKit.vbox(8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var head := UiKit.hbox(12)
	column.add_child(head)
	_name = UiKit.title("", 12, UiKit.ACCENT)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_note = UiKit.label("", UiKit.SMALL_SIZE)
	head.add_child(_note)
	_text = UiKit.label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 140.0, 84.0)
	column.add_child(_text)
	_buttons = BoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)
	visible = false
	Sim.item_delivered.connect(func(type: String, by_hand: bool) -> void:
		if type == "ingot" and not by_hand:
			_on_event("auto_ingot"))
	GameState.happened.connect(_on_event)


func is_open() -> bool:
	return _open


## Нажать «дальше» (-1) или выбрать вариант; так же жмут автопроверки.
func press(index: int = -1) -> void:
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
	else:
		pressed.emit(index)


func _on_event(event: String) -> void:
	for call in _calls:
		if call.get("event", "") == event and _fits(call):
			_enqueue(call)


func _process(_delta: float) -> void:
	if not enabled or _open or _player == null or not DayCycle.running or DayCycle.phase != DayCycle.Phase.DAY:
		return
	for call in _calls:
		if call.has("hour") and int(call["day"]) == GameState.day and DayCycle.hour >= float(call["hour"]) and _fits(call):
			_enqueue(call)
	if not _queue.is_empty() and not _moment.is_playing() and not _player.frozen:
		_show(_queue.pop_front())


func _fits(call: Dictionary) -> bool:
	for who in call.get("min", {}):      # отношения не ниже
		if int(GameState.bonds.get(who, 0)) < int(call["min"][who]):
			return false
	for who in call.get("max", {}):      # отношения не выше
		if int(GameState.bonds.get(who, 0)) > int(call["max"][who]):
			return false
	return (enabled and not GameState.story_done.has(call["id"]) and not GameState.story_done.has(call.get("unless_done", ""))
		and (not call.has("if") or GameState.story_flags.has(call["if"]))
		and (not call.has("unless") or not GameState.story_flags.has(call["unless"])))


func _enqueue(call: Dictionary) -> void:
	GameState.story_done.append(call["id"])
	_queue.append(call)


func _show(call: Dictionary) -> void:
	_open = true
	visible = true
	DayCycle.running = false
	_player.frozen = true
	_note.text = ""
	Audio.play("hint")
	_apply(call.get("effects", {}))
	var speaker: String = call.get("who", "aisha")
	var lines := _lines(call["lines"])
	for i in lines.size():
		var line: Dictionary = lines[i]
		var choices: Array = line.get("choices", call.get("choices", []) if i == lines.size() - 1 else [])
		_say(line.get("who", speaker), tr(line["text"]), choices)
		var picked: int = await pressed
		if choices.is_empty():
			continue
		var choice: Dictionary = choices[_pick(choices, picked)]
		_apply(choice.get("effects", {}))
		for reply in _lines(choice.get("reply", [])):
			_say(reply.get("who", speaker), tr(reply["text"]), [])
			await pressed
	visible = false
	_open = false
	_player.frozen = false
	DayCycle.running = true


## Реплики в одном виде: ключ перевода, {who, text} или их список превращаются в список словарей.
func _lines(value: Variant) -> Array:
	var result := []
	for line in (value if value is Array else [value]):
		result.append(line if line is Dictionary else {"text": line})
	return result


## Номер выбранного ответа; «дальше» (-1) берёт первый доступный.
func _pick(choices: Array, picked: int) -> int:
	if picked >= 0:
		return mini(picked, choices.size() - 1)
	for i in choices.size():
		if _can(choices[i].get("need", {})):
			return i
	return choices.size() - 1


## Показать реплику: портрет и имя говорящего, текст печатается, под ним «Дальше» или варианты ответа.
func _say(who: String, text: String, choices: Array) -> void:
	_who = who
	_name.text = tr("RADIO_NAME_" + who.to_upper())
	_name.add_theme_color_override("font_color", NAME_COLORS.get(who, UiKit.ACCENT))
	_face.queue_redraw()
	if not GameState.bonds.has(who):
		GameState.bonds[who] = 0         # познакомились
	_text.text = text
	_text.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, text.length() / LETTERS_PER_SECOND)
	for child in _buttons.get_children():
		child.queue_free()
	_buttons.vertical = choices.size() > 2      # три ответа в строку не помещаются
	if choices.is_empty():
		_buttons.add_child(UiKit.button(tr("RADIO_NEXT"), press.bind(-1)))
		return
	for i in choices.size():
		var can := _can(choices[i].get("need", {}))
		var why := "RADIO_CANT_BOND" if choices[i].get("need", {}).has("bonds") else "RADIO_CANT"
		var button := UiKit.button(tr(choices[i]["text"]) + ("" if can else " (%s)" % tr(why)), pressed.emit.bind(i))
		button.disabled = not can
		_buttons.add_child(button)


func _can(need: Dictionary) -> bool:
	for who in need.get("bonds", {}):
		if int(GameState.bonds.get(who, 0)) < int(need["bonds"][who]):
			return false
	return Sim.storage_count("ingot") >= int(need.get("storage_ingot", 0)) and GameState.can_afford(need.get("pockets", {}))


## Последствия реплики или выбора.
func _apply(effects: Dictionary) -> void:
	if effects.has("flag"):
		GameState.story_flags.append(effects["flag"])
	if effects.has("bonds"):
		_remember(effects["bonds"])
	if effects.has("storage_ingot"):
		Sim.storage_take_for_drone(-int(effects["storage_ingot"]))
		GameState.emit_quota()
	for type in effects.get("pockets", {}):
		var count := int(effects["pockets"][type])
		if count > 0:
			GameState.add_pocket(type, count)
		else:
			GameState.pay({type: -count})
	if effects.has("skip_hours"):
		DayCycle.hour = minf(DayCycle.hour + float(effects["skip_hours"]), 17.5)
	if effects.has("break_belts"):
		var belts := Sim.get_machines().filter(func(m: Variant) -> bool: return m.get("type") == "conveyor")
		belts.shuffle()
		for machine in belts.slice(0, int(effects["break_belts"])):
			Sim.remove_machine(machine.get("cell"))
		Audio.play("demolish")


## Отношения меняются, и игрок это видит: «▲ Айша это запомнит».
func _remember(changes: Dictionary) -> void:
	var notes := []
	var up := true
	for who in changes:
		var delta := int(changes[who])
		GameState.bonds[who] = int(GameState.bonds.get(who, 0)) + delta
		up = up and delta > 0
		notes.append(("▲ " if delta > 0 else "▼ ") + tr("RADIO_REMEMBER") % tr("BOND_NAME_" + who.to_upper()))
	_note.text = "   ".join(notes)
	_note.add_theme_color_override("font_color", BOND_UP if up else BOND_DOWN)
	_note.modulate.a = 0.0
	create_tween().tween_property(_note, "modulate:a", 1.0, 0.4)
	Audio.play("gift" if up else "hint")


func _draw_face() -> void:
	_face.draw_rect(Rect2(Vector2.ZERO, _face.size), Color("2a3350"))
	var rows: Array = FACES[_who]
	for y in rows.size():
		for x in rows[y].length():
			var key: String = rows[y][x]
			if PALETTE.has(key):
				_face.draw_rect(Rect2(x * FACE_PX, y * FACE_PX, FACE_PX, FACE_PX), PALETTE[key])


## Пробел, Enter или E — «дальше», когда выбора нет.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E] and (_buttons.get_child_count() <= 1 or (_typing and _typing.is_running())):
		press(-1)

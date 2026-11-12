# Рация: сюжет, разговоры и выборы с последствиями. На связи трое: Айша из аула, Ержан-ата и диспетчер
# комбината. Ответы игрока меняют отношения с каждым (GameState.bonds), ход партии и концовку.
# Сценарий в data/story.json: реплика — ключ перевода или {who, text, choices}. Владелец: A.
class_name Radio
extends Control

signal pressed(index: int)        # -1 — «дальше», 0.. — номер выбора

const PATH := "res://data/story.json"
const LETTERS_PER_SECOND := 55.0
const WIDTH := 760.0
const TOP := 64.0                 # окно висит под HUD и не закрывает шахту под ногами героя
const FACE_PX := 6                # размер «пикселя» портрета
const INK := Color("3b2a1f")       # тёмный текст на пергаменте
const INK_SOFT := Color("7a5a3c")
const BLIP_EVERY := 3             # тихий «блип» на каждую третью букву
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
const NAME_COLORS := {"aisha": Color("a8432f"), "erzhan": Color("2f6b36"), "dispatcher": Color("2e4a7a")}
const BOND_UP := Color("2f7a36")
const BOND_DOWN := Color("a8332a")

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
var _more: Label                  # мигающий «▼»: можно читать дальше
var _choices := 0                 # сколько ответов сейчас на экране
var _letters := 0                 # сколько букв уже «проблипало»
var _was_running := true


func setup(player: CharacterBody2D, moment: Moment) -> void:
	_player = player
	_moment = moment
	_calls = GameConfig.load_json(PATH).get("calls", [])
	UiKit.setup_root(self)
	_dim = UiKit.dim(0.18)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = TOP
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = WIDTH
	_panel.add_theme_stylebox_override("panel", UiKit.box("ui_dialog", 16))
	_panel.gui_input.connect(_on_panel_input)      # клик по окну — «дальше»
	center.add_child(_panel)
	var row := UiKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_panel.add_child(row)
	var portrait := VBoxContainer.new()
	portrait.add_theme_constant_override("separation", 4)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.box("ui_portrait", 4))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(frame)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(12, 12) * FACE_PX
	_face.draw.connect(_draw_face)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_face)
	var column := UiKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var head := UiKit.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_child(head)
	_name = UiKit.title("", 16, UiKit.ACCENT)
	_name.add_theme_constant_override("shadow_offset_x", 0)
	_name.add_theme_constant_override("shadow_offset_y", 0)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_note = UiKit.label("", UiKit.SMALL_SIZE)
	_note.add_theme_constant_override("shadow_offset_x", 0)
	_note.add_theme_constant_override("shadow_offset_y", 0)
	head.add_child(_note)
	_text = UiKit.label("", UiKit.FONT_SIZE, INK)
	_text.add_theme_constant_override("shadow_offset_x", 0)
	_text.add_theme_constant_override("shadow_offset_y", 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH - 12.0 * FACE_PX - 72.0
	column.add_child(_text)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	column.add_child(_buttons)
	_more = UiKit.label("▼", UiKit.FONT_SIZE, INK_SOFT)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_constant_override("shadow_offset_x", 0)
	_more.add_theme_constant_override("shadow_offset_y", 0)
	column.add_child(_more)
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
		_text.visible_characters = -1
	else:
		pressed.emit(index)


func _on_event(event: String) -> void:
	for call in _calls:
		if call.get("event", "") == event and _fits(call):
			_enqueue(call)


func _process(_delta: float) -> void:
	if _open:
		_process_typing()
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
	_was_running = DayCycle.running
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
	# Возвращаем то состояние, что было до звонка, а не «всегда идёт» (баг: часы шли под кино-моментом).
	DayCycle.running = _was_running
	_player.frozen = _moment.is_playing() or DayCycle.phase in [DayCycle.Phase.NIGHT, DayCycle.Phase.REPORT, DayCycle.Phase.OVER]


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
	_text.visible_characters = 0
	_letters = 0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_characters", text.length(), text.length() / LETTERS_PER_SECOND)
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_choices = choices.size()
	_more.visible = choices.is_empty()
	for i in choices.size():
		var can := _can(choices[i].get("need", {}))
		var why := "RADIO_CANT_BOND" if choices[i].get("need", {}).has("bonds") else "RADIO_CANT"
		var label := "%d. %s" % [i + 1, tr(choices[i]["text"])] + ("" if can else " (%s)" % tr(why))
		var button := _choice_button(label, pressed.emit.bind(i))
		button.disabled = not can
		_buttons.add_child(button)


## Ответ — светлая деревянная плашка с тёмным текстом, подсвечивается под курсором.
func _choice_button(text: String, on_press: Callable) -> Button:
	var button := UiKit.button(text, on_press)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiKit.box("ui_choice_hover" if state in ["hover", "pressed"] else "ui_choice", 4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", INK_SOFT)
	return button


## Мигающий «▼» и тихий звук печати.
func _process_typing() -> void:
	_more.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.006)) if not (_typing and _typing.is_running()) else 0.15
	if _typing and _typing.is_running() and _text.visible_characters >= _letters + BLIP_EVERY:
		_letters = _text.visible_characters
		Audio.play("blip")


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _choices == 0:
		press(-1)


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


## Пробел, Enter или E — «дальше», когда выбора нет; 1–3 — ответ. Esc не трогаем: пауза работает и в разговоре.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	var typing := _typing and _typing.is_running()
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E] and (_choices == 0 or typing):
		press(-1)
	elif _choices > 0 and not typing and event.keycode >= KEY_1 and event.keycode < KEY_1 + _choices:
		var button: Button = _buttons.get_child(event.keycode - KEY_1)
		if not button.disabled:
			pressed.emit(event.keycode - KEY_1)

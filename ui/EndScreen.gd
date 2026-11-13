# Экран конца игры: победа со звёздами и рекордом или поражение. Открывает Main. Владелец: B.
extends Control

signal restart_pressed()
signal retry_pressed()      # поражение: начать последний день заново с утра

const STAR := 48
const STAR_KEYS := ["END_STARS_1", "END_STARS_2", "END_STARS_3"]
const MISSING_TINT := Color(0.25, 0.27, 0.34)


func _ready() -> void:
	UiKit.setup_root(self)
	visible = false


func open(won: bool) -> void:
	for child in get_children():
		child.queue_free()
	add_child(UiKit.dim())
	var list := UiKit.window(self)
	_add(list, UiKit.title(tr("END_WIN_TITLE" if won else "END_LOSE_TITLE"), UiKit.TITLE_SIZE, UiKit.GOOD if won else UiKit.BAD))
	_add(list, UiKit.label(tr("END_WIN_TEXT" if won else "END_LOSE_TEXT")))
	if won:   # эпилог зависит от решений по рации: чью орбиту выбрал игрок и помогал ли он аулу
		for key in _epilogue():
			_add(list, UiKit.label(tr(key), UiKit.FONT_SIZE, UiKit.ACCENT))
	if won:
		_add_stars(list)
	_add(list, UiKit.label(tr("END_STATS") % [GameState.delivered_total, int(round(GameState.automation() * 100.0))]))
	if won and Settings.submit_record(GameState.stars(), GameState.automation()):
		_add(list, UiKit.label(tr("END_RECORD"), UiKit.FONT_SIZE, UiKit.ACCENT))
	if not won and not SaveManager.read().is_empty():
		_add_button(list, "END_RETRY", func() -> void: retry_pressed.emit())
	_add_button(list, "END_RESTART", func() -> void: restart_pressed.emit())
	visible = true


func _add_button(list: VBoxContainer, key: String, on_press: Callable) -> void:
	var button := UiKit.button(tr(key), on_press)
	button.custom_minimum_size.x = 260
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(button)


func _epilogue() -> Array:
	var flags := GameState.story_flags
	if flags.has("orbit_city"):
		return ["END_EPILOGUE_CITY"]
	if flags.has("orbit_both"):
		return ["END_EPILOGUE_BOTH"]
	var helped := int(flags.has("pump")) + int(flags.has("erzhan"))
	return ["END_EPILOGUE_%d" % helped] + (["END_ORBIT_AUL"] if flags.has("orbit_aul") else [])


## Три звезды с подписями: полученные — золотые, остальные — тёмные.
func _add_stars(list: VBoxContainer) -> void:
	var stars := GameState.stars()
	for i in STAR_KEYS.size():
		var row := UiKit.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon := UiKit.icon(Sprites.icon("star"), STAR)
		icon.modulate = Color.WHITE if i < stars else MISSING_TINT
		row.add_child(icon)
		row.add_child(UiKit.label(tr(STAR_KEYS[i]), UiKit.FONT_SIZE, UiKit.TEXT if i < stars else UiKit.MUTED))
		list.add_child(row)


func _add(list: VBoxContainer, label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(label)

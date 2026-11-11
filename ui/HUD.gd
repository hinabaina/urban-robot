# Верхняя панель: день, часы, квота склада, доверие, карманы, автоматизация, скорость и пауза. Владелец: B.
extends Control

signal pause_pressed()

const BAR_SIZE := Vector2(210, 24)
const AUTO_BAR_SIZE := Vector2(110, 16)
const HEART := 28
const POCKET_ICON := 24
const EDGE := 8

var _orb: TextureRect
var _day: Label
var _clock: Label
var _quota_bar: ProgressBar
var _quota_text: Label
var _hearts: Array[TextureRect] = []
var _pockets := {}            # тип -> Label
var _auto_label: Label
var _auto_bar: ProgressBar
var _speed_buttons := {}      # скорость -> Button


func _ready() -> void:
	UiKit.setup_root(self)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, EDGE)
	add_child(panel)
	var row := UiKit.hbox(14)
	panel.add_child(row)
	_build_left(row)
	_spacer(row)
	_build_center(row)
	_spacer(row)
	_build_right(row)
	GameState.quota_changed.connect(_on_quota)
	GameState.trust_changed.connect(_on_trust)
	GameState.pockets_changed.connect(_on_pockets)
	GameState.day_settled.connect(func(_r: Dictionary) -> void: _on_automation())
	DayCycle.speed_changed.connect(func(_s: float) -> void: _on_speed())
	_on_quota(Sim.storage_count("ingot"), GameState.display_quota())
	_on_trust(GameState.trust)
	_on_pockets()
	_on_automation()
	_on_speed()


func _build_left(row: HBoxContainer) -> void:
	_orb = UiKit.icon(Sprites.icon("sun"))
	_day = UiKit.label("")
	_clock = UiKit.title("06:00", UiKit.TITLE_SIZE, UiKit.ACCENT)
	for node in [_orb, _day, _clock]:
		row.add_child(node)


func _build_center(row: HBoxContainer) -> void:
	row.add_child(UiKit.icon(Sprites.item("ingot"), POCKET_ICON))
	row.add_child(UiKit.label(tr("HUD_STORAGE")))
	_quota_bar = ProgressBar.new()
	_quota_bar.custom_minimum_size = BAR_SIZE
	_quota_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quota_bar.show_percentage = false
	row.add_child(_quota_bar)
	_quota_text = UiKit.label("", UiKit.SMALL_SIZE)
	_quota_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quota_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quota_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quota_bar.add_child(_quota_text)
	var hearts := UiKit.hbox(2)
	row.add_child(hearts)
	for i in int(GameConfig.days()["start"]["trust"]):
		var heart := UiKit.icon(Sprites.icon("heart"), HEART)
		hearts.add_child(heart)
		_hearts.append(heart)


func _build_right(row: HBoxContainer) -> void:
	for type in Sprites.ITEMS:
		row.add_child(UiKit.icon(Sprites.item(type), POCKET_ICON))
		_pockets[type] = UiKit.label("0")
		_pockets[type].custom_minimum_size.x = 30
		row.add_child(_pockets[type])
	var auto := UiKit.vbox(0)
	auto.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(auto)
	_auto_label = UiKit.label("", UiKit.SMALL_SIZE, UiKit.MUTED)
	auto.add_child(_auto_label)
	_auto_bar = ProgressBar.new()
	_auto_bar.custom_minimum_size = AUTO_BAR_SIZE
	_auto_bar.show_percentage = false
	_auto_bar.max_value = 1.0
	auto.add_child(_auto_bar)
	for value in GameConfig.days()["clock"]["speeds"]:
		var button := UiKit.button("×%d" % int(value), DayCycle.set_user_speed.bind(value))
		button.toggle_mode = true
		_speed_buttons[value] = button
		row.add_child(button)
	var pause := UiKit.button("II", func() -> void: pause_pressed.emit())
	pause.tooltip_text = tr("HUD_PAUSE_TIP")
	row.add_child(pause)


func _spacer(row: HBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)


func _process(_delta: float) -> void:
	_clock.text = DayCycle.clock_text()
	_day.text = tr("HUD_DAY") % [GameState.day, GameConfig.total_days()]
	var h := fmod(DayCycle.hour, 24.0)
	_orb.texture = Sprites.icon("sun" if h >= 6.0 and h < 18.5 else "moon")


func _on_quota(have: int, need: int) -> void:
	_quota_bar.max_value = need
	_quota_bar.value = have
	_quota_text.text = tr("HUD_QUOTA") % [have, need]
	var done := have >= need
	_quota_text.add_theme_color_override("font_color", UiKit.GOOD if done else UiKit.TEXT)


func _on_trust(value: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = Sprites.icon("heart" if i < value else "heart_empty")


func _on_pockets() -> void:
	for type in _pockets:
		var count: int = GameState.pockets.get(type, 0)
		_pockets[type].text = str(count)
		var full := count >= GameConfig.pocket_limit(type)
		_pockets[type].add_theme_color_override("font_color", UiKit.ACCENT if full else UiKit.TEXT)


func _on_automation() -> void:
	_auto_label.text = tr("HUD_AUTOMATION") % int(round(GameState.automation() * 100.0))
	_auto_bar.value = GameState.automation()


func _on_speed() -> void:
	for value in _speed_buttons:
		_speed_buttons[value].set_pressed_no_signal(is_equal_approx(value, DayCycle.user_speed()))

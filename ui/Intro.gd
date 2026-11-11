# Вступительный ролик перед первой игрой: картинка (IntroStage), голос рассказчика, субтитры, звук. Владелец: A.
# Длина каждой сцены подстраивается под длину своей реплики, поэтому голос и картинка не расходятся.
# Пропуск: кнопка, Esc, Пробел, Enter или клик. По окончании шлёт finished и исчезает сам.
class_name Intro
extends Control

signal finished()

const VIEW_SIZE := Vector2i(320, 180)
const AUDIO := "res://assets/audio/"
const LINES := 7
const MIN_SECONDS := [4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 3.0]   # сцена не короче этого; обычно длину задаёт голос
const PAD_SECONDS := 0.4                                      # пауза после реплики до следующей сцены
const VOICE_DELAY := 0.35                                     # реплика начинается чуть позже картинки
const LIGHTNING := [0.42, 0.58, 0.74]                         # доли сцены бури с молниями
const QUOTA := 120
const FADE := 0.6
const SUB_SIZE := 28
const COUNTER_SIZE := 30

var _stage: Node2D
var _subtitle: Label
var _counter: Label
var _days: Label
var _title: Label
var _black: ColorRect
var _voice := AudioStreamPlayer.new()
var _wind := AudioStreamPlayer.new()
var _drone := AudioStreamPlayer.new()
var _music := AudioStreamPlayer.new()
var _starts: Array[float] = []
var _lengths: Array[float] = []
var _voices: Array[AudioStream] = []
var _time := 0.0
var _scene := -1
var _strikes := 0
var _last_count := -1
var _done := false
var _music_volume := 1.0          # громкость музыки игрока; музыку игры глушим на время ролика


func _ready() -> void:
	UiKit.setup_root(self)
	_music_volume = Audio.music_volume
	Audio.music_volume = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_view()
	_build_text()
	_build_audio()
	_build_timeline()
	_black.color.a = 1.0
	create_tween().tween_property(_black, "color:a", 0.0, FADE)


## Полная длина ролика в секундах.
func length() -> float:
	return _starts[-1] + _lengths[-1]


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time >= length():
		skip()
		return
	var index := _starts.size() - 1
	while _starts[index] > _time:
		index -= 1
	if index != _scene:
		_enter(index)
	var u := _time - _starts[index]
	_stage.u = u
	_stage.dur = _lengths[index]
	_update_scene(index, u / _lengths[index])


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	var click: bool = event is InputEventMouseButton and event.pressed
	if key or click:
		get_viewport().set_input_as_handled()
		skip()


## Закончить ролик: затемнение, сигнал finished, затем ролик растворяется и удаляется.
func skip() -> void:
	if _done:
		return
	_done = true
	Audio.music_volume = _music_volume
	for player in [_voice, _wind, _drone, _music]:
		create_tween().tween_property(player, "volume_db", -60.0, FADE)
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FADE * 0.6)
	tween.tween_callback(func() -> void:
		_stage.get_parent().get_parent().visible = false
		for label in [_subtitle, _counter, _days, _title]:
			label.visible = false
		finished.emit())
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)


# --- Сцены ------------------------------------------------------------------

func _enter(index: int) -> void:
	_scene = index
	_stage.scene = index
	_subtitle.text = tr("INTRO_%d" % (index + 1))
	if index < _voices.size() and _voices[index] != null:
		get_tree().create_timer(VOICE_DELAY).timeout.connect(func() -> void:
			if not _done and _scene == index:
				_voice.stream = _voices[index]
				_voice.play())
	match index:
		IntroStage.Scene.DROUGHT:
			_play_loop(_wind, "intro_wind", -14.0)
			_play_loop(_drone, "intro_drone", -10.0)
		IntroStage.Scene.STORM:
			create_tween().tween_property(_wind, "volume_db", -2.0, _lengths[index] * 0.5)
		IntroStage.Scene.SATELLITE:
			create_tween().tween_property(_wind, "volume_db", -22.0, 1.0)
		IntroStage.Scene.STATION:
			create_tween().tween_property(_drone, "volume_db", -40.0, 2.0)
			_play_loop(_music, "music_steppe", -12.0)
		IntroStage.Scene.TITLE:
			_title.visible = true
			_title.modulate.a = 0.0
			create_tween().tween_property(_title, "modulate:a", 1.0, 0.8)


func _update_scene(index: int, p: float) -> void:
	_counter.visible = index in [IntroStage.Scene.QUOTA, IntroStage.Scene.FACTORY]
	_days.visible = index == IntroStage.Scene.QUOTA
	if index == IntroStage.Scene.STORM:
		while _strikes < LIGHTNING.size() and p >= LIGHTNING[_strikes]:
			_strikes += 1
			_stage.flash = 1.0
			_stage.shake = 1.0
			_play_sfx("intro_thunder", -2.0)
	var count := 0
	if index == IntroStage.Scene.QUOTA:
		count = int(p * 4.0)                              # руками: 3 слитка за всю сцену
	elif index == IntroStage.Scene.FACTORY:
		count = int(lerpf(3.0, QUOTA, smoothstep(0.05, 0.6, p)))
		if p > 0.62 and _last_count < QUOTA + 1:
			_last_count = QUOTA + 1
			_play_sfx("rocket", 0.0)
	if _counter.visible and count != _last_count and _last_count <= QUOTA:
		if index == IntroStage.Scene.QUOTA or count % 12 == 0:
			_play_sfx("ingot", -8.0)
		_last_count = count
	_counter.text = "%d / %d" % [mini(count, QUOTA), QUOTA]
	_counter.add_theme_color_override("font_color", UiKit.GOOD if count >= QUOTA else UiKit.TEXT)
	if index == IntroStage.Scene.QUOTA and fposmod(_stage.u * 9.0 / TAU, 1.0) < 0.05:
		_play_sfx("dig", -10.0)


# --- Сборка ------------------------------------------------------------------

func _build_view() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 4
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(view)
	_stage = IntroStage.new()
	view.add_child(_stage)


func _build_text() -> void:
	_subtitle = _outlined(SUB_SIZE, UiKit.TEXT)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top = -150
	_subtitle.offset_bottom = -36
	_subtitle.offset_left = 120
	_subtitle.offset_right = -120
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_counter = _outlined(COUNTER_SIZE, UiKit.TEXT)
	_counter.position = Vector2(48, 40)
	_counter.add_child(_ingot_icon())
	_days = _outlined(COUNTER_SIZE - 6, UiKit.ACCENT)
	_days.position = Vector2(48, 88)
	_days.text = tr("HUD_DAY") % [1, 5]
	_title = UiKit.title("DALA WORKS", 72, UiKit.ACCENT)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.offset_top = -160
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", UiKit.SHADOW)
	add_child(_title)
	_title.visible = false
	for label in [_counter, _days]:
		label.visible = false
	var skip_button := UiKit.button(tr("INTRO_SKIP") + "  ›", skip)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_button.position += Vector2(-24, 20)
	skip_button.focus_mode = Control.FOCUS_NONE
	add_child(skip_button)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)


func _outlined(size: int, color: Color) -> Label:
	var label := UiKit.label("", size, color)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", UiKit.SHADOW)
	add_child(label)
	return label


func _ingot_icon() -> TextureRect:
	var icon := UiKit.icon(Sprites.item("ingot"), 36)
	icon.position = Vector2(-44, 4)
	return icon


func _build_audio() -> void:
	for player in [_voice, _wind, _drone, _music]:
		add_child(player)
	_voice.volume_db = 2.0
	for i in LINES:
		_voices.append(_load(AUDIO + "intro_vo_%d.ogg" % (i + 1)))


func _build_timeline() -> void:
	var start := 0.0
	for i in LINES:
		var voice := _voices[i]
		var need := VOICE_DELAY + voice.get_length() + PAD_SECONDS if voice != null else 0.0
		var seconds := maxf(float(MIN_SECONDS[i]), need)
		_starts.append(start)
		_lengths.append(seconds)
		start += seconds


func _play_loop(player: AudioStreamPlayer, sound: String, volume: float) -> void:
	var stream := _load(AUDIO + sound + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	player.stream = stream
	player.volume_db = volume + linear_to_db(maxf(_music_volume, 0.001))
	player.play()


func _play_sfx(sound: String, volume: float) -> void:
	var stream := _load(AUDIO + sound + ".wav")
	if stream == null or Audio.sfx_volume <= 0.0:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume + linear_to_db(Audio.sfx_volume)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null

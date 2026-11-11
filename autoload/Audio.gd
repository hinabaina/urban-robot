# Звук и музыка: короткие эффекты по имени из assets/audio и фоновая мелодия. Владелец: B.
extends Node

const DIR := "res://assets/audio/"
const VOICES := 8                  # сколько эффектов может звучать сразу
const MIN_GAP_MS := 45             # один и тот же звук не чаще этого: иначе слипается в треск
const MUSIC := "music_steppe"
const MUSIC_DB := -14.0
const FINAL_DAY_PITCH := 1.12      # в последний день музыка бодрее
const BLOCKED_EVERY := 5.0         # тихий сигнал «машина стоит» раз в столько секунд

var sfx_volume := 1.0: set = set_sfx_volume
var music_volume := 0.7: set = set_music_volume

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}                 # имя -> AudioStream или null, если файла нет
var _last_played := {}             # имя -> время (мс)
var _music := AudioStreamPlayer.new()
var _blocked := {}                 # клетки машин в состоянии BLOCKED
var _blocked_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	add_child(_music)
	_music.stream = _stream(MUSIC, ".ogg")
	if _music.stream is AudioStreamOggVorbis:
		_music.stream.loop = true
	set_music_volume(music_volume)
	Sim.item_delivered.connect(func(type: String, _by_hand: bool) -> void: play("deliver") if type == "ingot" else null)
	Sim.machine_state_changed.connect(_on_machine_state)
	Sim.machine_removed.connect(func(cell: Vector2i) -> void: _blocked.erase(cell))


## Проиграть короткий звук по имени файла без расширения ("dig", "place", "error"...).
func play(sound: String) -> void:
	var stream := _stream(sound, ".wav")
	var now := Time.get_ticks_msec()
	if stream == null or sfx_volume <= 0.0 or now - int(_last_played.get(sound, -1000)) < MIN_GAP_MS:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.play()


func start_music() -> void:
	if _music.stream and not _music.playing:
		_music.play()
	_music.pitch_scale = FINAL_DAY_PITCH if GameState.day >= GameConfig.total_days() else 1.0


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_music.volume_db = MUSIC_DB + linear_to_db(maxf(music_volume, 0.0001))


func _stream(sound: String, extension: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + extension
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _on_machine_state(cell: Vector2i, state: int) -> void:
	if state == Sim.State.BLOCKED:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)


func _process(delta: float) -> void:
	_blocked_timer += delta
	if _blocked_timer >= BLOCKED_EVERY:
		_blocked_timer = 0.0
		if not _blocked.is_empty() and DayCycle.phase == DayCycle.Phase.DAY and not get_tree().paused:
			play("blocked")

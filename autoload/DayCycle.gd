# Часы игры: день → дрон → вечер → ночь ×20 → отчёт. Двигает симуляцию через Sim.advance(). Владелец: B.
extends Node

signal day_started(day: int)
signal evening()                 # 18:00, прилетел дрон
signal night_started()
signal day_ended(day: int)       # ночь прошла, пора показывать отчёт
signal phase_changed(phase: int)
signal speed_changed(speed: float)

enum Phase { DAY, DRONE, EVENING, NIGHT, REPORT, OVER }

var hour := 6.0                  # игровое время; ночью продолжает расти за 24 до утра
var speed := 1.0                 # фактическая скорость симуляции: 1, 2 или 20
var phase: int = Phase.DAY
var drone_t := 0.0               # 0..1, ход визита дрона (читает view/Drone.gd)
var clock_scale := 1.0           # замедление часов на обучении (симуляция не замедляется)
var running := false             # Main включает после загрузки мира

var _clock: Dictionary = {}
var _user_speed := 1.0
var _settled := false
var _sim_time := 0.0             # сколько времени отдано симуляции (для сглаживания отрисовки)


func _ready() -> void:
	_clock = GameConfig.days()["clock"]
	reset()


func reset() -> void:
	hour = _clock["day_start_hour"]
	_user_speed = 1.0
	drone_t = 0.0
	_set_phase(Phase.DAY)


func set_user_speed(value: float) -> void:
	_user_speed = value if _clock["speeds"].has(value) else 1.0
	_update_speed()


func user_speed() -> float:
	return _user_speed


func can_sleep() -> bool:
	return phase == Phase.EVENING


func sleep() -> void:
	if can_sleep():
		_set_phase(Phase.NIGHT)
		night_started.emit()


## Кнопка «Утро» в ночном отчёте.
func next_morning() -> void:
	if phase != Phase.REPORT:
		return
	GameState.start_next_day()
	hour = _clock["day_start_hour"]
	_set_phase(Phase.DAY)
	day_started.emit(GameState.day)


## Часы строкой «14:20» (шаг 10 игровых минут, чтобы цифры не мельтешили).
func clock_text() -> String:
	var h := fmod(hour, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 6.0) * 10]


func tick_step() -> float:
	return float(_clock["sim_tick"])


## Доля текущего тика симуляции 0..1 (тики идут каждые sim_tick секунд времени симуляции).
func tick_alpha() -> float:
	return fmod(_sim_time, tick_step()) / tick_step()


func is_night() -> bool:
	return phase == Phase.NIGHT


func _process(delta: float) -> void:
	if not running or phase == Phase.REPORT or phase == Phase.OVER:
		return
	var sim_dt := delta * speed
	Sim.advance(sim_dt)
	_sim_time += sim_dt
	match phase:
		Phase.DAY:
			_advance_clock(sim_dt, _clock["drone_hour"])
			if hour >= _clock["drone_hour"]:
				drone_t = 0.0
				_settled = false
				_set_phase(Phase.DRONE)
				evening.emit()
		Phase.DRONE:
			drone_t = minf(1.0, drone_t + delta / float(_clock["drone_seconds"]))
			if not _settled and drone_t >= _clock["drone_pickup_at"]:
				_settled = true
				GameState.settle_day()
			if drone_t >= 1.0:
				_set_phase(Phase.OVER if GameState.finished else Phase.EVENING)
		Phase.EVENING:
			_advance_clock(sim_dt, _clock["sleep_hour"])
			if hour >= _clock["sleep_hour"]:
				GameState.notify("NOTICE_AUTO_SLEEP")   # 22:00 — засыпаешь там, где стоишь
				sleep()
		Phase.NIGHT:
			var morning: float = 24.0 + float(_clock["day_start_hour"])
			_advance_clock(sim_dt, morning)
			if hour >= morning:
				_set_phase(Phase.REPORT)
				day_ended.emit(GameState.day)


func _advance_clock(sim_dt: float, limit: float) -> void:
	var scale := clock_scale if phase == Phase.DAY else 1.0
	hour = minf(limit, hour + sim_dt * scale / float(_clock["seconds_per_hour"]))


func _set_phase(value: int) -> void:
	phase = value
	_update_speed()
	phase_changed.emit(phase)


func _update_speed() -> void:
	var new_speed: float = _clock["night_speed"] if phase == Phase.NIGHT else _user_speed
	if phase == Phase.DRONE:
		new_speed = 1.0
	if not is_equal_approx(new_speed, speed):
		speed = new_speed
		speed_changed.emit(speed)
	speed = new_speed

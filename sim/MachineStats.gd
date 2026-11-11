class_name MachineStats
extends RefCounted
## Статистика одной машины: состояния и выпуск за последние 30 с (рентген)
## и счётчики за отчётный период (ночной отчёт). Владелец: A.

var _states := PackedByteArray()
var _made := PackedByteArray()
var _next := 0
var _filled := 0
## Состояние -> сколько тиков машина провела в нём с начала периода.
var period: Dictionary = {}
var period_ticks := 0


## Записать итог одного тика. window: длина окна в тиках.
func record(state: int, made: int, window: int) -> void:
	if _states.size() != window:
		_states.resize(window)
		_made.resize(window)
		_next = 0
		_filled = 0
	_states[_next] = state
	_made[_next] = made
	_next = (_next + 1) % window
	_filled = mini(_filled + 1, window)
	period[state] = int(period.get(state, 0)) + 1
	period_ticks += 1


## Доля тиков окна в состоянии state, 0..1.
func share(state: int) -> float:
	if _filled == 0:
		return 0.0
	var count := 0
	for i in _filled:
		if _states[i] == state:
			count += 1
	return float(count) / _filled


## Сколько предметов машина выпускает в минуту по последним тикам окна.
func per_minute(tick_seconds: float) -> float:
	if _filled == 0:
		return 0.0
	var total := 0
	for i in _filled:
		total += _made[i]
	return total * 60.0 / (_filled * tick_seconds)


## Доля периода в состоянии state, 0..1.
func period_share(state: int) -> float:
	return float(period.get(state, 0)) / period_ticks if period_ticks > 0 else 0.0


func reset_period() -> void:
	period.clear()
	period_ticks = 0

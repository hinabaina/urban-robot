extends Node
## Часы игры: день, вечер, ночь, скорость. Автозагрузка `DayCycle`.
## Владелец: B. Сейчас это заглушка каркаса с полями и сигналами из docs/CONTRACT.md.

signal day_started(day: int)
signal evening
signal night_started
signal day_ended(day: int)

## Игровой час, 0..24.
var hour := 6.0
## Множитель скорости: 1, 2 или 20 (ночь). Числа лежат в data/days.json.
var speed := 1.0
## Пока false, время стоит и симуляция не тикает (меню, пауза, отчёт).
var running := false


func _process(delta: float) -> void:
	if not running:
		return
	# Единственное место в игре, которое двигает симуляцию.
	Sim.advance(delta * speed)
	# TODO(B5): двигать hour, в 18:00 дрон (evening), в 22:00 сон (night_started),
	# утром day_ended и day_started. TODO(B7): ночь на скорости night_speed.

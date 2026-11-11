class_name SimReport
extends RefCounted
## Цифры для рентгена и ночного отчёта. GDD «Рентген», «Ночной отчёт». Владелец: A.

## Машины, которые могут быть узким местом.
const PRODUCERS: Array[String] = ["drill", "furnace", "harvester", "sprinkler"]
## Состояния простоя.
const STALLED: Array[int] = [Machine.State.BLOCKED, Machine.State.NO_FUEL, Machine.State.NO_WATER,
	Machine.State.EXHAUSTED]

## Сколько чего произведено с начала отчётного периода.
var made: Dictionary = {}
var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim
	reset_period()


func note_made(item_type: String) -> void:
	made[item_type] = int(made.get(item_type, 0)) + 1


func reset_period() -> void:
	made = {Item.ORE: 0, Item.GRAIN: 0, Item.INGOT: 0}
	for machine: Machine in _sim.grid.machines():
		machine.stats.reset_period()


## Доли времени в состояниях за последние 30 с и выпуск в минуту. {} если машины нет.
func machine_stats(cell: Vector2i) -> Dictionary:
	var machine: Machine = _sim.grid.machine_at(cell)
	if machine == null:
		return {}
	var stats := machine.stats
	return {
		"working": stats.share(Machine.State.WORKING), "blocked": stats.share(Machine.State.BLOCKED),
		"no_fuel": stats.share(Machine.State.NO_FUEL), "idle": stats.share(Machine.State.IDLE),
		"per_min": stats.per_minute(_sim.data.tick_seconds()),
	}


## Итоги периода. Узкое место: машина, которая дольше всех простояла; пусто, если простоев не было.
func summary() -> Dictionary:
	var worst := {}
	for machine: Machine in _sim.grid.machines():
		for state in STALLED if PRODUCERS.has(machine.type) else []:
			var share := machine.stats.period_share(state)
			if share > float(worst.get("share", 0.0)):
				worst = {"cell": machine.cell, "type": machine.type, "state": state, "share": share}
	return {"made": made.duplicate(), "bottleneck": worst}

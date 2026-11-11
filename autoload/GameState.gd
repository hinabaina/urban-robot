extends Node
## Состояние партии: день, доверие, карманы, квоты. Автозагрузка `GameState`.
## Владелец: B. Сейчас это заглушка каркаса с полями и сигналами из docs/CONTRACT.md.

signal quota_changed(have: int, need: int)
signal trust_changed(value: int)
signal pockets_changed(pockets: Dictionary)

const DAYS_PATH := "res://data/days.json"

var config: Dictionary = {}
var day := 1
var trust := 0
var pockets := {"ore": 0, "grain": 0, "ingot": 0}


func _ready() -> void:
	config = SimData.load_json(DAYS_PATH)
	new_game()


func new_game() -> void:
	day = 1
	trust = int(config.get("trust", 0))
	pockets = config.get("player", {}).get("start_pockets", pockets).duplicate()
	pockets_changed.emit(pockets)
	trust_changed.emit(trust)


## Открыт ли чертёж машины в текущий день (день открытия лежит в data/machines.json).
func is_unlocked(machine_type: String) -> bool:
	return day >= int(Sim.machine_config(machine_type).get("unlock_day", 1))


func can_afford(cost: Dictionary) -> bool:
	for item_type in cost.keys():
		if int(pockets.get(item_type, 0)) < int(cost[item_type]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for item_type in cost.keys():
		pockets[item_type] = int(pockets.get(item_type, 0)) - int(cost[item_type])
	pockets_changed.emit(pockets)
	return true


## Сколько ещё предметов каждого типа влезет в карманы. Передаётся в Sim.take().
func room() -> Dictionary:
	var limits: Dictionary = config.get("player", {}).get("pocket_limits", {})
	var result := {}
	for item_type in limits.keys():
		result[item_type] = maxi(0, int(limits[item_type]) - int(pockets.get(item_type, 0)))
	return result


func to_dict() -> Dictionary:
	return {"day": day, "trust": trust, "pockets": pockets.duplicate()}


func from_dict(save: Dictionary) -> void:
	day = int(save.get("day", 1))
	trust = int(save.get("trust", trust))
	pockets = save.get("pockets", pockets).duplicate()
	pockets_changed.emit(pockets)
	trust_changed.emit(trust)

# TODO(B5): квоты и дрон (quota_changed), доверие, излишек на завтра, статистика
# автоматизации по сигналу Sim.item_delivered и результату Sim.storage_take_for_drone().

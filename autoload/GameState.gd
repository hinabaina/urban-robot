# Состояние партии: день, доверие, карманы, чертежи, сдача квот и счёт автоматизации. Владелец: B.
extends Node

signal quota_changed(have: int, need: int)
signal trust_changed(value: int)
signal pockets_changed()
signal unlocked_changed()
signal day_settled(result: Dictionary)   # {day, quota, taken, ok, auto, part}
signal game_over(won: bool)
signal notice(key: String)               # короткое сообщение игроку (ключ перевода)
signal happened(event: String)           # событие для обучения: "placed:drill", "campfire_loaded"...

var day := 1
var trust := 3
var pockets := {"ore": 0, "grain": 10, "ingot": 0}
var water := 0                    # сколько поливов осталось в лейке
var unlocked: Array[String] = []
var rocket: Array = []            # по дням: {part: String, patched: bool}
var delivered_total := 0
var delivered_auto := 0
var finished := false


func _ready() -> void:
	Sim.item_delivered.connect(func(_type: String, _by_hand: bool) -> void: emit_quota())
	new_game()


func new_game() -> void:
	var start: Dictionary = GameConfig.days()["start"]
	from_dict({"day": 1, "trust": start["trust"], "pockets": start["pockets"], "unlocked": start["unlocked"]})


func notify(key: String) -> void:
	notice.emit(key)


func report(event: String) -> void:
	happened.emit(event)


func quota() -> int:
	return int(GameConfig.day(day)["quota"])


## Квота для табло: после визита дрона склад уже копит на завтрашнюю.
func display_quota() -> int:
	var settled_today := rocket.size() >= day
	return int(GameConfig.day(day + 1 if settled_today else day)["quota"])


func emit_quota() -> void:
	quota_changed.emit(Sim.storage_count("ingot"), display_quota())


## Положить в карманы до лимита. Возвращает, сколько реально поместилось.
func add_pocket(type: String, count: int = 1) -> int:
	var accepted := clampi(count, 0, GameConfig.pocket_limit(type) - int(pockets.get(type, 0)))
	if accepted > 0:
		pockets[type] = int(pockets.get(type, 0)) + accepted
		pockets_changed.emit()
	return accepted


func can_afford(cost: Dictionary) -> bool:
	for type in cost:
		if int(pockets.get(type, 0)) < int(cost[type]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for type in cost:
		pockets[type] = int(pockets.get(type, 0)) - int(cost[type])
	pockets_changed.emit()


func set_water(value: int) -> void:
	water = value
	pockets_changed.emit()


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## Доля слитков, сданных без участия рук (0..1) за всю игру.
func automation() -> float:
	return float(delivered_auto) / float(delivered_total) if delivered_total > 0 else 0.0


## Звёзды итога: запуск, ни одной потери доверия, автоматизация выше порога из days.json.
func stars() -> int:
	if trust <= 0 or rocket.size() < GameConfig.total_days():
		return 0
	var clean := trust >= int(GameConfig.days()["start"]["trust"])
	var automated := automation() >= float(GameConfig.days()["stars"]["automation_for_third"])
	return 1 + int(clean) + int(automated)


## Дрон забирает квоту (вызывает DayCycle в момент погрузки).
func settle_day() -> Dictionary:
	var need := quota()
	var items: Array = Sim.storage_take_for_drone(need)
	var auto := items.filter(func(item: Variant) -> bool: return not item.get("by_hand")).size()
	delivered_total += items.size()
	delivered_auto += auto
	var ok := items.size() >= need
	if not ok:
		trust -= 1
		trust_changed.emit(trust)
	var part: String = GameConfig.day(day)["rocket_part"]
	rocket.append({"part": part, "patched": not ok})
	var result := {"day": day, "quota": need, "taken": items.size(), "ok": ok, "auto": auto, "part": part}
	day_settled.emit(result)
	emit_quota()
	if trust <= 0 or day >= GameConfig.total_days():
		finished = true
		game_over.emit(trust > 0)
	return result


## Утро следующего дня: подарок вечернего дрона (чертежи и ресурсы) становится доступен.
func start_next_day() -> void:
	var gift: Dictionary = GameConfig.day(day).get("gift", {})
	for id in gift.get("unlock", []):
		if not unlocked.has(id):
			unlocked.append(id)
	for type in gift.get("pockets", {}):
		add_pocket(type, int(gift["pockets"][type]))
	day += 1
	_emit_all()


func to_dict() -> Dictionary:
	return {"day": day, "trust": trust, "pockets": pockets.duplicate(), "water": water, "unlocked": unlocked.duplicate(),
		"rocket": rocket.duplicate(true), "delivered_total": delivered_total, "delivered_auto": delivered_auto}


## Восстановить состояние (загрузка сохранения или новая игра). Отсутствующие поля — как в начале партии.
func from_dict(d: Dictionary) -> void:
	day = int(d["day"])
	trust = int(d["trust"])
	pockets = {}
	for type in d["pockets"]:
		pockets[type] = int(d["pockets"][type])
	unlocked.assign(d["unlocked"])
	water = int(d.get("water", 0))
	rocket = d.get("rocket", []).duplicate(true)
	delivered_total = int(d.get("delivered_total", 0))
	delivered_auto = int(d.get("delivered_auto", 0))
	finished = false
	_emit_all()


func _emit_all() -> void:
	trust_changed.emit(trust)
	pockets_changed.emit()
	unlocked_changed.emit()
	emit_quota()

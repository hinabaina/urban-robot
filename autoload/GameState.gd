# Состояние партии: день, доверие, карманы, чертежи, квоты и статистика сдачи. Владелец: B.
extends Node

signal quota_changed(have: int, need: int)
signal trust_changed(value: int)
signal pockets_changed()
signal unlocked_changed()
signal day_settled(result: Dictionary)   # {day, quota, taken, ok, auto, part}
signal game_over(won: bool)
signal notice(key: String)             # короткое сообщение игроку (ключ перевода)
signal happened(event: String)         # игровое событие для обучения: "placed:drill", "campfire_loaded"...

const DAYS_PATH := "res://data/days.json"
const PLAYER_PATH := "res://data/player.json"

var config: Dictionary = {}
var player_config: Dictionary = {}
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
	config = load_json(DAYS_PATH)
	player_config = load_json(PLAYER_PATH)
	Sim.item_delivered.connect(func(_type: String, _by_hand: bool) -> void: emit_quota())
	new_game()


static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "нет файла данных: " + path)
	return JSON.parse_string(file.get_as_text())


func new_game() -> void:
	var start: Dictionary = config["start"]
	day = 1
	trust = int(start["trust"])
	pockets = {}
	for type in start["pockets"]:
		pockets[type] = int(start["pockets"][type])
	unlocked.assign(start["unlocked"])
	water = 0
	rocket = []
	delivered_total = 0
	delivered_auto = 0
	finished = false
	_emit_all()


func notify(key: String) -> void:
	notice.emit(key)


func report(event: String) -> void:
	happened.emit(event)


func set_water(value: int) -> void:
	water = value
	pockets_changed.emit()


func total_days() -> int:
	return config["days"].size()


func day_config(day_number: int = day) -> Dictionary:
	return config["days"][clampi(day_number, 1, total_days()) - 1]


func quota() -> int:
	return int(day_config()["quota"])


## Квота для табло: после визита дрона склад уже копит на завтрашнюю.
func display_quota() -> int:
	var settled_today := rocket.size() >= day
	return int(day_config(day + 1 if settled_today else day)["quota"])


func emit_quota() -> void:
	quota_changed.emit(Sim.storage_count("ingot"), display_quota())


func pocket_limit(type: String) -> int:
	return int(player_config["pocket_limits"].get(type, 0))


## Положить в карманы до лимита. Возвращает, сколько реально поместилось.
func add_pocket(type: String, count: int = 1) -> int:
	var accepted := clampi(count, 0, pocket_limit(type) - int(pockets.get(type, 0)))
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


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## День (1..N), утром которого чертёж уже доступен; 0 — с начала игры; -1 — нигде не выдаётся.
func unlock_day(id: String) -> int:
	if config["start"]["unlocked"].has(id):
		return 0
	for i in total_days():
		if config["days"][i].get("gift", {}).get("unlock", []).has(id):
			return i + 2
	return -1


## Доля слитков, сданных без участия рук (0..1) за всю игру.
func automation() -> float:
	return float(delivered_auto) / float(delivered_total) if delivered_total > 0 else 0.0


## Дрон забирает квоту (вызывает DayCycle в момент погрузки).
func settle_day() -> Dictionary:
	var need := quota()
	var items: Array = Sim.storage_take_for_drone(need)
	var auto := 0
	for item in items:
		if not item.get("by_hand"):
			auto += 1
	delivered_total += items.size()
	delivered_auto += auto
	var ok := items.size() >= need
	if not ok:
		trust -= 1
		trust_changed.emit(trust)
	rocket.append({"part": day_config()["rocket_part"], "patched": not ok})
	var result := {"day": day, "quota": need, "taken": items.size(), "ok": ok, "auto": auto, "part": day_config()["rocket_part"]}
	day_settled.emit(result)
	emit_quota()
	if trust <= 0 or day >= total_days():
		finished = true
		game_over.emit(trust > 0)
	return result


## Утро следующего дня: подарок вечернего дрона (чертежи и ресурсы) становится доступен.
func start_next_day() -> void:
	var gift: Dictionary = day_config().get("gift", {})
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


func from_dict(d: Dictionary) -> void:
	day = int(d["day"])
	trust = int(d["trust"])
	pockets = {}
	for type in d["pockets"]:
		pockets[type] = int(d["pockets"][type])
	unlocked.assign(d["unlocked"])
	water = int(d.get("water", 0))
	rocket = d["rocket"].duplicate(true)
	delivered_total = int(d["delivered_total"])
	delivered_auto = int(d["delivered_auto"])
	finished = false
	_emit_all()


func _emit_all() -> void:
	trust_changed.emit(trust)
	pockets_changed.emit()
	unlocked_changed.emit()
	emit_quota()

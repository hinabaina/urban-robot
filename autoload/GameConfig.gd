# Данные баланса B из JSON: дни (data/days.json) и игрок (data/player.json). Статический класс, не автозагрузка. Владелец: B.
class_name GameConfig

const DAYS_PATH := "res://data/days.json"
const PLAYER_PATH := "res://data/player.json"

static var _days: Dictionary = {}
static var _player: Dictionary = {}


static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "нет файла данных: " + path)
	return JSON.parse_string(file.get_as_text())


## Весь days.json: start, clock, days, stars.
static func days() -> Dictionary:
	if _days.is_empty():
		_days = load_json(DAYS_PATH)
	return _days


## Весь player.json: скорости, лимиты карманов, хотбар.
static func player() -> Dictionary:
	if _player.is_empty():
		_player = load_json(PLAYER_PATH)
	return _player


static func total_days() -> int:
	return days()["days"].size()


## Настройки дня с номером 1..N (номер вне диапазона прижимается к краю).
static func day(number: int) -> Dictionary:
	return days()["days"][clampi(number, 1, total_days()) - 1]


## Сколько слитков нужно сдать за всю игру.
static func total_quota() -> int:
	var total := 0
	for d in days()["days"]:
		total += int(d["quota"])
	return total


static func pocket_limit(type: String) -> int:
	return int(player()["pocket_limits"].get(type, 0))


## День (1..N), утром которого чертёж уже доступен; 0 — с начала игры; -1 — нигде не выдаётся.
static func unlock_day(id: String) -> int:
	if days()["start"]["unlocked"].has(id):
		return 0
	for i in total_days():
		if days()["days"][i].get("gift", {}).get("unlock", []).has(id):
			return i + 2
	return -1

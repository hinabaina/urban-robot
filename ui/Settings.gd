# Настройки игрока и личный рекорд в user://settings.cfg: громкость, язык, полный экран. Владелец: B.
class_name Settings

const PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {"music": 0.7, "sfx": 1.0, "locale": "ru", "fullscreen": false, "best_stars": 0, "best_automation": 0.0, "intro_seen": false, "locale_chosen": false}

static var _file: ConfigFile


static func _config() -> ConfigFile:
	if _file == null:
		_file = ConfigFile.new()
		_file.load(PATH)   # файла может не быть — тогда работают значения по умолчанию
	return _file


static func get_value(key: String) -> Variant:
	return _config().get_value(SECTION, key, DEFAULTS[key])


static func set_value(key: String, value: Variant) -> void:
	_config().set_value(SECTION, key, value)
	_config().save(PATH)
	apply()


## Применить настройки к игре (при запуске и после каждого изменения).
static func apply() -> void:
	Audio.music_volume = float(get_value("music"))
	Audio.sfx_volume = float(get_value("sfx"))
	var fullscreen: bool = get_value("fullscreen")
	var mode := DisplayServer.window_get_mode()
	if fullscreen != (mode == DisplayServer.WINDOW_MODE_FULLSCREEN):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Запомнить результат партии, если он лучше прежнего. Возвращает true для нового рекорда.
static func submit_record(stars: int, automation: float) -> bool:
	var better := stars > int(get_value("best_stars")) or (stars == int(get_value("best_stars"))
		and automation > float(get_value("best_automation")) + 0.001)
	if better:
		_config().set_value(SECTION, "best_stars", stars)
		set_value("best_automation", automation)
	return better

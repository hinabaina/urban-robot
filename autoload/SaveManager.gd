extends Node
## Сохранение в user://save.json. Автозагрузка `SaveManager`. Владелец: A.
## Игра сохраняется утром, после ночного отчёта. GDD «Сохранение».

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"


func _ready() -> void:
	# Ночной отчёт считает то, что фабрика сделала, пока игрок спал.
	DayCycle.night_started.connect(Sim.reset_period_stats)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Сохранить утро текущего дня. Сначала пишем во временный файл, потом заменяем им старый,
## чтобы сохранение не испортилось, если вкладку закроют посреди записи.
func save_morning() -> bool:
	var payload := {"version": SimSave.VERSION, "sim": Sim.to_dict(), "game": GameState.to_dict()}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var text := JSON.stringify(payload)
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) == OK:
		return true
	# Где переименование не поддерживается, пишем напрямую: лучше так, чем остаться без сохранения.
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


## Загрузить последнее утро («Продолжить», «Повторить день»). Мир должен быть уже загружен
## через Sim.load_world(). false, если файла нет, он повреждён или другой версии.
func load_morning() -> bool:
	var saved := read()
	if saved.is_empty() or not Sim.from_dict(saved["sim"]):
		return false
	GameState.from_dict(saved["game"])
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


## Содержимое сохранения, если оно есть и его версия подходит; иначе пустой словарь.
func read() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", -1)) != SimSave.VERSION:
		return {}
	if not parsed.has("sim") or not parsed.has("game"):
		return {}
	return parsed

extends Node
## Сохранение в user://save.json. Автозагрузка `SaveManager`. Владелец: A.
## Заглушка каркаса: методы контракта есть, запись на диск появится на этапе A9.

const SAVE_PATH := "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Сохранить игру (вызывается каждое утро после ночного отчёта).
func save_game() -> bool:
	# TODO(A9): собрать Sim.to_dict() и GameState.to_dict(), записать через временный файл.
	return false


## Загрузить последнее утреннее сохранение («Продолжить», «Повторить день»).
func load_game() -> bool:
	# TODO(A9): прочитать файл, проверить version, вызвать from_dict() у Sim и GameState.
	return false

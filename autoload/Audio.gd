# Звук и музыка. Пока только интерфейс: остальной код уже зовёт Audio.play(), звуки появятся в B12. Владелец: B.
extends Node

var sfx_volume := 1.0
var music_volume := 1.0


## Проиграть короткий звук по имени (например "dig", "place", "error").
func play(_sound: String) -> void:
	pass  # TODO(B12): AudioStreamPlayer-пул и файлы из assets/audio

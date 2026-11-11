class_name Vein
extends RefCounted
## Жила руды: один объект с общим запасом, тайлы только её картинка. GDD «Ручные действия».
## Владелец: A.

const INFINITE := -1

var id := 0
var cells: Array[Vector2i] = []
## Сколько руды осталось. INFINITE = бесконечная жила (глубокая порода).
var reserve := 0


func is_alive() -> bool:
	return reserve != 0

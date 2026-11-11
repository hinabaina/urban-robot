class_name TestWorld
extends RefCounted
## Маленькие миры для тестов, собранные кодом (без World.tscn). Владелец: A.

const STORAGE := Vector2i(12, 3)
const CAMPFIRE := Vector2i(9, 4)
const WELL := Vector2i(1, 4)
const PLOTS: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
const ORE := Vector2i(6, 7)


## Мир 16x12: небо y 0..4, почва y 5..6, камень y 7..9, коренная порода y 10..11.
static func small() -> Dictionary:
	var tiles := {}
	for x in 16:
		for y in range(5, 12):
			var kind := Tiles.Kind.SOIL
			if y >= 10:
				kind = Tiles.Kind.BEDROCK
			elif y >= 7:
				kind = Tiles.Kind.STONE
			tiles[Vector2i(x, y)] = kind
	tiles[ORE] = Tiles.Kind.ORE
	return {
		"size": Vector2i(16, 12),
		"tiles": tiles,
		"well": WELL,
		"plots": PLOTS,
		"prebuilt": [
			{"type": "storage", "cell": STORAGE, "dir": Vector2i.RIGHT},
			{"type": "campfire", "cell": CAMPFIRE, "dir": Vector2i.RIGHT},
		],
	}

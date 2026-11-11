class_name Tiles
extends RefCounted
## Виды тайлов мира. Владелец: A. Числа (время копания) лежат в data/world.json.

enum Kind { AIR, SOIL, STONE, DEEP, BEDROCK, ORE }

## Ключи слоёв в data/world.json -> вид тайла.
const KEYS := {
	"soil": Kind.SOIL,
	"stone": Kind.STONE,
	"deep": Kind.DEEP,
	"bedrock": Kind.BEDROCK,
	"ore": Kind.ORE,
}


static func key_of(kind: int) -> String:
	var found = KEYS.find_key(kind)
	return found if found != null else ""


static func is_solid(kind: int) -> bool:
	return kind != Kind.AIR

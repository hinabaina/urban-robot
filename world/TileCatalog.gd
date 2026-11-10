# Справочник тайлов: имя -> клетки атласа tiles.png и «вид» тайла. Владелец: B.
class_name TileCatalog

const TILE := 16
const MAP_SIZE := Vector2i(64, 40)
const ATLAS_PATH := "res://assets/sprites/tiles.png"
const LADDER_PATH := "res://assets/sprites/ladder.png"
const SOURCE_GROUND := 0
const SOURCE_LADDER := 1

# Порядок клеток совпадает с ORDER в tools/art/tiles.py.
const ATLAS := {
	"soil": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"grass": [Vector2i(3, 0), Vector2i(4, 0)],
	"bedrock": [Vector2i(5, 0), Vector2i(6, 0)],
	"farm_dry": [Vector2i(7, 0)],
	"stone": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"deep": [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)],
	"farm_wet": [Vector2i(6, 1)],
	"foundation": [Vector2i(7, 1)],
	"ore_soil": [Vector2i(0, 2), Vector2i(1, 2)],
	"ore_stone": [Vector2i(2, 2), Vector2i(3, 2)],
	"ore_deep": [Vector2i(4, 2), Vector2i(5, 2)],
	"wall_soil": [Vector2i(0, 3)],
	"wall_stone": [Vector2i(1, 3)],
	"wall_deep": [Vector2i(2, 3)],
}

# «Вид» тайла (custom data "kind"): по нему WorldLoader сообщает симуляции, что это за клетка.
const KIND := {
	"soil": "soil", "grass": "soil", "bedrock": "bedrock", "farm_dry": "farmland", "farm_wet": "farmland",
	"stone": "stone", "deep": "deep", "foundation": "foundation",
	"ore_soil": "ore", "ore_stone": "ore", "ore_deep": "ore",
}

# Символы раскладки world/layout.txt -> имя тайла.
const LAYOUT := {"g": "grass", "s": "soil", "t": "stone", "d": "deep", "b": "bedrock", "F": "farm_dry", "P": "foundation"}


## Клетка атласа для тайла; вариант выбирается по координатам, чтобы узор не повторялся.
static func coords(tile_name: String, cell: Vector2i) -> Vector2i:
	var variants: Array = ATLAS[tile_name]
	return variants[absi(cell.x * 7 + cell.y * 13 + cell.x * cell.y) % variants.size()]


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


static func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).floor())


static func in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y

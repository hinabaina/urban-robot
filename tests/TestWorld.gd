class_name TestWorld
extends RefCounted
## Маленькие миры для тестов, собранные кодом (без World.tscn). Владелец: A.
## Небо y 0..11, почва y 12..18, камень y 19..28: те же строки, что в data/world.json.

const STORAGE := Vector2i(30, 10)
const CAMPFIRE := Vector2i(20, 11)
const PLOTS_X := [9, 10, 11, 12, 13]
const PLOT_Y := 12
const SMALL_VEIN := Vector2i(25, 14)   # слой почвы: запас 40
const DEEP_VEIN := Vector2i(40, 30)    # глубокая порода: бесконечная


static func tiles() -> Dictionary:
	var result := {}
	for x in 64:
		for y in range(12, 40):
			var kind := Tiles.Kind.SOIL
			if y >= 38:
				kind = Tiles.Kind.BEDROCK
			elif y >= 29:
				kind = Tiles.Kind.DEEP
			elif y >= 19:
				kind = Tiles.Kind.STONE
			result[Vector2i(x, y)] = kind
	for x in PLOTS_X:
		result[Vector2i(x, PLOT_Y)] = Tiles.Kind.FARMLAND
	for cell in [SMALL_VEIN, SMALL_VEIN + Vector2i.RIGHT, DEEP_VEIN, DEEP_VEIN + Vector2i.DOWN]:
		result[cell] = Tiles.Kind.ORE
	return result


## Чистый мир со складом и костром.
static func load() -> void:
	Sim.load_world(tiles())
	Sim.place_machine("storage", STORAGE, Vector2i.RIGHT)
	Sim.place_machine("campfire", CAMPFIRE, Vector2i.RIGHT)


## Прорыть горизонтальный коридор, чтобы в нём можно было ставить машины.
static func carve(from: Vector2i, size: Vector2i) -> void:
	for cell in Grid.rect_cells(from, size):
		if Sim.get_tile(cell) != Tiles.Kind.ORE:
			Sim.grid.set_tile(cell, Tiles.Kind.AIR)


## Линия конвейеров длиной count от start в направлении dir.
static func belt(start: Vector2i, dir: Vector2i, count: int) -> void:
	for i in count:
		Sim.place_machine("conveyor", start + dir * i, dir)


static func run(seconds: float) -> void:
	for i in roundi(seconds / Sim.data.tick_seconds()):
		Sim.tick()


static func ingots() -> int:
	return Sim.storage_count(Item.INGOT)


## Состояние мира одной строкой для сравнения. Проход через JSON уравнивает 4 и 4.0,
## как это происходит при записи сохранения на диск.
static func dump(state: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(state)), "", true)

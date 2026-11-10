# Корень World.tscn: отдаёт карту симуляции и ставит готовые постройки (лестница шахты, склад, костёр). Владелец: B.
extends Node2D

# Соответствие «вида» тайла числу TileKind симуляции. Единственное место, где B знает эти числа.
var _sim_kind := {
	"soil": Sim.Tile.SOIL, "stone": Sim.Tile.STONE, "deep": Sim.Tile.DEEP, "bedrock": Sim.Tile.BEDROCK,
	"ore": Sim.Tile.ORE, "farmland": Sim.Tile.FARMLAND, "foundation": Sim.Tile.BEDROCK,
}

# Обратное соответствие: чем рисовать клетку, когда симуляция меняет её вид (AIR -> пусто).
var _tile_of_sim := {
	Sim.Tile.SOIL: "soil", Sim.Tile.STONE: "stone", Sim.Tile.DEEP: "deep", Sim.Tile.BEDROCK: "bedrock",
	Sim.Tile.FARMLAND: "farm_dry",
}

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var prebuilt: TileMapLayer = $Prebuilt


## Собрать словарь клетка -> TileKind из слоя Ground.
func collect_tiles() -> Dictionary:
	var tiles := {}
	for cell in ground.get_used_cells():
		var kind: String = ground.get_cell_tile_data(cell).get_custom_data("kind")
		tiles[cell] = _sim_kind[kind]
	return tiles


## Новая игра: загрузить карту в симуляцию и поставить то, что стоит на карте с самого начала.
func start_new() -> void:
	Sim.load_world(collect_tiles())
	for cell in prebuilt.get_used_cells():
		Sim.place_machine("ladder", cell, Vector2i.DOWN)
	prebuilt.visible = false  # дальше лестницы рисует MachineView
	Sim.place_machine("storage", marker_cell("Storage"), Vector2i.RIGHT)
	Sim.place_machine("campfire", marker_cell("Campfire"), Vector2i.RIGHT)


func marker_cell(marker_name: String) -> Vector2i:
	return TileCatalog.cell_at(marker_pos(marker_name))


func marker_pos(marker_name: String) -> Vector2:
	return ($Markers.get_node(marker_name) as Marker2D).global_position


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(TileCatalog.MAP_SIZE * TileCatalog.TILE))


## «Вид» тайла в клетке ("soil", "ore", ...) или "" для воздуха.
func kind_at(cell: Vector2i) -> String:
	var data := ground.get_cell_tile_data(cell)
	return data.get_custom_data("kind") if data else ""


## Применить изменение клетки из симуляции (сигнал Sim.tile_changed) к слою Ground.
func apply_tile(cell: Vector2i, sim_kind: int) -> void:
	var tile_name: String = _tile_of_sim.get(sim_kind, "")
	if tile_name == "":
		ground.erase_cell(cell)
	else:
		ground.set_cell(cell, TileCatalog.SOURCE_GROUND, TileCatalog.coords(tile_name, cell))

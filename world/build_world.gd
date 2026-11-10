# Сборщик карты: читает world/layout.txt и пишет world/tileset.tres + world/World.tscn. Владелец: B.
# Запуск: godot --headless --path . --script res://world/build_world.gd
# После запуска сцену можно править руками в редакторе; повторный запуск её перезапишет.
extends SceneTree

const T := TileCatalog.TILE
# Объекты поверхности: имя -> [текстура, клетка левого нижнего тайла, ширина в тайлах].
const PROPS := {
	"Well": ["well.png", Vector2i(5, 11), 2],
	"Yurt": ["yurt.png", Vector2i(24, 11), 4],
	"Headframe": ["headframe.png", Vector2i(31, 11), 3],
}
# Метки: имя -> клетка. Их читает WorldLoader и остальная игра.
const MARKERS := {
	"Spawn": Vector2i(28, 11), "Bed": Vector2i(26, 11), "Well": Vector2i(5, 11), "Campfire": Vector2i(29, 11),
	"Storage": Vector2i(50, 10), "Rocket": Vector2i(57, 11), "DronePark": Vector2i(50, 3),
}


func _init() -> void:
	var tileset := _build_tileset()
	ResourceSaver.save(tileset, "res://world/tileset.tres")
	tileset = load("res://world/tileset.tres")
	var root := Node2D.new()
	root.name = "World"
	root.set_script(load("res://world/WorldLoader.gd"))
	var walls := _layer(root, "Walls", tileset, -10)
	var ground := _layer(root, "Ground", tileset, 0)
	var prebuilt := _layer(root, "Prebuilt", tileset, 1)
	_fill(walls, ground, prebuilt)
	for prop_name in PROPS:
		_prop(root, prop_name, PROPS[prop_name])
	var markers := Node2D.new()
	markers.name = "Markers"
	root.add_child(markers)
	markers.owner = root
	for marker_name in MARKERS:
		var m := Marker2D.new()
		m.name = marker_name
		m.position = TileCatalog.cell_center(MARKERS[marker_name])
		markers.add_child(m)
		m.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, "res://world/World.tscn")
	print("World.tscn saved, err=", err, " ground cells=", ground.get_used_cells().size())
	quit()


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var ground := TileSetAtlasSource.new()
	ground.texture = load(TileCatalog.ATLAS_PATH)
	ground.texture_region_size = Vector2i(T, T)
	ts.add_source(ground, TileCatalog.SOURCE_GROUND)
	var h := T * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for tile_name in TileCatalog.ATLAS:
		for c in TileCatalog.ATLAS[tile_name]:
			ground.create_tile(c)
			if not TileCatalog.KIND.has(tile_name):
				continue  # задние стенки: без столкновений и без «вида»
			var data := ground.get_tile_data(c, 0)
			data.set_custom_data("kind", TileCatalog.KIND[tile_name])
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	var ladder := TileSetAtlasSource.new()
	ladder.texture = load(TileCatalog.LADDER_PATH)
	ladder.texture_region_size = Vector2i(T, T)
	ts.add_source(ladder, TileCatalog.SOURCE_LADDER)
	ladder.create_tile(Vector2i.ZERO)
	return ts


func _layer(root: Node2D, layer_name: String, tileset: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.z_index = z
	root.add_child(layer)
	layer.owner = root
	return layer


func _fill(walls: TileMapLayer, ground: TileMapLayer, prebuilt: TileMapLayer) -> void:
	var lines := FileAccess.open("res://world/layout.txt", FileAccess.READ).get_as_text().split("\n", false)
	var wall_of := {"s": "wall_soil", "g": "wall_soil", "F": "wall_soil", "P": "wall_soil", "t": "wall_stone", "d": "wall_deep", "b": "wall_deep"}
	var ore_of := {"wall_soil": "ore_soil", "wall_stone": "ore_stone", "wall_deep": "ore_deep"}
	for y in lines.size():
		for x in lines[y].length():
			var ch := lines[y][x]
			var cell := Vector2i(x, y)
			if ch == ".":
				continue
			# Стенка за рудой и за лестницей берётся от соседа слева (тот же слой породы).
			var wall: String = wall_of.get(ch, wall_of.get(lines[y][maxi(x - 1, 0)], _wall_by_neighbors(lines, x, y, wall_of)))
			walls.set_cell(cell, TileCatalog.SOURCE_GROUND, TileCatalog.coords(wall, cell))
			if ch == "H":
				prebuilt.set_cell(cell, TileCatalog.SOURCE_LADDER, Vector2i.ZERO)
			elif ch == "o":
				ground.set_cell(cell, TileCatalog.SOURCE_GROUND, TileCatalog.coords(ore_of[wall], cell))
			else:
				ground.set_cell(cell, TileCatalog.SOURCE_GROUND, TileCatalog.coords(TileCatalog.LAYOUT[ch], cell))


func _wall_by_neighbors(lines: PackedStringArray, x: int, y: int, wall_of: Dictionary) -> String:
	for dx in range(1, lines[y].length()):
		for nx in [x - dx, x + dx]:
			if nx >= 0 and nx < lines[y].length() and wall_of.has(lines[y][nx]):
				return wall_of[lines[y][nx]]
	return "wall_soil"


func _prop(root: Node2D, prop_name: String, spec: Array) -> void:
	var sprite := Sprite2D.new()
	sprite.name = prop_name
	sprite.texture = load("res://assets/sprites/" + spec[0])
	sprite.centered = false
	sprite.z_index = -5
	var bottom_left: Vector2i = spec[1]
	var size := sprite.texture.get_size()
	sprite.position = Vector2(bottom_left.x * T + (spec[2] * T - size.x) * 0.5, (bottom_left.y + 1) * T - size.y)
	root.add_child(sprite)
	sprite.owner = root

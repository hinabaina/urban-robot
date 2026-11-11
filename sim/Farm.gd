class_name Farm
extends RefCounted
## Грядки: посадка, полив, рост, сбор. GDD «Ферма». Владелец: A.

var plots: Dictionary = {}  # Vector2i -> Crop
var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## Собрать грядки из тайлов FARMLAND (стартовая пашня).
func build() -> void:
	plots.clear()
	for cell in _sim.grid.tiles.keys():
		if _sim.grid.tiles[cell] == Tiles.Kind.FARMLAND:
			plots[cell] = Crop.new(cell)


## Зона колодца: не дальше radius тайлов от любой клетки колодца.
func in_water_zone(cell: Vector2i) -> bool:
	var well: Dictionary = _sim.data.world.get("well", {})
	for raw in well.get("cells", []):
		var offset := (cell - SimData.to_vec2i(raw)).abs()
		if maxi(offset.x, offset.y) <= int(well.get("radius", 0)):
			return true
	return false


## Грядки не дальше radius тайлов от клетки (по горизонтали и вертикали).
func around(center: Vector2i, radius: int) -> Array[Crop]:
	var result: Array[Crop] = []
	for crop: Crop in plots.values():
		var offset := (crop.cell - center).abs()
		if maxi(offset.x, offset.y) <= radius:
			result.append(crop)
	return result


## Можно ли создать новую грядку: почва на поверхности, в зоне колодца, лимит не исчерпан.
func can_add_plot(cell: Vector2i) -> bool:
	return (_sim.grid.get_tile(cell) == Tiles.Kind.SOIL
		and _sim.grid.get_tile(cell + Vector2i.UP) == Tiles.Kind.AIR
		and in_water_zone(cell)
		and plots.size() < int(_sim.data.farm().get("max_plots", 0)))


## Посадить зерно в пустую грядку или создать новую грядку на почве. Зерно списывает вызывающий.
func plant(cell: Vector2i) -> bool:
	if not plots.has(cell):
		if not can_add_plot(cell):
			return false
		plots[cell] = Crop.new(cell)
		_sim.grid.set_tile(cell, Tiles.Kind.FARMLAND)
		_sim.tile_changed.emit(cell, Tiles.Kind.FARMLAND)
	var crop: Crop = plots[cell]
	if crop.stage != Crop.Stage.EMPTY:
		return false
	crop.stage = Crop.Stage.SPROUT
	crop.growth_ticks = 0
	_emit(crop)
	return true


func water(cell: Vector2i) -> bool:
	var crop: Crop = plots.get(cell)
	if crop == null:
		return false
	var was_wet := crop.wet
	crop.wet_ticks = _sim.data.ticks(float(_sim.data.farm().get("wet_seconds", 0.0)))
	crop.wet = true
	if not was_wet:
		_emit(crop)
	return true


## Собрать зрелую грядку. Возвращает, сколько зерна получено (0, если не зрелая).
func harvest(cell: Vector2i) -> int:
	var crop: Crop = plots.get(cell)
	if crop == null or crop.stage != Crop.Stage.RIPE:
		return 0
	crop.stage = Crop.Stage.EMPTY
	crop.growth_ticks = 0
	_emit(crop)
	return int(_sim.data.farm().get("yield", 0))


## Фаза роста: влажная грядка растёт и понемногу сохнет.
func tick() -> void:
	var stage_ticks: int = _sim.data.ticks(float(_sim.data.farm().get("stage_seconds", 1.0)))
	for crop: Crop in plots.values():
		if not crop.wet:
			continue
		if crop.stage != Crop.Stage.EMPTY and crop.stage != Crop.Stage.RIPE:
			crop.growth_ticks += 1
			var stage := mini(Crop.Stage.RIPE, Crop.Stage.SPROUT + crop.growth_ticks / stage_ticks)
			if stage != crop.stage:
				crop.stage = stage
				_emit(crop)
		crop.wet_ticks -= 1
		if crop.wet_ticks <= 0:
			crop.wet = false
			_emit(crop)


func save() -> Array:
	return plots.values().map(func(crop: Crop) -> Dictionary: return crop.save())


## Заменить грядки сохранёнными и сообщить виду обо всех изменениях.
func restore(saved: Array) -> void:
	var old := plots
	plots = {}
	for entry in saved:
		var crop := Crop.load_from(entry)
		plots[crop.cell] = crop
		_emit(crop)
	for cell in old.keys():
		if not plots.has(cell):
			_sim.crop_changed.emit(cell, Crop.Stage.EMPTY, false)


func _emit(crop: Crop) -> void:
	_sim.crop_changed.emit(crop.cell, crop.stage, crop.wet)

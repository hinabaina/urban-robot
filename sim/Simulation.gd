class_name Simulation
extends Node
## Вся игровая логика фабрики. Автозагрузка `Sim`. Владелец: A.
## Не обращается к нодам сцены: наружу только сигналы и методы чтения.
## Это фасад: логика лежит в Grid, Veins, Farm, Placement, Transfers и машинах.
## Полное описание методов и сигналов: docs/CONTRACT.md.

signal ticked(tick: int)
signal tile_changed(cell: Vector2i, kind: int)
signal machine_placed(cell: Vector2i, type: String, dir: Vector2i)
signal machine_removed(cell: Vector2i)
signal machine_state_changed(cell: Vector2i, state: int)
signal item_delivered(type: String, by_hand: bool)
signal crop_changed(cell: Vector2i, stage: int, wet: bool)
signal vein_exhausted(vein_id: int)

const Tile = Tiles.Kind
const State = Machine.State
var data := SimData.new()
var grid := Grid.new()
var veins := Veins.new(self)
var farm := Farm.new(self)
var placement := Placement.new(self)
var transfers := Transfers.new(self)
var saver := SimSave.new(self)
var report := SimReport.new(self)
var tick_count := 0
## Длина окна статистики в тиках (30 с).
var stats_window := 1
var _accumulator := 0.0


func _init() -> void:
	data.load_all()
	stats_window = data.ticks(float(data.world.get("stats_window_seconds", 30.0)))


# --- Жизненный цикл -----------------------------------------------------------

## Новая игра: полностью сбрасывает симуляцию. tiles: Vector2i -> Tile, клетки без записи = воздух.
func load_world(tiles: Dictionary) -> void:
	placement.clear()
	grid.clear()
	grid.size = SimData.to_vec2i(data.world.get("size"), Vector2i.ZERO)
	grid.tiles = tiles.duplicate()
	veins.build()
	farm.build()
	tick_count = 0
	_accumulator = 0.0
	report.reset_period()


## Продвинуть симуляцию на dt секунд (dt уже умножен на скорость игры).
## Время режется на тики фиксированной длины, поэтому результат не зависит от FPS.
func advance(dt: float) -> void:
	_accumulator += maxf(dt, 0.0)
	while _accumulator >= data.tick_seconds():
		_accumulator -= data.tick_seconds()
		tick()


## Доля текущего тика 0..1, для сглаживания отрисовки между тиками.
func tick_alpha() -> float:
	return _accumulator / data.tick_seconds()


## Один тик (0,25 с). Порядок фаз из GDD: машины и движение -> рост -> переходы -> статистика.
func tick() -> void:
	tick_count += 1
	for machine in grid.machines():
		machine.tick()
	farm.tick()
	transfers.run()
	for machine in grid.machines():
		machine.end_tick()
	ticked.emit(tick_count)


# --- Команды игрока -----------------------------------------------------------

func can_place(type: String, cell: Vector2i, dir: Vector2i) -> Dictionary:
	return placement.can_place(type, cell, dir)

func place_machine(type: String, cell: Vector2i, dir: Vector2i) -> bool:
	return placement.place(type, cell, dir)

## Снести машину. Возвращает предметы, лежавшие внутри; цену возвращает B.
func remove_machine(cell: Vector2i) -> Array[Item]:
	return placement.remove(cell)

## Сколько секунд держать ЛКМ на тайле; 0, если копать нельзя.
func dig_time(cell: Vector2i) -> float:
	return data.dig_time(grid.get_tile(cell))

## Игрок докопал тайл. {"removed": тайл исчез, "ore": игрок получил 1 руду}.
func dig(cell: Vector2i) -> Dictionary:
	if dig_time(cell) <= 0.0:
		return {"removed": false, "ore": false}
	if grid.get_tile(cell) == Tile.ORE:
		return {"removed": false, "ore": veins.take_ore(veins.at(cell))}
	grid.set_tile(cell, Tile.AIR)
	tile_changed.emit(cell, Tile.AIR)
	return {"removed": true, "ore": false}

## E: положить один предмет из карманов в машину. Предмет помечается by_hand.
func insert(cell: Vector2i, item_type: String) -> bool:
	var machine := grid.machine_at(cell)
	var item := Item.new(item_type, true)
	if machine == null or not machine.can_accept(item, Machine.BY_HAND):
		return false
	machine.accept(item, Machine.BY_HAND)
	return true

## E: забрать предметы из машины. Всё взятое руками становится by_hand.
func take(cell: Vector2i) -> Array[Item]:
	var machine := grid.machine_at(cell)
	var items: Array[Item] = machine.take_by_hand() if machine != null else []
	for item in items:
		item.by_hand = true
	return items

## Игрок держит ЛКМ на костре dt секунд. true, когда готов слиток (в карманы кладёт B).
func campfire_work(dt: float) -> bool:
	for machine in grid.machines():
		if machine is Campfire and machine.has_recipe():
			return machine.work(dt)
	return false

func plant(cell: Vector2i) -> bool:
	return farm.plant(cell)

func water(cell: Vector2i) -> bool:
	return farm.water(cell)

func harvest(cell: Vector2i) -> int:
	return farm.harvest(cell)

## Дрон забирает до amount слитков со склада, самые старые первыми.
func storage_take_for_drone(amount: int) -> Array[Item]:
	var storage := _storage()
	var empty: Array[Item] = []
	return storage.take_for_drone(amount) if storage != null else empty


# --- Чтение состояния ---------------------------------------------------------

func get_tile(cell: Vector2i) -> int:
	return grid.get_tile(cell)

## Машины: у каждой читаются cell, type, dir, state.
func get_machines() -> Array[Machine]:
	return grid.machines()

## Предметы на конвейерах: у каждого читаются cell, dir, progress, type, by_hand.
func get_items() -> Array[Item]:
	var result: Array[Item] = []
	for machine in grid.machines():
		if machine is Conveyor and machine.item != null:
			result.append(machine.item)
	return result

## Грядки: у каждой читаются cell, stage (0 пусто .. 4 зрелая), wet.
func get_crops() -> Array:
	return farm.plots.values()

func is_in_water_zone(cell: Vector2i) -> bool:
	return farm.in_water_zone(cell)

func storage_count(item_type: String) -> int:
	var storage := _storage()
	return storage.count(item_type) if storage != null else 0

## Рентген: {"working", "blocked", "no_fuel", "idle"} (доли 0..1 за последние 30 с) и "per_min".
func get_stats(cell: Vector2i) -> Dictionary:
	return report.machine_stats(cell)

## Начать новый отчётный период (перед ночью).
func reset_period_stats() -> void:
	report.reset_period()

## Ночной отчёт: {"made": {"ore", "grain", "ingot"}, "bottleneck": {"cell", "type", "state", "share"}}.
func night_summary() -> Dictionary:
	return report.summary()

func to_dict() -> Dictionary:
	return saver.to_dict()

func from_dict(saved: Dictionary) -> bool:
	return saver.from_dict(saved)


func _storage() -> Storage:
	for machine in grid.machines():
		if machine is Storage:
			return machine
	return null

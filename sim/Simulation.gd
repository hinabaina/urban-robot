class_name Simulation
extends Node
## Вся игровая логика фабрики. Автозагрузка `Sim`. Владелец: A.
## Не обращается к нодам сцены: наружу только сигналы и методы чтения.
## Полное описание методов и сигналов: docs/CONTRACT.md.

signal world_loaded
signal ticked(tick: int)
signal tile_changed(cell: Vector2i, kind: int)
signal machine_placed(cell: Vector2i, type: String, dir: Vector2i)
signal machine_removed(cell: Vector2i, type: String)
signal machine_state_changed(cell: Vector2i, state: int)
signal item_delivered(type: String, by_hand: bool)
signal storage_changed(type: String, count: int)
signal crop_changed(cell: Vector2i, stage: int, wet: bool)
signal vein_exhausted(vein_id: int)

const SAVE_VERSION := 1

var data := SimData.new()
var grid := Grid.new()
var farm := Farm.new(self)
var mining := Mining.new(self)
var placement := Placement.new(self)
var tick_count := 0
var _accumulator := 0.0


func _ready() -> void:
	data.load_all()


# --- Жизненный цикл -----------------------------------------------------------

## Очистить мир (новая игра, загрузка, тесты).
func reset() -> void:
	grid.clear()
	farm.clear()
	tick_count = 0
	_accumulator = 0.0


## Загрузить стартовую карту. world: {"size": Vector2i, "tiles": {Vector2i: Tiles.Kind},
## "well": Vector2i, "plots": [Vector2i], "prebuilt": [{"type", "cell", "dir"}]}.
func load_world(world: Dictionary) -> void:
	reset()
	grid.size = world.get("size", SimData.to_vec2i(data.world.get("size"), Vector2i.ZERO))
	grid.tiles = world.get("tiles", {}).duplicate()
	farm.well = world.get("well", Vector2i.ZERO)
	for cell in world.get("plots", []):
		farm.add_plot(cell)
	for entry in world.get("prebuilt", []):
		placement.place(entry["type"], entry["cell"], entry.get("dir", Vector2i.RIGHT), true)
	world_loaded.emit()


## Продвинуть симуляцию на dt секунд (dt уже умножен на скорость игры).
## Внутри время режется на тики фиксированной длины, поэтому результат не зависит от FPS.
func advance(dt: float) -> void:
	var step := data.tick_seconds()
	if dt <= 0.0 or step <= 0.0:
		return
	_accumulator += dt
	while _accumulator >= step:
		_accumulator -= step
		tick()


## Один тик (0,25 с).
func tick() -> void:
	tick_count += 1
	# TODO(A2): порядок фаз из GDD: машины -> рост -> движение -> переходы -> статистика.
	for machine in grid.machines():
		machine.tick()
	farm.tick()
	ticked.emit(tick_count)


# --- Команды игрока -----------------------------------------------------------

func can_place(type: String, cell: Vector2i, dir: Vector2i) -> Dictionary:
	return placement.can_place(type, cell, dir)

func place_machine(type: String, cell: Vector2i, dir: Vector2i) -> bool:
	return placement.place(type, cell, dir)

func remove_machine(cell: Vector2i) -> Dictionary:
	return placement.remove(cell)

func dig_time(cell: Vector2i) -> float:
	return mining.dig_time(cell)

func dig(cell: Vector2i) -> Dictionary:
	return mining.dig(cell)

## E: положить один предмет из карманов в машину. Предмет помечается by_hand.
func insert(cell: Vector2i, item_type: String) -> bool:
	var machine := grid.machine_at(cell)
	var item := Item.new(item_type, true)
	if machine == null or not machine.can_accept(item, Machine.BY_HAND):
		return false
	machine.accept(item, Machine.BY_HAND)
	return true

## E: взять предметы из машины. room: сколько ещё влезет в карманы, {"ore": 12, ...}.
func take(cell: Vector2i, room: Dictionary) -> Dictionary:
	var machine := grid.machine_at(cell)
	return machine.take_by_hand(room) if machine != null else {}

## Игрок держит ЛКМ на костре dt секунд. true, когда готов слиток (в карманы кладёт B).
func campfire_work(cell: Vector2i, dt: float) -> bool:
	var campfire := grid.machine_at(cell) as Campfire
	return campfire.work(dt) if campfire != null else false

func can_plant(cell: Vector2i) -> Dictionary:
	return farm.can_plant(cell)

func plant(cell: Vector2i) -> bool:
	return farm.plant(cell)

func water(cell: Vector2i) -> bool:
	return farm.water(cell)

func harvest(cell: Vector2i) -> int:
	return farm.harvest(cell)

## Дрон забирает до amount слитков со склада: {"taken": int, "by_hand": int}.
func storage_take_for_drone(amount: int) -> Dictionary:
	var storage := _storage()
	return storage.take_for_drone(amount) if storage != null else {"taken": 0, "by_hand": 0}


# --- Чтение состояния ---------------------------------------------------------

func get_tile(cell: Vector2i) -> int:
	return grid.get_tile(cell)

func get_machine(cell: Vector2i) -> Dictionary:
	var machine := grid.machine_at(cell)
	return machine.describe() if machine != null else {}

func get_machines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for machine in grid.machines():
		result.append(machine.describe())
	return result

## Предметы на конвейерах: [{"type", "cell", "dir", "progress", "by_hand", "stuck"}].
func get_items() -> Array[Dictionary]:
	return []  # TODO(A3): появятся вместе с конвейером.

func get_crops() -> Array[Dictionary]:
	return farm.snapshot()

func is_in_water_zone(cell: Vector2i) -> bool:
	return farm.in_water_zone(cell)

func storage_count(item_type: String) -> int:
	var storage := _storage()
	return storage.count(item_type) if storage != null else 0

func machine_types() -> Array:
	return data.machines.keys()

func machine_config(type: String) -> Dictionary:
	return data.machine(type)

## Доли времени в состояниях за последние 30 с и производительность, для рентгена.
func get_stats(_cell: Vector2i) -> Dictionary:
	# TODO(A3/A10): кольцевой буфер состояний. Пока нули.
	return {"working": 0.0, "blocked": 0.0, "no_fuel": 0.0, "idle": 1.0, "per_minute": 0.0}

## Начать новый отчётный период (вызывает DayCycle перед ночью).
func reset_period_stats() -> void:
	pass  # TODO(A8)

## Итоги периода для ночного отчёта.
func period_summary() -> Dictionary:
	# TODO(A8): считать произведённое и главное узкое место. Пока нули.
	return {"produced": {Item.ORE: 0, Item.GRAIN: 0, Item.INGOT: 0}, "bottleneck": {}}

func to_dict() -> Dictionary:
	# TODO(A9): полное сохранение мира, машин, предметов и фермы.
	return {"version": SAVE_VERSION, "tick": tick_count}

func from_dict(save: Dictionary) -> bool:
	# TODO(A9): восстановление. Пока только проверка версии.
	return int(save.get("version", -1)) == SAVE_VERSION


func _storage() -> Storage:
	for machine in grid.machines():
		if machine is Storage:
			return machine
	return null

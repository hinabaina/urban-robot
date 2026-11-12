class_name TestCampaign
extends RefCounted
## Фабрика пятого дня на настоящей карте: проверка, что квота 50 достижима
## полностью автоматической фабрикой из данных GDD. Владелец: A.
##
## Схема. Два бура на бесконечной жиле (y 31), у каждого своя лента наверх к своей печи:
## разветвителя в игре нет, поэтому одна лента не может кормить две печи.
## Ферма: 2 поливалки и 2 сборщика на 8 грядках у колодца, зерно едет в печи по лентам.
## Слитки обеих печей сливаются в одну ленту над землёй и едут на склад.

const DAY := 240.0            # сутки: 24 часа по 10 с
const QUOTA_DAY_5 := 50
const DRILL_A := Vector2i(30, 29)
const DRILL_B := Vector2i(33, 29)
const FURNACE_LEFT := Vector2i(7, 10)
const FURNACE_RIGHT := Vector2i(21, 10)
const STORAGE := Vector2i(50, 10)
const FIRST_DRILL := Vector2i(38, 10)
const FIRST_FURNACE := Vector2i(44, 10)

var _t: TestCase
var _cost := {}
var _failed: Array[String] = []


func run(t: TestCase, tree: SceneTree) -> void:
	_t = t
	t.group("Фабрика пятого дня на настоящей карте")
	var world: Node = load("res://world/World.tscn").instantiate()
	tree.root.add_child(world)
	world.start_new()
	_build()
	t.equal(_failed, [] as Array[String], "все машины встали на свои места через Sim.place_machine")
	TestWorld.run(120.0)      # разгон: ленты заполняются, грядки созревают
	Sim.storage_take_for_drone(999)
	Sim.reset_period_stats()
	TestWorld.run(DAY)
	var ingots := Sim.storage_take_for_drone(999)
	t.check(ingots.size() >= QUOTA_DAY_5, "за сутки на складе %d слитков при квоте %d" % [ingots.size(), QUOTA_DAY_5])
	t.check(ingots.all(func(item: Item) -> bool: return not item.by_hand),
		"ни одного слитка не касались руки: автоматизация 100%")
	var made: Dictionary = Sim.night_summary()["made"]
	t.check(int(made["grain"]) >= int(made["ingot"]), "ферма даёт зерна не меньше, чем сжигают печи (%d и %d)" % [made["grain"], made["ingot"]])
	for furnace in [FURNACE_LEFT, FURNACE_RIGHT]:
		t.check(float(Sim.get_stats(furnace)["no_fuel"]) < 0.05, "печь %s не простаивает без зерна" % furnace)
	print("    цена фабрики: %s, машин %d" % [_cost, Sim.get_machines().size()])
	world.queue_free()
	_first_line(t, tree)


## Первая линия дня 1: бур на рудном выходе у склада, лента, печь, лента, склад. Всё на поверхности, без копания.
## Посылка дрона (days.json, early_gift) должна покрывать её цену, а квота дня 1 набираться за минуту.
func _first_line(t: TestCase, tree: SceneTree) -> void:
	t.group("Первая линия дня 1 на поверхности")
	var world: Node = load("res://world/World.tscn").instantiate()
	tree.root.add_child(world)
	world.start_new()
	_failed.clear()
	_cost = {}
	_place("drill", FIRST_DRILL, Vector2i.RIGHT)
	_belt(Vector2i(40, 11), Vector2i.RIGHT, 4)
	_place("furnace", FIRST_FURNACE, Vector2i.RIGHT)
	_belt(Vector2i(46, 11), Vector2i.RIGHT, 4)
	t.equal(_failed, [] as Array[String], "бур, печь и 8 лент встают на поверхности без копания")
	var kit: Dictionary = GameConfig.day(1)["early_gift"]["pockets"]
	t.check(_cost.keys().all(func(type: String) -> bool: return int(_cost[type]) <= int(kit.get(type, 0))),
		"посылка дрона %s покрывает цену линии %s" % [kit, _cost])
	for i in 5:
		Sim.insert(FIRST_FURNACE, "grain")
	TestWorld.run(60.0)
	t.equal(Sim.storage_count("ingot"), 5, "одной закладки зерна (5) хватает на 5 слитков за минуту")
	for i in 4:       # норма дня 1 выше одной закладки: игрок подкидывает остаток стартового зерна
		Sim.insert(FIRST_FURNACE, "grain")
	TestWorld.run(60.0)
	var ingots := Sim.storage_count("ingot") + 1    # ещё один слиток игрок сдал руками до посылки
	t.check(ingots >= int(GameConfig.day(1)["quota"]), "со второй закладкой линия закрывает норму дня 1: %d при квоте %d" % [ingots, GameConfig.day(1)["quota"]])
	world.queue_free()


func _build() -> void:
	# Шахта: буры выдают руду вверх, в ряды y 28 и y 27.
	_dig_rect(DRILL_A, Vector2i(2, 2))
	_dig_rect(DRILL_B, Vector2i(2, 2))
	_place("drill", DRILL_A, Vector2i.UP)
	_place("drill", DRILL_B, Vector2i.UP)
	# Лента A: по ряду 28 влево и вверх по столбцу 7 в левую печь снизу.
	_belt(Vector2i(30, 28), Vector2i.LEFT, 23)
	_belt(Vector2i(7, 28), Vector2i.UP, 17)
	# Лента B: по ряду 27 влево и вверх по столбцу 22 в правую печь снизу.
	_belt(Vector2i(33, 28), Vector2i.UP, 1)
	_belt(Vector2i(33, 27), Vector2i.LEFT, 11)
	_belt(Vector2i(22, 27), Vector2i.UP, 16)
	# Печи выдают слитки вверх, на общую ленту в ряду 9.
	_place("furnace", FURNACE_LEFT, Vector2i.UP)
	_place("furnace", FURNACE_RIGHT, Vector2i.UP)
	_belt(Vector2i(7, 9), Vector2i.RIGHT, 42)
	_belt(Vector2i(49, 9), Vector2i.DOWN, 1)
	_belt(Vector2i(49, 10), Vector2i.RIGHT, 1)
	# Ферма: игрок один раз сажает 8 грядок, дальше всё делают машины.
	for x in range(9, 17):
		Sim.plant(Vector2i(x, 12))
	_place("sprinkler", Vector2i(12, 10), Vector2i.RIGHT)
	_place("sprinkler", Vector2i(15, 10), Vector2i.RIGHT)
	_place("harvester", Vector2i(10, 11), Vector2i.LEFT)
	_belt(Vector2i(9, 11), Vector2i.LEFT, 1)
	_place("harvester", Vector2i(15, 11), Vector2i.RIGHT)
	_belt(Vector2i(16, 11), Vector2i.RIGHT, 5)


func _place(type: String, cell: Vector2i, dir: Vector2i) -> void:
	if not Sim.place_machine(type, cell, dir):
		_failed.append("%s %s: %s" % [type, cell, Sim.can_place(type, cell, dir)["reason"]])
		return
	var price: Dictionary = Sim.data.machine(type).get("cost", {})
	for item in price:
		_cost[item] = int(_cost.get(item, 0)) + int(price[item])


## Лента длиной count от start в направлении dir; под землёй сначала копаем клетку, как игрок.
func _belt(start: Vector2i, dir: Vector2i, count: int) -> void:
	for i in count:
		var cell := start + dir * i
		_dig_rect(cell, Vector2i.ONE)
		_place("conveyor", cell, dir)


func _dig_rect(cell: Vector2i, size: Vector2i) -> void:
	for target in Grid.rect_cells(cell, size):
		if Sim.get_tile(target) != Tiles.Kind.AIR:
			Sim.dig(target)

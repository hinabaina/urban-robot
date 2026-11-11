class_name TestLogistics
extends RefCounted
## Конвейеры: скорость, обратное давление, лифт, слияние, петля. Владелец: A.
## Всё строится в небе (y < 12): симуляции физика не нужна.

const START := Vector2i(5, 5)


func run(t: TestCase) -> void:
	_speed(t)
	_back_pressure(t)
	_lift_and_turn(t)
	_merge(t)
	_loop(t)


func _feed(cell: Vector2i, type: String = Item.ORE) -> bool:
	var belt := Sim.grid.machine_at(cell)
	var item := Item.new(type, false)
	if not belt.can_accept(item, belt.dir):
		return false
	belt.accept(item, belt.dir)
	return true


func _speed(t: TestCase) -> void:
	t.group("Конвейер: 1 тайл в секунду")
	Sim.load_world({})
	TestWorld.belt(START, Vector2i.RIGHT, 10)
	Sim.place_machine("storage", START + Vector2i(10, 0), Vector2i.RIGHT)
	_feed(START)
	TestWorld.run(9.75)
	t.equal(Sim.storage_count(Item.ORE), 0, "за 9,75 с предмет ещё не доехал по 10 клеткам")
	t.equal(Sim.get_items().size(), 1, "предмет виден на конвейере")
	TestWorld.run(0.25)
	t.equal(Sim.storage_count(Item.ORE), 1, "ровно через 10 с предмет на складе")
	t.equal(Sim.get_items().size(), 0, "конвейер пуст")


func _back_pressure(t: TestCase) -> void:
	t.group("Обратное давление")
	Sim.load_world({})
	TestWorld.belt(START, Vector2i.RIGHT, 3)   # тупик: дальше ничего нет
	for i in 20:
		_feed(START)
		TestWorld.run(1.0)
	t.equal(Sim.get_items().size(), 3, "в тупике на 3 клетках стоят 3 предмета, лишние не влезли")
	t.check(not _feed(START), "занятый конвейер не принимает новый предмет")
	t.equal(Sim.grid.machine_at(START).state, Machine.State.BLOCKED, "конвейер в заторе: BLOCKED")
	t.check(Sim.get_items().all(func(item: Item) -> bool: return item.progress >= 1.0),
		"все предметы стоят у края клетки")
	TestWorld.belt(START + Vector2i(3, 0), Vector2i.RIGHT, 1)
	Sim.tick()
	var cells := Sim.get_items().map(func(item: Item) -> int: return item.cell.x - START.x)
	cells.sort()
	t.equal(cells, [1, 2, 3], "затор открыт: вся цепочка сдвинулась за один тик")
	var removed := Sim.remove_machine(START + Vector2i(1, 0))
	t.equal(removed.size(), 1, "снос конвейера возвращает лежавший на нём предмет")
	t.check(removed[0].by_hand, "предмет, взятый руками, помечен by_hand")


func _lift_and_turn(t: TestCase) -> void:
	t.group("Лифт и поворот")
	Sim.load_world({})
	TestWorld.belt(Vector2i(5, 9), Vector2i.UP, 4)          # лифт вверх: y 9..6
	TestWorld.belt(Vector2i(5, 5), Vector2i.RIGHT, 2)       # наверху поворот вправо
	Sim.place_machine("storage", Vector2i(7, 5), Vector2i.RIGHT)
	_feed(Vector2i(5, 9))
	TestWorld.run(6.0)
	t.equal(Sim.storage_count(Item.ORE), 1, "предмет поднялся на 4 клетки, повернул и доехал за 6 с")
	Sim.place_machine("conveyor", Vector2i(9, 9), Vector2i.RIGHT)
	Sim.place_machine("conveyor", Vector2i(10, 9), Vector2i.LEFT)
	_feed(Vector2i(9, 9))
	TestWorld.run(3.0)
	t.equal(Sim.grid.machine_at(Vector2i(10, 9)).state, Machine.State.IDLE,
		"встречный конвейер предмет не принимает")


func _merge(t: TestCase) -> void:
	t.group("Слияние потоков по очереди")
	Sim.load_world({})
	var joint := Vector2i(10, 5)
	TestWorld.belt(joint, Vector2i.RIGHT, 1)
	Sim.place_machine("storage", joint + Vector2i.RIGHT, Vector2i.RIGHT)
	Sim.place_machine("conveyor", joint + Vector2i.LEFT, Vector2i.RIGHT)   # ветка руды
	Sim.place_machine("conveyor", joint + Vector2i.UP, Vector2i.DOWN)      # ветка зерна
	for i in 400:
		_feed(joint + Vector2i.LEFT, Item.ORE)
		_feed(joint + Vector2i.UP, Item.GRAIN)
		Sim.tick()
	var ore := Sim.storage_count(Item.ORE)
	var grain := Sim.storage_count(Item.GRAIN)
	t.check(ore + grain >= 95, "общая клетка пропускает 1 предмет в секунду (%d за 100 с)" % (ore + grain))
	t.check(absi(ore - grain) <= 1, "ветки чередуются, ни одна не голодает (руда %d, зерно %d)" % [ore, grain])


func _loop(t: TestCase) -> void:
	t.group("Замкнутое кольцо")
	Sim.load_world({})
	var ring := {
		Vector2i(5, 5): Vector2i.RIGHT, Vector2i(6, 5): Vector2i.DOWN,
		Vector2i(6, 6): Vector2i.LEFT, Vector2i(5, 6): Vector2i.UP,
	}
	for cell in ring:
		Sim.place_machine("conveyor", cell, ring[cell])
	for cell in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6)]:
		_feed(cell)
	var first: Item = Sim.grid.machine_at(Vector2i(5, 5)).item
	TestWorld.run(8.0)
	t.equal(Sim.get_items().size(), 3, "кольцо со свободной клеткой крутится без потерь")
	t.equal(first.cell, Vector2i(5, 5), "за 8 с предмет прошёл 2 круга по 4 клетки и вернулся на место")
	for cell in ring:
		_feed(cell)   # влезет только в единственную свободную клетку
	TestWorld.run(8.0)
	t.equal(Sim.get_items().size(), 4, "кольцо заполнено целиком")
	t.check(Sim.grid.machines().all(func(m: Machine) -> bool: return m.state == Machine.State.BLOCKED),
		"полное кольцо стоит навсегда: это ошибка проектирования игрока, а не баг")

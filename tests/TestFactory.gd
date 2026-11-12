class_name TestFactory
extends RefCounted
## Бур, печь и вся линия: баланс GDD, by_hand, состояния, ночь x20. Владелец: A.

const DRILL := Vector2i(41, 30)      # касается бесконечной жилы TestWorld.DEEP_VEIN
const FURNACE := Vector2i(46, 30)
const STORAGE := Vector2i(48, 30)

var _auto_grain := false


func run(t: TestCase) -> void:
	Sim.ticked.connect(_keep_grain)
	_states(t)
	_balance(t)
	_by_hand(t)
	_night(t)
	_exhausted(t)
	Sim.ticked.disconnect(_keep_grain)


## Линия из GDD: бур -> 3 конвейера -> печь -> склад.
func _build(with_storage := true) -> void:
	Sim.load_world(TestWorld.tiles())
	TestWorld.carve(DRILL, Vector2i(9, 2))
	Sim.place_machine("drill", DRILL, Vector2i.RIGHT)
	TestWorld.belt(DRILL + Vector2i(2, 0), Vector2i.RIGHT, 3)
	Sim.place_machine("furnace", FURNACE, Vector2i.RIGHT)
	if with_storage:
		Sim.place_machine("storage", STORAGE, Vector2i.RIGHT)


## Замена фермы в тестах: каждый тик доливает печи зерно, не тронутое руками.
func _keep_grain(_tick: int) -> void:
	var furnace := Sim.grid.machine_at(FURNACE)
	var grain := Item.new(Item.GRAIN, false)
	if _auto_grain and furnace is Furnace and furnace.can_accept(grain, Vector2i.DOWN):
		furnace.accept(grain, Vector2i.DOWN)


func _states(t: TestCase) -> void:
	t.group("Состояния машин")
	Sim.load_world(TestWorld.tiles())
	t.equal(Sim.can_place("drill", Vector2i(5, 5), Vector2i.RIGHT)["reason"], "REASON_NEED_VEIN", "бур вдали от жилы")
	t.equal(Sim.can_place("furnace", Vector2i(5, 11), Vector2i.RIGHT)["reason"], "REASON_NOT_EMPTY", "печь 2x2 задевает землю")
	_auto_grain = false
	_build(false)
	t.equal(Sim.can_place("conveyor", DRILL + Vector2i.ONE, Vector2i.UP)["reason"], "REASON_OCCUPIED", "клетка занята буром")
	TestWorld.run(30.0)
	t.equal(Sim.grid.machine_at(FURNACE).state, Machine.State.NO_FUEL, "печь с рудой, но без зерна: NO_FUEL")
	_auto_grain = true
	TestWorld.run(120.0)
	t.equal(Sim.grid.machine_at(FURNACE).state, Machine.State.BLOCKED, "печь без склада: выход полон, BLOCKED")
	t.equal(Sim.grid.machine_at(DRILL).state, Machine.State.BLOCKED, "затор дошёл до бура: BLOCKED")
	t.check(float(Sim.get_stats(DRILL)["blocked"]) > 0.9, "рентген: бур простаивает больше 90% последних 30 с")
	Sim.reset_period_stats()
	TestWorld.run(60.0)
	var worst: Dictionary = Sim.night_summary()["bottleneck"]
	t.equal([worst.get("state"), worst.get("share")], [Machine.State.BLOCKED, 1.0],
		"ночной отчёт называет узкое место: %s простоял весь период" % worst.get("type"))
	t.equal(Sim.take(FURNACE).size(), 5, "игрок забирает из печи 5 слитков клавишей E")
	t.equal(Sim.remove_machine(FURNACE).size() > 0, true, "снос печи возвращает сырьё и слитки")


func _balance(t: TestCase) -> void:
	t.group("Баланс GDD: 1 бур + 1 печь")
	_auto_grain = true
	_build()
	TestWorld.run(200.0)   # сутки: 120 с дня + 80 с ночи
	t.near(TestWorld.ingots(), 25.0, 2.0, "слитков за сутки (в GDD около 25)")
	# Окно рентгена 30 с: в него попадает 7-8 руд и 3-4 слитка, отсюда допуск.
	t.near(float(Sim.get_stats(DRILL)["per_min"]), 15.0, 1.0, "бур: руды в минуту")
	t.near(float(Sim.get_stats(FURNACE)["per_min"]), 7.5, 1.5, "печь: слитков в минуту (ограничена рудой)")
	t.check(float(Sim.get_stats(DRILL)["working"]) > 0.95, "рентген: бур загружен, зелёный")
	t.equal(Sim.night_summary()["made"]["ore"], 50, "отчёт: добыто 50 руды")
	Sim.remove_machine(DRILL + Vector2i(2, 0))
	Sim.remove_machine(DRILL + Vector2i(3, 0))
	Sim.remove_machine(DRILL + Vector2i(4, 0))
	Sim.remove_machine(FURNACE)
	Sim.place_machine("furnace", DRILL + Vector2i(2, 0), Vector2i.RIGHT)
	t.check(Sim.grid.machine_at(DRILL).output_cell() == DRILL + Vector2i(2, 0), "печь стоит вплотную к буру")


func _by_hand(t: TestCase) -> void:
	t.group("Флаг «тронуто руками»")
	_auto_grain = true
	_build()
	TestWorld.run(60.0)
	var auto := Sim.storage_take_for_drone(99)
	t.check(auto.size() > 0 and auto.all(func(item: Item) -> bool: return not item.by_hand),
		"слитки с линии без участия игрока: by_hand = false")
	_auto_grain = false
	TestWorld.run(60.0)   # печь дожигает запас зерна и встаёт
	Sim.storage_take_for_drone(99)
	t.equal(Sim.grid.machine_at(FURNACE).state, Machine.State.NO_FUEL, "зерно кончилось: NO_FUEL")
	t.check(Sim.insert(FURNACE, Item.GRAIN), "игрок кладёт в печь 1 зерно руками")
	TestWorld.run(30.0)
	var touched := Sim.storage_take_for_drone(99)
	t.equal(touched.map(func(item: Item) -> bool: return item.by_hand), [false],
		"зерно-топливо из рук не делает слиток ручным (руда пришла с бура)")


func _night(t: TestCase) -> void:
	t.group("Ночь x20 даёт тот же результат, что x1")
	_auto_grain = true
	var normal := _play(200.0, 1.0)
	var fast := _play(200.0, 20.0)
	t.equal(fast["tick"], normal["tick"], "число тиков одинаково")
	t.equal(fast["ingot"], normal["ingot"], "число слитков одинаково")
	t.equal(TestWorld.dump(fast["save"]), TestWorld.dump(normal["save"]), "состояние мира совпадает полностью")


## Прожить seconds игровых секунд кадрами по 1/60 с на скорости speed.
func _play(seconds: float, speed: float) -> Dictionary:
	_build()
	for frame in roundi(seconds / speed * 60.0):
		Sim.advance(speed / 60.0)
	return {"tick": Sim.tick_count, "ingot": TestWorld.ingots(), "save": Sim.to_dict()}


func _exhausted(t: TestCase) -> void:
	t.group("Бур на жиле с запасом 40")
	Sim.load_world(TestWorld.tiles())
	var cell := TestWorld.SMALL_VEIN + Vector2i(2, -1)
	TestWorld.carve(cell, Vector2i(4, 2))
	Sim.place_machine("drill", cell, Vector2i.RIGHT)
	Sim.place_machine("storage", cell + Vector2i(2, 0), Vector2i.RIGHT)
	TestWorld.run(170.0)
	t.equal(Sim.storage_count(Item.ORE), 40, "бур добыл ровно 40 руды")
	t.equal(Sim.grid.machine_at(cell).state, Machine.State.EXHAUSTED, "жила пуста: EXHAUSTED")
	t.equal(Sim.get_tile(TestWorld.SMALL_VEIN), Tiles.Kind.STONE, "тайлы жилы стали камнем")

class_name TestFarm
extends RefCounted
## Ферма: рост, полив, новые грядки, поливалка, сборщик. Владелец: A.

const PLOT := Vector2i(9, 12)


func run(t: TestCase) -> void:
	_by_hand(t)
	_new_plots(t)
	_machines(t)


func _stage(cell: Vector2i) -> int:
	return Sim.farm.plots[cell].stage


func _by_hand(t: TestCase) -> void:
	t.group("Грядка руками")
	Sim.load_world(TestWorld.tiles())
	t.equal(Sim.get_crops().size(), 5, "грядки собраны из тайлов FARMLAND")
	t.check(Sim.plant(PLOT), "зерно посажено")
	t.check(not Sim.plant(PLOT), "дважды в одну грядку не сажается")
	TestWorld.run(20.0)
	t.equal(_stage(PLOT), Crop.Stage.SPROUT, "сухая грядка не растёт")
	t.check(Sim.water(PLOT), "грядка полита")
	TestWorld.run(14.75)
	t.check(Sim.farm.plots[PLOT].wet, "через 14,75 с ещё влажная")
	TestWorld.run(0.25)
	t.check(not Sim.farm.plots[PLOT].wet, "полив держится ровно 15 с")
	t.equal(_stage(PLOT), Crop.Stage.STALK, "за 15 влажных секунд выросла до колоса")
	t.equal(Sim.harvest(PLOT), 0, "незрелую грядку собрать нельзя")
	Sim.water(PLOT)
	TestWorld.run(15.0)
	t.equal(_stage(PLOT), Crop.Stage.RIPE, "два полива и 30 влажных секунд: зрелая")
	TestWorld.run(60.0)
	t.equal(_stage(PLOT), Crop.Stage.RIPE, "зрелая грядка ждёт сбора и не портится")
	t.equal(Sim.harvest(PLOT), 3, "сбор даёт 3 зерна")
	t.equal(_stage(PLOT), Crop.Stage.EMPTY, "после сбора грядка пустая")


func _new_plots(t: TestCase) -> void:
	t.group("Новые грядки")
	Sim.load_world(TestWorld.tiles())
	t.check(Sim.is_in_water_zone(Vector2i(16, 12)) and not Sim.is_in_water_zone(Vector2i(17, 12)),
		"зона колодца: 10 тайлов от колодца")
	t.check(Sim.plant(Vector2i(15, 12)), "новая грядка на почве в зоне колодца")
	t.equal(Sim.get_tile(Vector2i(15, 12)), Tiles.Kind.FARMLAND, "тайл стал пашней")
	t.check(not Sim.plant(Vector2i(30, 12)), "вне зоны колодца грядку не создать")
	t.check(not Sim.plant(Vector2i(15, 13)), "под землёй грядку не создать")
	for x in range(0, 17):
		Sim.plant(Vector2i(x, 12))
	Sim.dig(Vector2i(16, 12))
	t.check(Sim.get_crops().size() <= 24, "не больше 24 грядок (сейчас %d)" % Sim.get_crops().size())


func _machines(t: TestCase) -> void:
	t.group("Поливалка и сборщик")
	Sim.load_world(TestWorld.tiles())
	Sim.place_machine("sprinkler", Vector2i(40, 11), Vector2i.RIGHT)
	Sim.tick()
	t.equal(Sim.grid.machine_at(Vector2i(40, 11)).state, Machine.State.NO_WATER, "поливалка вне зоны колодца: NO_WATER")
	Sim.place_machine("sprinkler", Vector2i(11, 10), Vector2i.RIGHT)
	for x in TestWorld.PLOTS_X:
		Sim.plant(Vector2i(x, TestWorld.PLOT_Y))
	TestWorld.run(30.0)
	t.check(TestWorld.PLOTS_X.all(func(x: int) -> bool: return _stage(Vector2i(x, 12)) == Crop.Stage.RIPE),
		"под поливалкой все 5 грядок созрели за 30 с без единого ручного полива")
	Sim.place_machine("harvester", Vector2i(11, 11), Vector2i.RIGHT)
	TestWorld.run(120.0)
	var harvester := Sim.grid.machine_at(Vector2i(11, 11))
	t.equal(harvester.out.size(), 6, "без вывоза выход сборщика заполняется до 6")
	t.equal(harvester.state, Machine.State.BLOCKED, "сборщик ждёт: BLOCKED")
	t.check(TestWorld.PLOTS_X.any(func(x: int) -> bool: return _stage(Vector2i(x, 12)) == Crop.Stage.RIPE),
		"урожай остаётся на грядках")
	TestWorld.belt(Vector2i(12, 11), Vector2i.RIGHT, 18)
	Sim.place_machine("storage", Vector2i(30, 10), Vector2i.RIGHT)
	Sim.take(Vector2i(30, 10))
	TestWorld.run(180.0)
	var per_minute := Sim.storage_count(Item.GRAIN) / 3.0
	t.near(per_minute, 20.0, 3.0, "5 грядок под сборщиком дают зерна в минуту (в GDD 4 с грядки)")
	t.check(Sim.storage_take_for_drone(0).is_empty() and not Sim.grid.machine_at(Vector2i(30, 10)).contents()[0].by_hand,
		"зерно со сборщика не тронуто руками")

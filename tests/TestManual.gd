class_name TestManual
extends RefCounted
## Проверки ручных действий игрока: склад, костёр, копание, грядки. Владелец: A.


func run(t: TestCase, events: Array) -> void:
	Sim.load_world(TestWorld.small())
	_storage(t, events)
	_campfire(t)
	_digging(t, events)
	_farm(t, events)
	t.group("Сохранение (заглушка)")
	t.check(Sim.from_dict(Sim.to_dict()), "to_dict() и from_dict() согласованы по версии")
	t.check(not Sim.from_dict({"version": 999}), "чужая версия сохранения отклоняется")


func _storage(t: TestCase, events: Array) -> void:
	t.group("Склад и дрон")
	events.clear()
	var storage := TestWorld.STORAGE
	t.check(Sim.insert(storage, Item.INGOT), "игрок кладёт слиток на склад")
	t.equal(events, [["delivered", "ingot", true]], "сигнал item_delivered с by_hand = true")
	var machine := Sim.grid.machine_at(storage)
	machine.accept(Item.new(Item.INGOT, false), Vector2i.LEFT)
	machine.accept(Item.new(Item.INGOT, false), Vector2i.LEFT)
	t.check(Sim.insert(storage, Item.ORE), "склад принимает и руду")
	t.equal(Sim.storage_count(Item.INGOT), 3, "на складе 3 слитка")
	t.equal(Sim.take(storage, {"ore": 5, "ingot": 5}), {"ore": 1}, "руду забрать можно, слитки нет")
	t.equal(Sim.storage_take_for_drone(2), {"taken": 2, "by_hand": 1}, "дрон берёт квоту, старые первыми")
	t.equal(Sim.storage_count(Item.INGOT), 1, "излишек остался на складе")
	t.equal(Sim.storage_take_for_drone(10), {"taken": 1, "by_hand": 0}, "при недостаче дрон берёт всё")


func _campfire(t: TestCase) -> void:
	t.group("Костёр")
	var fire := TestWorld.CAMPFIRE
	t.check(not Sim.campfire_work(fire, 10.0), "пустой костёр не плавит")
	t.check(Sim.insert(fire, Item.ORE) and Sim.insert(fire, Item.ORE), "2 руды положены")
	t.check(not Sim.insert(fire, Item.ORE), "третья руда не влезает")
	t.check(not Sim.insert(fire, Item.INGOT), "слиток в костёр не кладётся")
	t.check(not Sim.campfire_work(fire, 10.0), "без зерна не плавит")
	t.check(Sim.insert(fire, Item.GRAIN), "зерно положено")
	t.check(not Sim.campfire_work(fire, 2.9), "2,9 с ещё мало")
	t.check(Sim.campfire_work(fire, 0.1), "через 3 с слиток готов")
	t.equal(Sim.get_machine(fire)["contents"], {}, "сырьё потрачено")


func _digging(t: TestCase, events: Array) -> void:
	t.group("Копание")
	events.clear()
	var soil := Vector2i(7, 5)
	t.equal(Sim.dig_time(soil), 0.4, "почва 0,4 с")
	t.equal(Sim.dig_time(TestWorld.ORE), 1.2, "руда 1,2 с")
	t.equal(Sim.dig_time(Vector2i(7, 10)), -1.0, "коренную породу копать нельзя")
	t.equal(Sim.dig_time(Vector2i(7, 2)), -1.0, "воздух копать нельзя")
	t.equal(Sim.dig(soil), {"removed": true, "ore": false}, "почва выкопана")
	t.equal(Sim.get_tile(soil), Tiles.Kind.AIR, "на месте тайла воздух")
	t.equal(events, [["tile", soil, Tiles.Kind.AIR]], "сигнал tile_changed")
	t.equal(Sim.dig(TestWorld.ORE), {"removed": false, "ore": true}, "жила даёт руду и остаётся")
	t.equal(Sim.dig(Vector2i(7, 10)), {"removed": false, "ore": false}, "коренная порода цела")


func _farm(t: TestCase, events: Array) -> void:
	t.group("Грядки")
	var plot: Vector2i = TestWorld.PLOTS[0]
	t.check(Sim.can_plant(plot)["ok"], "в пустую грядку можно сажать")
	t.check(Sim.plant(plot), "зерно посажено")
	t.equal(Sim.can_plant(plot)["reason"], "already_planted", "дважды не сажается")
	events.clear()
	t.check(Sim.water(plot), "грядка полита")
	t.equal(events, [["crop", plot, Crop.Stage.SPROUT, true]], "сигнал crop_changed: росток, влажная")
	t.equal(Sim.harvest(plot), 0, "незрелую грядку собрать нельзя")
	t.check(Sim.can_plant(Vector2i(5, 5))["ok"], "новая грядка на почве в зоне колодца")
	t.equal(Sim.can_plant(Vector2i(14, 5))["reason"], "no_water", "вне зоны колодца нельзя")
	t.equal(Sim.can_plant(Vector2i(5, 7))["reason"], "not_soil", "на камне нельзя")
	t.equal(Sim.can_plant(Vector2i(5, 6))["reason"], "blocked_above", "под землёй нельзя")
	t.check(Sim.is_in_water_zone(TestWorld.WELL), "колодец в своей зоне")

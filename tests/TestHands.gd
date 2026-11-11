class_name TestHands
extends RefCounted
## Ручные действия игрока: копание, жилы, костёр, склад, дрон. Владелец: A.


func run(t: TestCase) -> void:
	_digging(t)
	_campfire(t)
	_storage(t)


func _digging(t: TestCase) -> void:
	t.group("Копание и жилы")
	TestWorld.load()
	var events := []
	var on_tile := func(cell: Vector2i, kind: int) -> void: events.append([cell, kind])
	var on_vein := func(id: int) -> void: events.append(["vein", id])
	Sim.tile_changed.connect(on_tile)
	Sim.vein_exhausted.connect(on_vein)
	var soil := Vector2i(3, 13)
	t.equal(Sim.dig_time(soil), 0.4, "почва 0,4 с")
	t.equal(Sim.dig_time(TestWorld.SMALL_VEIN), 1.2, "руда 1,2 с")
	t.equal(Sim.dig_time(Vector2i(3, 39)), 0.0, "коренную породу копать нельзя")
	t.equal(Sim.dig_time(Vector2i(3, 5)), 0.0, "воздух копать нельзя")
	t.equal(Sim.dig_time(Vector2i(9, 12)), 0.0, "грядку копать нельзя")
	t.equal(Sim.dig(soil), {"removed": true, "ore": false}, "почва выкопана")
	t.equal(events, [[soil, Tiles.Kind.AIR]], "сигнал tile_changed")
	t.equal(Sim.veins.list.size(), 2, "соседние тайлы руды объединены в 2 жилы")
	for i in 39:
		Sim.dig(TestWorld.SMALL_VEIN)
	t.equal(Sim.get_tile(TestWorld.SMALL_VEIN), Tiles.Kind.ORE, "после 39 руд жила ещё жива")
	events.clear()
	t.equal(Sim.dig(TestWorld.SMALL_VEIN + Vector2i.RIGHT), {"removed": false, "ore": true},
		"40-я руда берётся с другого тайла той же жилы: запас общий")
	t.equal(Sim.get_tile(TestWorld.SMALL_VEIN), Tiles.Kind.STONE, "пустая жила стала камнем")
	t.equal(events.size(), 3, "2 сигнала tile_changed и vein_exhausted")
	for i in 200:
		Sim.dig(TestWorld.DEEP_VEIN)
	t.equal(Sim.get_tile(TestWorld.DEEP_VEIN), Tiles.Kind.ORE, "глубокая жила не кончается")
	Sim.tile_changed.disconnect(on_tile)
	Sim.vein_exhausted.disconnect(on_vein)


func _campfire(t: TestCase) -> void:
	t.group("Костёр")
	TestWorld.load()
	var fire := TestWorld.CAMPFIRE
	t.check(not Sim.campfire_work(10.0), "пустой костёр не плавит")
	t.check(Sim.insert(fire, Item.ORE) and Sim.insert(fire, Item.ORE), "2 руды положены")
	t.check(not Sim.insert(fire, Item.ORE), "третья руда не влезает")
	t.check(not Sim.insert(fire, Item.INGOT), "слиток в костёр не кладётся")
	t.check(not Sim.campfire_work(10.0), "без зерна не плавит")
	t.check(Sim.insert(fire, Item.GRAIN), "зерно положено")
	t.check(not Sim.campfire_work(2.9), "2,9 с ещё мало")
	t.check(Sim.campfire_work(0.1), "через 3 с слиток готов")
	t.check(not Sim.campfire_work(10.0), "сырьё потрачено")


func _storage(t: TestCase) -> void:
	t.group("Склад и дрон")
	TestWorld.load()
	var delivered := []
	var on_delivered := func(type: String, by_hand: bool) -> void: delivered.append([type, by_hand])
	Sim.item_delivered.connect(on_delivered)
	var storage := TestWorld.STORAGE
	t.check(Sim.insert(storage + Vector2i.ONE, Item.INGOT), "игрок кладёт слиток (по любой клетке склада)")
	t.equal(delivered, [["ingot", true]], "сигнал item_delivered с by_hand = true")
	var machine := Sim.grid.machine_at(storage)
	machine.accept(Item.new(Item.INGOT, false), Vector2i.RIGHT)
	machine.accept(Item.new(Item.INGOT, false), Vector2i.RIGHT)
	Sim.insert(storage, Item.ORE)
	t.equal(Sim.storage_count(Item.INGOT), 3, "на складе 3 слитка")
	var taken := Sim.take(storage)
	t.equal(taken.map(func(item: Item) -> String: return item.type), ["ore"], "руду забрать можно, слитки нет")
	var first := Sim.storage_take_for_drone(2)
	t.equal(first.map(func(item: Item) -> bool: return item.by_hand), [true, false],
		"дрон берёт ровно квоту, старые первыми")
	t.equal(Sim.storage_count(Item.INGOT), 1, "излишек остался на складе")
	t.equal(Sim.storage_take_for_drone(10).size(), 1, "при недостаче дрон берёт всё, что есть")
	Sim.item_delivered.disconnect(on_delivered)

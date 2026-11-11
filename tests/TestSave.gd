class_name TestSave
extends RefCounted
## Сохранение: мир после загрузки тот же и дальше живёт так же. Владелец: A.


func run(t: TestCase) -> void:
	t.group("Сохранение и загрузка")
	var factory := TestFactory.new()
	factory._auto_grain = true
	Sim.ticked.connect(factory._keep_grain)
	factory._build()
	Sim.plant(Vector2i(9, 12))
	Sim.water(Vector2i(9, 12))
	Sim.dig(Vector2i(3, 13))
	TestWorld.run(45.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Sim.to_dict()))
	TestWorld.run(60.0)
	var expected := TestWorld.dump(Sim.to_dict())

	var events := {"removed": 0, "placed": 0}
	var on_removed := func(_cell: Vector2i) -> void: events["removed"] += 1
	var on_placed := func(_cell: Vector2i, _type: String, _dir: Vector2i) -> void: events["placed"] += 1
	Sim.machine_removed.connect(on_removed)
	Sim.machine_placed.connect(on_placed)
	t.check(Sim.from_dict(saved), "сохранение загружено")
	t.equal([events["removed"], events["placed"]], [6, 6], "вид получил сигналы о всех 6 машинах")
	Sim.machine_removed.disconnect(on_removed)
	Sim.machine_placed.disconnect(on_placed)
	t.equal(TestWorld.dump(Sim.to_dict()), TestWorld.dump(saved), "мир после загрузки совпадает с сохранённым")
	t.equal(Sim.get_tile(Vector2i(3, 13)), Tiles.Kind.AIR, "выкопанный тайл остался выкопанным")
	TestWorld.run(60.0)
	t.equal(TestWorld.dump(Sim.to_dict()), expected, "после загрузки фабрика работает так же, как без неё")
	Sim.ticked.disconnect(factory._keep_grain)

	var before := TestWorld.dump(Sim.to_dict())
	t.check(not Sim.from_dict({"version": 999, "tiles": {}}), "сохранение другой версии отклонено")
	t.equal(TestWorld.dump(Sim.to_dict()), before, "при отказе мир не изменился")

	SaveManager.delete_save()
	t.check(not SaveManager.has_save(), "сохранения нет")
	t.check(not SaveManager.load_morning(), "загрузка без файла возвращает false")
	var day: int = GameState.day
	t.check(SaveManager.save_morning() and SaveManager.has_save(), "утреннее сохранение записано в user://save.json")
	GameState.day = day + 3
	TestWorld.run(20.0)
	t.check(SaveManager.load_morning(), "утреннее сохранение загружено")
	t.equal(GameState.day, day, "день восстановлен")
	t.equal(TestWorld.dump(Sim.to_dict()), before, "мир восстановлен с диска")
	SaveManager.delete_save()

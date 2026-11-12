extends Node
## Проверка симуляции без графики. Владелец: A.
## Запуск: godot --headless --path . res://tests/SimTest.tscn
## Код возврата 0, если все проверки прошли.

const CONTRACT_METHODS := [
	"load_world", "advance", "tick", "tick_alpha", "can_place", "place_machine", "remove_machine",
	"dig_time", "dig", "insert", "take", "campfire_work", "plant", "water", "harvest",
	"storage_take_for_drone", "get_tile", "get_machines", "get_items", "get_crops",
	"is_in_water_zone", "storage_count", "get_stats", "reset_period_stats", "night_summary",
	"to_dict", "from_dict",
]
const CONTRACT_SIGNALS := [
	"ticked", "tile_changed", "machine_placed", "machine_removed", "machine_state_changed",
	"item_delivered", "crop_changed", "vein_exhausted",
]


func _ready() -> void:
	var t := TestCase.new()
	_contract(t)
	_data(t)
	TestHands.new().run(t)
	TestLogistics.new().run(t)
	TestFactory.new().run(t)
	TestFarm.new().run(t)
	TestSave.new().run(t)
	# Сцену карты можно добавить в дерево только после того, как дерево закончит свой _ready.
	await get_tree().process_frame
	TestRealMap.new().run(t, get_tree())
	TestCampaign.new().run(t, get_tree())
	get_tree().quit(t.summary())


func _contract(t: TestCase) -> void:
	t.group("Контракт: методы и сигналы из docs/CONTRACT.md существуют")
	for method in CONTRACT_METHODS:
		t.check(Sim.has_method(method), "Sim.%s()" % method)
	for signal_name in CONTRACT_SIGNALS:
		t.check(Sim.has_signal(signal_name), "сигнал Sim.%s" % signal_name)
	for method in ["has_save", "save_morning", "load_morning", "delete_save"]:
		t.check(SaveManager.has_method(method), "SaveManager.%s()" % method)
	t.equal(Sim.Tile.FARMLAND, 6, "Sim.Tile: AIR..FARMLAND")
	t.equal(Sim.State.EXHAUSTED, 5, "Sim.State: IDLE..EXHAUSTED")


func _data(t: TestCase) -> void:
	t.group("Данные: числа GDD в JSON")
	t.equal(Sim.data.machines.size(), 8, "8 типов объектов в machines.json")
	t.equal(Sim.data.tick_seconds(), 0.25, "тик 0,25 с")
	t.equal(MachineCatalog.cost("drill"), {"ingot": 3.0, "ore": 5.0}, "цена бура")
	t.equal(MachineCatalog.cost("furnace"), {"ore": 8.0, "ingot": 2.0}, "цена печи")
	t.equal(MachineCatalog.size("storage"), Vector2i(2, 2), "склад 2x2")
	t.equal(Sim.data.dig_time(Tiles.Kind.STONE), 0.9, "камень копается 0,9 с")
	t.equal(Sim.data.dig_time(Tiles.Kind.BEDROCK), 0.0, "коренная порода не копается")
	t.equal(Sim.data.vein_reserve(14), 40, "жила в почве: 40 руды")
	t.equal(Sim.data.vein_reserve(25), 120, "жила в камне: 120 руды")
	t.equal(Sim.data.vein_reserve(33), -1, "глубокая жила бесконечна")
	var total := 0
	for day in GameConfig.days()["days"]:
		total += int(day["quota"])
	t.equal(total, 133, "сумма квот за 5 дней")

extends Node
## Проверка симуляции без графики. Владелец: A.
## Запуск: godot --headless --path . res://tests/SimTest.tscn
## Код возврата 0, если все проверки прошли.

## Сколько слитков игрок успевает сделать руками за сутки (GDD «Баланс: ручной труд»).
const HAND_INGOTS_PER_DAY := 10
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
	# Сами квоты — баланс B (data/days.json, подобраны ботом tools/b_smoke/play.gd). Здесь проверяем свойства,
	# на которых держится игра: квоты растут, с дня 3 руками не успеть (GDD: ~10 слитков в сутки),
	# а квота дня 5 не выше того, что фабрика гарантированно даёт (TestCampaign.QUOTA_DAY_5).
	var quotas: Array = GameConfig.days()["days"].map(func(day: Dictionary) -> int: return int(day["quota"]))
	t.equal(quotas.size(), 5, "5 игровых дней")
	var growing := true
	for i in range(1, quotas.size()):
		growing = growing and quotas[i] > quotas[i - 1]
	t.check(growing, "квоты растут каждый день: %s" % [quotas])
	t.check(quotas.slice(2).all(func(q: int) -> bool: return q > HAND_INGOTS_PER_DAY),
		"с дня 3 квота больше ручного потолка %d слитков" % HAND_INGOTS_PER_DAY)
	t.check(quotas[-1] <= TestCampaign.QUOTA_DAY_5, "квота дня 5 (%d) не выше проверенной мощности фабрики" % quotas[-1])

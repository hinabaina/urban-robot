extends Node
## Проверка симуляции без графики. Владелец: A.
## Запуск: godot --headless --path . res://tests/SimTest.tscn
## Код возврата 0, если все проверки прошли.

const CONTRACT_METHODS := [
	"reset", "load_world", "advance", "tick", "can_place", "place_machine", "remove_machine",
	"dig_time", "dig", "insert", "take", "campfire_work", "can_plant", "plant", "water",
	"harvest", "storage_take_for_drone", "get_tile", "get_machine", "get_machines",
	"get_items", "get_crops", "is_in_water_zone", "storage_count", "machine_types",
	"machine_config", "get_stats", "reset_period_stats", "period_summary", "to_dict", "from_dict",
]
const CONTRACT_SIGNALS := [
	"world_loaded", "ticked", "tile_changed", "machine_placed", "machine_removed",
	"machine_state_changed", "item_delivered", "storage_changed", "crop_changed", "vein_exhausted",
]

var t := TestCase.new()
var _events: Array = []


func _ready() -> void:
	Sim.item_delivered.connect(func(type, by_hand): _events.append(["delivered", type, by_hand]))
	Sim.tile_changed.connect(func(cell, kind): _events.append(["tile", cell, kind]))
	Sim.crop_changed.connect(func(cell, stage, wet): _events.append(["crop", cell, stage, wet]))
	_test_contract()
	_test_data()
	_test_world_and_ticks()
	TestBuild.new().run(t, _events)
	TestManual.new().run(t, _events)
	get_tree().quit(t.summary())


func _test_contract() -> void:
	t.group("Контракт: методы и сигналы из docs/CONTRACT.md существуют")
	for method in CONTRACT_METHODS:
		t.check(Sim.has_method(method), "Sim.%s()" % method)
	for signal_name in CONTRACT_SIGNALS:
		t.check(Sim.has_signal(signal_name), "сигнал Sim.%s" % signal_name)
	for signal_name in ["quota_changed", "trust_changed", "pockets_changed"]:
		t.check(GameState.has_signal(signal_name), "сигнал GameState.%s" % signal_name)
	for signal_name in ["day_started", "evening", "night_started", "day_ended"]:
		t.check(DayCycle.has_signal(signal_name), "сигнал DayCycle.%s" % signal_name)
	for method in ["has_save", "save_game", "load_game"]:
		t.check(SaveManager.has_method(method), "SaveManager.%s()" % method)


func _test_data() -> void:
	t.group("Данные: числа GDD в JSON")
	t.equal(Sim.machine_types().size(), 8, "8 типов объектов в machines.json")
	t.equal(Sim.data.tick_seconds(), 0.25, "тик 0,25 с")
	t.equal(Sim.machine_config("drill")["cost"], {"ingot": 3.0, "ore": 5.0}, "цена бура")
	t.equal(Sim.machine_config("furnace")["cycle_seconds"], 6.0, "печь 6 с на слиток")
	t.equal(Sim.data.dig_time(Tiles.Kind.STONE), 0.9, "камень копается 0,9 с")
	t.equal(Sim.data.dig_time(Tiles.Kind.BEDROCK), -1.0, "коренная порода не копается")
	var total := 0
	for day in GameState.config["days"]:
		total += int(day["quota"])
	t.equal(total, 120, "сумма квот за 5 дней")
	t.equal(GameState.pockets, {"ore": 0.0, "grain": 10.0, "ingot": 0.0}, "стартовые карманы")


func _test_world_and_ticks() -> void:
	t.group("Мир и тики")
	Sim.load_world(TestWorld.small())
	t.equal(Sim.get_tile(Vector2i(3, 5)), Tiles.Kind.SOIL, "тайл почвы на месте")
	t.equal(Sim.get_tile(Vector2i(3, 2)), Tiles.Kind.AIR, "небо это воздух")
	t.equal(Sim.get_tile(Vector2i(-1, 0)), Tiles.Kind.BEDROCK, "за границей мира коренная порода")
	t.equal(Sim.get_machines().size(), 2, "склад и костёр стоят на карте заранее")
	t.equal(Sim.get_crops().size(), 2, "стартовые грядки загружены")
	Sim.advance(1.0)
	t.equal(Sim.tick_count, 4, "1 секунда = 4 тика")
	Sim.advance(0.2)
	t.equal(Sim.tick_count, 4, "0,2 с ещё не тик")
	Sim.advance(0.05)
	t.equal(Sim.tick_count, 5, "остаток времени копится до следующего тика")
	var at_x1 := _ticks_after(120, 1.0)
	var at_x20 := _ticks_after(6, 20.0)
	t.equal(at_x20, at_x1, "скорость x20 даёт столько же тиков, сколько x1 за то же игровое время")


## Сколько тиков пройдёт за frames кадров по 1/60 с на скорости speed.
func _ticks_after(frames: int, speed: float) -> int:
	Sim.load_world(TestWorld.small())
	for i in frames:
		Sim.advance(speed / 60.0)
	return Sim.tick_count

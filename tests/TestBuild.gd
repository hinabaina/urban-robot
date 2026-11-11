class_name TestBuild
extends RefCounted
## Проверки постановки и сноса машин. Владелец: A.


func run(t: TestCase, _events: Array) -> void:
	t.group("Постановка и снос машин")
	Sim.load_world(TestWorld.small())
	var air := Vector2i(5, 3)
	t.equal(Sim.can_place("drill", air, Vector2i.RIGHT), {"ok": true, "reason": ""}, "бур в воздухе можно")
	t.equal(Sim.can_place("laser", air, Vector2i.RIGHT)["reason"], "unknown_type", "неизвестный тип")
	t.equal(Sim.can_place("storage", air, Vector2i.RIGHT)["reason"], "not_buildable", "склад игрок не строит")
	t.equal(Sim.can_place("conveyor", air, Vector2i(1, 1))["reason"], "bad_direction", "диагональ запрещена")
	t.equal(Sim.can_place("conveyor", Vector2i(5, 6), Vector2i.UP)["reason"], "tile_solid", "в землю нельзя")
	t.equal(Sim.can_place("drill", Vector2i(15, 3), Vector2i.UP)["reason"], "out_of_bounds", "за край нельзя")
	t.equal(Sim.can_place("drill", Vector2i(5, 4), Vector2i.UP)["reason"], "tile_solid", "бур 2x2 задевает землю")

	t.check(Sim.place_machine("drill", air, Vector2i.LEFT), "бур поставлен")
	t.equal(Sim.get_machine(air + Vector2i(1, 1)).get("type"), "drill", "бур занимает все 4 клетки")
	t.equal(Sim.get_machine(air)["dir"], Vector2i.LEFT, "направление выхода запомнено")
	t.equal(Sim.get_machine(air)["state"], Machine.State.IDLE, "новая машина в состоянии IDLE")
	t.equal(Sim.can_place("conveyor", air + Vector2i(1, 0), Vector2i.UP)["reason"], "occupied", "занятая клетка")
	t.check(not Sim.place_machine("conveyor", air, Vector2i.UP), "поверх машины не ставится")

	var removed := Sim.remove_machine(air + Vector2i(1, 1))
	t.check(removed["ok"], "бур снесён по любой своей клетке")
	t.equal(removed["refund"], {"ingot": 3.0, "ore": 5.0}, "возврат 100% цены")
	t.equal(Sim.get_machine(air), {}, "клетка свободна после сноса")
	t.equal(Sim.remove_machine(air)["reason"], "no_machine", "сносить нечего")
	t.equal(Sim.remove_machine(TestWorld.STORAGE)["reason"], "not_removable", "склад снести нельзя")
	t.check(Sim.place_machine("ladder", Vector2i(4, 4), Vector2i.RIGHT), "лестница ставится")

class_name TestRealMap
extends RefCounted
## Настоящая карта world/World.tscn на настоящем движке: жилы, грядки, готовые постройки. Владелец: A.


func run(t: TestCase, tree: SceneTree) -> void:
	t.group("Настоящая карта (world/World.tscn)")
	var world: Node = load("res://world/World.tscn").instantiate()
	tree.root.add_child(world)
	world.start_new()
	var reserves := Sim.veins.list.map(func(vein: Vein) -> int: return vein.reserve)
	reserves.sort()
	t.equal(reserves, [-1, 40, 40, 120, 120], "5 жил: 2 в почве по 40, 2 в камне по 120, 1 бесконечная")
	var sizes := Sim.veins.list.map(func(vein: Vein) -> int: return vein.cells.size())
	sizes.sort()
	t.equal(sizes, [6, 6, 12, 12, 20], "размеры жил 3x2, 4x3 и 5x4 тайлов")
	t.equal(Sim.get_crops().size(), 12, "12 стартовых грядок")
	var types := Sim.get_machines().map(func(machine: Machine) -> String: return machine.type)
	t.equal([types.count("storage"), types.count("campfire"), types.count("ladder")], [1, 1, 6],
		"склад, костёр и 6 лестниц старой шахты стоят с начала игры")
	var in_zone := Sim.get_crops().filter(func(crop: Crop) -> bool: return Sim.is_in_water_zone(crop.cell)).size()
	t.check(in_zone >= 8, "в зоне колодца %d грядок из 12" % in_zone)
	world.queue_free()

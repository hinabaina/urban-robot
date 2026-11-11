class_name MachineRegistry
extends RefCounted
## Создание машины по строковому типу из data/machines.json. Владелец: A.


static func create(type: String, cell: Vector2i, dir: Vector2i, config: Dictionary, sim: Node) -> Machine:
	var machine := _instance(type)
	machine.setup(type, cell, dir, config, sim)
	return machine


static func _instance(type: String) -> Machine:
	match type:
		"conveyor": return Conveyor.new()
		"drill": return Drill.new()
		"furnace": return Furnace.new()
		"sprinkler": return Sprinkler.new()
		"harvester": return Harvester.new()
		"storage": return Storage.new()
		"campfire": return Campfire.new()
	# Лестница пассивна: ей хватает базового класса.
	return Machine.new()

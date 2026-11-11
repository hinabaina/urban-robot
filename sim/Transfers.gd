class_name Transfers
extends RefCounted
## Разрешение переходов предметов между машинами с обратным давлением. Владелец: A.
## GDD «Порядок одного тика», шаг 4. Это главная нетривиальная система симуляции.

var _sim: Node


func _init(p_sim: Node) -> void:
	_sim = p_sim


## Повторяем проходы, пока хоть один предмет сдвинулся. Так плотная цепочка
## на конвейере едет вся сразу: передний освободил клетку, следующий занял её в том же тике.
## Каждый предмет переходит не больше одного раза за тик.
func run() -> void:
	var moved := {}  # Item -> true
	var progress := true
	while progress:
		progress = false
		var claims := _collect_claims(moved)
		for target: Machine in claims.keys():
			var source := _pick(target, claims[target])
			var item := source.take_output()
			target.accept(item, source.dir)
			target.last_source_id = source.get_instance_id()
			moved[item] = true
			progress = true


## Кто в какую машину хочет отдать предмет прямо сейчас: цель -> список источников.
func _collect_claims(moved: Dictionary) -> Dictionary:
	var claims := {}
	for source: Machine in _sim.grid.machines():
		var item := source.peek_output()
		if item == null or moved.has(item):
			continue
		var target: Machine = _sim.grid.machine_at(source.output_cell())
		if target == null or target == source or not target.can_accept(item, source.dir):
			continue
		if not claims.has(target):
			claims[target] = []
		claims[target].append(source)
	return claims


## Слияние потоков: если желающих несколько, берём не того, у кого взяли в прошлый раз.
## Так ни одна ветка не «голодает».
func _pick(target: Machine, sources: Array) -> Machine:
	for source: Machine in sources:
		if source.get_instance_id() != target.last_source_id:
			return source
	return sources[0]

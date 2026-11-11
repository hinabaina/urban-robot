# Бот-игрок: проходит 5 дней на настоящем движке, чтобы проверить баланс квот (в билд не входит). Владелец: B.
# Запуск: tools/b_smoke/shot.sh out.png 0.2 play
# Руками бот делает то же, что игрок (те же вызовы Sim и GameState), и тратит на это игровое время:
# копание, плавка, полив, постройка и ходьба между точками. Ходит идеально, поэтому живому игроку
# нужен запас: цель — пройти с заметным излишком на каждом дне.
extends "res://tools/b_smoke/checks.gd"

const TIME_SCALE := 10.0
const WALK_X := 7.5          # клеток в секунду по горизонтали (120 px/с)
const WALK_Y := 5.0          # по лестнице (90 px/с) с запасом на перелезание
const ACT := 0.25            # клик или E
const FARM := Vector2i(14, 11)
const WELL := Vector2i(7, 11)
const VEIN_A := [Vector2i(33, 16), Vector2i(34, 16), Vector2i(35, 16), Vector2i(33, 17), Vector2i(34, 17), Vector2i(35, 17)]
const VEIN_B := [Vector2i(41, 16), Vector2i(42, 16), Vector2i(43, 16), Vector2i(41, 15), Vector2i(42, 15), Vector2i(43, 15)]
const VEIN_D := [Vector2i(41, 24), Vector2i(41, 25), Vector2i(41, 26), Vector2i(40, 24), Vector2i(40, 25), Vector2i(40, 26)]
const VEIN_E := [Vector2i(34, 31), Vector2i(34, 32), Vector2i(34, 33), Vector2i(34, 34)]
const VEIN_C := [Vector2i(29, 21), Vector2i(29, 22), Vector2i(29, 23), Vector2i(28, 21), Vector2i(28, 22), Vector2i(28, 23)]

const F1 := Vector2i(48, 10)

const FEED_EVERY_HOURS := 2.5    # 25 игровых секунд

var _pos := Vector2i(28, 11)
var _last_feed := 0.0
var _log := LogLines.new()


## Журнал, который печатает строки сразу: так видно, где бот застрял.
class LogLines:
	var lines: Array[String] = []

	func append(line: String) -> void:
		lines.append(line)
		print("[%.1f ч] %s" % [DayCycle.hour, line])
var _storage := Vector2i.ZERO
var _fire := Vector2i.ZERO


func scenario_play() -> void:
	player = main.get_node("Player")
	world = main.get_node("World")
	_storage = world.marker_cell("Storage")
	_fire = world.marker_cell("Campfire")
	main.get_node("UI/Tutorial")._finish()     # без замедления часов обучения: проверяем худший случай
	Engine.time_scale = TIME_SCALE
	GameState.day_settled.connect(_on_settled)
	DayCycle.day_ended.connect(func(_d: int) -> void: _log.append("   ночь: %s" % Sim.night_summary()))
	for day in GameConfig.total_days():
		_log.append("День %d утро: карманы %s, склад %d" % [GameState.day, GameState.pockets, Sim.storage_count("ingot")])
		await call("_day_%d" % GameState.day)
		await _finish_day()
		if DayCycle.phase == DayCycle.Phase.OVER:
			break
	Engine.time_scale = 1.0
	check("all five quotas delivered", GameState.rocket.size() == 5 and GameState.trust == 3,
		[GameState.rocket.size(), GameState.trust])
	check("won", GameState.stars() >= 1, GameState.stars())
	print("RESULT: ", "ALL PASS" if failed == 0 else "%d FAILED" % failed)


func _on_settled(r: Dictionary) -> void:
	_log.append("   18:00 дрон: квота %d, сдано %d, излишек %d, авто %d, доверие %d" % [r["quota"], r["taken"],
		Sim.storage_count("ingot"), r["auto"], GameState.trust])


## Ждать до вечера, сдать слитки, лечь спать, пролистать отчёт.
func _finish_day() -> void:
	await _deliver()
	await wait_phase(DayCycle.Phase.EVENING, 300.0)
	if DayCycle.phase == DayCycle.Phase.OVER:
		return
	DayCycle.sleep()
	await wait_phase(DayCycle.Phase.REPORT, 300.0)
	main.get_node("UI/NightReport")._on_morning()
	_pos = world.marker_cell("Spawn")


# --- Дни ---------------------------------------------------------------------
# Планировка: печи стоят вплотную к складу и отдают слитки прямо в него.
# Руда поднимается лифтом x=48 (печь 1) и x=53 (печь 2), зерно приходит лентой y=10 с фермы.

func _day_1() -> void:
	await _farm_pass(5)
	await _mine(VEIN_A, 10)
	await _smelt(5)
	await _deliver()
	while DayCycle.hour < 17.0:
		await _farm_pass(6)
		await _mine_any(15)


## Линия 1: бур у жилы B → конвейер → лифт → печь у склада. Зерно в печь пока носим руками.
func _day_2() -> void:
	await _build("drill", Vector2i(44, 15), Vector2i.RIGHT)
	await _belt([Vector2i(46, 15), Vector2i(47, 15)], Vector2i.RIGHT)
	await _belt(_col(48, 15, 12), Vector2i.UP)
	await _build("furnace", F1, Vector2i.RIGHT)
	while DayCycle.hour < 17.5:
		await _feed(F1)
		await _farm_pass(0)
		await _mine_any(10)


## Ферма кормит шахту: поливалка, сборщики и лента зерна в печь 1. Новая жила D под лифт x=48.
func _day_3() -> void:
	await _build("sprinkler", Vector2i(12, 11), Vector2i.UP)
	await _build("harvester", Vector2i(11, 11), Vector2i.UP)
	await _belt(_row(11, 47, 10), Vector2i.RIGHT)
	await _build("drill", Vector2i(42, 24), Vector2i.RIGHT)
	await _belt(_row(44, 47, 24), Vector2i.RIGHT)
	await _belt(_col(48, 24, 16), Vector2i.UP)
	while DayCycle.hour < 17.5:
		await _feed(F1)
		await _mine_any(10)


## Камень кончается: бур у бесконечной глубокой жилы E, лента y=31 и лифт x=48 к печи 1.
func _day_4() -> void:
	await _build("drill", Vector2i(35, 31), Vector2i.RIGHT)
	await _belt(_row(37, 47, 31), Vector2i.RIGHT)
	await _belt(_col(48, 31, 25), Vector2i.UP)
	while DayCycle.hour < 17.5:
		await _feed(F1)
		await _farm_pass(0)


## Второй бур под жилой D догружает печь 1 до её предела (10 слитков в минуту).
func _day_5() -> void:
	await _build("drill", Vector2i(38, 27), Vector2i.RIGHT)
	await _belt(_row(40, 47, 27), Vector2i.RIGHT)
	while DayCycle.hour < 17.5:
		await _feed(F1)
		await _farm_pass(0)


# --- Руки ----------------------------------------------------------------------

## Бот работает днём и вечером; ночью и в отчёте руки заняты сном.
func _working_hours() -> bool:
	return DayCycle.phase in [DayCycle.Phase.DAY, DayCycle.Phase.DRONE, DayCycle.Phase.EVENING]


func _act(seconds: float) -> void:
	await wait(seconds)


func _walk(to: Vector2i) -> void:
	var d := (to - _pos).abs()
	await _act(d.x / WALK_X + d.y / WALK_Y)
	_pos = to


## Копать руками ближайшую живую жилу из списка (по порядку предпочтения).
func _mine_any(count: int) -> void:
	for vein in [VEIN_A, VEIN_C, VEIN_D, VEIN_E]:
		if _alive(vein):
			await _mine(vein, count)
			return


func _mine(vein: Array, count: int) -> void:
	await _walk(vein[0] + Vector2i.UP)
	for i in count:
		var tile: Vector2i = Vector2i(-1, -1)
		for c in vein:
			if Sim.get_tile(c) == Sim.Tile.ORE:
				tile = c
				break
		if tile.x < 0 or GameState.pockets["ore"] >= GameConfig.pocket_limit("ore"):
			return
		await _act(Sim.dig_time(tile))
		if Sim.dig(tile)["ore"]:
			GameState.add_pocket("ore")


func _alive(vein: Array) -> bool:
	return vein.any(func(c: Vector2i) -> bool: return Sim.get_tile(c) == Sim.Tile.ORE)


func _smelt(count: int) -> void:
	await _walk(_fire)
	for i in count:
		if not GameState.can_afford({"ore": 2, "grain": 1}):
			return
		for type in ["ore", "ore", "grain"]:
			Sim.insert(_fire, type)
			GameState.pay({type: 1})
		await _act(ACT * 3 + 3.0)
		if Sim.campfire_work(3.0):
			GameState.add_pocket("ingot")


func _deliver() -> void:
	if GameState.pockets["ingot"] <= _reserve_ingots():
		return
	await _walk(_storage)
	while GameState.pockets["ingot"] > _reserve_ingots() and Sim.insert(_storage, "ingot"):
		GameState.pay({"ingot": 1})
	await _act(ACT)


## Слитки, которые бот держит на завтрашние постройки (подарок дрона идёт туда же).
func _reserve_ingots() -> int:
	return 0 if GameState.day == 1 else 99


## Обойти грядки: собрать зрелые, посадить пустые (оставив keep зерна), полить сухие.
func _farm_pass(keep: int) -> void:
	await _walk(FARM)
	for crop in Sim.get_crops():
		var cell: Vector2i = crop.get("cell")
		var stage: int = crop.get("stage")
		if stage == 4:
			await _act(0.3)
			GameState.add_pocket("grain", Sim.harvest(cell))
		elif stage == 0 and GameState.pockets["grain"] > keep:
			await _act(ACT)
			if Sim.plant(cell):
				GameState.pay({"grain": 1})
		if crop.get("stage") in [1, 2, 3] and not crop.get("wet"):
			if GameState.water <= 0:
				await _walk(WELL)
				await _act(1.0)
				GameState.set_water(10)
				await _walk(FARM)
			await _act(0.3)
			if Sim.water(cell):
				GameState.set_water(GameState.water - 1)


## Во время стройки не забывать про печи: зерна в печи хватает на 30 с работы.
func _keep_fed() -> void:
	if DayCycle.hour - _last_feed < FEED_EVERY_HOURS:
		return
	for furnace in [F1]:
		if MachineCatalog.find(furnace).get("type", "") == "furnace":
			await _feed(furnace)


## Подбросить в печь зерно и руду из карманов (E), забрать готовые слитки.
func _feed(furnace: Vector2i) -> void:
	_last_feed = DayCycle.hour
	await _walk(furnace + Vector2i.LEFT)
	for item in Sim.take(furnace):
		GameState.add_pocket(item.get("type"))
	for type in ["grain", "ore"]:
		var keep := 0 if type == "grain" else 20      # руду бережём на конвейеры
		while GameState.pockets[type] > keep and Sim.insert(furnace, type):
			GameState.pay({type: 1})
	await _act(ACT)
	if GameState.pockets["ingot"] > _reserve_ingots():
		await _deliver()


# --- Постройка -----------------------------------------------------------------

## Клетки столбца x сверху вниз или снизу вверх, от from_y до to_y включительно.
func _col(x: int, from_y: int, to_y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var step := 1 if to_y >= from_y else -1
	for y in range(from_y, to_y + step, step):
		cells.append(Vector2i(x, y))
	return cells


## Наплавить слитков в костре на постройки (со склада слитки не забрать — так в GDD).
func _ingots(need: int) -> void:
	while GameState.pockets["ingot"] < need:
		if not GameState.can_afford({"ore": 2, "grain": 1}):
			if GameState.pockets["ore"] < 2:
				await _mine_any(12)
			if GameState.pockets["grain"] < 1:
				await _farm_pass(0)
			continue
		await _smelt(need - GameState.pockets["ingot"])


func _row(from_x: int, to_x: int, y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(from_x, to_x + 1):
		cells.append(Vector2i(x, y))
	return cells


func _belt(cells: Array[Vector2i], dir: Vector2i) -> void:
	for cell in cells:
		await _build("conveyor", cell, dir)


func _build(type: String, cell: Vector2i, dir: Vector2i) -> void:
	await _keep_fed()
	await _walk(cell)
	for c in MachineCatalog.cells(type, cell):
		if Sim.get_tile(c) != Sim.Tile.AIR:
			await _act(Sim.dig_time(c))
			Sim.dig(c)
	var cost := MachineCatalog.cost(type)
	while not GameState.can_afford(cost) and _working_hours():
		_log.append("   %02d:%02d не хватает на %s %s: %s" % [int(DayCycle.hour), 0, type, cell, GameState.pockets])
		if cost.has("ingot") and GameState.pockets["ingot"] < int(cost["ingot"]):
			await _ingots(int(cost["ingot"]))
		elif cost.has("grain") and GameState.pockets["grain"] < int(cost["grain"]):
			await _farm_pass(0)
		else:
			await _mine_any(15)
		await _walk(cell)
	if not GameState.can_afford(cost):
		return
	var check_place := Sim.can_place(type, cell, dir)
	if not check_place["ok"]:
		_log.append("   НЕЛЬЗЯ поставить %s в %s: %s" % [type, cell, check_place["reason"]])
		failed += 1
		return
	GameState.pay(cost)
	Sim.place_machine(type, cell, dir)
	await _act(ACT)

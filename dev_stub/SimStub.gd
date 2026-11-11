# ВРЕМЕННАЯ заглушка Simulation (владелец B, только для разработки до каркаса A).
# Повторяет контракт из TEAM_PLAN §5.2 с упрощённой логикой. Удаляется, когда придёт sim/ от A.
extends Node

enum Tile { AIR, SOIL, STONE, DEEP, BEDROCK, ORE, FARMLAND, WELL }
enum State { IDLE, WORKING, BLOCKED, NO_FUEL, NO_WATER, EXHAUSTED }

signal tile_changed(cell: Vector2i, kind: int)
signal machine_placed(cell: Vector2i, type: String, dir: Vector2i)
signal machine_removed(cell: Vector2i)
signal machine_state_changed(cell: Vector2i, state: int)
signal item_delivered(type: String, by_hand: bool)
signal crop_changed(cell: Vector2i, stage: int, wet: bool)
signal vein_exhausted(vein_id: int)

const TICK := 0.25
const DIG_TIME := {Tile.SOIL: 0.4, Tile.STONE: 0.9, Tile.DEEP: 1.6, Tile.ORE: 1.2}

var _tiles := {}
var _ore_left := {}
var _m := {}          # anchor cell -> machine dict
var _occ := {}        # any occupied cell -> anchor cell
var _items := []      # {cell, dir, progress, type, by_hand}
var _crops := {}      # cell -> {stage, wet, t}
var _acc := 0.0
var _sizes := {}

func _ready() -> void:
	var f := FileAccess.open("res://dev_stub/machines.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k in d:
		_sizes[k] = Vector2i(d[k]["size"][0], d[k]["size"][1])

func load_world(tiles: Dictionary) -> void:
	_tiles = tiles.duplicate()
	_m.clear(); _occ.clear(); _items.clear(); _crops.clear(); _ore_left.clear()
	for c in _tiles:
		if _tiles[c] == Tile.FARMLAND:
			_crops[c] = {"stage": 0, "wet": false, "t": 0.0, "wet_t": 0.0}

func get_tile(cell: Vector2i) -> int:
	return _tiles.get(cell, Tile.AIR)

func dig_time(cell: Vector2i) -> float:
	return DIG_TIME.get(get_tile(cell), 0.0)

func dig(cell: Vector2i) -> Dictionary:
	var k := get_tile(cell)
	if not DIG_TIME.has(k):
		return {"removed": false, "ore": false}
	if k == Tile.ORE:
		_ore_left[cell] = _ore_left.get(cell, 5) - 1
		if _ore_left[cell] > 0:
			return {"removed": false, "ore": true}
		_tiles[cell] = Tile.STONE
		tile_changed.emit(cell, Tile.STONE)
		return {"removed": false, "ore": true}
	_tiles[cell] = Tile.AIR
	tile_changed.emit(cell, Tile.AIR)
	return {"removed": true, "ore": false}

func _cells(type: String, cell: Vector2i) -> Array:
	var out := []
	var s: Vector2i = _sizes.get(type, Vector2i.ONE)
	for y in s.y:
		for x in s.x:
			out.append(cell + Vector2i(x, y))
	return out

func can_place(type: String, cell: Vector2i, _dir: Vector2i) -> Dictionary:
	var touches := false
	for c in _cells(type, cell):
		if get_tile(c) != Tile.AIR:
			return {"ok": false, "reason": "REASON_NOT_EMPTY"}
		if _occ.has(c):
			return {"ok": false, "reason": "REASON_OCCUPIED"}
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			touches = touches or get_tile(c + d) == Tile.ORE
	if type == "drill" and not touches:
		return {"ok": false, "reason": "REASON_NEED_VEIN"}
	return {"ok": true, "reason": ""}

func place_machine(type: String, cell: Vector2i, dir: Vector2i) -> bool:
	if not can_place(type, cell, dir)["ok"]:
		return false
	_m[cell] = {"cell": cell, "type": type, "dir": dir, "state": State.IDLE,
		"buffers": {"ore": 0, "grain": 0, "ingot": 0, "out": 0}, "t": 0.0, "hand": false}
	for c in _cells(type, cell):
		_occ[c] = cell
	machine_placed.emit(cell, type, dir)
	return true

func remove_machine(cell: Vector2i) -> Array:
	if not _occ.has(cell):
		return []
	var a: Vector2i = _occ[cell]
	var out := []
	for it in _items.filter(func(i): return i["cell"] == a):
		out.append(it)
		_items.erase(it)
	for c in _cells(_m[a]["type"], a):
		_occ.erase(c)
	_m.erase(a)
	machine_removed.emit(a)
	return out

func insert(cell: Vector2i, type: String) -> bool:
	if not _occ.has(cell):
		return false
	var m: Dictionary = _m[_occ[cell]]
	if m["type"] == "storage":
		m["buffers"][type] += 1
		item_delivered.emit(type, true)
		return true
	if m["type"] in ["furnace", "campfire"] and type in ["ore", "grain"]:
		m["buffers"][type] += 1
		m["hand"] = true
		return true
	return false

func take(cell: Vector2i) -> Array:
	if not _occ.has(cell):
		return []
	var m: Dictionary = _m[_occ[cell]]
	var out := []
	if m["type"] == "storage":
		for t in ["ore", "grain"]:
			for i in m["buffers"][t]:
				out.append({"type": t, "by_hand": true})
			m["buffers"][t] = 0
	elif m["buffers"]["out"] > 0:
		var t := "ingot" if m["type"] == "furnace" else "ore"
		for i in m["buffers"]["out"]:
			out.append({"type": t, "by_hand": true})
		m["buffers"]["out"] = 0
	return out

func plant(cell: Vector2i) -> bool:
	if _crops.has(cell) and _crops[cell]["stage"] == 0:
		_crops[cell]["stage"] = 1
		_crops[cell]["t"] = 0.0
		crop_changed.emit(cell, 1, _crops[cell]["wet"])
		return true
	return false

func water(cell: Vector2i) -> bool:
	if not _crops.has(cell):
		return false
	_crops[cell]["wet"] = true
	_crops[cell]["wet_t"] = 15.0
	crop_changed.emit(cell, _crops[cell]["stage"], true)
	return true

func harvest(cell: Vector2i) -> int:
	if _crops.has(cell) and _crops[cell]["stage"] == 4:
		_crops[cell]["stage"] = 0
		crop_changed.emit(cell, 0, _crops[cell]["wet"])
		return 3
	return 0

func campfire_work(dt: float) -> bool:
	for a in _m:
		var m: Dictionary = _m[a]
		if m["type"] == "campfire" and m["buffers"]["ore"] >= 2 and m["buffers"]["grain"] >= 1:
			m["t"] += dt
			if m["t"] >= 3.0:
				m["t"] = 0.0
				m["buffers"]["ore"] -= 2
				m["buffers"]["grain"] -= 1
				return true
	return false

func storage_count(type: String) -> int:
	var n := 0
	for a in _m:
		if _m[a]["type"] == "storage":
			n += _m[a]["buffers"].get(type, 0)
	return n

func storage_take_for_drone(n: int) -> Array:
	var out := []
	for a in _m:
		if _m[a]["type"] == "storage":
			while out.size() < n and _m[a]["buffers"]["ingot"] > 0:
				_m[a]["buffers"]["ingot"] -= 1
				out.append({"type": "ingot", "by_hand": true})
	return out

func get_machines() -> Array:
	return _m.values()

func get_items() -> Array:
	return _items

func get_crops() -> Array:
	var out := []
	for c in _crops:
		out.append({"cell": c, "stage": _crops[c]["stage"], "wet": _crops[c]["wet"]})
	return out

func get_stats(_cell: Vector2i) -> Dictionary:
	return {"working": 0.5, "blocked": 0.1, "idle": 0.4, "per_min": 7.5}

func night_summary() -> Dictionary:
	return {"made": {"ingot": 0, "ore": 0, "grain": 0}, "bottleneck": {}}

func to_dict() -> Dictionary:
	return {}

func from_dict(_d: Dictionary) -> void:
	pass

func advance(dt: float) -> void:
	_acc += dt
	while _acc >= TICK:
		_acc -= TICK
		_tick()

func _set_state(m: Dictionary, s: int) -> void:
	if m["state"] != s:
		m["state"] = s
		machine_state_changed.emit(m["cell"], s)

func _out_cell(m: Dictionary) -> Vector2i:
	var s: Vector2i = _sizes.get(m["type"], Vector2i.ONE)
	var d: Vector2i = m["dir"]
	return m["cell"] + Vector2i(s.x if d.x > 0 else (-1 if d.x < 0 else 0), s.y if d.y > 0 else (-1 if d.y < 0 else 0))

func _conveyor_free(c: Vector2i) -> bool:
	return _m.has(c) and _m[c]["type"] == "conveyor" and not _items.any(func(i): return i["cell"] == c)

func _tick() -> void:
	for a in _m:
		var m: Dictionary = _m[a]
		var b: Dictionary = m["buffers"]
		if m["type"] == "drill":
			m["t"] += TICK
			if m["t"] >= 4.0 and b["out"] < 5:
				m["t"] = 0.0
				b["out"] += 1
			_set_state(m, State.BLOCKED if b["out"] >= 5 else State.WORKING)
		elif m["type"] == "furnace":
			if b["ore"] >= 2 and b["out"] < 5:
				m["t"] += TICK
				_set_state(m, State.WORKING)
				if m["t"] >= 6.0:
					m["t"] = 0.0
					b["ore"] -= 2
					b["out"] += 1
			else:
				_set_state(m, State.BLOCKED if b["out"] >= 5 else State.IDLE)
		if m["type"] in ["drill", "furnace"] and b["out"] > 0 and _conveyor_free(_out_cell(m)):
			b["out"] -= 1
			var oc := _out_cell(m)
			_items.append({"cell": oc, "dir": _m[oc]["dir"], "progress": 0.0,
				"type": "ore" if m["type"] == "drill" else "ingot", "by_hand": false})
	for it in _items.duplicate():
		it["progress"] = minf(1.0, it["progress"] + TICK)
		if it["progress"] < 1.0:
			continue
		var nxt: Vector2i = it["cell"] + it["dir"]
		if _conveyor_free(nxt):
			it["cell"] = nxt
			it["dir"] = _m[nxt]["dir"]
			it["progress"] = 0.0
		elif _occ.has(nxt) and _m[_occ[nxt]]["type"] in ["storage", "furnace"]:
			var t: Dictionary = _m[_occ[nxt]]
			if t["type"] == "storage" or (it["type"] == "ore" and t["buffers"]["ore"] < 10):
				t["buffers"][it["type"]] += 1
				_items.erase(it)
				if t["type"] == "storage":
					item_delivered.emit(it["type"], it["by_hand"])
	for c in _crops:
		var cr: Dictionary = _crops[c]
		if cr["wet"]:
			cr["wet_t"] -= TICK
			if cr["stage"] in [1, 2, 3]:
				cr["t"] += TICK
				var st := 1 + int(cr["t"] / 10.0)
				if st != cr["stage"]:
					cr["stage"] = st
					crop_changed.emit(c, st, true)
			if cr["wet_t"] <= 0.0:
				cr["wet"] = false
				crop_changed.emit(c, cr["stage"], false)

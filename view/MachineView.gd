# Рисует машины по сигналам симуляции: кадры анимации, вид по состоянию, значок проблемы. Владелец: B.
extends Node2D

const ANIM_FPS := {"conveyor": 8.0, "drill": 8.0, "furnace": 6.0, "sprinkler": 3.0, "harvester": 6.0, "campfire": 8.0}
const PRODUCERS := ["drill", "furnace", "sprinkler", "harvester"]   # у них есть «простаивает/работает»
const IDLE_TINT := Color(0.78, 0.78, 0.84)
const EXHAUSTED_TINT := Color(0.5, 0.5, 0.55)
const BLOCKED_TINT := Color(1.0, 0.45, 0.4)
const CAMPFIRE_GLOW_TIME := 0.25
const ICON_GAP := 7.0
const HIGHLIGHT_TIME := 8.0      # сколько секунд утром мигает машина из ночного отчёта
const HIGHLIGHT_COLOR := Color(1.0, 0.67, 0.27)
const ARROW_INSET := 4.0         # стрелка выхода сидит на краю машины, внутри её контура

var _nodes := {}      # клетка-якорь -> {type, sprite, icon, state}
var _time := 0.0
var _campfire_lit := 0.0
var _highlight_cell := Vector2i(-999, -999)
var _highlight_left := 0.0
# Единственное место, где B знает числа состояний симуляции.
@onready var _icon_of_state := {Sim.State.BLOCKED: "stop", Sim.State.NO_FUEL: "no_fuel",
	Sim.State.NO_WATER: "no_water", Sim.State.EXHAUSTED: "exhausted"}


func _ready() -> void:
	z_index = 1
	Sim.machine_placed.connect(_on_placed)
	Sim.machine_removed.connect(_on_removed)
	Sim.machine_state_changed.connect(_on_state)
	DayCycle.day_ended.connect(func(_day: int) -> void:
		_highlight_cell = Sim.night_summary().get("bottleneck", {}).get("cell", Vector2i(-999, -999)))
	DayCycle.day_started.connect(func(_day: int) -> void: _highlight_left = HIGHLIGHT_TIME)


func light_campfire(_cell: Vector2i) -> void:
	_campfire_lit = CAMPFIRE_GLOW_TIME


## Подсветка сноса: машина краснеет и сжимается, пока держат F.
func show_demolish(cell: Vector2i, _type: String, ratio: float) -> void:
	if _nodes.has(cell):
		_nodes[cell]["sprite"].scale = Vector2.ONE * (1.0 - 0.25 * ratio)
		_nodes[cell]["sprite"].self_modulate = Color.WHITE.lerp(BLOCKED_TINT, ratio)


func clear_demolish() -> void:
	for cell in _nodes:
		_nodes[cell]["sprite"].scale = Vector2.ONE
		_nodes[cell]["sprite"].self_modulate = Color.WHITE


func _on_placed(cell: Vector2i, type: String, dir: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = Sprites.machine(type)
	sprite.position = MachineCatalog.center(type, cell)
	if type == "conveyor":
		sprite.rotation = Vector2(dir).angle()
	add_child(sprite)
	var icon := Sprite2D.new()
	icon.visible = false
	icon.z_index = 3
	icon.position = sprite.position - Vector2(0, sprite.texture.get_height() * 0.5 + ICON_GAP)
	add_child(icon)
	if GameConfig.player()["directional"].has(type) and type != "conveyor":
		var arrow := Sprite2D.new()
		arrow.texture = Sprites.tex("arrow_out")
		arrow.position = Vector2(dir) * (sprite.texture.get_width() * 0.5 - ARROW_INSET)
		arrow.rotation = Vector2(dir).angle()
		arrow.modulate.a = 0.85
		sprite.add_child(arrow)
	_nodes[cell] = {"type": type, "sprite": sprite, "icon": icon, "state": Sim.State.IDLE}
	sprite.scale = Vector2.ZERO   # «клац»: 0 -> 1,1 -> 1
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.1, 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.06)


func _on_removed(cell: Vector2i) -> void:
	if _nodes.has(cell):
		_nodes[cell]["sprite"].queue_free()
		_nodes[cell]["icon"].queue_free()
		_nodes.erase(cell)


func _on_state(cell: Vector2i, state: int) -> void:
	if not _nodes.has(cell):
		return
	var node: Dictionary = _nodes[cell]
	node["state"] = state
	var icon: Sprite2D = node["icon"]
	icon.visible = _icon_of_state.has(state)
	if icon.visible:
		icon.texture = Sprites.state_icon(_icon_of_state[state])


func _process(delta: float) -> void:
	_time += delta * DayCycle.speed if DayCycle.running else 0.0
	_campfire_lit = maxf(0.0, _campfire_lit - delta)
	_highlight_left = maxf(0.0, _highlight_left - delta)
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	for cell in _nodes:
		var node: Dictionary = _nodes[cell]
		var type: String = node["type"]
		var sprite: Sprite2D = node["sprite"]
		var state: int = node["state"]
		var frame := int(_time * float(ANIM_FPS.get(type, 0.0)))
		var tint := Color.WHITE
		if type == "campfire":
			frame = 1 + frame % 3 if _campfire_lit > 0.0 else 0
		elif type == "furnace":
			frame = 1 + frame % 2 if state == Sim.State.WORKING else 0
		elif PRODUCERS.has(type) and state != Sim.State.WORKING:
			frame = 0
			tint = IDLE_TINT
		if state == Sim.State.BLOCKED:
			tint = Color.WHITE.lerp(BLOCKED_TINT, blink)
		elif state == Sim.State.EXHAUSTED:
			tint = EXHAUSTED_TINT
		if cell == _highlight_cell and _highlight_left > 0.0:
			tint = tint.lerp(HIGHLIGHT_COLOR, blink)
		sprite.texture = Sprites.machine(type, frame)
		sprite.modulate = tint
		node["icon"].offset.y = roundf(sin(Time.get_ticks_msec() * 0.005) * 1.5)

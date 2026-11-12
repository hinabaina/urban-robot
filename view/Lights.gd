# Тёплый свет в сумерках и ночью: окно юрты, костёр, фонарь склада, работающие печи, лампа на каске.
# Днём огни гаснут. Только картинка. Владелец: A.
extends Node2D

const WARM := Color("ffb866")
const FIRE := Color("ff8a3d")
const LAMP := Color("ffe9b0")
const SIZE := 128                 # сторона текстуры пятна света
const FURNACE_AT := Vector2(0, 4)

var _texture := GradientTexture2D.new()
var _lights: Array[PointLight2D] = []
var _furnaces := {}               # клетка-якорь печи -> PointLight2D
var _working := {}                # клетка-якорь печи -> работает ли
var _lamp: PointLight2D
var _player: Node2D
var _tint := Gradient.new()


func _ready() -> void:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	_texture.gradient = fade
	_texture.width = SIZE
	_texture.height = SIZE
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	Sim.machine_placed.connect(_on_placed)
	Sim.machine_removed.connect(_on_removed)
	Sim.machine_state_changed.connect(func(cell: Vector2i, state: int) -> void: _working[cell] = state == Sim.State.WORKING)


## Main зовёт, когда карта загружена.
func setup(player: Node2D, world: Node2D) -> void:
	_player = player
	var yurt: Sprite2D = world.get_node("Yurt")
	_add(yurt.position + Vector2(yurt.texture.get_width() * 0.5, yurt.texture.get_height() - 12.0), WARM, 1.5, 1.0)
	_add(TileCatalog.cell_center(world.marker_cell("Campfire")), FIRE, 1.0, 0.9)
	_add(MachineCatalog.center("storage", world.marker_cell("Storage")) - Vector2(0, 6), LAMP, 1.1, 0.8)
	_lamp = _add(Vector2.ZERO, LAMP, 1.3, 0.7)


func _add(pos: Vector2, color: Color, radius: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _texture
	light.position = pos
	light.color = color
	light.texture_scale = radius
	light.set_meta("energy", energy)
	light.energy = 0.0
	add_child(light)
	_lights.append(light)
	return light


func _on_placed(cell: Vector2i, type: String, _dir: Vector2i) -> void:
	if type == "furnace":
		_furnaces[cell] = _add(MachineCatalog.center(type, cell) + FURNACE_AT, FIRE, 0.9, 0.8)


func _on_removed(cell: Vector2i) -> void:
	if _furnaces.has(cell):
		_lights.erase(_furnaces[cell])
		_furnaces[cell].queue_free()
		_furnaces.erase(cell)
		_working.erase(cell)


func _process(_delta: float) -> void:
	# Темнота берётся из общего оттенка мира (CanvasModulate в Background): чем он темнее, тем ярче огни.
	var tint: Color = get_node("../Background").world_tint()
	var dark := clampf((1.0 - tint.get_luminance()) * 2.2, 0.0, 1.0)
	var flicker := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.011)
	for light in _lights:
		light.energy = float(light.get_meta("energy")) * dark * flicker
	for cell in _furnaces:
		# Печь светит и днём, если работает: под землёй это видно.
		_furnaces[cell].energy = (0.35 + 0.5 * dark) * flicker if _working.get(cell, false) else 0.0
	if _lamp and _player:
		_lamp.position = _player.global_position - Vector2(0, 6)

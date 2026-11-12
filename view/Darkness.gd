# Темнота шахты и свет в ней: лампа на каске героя, фонари в стволе, работающие печи и буры, костёр.
# Поверх темноты мерцают блики руды, чтобы жилы было видно в глубине. Только картинка. Владелец: B.
extends Node2D

const SURFACE_Y := 12.0 * 16.0
const MAX_LIGHTS := 24
const LAMP := Vector3(88.0, 1.0, -6.0)          # радиус, сила, подъём над центром героя (каска)
const LANTERN := Vector2(60.0, 0.85)
const SOURCES := {"furnace": Vector2(70.0, 0.9), "drill": Vector2(40.0, 0.55), "campfire": Vector2(56.0, 0.9)}
const LANTERNS: Array[Vector2i] = [Vector2i(31, 14), Vector2i(31, 17)]   # на стенке старой шахты
const GLINT_PERIOD := 2.6
const GLINT_TIME := 0.45
const GLINT := Color("fff3c4")

var _player: Node2D
var _machines: Node2D
var _rect := ColorRect.new()
var _material := ShaderMaterial.new()
var _glints := Node2D.new()


func _ready() -> void:
	z_index = 6                       # над машинами и героем, под всплывающим текстом и рентгеном
	_material.shader = load("res://view/shaders/darkness.gdshader")
	_material.set_shader_parameter("surface_y", SURFACE_Y)
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2(TileCatalog.MAP_SIZE * TileCatalog.TILE)
	add_child(_rect)
	_glints.z_index = 1
	_glints.draw.connect(_draw_glints)
	add_child(_glints)


## Main зовёт, когда карта загружена.
func setup(player: Node2D, machines: Node2D) -> void:
	_player = player
	_machines = machines


func _process(_delta: float) -> void:
	if _player == null:
		return
	var view := _view_rect()
	var lights: Array[Vector4] = [Vector4(_player.global_position.x, _player.global_position.y + LAMP.z, LAMP.x, LAMP.y)]
	for cell in LANTERNS:
		_push(lights, TileCatalog.cell_center(cell), LANTERN, view)
	for machine in Sim.get_machines():
		var type: String = machine.get("type")
		if not SOURCES.has(type):
			continue
		var lit: bool = machine.get("state") == Sim.State.WORKING or (type == "campfire" and _machines.campfire_glowing())
		if lit:
			_push(lights, MachineCatalog.center(type, machine.get("cell")), SOURCES[type], view)
	_material.set_shader_parameter("light_count", lights.size())
	var packed := PackedVector4Array(lights)
	packed.resize(MAX_LIGHTS)
	_material.set_shader_parameter("lights", packed)
	_glints.queue_redraw()


func _push(lights: Array[Vector4], pos: Vector2, light: Vector2, view: Rect2) -> void:
	if lights.size() < MAX_LIGHTS and view.grow(light.x).has_point(pos):
		lights.append(Vector4(pos.x, pos.y, light.x, light.y))


func _view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, _rect.size)
	var half := get_viewport_rect().size / camera.zoom * 0.5
	return Rect2(camera.get_screen_center_position() - half, half * 2.0)


## Блики на руде в кадре: короткая четырёхлучевая искра в случайный момент у каждого тайла.
func _draw_glints() -> void:
	var view := _view_rect().grow(TileCatalog.TILE)
	var from := TileCatalog.cell_at(view.position)
	var to := TileCatalog.cell_at(view.end)
	var time := Time.get_ticks_msec() * 0.001
	for y in range(maxi(from.y, 0), mini(to.y + 1, TileCatalog.MAP_SIZE.y)):
		for x in range(maxi(from.x, 0), mini(to.x + 1, TileCatalog.MAP_SIZE.x)):
			if Sim.get_tile(Vector2i(x, y)) != Sim.Tile.ORE:
				continue
			var seed := absi(x * 73856093 ^ y * 19349663)
			var t := fmod(time + float(seed % 1000) * 0.0137, GLINT_PERIOD)
			if t > GLINT_TIME:
				continue
			var k := sin(t / GLINT_TIME * PI)
			var at := Vector2(x * 16 + 3 + seed % 10, y * 16 + 3 + (seed / 7) % 10)
			var color := Color(GLINT, k)
			_glints.draw_rect(Rect2(at, Vector2.ONE), color)
			if k > 0.5:
				for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					_glints.draw_rect(Rect2(at + d, Vector2.ONE), Color(GLINT, k * 0.6))

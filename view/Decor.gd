# Живая степь: трава, ковыль, тюльпаны и камни на поверхности, дымок над юртой, пух на ветру, темнота глубины.
# Только картинка. Владелец: A.
extends Node2D

const SURFACE_ROW := 12            # строка верхнего слоя земли (как SURFACE_Y в Background)
const SHADE_ALPHA := 0.34          # насколько темнее самый низ карты
const SMOKE_AT := Vector2(31, 2)   # дымоход юрты относительно её левого верхнего угла
const GRASS := Color("7c9a3a")
const GRASS_DARK := Color("5d7a2c")
const FEATHER := Color("e9dfb4")
const STEM := Color("6f8a34")
const STONE := Color("8d8f9a")
const STONE_DARK := Color("5f6270")
const BUSH := Color("a08a52")
const PETALS := [Color("e8503a"), Color("f4d34f"), Color("f08fb0")]

var world: Node2D     # WorldLoader, задаёт Main

var _spots := {}      # столбец -> вид украшения; только там, где сейчас трава и над ней пусто
var _dirty := true
var _wind: CPUParticles2D


func _ready() -> void:
	Sim.tile_changed.connect(func(_cell: Vector2i, _kind: int) -> void: _dirty = true)
	Sim.machine_placed.connect(func(_cell: Vector2i, _type: String, _dir: Vector2i) -> void: _dirty = true)
	Sim.machine_removed.connect(func(_cell: Vector2i) -> void: _dirty = true)
	_wind = _particles(Color(0.96, 0.93, 0.8, 0.55), 12, 7.0)
	_wind.direction = Vector2(1, -0.1)
	_wind.spread = 12.0
	_wind.initial_velocity_min = 14.0
	_wind.initial_velocity_max = 34.0
	_wind.gravity = Vector2(0, 3)
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(380, 50)


## Main зовёт, когда карта загружена.
func setup(p_world: Node2D) -> void:
	world = p_world
	var smoke := _particles(Color(0.92, 0.92, 0.95, 0.5), 6, 2.6)
	smoke.position = (world.get_node("Yurt") as Sprite2D).position + SMOKE_AT
	smoke.direction = Vector2(0.4, -1)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 11.0
	smoke.gravity = Vector2(4, -4)
	smoke.scale_amount_max = 3.0


func _particles(color: Color, amount: int, lifetime: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.color = color
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	add_child(particles)
	return particles


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		_wind.position = Vector2(camera.get_screen_center_position().x - 120.0, SURFACE_ROW * TileCatalog.TILE - 60.0)
	if _dirty and world:
		_dirty = false
		_collect()
	queue_redraw()


## Где можно рисовать украшение: под клеткой трава, сама клетка пустая и не занята постройкой.
func _collect() -> void:
	_spots.clear()
	var busy := {}
	for machine in Sim.get_machines():
		for cell in MachineCatalog.cells(machine.get("type"), machine.get("cell")):
			busy[cell] = true
	for x in TileCatalog.MAP_SIZE.x:
		var above := Vector2i(x, SURFACE_ROW - 1)
		var below := Vector2i(x, SURFACE_ROW)
		if world.kind_at(below) != "soil" or busy.has(above) or busy.has(below) or world.is_well(above) or _under_sprite(above):
			continue
		_spots[x] = absi(x * 37 + x * x * 11 + 5) % 12


## Клетка закрыта юртой или копром шахты.
func _under_sprite(cell: Vector2i) -> bool:
	var point := TileCatalog.cell_center(cell)
	for sprite_name in ["Yurt", "Headframe"]:
		var sprite: Sprite2D = world.get_node(sprite_name)
		if Rect2(sprite.position, sprite.texture.get_size()).grow(2.0).has_point(point):
			return true
	return false


func _draw() -> void:
	var size := Vector2(TileCatalog.MAP_SIZE * TileCatalog.TILE)
	var top := float((SURFACE_ROW + 1) * TileCatalog.TILE)
	# Чем глубже, тем темнее: шахта читается как глубина, а не как плоская стена.
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), size, Vector2(0, size.y)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0.05, SHADE_ALPHA), Color(0, 0, 0.05, SHADE_ALPHA)]))
	var ground := float(SURFACE_ROW * TileCatalog.TILE)
	var time := Time.get_ticks_msec() * 0.001
	for x: int in _spots:
		var sway := roundf(sin(time * 1.7 + x * 0.9) * 1.2)       # порыв ветра качает верхушки
		var base := Vector2(x * TileCatalog.TILE + 3 + (x * 5) % 9, ground)
		match int(_spots[x]):
			0, 1, 2:
				_tuft(base, sway, 5 + x % 3)
				_tuft(base + Vector2(5, 0), sway, 4)
				_tuft(base - Vector2(4, 0), sway, 3)
			3, 4:
				_feather(base, sway, 11 + x % 4)
				_feather(base + Vector2(4, 0), sway, 8 + x % 3)
				_feather(base - Vector2(3, 0), sway, 7)
			5, 6:
				_tulip(base, sway, PETALS[x % PETALS.size()])
				_tulip(base + Vector2(6, 1), -sway, PETALS[(x + 1) % PETALS.size()])
				_tuft(base + Vector2(3, 0), sway, 4)
			7:
				draw_rect(Rect2(base.x, ground - 3, 5, 3), STONE)
				draw_rect(Rect2(base.x + 1, ground - 4, 3, 1), STONE)
				draw_rect(Rect2(base.x, ground - 1, 5, 1), STONE_DARK)
			8:
				for i in 4:
					draw_line(base + Vector2(2, 0), base + Vector2(-2 + i * 3 + sway * 0.5, -5 - i % 2), BUSH, 1.0)


func _tuft(base: Vector2, sway: float, height: int) -> void:
	draw_rect(Rect2(base.x, base.y - height + 1, 1, height - 1), GRASS_DARK)
	draw_rect(Rect2(base.x + sway * 0.5, base.y - height, 1, 1), GRASS)
	draw_rect(Rect2(base.x + 2, base.y - height + 2, 1, height - 2), GRASS)


## Ковыль: тонкий стебель и светлая метёлка, которая клонится по ветру.
func _feather(base: Vector2, sway: float, height: int) -> void:
	draw_rect(Rect2(base.x, base.y - height + 3, 1, height - 3), STEM)
	draw_rect(Rect2(base.x + sway * 0.5, base.y - height + 1, 1, 2), FEATHER)
	draw_rect(Rect2(base.x + sway, base.y - height, 2, 1), FEATHER)
	draw_rect(Rect2(base.x + sway + 1, base.y - height + 1, 2, 1), FEATHER)


## Степной тюльпан.
func _tulip(base: Vector2, sway: float, petals: Color) -> void:
	draw_rect(Rect2(base.x + 1, base.y - 5, 1, 5), STEM)
	draw_rect(Rect2(base.x + 2, base.y - 3, 1, 1), STEM)
	draw_rect(Rect2(base.x + sway * 0.5, base.y - 8, 3, 3), petals)
	draw_rect(Rect2(base.x + sway * 0.5 + 1, base.y - 8, 1, 1), petals.lightened(0.35))

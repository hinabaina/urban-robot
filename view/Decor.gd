# Живая степь: трава, ковыль, тюльпаны и камни на поверхности, дымок над юртой, пух на ветру, темнота глубины.
# Только картинка. Владелец: A.
extends Node2D

const SURFACE_ROW := 12            # строка верхнего слоя земли (как SURFACE_Y в Background)
const MAST_X := 22
const MAST_HEIGHT := 46.0
const CRATE_XS: Array[int] = [52, 53]
const FENCE_XS: Array[int] = [1, 2, 3, 21, 22]
const WOOD := Color("a8743e")
const WOOD_DARK := Color("5a3a22")
const BARREL := Color("8a5a32")
const METAL := Color("9aa8bd")
const METAL_DARK := Color("4a5468")
const WIRE := Color(0.25, 0.25, 0.3, 0.6)
const LANTERNS: Array[Vector2i] = [Vector2i(31, 14), Vector2i(31, 17)]   # те же, что светят в Darkness
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
var _fireflies: CPUParticles2D


func _ready() -> void:
	Sim.tile_changed.connect(func(_cell: Vector2i, _kind: int) -> void: _dirty = true)
	Sim.machine_placed.connect(func(_cell: Vector2i, _type: String, _dir: Vector2i) -> void: _dirty = true)
	Sim.machine_removed.connect(func(_cell: Vector2i) -> void: _dirty = true)
	# Светлячки над степью: видны только в сумерках и ночью.
	_fireflies = _particles(Color(0.85, 1.0, 0.45, 0.9), 14, 5.0)
	_fireflies.direction = Vector2(0, -1)
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 3.0
	_fireflies.initial_velocity_max = 9.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = Vector2(170, 22)
	_fireflies.scale_amount_max = 1.0
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
		_fireflies.position = Vector2(camera.get_screen_center_position().x, SURFACE_ROW * TileCatalog.TILE - 26.0)
	var background := get_node_or_null("../Background")
	if background:
		var tint: Color = background.world_tint()
		_fireflies.modulate.a = clampf((0.75 - tint.get_luminance()) * 3.0, 0.0, 1.0)
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
	# Глубину теперь показывает Darkness (шейдер со светом); здесь фонари на стенке старой шахты.
	for cell: Vector2i in LANTERNS:
		_lantern(Vector2(cell) * TileCatalog.TILE)
	_props()
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


## Обжитая станция: мачта рации у юрты, ящики и бочка у склада, заборчик у колодца.
func _props() -> void:
	var ground := float(SURFACE_ROW * TileCatalog.TILE)
	var busy := _busy_cells()
	_mast(Vector2(MAST_X * TileCatalog.TILE + 8, ground))
	for x in CRATE_XS:
		if not busy.has(Vector2i(x, SURFACE_ROW - 1)):
			_crates(Vector2(x * TileCatalog.TILE, ground), x)
	for x in FENCE_XS:
		if not busy.has(Vector2i(x, SURFACE_ROW - 1)) and world.kind_at(Vector2i(x, SURFACE_ROW)) != "":
			_fence(Vector2(x * TileCatalog.TILE, ground))


func _busy_cells() -> Dictionary:
	var busy := {}
	for machine in Sim.get_machines():
		for cell in MachineCatalog.cells(machine.get("type"), machine.get("cell")):
			busy[cell] = true
	return busy


## Мачта рации: решётчатая стойка, растяжки и мигающий красный огонёк (по ней звонят Айша и диспетчер).
func _mast(base: Vector2) -> void:
	var top := base.y - MAST_HEIGHT
	draw_line(base + Vector2(-6, 0), Vector2(base.x, top + 6), WIRE, 1.0)
	draw_line(base + Vector2(6, 0), Vector2(base.x, top + 6), WIRE, 1.0)
	draw_rect(Rect2(base.x - 1, top, 3, MAST_HEIGHT), METAL_DARK)
	draw_rect(Rect2(base.x, top, 1, MAST_HEIGHT), METAL)
	for y in range(int(top) + 4, int(base.y), 5):
		draw_rect(Rect2(base.x - 2, y, 5, 1), METAL_DARK)
	draw_rect(Rect2(base.x - 4, top + 2, 9, 1), METAL)
	var on := fmod(Time.get_ticks_msec() * 0.001, 1.6) < 0.5
	draw_rect(Rect2(base.x - 1, top - 2, 3, 2), Color("ff5a4a") if on else Color("6b2a2a"))
	if on:
		draw_rect(Rect2(base.x - 2, top - 3, 5, 4), Color(1.0, 0.35, 0.3, 0.25))


func _crates(base: Vector2, x: int) -> void:
	if x % 2 == 0:
		draw_rect(Rect2(base.x + 1, base.y - 10, 11, 10), WOOD_DARK)
		draw_rect(Rect2(base.x + 2, base.y - 9, 9, 8), WOOD)
		draw_line(Vector2(base.x + 2, base.y - 9), Vector2(base.x + 10, base.y - 2), WOOD_DARK, 1.0)
		draw_rect(Rect2(base.x + 4, base.y - 16, 7, 6), WOOD_DARK)
		draw_rect(Rect2(base.x + 5, base.y - 15, 5, 4), WOOD)
	else:
		draw_rect(Rect2(base.x + 3, base.y - 12, 9, 12), WOOD_DARK)
		draw_rect(Rect2(base.x + 4, base.y - 11, 7, 10), BARREL)
		draw_rect(Rect2(base.x + 3, base.y - 9, 9, 1), METAL)
		draw_rect(Rect2(base.x + 3, base.y - 4, 9, 1), METAL)


func _fence(base: Vector2) -> void:
	for dx in [2, 13]:
		draw_rect(Rect2(base.x + dx, base.y - 9, 2, 9), WOOD_DARK)
		draw_rect(Rect2(base.x + dx, base.y - 9, 1, 8), WOOD)
	draw_rect(Rect2(base.x, base.y - 7, 16, 1), WOOD)
	draw_rect(Rect2(base.x, base.y - 4, 16, 1), WOOD)


## Фонарь на крюке: тёплое стекло, тёмная оправа.
func _lantern(at: Vector2) -> void:
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.013 + at.y)
	draw_rect(Rect2(at.x + 9, at.y + 3, 5, 1), Color("1a1423"))
	draw_rect(Rect2(at.x + 9, at.y + 3, 1, 3), Color("1a1423"))
	draw_rect(Rect2(at.x + 7, at.y + 6, 5, 7), Color("1a1423"))
	draw_rect(Rect2(at.x + 8, at.y + 7, 3, 5), Color("ffcf6b") * flicker)
	draw_rect(Rect2(at.x + 9, at.y + 8, 1, 2), Color("fff3c4"))


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

# Небо, солнце и луна, облака, холмы степи и общий оттенок мира по времени суток. Владелец: B.
extends Node2D

const ORB_HORIZON := 14.0        # солнце и луна встают чуть выше земли
const ORB_TOP_MARGIN := 30.0     # и в зените не заходят под верхнюю панель (пиксели мира)
const SURFACE_Y := 192.0       # верх земли в пикселях (строка 12)
const BAND := 8.0
const HILLS := [["hills_far", 0.85, 30.0], ["hills_near", 0.7, 22.0]]   # текстура, параллакс, высота над землёй
const CLOUD_COUNT := 13
const BIRD_FLOCKS := 2
const STAR_COUNT := 60
# Часы -> цвет: верх неба, низ неба, общий оттенок мира.
const KEYS := [
	[0.0, "0b1030", "1d2750", "6f7fc0"], [5.0, "0b1030", "2a3463", "6f7fc0"], [6.5, "6f9fd8", "f7c58f", "ffe9d6"],
	[9.0, "5fb1ea", "cfeaf7", "ffffff"], [16.0, "5fb1ea", "cfeaf7", "ffffff"], [18.5, "56508f", "f29a5a", "ffc9a0"],
	[20.5, "141a44", "3a3a70", "8a90cc"], [24.0, "0b1030", "1d2750", "6f7fc0"],
]

var _top := Gradient.new()
var _bottom := Gradient.new()
var _tint := Gradient.new()
var _modulate := CanvasModulate.new()
var _width := float(TileCatalog.MAP_SIZE.x * TileCatalog.TILE)


func _ready() -> void:
	z_index = -100
	light_mask = 0   # огни (view/Lights.gd) освещают землю и постройки, но не небо
	add_child(_modulate)
	var offsets := PackedFloat32Array()
	var colors := [PackedColorArray(), PackedColorArray(), PackedColorArray()]
	for key in KEYS:
		offsets.append(key[0] / 24.0)
		for i in 3:
			colors[i].append(Color(key[i + 1]))
	var gradients: Array[Gradient] = [_top, _bottom, _tint]
	for i in 3:
		gradients[i].offsets = offsets
		gradients[i].colors = colors[i]


func _process(_delta: float) -> void:
	_modulate.color = _tint.sample(_day_fraction())
	queue_redraw()


## Общий оттенок мира сейчас (для огней: чем темнее, тем они ярче).
func world_tint() -> Color:
	return _modulate.color


func _day_fraction() -> float:
	return fmod(DayCycle.hour, 24.0) / 24.0


func _draw() -> void:
	var t := _day_fraction()
	var top := _top.sample(t)
	var bottom := _bottom.sample(t)
	# Небо не должно темнеть дважды: делим на общий оттенок, которым CanvasModulate умножит весь мир.
	var tint := _modulate.color
	var fix := Color(1.0 / maxf(tint.r, 0.01), 1.0 / maxf(tint.g, 0.01), 1.0 / maxf(tint.b, 0.01))
	var bands := int(SURFACE_Y / BAND)
	for i in bands:
		draw_rect(Rect2(0, i * BAND, _width, BAND), top.lerp(bottom, float(i) / float(bands - 1)) * fix)
	var darkness := clampf(1.0 - top.get_luminance() * 3.0, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STAR_COUNT:
		var pos := Vector2(rng.randf() * _width, rng.randf() * (SURFACE_Y - 50.0))
		draw_rect(Rect2(pos, Vector2.ONE), Color(1, 1, 1, darkness * rng.randf_range(0.4, 1.0)) * fix)
	var camera := get_viewport().get_camera_2d()
	var view_w := get_viewport_rect().size.x / (camera.zoom.x if camera else 1.0)
	var center_x := camera.get_screen_center_position().x if camera else _width * 0.5
	_draw_orb("sun", (fmod(DayCycle.hour, 24.0) - 5.5) / 13.5, center_x, view_w, fix)
	_draw_orb("moon", fmod(DayCycle.hour + 5.0, 24.0) / 11.5, center_x, view_w, fix)
	_draw_clouds(fix)
	_draw_birds(top.get_luminance(), fix)
	for hill in HILLS:
		var tex := Sprites.tex(hill[0])
		var shift := fposmod(center_x * hill[1], float(tex.get_width()))
		var x := -float(tex.get_width()) + shift
		while x < _width:
			draw_texture(tex, Vector2(x, SURFACE_Y - hill[2]))
			x += tex.get_width()


## Светило идёт по дуге через видимую часть экрана; phase 0..1 — от восхода до заката.
func _draw_orb(icon_name: String, phase: float, center_x: float, view_w: float, fix: Color) -> void:
	if phase < 0.0 or phase > 1.0:
		return
	# Дуга внутри видимого неба: от горизонта до полосы под верхней панелью, при любом зуме и сдвиге камеры.
	var camera := get_viewport().get_camera_2d()
	var view_top := SURFACE_Y - 200.0
	if camera:
		view_top = camera.get_screen_center_position().y - get_viewport_rect().size.y / camera.zoom.y * 0.5
	var low := SURFACE_Y - ORB_HORIZON
	var high := minf(view_top + ORB_TOP_MARGIN, low)
	var pos := Vector2(center_x + (phase - 0.5) * view_w * 0.9, lerpf(low, high, sin(phase * PI)))
	var glow := Color("fff0b0") if icon_name == "sun" else Color("cfd8ff")
	for i in 3:
		draw_circle(pos, 12.0 + i * 7.0, Color(glow, 0.10 - i * 0.025) * fix)
	draw_texture(Sprites.icon(icon_name), pos - Vector2(8, 8), fix)


## Облака в два слоя: дальние крупные и бледные плывут медленно, ближние быстрее.
func _draw_clouds(fix: Color) -> void:
	var clouds := Sprites.tex("clouds")
	var drift := Time.get_ticks_msec() * 0.001
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in CLOUD_COUNT:
		var far := i % 3 == 0
		var scale := 2.0 if far else 1.0
		var speed := rng.randf_range(1.0, 2.0) if far else rng.randf_range(2.5, 5.0)
		var x := fposmod(rng.randf() * _width + drift * speed, _width + 192.0) - 96.0
		var y := rng.randf_range(8.0, 70.0) if far else rng.randf_range(20.0, 120.0)
		var alpha := 0.45 if far else rng.randf_range(0.7, 0.9)
		draw_texture_rect_region(clouds, Rect2(roundf(x), roundf(y), 48 * scale, 16 * scale),
			Rect2(rng.randi_range(0, 1) * 48, 0, 48, 16), Color(1, 1, 1, alpha) * Color(fix, 1.0))


## Стайки птиц днём: галочки, которые машут крыльями и летят против ветра.
func _draw_birds(daylight: float, fix: Color) -> void:
	if daylight < 0.35:
		return
	var time := Time.get_ticks_msec() * 0.001
	var color := Color(0.16, 0.14, 0.2, 0.8) * Color(fix, 1.0)
	for flock in BIRD_FLOCKS:
		var lead := Vector2(_width + 60.0 - fposmod(time * (13.0 + flock * 5.0) + flock * 500.0, _width + 120.0),
			46.0 + flock * 38.0 + sin(time * 0.4 + flock) * 6.0)
		for i in 4 + flock:
			var pos := (lead + Vector2(i * 9.0, (i % 2) * 6.0 + i * 2.0)).round()
			var wing := 1.0 + roundf(sin(time * 7.0 + i * 1.3) * 1.5)
			draw_line(pos, pos + Vector2(-3, -wing), color, 1.0)
			draw_line(pos, pos + Vector2(3, -wing), color, 1.0)

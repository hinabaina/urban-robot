# Небо, солнце и луна, облака, холмы степи и общий оттенок мира по времени суток. Владелец: B.
extends Node2D

const SURFACE_Y := 192.0       # верх земли в пикселях (строка 12)
const BAND := 8.0
const HILLS := [["hills_far", 0.85, 30.0], ["hills_near", 0.7, 22.0]]   # текстура, параллакс, высота над землёй
const CLOUDS := [[90.0, 30.0, 4.0, 0], [380.0, 58.0, 2.5, 1], [640.0, 22.0, 3.2, 1], [900.0, 70.0, 2.0, 0]]
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
	var clouds := Sprites.tex("clouds")
	var drift := Time.get_ticks_msec() * 0.001
	for cloud in CLOUDS:
		var x := fposmod(cloud[0] + drift * cloud[2], _width + 96.0) - 48.0
		draw_texture_rect_region(clouds, Rect2(x, cloud[1], 48, 16), Rect2(cloud[3] * 48, 0, 48, 16), Color(1, 1, 1, 0.85))
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
	var pos := Vector2(center_x + (phase - 0.5) * view_w * 0.9, SURFACE_Y - 30.0 - sin(phase * PI) * 120.0)
	draw_texture(Sprites.icon(icon_name), pos - Vector2(8, 8), fix)

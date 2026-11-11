# Картинка вступительного ролика: шесть сцен, нарисованных кодом из пиксель-арта игры. Владелец: A.
# Рисует в маленьком холсте 320x180, который Intro растягивает в 4 раза без сглаживания.
# Время задаёт Intro: scene (номер сцены) и u (секунды от её начала), dur (длина сцены).
class_name IntroStage
extends Node2D

const W := 320.0
const H := 180.0
const GROUND := 132.0                 # верх земли в сценах со степью
const TILE := 16
const SPRITES := "res://assets/sprites/"
enum Scene { DROUGHT, STORM, SATELLITE, STATION, QUOTA, FACTORY, TITLE }

var scene := Scene.DROUGHT
var u := 0.0
var dur := 1.0
var shake := 0.0                      # сила тряски, затухает сама
var flash := 0.0                      # белая вспышка молнии, затухает сама

var _tex := {}
var _rng := RandomNumberGenerator.new()
var _dust: Array[Vector3] = []        # x, y, скорость
var _stars: Array[Vector3] = []       # x, y, фаза мерцания


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 2026
	for i in 70:
		_dust.append(Vector3(_rng.randf() * W, _rng.randf_range(20.0, H), _rng.randf_range(0.5, 1.5)))
	for i in 80:
		_stars.append(Vector3(_rng.randf() * W, _rng.randf() * 110.0, _rng.randf() * TAU))


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 6.0)
	flash = maxf(0.0, flash - delta * 2.5)
	position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 3.0
	queue_redraw()


func _draw() -> void:
	match scene:
		Scene.DROUGHT: _draw_drought()
		Scene.STORM: _draw_storm()
		Scene.SATELLITE: _draw_satellite()
		Scene.STATION: _draw_station()
		Scene.QUOTA: _draw_quota()
		Scene.FACTORY: _draw_factory()
		Scene.TITLE: _draw_title()
	if flash > 0.0:
		draw_rect(Rect2(-8, -8, W + 16, H + 16), Color(1, 1, 0.95, flash))


## Доля сцены 0..1.
func _p() -> float:
	return clampf(u / maxf(dur, 0.01), 0.0, 1.0)


# --- Сцены ------------------------------------------------------------------

## 1. Засуха: пылающее солнце, марево, трава выгорает, по земле ползут трещины.
func _draw_drought() -> void:
	var p := _p()
	_sky(Color("e89a3c"), Color("fde2a2"))
	var sun := Vector2(232, 46)
	var pulse := 1.0 + 0.08 * sin(u * 3.0)
	for i in 4:
		draw_circle(sun, (34.0 - i * 6.0) * pulse, Color(1.0, 0.85, 0.4, 0.10 + i * 0.05))
	for i in 12:
		var a := u * 0.25 + i * TAU / 12.0
		draw_line(sun + Vector2.from_angle(a) * 22.0 * pulse, sun + Vector2.from_angle(a) * (30.0 + 4.0 * sin(u * 5.0 + i)) * pulse, Color("fff3a8"), 2.0)
	draw_circle(sun, 16.0 * pulse, Color("fff3a8"))
	draw_circle(sun, 13.0 * pulse, Color("ffffff"))
	var pan := -u * 5.0
	_hills(pan, Color("e0b080"), Color("c8925e"))
	var dry := Color(1, 1, 1).lerp(Color(1.25, 0.95, 0.55), p)
	_ground("grass", pan * 1.4, GROUND, dry)
	_dead_tree(Vector2(70 + pan * 1.4 + 40, GROUND), p)
	_cracks(pan * 1.4, smoothstep(0.1, 0.9, p))
	_shimmer(GROUND - 14.0, 0.18)
	_dust_motes(Color(0.95, 0.75, 0.45, 0.5), 10.0)


## 2. Урожай гибнет: колосья желтеют и никнут, приходит пыльная буря с молниями и уносит их.
func _draw_storm() -> void:
	var p := _p()
	var storm := smoothstep(0.30, 0.50, p)
	_sky(Color("e8a04a").lerp(Color("2a2230"), storm), Color("f6d39a").lerp(Color("6b5040"), storm))
	_hills(-u * 2.0, Color("d09a6a").lerp(Color("3b2d2c"), storm), Color("b07a4a").lerp(Color("2d2222"), storm))
	# Тяжёлые тучи наползают слева.
	var clouds := _t("clouds")
	for i in 7:
		var x := -140.0 + i * 52.0 + storm * 150.0 + sin(u + i) * 3.0
		draw_texture_rect_region(clouds, Rect2(x, 4 + (i % 3) * 14, 96, 32), Rect2((i % 2) * 48, 0, 48, 16), Color(0.35, 0.3, 0.33, storm))
	_ground("soil", 0.0, GROUND, Color(1.05, 0.9, 0.75).lerp(Color(0.55, 0.45, 0.4), storm))
	# Ряд колосьев: зелёные -> жёлтые -> никнут -> ветер уносит.
	var crops := _t("crops")
	var wilt := smoothstep(0.0, 0.35, p)
	for i in 15:
		var base := Vector2(28 + i * 18, GROUND)
		var gone := clampf((p - 0.62 - i * 0.012) * 4.0, 0.0, 1.0)
		var frame := 1 if wilt < 0.4 else 2
		var tint := Color(1, 1, 1).lerp(Color(0.75, 0.55, 0.3), wilt)
		var lean := wilt * 0.5 + storm * (0.4 + 0.2 * sin(u * 9.0 + i))
		var fly := Vector2(-gone * gone * 260.0, -gone * 70.0 * (0.6 + 0.4 * sin(i)))
		draw_set_transform(base + fly, -lean - gone * 6.0, Vector2(1, 1.0 - wilt * 0.3))
		draw_texture_rect_region(crops, Rect2(-8, -16, 16, 16), Rect2(frame * 16, 0, 16, 16), Color(tint, 1.0 - gone * 0.6))
		draw_set_transform(Vector2.ZERO)
	# Ветер и пыль.
	if storm > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.45, 0.32, 0.22, storm * 0.35))
		for i in 40:
			var y := fposmod(i * 23.0, H)
			var x := W - fposmod(u * 420.0 + i * 61.0, W + 80.0)
			draw_line(Vector2(x, y), Vector2(x + 18 + (i % 4) * 6, y + 1), Color(0.9, 0.75, 0.55, 0.35 * storm), 1.0)
	_dust_motes(Color(0.85, 0.65, 0.45, 0.7 * storm), 120.0 * storm + 8.0)
	# Молнии в моменты вспышек (их запускает Intro по таймингу).
	if flash > 0.35:
		_bolt(Vector2(90 + fmod(u * 97.0, 140.0), 0), GROUND - 10)


## 3. Метеоспутник: ночь, звёзды, фермеры смотрят на небо, спутник проходит и сканирует облака.
func _draw_satellite() -> void:
	var p := _p()
	_sky(Color("0b1030"), Color("2a3463"))
	for s in _stars:
		draw_rect(Rect2(s.x, s.y, 1, 1), Color(1, 1, 0.9, 0.5 + 0.5 * sin(u * 2.5 + s.z)))
	# Облака далёкой бури у горизонта.
	var clouds := _t("clouds")
	for i in 4:
		draw_texture_rect_region(clouds, Rect2(20 + i * 75, 84 + (i % 2) * 6, 64, 21), Rect2((i % 2) * 48, 0, 48, 16), Color(0.35, 0.38, 0.6, 0.8))
	_hills(0.0, Color("1d2750"), Color("161d3c"))
	_ground("grass", 0.0, GROUND, Color(0.35, 0.4, 0.65))
	draw_texture(_t("yurt"), Vector2(24, GROUND - 48), Color(0.4, 0.45, 0.7))
	_person(Vector2(120, GROUND), int(u * 2.0) % 2, false, Color(0.55, 0.6, 0.9))
	_person(Vector2(140, GROUND), (int(u * 2.0) + 1) % 2, true, Color(0.5, 0.55, 0.85))
	# Спутник по дуге и его луч.
	var pos := Vector2(lerpf(-20.0, W + 20.0, p), 34.0 + 10.0 * pow(p * 2.0 - 1.0, 2.0))
	var beam := PackedVector2Array([pos, Vector2(pos.x - 34, 108), Vector2(pos.x + 34, 108)])
	draw_colored_polygon(beam, Color(0.5, 1.0, 0.6, 0.10 + 0.05 * sin(u * 8.0)))
	for k in 3:
		var r := fposmod(u * 30.0 + k * 14.0, 42.0)
		draw_arc(Vector2(pos.x, 104), r, PI, TAU, 24, Color(0.6, 1.0, 0.7, 0.5 * (1.0 - r / 42.0)), 1.0)
	_satellite(pos)


## 4. Станция: рассвет, камера едет вдоль юрты, костра и копра к ржавой недостроенной ракете; идёт герой.
func _draw_station() -> void:
	var p := _p()
	_sky(Color("6f9fd8"), Color("f7c58f"))
	var cam := -smoothstep(0.0, 1.0, p) * 170.0
	_hills(cam * 0.3, Color("c9a07a"), Color("a77d58"))
	_ground("grass", cam, GROUND, Color(1.1, 1.0, 0.8))
	draw_texture(_t("yurt"), Vector2(30 + cam, GROUND - 48))
	var fire := _t("campfire")
	draw_texture_rect_region(fire, Rect2(112 + cam, GROUND - 16, 16, 16), Rect2((1 + int(u * 8.0) % 3) * 16, 0, 16, 16))
	draw_texture(_t("headframe"), Vector2(170 + cam, GROUND - 40), Color(0.85, 0.75, 0.7))
	# Ракета: только низ и двигатель, ржавые, в лесах.
	var rx := 400.0 + cam
	var base := _t("rocket_base")
	var engine := _t("rocket_engine")
	draw_texture(base, Vector2(rx - 16, GROUND - 12), Color(0.85, 0.7, 0.6))
	draw_texture(engine, Vector2(rx - 16, GROUND - 32), Color(0.8, 0.65, 0.55))
	draw_texture(_t("rocket_patch"), Vector2(rx - 6, GROUND - 26))
	for k in 4:
		var y := GROUND - 30.0 - k * 22.0
		draw_line(Vector2(rx - 26, GROUND), Vector2(rx - 26, y), Color("7a4a2c"), 1.0)
		draw_line(Vector2(rx + 26, GROUND), Vector2(rx + 26, y), Color("7a4a2c"), 1.0)
		draw_line(Vector2(rx - 26, y), Vector2(rx + 26, y), Color("a86b3c"), 1.0)
	_dashed_rocket(Vector2(rx, GROUND - 32), 0.35 + 0.15 * sin(u * 3.0))
	# Герой идёт к ракете.
	var walk := smoothstep(0.15, 0.95, p)
	_person(Vector2(lerpf(70.0, 360.0, walk) + cam, GROUND), 2 + int(u * 8.0) % 4 if walk < 1.0 else 0, false, Color.WHITE)
	_dust_motes(Color(1, 0.9, 0.7, 0.3), 6.0)


## 5. Квота: герой копает руду киркой, слитки появляются по одному. Счётчик и дни рисует Intro.
func _draw_quota() -> void:
	_sky(Color("5fb1ea"), Color("cfeaf7"))
	_hills(0.0, Color("9fb59a"), Color("889e7c"))
	_ground("grass", 0.0, 112.0, Color.WHITE)
	# Разрез: под героем жила руды.
	var tiles := _t("tiles")
	for x in range(7, 13):
		for y in range(8, 12):
			var ore := (x + y) % 3 == 0 and y >= 9
			var cell := Vector2i(x % 2, 2) if ore else Vector2i(x % 3, 0)
			draw_texture_rect_region(tiles, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(cell * TILE, Vector2(TILE, TILE)))
	var hero := Vector2(150, 112)
	var swing := sin(u * 9.0)
	var hit := fposmod(u * 9.0 / TAU, 1.0)
	# Рудная глыба прямо перед героем: кирка бьёт в неё, при ударе она вздрагивает.
	var jolt := Vector2(1, 0) if hit < 0.12 else Vector2.ZERO
	for x in 2:
		for y in 2:
			var cell := Vector2i((x + y) % 2, 2)
			draw_texture_rect_region(tiles, Rect2(hero + Vector2(12 + x * TILE, -32 + y * TILE) + jolt, Vector2(TILE, TILE)),
				Rect2(cell * TILE, Vector2(TILE, TILE)))
	_person(hero, 0, false, Color.WHITE)
	draw_set_transform(hero + Vector2(10, -12), -0.6 + swing * 0.9, Vector2.ONE)
	draw_texture_rect_region(_t("icons"), Rect2(-4, -14, 16, 16), Rect2(0, 0, 16, 16))
	draw_set_transform(Vector2.ZERO)
	# Искра и осколки руды отлетают от глыбы к герою при каждом ударе.
	if hit < 0.1:
		draw_circle(hero + Vector2(13, -14), 3.0, Color("fff3a8"))
	if hit < 0.35:
		for k in 5:
			var v := Vector2(-8.0 - k * 4.0, -16.0 - (k % 3) * 6.0) * hit * 3.0
			draw_rect(Rect2(hero + Vector2(13, -14) + v + Vector2(0, 50.0 * hit * hit), Vector2(2, 2)), Color("e07b24"))
	# Капли пота: тяжело.
	draw_rect(Rect2(hero + Vector2(-6, -22 + fposmod(u * 14.0, 10.0)), Vector2(1, 2)), Color("7cc4f2"))


## 6. Фабрика: бур, конвейер, печь и дрон работают сами, ракета собрана и взлетает.
func _draw_factory() -> void:
	var p := _p()
	var launch := smoothstep(0.62, 1.0, p)
	_sky(Color("5fb1ea").lerp(Color("f29a5a"), launch * 0.6), Color("cfeaf7").lerp(Color("ffd9a0"), launch))
	_hills(-u * 3.0, Color("b5c39a"), Color("98a87c"))
	_ground("grass", 0.0, GROUND, Color.WHITE)
	var frame := int(u * 8.0)
	var y := GROUND - 32
	var drill := _t("drill")
	draw_texture_rect_region(drill, Rect2(8, y, 32, 32), Rect2((1 + frame % 3) * 32, 0, 32, 32))
	var belt := _t("conveyor")
	for i in 8:
		draw_texture_rect_region(belt, Rect2(40 + i * 16, GROUND - 16, 16, 16), Rect2((frame % 4) * 16, 0, 16, 16))
	var items := _t("items")
	for i in 6:
		var x := 40.0 + fposmod(u * 22.0 + i * 21.0, 128.0)
		draw_texture_rect_region(items, Rect2(x, GROUND - 18, 8, 8), Rect2(0, 0, 8, 8))
	var furnace := _t("furnace")
	draw_texture_rect_region(furnace, Rect2(168, y, 32, 32), Rect2((1 + frame % 2) * 32, 0, 32, 32))
	draw_circle(Vector2(184, y + 22), 6.0 + 2.0 * sin(u * 12.0), Color(1, 0.6, 0.2, 0.25))
	for i in 3:
		var x := 200.0 + fposmod(u * 26.0 + i * 16.0, 48.0)
		draw_texture_rect_region(belt, Rect2(200 + i * 16, GROUND - 16, 16, 16), Rect2((frame % 4) * 16, 0, 16, 16))
		draw_texture_rect_region(items, Rect2(x, GROUND - 18, 8, 8), Rect2(16, 0, 8, 8))
	# Дрон уносит слитки к ракете.
	var drone := _t("drone")
	var dpos := Vector2(fposmod(u * 70.0, W + 40.0) - 20.0, 40.0 + sin(u * 3.0) * 4.0)
	draw_texture_rect_region(drone, Rect2(dpos, Vector2(32, 16)), Rect2((frame % 2) * 32, 0, 32, 16))
	_rocket(Vector2(284, GROUND), launch)


## 7. Название и затемнение.
func _draw_title() -> void:
	_sky(Color("141a44"), Color("f29a5a"))
	_hills(0.0, Color("3a3060"), Color("2a2448"))
	_ground("grass", 0.0, GROUND, Color(0.5, 0.45, 0.6))
	# Ракета уже высоко: хвост дыма через всё небо.
	for i in 30:
		var t := float(i) / 30.0
		draw_circle(Vector2(284 + sin(t * 8.0) * 4.0, GROUND - t * 160.0 - u * 20.0), 3.0 + t * 6.0, Color(1, 1, 1, 0.25 * (1.0 - t)))
	var top := Vector2(284, GROUND - 175.0 - u * 60.0)
	draw_circle(top, 3.0, Color("fff3a8"))


# --- Помощники ----------------------------------------------------------------

func _t(file_name: String) -> Texture2D:
	if not _tex.has(file_name):
		_tex[file_name] = load(SPRITES + file_name + ".png")
	return _tex[file_name]


func _sky(top: Color, bottom: Color) -> void:
	var rect := PackedVector2Array([Vector2(-8, -8), Vector2(W + 8, -8), Vector2(W + 8, H + 8), Vector2(-8, H + 8)])
	draw_polygon(rect, PackedColorArray([top, top, bottom, bottom]))


## Два слоя холмов из игры, с параллаксом и своим цветом для настроения.
func _hills(pan: float, far: Color, near: Color) -> void:
	var layers := [["hills_far", 0.5, 30.0, far], ["hills_near", 0.8, 20.0, near]]
	for layer in layers:
		var tex := _t(layer[0])
		var shift := fposmod(pan * float(layer[1]), 256.0)
		for k in 3:
			draw_texture(tex, Vector2(-256 + shift + k * 256, GROUND - float(layer[2]) - 20.0), layer[3])


## Земля: верхний ряд тайлов (трава или почва) и почва до низа кадра.
func _ground(top_tile: String, pan: float, top: float, tint: Color) -> void:
	var tiles := _t("tiles")
	var top_cell := Vector2i(3, 0) if top_tile == "grass" else Vector2i(0, 0)
	var shift := fposmod(pan, TILE)
	var x := -TILE + shift
	while x < W + TILE:
		var y := top
		var row := 0
		while y < H + TILE:
			var cell := top_cell if row == 0 else Vector2i(int(absf(x + row * 3.0) / TILE) % 3, 0)
			draw_texture_rect_region(tiles, Rect2(x, y, TILE, TILE), Rect2(cell * TILE, Vector2(TILE, TILE)), tint)
			y += TILE
			row += 1
		x += TILE


## Марево: короткие дрожащие блики над землёй, как от раскалённого воздуха.
func _shimmer(y: float, alpha: float) -> void:
	for i in 26:
		var row := i % 5
		var x := fposmod(i * 47.0 + sin(u * 3.0 + i) * 6.0, W)
		var yy := y + row * 2.5 + sin(u * 7.0 + i * 1.7) * 0.8
		draw_line(Vector2(x, yy), Vector2(x + 10 + (i % 3) * 6, yy), Color(1, 0.97, 0.85, alpha * (1.0 - row / 5.0)), 1.0)


## Трещины в сухой земле: ломаные линии, которые растут вглубь с долей grow 0..1.
func _cracks(pan: float, grow: float) -> void:
	if grow <= 0.0:
		return
	var color := Color(0.22, 0.12, 0.08, 0.85)
	for i in 9:
		var x0 := fposmod(i * 61.0 + 20.0 + pan, W + 40.0) - 20.0
		var p := Vector2(x0, GROUND + 3)
		var steps := int(1 + grow * 6.0)
		for k in steps:
			var next := p + Vector2(sin(i * 3.1 + k * 1.9) * 5.0, 3.0 + (k % 2) * 2.0)
			draw_line(p, next, color, 1.0)
			if k == 2:
				draw_line(next, next + Vector2(6.0 if i % 2 == 0 else -6.0, 2.0), color, 1.0)
			p = next


func _dust_motes(color: Color, speed: float) -> void:
	if color.a <= 0.0:
		return
	for d in _dust:
		var x := W - fposmod(u * speed * d.z + d.x, W + 10.0)
		draw_rect(Rect2(x, d.y + sin(u * 2.0 + d.x) * 3.0, 1, 1), color)


func _dead_tree(root: Vector2, p: float) -> void:
	var c := Color("4e2f1f")
	draw_line(root, root + Vector2(0, -34), c, 2.0)
	draw_line(root + Vector2(0, -20), root + Vector2(-12, -30), c, 1.0)
	draw_line(root + Vector2(0, -26), root + Vector2(10, -38), c, 1.0)
	draw_line(root + Vector2(-12, -30), root + Vector2(-16, -38), c, 1.0)
	# Последние листья опадают.
	for k in 4:
		var fall := fposmod(u * 0.4 + k * 0.25, 1.0)
		if p > k * 0.2:
			draw_rect(Rect2(root + Vector2(-10 + k * 6 + sin(fall * 9.0) * 4.0, -34 + fall * 34.0), Vector2(2, 1)), Color("c8bf5a"))


func _bolt(from: Vector2, bottom: float) -> void:
	var points := PackedVector2Array([from])
	var p := from
	_rng.seed = int(from.x)
	while p.y < bottom:
		p += Vector2(_rng.randf_range(-10, 10), _rng.randf_range(8, 16))
		points.append(p)
	draw_polyline(points, Color("fff3a8"), 2.0)
	draw_polyline(points, Color.WHITE, 1.0)


## Человек из листа игрока; flip смотрит влево.
func _person(feet: Vector2, frame: int, flip: bool, tint: Color) -> void:
	var sheet := _t("player")
	var size := Vector2(16, 24)
	var rect := Rect2(feet - Vector2(8, 24), size)
	if flip:
		rect.size.x = -size.x
		rect.position.x += size.x
	draw_texture_rect_region(sheet, rect, Rect2(frame * 16, 0, 16, 24), tint)


func _satellite(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(4, 3), Vector2(8, 6)), Color("9aa8bd"))
	draw_rect(Rect2(pos - Vector2(3, 2), Vector2(6, 4)), Color("d3dbe6"))
	for side in [-1, 1]:
		var panel := Rect2(pos + Vector2(-14 if side < 0 else 6, -3), Vector2(8, 6))
		draw_rect(panel, Color("3a86d6"))
		draw_line(panel.position + Vector2(4, 0), panel.position + Vector2(4, 6), Color("1f4e8c"))
		draw_line(pos + Vector2(side * 4, 0), pos + Vector2(side * 6, 0), Color("9aa8bd"))
	draw_line(pos + Vector2(0, 3), pos + Vector2(0, 6), Color("d3dbe6"))
	if int(u * 3.0) % 2 == 0:
		draw_rect(Rect2(pos + Vector2(-1, -5), Vector2(2, 2)), Color("f0705a"))


## Пунктирный силуэт недостающих частей ракеты.
func _dashed_rocket(top: Vector2, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha)
	var h := 84.0
	for k in int(h / 4.0):
		if k % 2 == 0:
			draw_line(top + Vector2(-14, -k * 4), top + Vector2(-14, -k * 4 - 2), c)
			draw_line(top + Vector2(14, -k * 4), top + Vector2(14, -k * 4 - 2), c)
	draw_line(top + Vector2(-14, -h), top + Vector2(0, -h - 18), c)
	draw_line(top + Vector2(14, -h), top + Vector2(0, -h - 18), c)


## Собранная ракета; launch 0..1 — взлёт с пламенем и дымом.
func _rocket(foot: Vector2, launch: float) -> void:
	var rise := launch * launch * 220.0
	if launch > 0.0:
		shake = maxf(shake, 0.6 * (1.0 - launch))
		for i in 14:
			var t := fposmod(u * 1.6 + i / 14.0, 1.0)
			var puff := foot + Vector2(sin(i * 2.1) * 30.0 * t, -4.0 - t * 10.0)
			draw_circle(puff, 4.0 + t * 12.0, Color(0.95, 0.92, 0.88, 0.55 * (1.0 - t) * minf(launch * 4.0, 1.0)))
	var y := foot.y - rise
	var parts := ["rocket_base", "rocket_engine", "rocket_tank", "rocket_hull", "rocket_nose"]
	if launch > 0.0:
		var flame := 10.0 + 6.0 * sin(u * 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 7, y), Vector2(foot.x + 7, y), Vector2(foot.x, y + flame + 8)]), Color("ffab45"))
		draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 4, y), Vector2(foot.x + 4, y), Vector2(foot.x, y + flame)]), Color("fff3a8"))
	for part in parts:
		var tex := _t(part)
		y -= tex.get_height()
		draw_texture(tex, Vector2(foot.x - 16, y))

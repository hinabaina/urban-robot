# Камера в духе Terraria: крупный целый зум, мягкое следование, взгляд вверх на поверхности и вниз в шахте,
# лёгкий упреждающий сдвиг по ходу бега, тряска отдельно от кино-сдвига (offset). Владелец: B.
extends Camera2D

const SURFACE_Y := 12.0 * 16.0     # верх земли в пикселях мира (строка 12)
const UNDERGROUND_FROM := 8.0      # ноги ниже поверхности на столько пикселей — уже шахта
const SHAKE_BASE_ZOOM := 2.0

var shake_offset := Vector2.ZERO   # тряска от Juice; кино-моменты двигают offset, они не мешают друг другу

var _cfg: Dictionary = {}
var _target: Node2D
var _look := Vector2.ZERO          # куда смотрим относительно героя (плавно)
var _pos := Vector2.ZERO           # сглаженная точка следования (без тряски)
var _bounds := Rect2()
var _anchor_y := 0.0               # высота, за которой камера следит по вертикали (земля под героем)


func _ready() -> void:
	_cfg = GameConfig.player()["camera"]
	_target = get_parent()
	top_level = true                  # камера сама решает, где ей быть, а не едет жёстко за родителем
	position_smoothing_enabled = false
	zoom = Vector2.ONE * float(_cfg["zoom"])
	get_viewport().size_changed.connect(snap)
	snap.call_deferred()


## Границы мира: камера не показывает пустоту за краями карты.
func set_bounds(world: Rect2) -> void:
	_bounds = world
	limit_left = int(world.position.x)
	limit_top = int(world.position.y)
	limit_right = int(world.end.x)
	limit_bottom = int(world.end.y)
	snap()


## Встать на место сразу, без плавного подъезда (новый день, телепорт, смена размера окна).
func snap() -> void:
	if _target == null:
		return
	_look = _wanted_look()
	_anchor_y = _target.global_position.y
	_pos = _clamp(_follow_point() + _look)
	global_position = _pos


func _process(delta: float) -> void:
	if _target == null:
		return
	_look = _look.lerp(_wanted_look(), 1.0 - exp(-float(_cfg["look_speed"]) * delta))
	_update_anchor()
	_pos = _pos.lerp(_clamp(_follow_point() + _look), 1.0 - exp(-float(_cfg["follow_speed"]) * delta))
	# Тряска задана в пикселях мира под старый зум 2; на крупном зуме гасим её, чтобы на экране размах был прежним.
	global_position = _pos + shake_offset * (SHAKE_BASE_ZOOM / zoom.x)


## Как в Terraria: в прыжке камера по вертикали стоит, едет только на земле, на лестнице, при падении
## ниже прежней опоры или если герой поднялся заметно выше (например, запрыгнул на машину).
func _update_anchor() -> void:
	var y := _target.global_position.y
	var grounded: bool = _target.is_on_floor() if _target.has_method("is_on_floor") else true
	var climbing: bool = _target.get("climbing") == true
	if grounded or climbing or y > _anchor_y or _anchor_y - y > float(_cfg["jump_follow_px"]):
		_anchor_y = y


func _follow_point() -> Vector2:
	return Vector2(_target.global_position.x, _anchor_y)


## На поверхности смотрим выше героя (юрта, небо), в шахте — ниже ног (руда под ним), в беге — чуть вперёд.
func _wanted_look() -> Vector2:
	var tile := float(TileCatalog.TILE)
	var feet: float = _target.feet_y() if _target.has_method("feet_y") else _target.global_position.y
	var underground := feet > SURFACE_Y + UNDERGROUND_FROM
	var y := float(_cfg["look_down_tiles"]) * tile if underground else -float(_cfg["look_up_tiles"]) * tile
	var vx: float = _target.velocity.x if "velocity" in _target else 0.0
	# Остановился — камера тоже стоит: иначе мир ползёт под неподвижным курсором и машина встаёт не туда.
	var x := signf(vx) * float(_cfg["lead_tiles"]) * tile if absf(vx) > 1.0 else _look.x
	return Vector2(x, y)


## Центр кадра внутри мира: иначе у края карты сглаживание «залипает» за границей.
func _clamp(point: Vector2) -> Vector2:
	if _bounds.size == Vector2.ZERO:
		return point
	var half := get_viewport_rect().size / zoom * 0.5
	var lo := _bounds.position + half
	var hi := _bounds.end - half
	return Vector2(clampf(point.x, lo.x, maxf(lo.x, hi.x)), clampf(point.y, lo.y, maxf(lo.y, hi.y)))

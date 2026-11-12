# Сообщения поверх игры: короткие уведомления, итог сдачи, подсказка фазы дня, причина «нельзя поставить», затемнение ночи. Владелец: B.
extends Control

const TOAST_TIME := 1.6
const BANNER_TIME := 3.5
const FADE := 0.3
const TOAST_BOTTOM := 205.0
const HINT_TOP := 70.0
const BANNER_TOP := 120.0
const CURSOR_OFFSET := Vector2(20, 18)
const NIGHT_ALPHA := 0.55

var _build: Node
var _toast: Label
var _banner: Label
var _hint: Label
var _reason: Label
var _night: ColorRect
var _toast_tween: Tween
var _banner_tween: Tween
var _quota_have := -1          # сколько слитков было на складе при прошлом сигнале
@onready var _hint_of_phase := {DayCycle.Phase.DRONE: "HINT_DRONE", DayCycle.Phase.EVENING: "HINT_EVENING",
	DayCycle.Phase.NIGHT: "HINT_NIGHT"}


func setup(build: Node) -> void:
	_build = build
	UiKit.setup_root(self)
	_night = UiKit.dim(0.0)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_night)
	_hint = _line(UiKit.label("", UiKit.FONT_SIZE, UiKit.ACCENT), Control.PRESET_TOP_WIDE, HINT_TOP)
	_banner = _line(UiKit.title("", UiKit.TITLE_SIZE), Control.PRESET_TOP_WIDE, BANNER_TOP)
	_toast = _line(UiKit.label(""), Control.PRESET_BOTTOM_WIDE, -TOAST_BOTTOM)
	_reason = UiKit.label("", UiKit.SMALL_SIZE, UiKit.BAD)
	add_child(_reason)
	_banner.modulate.a = 0.0
	_toast.modulate.a = 0.0
	GameState.notice.connect(_on_notice)
	GameState.day_settled.connect(_on_settled)
	GameState.gift_arrived.connect(_on_gift)
	GameState.quota_changed.connect(_on_quota)
	DayCycle.phase_changed.connect(_on_phase)
	_on_phase(DayCycle.phase)


func _line(label: Label, preset: int, offset_y: float) -> Label:
	label.set_anchors_and_offsets_preset(preset)
	label.offset_top = offset_y
	label.offset_bottom = offset_y + 30.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _process(_delta: float) -> void:
	var ghost: Dictionary = _build.ghost
	_reason.visible = not ghost.is_empty() and not ghost["ok"]
	if _reason.visible:
		_reason.text = tr(ghost["reason"])
		_reason.position = get_local_mouse_position() + CURSOR_OFFSET


func _on_notice(key: String) -> void:
	_toast.text = tr(key)
	_toast_tween = _flash(_toast, _toast_tween, TOAST_TIME)


func _on_settled(result: Dictionary) -> void:
	var key := "BANNER_QUOTA_OK" if result["ok"] else "BANNER_QUOTA_FAIL"
	_banner.text = tr(key) % [result["taken"], result["quota"]]
	_banner.add_theme_color_override("font_color", UiKit.GOOD if result["ok"] else UiKit.BAD)
	_banner_tween = _flash(_banner, _banner_tween, BANNER_TIME)
	Audio.play("quota_ok" if result["ok"] else "quota_fail")


## Посылка дрона посреди дня: чертежи первых машин.
func _on_gift(_gift: Dictionary) -> void:
	_banner.text = tr("NOTICE_EARLY_GIFT")
	_banner.add_theme_color_override("font_color", UiKit.ACCENT)
	_banner_tween = _flash(_banner, _banner_tween, BANNER_TIME)
	Audio.play("quota_ok")


## Склад только что набрал норму дня: радуем игрока сразу, а не вечером.
func _on_quota(have: int, need: int) -> void:
	if _quota_have >= 0 and _quota_have < need and have >= need and DayCycle.phase == DayCycle.Phase.DAY:
		_banner.text = tr("NOTICE_QUOTA_DONE")
		_banner.add_theme_color_override("font_color", UiKit.GOOD)
		_banner_tween = _flash(_banner, _banner_tween, BANNER_TIME)
		Audio.play("quota_ok")
	_quota_have = have


func _flash(label: Label, old: Tween, hold: float) -> Tween:
	if old:
		old.kill()
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, FADE)
	return tween


func _on_phase(phase: int) -> void:
	_hint.text = tr(_hint_of_phase[phase]) if _hint_of_phase.has(phase) else ""
	var night := phase == DayCycle.Phase.NIGHT or phase == DayCycle.Phase.REPORT
	create_tween().tween_property(_night, "color:a", NIGHT_ALPHA if night else 0.0, FADE)

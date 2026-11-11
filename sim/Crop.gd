class_name Crop
extends RefCounted
## Одна грядка: стадия роста и влажность. GDD «Ферма». Владелец: A.

enum Stage { EMPTY, SPROUT, STALK, RIPENING, RIPE }

var cell: Vector2i
var stage: int = Stage.EMPTY
## Сколько секунд грядка ещё влажная. Растёт только влажная грядка.
var wet_left := 0.0
## Сколько секунд грядка уже росла влажной.
var growth := 0.0


func _init(p_cell: Vector2i = Vector2i.ZERO) -> void:
	cell = p_cell


func is_wet() -> bool:
	return wet_left > 0.0


func describe() -> Dictionary:
	return {"cell": cell, "stage": stage, "wet": is_wet()}

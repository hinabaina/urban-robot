class_name Crop
extends RefCounted
## Одна грядка: стадия роста и влажность. GDD «Ферма». Владелец: A.

enum Stage { EMPTY, SPROUT, STALK, RIPENING, RIPE }

var cell: Vector2i
var stage: int = Stage.EMPTY
var wet := false
## Сколько тиков грядка ещё влажная. Растёт только влажная грядка.
var wet_ticks := 0
## Сколько тиков грядка уже росла влажной.
var growth_ticks := 0


func _init(p_cell: Vector2i = Vector2i.ZERO) -> void:
	cell = p_cell


func save() -> Dictionary:
	return {"cell": SimData.from_vec2i(cell), "stage": stage, "wet": wet_ticks, "growth": growth_ticks}


static func load_from(saved: Dictionary) -> Crop:
	var crop := Crop.new(SimData.to_vec2i(saved.get("cell"), Vector2i.ZERO))
	crop.stage = int(saved.get("stage", Stage.EMPTY))
	crop.wet_ticks = int(saved.get("wet", 0))
	crop.wet = crop.wet_ticks > 0
	crop.growth_ticks = int(saved.get("growth", 0))
	return crop

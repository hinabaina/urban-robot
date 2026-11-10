# Рисует посевы над грядками и влажность земли по сигналу Sim.crop_changed. Владелец: B.
extends Node2D

const STAGES := 4            # кадров в crops.png: росток, колос, желтеет, зрелый
const SWAY_SPEED := 0.004
const SWAY_PIXELS := 1.0

var world: Node2D            # WorldLoader, задаёт Main

var _sprites := {}           # клетка грядки -> Sprite2D
@onready var _ripe := int(GameState.player_config["ripe_stage"])


func _ready() -> void:
	z_index = 2
	Sim.crop_changed.connect(_on_crop)


## Перечитать все грядки из симуляции (новая игра или загрузка).
func refresh() -> void:
	for crop in Sim.get_crops():
		_on_crop(crop.get("cell"), crop.get("stage"), crop.get("wet"))


func _on_crop(cell: Vector2i, stage: int, wet: bool) -> void:
	world.set_plot_wet(cell, wet)
	if not _sprites.has(cell):
		var sprite := Sprite2D.new()
		sprite.texture = Sprites.tex("crops")
		sprite.hframes = STAGES
		sprite.position = TileCatalog.cell_center(cell + Vector2i.UP)
		add_child(sprite)
		_sprites[cell] = sprite
	var node: Sprite2D = _sprites[cell]
	node.visible = stage > 0
	node.frame = clampi(stage, 1, STAGES) - 1
	node.set_meta("ripe", stage >= _ripe)


func _process(_delta: float) -> void:
	for cell in _sprites:   # зрелые колосья слегка покачиваются: «пора собирать»
		var sprite: Sprite2D = _sprites[cell]
		var ripe: bool = sprite.get_meta("ripe", false)
		sprite.offset.x = roundf(sin(Time.get_ticks_msec() * SWAY_SPEED + cell.x) * SWAY_PIXELS) if ripe else 0.0

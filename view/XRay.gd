# Рентген узких мест (клавиша X): мир темнеет, машины светятся по загрузке за последние 30 с. Владелец: B.
# Цифры считает симуляция (Sim.get_stats), здесь только картинка.
extends Node2D

const DIM := Color(0.02, 0.03, 0.08, 0.72)
const GOOD := Color("84c95a")
const MEDIUM := Color("f4d34f")
const BAD := Color("f0705a")
const GOOD_FROM := 0.7            # WORKING >= 70% — зелёный
const BAD_BELOW := 0.3            # WORKING < 30% — красный
const SKIP := ["ladder", "conveyor", "storage", "campfire"]   # у них нет цикла производства
const FONT_SIZE := 8
const LABEL_GAP := 3.0

var active := false


func _ready() -> void:
	z_index = 20
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Actions.XRAY) and DayCycle.running:
		active = not active
		visible = active
		Audio.play("select")


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


## Цвет машины по доле времени в работе (правило из GDD).
func color_for(stats: Dictionary) -> Color:
	var working := float(stats.get("working", 0.0))
	if working >= GOOD_FROM:
		return GOOD
	return BAD if working < BAD_BELOW else MEDIUM


func _draw() -> void:
	var world := Rect2(Vector2.ZERO, Vector2(TileCatalog.MAP_SIZE * TileCatalog.TILE))
	draw_rect(world, DIM)
	var font := UiKit.title_font()     # пиксельный 8 px: при зуме 4 это 32 px на экране, ровно по сетке
	for machine in Sim.get_machines():
		var type: String = machine.get("type")
		if SKIP.has(type):
			continue
		var cell: Vector2i = machine.get("cell")
		var stats: Dictionary = Sim.get_stats(cell)
		var color := color_for(stats)
		var rect := Rect2(Vector2(cell) * TileCatalog.TILE, Vector2(MachineCatalog.size(type)) * TileCatalog.TILE)
		draw_texture_rect(Sprites.machine(type), rect, false, Color.WHITE.lerp(color, 0.55))
		draw_rect(rect.grow(1.0), color, false, 1.0)
		var text := "%.1f" % float(stats.get("per_min", 0.0))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, Vector2(rect.get_center().x - width * 0.5, rect.position.y - LABEL_GAP), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
	for item in Sim.get_items():   # предметы, которые стоят в конце клетки, — затор
		if float(item.get("progress")) >= 1.0:
			draw_circle(TileCatalog.cell_center(item.get("cell")), 2.0, BAD)

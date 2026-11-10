# Снимок игры для проверки глазами (в билд не входит):
#   godot --path . res://tools/b_smoke/Shot.tscn -- out.png [секунды] [сценарий]
extends Node

var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "shot.png"
	var wait := float(args[1]) if args.size() > 1 else 1.0
	main = load("res://main/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.3).timeout
	if args.size() > 2:
		await call("scenario_" + args[2])
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()


func hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)


func mouse_to_cell(cell: Vector2i) -> void:
	var world_pos := TileCatalog.cell_center(cell)
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * world_pos
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)


func click(action: StringName, seconds: float = 0.05) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(seconds).timeout
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


## Дойти до шахты, спуститься и покопать руду.
func scenario_mine() -> void:
	await hold(Actions.RIGHT, 0.55)
	await hold(Actions.DOWN, 1.2)
	mouse_to_cell(Vector2i(33, 16))
	await click(Actions.USE, 2.6)
	mouse_to_cell(Vector2i(31, 16))
	await click(Actions.USE, 0.3)


func scenario_ui() -> void:
	var hotbar: Control = main.get_node("UI/Hotbar")
	print("hotbar root ", hotbar.get_global_rect())
	for child in hotbar.get_children():
		print("  ", child.get_class(), " ", child.get_global_rect(), " visible=", child.visible)

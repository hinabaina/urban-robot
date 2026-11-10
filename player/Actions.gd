# Имена действий ввода и клавиши по умолчанию. Владелец: B.
# Если действие уже объявлено в project.godot (каркас A), оно не трогается; иначе добавляется здесь.
class_name Actions

const LEFT := &"move_left"
const RIGHT := &"move_right"
const JUMP := &"jump"
const UP := &"climb_up"
const DOWN := &"climb_down"
const USE := &"use"            # ЛКМ: инструмент
const PLACE := &"place"        # ПКМ: поставить / посадить
const ROTATE := &"rotate"      # Q
const INTERACT := &"interact"  # E
const DEMOLISH := &"demolish"  # F
const XRAY := &"xray"          # X
const SLEEP := &"sleep"        # Z
const PAUSE := &"pause"        # Esc
const SLOT_PREFIX := "slot_"   # slot_1 .. slot_9

# Физические клавиши: раскладка (RU/KZ/EN) не влияет на управление.
const KEYS := {
	LEFT: [KEY_A, KEY_LEFT], RIGHT: [KEY_D, KEY_RIGHT], JUMP: [KEY_SPACE],
	UP: [KEY_W, KEY_UP], DOWN: [KEY_S, KEY_DOWN], ROTATE: [KEY_Q], INTERACT: [KEY_E],
	DEMOLISH: [KEY_F], XRAY: [KEY_X], SLEEP: [KEY_Z], PAUSE: [KEY_ESCAPE],
}
const MOUSE := {USE: MOUSE_BUTTON_LEFT, PLACE: MOUSE_BUTTON_RIGHT}
const SLOT_COUNT := 9


static func slot(index: int) -> StringName:
	return StringName(SLOT_PREFIX + str(index + 1))


static func ensure() -> void:
	for action in KEYS:
		if _add(action):
			for key in KEYS[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)
	for action in MOUSE:
		if _add(action):
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE[action]
			InputMap.action_add_event(action, event)
	for i in SLOT_COUNT:
		if _add(slot(i)):
			var event := InputEventKey.new()
			event.physical_keycode = KEY_1 + i
			InputMap.action_add_event(slot(i), event)


static func _add(action: StringName) -> bool:
	if InputMap.has_action(action):
		return false
	InputMap.add_action(action)
	return true

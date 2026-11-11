# Выбор языка при самом первом запуске: русский, казахский или английский. Владелец: A.
# Позже язык меняется в настройках. Выбор шлёт chosen(code), Main сохраняет его и перезапускает сцену.
class_name LanguagePicker
extends Control

signal chosen(code: String)

const LOCALES := {"ru": "Русский", "kk": "Қазақша", "en": "English"}


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dim(0.85))
	var list := UiKit.window(self, 560)
	var title := UiKit.title("Язык · Тіл · Language", UiKit.TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	for code in LOCALES:
		var button := UiKit.button(LOCALES[code], func() -> void: chosen.emit(code))
		button.custom_minimum_size = Vector2(260, 52)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		list.add_child(button)

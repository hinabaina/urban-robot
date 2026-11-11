# Страница с текстом: «Как играть» и «Авторы». Строки берутся из переводов по списку ключей. Владелец: B.
extends Control

signal closed()

const PAGES := {
	"howto": {"title": "HOWTO_TITLE", "lines": ["HOWTO_GOAL", "HOWTO_MOVE", "HOWTO_TOOLS", "HOWTO_BUILD", "HOWTO_HANDS",
		"HOWTO_DAY", "HOWTO_AUTOMATION"]},
	"credits": {"title": "CREDITS_TITLE", "lines": ["CREDITS_TEAM", "CREDITS_ENGINE", "CREDITS_ART", "CREDITS_SOUND",
		"CREDITS_FONTS", "CREDITS_AI", "CREDITS_EVENT"]},
}
const WIDTH := 860


func _ready() -> void:
	UiKit.setup_root(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(page: String) -> void:
	for child in get_children():
		child.queue_free()
	add_child(UiKit.dim())
	var list := UiKit.window(self, WIDTH)
	var title := UiKit.title(tr(PAGES[page]["title"]), UiKit.TITLE_SIZE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	for key in PAGES[page]["lines"]:
		var line := UiKit.label(_text(key), UiKit.SMALL_SIZE + 2)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(line)
	var back := UiKit.button(tr("BTN_BACK"), close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 180
	list.add_child(back)
	visible = true


## Числа в «Как играть» берутся из days.json, чтобы текст не расходился с балансом.
func _text(key: String) -> String:
	match key:
		"HOWTO_GOAL":
			return tr(key) % [GameConfig.total_days(), GameConfig.total_quota()]
		"HOWTO_AUTOMATION":
			return tr(key) % int(GameConfig.day(GameConfig.total_days())["quota"])
	return tr(key)


func close() -> void:
	visible = false
	closed.emit()

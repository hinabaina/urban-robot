# Загрузка переводов из data/translations.csv (колонки: keys, ru, kk). Владелец: B.
# Читаем файл сами, чтобы не зависеть от настроек проекта; пустой перевод заменяется русским.
class_name Loc

const PATH := "res://data/translations.csv"
const DEFAULT_LOCALE := "ru"


static var _loaded := false


static func setup(locale: String = DEFAULT_LOCALE) -> void:
	TranslationServer.set_locale(locale)
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	assert(file != null, "нет файла переводов")
	var header := file.get_csv_line()
	var translations: Array[Translation] = []
	for i in range(1, header.size()):
		var translation := Translation.new()
		translation.locale = header[i]
		translations.append(translation)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		for i in translations.size():
			var text := row[i + 1] if i + 1 < row.size() and row[i + 1] != "" else row[1]
			translations[i].add_message(row[0], text)
	for translation in translations:
		TranslationServer.add_translation(translation)

# build/ — владелец A

Готовые сборки в репозитории не хранятся (файлы по 40–110 МБ). Их собирает GitHub Actions (`.github/workflows/build.yml`) при каждом изменении `main` и выкладывает на GitHub Pages:

- Web: https://hinabaina.github.io/urban-robot/
- Windows x64 (zip, один exe): https://hinabaina.github.io/urban-robot/dala-works-win64.zip

## Собрать у себя

Нужны Godot 4.7.2-stable и его шаблоны экспорта (в редакторе: «Редактор → Управление шаблонами экспорта»).

```bash
build/build.sh web        # build/web/index.html
build/build.sh windows    # build/dala-works-win64.zip
build/build.sh            # обе сборки
```

Web-сборку нельзя открыть двойным щелчком по `index.html`: браузеру нужен сервер. Локально:

```bash
python3 -m http.server 8000 --directory build/web    # затем открыть http://localhost:8000
```

## Настройки экспорта (`export_presets.cfg`)

- Web собран без потоков (`thread_support=false`), поэтому работает на GitHub Pages и любом простом хостинге без особых заголовков.
- В сборку не попадают `tests/`, `tools/`, `docs/`. Файлы `data/*.json` и `data/*.csv` добавлены явно: игра читает их как обычные файлы.
- Windows: один exe со встроенными данными, установка не нужна.

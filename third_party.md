# Сторонние компоненты и лицензии

Всё, что команда не сделала сама, перечислено здесь. Копия списка показывается в игре на экране «Авторы».

## Движок

| Компонент | Версия | Автор | Лицензия |
|---|---|---|---|
| Godot Engine | 4.4.1-stable | Juan Linietsky, Ariel Manzur и участники проекта Godot | MIT |

## Шрифты

| Шрифт | Файл | Автор | Лицензия |
|---|---|---|---|
| Tektur | `assets/fonts/Tektur.ttf` | The Tektur Project Authors (Adam Jagosz) | SIL Open Font License 1.1 (`assets/fonts/OFL-Tektur.txt`) |
| Press Start 2P | `assets/fonts/PressStart2P-Regular.ttf` | The Press Start 2P Project Authors (CodeMan38) | SIL Open Font License 1.1 (`assets/fonts/OFL-PressStart2P.txt`) |

Оба шрифта взяты из каталога Google Fonts; покрытие русских и казахских букв проверено.

## Графика

Весь пиксель-арт в `assets/sprites/` оригинальный: нарисован кодом команды в `tools/art/` (запуск `python3 tools/art/gen_all.py`). Чужих спрайтов, тайлсетов и изображений в проекте нет.

## Звук и музыка

Все звуки и мелодия в `assets/audio/` оригинальные: синтезированы кодом команды в `tools/audio/gen_audio.py`. Чужих записей и семплов в проекте нет.

## Инструменты разработки (в билд не входят)

| Инструмент | Для чего | Лицензия |
|---|---|---|
| Python 3, Pillow | генерация спрайтов | PSF, MIT-CMU (HPND) |
| numpy | синтез звука | BSD-3-Clause |
| ffmpeg (libvorbis) | кодирование музыки в OGG | LGPL/GPL, BSD (libvorbis) |

## ИИ-инструменты

| Инструмент | Для чего | Ответственность |
|---|---|---|
| Claude (Anthropic) | помощь с кодом, генераторами графики и звука, текстами | команда проверяет результат и может объяснить любую часть кода |

## Идеи и источники вдохновения

Использованы только идеи жанра, без кода и ассетов этих игр: вид сбоку и копание вглубь (Terraria), ритм дня, грядки и сон (Stardew Valley), конвейеры, узкие места и ракета (Factorio).

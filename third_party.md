# Сторонние компоненты и лицензии

Всё, что команда не сделала сама, перечислено здесь. Копия списка показывается в игре на экране «Авторы».

## Движок

| Компонент | Версия | Автор | Лицензия |
|---|---|---|---|
| Godot Engine | 4.7.2-stable | Juan Linietsky, Ariel Manzur и участники проекта Godot | MIT |

## Шрифты

| Шрифт | Файл | Автор | Лицензия |
|---|---|---|---|
| DALA Pixel (основной шрифт интерфейса) | `assets/fonts/DalaPixel.ttf` | на основе Fusion Pixel 12px (© 2022 TakWolf); команда дорисовала 18 казахских букв скриптом `tools/font/build_font.py` и переименовала шрифт, как требует OFL | SIL Open Font License 1.1 (`assets/fonts/OFL-FusionPixel.txt`) |
| Tektur (запасной для редких символов) | `assets/fonts/Tektur.ttf` | The Tektur Project Authors (Adam Jagosz) | SIL Open Font License 1.1 (`assets/fonts/OFL-Tektur.txt`) |
| Press Start 2P | `assets/fonts/PressStart2P-Regular.ttf` | The Press Start 2P Project Authors (CodeMan38) | SIL Open Font License 1.1 (`assets/fonts/OFL-PressStart2P.txt`) |

Оба шрифта взяты из каталога Google Fonts; покрытие русских и казахских букв проверено.

## Графика

Весь пиксель-арт в `assets/sprites/` оригинальный: нарисован кодом команды в `tools/art/` (запуск `python3 tools/art/gen_all.py`). Чужих спрайтов, тайлсетов и изображений в проекте нет.

## Звук и музыка

Все звуки и мелодия в `assets/audio/` оригинальные: синтезированы кодом команды в `tools/audio/gen_audio.py` и `tools/audio/gen_intro_audio.py` (ветер, гул и гром вступления). Чужих записей и семплов в проекте нет.

Исключение: голос рассказчика во вступительном ролике (`assets/audio/intro_vo_ru_*.ogg` и `intro_vo_en_*.ogg`) сгенерирован ИИ, см. раздел ниже. Текст реплик написан командой.

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
| ElevenLabs (модель eleven_v4; голоса из библиотеки ElevenLabs: Egor Gadzhiyev для русского, Declan Sage для английского) | озвучка вступительного ролика по тексту команды | команда выбрала голос и дубль, разрезала запись на реплики; источник указан по правилам ElevenLabs: https://elevenlabs.io |

## Идеи и источники вдохновения

Использованы только идеи жанра, без кода и ассетов этих игр: вид сбоку и копание вглубь (Terraria), ритм дня, грядки и сон (Stardew Valley), конвейеры, узкие места и ракета (Factorio).

# Просьбы друг к другу

Дописываем в конец. Формат: дата, от кого, что нужно и зачем. Владелец модуля отвечает строкой «→ сделано / не буду, потому что…».

## 10 ноября, от B (Игра) → A (Движок)

Каркаса в `main` на момент работы не было, поэтому B собрал временный харнесс (`project.godot`, `dev_stub/SimStub.gd`, `dev_stub/machines.json`) строго по §5.2 плана. Когда придёт каркас A, харнесс удаляется, файлы A главные. Ниже — всё, что B предположил; где у A иначе, скажи, поправлю у себя (все такие места собраны в одном файле каждое).

1. **project.godot.** Нужны: окно 1280×720, `stretch/mode=canvas_items`, `aspect=keep`, фильтр текстур по умолчанию Nearest, рендерер `gl_compatibility` (Web), главная сцена `res://main/Main.tscn`, автозагрузки в порядке `Sim`, `GameState`, `DayCycle`, `SaveManager`, `Audio` (GameState в `_ready` подписывается на `Sim.item_delivered`).
2. **Действия ввода.** B использует имена: `move_left`, `move_right`, `jump`, `climb_up`, `climb_down`, `use` (ЛКМ), `place` (ПКМ), `rotate` (Q), `interact` (E), `demolish` (F), `xray` (X), `sleep` (Z), `pause` (Esc), `slot_1`…`slot_9`. Если в каркасе их нет, `player/Actions.gd` добавляет их сам при запуске (по физическим клавишам, чтобы не зависеть от раскладки). Если у тебя другие имена — поменяю константы в `Actions.gd`.
3. **Перечисления.** B обращается к `Sim.Tile.{AIR, SOIL, STONE, DEEP, BEDROCK, ORE, FARMLAND}` (только `world/WorldLoader.gd`) и `Sim.State.{IDLE, WORKING, BLOCKED, NO_FUEL, NO_WATER, EXHAUSTED}` (`view/MachineView.gd`, `autoload/Audio.gd`). Назови, как они называются у тебя.
4. **load_world.** B отдаёт: руда — вид ORE (жилы прошу собрать по соседству клеток, запас по слою из `world.json`); 12 грядок — вид FARMLAND (y = 12, x = 9…20); плиты под колодцем, юртой, костром, складом и площадкой — как BEDROCK, чтобы постройки нельзя было подкопать. Повторный `load_world` должен полностью сбрасывать симуляцию («Начать сначала»).
5. **Колодец.** Его клетки (5,11) и (6,11) есть в `World.tscn` (метка `Markers/Well`). Как сообщить их симуляции для зоны полива: метод `Sim.set_well(cell)` или координата в `world.json`?
6. **Готовые постройки.** После `load_world` B зовёт `place_machine("ladder", cell, DOWN)` для ствола шахты (x = 32, y = 12…17), `place_machine("storage", (50,10), RIGHT)` и `place_machine("campfire", (29,11), RIGHT)`. Для машин 2×2 `cell` — левая верхняя клетка.
7. **machines.json.** B читает только `cost` (словарь тип → количество) и `size` ([ширина, высота]). Дни открытия чертежей B берёт из своих `days.json` (подарки дрона).
8. **Формат данных чтения.** B читает поля через `.get()`, поэтому подойдут и словари, и объекты: машины — `cell`, `type`, `dir`, `state`; предметы — `cell`, `dir`, `progress`, `type`, `by_hand`; посевы — `cell`, `stage` (0 пусто … 4 зрелая), `wet`.
9. **can_place.reason.** B переводит строку через `translations.csv`. Сейчас есть ключи `REASON_NOT_EMPTY`, `REASON_OCCUPIED`, `REASON_NEED_VEIN`. Пришли список своих причин — добавлю тексты.
10. **dig / dig_time.** `dig_time == 0` B понимает как «не копается» (воздух, коренная порода, грядка). Для руды ждёт `{removed: false, ore: true}`.
11. **get_stats / night_summary.** Рентген берёт `working` (доля 0..1 за 30 с) и `per_min`; отчёт берёт `made: {ingot, ore, grain}`. Главное узкое место покажу, когда договоримся о полях (предлагаю `bottleneck: {cell, type, state, share}`).
12. **Сглаживание предметов.** Сейчас B сам считает долю тика (`DayCycle.tick_alpha()`), полагаясь на шаг 0,25 с. Надёжнее будет `Sim.tick_alpha() -> float`: добавь, если нетрудно.
13. **SaveManager.** Чтобы подключить «Продолжить» и «Повторить день», мне нужны: `has_save() -> bool`, `save_morning()`, `load_morning() -> bool`. Настройки и рекорд B пока хранит сам в `user://settings.cfg` (`ui/Settings.gd`); если заберёшь в `settings.json` — перенесу.

## 11 ноября, от A (Движок) → B (Игра)

Каркас A влит поверх main. Ответы по пунктам выше:

1. → сделано: `project.godot` версии A, автозагрузки в порядке `Sim`, `GameState`, `DayCycle`, `SaveManager`, `Audio`, добавлен `aspect=keep`. `Sim` теперь `res://sim/Simulation.gd`, не заглушка.
2. → сделано: действие ЛКМ в каркасе переименовано из `use_tool` в `use`, остальные имена совпадали. Добавлять действия в `Actions.gd` больше не нужно (но и не мешает).
3–13. → в работе: подгоняю `sim/` под эти пункты, затем удаляю `dev_stub/`. Пока это не сделано, игра на настоящем `Sim` может не запускаться. Отвечу здесь по каждому пункту.

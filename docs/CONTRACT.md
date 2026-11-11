# CONTRACT: граница между «Движком» (A) и «Игрой» (B)

Версия 2, 11 ноября. Описывает то, что реально лежит в `sim/` и вызывается игрой. Каждый метод и сигнал отсюда проверяется тестом `tests/SimTest.tscn`.

- **A, «Движок»**: `sim/`, `autoload/SaveManager.gd`, `tests/`, `build/`, `data/machines.json`, `data/world.json`, `project.godot`.
- **B, «Игра»**: `player/`, `view/`, `ui/`, `world/`, `main/`, `assets/`, `tools/`, `autoload/GameState.gd`, `GameConfig.gd`, `DayCycle.gd`, `Audio.gd`, `data/days.json`, `player.json`, `tutorial.json`, `translations.csv`.
- **Общие**: `docs/`, `README.md`, `third_party.md`.

В чужой файл не пишем. Нужна правка у напарника: запись в `docs/REQUESTS.md`.

## 1. Принципы

1. `Sim` (автозагрузка, `sim/Simulation.gd`) не знает о нодах сцены, спрайтах и кнопках. Наружу только сигналы и методы чтения.
2. Игрок и часы отдают `Sim` **команды**. Вид, UI и звук **читают** состояние и слушают сигналы.
3. Числа баланса только в `data/*.json`.
4. Симуляцию двигает одно место в игре: `DayCycle._process` вызывает `Sim.advance(delta * speed)`.
5. `Sim` не списывает ресурсы игрока и не проверяет карманы, радиус 4 тайла и открытые чертежи. Это делает B.

## 2. Общие типы

| Что | Тип | Значения |
|---|---|---|
| Клетка | `Vector2i` | в тайлах, тайл 16 px, (0,0) слева сверху, y растёт вниз |
| Направление | `Vector2i` | `RIGHT`, `LEFT`, `UP`, `DOWN` |
| Тип предмета | `String` | `"ore"`, `"grain"`, `"ingot"` |
| Тип машины | `String` | `"ladder"`, `"conveyor"`, `"drill"`, `"furnace"`, `"sprinkler"`, `"harvester"`, `"storage"`, `"campfire"` |
| Вид тайла | `Sim.Tile` | `AIR`, `SOIL`, `STONE`, `DEEP`, `BEDROCK`, `ORE`, `FARMLAND` |
| Состояние машины | `Sim.State` | `IDLE`, `WORKING`, `BLOCKED`, `NO_FUEL`, `NO_WATER`, `EXHAUSTED` |
| Стадия грядки | `int` | 0 пусто, 1 росток, 2 колос, 3 желтеет, 4 зрелая |

Машина 2×2 задаётся левой верхней клеткой. Любой метод, принимающий клетку машины, понимает любую из её клеток. Выход машины 2×2 это клетка рядом с ней по направлению выхода, в строке (для `LEFT`/`RIGHT`) или столбце (для `UP`/`DOWN`) левой верхней клетки.

## 3. Sim: команды

```gdscript
Sim.load_world(tiles: Dictionary) -> void       # Vector2i -> Sim.Tile; полный сброс симуляции
Sim.advance(dt: float) -> void                  # dt уже умножен на скорость игры
Sim.tick_alpha() -> float                       # доля текущего тика 0..1, для сглаживания

Sim.can_place(type, cell, dir) -> Dictionary    # {"ok": bool, "reason": String}
Sim.place_machine(type, cell, dir) -> bool      # цену не списывает
Sim.remove_machine(cell) -> Array               # предметы, лежавшие внутри; цену возвращает B

Sim.dig_time(cell) -> float                     # секунды; 0 = копать нельзя
Sim.dig(cell) -> Dictionary                     # {"removed": bool, "ore": bool}
Sim.insert(cell, item_type) -> bool             # E: 1 предмет из карманов в машину
Sim.take(cell) -> Array                         # E: забрать предметы из машины
Sim.campfire_work(dt) -> bool                   # true в тот вызов, когда слиток готов

Sim.plant(cell) -> bool
Sim.water(cell) -> bool
Sim.harvest(cell) -> int                        # сколько зерна; 0, если не зрелая

Sim.storage_take_for_drone(amount) -> Array     # до amount слитков, старые первыми
```

Пояснения:

- **`load_world`**. Жилы отдельно не описываются: соседние тайлы `ORE` объединяются в жилу, её запас берётся по слою из `data/world.json` (почва 40, камень 120, глубокая порода бесконечно). Тайлы `FARMLAND` становятся грядками. Клетки колодца лежат в `data/world.json` (`well.cells`). Готовые постройки (лестницы шахты, склад, костёр) B ставит сам через `place_machine` сразу после `load_world`.
- **`can_place.reason`** это ключ перевода: `REASON_NOT_EMPTY` (клетка не воздух или за краем мира), `REASON_OCCUPIED`, `REASON_NEED_VEIN` (бур не касается жилы стороной), `REASON_UNKNOWN` (нет такого типа или направление не из четырёх).
- **`remove_machine`, `take`, `storage_take_for_drone`** возвращают массив предметов. У каждого читаются `type` и `by_hand` (можно через `.get()`). Всё, что игрок взял руками, приходит с `by_hand = true`. `take` со склада отдаёт руду и зерно, слитки не отдаёт. `take` из печи, бура, сборщика отдаёт их выход, из костра возвращает сырьё, с конвейера снимает предмет.
- **`insert`** принимают: склад (всё), печь (руда до 10, зерно до 5), костёр (ровно один набор: 2 руды и 1 зерно). Вставленный предмет помечается `by_hand`.
- **`dig`**. Обычный тайл исчезает (`removed`). Тайл руды остаётся, а общий запас жилы уменьшается на 1 (`ore`). Когда запас кончился, все тайлы жилы становятся камнем: приходит `tile_changed` на каждую клетку и `vein_exhausted`.
- **`plant`** сажает в пустую грядку. Если грядки в клетке нет, создаёт новую: клетка должна быть почвой с воздухом сверху, в зоне колодца, всего не больше 24 грядок. Тогда тайл становится `FARMLAND` и приходит `tile_changed`. 1 зерно списывает B.
- **`water`** делает грядку влажной на 15 с. Грядка растёт только влажной: 30 влажных секунд до зрелости.

## 4. Sim: чтение

```gdscript
Sim.get_tile(cell) -> int                # за границей мира BEDROCK
Sim.get_machines() -> Array              # у каждой: cell, type, dir, state
Sim.get_items() -> Array                 # предметы на конвейерах: cell, dir, progress, type, by_hand
Sim.get_crops() -> Array                 # у каждой: cell, stage, wet
Sim.is_in_water_zone(cell) -> bool       # не дальше 10 тайлов от колодца
Sim.storage_count(item_type) -> int
Sim.get_stats(cell) -> Dictionary        # рентген
Sim.night_summary() -> Dictionary        # ночной отчёт
Sim.reset_period_stats() -> void
Sim.to_dict() -> Dictionary
Sim.from_dict(saved: Dictionary) -> bool
Sim.tick_count: int
```

- Элементы массивов это объекты симуляции, а не словари. Поля читаются как свойства или через `.get("cell")`. Менять их снаружи нельзя.
- **`get_items`**. `progress` 0..1 это путь по клетке вдоль `dir`: 0 на входном крае, 1 на выходном. Предмет с `progress == 1` доехал до края и стоит: значит, впереди затор.
- **`get_stats`**: `{"working", "blocked", "no_fuel", "idle"}` (доли 0..1 за последние 30 с) и `"per_min"` (выпуск в минуту). `{}`, если машины в клетке нет.
- **`night_summary`**: `{"made": {"ore", "grain", "ingot"}, "bottleneck": {"cell", "type", "state", "share"}}`. `made` считает произведённое бурами, сборщиками и печами с начала периода. `bottleneck` это бур, печь, сборщик или поливалка с наибольшей долей простоя (`BLOCKED`, `NO_FUEL`, `NO_WATER`, `EXHAUSTED`); пустой словарь, если простоев не было. Период начинается заново при `DayCycle.night_started` (подписку делает `SaveManager`), то есть отчёт показывает то, что фабрика сделала за ночь.

## 5. Sim: сигналы

```gdscript
signal ticked(tick: int)
signal tile_changed(cell: Vector2i, kind: int)
signal machine_placed(cell: Vector2i, type: String, dir: Vector2i)
signal machine_removed(cell: Vector2i)
signal machine_state_changed(cell: Vector2i, state: int)
signal item_delivered(type: String, by_hand: bool)      # предмет попал на склад
signal crop_changed(cell: Vector2i, stage: int, wet: bool)
signal vein_exhausted(vein_id: int)
```

## 6. Сохранение (SaveManager, владелец A)

```gdscript
SaveManager.has_save() -> bool
SaveManager.save_morning() -> bool       # звать утром, после ночного отчёта
SaveManager.load_morning() -> bool       # «Продолжить» и «Повторить день»
SaveManager.delete_save() -> void        # «Начать сначала»
```

- Файл `user://save.json`: `Sim.to_dict()` и `GameState.to_dict()`. Запись идёт во временный файл, потом он заменяет старый.
- **Порядок загрузки**: сначала `world.start_new()` (карта и готовые постройки), потом `SaveManager.load_morning()`.
- При загрузке `Sim` рассылает обычные сигналы: `machine_removed` на все старые машины, `tile_changed` на каждую изменившуюся клетку, `crop_changed` на все грядки, `machine_placed` и `machine_state_changed` на все загруженные машины. Вид, который слушает эти сигналы, обновится сам.
- `load_morning()` возвращает `false`, если файла нет, он повреждён или записан другой версией игры. Тогда мир не меняется и нужно предложить начать заново.

## 7. Как работает тик

Один тик = 0,25 с игрового времени. `advance(dt)` копит время и выполняет целое число тиков, поэтому результат не зависит от FPS, а ночь на ×20 даёт тот же мир, что и ×1 (проверено тестом).

1. **Машины и движение.** Каждая машина обновляет свой таймер и состояние: бур добывает, печь плавит, поливалка поливает, сборщик собирает. Предметы на конвейерах проезжают четверть клетки.
2. **Рост.** Влажные грядки растут и сохнут.
3. **Переходы с обратным давлением.** Предметы, доехавшие до края клетки, и предметы в выходных буферах пробуют перейти в следующую машину. Проходы повторяются, пока хоть что-то сдвинулось, поэтому плотная цепочка едет вся сразу. Каждый предмет переходит не больше одного раза за тик. Если в одну клетку хотят двое, она берёт их по очереди.
4. **Статистика.** Каждая машина записывает своё состояние в кольцевой буфер на 30 с.

Файлы: `sim/Simulation.gd` (фасад), `Transfers.gd` (шаг 3), `machines/*.gd` (шаг 1), `Farm.gd` (шаг 2), `MachineStats.gd` и `SimReport.gd` (шаг 4), `Veins.gd` (жилы), `SimSave.gd` (сохранение).

## 8. Ввод и настройки проекта

Действия: `move_left`, `move_right`, `jump`, `climb_up`, `climb_down`, `use` (ЛКМ), `place` (ПКМ), `rotate` (Q), `interact` (E), `demolish` (F), `xray` (X), `sleep` (Z), `pause` (Esc), `slot_1` … `slot_9`. Клавиши заданы физическими кодами и работают при русской раскладке.

Автозагрузки по порядку: `Sim`, `GameState`, `DayCycle`, `SaveManager`, `Audio`. Окно 1280×720, растяжение `canvas_items`, пиксельная фильтрация, рендерер Compatibility (нужен для Web). Версия движка: **Godot 4.7.2**.

## 9. Как менять контракт

1. Добавлять методы и сигналы можно без согласования. Владелец правит этот файл в том же коммите.
2. Менять или удалять существующее только по согласию, через `docs/REQUESTS.md`.
3. Любое изменение `Sim` сопровождается проверкой в `tests/`.

## 10. Проверка перед каждым PR

```
godot --headless --path . res://tests/SimTest.tscn      # движок: «Итог: N ок, 0 провалено», код возврата 0
tools/b_smoke/shot.sh /tmp/out.png 0.2 checks           # игра целиком: «RESULT: ALL PASS» (Linux, xvfb)
```

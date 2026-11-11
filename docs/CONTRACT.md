# CONTRACT: граница между «Движком» (A) и «Игрой» (B)

Этот файл главный по интерфейсам. Пока он не меняется, A и B работают параллельно и не читают код друг друга. Каждая строка здесь проверяется тестом `tests/SimTest.tscn` (блок «Контракт»).

- **A, «Движок»**: `sim/`, `autoload/SaveManager.gd`, `tests/`, `build/`, `data/machines.json`, `data/world.json`, `project.godot`.
- **B, «Игра»**: `player/`, `view/`, `ui/`, `world/`, `main/`, `assets/`, `autoload/GameState.gd`, `autoload/DayCycle.gd`, `autoload/Audio.gd`, `data/days.json`, `data/tutorial.json`, `data/translations.csv`.
- **Общие**: `docs/`, `README.md`, `third_party.md`.

В чужой файл не пишем. Нужна правка у напарника: запись в `docs/REQUESTS.md`.

## 1. Принципы

1. `Sim` (автозагрузка, `sim/Simulation.gd`) не знает о нодах сцены, спрайтах и кнопках. Наружу только сигналы и методы чтения.
2. Игрок и часы отдают `Sim` **команды**. Вид, UI и звук **читают** состояние и слушают сигналы.
3. Числа баланса только в `data/*.json`. В коде чисел нет.
4. Симуляцию двигает одно место в игре: `DayCycle._process` вызывает `Sim.advance(delta * speed)`.
5. `Sim` не списывает ресурсы игрока и не проверяет карманы, радиус 4 тайла и открытые чертежи. Это делает B через `GameState`.

## 2. Общие типы

| Что | Тип | Значения |
|---|---|---|
| Клетка | `Vector2i` | в тайлах, тайл 16 px, (0,0) слева сверху, y растёт вниз |
| Направление | `Vector2i` | `RIGHT`, `LEFT`, `UP`, `DOWN` |
| Тип предмета | `String` | `Item.ORE` = `"ore"`, `Item.GRAIN` = `"grain"`, `Item.INGOT` = `"ingot"` |
| Тип машины | `String` | `"ladder"`, `"conveyor"`, `"drill"`, `"furnace"`, `"sprinkler"`, `"harvester"`, `"storage"`, `"campfire"` |
| Вид тайла | `Tiles.Kind` | `AIR`, `SOIL`, `STONE`, `DEEP`, `BEDROCK`, `ORE` |
| Состояние машины | `Machine.State` | `IDLE`, `WORKING`, `BLOCKED`, `NO_FUEL`, `NO_WATER`, `EXHAUSTED` |
| Стадия грядки | `Crop.Stage` | `EMPTY`, `SPROUT`, `STALK`, `RIPENING`, `RIPE` |

Машина 2×2 задаётся левой верхней клеткой. Любой метод, принимающий клетку машины, понимает любую из её клеток.

Числа из JSON приходят как `float` (так работает JSON в Godot). Перед сравнением с целым оборачивайте в `int()`.

## 3. Sim: команды (вызывает B)

```gdscript
# Жизненный цикл
Sim.reset() -> void
Sim.load_world(world: Dictionary) -> void
Sim.advance(dt: float) -> void          # dt уже умножен на скорость игры
Sim.tick() -> void                      # один тик вручную, нужен только тестам

# Машины
Sim.can_place(type: String, cell: Vector2i, dir: Vector2i) -> Dictionary
Sim.place_machine(type: String, cell: Vector2i, dir: Vector2i) -> bool
Sim.remove_machine(cell: Vector2i) -> Dictionary

# Ручные действия
Sim.dig_time(cell: Vector2i) -> float
Sim.dig(cell: Vector2i) -> Dictionary
Sim.insert(cell: Vector2i, item_type: String) -> bool
Sim.take(cell: Vector2i, room: Dictionary) -> Dictionary
Sim.campfire_work(cell: Vector2i, dt: float) -> bool

# Ферма
Sim.can_plant(cell: Vector2i) -> Dictionary
Sim.plant(cell: Vector2i) -> bool
Sim.water(cell: Vector2i) -> bool
Sim.harvest(cell: Vector2i) -> int

# Дрон
Sim.storage_take_for_drone(amount: int) -> Dictionary
```

### load_world

Вызывается один раз при старте новой игры из `world/WorldLoader.gd`:

```gdscript
Sim.load_world({
    "size": Vector2i(64, 40),
    "tiles": {Vector2i(0, 12): Tiles.Kind.SOIL, ...},   # клетки без записи = воздух
    "well": Vector2i(6, 11),                            # клетка колодца, центр зоны воды
    "plots": [Vector2i(9, 12), ...],                    # 12 стартовых грядок (клетка почвы)
    "prebuilt": [                                       # то, что стоит на карте заранее
        {"type": "storage", "cell": Vector2i(50, 10), "dir": Vector2i.RIGHT},
        {"type": "campfire", "cell": Vector2i(27, 11), "dir": Vector2i.RIGHT},
        {"type": "ladder", "cell": Vector2i(32, 12), "dir": Vector2i.RIGHT},
    ],
})
```

Жилы отдельно описывать не нужно: B рисует тайлы `ORE`, а `Sim` сам объединяет соседние тайлы руды в жилу и берёт её запас по слою из `data/world.json` (этап A4).

### Что возвращают команды

| Метод | Результат |
|---|---|
| `can_place` | `{"ok": bool, "reason": String}`. Причины: `unknown_type`, `not_buildable`, `bad_direction`, `out_of_bounds`, `tile_solid`, `occupied`, позже `needs_vein` (бур не касается жилы). Причина это ключ для перевода, не текст. |
| `place_machine` | `true`, если поставлена. Цену **не** списывает. |
| `remove_machine` | `{"ok", "reason", "type", "refund": {"ore": 1}, "items": {"ore": 2}}`. `refund` это 100% цены, `items` это то, что лежало внутри. Причины отказа: `no_machine`, `not_removable` (склад, костёр). |
| `dig_time` | секунды, сколько держать ЛКМ; `-1`, если копать нельзя. |
| `dig` | `{"removed": bool, "ore": bool}`. `removed`: тайл исчез. `ore`: игрок получил 1 руду. Вызывать после того, как игрок продержал ЛКМ `dig_time` секунд. |
| `insert` | `true`, если машина приняла 1 предмет. Предмет помечается `by_hand`. Списать из карманов должен B. |
| `take` | `{"ore": 3, "grain": 1}`: что отдано игроку. `room` это сколько ещё влезет в карманы (`GameState.room()`). Слитки со склада не выдаются. |
| `campfire_work` | `true` в тот вызов, когда слиток готов. B кладёт 1 слиток в карманы. Вызывать каждый кадр, пока игрок держит ЛКМ на костре. |
| `can_plant` | `{"ok", "reason"}`. Причины: `already_planted`, `not_soil`, `blocked_above`, `no_water`, `too_many_plots`. |
| `plant` | `true`, если посажено (в пустую грядку или на новой). 1 зерно списывает B. |
| `water` | `true`, если в клетке есть грядка и она полита. |
| `harvest` | сколько зерна получено; `0`, если грядка не зрелая. |
| `storage_take_for_drone` | `{"taken": int, "by_hand": int}`: сколько слитков забрано и сколько из них тронуты руками. По этим числам B считает уровень автоматизации. |

## 4. Sim: чтение

```gdscript
Sim.get_tile(cell) -> int                    # Tiles.Kind; за границей мира BEDROCK
Sim.get_machine(cell) -> Dictionary          # {} если машины нет
Sim.get_machines() -> Array[Dictionary]
Sim.get_items() -> Array[Dictionary]         # предметы на конвейерах, читать каждый кадр
Sim.get_crops() -> Array[Dictionary]
Sim.is_in_water_zone(cell) -> bool
Sim.storage_count(item_type) -> int
Sim.machine_types() -> Array                 # ключи data/machines.json
Sim.machine_config(type) -> Dictionary       # size, cost, unlock_day, hotbar_slot, ...
Sim.get_stats(cell) -> Dictionary            # для рентгена
Sim.reset_period_stats() -> void             # DayCycle зовёт перед ночью
Sim.period_summary() -> Dictionary           # для ночного отчёта
Sim.to_dict() -> Dictionary
Sim.from_dict(save: Dictionary) -> bool
Sim.tick_count: int
```

| Метод | Формат |
|---|---|
| `get_machine` | `{"type", "cell", "dir", "size", "state", "contents": {"ore": 2}}` |
| `get_items` | `[{"type", "cell", "dir", "progress", "by_hand", "stuck"}]`. Спрайт ставится между центром клетки `cell` и центром `cell + dir` по `progress` 0..1. `stuck`: предмет стоит дольше 3 с (красная точка в рентгене). |
| `get_crops` | `[{"cell", "stage", "wet"}]` |
| `get_stats` | `{"working", "blocked", "no_fuel", "idle"}` (доли 0..1 за последние 30 с) и `"per_minute"` |
| `period_summary` | `{"produced": {"ore", "grain", "ingot"}, "bottleneck": {"cell", "type", "state", "share"}}`; `bottleneck` пустой, если простоев не было |

## 5. Sim: сигналы

```gdscript
signal world_loaded
signal ticked(tick: int)
signal tile_changed(cell: Vector2i, kind: int)
signal machine_placed(cell: Vector2i, type: String, dir: Vector2i)
signal machine_removed(cell: Vector2i, type: String)
signal machine_state_changed(cell: Vector2i, state: int)
signal item_delivered(type: String, by_hand: bool)     # предмет попал на склад
signal storage_changed(type: String, count: int)
signal crop_changed(cell: Vector2i, stage: int, wet: bool)
signal vein_exhausted(vein_id: int)
```

После `world_loaded` вид один раз читает `get_machines()`, `get_crops()` и тайлы, дальше живёт на сигналах.

## 6. GameState и DayCycle (владелец B): что обещано A

```gdscript
# GameState
var day: int
var trust: int
var pockets: Dictionary                 # {"ore", "grain", "ingot"}
func new_game() -> void
func is_unlocked(machine_type: String) -> bool
func can_afford(cost: Dictionary) -> bool
func pay(cost: Dictionary) -> bool
func room() -> Dictionary               # сколько ещё влезет в карманы
func to_dict() -> Dictionary
func from_dict(save: Dictionary) -> void
signal quota_changed(have: int, need: int)
signal trust_changed(value: int)
signal pockets_changed(pockets: Dictionary)

# DayCycle
var hour: float
var speed: float                        # 1, 2 или 20
var running: bool
signal day_started(day: int)
signal evening
signal night_started
signal day_ended(day: int)

# SaveManager (владелец A)
func has_save() -> bool
func save_game() -> bool                # B зовёт утром после ночного отчёта
func load_game() -> bool                # «Продолжить» и «Повторить день»
```

`SaveManager` сохраняет `Sim.to_dict()` и `GameState.to_dict()`. Всё, что B хочет сохранить (излишек, статистика, части ракеты), он кладёт в `GameState.to_dict()`.

## 7. Что уже работает в каркасе и что пока заглушка

B может строить игру поверх этого с первого дня.

| Работает по-настоящему | Заглушка до этапа |
|---|---|
| `load_world`, тайлы, `advance` и счёт тиков | фазы тика, движение предметов: A2, A3 |
| `can_place`, `place_machine`, `remove_machine` для всех типов, занятость клеток 2×2 | конвейер, бур, печь, поливалка, сборщик ничего не делают: A3–A7 |
| склад: `insert`, `take`, `storage_count`, дрон, сигналы | `get_items()` всегда пустой: A3 |
| костёр: 2 руды + 1 зерно, 3 с, слиток | жилы бесконечны, `vein_exhausted` не приходит: A4 |
| `dig_time`, `dig` (земля исчезает, руда выдаётся) | грядки не растут и не сохнут, `harvest` возвращает 0: A7 |
| `can_plant`, `plant`, `water`, зона колодца | `get_stats`, `period_summary` возвращают нули: A8, A10 |
| `GameState`: карманы, `can_afford`, `pay`, `room` | сохранение на диск: A9 |

То есть ручной цикл первого дня (выкопать руду, переплавить в костре, сдать на склад, дрон) уже можно собрать целиком.

## 8. Ввод (уже в project.godot)

`move_left` (A, ←), `move_right` (D, →), `jump` (Пробел), `climb_up` (W, ↑), `climb_down` (S, ↓), `use_tool` (ЛКМ), `place` (ПКМ), `rotate` (Q), `interact` (E), `demolish` (F), `xray` (X), `sleep` (Z), `pause` (Esc), `slot_1` … `slot_9` (1–9).

Клавиши заданы физическими кодами, поэтому работают при русской раскладке.

Слои физики: 1 `terrain`, 2 `player`, 3 `ladder`, 4 `interact`. Окно 1280×720, растяжение `canvas_items`, пиксельная фильтрация, рендерер Compatibility (нужен для Web).

## 9. Как менять контракт

1. Добавлять методы и сигналы можно без согласования: это не ломает напарника. Владелец правит этот файл в том же коммите.
2. Менять или удалять существующее только по согласию. Запрос пишется в `docs/REQUESTS.md`.
3. Любое изменение `Sim` сопровождается проверкой в `tests/`.

## 10. Проверка

```
godot --headless --path . res://tests/SimTest.tscn
```

Код возврата 0 и строка «Итог: N ок, 0 провалено» означают, что контракт цел. Запускать перед каждым PR.

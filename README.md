# FT2 — Fast Tracker 2

English first, Russian below. / Сначала английский, ниже русский.

---

## English

An AY tracker for ZX Evolution with TS-Config, in Z80 assembler (sjasmplus). The successor of Fast Tracker for the
ZX Spectrum; the screen says "Fast Tracker 2.01b". Author: Orion/DR.

Big thanks to **Pator**, the author of **Bitphase**: a great deal of FT2 is taken from it - the interface, the pattern
commands, the envelope column, the timer effects (FX), the instrument model. Bitphase is the reference our player is
checked against (PSG exports, `doc/bitphase.md`).

Target hardware: the **ZX Trinity** sound card (AY with timer effects in the style of the Atari ST - SID, sync-buzzer,
FM, PWM - written by an RP2350 straight into the AY, plus GS); see `Trinity/doc/zx-trinity.md`. Without the card FT2 plays a
normal AY / TurboSound.

The notes below are what is decided and how it works. Updated on request.

### Build and run

- **F5 in VS Code** (or `build.bat` from the root): the FAT32 driver (`drivers/fat32`), sjasmplus `srs/main.asm`,
  spgbld `srs/spg.ini` → the **`FT2/` folder** (`ft2b.spg` and `ft2.ini` from `srs/ft2.ini`); robimg puts it into the
  image `tools/unreal/wc.img` as `\FT2`, test modules (`Modules for test`) as `\MUSIC`; Unreal starts.
- `ft2.ini`: `load=` - a track to load at start (path from the card root).
- `tools/` (emulators, disk image) and `pentevo/` (Evo sources, Unreal, TS-Config docs) are local only, not in git.
- Emulators: **Unreal** - our build `tools/unreal/Unreal.exe` (below), the original tslabs 2024-07-08 is
  `Unreal_orig.exe`; **Xpeccy** - the mouse works fine. The reference is a real ZX Evolution.

### Our Unreal

- Source in `unreal/` - tslabs/zx-evo commit `02d4daf`. Built with VS 2019 **v142**:
  `MSBuild unreal\Unreal_2017.sln -p:Configuration="Release Unreal" -p:Platform=x64`.
- Our changes: GXOFFS in text mode (as in the FPGA); the mouse follows the Windows cursor (`MouseDiv` in `Unreal.ini`);
  PS/2 log without the mouse, held keys released on focus return; SD write fixed; the **AY FX** device (the Trinity
  timer effects card: `[AY] AYFX=1`); **FT2 frame log** in Save Sound (`*.f2l`: AY registers of both chips + card timer
  state per frame, for comparing with Bitphase exports).
- `Unreal.ini`: `MouseDiv=2`, `video=triple`, `CONTROL=SYM` (Ctrl = Symbol Shift); sound `[AY] Chip=YM`,
  `Scheme=CHRV` - TurboSound (`#FF` selects the first chip); Unreal's F5/F6/F7 bindings are removed (the tracker needs
  them). Debugger - the `` ` `` key, Esc reaches the tracker.

### Structure

| Where | What |
|---|---|
| `srs/main.asm` | entry: includes everything, lays out the pages |
| `srs/core.asm` | core: IM1, start, tool calls; `impcore.asm` - shared import code, converter and PSG calls |
| `srs/mem_defs.asm` | **page map** and core page macros |
| `sdk/plugin.asm` | **SDK**: pattern format, system variables, API, colour roles, command codes |
| `sdk/trinity_ay.asm` | the only way to talk to the Trinity card (protocol - `Trinity/doc/trinity-api.md`) |
| `srs/song.asm` | tracks: current one (`Song_Select`), empty track (`Song_New`) |
| `srs/patview.asm` + `head.asm` | pattern view (6 channels) and the header |
| `srs/instrview.asm`, `fxedit.asm` | Instr / Orn / FX tabs: instrument, ornament and FX editors, note preview |
| `srs/diskview.asm` | Disk tab: catalog, load, save, PSG export (`psgexp.asm`), Check (`cncheck.asm`), import messages (`impdone.asm`) |
| `srs/convview.asm` | converters page: PT3 / PT2 / FTC import (`pt3imp.asm`, `pt2imp.asm`, `ftcimp.asm`) |
| `srs/ft2c.asm` | the `.ft2` container (`doc/formats/ft2.md`) |
| `srs/cmpview.asm` | player comparator against reference players (`ptsplay.asm`, `ftplay.asm`) |
| `srs/optview.asm` | Setup and Help tabs, `\FT2\FT2.INI` |
| `srs/player.asm` | player (own pages, tick from IM1) |
| `srs/window.asm`, `prim.asm`, `button.asm`, `spin.asm`, `scroll.asm`, `textin.asm`, `fields.asm` | windows and standard UI elements (`doc/ui.md`) |
| `srs/input.asm`, `mouse.asm` | PS/2 keyboard (AVR log), Kempston mouse with wheel |
| `srs/diskcall.asm`, `disk.asm` | FAT32 driver calls |
| `drivers/fat32/` | FAT32 driver (copy of github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution, MIT) |
| `srs/fonts/` | the font `cp866bold.SpecCHR` (UI glyphs at codes #00-#1F) |
| `doc/` | design, trackers, formats (`doc/formats/`), Bitphase, AY, instruments, player, Trinity card |

### Memory

- Windows: 0 - core (page #00, IM1 at #38, stack #3E00-#3FFF), 1 - tool or converter (org #4000), 2/3 - tool data
  and screen. Pages are switched **only by macros** (they keep shadows in `SV_PAGES`).
- Fixed layout, no memory manager: each track has its own pages. Map - header of `srs/mem_defs.asm`:

| Pages | What |
|---|---|
| #00 | core |
| #01, #03 | window image / what is under the window |
| #02 | start code |
| #04 | pattern view |
| #05 | undo / clipboard (SPG loader resident at load) |
| #06 | converters (import PT3 / PT2 / FTC) |
| #07 | player: tables (window 2 during the tick) |
| #08-#0F | sprite graphics block; sprites use #08 and #0C-#0D, the rest: #09-#0B pattern view templates, #0E row numbers, #0F Disk catalog |
| #10/#11, #12/#13 | text screen / font, second screen / font |
| #14/#15 | FAT32 driver: code / work memory |
| #16/#17 | track pages 1 and 2 |
| #18 | FAT32 adapter |
| #19 | player: code (window 1 during the IM1 tick) |
| #1A, #1B, #1C, #1D | Disk, Instr/Orn/FX, Setup/Help, comparator |
| #1E-#21 | file buffer (64K) |
| #22-#BF | pool: per track 64 patterns + instruments + ornaments + FX rows + FX tables (68 pages); free - its tail #AA-#BF |
| #C0-#FF | system - untouched |

- Free pages: 22, one piece (shown in Setup).

### Frame

- **IM1 every frame in order:** music → mouse → input → output of the active editor. IM1 only executes; all logic is
  in the main loop. Re-entry is blocked (`Im_Busy`, counter `Im_Reenter` in Setup).
- **The whole UI is redrawn every frame and must fit in a frame.** No skipping, no cached lines.
- The main code never holds DI longer than ~32 T (the frame INT pulse is 32 T).
- **Timing:** Ctrl+T - the time band: the border colour per step.

### Track and pattern

- **Two tracks in memory** (Track 1 / 2 in the header). Load, save, instruments and preview act on the current one.
- **Limits:** patterns 64, instruments 32, ornaments 16, FX 32, positions 256, rows 64. Compiled track ≤ 32K.
- **Pattern** = one 16K page; a row - 256 bytes: data 0..111 (2 chips × 56), then the row's ready text.
- **Chip:** header 8 bytes (envelope period 2, **envelope command** 2, noise 1, envelope note 1, reserved 2) + 3
  channels × 16 (note, sample, envelope shape, ornament, volume, reserved, 2 commands × 2 bytes, reserved 6).
- **Command** - 2 bytes (code<<4 | delay, parameter), 4 hex on screen; codes - `doc/commands.md`. The **envelope
  command** (Env column) acts on the chip's envelope period, like Bitphase's envelope effect column.
- **Instruments and ornaments** - FTC format (`doc/instruments.md`); **FX** - `doc/fx-row.md`.

### Header

- Row 0: "Fast Tracker 2.01b", tabs, transport buttons, 3ch/6ch and stereo, Disk Setup Help About.
- Rows 1-3: File, Chip, Tune; Song, By, Track 1/2; Speed, Size, Octave, Step, Env as Note, Auto Env, Env FT/PT.
- **Tune** - note table: 1.75 MHz (default, YM on the Evo) or 1.7734 MHz; both equal-tempered, A-4 = 440 Hz.
- **Stereo** - 5 layouts as in VT (ABC ACB BAC BCA CAB), applied only on output.
- **Env FT/PT** - FT: the channel with the envelope leads its period; PT: sample offsets of all channels add up (PT3).

### Pattern view, editor, instruments

- The screen is rebuilt every frame: fields by DMA tiling, attributes by DMA from templates, separators on top. One
  element is open (the channel under the cursor or the chip's Env), the rest closed.
- Keys via the action table (`ACT_*`, `Bind_Tab`; defaults - VT). Input as in VT; selection, clipboard, transpose,
  undo (5 steps per channel). Playback: F5 song from position, F6 from the start, F7 pattern from row, F8 pattern,
  Esc stop. Ctrl+E - chip Env, Alt+E - envelope as note, Ctrl+T - time band.
- Instr / Orn / FX: list, Name, Len, Loop, Clone Copy Paste Clear Unloop, rows; note preview at the bottom.

### Disk

- Catalog up to 640 files. Load: FT2, PT3 (incl. TurboSound), PT2, FTC; save: FT2. Losses - in words in the log.
- Buttons: Load, Save, **Compare** (after loading PT3 / PT2 / FTC - compare our player with the reference),
  **PSG** (export: the song from position 0 to its end, chip 1 registers per frame → `<name>.psg`), Check (an FT2 file
  against the track in memory), New, Exit WC, Device.
- Import code lives on its own page (#06); Disk calls it through the core (`Call_Conv`).

### Player

- Notes, instruments and ornaments (FTC), volume, envelope, noise, 2 chips (TurboSound), accumulations as PT3/FTC,
  note preview, all pattern commands (checked against PT3 with the comparator), envelope command (slides so far).
- FX: rows are sent to the Trinity card as packets (`Trinity/doc/trinity-api.md`); the card plays the timers.

### Decided but not done yet

- instrument library; PT3 compiler and other formats (STC, ASC, SQT, PSC, PT1, GTR), VT import;
- the rest of the envelope commands (portamento, vibrato, arpeggio, on/off, detune, auto-envelope);
- per-track cursor; pattern view rework; windows rework (`doc/todo.md`).

---

## Русский

AY-трекер для ZX Evolution с TS-Config, на ассемблере Z80 (sjasmplus). Наследник Fast Tracker для ZX Spectrum. На
экране — «Fast Tracker 2.01b». Автор — Orion/DR.

Огромное спасибо **Pator**, автору **Bitphase**: очень многое в FT2 взято из него — интерфейс, команды паттерна,
колонка огибающей, таймерные эффекты (FX), модель инструментов. По Bitphase сверяется наш плеер (экспорт PSG,
`doc/bitphase.md`).

Целевое железо — звуковая карта **ZX Trinity** (AY с таймерными эффектами в духе Atari ST — SID, sync-buzzer, FM, ШИМ:
RP2350 пишет их прямо в AY, плюс GS); описание — `Trinity/doc/zx-trinity.md`. Без карты FT2 играет на обычном AY / TurboSound.

Шпаргалка ниже — что уже решено и как устроено. Обновляется по команде.

### Сборка и запуск

- **F5 в VS Code** (или `build.bat` из корня): FAT32-драйвер (`drivers/fat32`), sjasmplus `srs/main.asm`, spgbld
  `srs/spg.ini` → **каталог `FT2/`** (`ft2b.spg` и `ft2.ini` из `srs/ft2.ini`); robimg кладёт его в образ
  `tools/unreal/wc.img` как `\FT2`, тестовые модули (`Modules for test`) — в `\MUSIC`; запускается Unreal.
- `ft2.ini`: `load=` — трек, который грузится при старте (путь от корня карты).
- `tools/` (эмуляторы, образ диска) и `pentevo/` (исходники Evo, Unreal, доки TS-Config) — только локально, в git нет.
- Эмуляторы: **Unreal** — наша сборка `tools/unreal/Unreal.exe` (ниже), оригинал tslabs 2024-07-08 — `Unreal_orig.exe`;
  **Xpeccy** — мышь нормальная. Эталон — настоящий ZX Evolution.

### Свой Unreal

- Исходник в `unreal/` — tslabs/zx-evo, коммит `02d4daf`. Сборка VS 2019 **v142**:
  `MSBuild unreal\Unreal_2017.sln -p:Configuration="Release Unreal" -p:Platform=x64`.
- Наши правки: GXOFFS в текстовом режиме (как в ПЛИС); мышь по курсору Windows (`MouseDiv` в `Unreal.ini`); лог PS/2
  без мыши, отпускание клавиш при возврате фокуса; починена запись на SD; устройство **AY FX** (карта таймерных
  эффектов Trinity: `[AY] AYFX=1`); **кадровый журнал FT2** в Save Sound (`*.f2l`: регистры AY обоих чипов и
  состояние таймеров карты по кадрам — для сверки с экспортом Bitphase).
- `Unreal.ini`: `MouseDiv=2`, `video=triple`, `CONTROL=SYM` (Ctrl = Symbol Shift); звук `[AY] Chip=YM`, `Scheme=CHRV` —
  TurboSound (`#FF` выбирает первый чип); привязки Unreal к F5/F6/F7 сняты (нужны трекеру). Отладчик — `` ` ``,
  Esc доходит до трекера.

### Структура

| Где | Что |
|---|---|
| `srs/main.asm` | точка входа: подключает всё, раскладывает по страницам |
| `srs/core.asm` | коре: IM1, старт, вызов тулз; `impcore.asm` — общее для импорта, вызов конвертеров и PSG |
| `srs/mem_defs.asm` | **карта страниц** и макросы страниц коре |
| `sdk/plugin.asm` | **SDK**: формат паттерна, системные переменные, API, роли цветов, коды команд |
| `sdk/trinity_ay.asm` | единственный путь к карте Trinity (протокол — `Trinity/doc/trinity-api.md`) |
| `srs/song.asm` | треки: текущий (`Song_Select`), пустой трек (`Song_New`) |
| `srs/patview.asm` + `head.asm` | вид паттерна (6 каналов) и шапка |
| `srs/instrview.asm`, `fxedit.asm` | вкладки Instr / Orn / FX: редакторы инструментов, орнаментов и FX, проба ноты |
| `srs/diskview.asm` | вкладка Disk: каталог, загрузка, сохранение, экспорт PSG (`psgexp.asm`), Check (`cncheck.asm`), сообщения импорта (`impdone.asm`) |
| `srs/convview.asm` | страница конвертеров: импорт PT3 / PT2 / FTC (`pt3imp.asm`, `pt2imp.asm`, `ftcimp.asm`) |
| `srs/ft2c.asm` | контейнер `.ft2` (`doc/formats/ft2.md`) |
| `srs/cmpview.asm` | компаратор плеера против эталонных плееров (`ptsplay.asm`, `ftplay.asm`) |
| `srs/optview.asm` | вкладки Setup и Help, `\FT2\FT2.INI` |
| `srs/player.asm` | плеер (свои страницы, тик из IM1) |
| `srs/window.asm`, `prim.asm`, `button.asm`, `spin.asm`, `scroll.asm`, `textin.asm`, `fields.asm` | окна и стандартные элементы интерфейса (`doc/ui.md`) |
| `srs/input.asm`, `mouse.asm` | клавиатура PS/2 (лог AVR), мышь Kempston с колесом |
| `srs/diskcall.asm`, `disk.asm` | вызов FAT32-драйвера |
| `drivers/fat32/` | FAT32-драйвер (копия github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution, MIT) |
| `srs/fonts/` | шрифт `cp866bold.SpecCHR` (значки интерфейса — коды #00-#1F) |
| `doc/` | архитектура, трекеры, форматы (`doc/formats/`), Bitphase, AY, инструменты, плеер, карта Trinity |

### Память

- Окна: 0 — коре (страница #00, IM1 на #38, стек #3E00-#3FFF), 1 — тулза или конвертеры (org #4000), 2/3 — данные
  тулзы и экран. Страницы переключаются **только макросами** (они ведут тени в `SV_PAGES`).
- Распределение жёсткое, без менеджмента памяти: у каждого трека свои страницы. Карта — шапка `srs/mem_defs.asm`:

| Страницы | Что |
|---|---|
| #00 | коре |
| #01, #03 | вид окна / что под окном |
| #02 | стартовый код |
| #04 | вид паттерна |
| #05 | отмена / буфер обмена (при загрузке — резидент загрузчика SPG) |
| #06 | конвертеры (импорт PT3 / PT2 / FTC) |
| #07 | плеер: таблицы (окно 2 на время тика) |
| #08-#0F | блок графики спрайтов; спрайты берут #08 и #0C-#0D, остальное: #09-#0B шаблоны вида паттерна, #0E номера роу, #0F каталог Disk |
| #10/#11, #12/#13 | текстовый экран / шрифт, второй экран / шрифт |
| #14/#15 | FAT32-драйвер: код / рабочая память |
| #16/#17 | страницы треков 1 и 2 |
| #18 | переходник к FAT32 |
| #19 | плеер: код (окно 1 на время тика в IM1) |
| #1A, #1B, #1C, #1D | Disk, Instr/Orn/FX, Setup/Help, компаратор |
| #1E-#21 | буфер файла (64К) |
| #22-#BF | пул: на трек 64 паттерна + инструменты + орнаменты + строки FX + таблицы FX (68 страниц); свободно — его хвост #AA-#BF |
| #C0-#FF | система — не трогаем |

- Свободно 22 страницы одним куском (видно в Setup).

### Кадр

- **IM1 каждый кадр по порядку:** музыка → мышь → ввод → вывод активного редактора. IM1 только исполняет, вся логика —
  в основном цикле. Повторный вход закрыт (`Im_Busy`, счётчик `Im_Reenter` — в Setup).
- **Весь интерфейс рисуется каждый кадр и влезает в кадр.** Пропуск перерисовки и кеш строк — нельзя.
- Основной код не держит DI дольше ~32 тактов (импульс кадрового INT — 32 такта).
- **Замер времени:** Ctrl+T — полоса времени: цвет бордюра на каждый шаг.

### Трек и паттерн

- **Два трека в памяти** (Track 1 / 2 в шапке). Загрузка, сохранение, инструменты и проба — в текущий.
- **Лимиты:** паттернов 64, инструментов 32, орнаментов 16, FX 32, позиций 256, роу 64. Откомпилированный трек ≤ 32К.
- **Паттерн** — одна страница 16К; роу — 256 байт: данные 0..111 (2 чипа × 56), дальше готовый текст роу.
- **Чип:** заголовок 8 байт (период огибающей 2, **команда огибающей** 2, шум 1, нота огибающей 1, резерв 2) + 3 канала
  по 16 (нота, сэмпл, форма огибающей, орнамент, громкость, резерв, 2 команды по 2 байта, резерв 6).
- **Команда** — 2 байта (код<<4 | задержка, параметр), на экране 4 hex; коды — `doc/commands.md`. **Команда
  огибающей** (колонка Env) действует на период огибающей чипа — как колонка эффекта огибающей Bitphase.
- **Инструменты и орнаменты** — формат FTC (`doc/instruments.md`); **FX** — `doc/fx-row.md`.

### Шапка

- Строка 0: «Fast Tracker 2.01b», вкладки, кнопки транспорта, 3ch/6ch и стерео, Disk Setup Help About.
- Строки 1–3: File, Chip, Tune; Song, By, Track 1/2; Speed, Size, Octave, Step, Env as Note, Auto Env, Env FT/PT.
- **Tune** — таблица нот: 1.75 МГц (по умолчанию, YM на Evo) или 1.7734 МГц; обе ровные, A-4 = 440 Гц.
- **Стерео** — 5 раскладок как в VT (ABC ACB BAC BCA CAB), только при выводе.
- **Env FT/PT** — FT: период огибающей ведёт канал с огибающей; PT: смещения сэмплов всех каналов складываются (PT3).

### Вид паттерна, редактор, инструменты

- Экран пересобирается каждый кадр: поля — DMA-черепицей, атрибуты — DMA из шаблонов, разделители поверх. Открыт один
  элемент (канал под курсором или Env чипа), остальные закрыты.
- Клавиши — через таблицу действий (`ACT_*`, `Bind_Tab`; умолчания — VT). Ввод как VT; выделение, буфер обмена,
  транспонирование, отмена (5 шагов в канале). Проигрывание: F5 — сонг с позиции, F6 — с начала, F7 — паттерн с роу,
  F8 — паттерн, Esc — стоп. Ctrl+E — Env чипа, Alt+E — огибающая нотой, Ctrl+T — полоса времени.
- Instr / Orn / FX: список, Name, Len, Loop, Clone Copy Paste Clear Unloop, строки; внизу — проба ноты.

### Диск

- Каталог до 640 файлов. Загрузка: FT2, PT3 (в т.ч. TurboSound), PT2, FTC; сохранение: FT2. Потери — словами в логе.
- Кнопки: Load, Save, **Compare** (после загрузки PT3 / PT2 / FTC — сравнить наш плеер с эталоном), **PSG** (экспорт:
  трек с позиции 0 до конца, регистры чипа 1 по кадрам → `<имя>.psg`), Check (файл FT2 против трека в памяти), New,
  Exit WC, Device.
- Код импорта — в своей странице (#06), Disk зовёт его через коре (`Call_Conv`).

### Плеер

- Ноты, инструменты и орнаменты (FTC), громкость, огибающая, шум, 2 чипа (TurboSound), накопления как в PT3/FTC, проба
  ноты, все команды паттерна (сверено с PT3 компаратором), команда огибающей (пока слайды).
- FX: строки уходят в карту Trinity пакетами (`Trinity/doc/trinity-api.md`), таймеры играет карта.

### Решено, но ещё не сделано

- библиотека инструментов; компилятор в PT3 и остальные форматы (STC, ASC, SQT, PSC, PT1, GTR), импорт из VT;
- остальные команды огибающей (портаменто, вибрато, арпеджио, вкл / выкл, детюн, автоогибающая);
- свой курсор у каждого трека; реворк вида паттерна; реворк окон (`doc/todo.md`).

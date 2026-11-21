# FT2 — Fast Tracker 2

English first, Russian below. / Сначала английский, ниже русский.

---

## English

**Fast Tracker 2** is an AY / YM tracker for **ZX Evolution** with the **TS-Config** firmware, written in Z80 assembler.
It is the successor of Fast Tracker for the ZX Spectrum, with an interface in the spirit of Bitphase and FastTracker 2
on the PC: text mode 90×36, mouse, PC keyboard. Author: Orion/DR.

**Status: beta.** A lot works already, but this is not a finished tracker yet. Releases are on the
[Releases](https://github.com/Zeizwell/FT2/releases) page. The archive has the `FT2` folder, `README.TXT` and the format
description `FT2FMT.TXT`.

Big thanks to **Pator**, the author of **Bitphase**: a great deal of FT2 is taken from it - the interface, the pattern
commands, the envelope column, the timer effects (FX), the instrument model. Bitphase is the reference our player is
checked against.

### What it can do

- **6 channels:** one AY (3 channels) or TurboSound (two chips). Stereo layouts ABC ACB BAC BCA CAB, as in Vortex Tracker.
- **Two tracks in memory**, switched from the header (Track 1 / 2).
- **Pattern editor:**
  - input as in Vortex Tracker;
  - selection, clipboard, transpose, undo / redo;
  - an envelope column per chip (period, noise, envelope command);
  - "Env as Note" - enter the envelope period as a note.
- **Instruments and ornaments** in the Fast Tracker model: 32 instruments and 32 ornaments, up to 100 rows each. Rows
  have loops, and a note preview sits under the editor.
- **FX - timer effects** of the ZX Trinity card: SID, Sync-buzzer, FM, Env FM, PWM with sweep shapes. 32 FX, each with
  its own editor. An edit is heard at once.
- **Player:**
  - all pattern commands (`doc/commands.md`): portamento, glide, vibrato, arpeggio, volume and envelope slides,
    on / off, retrigger, speed;
  - two track modes, FT (Fast Tracker 1.15) and PT (Pro Tracker 3);
  - note tables 1.75 MHz and 1.7734 MHz.
- **Disk:**
  - SD card catalog with long names, up to 640 files;
  - loads FT2, PT3 (with TurboSound), PT2 and FTC;
  - saves FT2 (own format, `doc/formats/ft2.md`);
  - PSG export (chip 1 registers per frame);
  - after an import, a message says what did not fit;
  - Check: compares an FT2 file with the track in memory.
- **Compare:** after a PT3 / PT2 / FTC import, plays the module with our player and with the original player side by
  side and shows the frames where they differ.
- **Setup:** 6 colour themes, mouse speed and acceleration. Settings go to `\FT2\FT2.INI`, and only when you press Save.
- **Help:** keys and pattern commands, built from the real key bindings.

### What you need

- ZX Evolution with TS-Config (it also runs in the Unreal Speccy emulator; Xpeccy has the best mouse).
- An SD card with FAT32 (Z-Controller / SD-ZC).
- A PS/2 (PC) keyboard and a Kempston mouse with a wheel.
- AY / YM; for 6 channels - TurboSound (chips selected by `#FF` / `#FE`).
- Optional: the **ZX Trinity** card for the timer effects. Without it FT2 plays a plain AY / TurboSound, and FX are
  silent.

### Install and run

1. Copy the `FT2` folder to the root of the SD card.
2. Run `\FT2\FT2B.SPG`.
3. In `FT2.INI`, `load=` names a track to load at start (path from the card root).

### Main keys

| Key | Action |
|---|---|
| F5 / F6 | play the song from the position / from the start |
| F7 / F8 | play the pattern from the row / the whole pattern in a loop |
| Esc | stop; in tools - back to the pattern |
| Z..M, Q..P | notes (Shift - an octave higher); A - off, K - erase |
| 0-9, A-F | digits into fields; Delete - clear |
| Insert / Backspace | insert / delete a track row (Ctrl+I / Ctrl+Y - pattern row) |
| Shift + arrows / click | selection; Ctrl+A - all; Ctrl+C X V - copy, cut, paste |
| Num + / - | transpose (with Ctrl - by an octave) |
| Ctrl+Z / Ctrl+Shift+Z | undo / redo |
| Ctrl+E | the chip's envelope column; Alt+E - envelope as a note |
| Ctrl+T | time band (how much of the frame each part takes) |
| Mouse | click - cursor and buttons, wheel - rows (Ctrl / Shift - channels), right click - menu |

The full list is in the Help tab and in `dist/README_WIN.TXT`.

### Limits

Patterns 64, rows per pattern 64, positions 256, instruments 32 and ornaments 32 (100 rows each), FX 32, two tracks,
compiled track up to 32K.

### Not done yet

- an instrument library on the disk;
- PT3 export, and loading other formats (STC, ASC, SQT, PSC, PT1, GTR, Vortex Tracker text);
- the rest of the envelope column commands (portamento, vibrato, arpeggio, on / off, detune, auto-envelope);
- FX commands E1..E5 in the pattern;
- a separate cursor for each track; the pattern view and windows rework (`doc/todo.md`).

### Authors and licenses

- Fast Tracker 2 - Orion/DR.
- FAT32 driver - [andrewinsidelazarev/FAT32-Driver-ZX-Evolution](https://github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution) (MIT).
- Fonts Toshiba TxL1 / TxL2, Compaq Thin - The Ultimate Oldschool PC Font Pack, int10h.org (CC BY-SA 4.0).

---

### For developers

#### Build and run

- **F5 in VS Code** (or `build.bat` from the root) does the following:
  1. builds the FAT32 driver (`drivers/fat32`);
  2. sjasmplus `srs/main.asm`, then spgbld `srs/spg.ini` → the **`FT2/` folder** (`ft2b.spg`, and `ft2.ini` from
     `srs/ft2.ini`);
  3. robimg puts it into the image `tools/unreal/wc.img` as `\FT2`, and the test modules as `\MUSIC`;
  4. starts Unreal.
- `tools/` (emulators, disk image) and `pentevo/` (Evo sources, TS-Config docs) are local only, not in git.
- Emulators:
  - **Unreal** - our build, `tools/unreal/Unreal.exe` (below); the original tslabs 2024-07-08 is `Unreal_orig.exe`;
  - **Xpeccy** - the mouse works fine.
  
  The reference is a real ZX Evolution.

#### Our Unreal

- Source in `unreal/` - tslabs/zx-evo commit `02d4daf`. Built with VS 2019 **v142**:
  `MSBuild unreal\Unreal_2017.sln -p:Configuration="Release Unreal" -p:Platform=x64`.
- Our changes:
  - GXOFFS in text mode (as in the FPGA);
  - the mouse follows the Windows cursor (`MouseDiv` in `Unreal.ini`);
  - the PS/2 log has no mouse data, and held keys are released when focus returns;
  - SD write fixed;
  - the **ZX Trinity card** as a plugin DLL (`trinity_card.dll`: AY with timer effects; `GSType=TRIN` - RP-GS from
    `trinity_gs.dll`);
  - an **FT2 frame log** in Save Sound (`*.f2l`).
- `Unreal.ini`:
  - `MouseDiv=2`, `video=triple`, `CONTROL=SYM` (Ctrl = Symbol Shift);
  - sound `[AY] Chip=YM`, `Scheme=CHRV` (TurboSound);
  - Unreal's F5 / F6 / F7 bindings are removed, because the tracker needs those keys;
  - the debugger is on the `` ` `` key, and Esc reaches the tracker.

#### Structure

| Where | What |
|---|---|
| `srs/main.asm` | entry: includes everything, lays out the pages |
| `srs/core.asm` | core: IM1, start, tool calls; `impcore.asm` - shared import code, converter and PSG calls |
| `srs/mem_defs.asm` | **page map** and core page macros |
| `sdk/plugin.asm` | **SDK**: pattern format, system variables, API, colour roles, command codes |
| `sdk/trinity_ay.asm` | the only way to talk to the Trinity card (copy of the card's SDK) |
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
| `drivers/fat32/` | FAT32 driver (copy of the upstream, MIT) |
| `srs/fonts/` | the font `cp866bold.SpecCHR` (UI glyphs at codes #00-#1F) |
| `doc/` | design, trackers, formats (`doc/formats/`), Bitphase, AY, instruments, commands, UI |

#### Memory

- Windows:
  - 0 - core (page #00, IM1 at #38, stack #3E00-#3FFF);
  - 1 - a tool or the converters (org #4000);
  - 2 / 3 - tool data and the screen.
  
  Pages are switched **only by macros**, which keep the shadows in `SV_PAGES`.
- Fixed layout, no memory manager: each track has its own pages. The map is in the header of `srs/mem_defs.asm`:

| Pages | What |
|---|---|
| #00 | core |
| #01, #03 | window image / what is under the window |
| #02 | start code |
| #04 | pattern view |
| #05 | undo / clipboard (SPG loader resident at load) |
| #06 | converters (import PT3 / PT2 / FTC) |
| #07 | player: tables (window 2 during the tick) |
| #08-#0F | sprites #08, #0C-#0D; pattern view templates #09-#0B, row numbers #0E, Disk catalog #0F |
| #10/#11, #12/#13 | text screen / font, second screen / font |
| #14/#15 | FAT32 driver: code / work memory |
| #16/#17 | track pages 1 and 2 |
| #18 | FAT32 adapter |
| #19 | player: code (window 1 during the IM1 tick) |
| #1A, #1B, #1C, #1D | Disk, Instr/Orn/FX, Setup/Help, comparator |
| #1E-#21 | file buffer (64K) |
| #22-#BF | pool: per track 64 patterns + instruments + ornaments + FX rows + FX tables; free - its tail |
| #C0-#FF | system - untouched |

#### Frame

- **IM1 every frame, in order:** music → mouse → input → output of the active editor. IM1 only executes; all the
  logic is in the main loop. Re-entry is blocked (`Im_Busy`).
- **The whole UI is redrawn every frame and must fit in a frame.** No skipping, no cached lines.
- The main code never holds DI longer than ~32 T (the frame INT pulse is 32 T).

#### Track and pattern

- **Pattern** = one 16K page. A row is 256 bytes: data 0..111 (2 chips × 56), then the row's ready text.
- **Chip:**
  - header, 8 bytes: envelope period 2, envelope command 2, noise 1, envelope note 1, reserved 2;
  - then 3 channels × 16 bytes: note, sample, envelope shape, ornament, volume, reserved, 2 commands × 2 bytes,
    reserved 6.
- **Command** - 2 bytes (code<<4 | delay, parameter), shown as 4 hex digits; codes - `doc/commands.md`.
- Instruments and ornaments - `doc/instruments.md`; FX - `doc/fx-row.md`.
- **Player:**
  - code on page #19, tables on page #07;
  - each channel's code is a macro ×6, and modes are switched by "gates" (a `jr` ↔ `cp n` opcode);
  - FX go to the Trinity card as packets through `sdk/trinity_ay.asm`.

---

## Русский

**Fast Tracker 2** — AY / YM-трекер для **ZX Evolution** с прошивкой **TS-Config**, написан на ассемблере Z80. Это
наследник Fast Tracker для ZX Spectrum. Интерфейс — в духе Bitphase и FastTracker 2 на ПК: текстовый режим 90×36,
мышь, клавиатура PC. Автор — Orion/DR.

**Состояние: бета.** Многое уже работает, но это ещё не готовый трекер. Релизы — на странице
[Releases](https://github.com/Zeizwell/FT2/releases). В архиве — папка `FT2`, `README.TXT` и описание формата `FT2FMT.TXT`.

Огромное спасибо **Pator**, автору **Bitphase**: очень многое в FT2 взято из него — интерфейс, команды паттерна,
колонка огибающей, таймерные эффекты (FX), модель инструментов. По Bitphase сверяется наш плеер.

### Что умеет

- **6 каналов:** один AY (3 канала) или TurboSound (два чипа). Стерео — ABC ACB BAC BCA CAB, как в Vortex Tracker.
- **Два трека в памяти**, переключаются в шапке (Track 1 / 2).
- **Редактор паттерна:**
  - ввод как в Vortex Tracker;
  - выделение, буфер обмена, транспонирование, отмена и повтор;
  - колонка огибающей у каждого чипа (период, шум, команда огибающей);
  - «Env as Note» — период огибающей вводится нотой.
- **Инструменты и орнаменты** по модели Fast Tracker: 32 инструмента и 32 орнамента, до 100 строк в каждом. У строк есть
  петли, под редактором — проба ноты.
- **FX — таймерные эффекты** карты ZX Trinity: SID, Sync-buzzer, FM, Env FM, ШИМ с формами свипа. 32 FX, у каждого свой
  редактор. Правка слышна сразу.
- **Плеер:**
  - все команды паттерна (`doc/commands.md`): портаменто, глисс, вибрато, арпеджио, слайды громкости и огибающей,
    вкл / выкл, ретриггер, скорость;
  - два режима трека — FT (Fast Tracker 1.15) и PT (Pro Tracker 3);
  - таблицы нот 1.75 МГц и 1.7734 МГц.
- **Диск:**
  - каталог SD-карты с длинными именами, до 640 файлов;
  - загрузка FT2, PT3 (с TurboSound), PT2 и FTC;
  - сохранение FT2 (свой формат, `doc/formats/ft2.md`);
  - экспорт PSG (регистры чипа 1 по кадрам);
  - после импорта сообщение говорит, что не влезло;
  - Check — сравнение файла FT2 с треком в памяти.
- **Compare:** после импорта PT3 / PT2 / FTC модуль играется нашим плеером и оригинальным рядом, видно кадры, где они
  расходятся.
- **Setup:** 6 цветовых тем, скорость и ускорение мыши. Настройки пишутся в `\FT2\FT2.INI` — только кнопкой Save.
- **Help:** клавиши и команды паттерна, строится из настоящих биндов.

### Что нужно

- ZX Evolution с TS-Config (работает и в эмуляторе Unreal Speccy; лучшая мышь — в Xpeccy).
- SD-карта с FAT32 (Z-Controller / SD-ZC).
- Клавиатура PS/2 (PC) и мышь Kempston с колесом.
- AY / YM; для 6 каналов — TurboSound (чипы выбираются `#FF` / `#FE`).
- По желанию — карта **ZX Trinity** для таймерных эффектов. Без неё FT2 играет на обычном AY / TurboSound, а FX молчат.

### Установка и запуск

1. Скопировать папку `FT2` в корень SD-карты.
2. Запустить `\FT2\FT2B.SPG`.
3. В `FT2.INI` строка `load=` задаёт трек, который грузится при старте (путь от корня карты).

### Главные клавиши

| Клавиша | Действие |
|---|---|
| F5 / F6 | сонг с позиции / с начала |
| F7 / F8 | паттерн с роу / паттерн по кругу |
| Esc | стоп; в тулзах — назад к паттерну |
| Z..M, Q..P | ноты (Shift — октавой выше); A — выкл, K — стереть |
| 0-9, A-F | цифры в поля; Delete — очистить |
| Insert / Backspace | вставить / удалить роу трека (Ctrl+I / Ctrl+Y — роу паттерна) |
| Shift + стрелки / клик | выделение; Ctrl+A — всё; Ctrl+C X V — копировать, вырезать, вставить |
| Num + / - | транспонирование (с Ctrl — на октаву) |
| Ctrl+Z / Ctrl+Shift+Z | отмена / повтор |
| Ctrl+E | колонка огибающей чипа; Alt+E — огибающая нотой |
| Ctrl+T | полоса времени (сколько кадра занимает каждая часть) |
| Мышь | клик — курсор и кнопки, колесо — роу (Ctrl / Shift — каналы), правая кнопка — меню |

Полный список — во вкладке Help и в `dist/README_WIN.TXT`.

### Лимиты

Паттернов 64, роу в паттерне 64, позиций 256, инструментов 32 и орнаментов 32 (по 100 строк), FX 32, два трека,
откомпилированный трек — до 32К.

### Ещё не сделано

- библиотека инструментов на диске;
- экспорт в PT3, загрузка остальных форматов (STC, ASC, SQT, PSC, PT1, GTR, текст Vortex Tracker);
- остальные команды колонки огибающей (портаменто, вибрато, арпеджио, вкл / выкл, детюн, автоогибающая);
- команды FX E1..E5 в паттерне;
- свой курсор у каждого трека; реворк вида паттерна и окон (`doc/todo.md`).

### Авторы и лицензии

- Fast Tracker 2 — Orion/DR.
- FAT32-драйвер — [andrewinsidelazarev/FAT32-Driver-ZX-Evolution](https://github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution) (MIT).
- Шрифты Toshiba TxL1 / TxL2, Compaq Thin — The Ultimate Oldschool PC Font Pack, int10h.org (CC BY-SA 4.0).

---

### Для разработчика

#### Сборка и запуск

- **F5 в VS Code** (или `build.bat` из корня) делает следующее:
  1. собирает FAT32-драйвер (`drivers/fat32`);
  2. sjasmplus `srs/main.asm`, потом spgbld `srs/spg.ini` → **каталог `FT2/`** (`ft2b.spg`, и `ft2.ini` из
     `srs/ft2.ini`);
  3. robimg кладёт его в образ `tools/unreal/wc.img` как `\FT2`, а тестовые модули — в `\MUSIC`;
  4. запускает Unreal.
- `tools/` (эмуляторы, образ диска) и `pentevo/` (исходники Evo, доки TS-Config) — только локально, в git нет.
- Эмуляторы:
  - **Unreal** — наша сборка, `tools/unreal/Unreal.exe` (ниже); оригинал tslabs 2024-07-08 — `Unreal_orig.exe`;
  - **Xpeccy** — мышь нормальная.
  
  Эталон — настоящий ZX Evolution.

#### Свой Unreal

- Исходник в `unreal/` — tslabs/zx-evo, коммит `02d4daf`. Сборка VS 2019 **v142**:
  `MSBuild unreal\Unreal_2017.sln -p:Configuration="Release Unreal" -p:Platform=x64`.
- Наши правки:
  - GXOFFS в текстовом режиме (как в ПЛИС);
  - мышь идёт по курсору Windows (`MouseDiv` в `Unreal.ini`);
  - в логе PS/2 нет мыши, при возврате фокуса зажатые клавиши отпускаются;
  - починена запись на SD;
  - **карта ZX Trinity** — DLL-плагином (`trinity_card.dll`: AY с таймерными эффектами; `GSType=TRIN` — RP-GS из
    `trinity_gs.dll`);
  - **кадровый журнал FT2** в Save Sound (`*.f2l`).
- `Unreal.ini`:
  - `MouseDiv=2`, `video=triple`, `CONTROL=SYM` (Ctrl = Symbol Shift);
  - звук `[AY] Chip=YM`, `Scheme=CHRV` (TurboSound);
  - привязки Unreal к F5 / F6 / F7 сняты — эти клавиши нужны трекеру;
  - отладчик — на клавише `` ` ``, Esc доходит до трекера.

#### Структура

| Где | Что |
|---|---|
| `srs/main.asm` | точка входа: подключает всё, раскладывает по страницам |
| `srs/core.asm` | коре: IM1, старт, вызов тулз; `impcore.asm` — общее для импорта, вызов конвертеров и PSG |
| `srs/mem_defs.asm` | **карта страниц** и макросы страниц коре |
| `sdk/plugin.asm` | **SDK**: формат паттерна, системные переменные, API, роли цветов, коды команд |
| `sdk/trinity_ay.asm` | единственный путь к карте Trinity (копия SDK карты) |
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
| `drivers/fat32/` | FAT32-драйвер (копия оригинала, MIT) |
| `srs/fonts/` | шрифт `cp866bold.SpecCHR` (значки интерфейса — коды #00-#1F) |
| `doc/` | архитектура, трекеры, форматы (`doc/formats/`), Bitphase, AY, инструменты, команды, интерфейс |

#### Память

- Окна:
  - 0 — коре (страница #00, IM1 на #38, стек #3E00-#3FFF);
  - 1 — тулза или конвертеры (org #4000);
  - 2 / 3 — данные тулзы и экран.
  
  Страницы переключаются **только макросами**, они ведут тени в `SV_PAGES`.
- Распределение жёсткое, без менеджмента памяти: у каждого трека свои страницы. Карта — в шапке `srs/mem_defs.asm`:

| Страницы | Что |
|---|---|
| #00 | коре |
| #01, #03 | вид окна / что под окном |
| #02 | стартовый код |
| #04 | вид паттерна |
| #05 | отмена / буфер обмена (при загрузке — резидент загрузчика SPG) |
| #06 | конвертеры (импорт PT3 / PT2 / FTC) |
| #07 | плеер: таблицы (окно 2 на время тика) |
| #08-#0F | спрайты #08, #0C-#0D; шаблоны вида паттерна #09-#0B, номера роу #0E, каталог Disk #0F |
| #10/#11, #12/#13 | текстовый экран / шрифт, второй экран / шрифт |
| #14/#15 | FAT32-драйвер: код / рабочая память |
| #16/#17 | страницы треков 1 и 2 |
| #18 | переходник к FAT32 |
| #19 | плеер: код (окно 1 на время тика в IM1) |
| #1A, #1B, #1C, #1D | Disk, Instr/Orn/FX, Setup/Help, компаратор |
| #1E-#21 | буфер файла (64К) |
| #22-#BF | пул: на трек 64 паттерна + инструменты + орнаменты + строки FX + таблицы FX; свободно — его хвост |
| #C0-#FF | система — не трогаем |

#### Кадр

- **IM1 каждый кадр, по порядку:** музыка → мышь → ввод → вывод активного редактора. IM1 только исполняет, вся логика —
  в основном цикле. Повторный вход закрыт (`Im_Busy`).
- **Весь интерфейс рисуется каждый кадр и влезает в кадр.** Пропуск перерисовки и кеш строк — нельзя.
- Основной код не держит DI дольше ~32 тактов (импульс кадрового INT — 32 такта).

#### Трек и паттерн

- **Паттерн** — одна страница 16К. Роу — 256 байт: данные 0..111 (2 чипа × 56), дальше готовый текст роу.
- **Чип:**
  - заголовок, 8 байт: период огибающей 2, команда огибающей 2, шум 1, нота огибающей 1, резерв 2;
  - дальше 3 канала по 16 байт: нота, сэмпл, форма огибающей, орнамент, громкость, резерв, 2 команды по 2 байта,
    резерв 6.
- **Команда** — 2 байта (код<<4 | задержка, параметр), на экране 4 hex; коды — `doc/commands.md`.
- Инструменты и орнаменты — `doc/instruments.md`; FX — `doc/fx-row.md`.
- **Плеер:**
  - код — на странице #19, таблицы — на #07;
  - код каждого канала — макрос ×6, режимы переключаются «воротами» (опкод `jr` ↔ `cp n`);
  - FX уходят в карту Trinity пакетами через `sdk/trinity_ay.asm`.

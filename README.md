# FT2 — Fast Tracker 2

English first, Russian below. / Сначала английский, ниже русский.

---

## English

**6-channel AY / YM tracker for ZX Evolution (TS-Config).** Z80 assembler. Text mode 90×36, mouse, PC keyboard.
Successor of Fast Tracker for the ZX Spectrum. Author: Orion/DR. **Status: beta** — [Releases](https://github.com/Zeizwell/FT2/releases).

**Key points**
- **ZX Trinity timer effects** on real AY chips: SID, Sync, FM, Env FM, PWM with sweep — own editor, heard while editing.
- **Player checked frame by frame** against the original players: PT3 / PT2 — Bulba's player, FTC — Fast Tracker 1.15.
- **Import PT3 (TurboSound), PT2, FTC** with a report of what did not fit, and side-by-side compare with the original player.
- **Two tracks in memory**; the song is edited as one sheet — patterns stitched by the order.

### Song

| | |
|---|---|
| Channels | 6: TurboSound (2 × AY / YM) or 3 on one chip |
| Stereo | ABC, ACB, BAC, BCA, CAB |
| Tracks in memory | 2 |
| Patterns | 64 × up to 64 rows |
| Order | 256 positions, loop position; shown as one sheet |
| Channel fields | note C-1..B-8, instrument, envelope shape 1..14, ornament, volume 0..F, 2 commands |
| Chip column | envelope period (or as a note), envelope command, noise |
| Commands | codes 1..E and F with sub-codes: portamento, glide, vibrato, arpeggio, volume and envelope slides, on / off, retrigger, speed |
| Note tables | 1.75 MHz, 1.7734 MHz |
| Envelope mode | FT (Fast Tracker 1.15) or PT (Pro Tracker 3) |
| Name / author | 32 + 32 characters |
| Compiled track | up to 32K |

### Instruments, ornaments, FX

| | |
|---|---|
| Instruments | 32 × up to 100 rows, loop; row: tone offset 12 bit, noise offset, envelope offset, volume 0..F, accumulation of tone / noise / envelope, volume slide, envelope retrigger; linked FX |
| Ornaments | 32 × up to 100 rows, loop; row: note offset ±, noise offset, accumulation |
| FX (ZX Trinity) | 32 × up to 32 rows, loop; per row: Mix (SID / Sync), FM, Env FM — each with own timer, table and length 1..16; detune in semitones and raw; PWM 16 steps 0..50 %; sweep 256 phases, shape by table |
| FX tables | 256 × 16 values |

### Disk and files

| | |
|---|---|
| Catalog | SD card (FAT32), long names, up to 640 files |
| Load | FT2, PT3 (TurboSound), PT2, FTC; report of what did not fit |
| Save | FT2 — own block format with CRC-16 ([spec](doc/formats/ft2.md)) |
| Export | PSG (chip 1 registers per frame) |
| Check | compares an FT2 file with the track in memory |
| Compare | imported module played by our player and the original one, frames that differ are shown |

### Interface

| | |
|---|---|
| Screen | text 90×36, the whole interface redrawn every frame (50 fps) |
| Mouse | Kempston with wheel: 16.8 fixed-point precision, fractional speed, cubic acceleration 0..8 |
| Keyboard | PS/2 (PC), Ctrl / Alt / Shift combinations |
| Editing | selection, clipboard, transpose, undo / redo |
| Themes | 6 colour themes; settings saved to `\FT2\FT2.INI` only by Save |
| Help | keys and pattern commands, built from the real key bindings |

### Requirements and install

- ZX Evolution with TS-Config (also Unreal Speccy, Xpeccy); SD card FAT32 (Z-Controller); PS/2 keyboard; Kempston mouse with wheel.
- AY / YM; 6 channels — TurboSound (`#FF` / `#FE`). Optional: **ZX Trinity** card for FX (without it FX are silent).
- Copy the `FT2` folder to the SD root, run `\FT2\FT2B.SPG`. `load=` in `FT2.INI` — a track to load at start.

### Main keys

| Key | Action |
|---|---|
| F5 / F6 | play the song from the position / from the start |
| F7 / F8 | play the pattern from the row / the whole pattern in a loop |
| Esc | stop; in tabs - back to the pattern |
| Z..M, Q..P | notes (Shift - an octave higher); A - off, K - erase |
| Insert / Backspace | insert / delete a track row (Ctrl+I / Ctrl+Y - pattern row) |
| Shift + arrows / click | selection; Ctrl+A - all; Ctrl+C X V - copy, cut, paste |
| Num + / - | transpose (with Ctrl - by an octave) |
| Ctrl+Z / Ctrl+Shift+Z | undo / redo |
| Ctrl+E / Alt+E | envelope column / envelope as a note |
| Mouse | click - cursor and buttons, wheel - rows (Ctrl / Shift - channels), right click - menu |

Full list — Help tab and `README.TXT`.

### Not done yet

Instrument library on disk; PT3 export; import STC, ASC, SQT, PSC, PT1, GTR, Vortex Tracker text; envelope column commands (portamento, vibrato, arpeggio, on / off, detune, auto-envelope); FX commands E1..E5 in the pattern; separate cursor per track.

### Credits and licenses

- Fast Tracker 2 — Orion/DR.
- Thanks to **Pator**, the author of **Bitphase**: the interface, pattern commands, envelope column and timer effects (FX) are largely taken from it.
- FAT32 driver — [andrewinsidelazarev/FAT32-Driver-ZX-Evolution](https://github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution) (MIT).
- Fonts Toshiba TxL1 / TxL2, Compaq Thin — The Ultimate Oldschool PC Font Pack, int10h.org (CC BY-SA 4.0).

---

## Русский

**6-канальный AY / YM-трекер для ZX Evolution (TS-Config).** Ассемблер Z80. Текстовый режим 90×36, мышь, клавиатура PC.
Наследник Fast Tracker для ZX Spectrum. Автор — Orion/DR. **Состояние: бета** — [Releases](https://github.com/Zeizwell/FT2/releases).

**Главное**
- **Таймерные эффекты ZX Trinity** на настоящих AY: SID, Sync, FM, Env FM, ШИМ со свипом — свой редактор, слышно во время правки.
- **Плеер сверен покадрово** с оригинальными плеерами: PT3 / PT2 — плеер Бульбы, FTC — Fast Tracker 1.15.
- **Импорт PT3 (TurboSound), PT2, FTC** с отчётом, что не влезло, и сравнение с оригинальным плеером рядом.
- **Два трека в памяти**; песня правится одним листом — паттерны сшиты по ордеру.

### Песня

| | |
|---|---|
| Каналы | 6: TurboSound (2 × AY / YM) или 3 на одном чипе |
| Стерео | ABC, ACB, BAC, BCA, CAB |
| Треков в памяти | 2 |
| Паттерны | 64 × до 64 строк |
| Ордер | 256 позиций, позиция цикла; показывается одним листом |
| Поля канала | нота C-1..B-8, инструмент, форма огибающей 1..14, орнамент, громкость 0..F, 2 команды |
| Колонка чипа | период огибающей (или нотой), команда огибающей, шум |
| Команды | коды 1..E и F с подкодами: портаменто, глисс, вибрато, арпеджио, слайды громкости и огибающей, вкл / выкл, ретриггер, скорость |
| Таблицы нот | 1.75 МГц, 1.7734 МГц |
| Огибающая | FT (Fast Tracker 1.15) или PT (Pro Tracker 3) |
| Имя / автор | 32 + 32 знака |
| Откомпилированный трек | до 32К |

### Инструменты, орнаменты, FX

| | |
|---|---|
| Инструменты | 32 × до 100 строк, петля; строка: смещение тона 12 бит, шума, огибающей, громкость 0..F, накопление тона / шума / огибающей, слайд громкости, ретриггер огибающей; привязка FX |
| Орнаменты | 32 × до 100 строк, петля; строка: смещение ноты ±, смещение шума, накопление |
| FX (ZX Trinity) | 32 × до 32 строк, петля; в строке: Mix (SID / Sync), FM, Env FM — у каждого свой таймер, таблица и длина 1..16; детюн в полутонах и сырой; ШИМ 16 ступеней 0..50 %; свип 256 фаз, форма — таблицей |
| Таблицы FX | 256 × 16 значений |

### Диск и файлы

| | |
|---|---|
| Каталог | SD-карта (FAT32), длинные имена, до 640 файлов |
| Загрузка | FT2, PT3 (TurboSound), PT2, FTC; отчёт, что не влезло |
| Сохранение | FT2 — свой блочный формат с CRC-16 ([описание](doc/formats/ft2.md)) |
| Экспорт | PSG (регистры чипа 1 по кадрам) |
| Check | сравнение файла FT2 с треком в памяти |
| Compare | импортированный модуль играют наш и оригинальный плеер, показаны кадры с расхождением |

### Интерфейс

| | |
|---|---|
| Экран | текст 90×36, весь интерфейс перерисовывается каждый кадр (50 кадров/с) |
| Мышь | Kempston с колесом: точность 16.8, дробная скорость, кубическая акселерация 0..8 |
| Клавиатура | PS/2 (PC), сочетания Ctrl / Alt / Shift |
| Правка | выделение, буфер обмена, транспонирование, отмена / повтор |
| Темы | 6 цветовых тем; настройки в `\FT2\FT2.INI` — только кнопкой Save |
| Help | клавиши и команды паттерна, строится из настоящих биндов |

### Что нужно и установка

- ZX Evolution с TS-Config (а также Unreal Speccy, Xpeccy); SD-карта FAT32 (Z-Controller); клавиатура PS/2; мышь Kempston с колесом.
- AY / YM; 6 каналов — TurboSound (`#FF` / `#FE`). По желанию — карта **ZX Trinity** для FX (без неё FX молчат).
- Папку `FT2` — в корень SD-карты, запуск `\FT2\FT2B.SPG`. `load=` в `FT2.INI` — трек, который грузится при старте.

### Главные клавиши

| Клавиша | Действие |
|---|---|
| F5 / F6 | песня с позиции / с начала |
| F7 / F8 | паттерн со строки / паттерн по кругу |
| Esc | стоп; во вкладках — назад к паттерну |
| Z..M, Q..P | ноты (Shift — октавой выше); A — выкл, K — стереть |
| Insert / Backspace | вставить / удалить строку трека (Ctrl+I / Ctrl+Y — строку паттерна) |
| Shift + стрелки / клик | выделение; Ctrl+A — всё; Ctrl+C X V — копировать, вырезать, вставить |
| Num + / - | транспонирование (с Ctrl — на октаву) |
| Ctrl+Z / Ctrl+Shift+Z | отмена / повтор |
| Ctrl+E / Alt+E | колонка огибающей / огибающая нотой |
| Мышь | клик — курсор и кнопки, колесо — строки (Ctrl / Shift — каналы), правая кнопка — меню |

Полный список — вкладка Help и `README.TXT`.

### Ещё не сделано

Библиотека инструментов на диске; экспорт в PT3; импорт STC, ASC, SQT, PSC, PT1, GTR, текста Vortex Tracker; команды колонки огибающей (портаменто, вибрато, арпеджио, вкл / выкл, детюн, автоогибающая); команды FX E1..E5 в паттерне; свой курсор у каждого трека.

### Авторы и лицензии

- Fast Tracker 2 — Orion/DR.
- Спасибо **Pator**, автору **Bitphase**: интерфейс, команды паттерна, колонка огибающей и таймерные эффекты (FX) во многом взяты из него.
- FAT32-драйвер — [andrewinsidelazarev/FAT32-Driver-ZX-Evolution](https://github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution) (MIT).
- Шрифты Toshiba TxL1 / TxL2, Compaq Thin — The Ultimate Oldschool PC Font Pack, int10h.org (CC BY-SA 4.0).

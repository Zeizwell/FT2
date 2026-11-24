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

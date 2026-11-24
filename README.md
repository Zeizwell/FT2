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

### Technical info

```
Tracks in memory:                                                2
Channels:                                      3 or 6 (TurboSound)
Stereo:                                        ABC ACB BAC BCA CAB
Patterns:                                                       64
Rows per pattern:                                          1 to 64
Positions:                                                     256
Speed:                                                    1 to 255
Instruments:                                                    32
Max instrument length:                                         100
Ornaments:                                                      32
Max ornament length:                                           100
FX (ZX Trinity):                                                32
Max FX length:                                                  32
FX tables:                                                256 x 16
Note tables:                                     1.75 / 1.7734 MHz
Envelope mode:                                      FT 1.15 / PT 3
Name / author:                                       32 + 32 chars
Compiled track:                                        up to 32768
```

### Pattern field

```
Channel (x6):
  Note:                                            C-1 .. B-8, off
  Instrument:                                                1..32
  Envelope shape:                                       1..14, off
  Ornament:                                            1..32, none
  Volume:                                                     0..F
  Commands:                          2 (4 hex: code, delay, param)
Chip ENV column (x2):
  Envelope period:                             16 bit or as a note
  Envelope command:                    1 (4 hex): 1 - up, 2 - down
  Noise:                                                    00..1F
```

### Channel commands

```
  1 / 2   glide down / up               delay, step
  3       portamento to note            delay, step
  4 / 5   sample / ornament from row    row
  6       sound on / off                on, off
  7       volume slide                  delay, up, down
  8       vibrato                       ticks/step, speed, depth
  9 / A   envelope slide down / up      delay, step
  B       speed                         ticks per row
  C       arpeggio                      ticks/step, shift 1, shift 2
  F0      envelope and tone retrigger
  F1      detune                        period offset +/-
  F2      note delay                    ticks
```

### Instruments, ornaments, FX

```
Instrument row:
  Tone offset:                       12 bit +/-, accumulation, off
  Noise offset:                             +/-, accumulation, off
  Envelope offset:                           +/-, accumulation, on
  Volume:                                    0..F, slide up / down
  Envelope retrigger:                                          yes
  Linked FX:                                                 0..32
Ornament row:
  Note offset:                         semitones +/-, accumulation
  Noise offset:                                  +/-, accumulation
FX row (ZX Trinity):
  Mix:                             SID / Sync, own timer and table
  FM:                             tone period, own timer and table
  Env FM:                        envelope period, own timer, table
  Table length:                                        1..16 steps
  Detune:                                        semitones and raw
  PWM:                                            16 steps 0..50 %
  Sweep:                                256 phases, shape by table
```

### Disk and files

```
Storage:                                            SD card, FAT32
Long names:                                                    yes
Files in catalog:                                        up to 640
Load:                              FT2, PT3 (TurboSound), PT2, FTC
Import report:                                    what did not fit
Save:                                      FT2, blocks with CRC-16
Export:                                     PSG, chip 1, per frame
Check:                                 FT2 file vs track in memory
Compare:                         ours vs original player, by frame
```

FT2 file format: [spec](doc/formats/ft2.md)

### Interface

```
Screen:                                               text 90 x 36
Redraw:                                       whole screen, 50 fps
Mouse:                                             Kempston, wheel
Mouse precision:                                  16.8 fixed point
Mouse speed:                                            fractional
Mouse acceleration:                                    cubic, 0..8
Keyboard:                                 PS/2, Ctrl / Alt / Shift
Editing:                           selection, clipboard, transpose
Undo / redo:                                                   yes
Colour themes:                                                   6
Settings:                                    FT2.INI, by Save only
Help:                              keys, commands, from real binds
```

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

### Техническая инфа

```
Треков в памяти:                                                 2
Каналов:                                      3 или 6 (TurboSound)
Стерео:                                        ABC ACB BAC BCA CAB
Паттернов:                                                      64
Строк в паттерне:                                       от 1 до 64
Позиций:                                                       256
Скорость:                                              от 1 до 255
Инструментов:                                                   32
Максимальная длина инструмента:                                100
Орнаментов:                                                     32
Максимальная длина орнамента:                                  100
FX (ZX Trinity):                                                32
Максимальная длина FX:                                          32
Таблиц FX:                                               256 по 16
Таблицы нот:                                     1.75 / 1.7734 МГц
Огибающая:                                          FT 1.15 / PT 3
Имя / автор:                                         32 + 32 знака
Откомпилированный трек:                                   до 32768
```

### Поле паттерна

```
Канал (x6):
  Нота:                                           C-1 .. B-8, выкл
  Инструмент:                                                1..32
  Форма огибающей:                                     1..14, выкл
  Орнамент:                                   1..32, без орнамента
  Громкость:                                                  0..F
  Команд:                       2 (4 hex: код, задержка, параметр)
Колонка чипа ENV (x2):
  Период огибающей:                               16 бит или нотой
  Команда огибающей:                1 (4 hex): 1 - вверх, 2 - вниз
  Шум:                                                      00..1F
```

### Команды канала

```
  1 / 2   глисс вниз / вверх            задержка, шаг
  3       портаменто к ноте             задержка, шаг
  4 / 5   сэмпл / орнамент с позиции    строка
  6       звук вкл / выкл               вкл, выкл
  7       слайд громкости               задержка, вверх, вниз
  8       вибрато                       тиков/шаг, скорость, глубина
  9 / A   слайд огибающей вниз / вверх  задержка, шаг
  B       скорость                      тиков на строку
  C       арпеджио                      тиков/шаг, сдвиг 1, сдвиг 2
  F0      ретриггер огибающей и тона
  F1      детюн                         сдвиг периода +/-
  F2      задержка ноты                 тиков
```

### Инструменты, орнаменты, FX

```
Строка инструмента:
  Смещение тона:                      12 бит +/-, накопление, выкл
  Смещение шума:                             +/-, накопление, выкл
  Смещение огибающей:                         +/-, накопление, вкл
  Громкость:                              0..F, слайд вверх / вниз
  Ретриггер огибающей:                                        есть
  Привязка FX:                                               0..32
Строка орнамента:
  Смещение ноты:                          полутоны +/-, накопление
  Смещение шума:                                   +/-, накопление
Строка FX (ZX Trinity):
  Mix:                           SID / Sync, свой таймер и таблица
  FM:                            период тона, свой таймер, таблица
  Env FM:                        период огибающей, таймер, таблица
  Длина таблицы:                                       1..16 шагов
  Детюн:                                          полутоны и сырой
  ШИМ:                                         16 ступеней 0..50 %
  Свип:                                    256 фаз, форма таблицей
```

### Диск и файлы

```
Носитель:                                          SD-карта, FAT32
Длинные имена:                                                есть
Файлов в каталоге:                                          до 640
Загрузка:                          FT2, PT3 (TurboSound), PT2, FTC
Отчёт импорта:                                       что не влезло
Сохранение:                                    FT2, блоки с CRC-16
Экспорт:                                     PSG, чип 1, по кадрам
Check:                              файл FT2 против трека в памяти
Compare:                       наш и оригинальный плеер, по кадрам
```

Формат файла FT2: [описание](doc/formats/ft2.md)

### Интерфейс

```
Экран:                                               текст 90 x 36
Перерисовка:                               весь экран, 50 кадров/с
Мышь:                                             Kempston, колесо
Точность мыши:                           16.8, фиксированная точка
Скорость мыши:                                             дробная
Акселерация мыши:                                 кубическая, 0..8
Клавиатура:                               PS/2, Ctrl / Alt / Shift
Правка:                         выделение, буфер, транспонирование
Отмена / повтор:                                              есть
Цветовых тем:                                                    6
Настройки:                            FT2.INI, только кнопкой Save
Help:                                  клавиши, команды, из биндов
```

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

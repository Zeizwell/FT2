FAST TRACKER 2.01b - AY tracker for ZX Evolution (TS-Config)
=============================================================
English first, Russian below. README.TXT / FT2FMT.TXT - CP866 (for the Spectrum),
README_WIN.TXT / FT2FMT_WIN.TXT - UTF-8 (for Windows).

Work in progress: a lot works already, but it is not a finished tracker yet.
The successor of Fast Tracker for the ZX Spectrum. The interface is in the spirit
of Bitphase and FastTracker 2 on the PC: text mode 90x36, mouse, PC keyboard.


WHAT YOU NEED
-------------
- ZX Evolution with the TS-Config firmware (also runs in the Unreal Speccy emulator).
- SD card with FAT32 (Z-Controller / SD-ZC).
- PS/2 (PC) keyboard and a Kempston mouse.
- AY / YM; for 6 channels - TurboSound (two chips, selected by #FE / #FF).
- Optional: the ZX Trinity card - timer effects (FX: SID, Sync, FM, PWM).


INSTALL AND RUN
---------------
1. Copy the FT2 folder to the root of the SD card.
2. Run \FT2\FT2B.SPG.
3. Settings are in \FT2\FT2.INI (written only by the Save button on the Setup tab).
   load= in the INI - a track to load at start. Keep modules in a folder, e.g. \MUSIC.


SCREEN
------
Top row: Fast Tracker 2.01b, tabs Instr Orn FX, transport buttons, 3ch / 6ch and
stereo, Disk Setup, Help About. Below - the track header:
  File, Chip, Tune      - file, chip type, note table (1.75 / 1.77 MHz);
  Song, By, Track 1 2   - name, author, which of the two tracks in memory is edited;
  Speed Size Octave Step, Env as Note, Auto Env, Env FT / PT.
Stereo - ABC ACB BAC BCA CAB (as in Vortex Tracker), click - next; channels are
swapped only on output. Env FT / PT - the envelope period: FT - the channel with the
envelope leads it, PT - sample offsets of all channels add up (as PT3; PT3 modules
load with PT).
The main window is the pattern: order on the left, channels A B C (and D E F on the
second chip), the chip's Env column (envelope period, noise, envelope command).
Free memory (pages) - in Setup.

Tabs:
  Instr / Orn / FX - instruments, ornaments (Fast Tracker format) and timer effects:
                rows, length, loop, Clone / Copy / Paste / Clear / Unloop;
                note preview at the bottom.
  Disk        - the card's catalog (up to 640 files, long names), load and save.
                Compare - after loading PT3 / PT2 / FTC (up to 32K) compare the FT2
                player with the reference one. PSG - export the song (chip 1
                registers per frame) to <name>.psg. Check - an FT2 file against
                the track in memory. New, Exit WC.
  Setup       - theme (6 palettes), mouse (speed, acceleration). Applied at once,
                written to the INI only by Save.
  Help        - keys and pattern commands.


KEYS
----
Pattern:
  F5          play the song from the current position
  F6          play the song from the start
  F7          play the pattern from the current row
  F8          play the pattern in a loop
  Esc         stop
  Ctrl+E      open the chip's envelope column
  Alt+E       envelope as a note (Env as Note)
  wheel       rows; Ctrl / Shift + wheel - channels
  <- ->       cell fields;  Tab - channels;  click - cursor to the field and row
  Z..M Q..P   notes (Shift - an octave higher);  A - off;  K - erase the note
  0-9 A-F     digits into fields;  Delete - clear the field / selection
  Insert, Backspace     insert / delete a track row
  Ctrl+I, Ctrl+Y        insert / delete a pattern row
  Shift+arrows, Shift+click - selection;  Ctrl+A - all
  Ctrl+C X V  copy / cut / paste
  Num + -     transpose (with Ctrl - by an octave)
  Ctrl+Z      undo (5 steps, within a channel);  Ctrl+Shift+Z - redo
  Space       auto step;  Ctrl+0..9 - step;  Num 1..8 - octave
  Enter       play the pattern from the cursor while held

Instruments and ornaments:
  arrows, PgUp / PgDn, Home / End - cursor
  0-9 A-F     digits;  - =  sign (for the slide - down / up);  space - flag
  click on the loop bracket or the row number - loop to this row;
  click on the bar - volume; + and x on the right - insert / delete a row
  Enter       play the note of the preview row (while held)
  Tab         to the preview row: piano Z..M (octave) and Q..P (octave higher),
              the note sounds while the key is held

Mouse: click - select, buttons act on release (as in Windows).


FORMATS
-------
Load:   FT2 (own), PT3 (Pro Tracker 3 / Vortex Tracker II, including TurboSound),
        PT2 (Pro Tracker 2), FTC (Fast Tracker).
Save:   FT2.  Export: PSG (AY registers per frame).
If something did not fit the limits, a message after loading says what.
FT2 file format - FT2FMT.TXT.


LIMITS
------
Patterns 64, rows per pattern 64, positions 256, instruments 32 (up to 64 rows),
ornaments 16, FX 32, two tracks in memory, 1 or 2 chips (3 / 6 channels).


NOT YET
-------
- an instrument library on the disk;
- saving to PT3 and loading other formats (STC, ASC, SQT, PSC, PT1, GTR, VT).


AUTHORS AND LICENSES
--------------------
Fast Tracker 2 - Orion/DR.
Big thanks to Pator - the author of Bitphase. A great deal of FT2 is taken from it:
the interface, the pattern commands, the envelope column, the timer effects (FX),
the instrument model. Bitphase is the reference we check our player against.
FAT32 driver - github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution (MIT).
Fonts Toshiba TxL1 / TxL2, Compaq Thin - The Ultimate Oldschool PC Font Pack,
int10h.org (CC BY-SA 4.0).
Sources: github.com/Zeizwell/FT2


=============================================================
РУССКИЙ
=============================================================

FAST TRACKER 2.01b - AY-трекер для ZX Evolution (TS-Config)

Рабочая сборка (work in progress). Многое уже работает, но это ещё не готовый
трекер. Наследник Fast Tracker для ZX Spectrum. Интерфейс - в духе Bitphase и
FastTracker 2 на ПК: текстовый режим 90x36, мышь, клавиатура PC.


ЧТО НУЖНО
---------
- ZX Evolution с прошивкой TS-Config (проверяется и в эмуляторе Unreal Speccy).
- SD-карта с FAT32 (контроллер Z-Controller / SD-ZC).
- Клавиатура PS/2 (PC) и мышь (Kempston).
- AY / YM; для 6 каналов - TurboSound (два чипа, выбор #FE / #FF).
- По желанию: карта ZX Trinity - таймерные эффекты (FX: SID, Sync, FM, ШИМ).


УСТАНОВКА И ЗАПУСК
------------------
1. Скопировать папку FT2 в корень SD-карты.
2. Запустить \FT2\FT2B.SPG.
3. Настройки лежат в \FT2\FT2.INI (пишутся только кнопкой Save во вкладке Setup).
   load= в INI - трек, который грузится при старте. Модули удобно держать в своей
   папке, например \MUSIC.


ЭКРАН
-----
Верхняя строка: Fast Tracker 2.01b, вкладки Instr Orn FX, кнопки транспорта,
3ch / 6ch и стерео, Disk Setup, Help About. Ниже - шапка трека:
  File, Chip, Tune      - файл, тип чипа, таблица нот (1.75 / 1.77 МГц);
  Song, By, Track 1 2   - имя, автор, какой из двух треков в памяти правим;
  Speed Size Octave Step, Env as Note, Auto Env, Env FT / PT.
Стерео - ABC ACB BAC BCA CAB (как в Vortex Tracker), клик - следующее; каналы
переставляются только на выходе. Env FT / PT - период огибающей: FT - его ведёт
канал с огибающей, PT - смещения сэмплов всех каналов складываются (как PT3;
PT3-модули грузятся с PT).
Основное окно - паттерн: ордер слева, каналы A B C (и D E F на втором чипе),
колонка Env чипа (период огибающей, шум, команда огибающей).
Свободная память (страницы) - в Setup.

Вкладки:
  Instr / Orn / FX - инструменты, орнаменты (формат Fast Tracker) и таймерные
                эффекты: строки, длина, цикл, Clone / Copy / Paste / Clear /
                Unloop; внизу проба ноты.
  Disk        - каталог карты (до 640 файлов, длинные имена), загрузка и
                сохранение. Compare - после загрузки PT3 / PT2 / FTC (до 32К)
                сравнить плеер FT2 с эталонным. PSG - экспорт трека (регистры
                чипа 1 по кадрам) в <имя>.psg. Check - файл FT2 против трека в
                памяти. New, Exit WC.
  Setup       - тема (6 палитр), мышь (скорость, ускорение). Меняется сразу,
                в INI пишется только кнопкой Save.
  Help        - клавиши и команды паттерна.


КЛАВИШИ
-------
Паттерн:
  F5          играть сонг с текущей позиции
  F6          играть сонг с начала
  F7          играть паттерн с текущей строки
  F8          играть паттерн по кругу
  Esc         стоп
  Ctrl+E      открыть колонку огибающей чипа
  Alt+E       огибающая нотой (Env as Note)
  колесо      строки; Ctrl / Shift + колесо - каналы
  <- ->       поля клетки;  Tab - каналы;  клик - курсор в поле и роу
  Z..M Q..P   ноты (Shift - октавой выше);  A - off;  K - стереть ноту
  0-9 A-F     цифры в поля;  Delete - очистить поле / выделение
  Insert, Backspace     вставить / удалить строку трека
  Ctrl+I, Ctrl+Y        вставить / удалить строку паттерна
  Shift+стрелки, Shift+клик - выделение;  Ctrl+A - всё
  Ctrl+C X V  копировать / вырезать / вставить
  Num + -     транспонировать (с Ctrl - на октаву)
  Ctrl+Z      отмена (5 шагов, в пределах канала);  Ctrl+Shift+Z - повтор
  Space       автошаг;  Ctrl+0..9 - шаг;  Num 1..8 - октава
  Enter       играть паттерн с курсора, пока держишь

Инструменты и орнаменты:
  стрелки, PgUp / PgDn, Home / End - курсор
  0-9 A-F     цифры;  - =  знак (у слайда - вниз / вверх);  пробел - флаг
  клик по скобке цикла или номеру строки - цикл на эту строку;
  клик по полосе - громкость; + и x справа - вставить / удалить строку
  Enter       сыграть ноту из строки пробы (пока держишь)
  Tab         в строку пробы: пианино Z..M (октава) и Q..P (октава выше),
              нота звучит, пока держишь клавишу

Мышь: клик - выбрать, кнопки срабатывают при отпускании (как в Windows).


ФОРМАТЫ
-------
Загрузка:   FT2 (свой), PT3 (Pro Tracker 3 / Vortex Tracker II, включая
            TurboSound), PT2 (Pro Tracker 2), FTC (Fast Tracker).
Сохранение: FT2.  Экспорт: PSG (регистры AY по кадрам).
Если что-то не влезло в лимиты, после загрузки будет сообщение, что именно.
Формат файла FT2 - FT2FMT.TXT.


ЛИМИТЫ
------
Паттернов 64, строк в паттерне 64, позиций 256, инструментов 32 (строк до 64),
орнаментов 16, FX 32, два трека в памяти, 1 или 2 чипа (3 / 6 каналов).


ЧЕГО ПОКА НЕТ
-------------
- библиотеки инструментов на диске;
- сохранения в PT3 и загрузки других форматов (STC, ASC, SQT, PSC, PT1, GTR, VT).


АВТОРЫ И ЛИЦЕНЗИИ
-----------------
Fast Tracker 2 - Orion/DR.
Огромное спасибо Pator, автору Bitphase. Очень многое в FT2 взято из него:
интерфейс, команды паттерна, колонка огибающей, таймерные эффекты (FX), модель
инструментов. По Bitphase мы сверяем свой плеер.
FAT32-драйвер - github.com/andrewinsidelazarev/FAT32-Driver-ZX-Evolution (MIT).
Шрифты Toshiba TxL1 / TxL2, Compaq Thin - The Ultimate Oldschool PC Font Pack,
int10h.org (CC BY-SA 4.0).
Исходники: github.com/Zeizwell/FT2

# ZX Trinity: найденные материалы — где лежат и что в них

Указатель (2026-10-18). **Сначала смотреть сюда, а не искать заново в интернете.** Пути — от `D:\_Work\Speccy\`.
Материалы пользователя в git не добавлены (лежат в папке проекта, ждут его решения).

## Звук Paula / Amiga — `FT2/Paula/` (разбор — `doc/paula.md`)

| Что | Где | Зачем нам | Лицензия |
|---|---|---|---|
| Paula на Verilog (весь чип: DMA, период, ШИМ-громкость, attach) | `FT2/Paula/paula.v`, `FT2/Paula/amiga_replacement_project-master/paula/Paula.v`, `Better_Audio.v` | как устроен звук в железе | CC BY-NC (только справочник) |
| **Эмуляция Paula pt2-clone** (BLEP + фильтры A500 / A1200 / LED, номиналы RC) | `FT2/Paula/pt2-clone-master/src/pt2_paula.c`, `pt2_blep.c`, `pt2_rcfilters.c` | **берём в прошивку** (~660 строк) | BSD-3 |
| **pocketmod** — MOD-плеер одним файлом, без зависимостей | `FT2/Paula/pocketmod-master/pocketmod.h` | **берём**: разбор MOD, команды ProTracker; его микшер заменить на Paula из pt2 | MIT |
| WinUAE `audio.cpp` (sinc-очередь, модели фильтров) | `FT2/Paula/WinUAE-master/audio.cpp` | справочник | GPL |
| MilkyTracker `ResamplerAmiga.h` (BLEP) | `FT2/Paula/MilkyTracker-master/src/milkyplay/` | справочник | GPL |
| Заметка «как правильно ресемплить Amiga» (метод BLEP, A. Lankila) | `FT2/Paula/milkytracker.txt` | теория | — |
| **PicoGUS** — GUS / SB / OPL на RP2040: шина ISA через PIO, I2S (`pico_audio_i2s`), PSRAM, 32 голоса | `FT2/Paula/picogus-main/sw/` | образец: звук + шина + PSRAM на RP | GPL (справочник) |
| Заметка о ЦАП (PCM5102A / PCM5122 / ES9023) | `FT2/Paula/ДАКИ.txt`, `adafruit-pcm5122-i2s-dac.pdf` | выбор ЦАП (решено: PCM5102A) | — |

## General Sound / NeoGS

| Что | Где | Ключевое |
|---|---|---|
| **Руководство программиста GS** v1.04 + правки ROM 1.05a (30 стр.) | `FT2/pentevo/docs/GS/gs_prog.pdf` | порты `#BB` (команда / статус: бит 7 данные, бит 0 команда), `#B3` (данные / вывод); все команды `#00..#FA` (модули `#30..#33`, FX `#38..#49`, позиция `#60..#64`, память `#14 / #15 / #17`); версия — **Peek `#17`: ПЗУ `#0004` BCD, `#0100` копирайты 3×24, `#0080` патч**; `#6A` / `#6B` (1.05a) |
| PiCard3 — карта на Pico: **настоящее ПЗУ GS 1.05b в эмуляторе Z80**, TurboSound, I2S, PS/2 | `FT2/schemes/PiCard3/src/GS/` (`GS.cpp`, `gs105b.rom.h`), `src/PIO`, `src/i2s` | образец интерфейса GS на шине Спектрума через PIO |
| PiCard3 — **шина без CPLD** (разбор 2026-10-19, схемы в проекте нет — только прошивка) | `FT2/schemes/PiCard3/config.h`, `src/PIO/pio_data_z80_bus.cpp`, цикл в `PiCard3.ino` (~стр. 436) | RP2350 (PGA2350), **разгон 351 МГц при 1.60 В**. A0..A15 — GP8..23, M1 / WR / RD / IORQ / MREQ — GP3..7: **прямо в RP** (входы терпят 5 В). Данные D0..D7 — GP24..31 **через один 74…245**: OE / направление — side-set PIO на GP2 (PIO выдаёт байт, пока /RD внизу). Дешифрация портов — **ядро опрашивает `gpio_get_all()` в цикле** (не PIO), WAIT нет, IORQGE нет. ROMCS — GP1 (`PIN_ROM_BLK`), NMI — GP35 (открытый сток сменой направления). Итого: без CPLD и без шифтеров на входах, но буфер на данных есть. **Модуль:** схемы платы в проекте нет, но сборка — под `pimoroni_pga2350` (PiCard3; ранний PiCard — `pimoroni_pico_plus_2`), ножки до GP47 — значит **PGA2350** (RP2350B, 16 МБ флеш + 8 МБ PSRAM, выводы сеткой 2.54 — впаивается в отверстия платы или в панельку) |
| NeoGS rev C-VS — схема и плата (sch, pcb, гербера, BOM, PDF) | `FT2/schemes/Neogs/revC-VS.r191/` | разбор в `doc/zx-trinity.md` |
| **Исходники NeoGS целиком** (git-зеркало SVN nedopc: github.com/alfishe/neogs, скачано 2026-10-18) | `ref-neogs/neogs/` | `z80/main_rom/main_ngs.a80` — ПЗУ NeoGS (GS-совместимое, v1.11 от 07.02.2026), `z80/gs105a_fix` — исходник ПЗУ GS 1.05a, `fpga/current/sound` (ЦАП, `sound_mulacc.v`), `fpga/current/zxbus/zxbus.v` — шина, `cpld/`, `docs/NGS_prm/ngspgm_01a.pdf` — **руководство программиста NeoGS** (порты GSCTR / GSCOM / GSDAT, 8 каналов, MP3, SD, память 2 МБ), `docs/_old_gs/GS104SRC` — исходник ПЗУ GS 1.04 |
| Опознание NeoGS (из `main_ngs.a80`) | — | **то же, что у GS**: ПЗУ `#0004` — `DW` версия BCD (`#0111` = 1.11), `#0080` — строка патча, `#0100` — 3 строки по 24 («General Sound (tm) ROM», «Copyright 1997 Stinger», «Version 1.11»). Наш движок кладёт туда своё |

Текст PDF (`gs_prog.pdf`, `ngspgm_01a.pdf`) вытаскивается `python` + `pypdf` (поставлен 2026-10-18).

## Диск / драйверы устройств

| Что | Где | Ключевое |
|---|---|---|
| tslabs/zx-evo целиком (разреженный клон, только дерево) | `ref-zxevo/zx-evo/` | `pentevo/soft/WC/source/core32/drivers/SD_NGS.ASM`, ПЗУ `pentevo/unreal/Unreal/cfg/rom/gs105a.rom`; файлы берутся `git checkout` по пути |
| Наш FAT32 (из WC Improved): ядро без железа, устройство — таблица `init / read512 / write512 / sync` | `FT2/drivers/fat32/` (README) | порт сейчас один: `ports/sdzc.asm` (SD Z-Controller, номер карты 0 / 1 = SD / SD2) |
| **Исходники Wild Commander Improved** (скачаны 2026-10-18) | `ref-wc/Wild-Commander-Improved/source/` | драйверы устройств: `DIDENEMO.ASM` (IDE Nemo), `DIDESMUC.ASM` (IDE SMUC), `DSDZC.ASM` (SD ZC), `DSDNGS.ASM` (SD NeoGS); список «Select Device» — `WCVLS.ASM` (`THDD`) |

## AY / Atari / прочее

| Что | Где |
|---|---|
| SNDH-плеер (AtariAudio, MIT) | разбор `doc/trinity-sndh.md`, исходник — `D:\Data\Speccy\Atari\SndhArchivePlayer` (копия — в Trinity, см. там) |
| AYX-32 (STM32, прошивки, KiCad) | `FT2/schemes/AYX-32/` |
| ZX Evolution rev D+ | `FT2/schemes/rev_d+.r1368/`, разбор `doc/evo-rev-d.md` |
| MultiSound, схемы карт | `FT2/schemes/`, разбор `doc/zx-trinity.md` |
| Карта портов AY (кто какие номера занял) | `doc/ay-ports-map.md` |
| Verilog TS-Config, доки Evo | `FT2/pentevo/` (`fpga/current`, `docs/`) |

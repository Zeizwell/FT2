# Bitphase: проект `.btp` и экспорт (PSG, TAYM, SNDH, VGM, NSF, WAV)

Разобрано 2026-10-20 по исходникам `paator/bitphase` (GitHub): `docs/import-export.md`, `cli/btp-loader.ts`,
`src/lib/models/project.ts`, `song.ts`, `services/file/project/file-import.ts` / `file-export.ts`,
`services/file/taym/taym-spec.ts`; ключи JSON проверены на демо-проектах `src/demo/*.btp`. Интерфейс Bitphase —
`doc/bitphase.md`, таймерные эффекты физически — `doc/bitphase-fx.md`.

## 1. `.btp` = JSON, сжатый gzip

`JSON.stringify(project)` -> gzip (`CompressionStream('gzip')`); чтение — `gunzip` -> `JSON.parse`. Свой формат
целиком, без заголовка и версии в файле (старое приводится при загрузке: `migrateLegacyInstrument`).

### Проект (верх)

| Ключ | Что |
|---|---|
| `name`, `author` | название, автор |
| `songs[]` | песни; песня = один чип (AY или NES), TurboSound = 2 песни AY |
| `patternOrder[]` | ордер: номера паттернов (общий на все песни) |
| `loopPointId` | позиция петли в ордере |
| `patternOrderColors{}` | цвет позиции ордера (интерфейс) |
| `tables[]` | таблицы: `{id, rows[], loop, name, additive}` — арпеджио / таймерные волны |
| `instruments[]` | инструменты (общие) |
| `initialSpeed`, `tempo` | скорость 1..255 (по умолчанию 3), темп 0..255 |

### Песня `songs[]`

`chipType` (`ay`), `chipVariant` (`AY` / `YM`), `chipFrequency` (1750000), `interruptFrequency` (50), `tuningTable[96]`,
`tuningTableIndex`, `a4TuningHz`, `initialSpeed`, `defaultPatternLength` (64, до 256), `stereoLayout` (`mono` / ABC...),
`stMixing`, `virtualChannelMap{}` (виртуальные каналы), `schema{}` (описание колонок для интерфейса — читать не нужно),
`patterns[]`.

### Паттерн `patterns[]`

`id`, `length`, `channels[]` (у AY — 3 + служебные), `patternRows[]` — общая колонка паттерна:
`envelopeValue` (период огибающей, 4 hex), `noiseValue` (шум, 2 hex), `envelopeEffect` (эффект огибающей или `null`).

Канал: `label`, `effectColumnCount`, `rows[]`. Строка канала:

| Ключ | Что |
|---|---|
| `note` | `{name, octave}`: `name` 0 — пусто, 1 — Off, 2..13 — C..B, 14 — Release |
| `instrument` | номер, 0 — нет |
| `envelopeShape` | форма огибающей 0..F (0 — нет) |
| `table` | **0 — пусто (не менять), −1 — выключить, k — таблица `id` k−1** (проверено на `atarized.btp`: значения 2..9 при таблицах 0..8) |
| `volume` | громкость 0..F (0 — нет) |
| `effects[]` | `{effect, delay, parameter[, tableIndex]}` или `null` |

Коды эффектов (`EffectType`): 1 — слайд вверх, 2 — слайд вниз, 4 — позиция сэмпла, 5 — позиция орнамента,
6 — вкл / выкл, 7 — задержка ноты, 8 — слайд громкости, `'A'` — арпеджио, `'P'` — портаменто, `'S'` — скорость,
`'Q'` — конец песни, `'V'` — вибрато, `'D'` — детюн, `'E'` — особое чипа.

**Замечено на `atarized.btp` (2026-10-25):** номер паттерна бывает дважды (`id` 0 у двух паттернов) — Bitphase
берёт первый; в общей колонке паттерна `envelopeEffect` бывает объектом (эффект огибающей); код эффекта `0` встречается.
«Таблицы» (`tables[]`) — это **орнаменты** (сдвиги нот, `additive` — накоплением), не таблицы таймера.

### Инструмент `instruments[]`

`id` (строка `"01"`), `name`, `chipType`, `loop`. Два поколения:
- **старое** (в демо): `rows[]` — строка: `tone`, `noise`, `envelope`, `retriggerEnvelope`, `toneAdd`, `noiseAdd`,
  `envelopeAdd`, `volume`, `loop`, `amplitudeSliding`, `amplitudeSlideUp`, `toneAccumulation`, `noiseAccumulation`,
  `envelopeAccumulation` (как PT3 / VT);
- **новое**: `macros{}` — `{values[], loop, release?}` по полям (и `timerMacros`); старое при загрузке переводится.

Таймерные эффекты (`doc/bitphase-fx.md`): `timerRows[]` — `sid`, `syncbuzzer`, `fm`, `envFm`, `sidPeriodMode`,
`fmOffsetMode` (`semitone` ...), `semitone`, `detune`, `timerWaveform[]` + `timerWaveformLoop`, `fmWaveform[]` +
`fmWaveformLoop`, `envFmWaveform[]` + `envFmWaveformLoop`; на инструмент: `timerLoop`, `timerPwmDuty`,
`timerPwmSweep`, `timerPwmSweepMin`, `timerPwmSweepShape` (`triangle` ...), `timerPwmSweepStartPhase`,
`timerPwmPreserveOnNewNote`.

## 2. Экспорт (меню File -> Export)

| Формат | Что это | Когда есть | Нам |
|---|---|---|---|
| **WAV** | звук; 22–96 кГц, 16 / 24 / float, повторы, каналы отдельно (ZIP) | всегда | слушать эталон |
| **PSG** | дамп регистров AY по кадрам | одна песня AY (несколько — ZIP по чипу) | плеер PSG на RP-AY / Спектруме — просто |
| **TAYM** | дамп регистров + **описание таймеров**, что переписывают регистры между кадрами (SID, sync-buzzer, digi) — формат `ruguevara/taym` | одна песня AY (несколько — ZIP) | **ближе всего к Trinity AY FX**: таймеры -> наши пакеты FX |
| **SNDH** | плеер для Atari ST: PSG-дамп + заголовок (таймер 50 Гц) | одна песня AY | режим ATARI на RP-AY (`doc/trinity-sndh.md`) |
| **VGM** | дамп для VGM-плееров, AY и NES (до 2 каждого), таймерные эффекты AY записаны | AY / NES | справочно |
| **NSF** | для NES-плееров (AY -> Sunsoft 5B) | AY / NES | нет |

TAYM (`taym-spec.ts`): магия `TAYM`, версия 1, заголовок 16 байт, дальше чанки по 8 байт заголовка с тегами
`TRAK`, `INFO`, `CHIP`, `TIMR`, `MODS`, `ACTN`, `LANE`, `TLAN`, `VU08` / `VU16` / `VU32`; команды таймера
Start / Modulate / Stop; числа с фиксированной точкой 16.16. Полная спецификация — у `ruguevara/taym`, разобрать, когда
дойдём до импорта.

## 3. Что это значит для нас (идеи, не решено)

- **Конвертер `.btp -> .ft2` — есть (2026-10-25):** `Trinity/engine/btp/` (C, потоком: uzlib + свой разбор JSON,
  вход читается дважды), утилита ПК `Trinity/tools/btp2ft2` (`btp2ft2 вход.btp выход.ft2`, лог потерь в консоль).
  Сделано: ордер, паттерны (куски по 64 роу), ноты, громкость, огибающая, шум, орнаменты, инструменты (макросы -> строки),
  команды (`doc/commands.md`). Нет пока: таймерные эффекты (FX), TurboSound (2 песни), команды `E` / с таблицей,
  эффекты огибающей общей колонки, инструменты старого формата (`rows[]`).
- **Импорт `.btp` в FT2** — на Спектруме gzip + JSON тяжело; проще конвертер на ПК `.btp` -> `.ft2` (как `btp-to-psg`
  у них в `cli/`).
- **Конвертер внутри карты** (решено 2026-10-25, `doc/zx-trinity.md` п.14в): Ева отдаёт `.btp` в карту, **RP-AY**
  (сервис на ядре 0 — AY-фичи в RP-AY, GS-фичи в RP-GS, не смешивать) распаковывает gzip + JSON **потоком** (окно 32К,
  целиком не разворачивать) и отдаёт готовый `.ft2` потоком — без ПК. Код конвертера — C, один и тот же для ПК (тест на
  хосте) и RP.
  Обмен — только через SDK. Что не влезает в лимиты FT2 — режется, карта отдаёт список обрезанного.
- **TAYM -> Trinity AY FX**: таймеры TAYM описывают ровно то, что делает наша карта (SID, Sync, FM) — путь проигрывать
  треки Bitphase на железе с эффектами.
- **SNDH** из Bitphase — готовый материал для режима ATARI на RP-AY.

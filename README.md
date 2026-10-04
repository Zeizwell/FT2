# FT2

Программа для ZX Evolution (TS-Config), написанная на ассемблере Z80.
Собирается в файл `ft2.spg` и запускается в эмуляторе Unreal Speccy.

## Структура

| Папка / файл | Что там |
|---|---|
| `srs/` | исходники программы (`main.asm` — точка входа), шрифты, `spg.ini` |
| `includes/` | общие определения, в том числе порты TS-Config (`tsconfig.asm`) |
| `demos/` | примеры и демо |
| `build.bat` | сборка и запуск в эмуляторе |
| `sjasmplus.exe`, `spgbld.exe`, `robimg.exe` | утилиты, которые использует `build.bat` |

Папки `tools/` (эмуляторы, образ диска `wc.img`) и `pentevo/` в репозиторий
не входят — они слишком большие и лежат только локально.

## Сборка

Запустите `build.bat` из корня проекта или задачу сборки в VS Code
(Terminal → Run Build Task; у автора она назначена на F5 в личных настройках).
Скрипт:

1. закрывает запущенный Unreal;
2. компилирует `srs/main.asm` через sjasmplus (листинг — в `main.lst`);
3. собирает `srs/ft2.spg` через spgbld по `srs/spg.ini`;
4. копирует `ft2.spg` в образ диска `tools/unreal/wc.img` через robimg;
5. запускает эмулятор `tools/unreal/Unreal.exe`.

Для шагов 4–5 и для файлов отладки (`tools/unreal/ft.l`, `tools/unreal/bpx.ini`),
которые пишет `main.asm`, нужна локальная папка `tools/unreal`.

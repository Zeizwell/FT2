@echo off


@echo off
set WorkDir=srs

:: 1. Автоматически закрываем старый Unreal, чтобы снять все блокировки
taskkill /f /im Unreal.exe >nul 2>&1

:: 2. Компиляция и сборка spg
:: FAT32 driver (drivers/fat32): code and SD-ZC port, before the main build
pushd drivers\fat32
if not exist build mkdir build
sjasmplus.exe --nologo --inc=src --inc=include src\main.asm
sjasmplus.exe --nologo --inc=src --inc=include ports\sdzc.asm
popd
sjasmplus.exe %WorkDir%\main.asm --lst=main.lst
:: 3. Каталог программы FT2: запускаемый ft2b.spg и настройки ft2.ini (по умолчанию -
::    srs\ft2.ini; трекер сохраняет свои в \FT2\FT2.INI, сборка их перезаписывает)
if not exist FT2 mkdir FT2
spgbld.exe -b %WorkDir%\spg.ini FT2\ft2b.spg
copy /Y %WorkDir%\ft2.ini FT2\ft2.ini >nul
copy /Y dist\README.TXT FT2\README.TXT >nul
copy /Y dist\FT2FMT.TXT FT2\FT2FMT.TXT >nul
copy /Y dist\README_WIN.TXT FT2\README_WIN.TXT >nul
copy /Y dist\FT2FMT_WIN.TXT FT2\FT2FMT_WIN.TXT >nul

:: 4. Запись СТРОГО в тот образ, который РЕАЛЬНО открывает твой эмулятор
set IName="d:\_Work\Speccy\FT2\tools\unreal\wc.img"
robimg.exe -p=%IName% -C="FT2",\FT2
:: test modules - into \MUSIC (overwritten each build, nothing deleted)
robimg.exe -p=%IName% -C="Modules for test",\MUSIC >nul
timeout /t 2 >nul

:: 5. Переход и чистый запуск эмулятора



cd tools\unreal
start Unreal.exe

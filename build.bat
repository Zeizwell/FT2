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
spgbld.exe -b %WorkDir%\spg.ini %WorkDir%\ft2.spg

:: 3. Временная папка для копирования
mkdir TMPFT
del /s /q TMPFT\*.* >nul
xcopy /Y srs\ft2.spg TMPFT\ >nul

:: 4. Запись СТРОГО в тот образ, который РЕАЛЬНО открывает твой эмулятор
set IName="d:\_Work\Speccy\FT2\tools\unreal\wc.img"
robimg.exe -p=%IName% -C="TMPFT",\TMPFT
timeout /t 2 >nul

:: 5. Очистка временного мусора на ПК
del /s /q TMPFT\*.* >nul
rmdir /s /q "TMPFT"

:: 6. Переход и чистый запуск эмулятора



cd tools\unreal
start Unreal.exe

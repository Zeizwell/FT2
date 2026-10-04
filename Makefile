# =========================================================================
# ПУТИ К ИНСТРУМЕНТАМ (СТРОГО ПО ТВОЕЙ СТРУКТУРЕ)
# =========================================================================
SJASMPLUS := sjasmplus.exe
SPGBLD    := spgbld.exe
ROBIMG    := robimg.exe
EMULATOR  := tools/unreal/Unreal.exe
IMAGE     := tools/unreal/wc.img

MAIN_ASM  := srs/main.asm
INI_FILE  := srs/spg.ini

# Директории для сборки
TEMP_DIR  := temp_build
FINAL_SPG := ft2.spg

.PHONY: all clean build pack inject run

# Порядок выполнения: сначала чистим старое, собираем, шьем, запускаем и снова чистим
all: clean build pack inject run clean

# =========================================================================
# ЭТАПЫ СБОРКИ
# =========================================================================

# 1. Создаем чистый темп и компилируем туда сырой .bin и .lst
build:
	@echo --- Создание временного каталога и компиляция ---
	@if not exist $(TEMP_DIR) mkdir $(TEMP_DIR)
	$(SJASMPLUS) --lst=$(TEMP_DIR)/main.lst $(MAIN_ASM)

# 2. Собираем .spg утилитой spgbld внутри темп-папки
pack:
	@echo --- Упаковка в SPG контейнер ---
	$(SPGBLD) -b $(INI_FILE) $(TEMP_DIR)/$(FINAL_SPG)

# 3. Пропихиваем готовый .spg из темп-папки напрямую в корень FAT-образа wc.img
inject:
	@echo --- Импорт файла в FAT-образ wc.img ---
	$(ROBIMG) -p=$(IMAGE) -C=$(TEMP_DIR),\

# 4. Запускаем Unreal
run:
	@echo --- Запуск Unreal Evo ---
	cd tools/unreal && start Unreal.exe

# 5. Полная очистка временного мусора (СТРОГО В КОНЦЕ ФАЙЛА)
clean:
	@echo --- Очистка временных файлов сборки ---
	@if exist $(TEMP_DIR) del /s /q $(TEMP_DIR)\*.* >nul
	@if exist $(TEMP_DIR) rmdir /s /q $(TEMP_DIR)

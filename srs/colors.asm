C_BASE      equ #0F
;C_BASE_INK      equ C_BASE_INK




COLOR_TABLE
COLOR_0     equ $
            DUP 16, X
            db  X
            EDUP

;-------- Тема по умолчанию: атрибут (paper<<4 | ink) для каждой роли CLR_*
; Индексы - цвета палитры 13 (Palette_Data в video.asm). Коре копирует таблицу
; в THEME_ATTR при старте, дальше тему меняют настройки.
; Фон окна - цвет #1 (базовый тёмный фон окон), заголовки - на #7.
Theme_Default
            db #19      ; CLR_BG        фон
            db #19      ; CLR_TEXT      стальной текст
            db #17      ; CLR_TITLE     дымчато-синий - рамки
            db #1B      ; CLR_NOTE      белый - ноты
            db #1E      ; CLR_INSTR     лазурный - инструмент
            db #19      ; CLR_PARAM     стальной - параметры
            db #1D      ; CLR_CMD       зелёный - команды, кнопки
            db #18      ; CLR_EMPTY     тусклый - пустые поля
            db #19      ; CLR_ROW_NUM   номера строк
            db #1A      ; CLR_ROW_BEAT  крем - каждая 4-я строка, текущая позиция
            db #F0      ; CLR_CURSOR    курсор
            db #2B      ; CLR_SELECT    выделение
            db #3B      ; CLR_PLAY_ROW  играющая строка
            db #14      ; CLR_MUTED     заглушенный канал
            db #1C      ; CLR_ERROR     бордовый - ошибки
            db #7B      ; CLR_HEADER    белый на дымчато-синем - плашка заголовков
Theme_Default_end
    ASSERT Theme_Default_end-Theme_Default <= THEME_ROLES_MAX

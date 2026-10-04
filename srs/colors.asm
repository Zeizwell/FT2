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
; Фон - цвет #0 (ультра-тёмный), плашка заголовков - чуть светлее, #1.
Theme_Default
            db #06      ; CLR_BG        фон
            db #09      ; CLR_TEXT      стальной текст
            db #07      ; CLR_TITLE     дымчато-синий - рамки
            db #0B      ; CLR_NOTE      белый - ноты
            db #0E      ; CLR_INSTR     лазурный - инструмент
            db #09      ; CLR_PARAM     стальной - прочие параметры
            db #0D      ; CLR_CMD       зелёный - команды
            db #08      ; CLR_EMPTY     тусклый - пустые поля
            db #09      ; CLR_ROW_NUM   номера строк
            db #0A      ; CLR_ROW_BEAT  крем - каждая 4-я строка
            db #F0      ; CLR_CURSOR    курсор
            db #2B      ; CLR_SELECT    выделение
            db #3B      ; CLR_PLAY_ROW  играющая строка
            db #04      ; CLR_MUTED     заглушенный канал
            db #0C      ; CLR_ERROR     бордовый - ошибки
            db #1B      ; CLR_HEADER    белый на чуть более светлом фоне - плашка заголовков
            db #09      ; CLR_ENVSHAPE  форма огибающей
            db #09      ; CLR_ORNAMENT  орнамент
            db #09      ; CLR_VOLUME    громкость
            db #09      ; CLR_ENVPER    период огибающей
            db #09      ; CLR_NOISE     шум
            db #0D      ; CLR_BUTTON    кнопки
            db #0A      ; CLR_LOOP      маркер повтора
            db #0A      ; CLR_ORD_CUR   стрелки текущей позиции
            db #0B      ; CLR_PATNUM    номера паттернов в ордер-листе
            db #20      ; CLR_EDIT_ROW  фон #2 - выделенный фон дорожки
Theme_Default_end
    ASSERT Theme_Default_end-Theme_Default <= THEME_ROLES_MAX

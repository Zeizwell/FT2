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
            db #01      ; CLR_TITLE     рамки - еле видно (#1 на фоне #0)
            db #0B      ; CLR_NOTE      белый - ноты активного паттерна
            db #06      ; CLR_INSTR     светло-серый - инструмент
            db #09      ; CLR_PARAM     стальной - прочие параметры
            db #0A      ; CLR_CMD       кремовый - команды
            db #03      ; CLR_EMPTY     тусклый текст (соседние паттерны) - палитра фона, чуть ярче
            db #07      ; CLR_ROW_NUM   дымчато-синий - номера роу
            db #02      ; CLR_ROW_BEAT  светлый - каждая 4-я роу
            db #F0      ; CLR_CURSOR    курсор
            db #2B      ; CLR_SELECT    выделение
            db #3B      ; CLR_PLAY_ROW  играющая строка
            db #04      ; CLR_MUTED     заглушенный канал
            db #0C      ; CLR_ERROR     бордовый - ошибки
            db #02      ; CLR_HEADER    светлый на фоне - заголовки колонок
            db #02      ; CLR_ENVSHAPE  светлый лавандовый - форма огибающей
            db #02      ; CLR_ORNAMENT  светлый лавандовый - орнамент
            db #02      ; CLR_VOLUME    светлый лавандовый - громкость
            db #06      ; CLR_ENVPER    светло-серый - период огибающей
            db #06      ; CLR_NOISE     светло-серый - шум
            db #07      ; CLR_BUTTON    дымчато-синий - кнопки
            db #0A      ; CLR_LOOP      маркер повтора
            db #0A      ; CLR_ORD_CUR   стрелки текущей позиции
            db #0B      ; CLR_PATNUM    номера паттернов в ордер-листе
            db #12      ; CLR_EDIT_ROW  строка редактирования целиком: светлый #2 на фоне #1
            db #01      ; CLR_SEP       разделители - еле видно (#1 на фоне #0)
            db #04      ; CLR_SB_TRACK  графит - дорожка скроллбара
            db #09      ; CLR_SB_THUMB  стальной - ползунок
            db #1B      ; CLR_HOVER     поле под мышью: белый на фоне #1
Theme_Default_end
    ASSERT Theme_Default_end-Theme_Default <= THEME_ROLES_MAX

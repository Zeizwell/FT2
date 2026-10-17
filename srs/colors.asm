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
; Палитра синяя (как FT2 на ПК): фон #0 - тёмно-синий, плашки заголовков - #1.
Theme_Default
            db #06      ; CLR_BG        фон
            db #09      ; CLR_TEXT      стальной текст
            db #01      ; CLR_TITLE     рамки - еле видно (#1 на фоне #0)
            db #0B      ; CLR_NOTE      белый - ноты активного паттерна
            db #06      ; CLR_INSTR     светлый нейтральный - инструмент
            db #09      ; CLR_PARAM     стальной - прочие параметры
            db #0A      ; CLR_CMD       янтарный - команды
            db #04      ; CLR_EMPTY     соседние паттерны - еле видно (#4 на фоне #0)
            db #07      ; CLR_ROW_NUM   небесно-голубой - номера роу
            db #02      ; CLR_ROW_BEAT  светлый - каждая 4-я роу
            db #F0      ; CLR_CURSOR    курсор
            db #2B      ; CLR_SELECT    выделение
            db #3B      ; CLR_PLAY_ROW  играющая строка
            db #04      ; CLR_MUTED     заглушенный канал
            db #0C      ; CLR_ERROR     бордовый - ошибки
            db #02      ; CLR_HEADER    светлый на фоне - заголовки колонок
            db #02      ; CLR_ENVSHAPE  светлый голубой - форма огибающей
            db #02      ; CLR_ORNAMENT  светлый голубой - орнамент
            db #02      ; CLR_VOLUME    светлый голубой - громкость
            db #06      ; CLR_ENVPER    светло-серый - период огибающей
            db #06      ; CLR_NOISE     светло-серый - шум
            db #07      ; CLR_BUTTON    небесно-голубой - кнопки
            db #0A      ; CLR_LOOP      маркер повтора
            db #0A      ; CLR_ORD_CUR   стрелки текущей позиции
            db #0B      ; CLR_PATNUM    номера паттернов в ордер-листе
            db #12      ; CLR_EDIT_ROW  строка редактирования целиком: светлый #2 на фоне #1
            db #01      ; CLR_SEP       разделители - еле видно (#1 на фоне #0)
            db #04      ; CLR_SB_TRACK  графит - дорожка скроллбара
            db #09      ; CLR_SB_THUMB  стальной - ползунок
            db #7B      ; CLR_HOVER     поле под мышью: белый на небесно-голубом
            db #00      ; CLR_HEAD_BG   полоса заголовков паттерна: фон как у паттерна
            db #1E      ; CLR_HEAD_TEXT   заголовки колонок: светлый #E на плашке #1
            db #E1      ; CLR_TOP_VALUE   шапка: значения - #1 на светлом #E
            db #01      ; CLR_HEAD_LINE   рамки: как у паттерна (#1 на фоне #0)
            db #1B      ; CLR_HEAD_HI     заголовок в фокусе: белый на плашке #1
            db #0E      ; CLR_HEAD_BTN    кнопки [+][-] в строке заголовков: цветом заголовков #E
            db #EE      ; CLR_TOP_BG      шапка: светлый фон #E
            db #E0      ; CLR_TOP_TEXT    подписи: самый тёмный #0
            db #90      ; CLR_TOP_HI      активное (вкладка, трек, Step, Env as Note, Auto Env): фон темнее #9, буква как у подписей
            db #E0      ; CLR_TOP_BTN     кнопки [-][+]: как подписи шапки
            db #1B      ; CLR_BAR         строка 0 шапки: тёмная полоса #1, вкладки и Help / About - светлые #E
            db #1B      ; CLR_BAR_TITLE   название "Fast Tracker 2.01b" (и версия): светло-голубой #2
Theme_Default_end
    ASSERT Theme_Default_end-Theme_Default <= THEME_ROLES_MAX

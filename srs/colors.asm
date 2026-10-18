C_BASE      equ #0F
;C_BASE_INK      equ C_BASE_INK




COLOR_TABLE
COLOR_0     equ $
            DUP 16, X
            db  X
            EDUP

;-------- Тема по умолчанию: атрибут (paper<<4 | ink) для каждой роли CLR_*
; Индексы - цвета палитры 13 (тема из Pal_Data, srs/palettes.asm). Коре копирует таблицу
; в THEME_ATTR при старте, дальше тему меняют настройки.
; Палитра синяя (как FT2 на ПК): раскладка - srs/palettes.asm (0 чёрный, 1-3 тёмные темы, 4 тёмно-серый,
; 5-9 оттенки темы, A янтарь, B зелёный, C голубой, D красный, E серый, F белый).
Theme_Default
            db #0F      ; CLR_BG        фон
            db #0E      ; CLR_TEXT      стальной текст
            db #02      ; CLR_TITLE     рамки - еле видно (#1 на фоне #0)
            db #0F      ; CLR_NOTE      белый - ноты активного паттерна
            db #0F      ; CLR_INSTR     светлый нейтральный - инструмент
            db #0E      ; CLR_PARAM     стальной - прочие параметры
            db #0A      ; CLR_CMD       янтарный - команды
            db #04      ; CLR_EMPTY     соседние паттерны - еле видно (#4 на фоне #0)
            db #06      ; CLR_ROW_NUM   небесно-голубой - номера роу
            db #07      ; CLR_ROW_BEAT  светлый - каждая 4-я роу
            db #C0      ; CLR_CURSOR    курсор
            db #7F      ; CLR_SELECT    выделение
            db #3F      ; CLR_PLAY_ROW  играющая строка
            db #04      ; CLR_MUTED     заглушенный канал
            db #0D      ; CLR_ERROR     бордовый - ошибки
            db #07      ; CLR_HEADER    светлый на фоне - заголовки колонок
            db #07      ; CLR_ENVSHAPE  светлый голубой - форма огибающей
            db #07      ; CLR_ORNAMENT  светлый голубой - орнамент
            db #07      ; CLR_VOLUME    светлый голубой - громкость
            db #0F      ; CLR_ENVPER    светло-серый - период огибающей
            db #0F      ; CLR_NOISE     светло-серый - шум
            db #06      ; CLR_BUTTON    небесно-голубой - кнопки
            db #0A      ; CLR_LOOP      маркер повтора
            db #0A      ; CLR_ORD_CUR   стрелки текущей позиции
            db #0F      ; CLR_PATNUM    номера паттернов в ордер-листе
            db #27      ; CLR_EDIT_ROW  строка редактирования целиком: светлый #2 на фоне #1
            db #02      ; CLR_SEP       разделители - еле видно (#1 на фоне #0)
            db #04      ; CLR_SB_TRACK  графит - дорожка скроллбара
            db #0E      ; CLR_SB_THUMB  стальной - ползунок
            db #6F      ; CLR_HOVER     поле под мышью: белый на небесно-голубом
            db #00      ; CLR_HEAD_BG   полоса заголовков паттерна: фон как у паттерна
            db #27      ; CLR_HEAD_TEXT   заголовки колонок: светлый #E на плашке #1
            db #17      ; CLR_TOP_VALUE   шапка: значения "вдавлены" - светлый #7 на самом тёмном фоне темы #1
            db #02      ; CLR_HEAD_LINE   рамки: как у паттерна (#1 на фоне #0)
            db #2F      ; CLR_HEAD_HI     заголовок в фокусе: белый на плашке #1
            db #07      ; CLR_HEAD_BTN    кнопки [+][-] в строке заголовков: цветом заголовков #E
            db #77      ; CLR_TOP_BG      шапка: светлый фон #E
            db #70      ; CLR_TOP_TEXT    подписи: самый тёмный #0
            db #E0      ; CLR_TOP_HI      активное (вкладка, трек, Step, Env as Note, Auto Env): фон темнее #9, буква как у подписей
            db #70      ; CLR_TOP_BTN     кнопки [-][+]: как подписи шапки
            db #2F      ; CLR_BAR         строка 0 шапки: тёмная полоса #1, вкладки и Help / About - светлые #E
            db #2F      ; CLR_BAR_TITLE   название "Fast Tracker 2.01b" (и версия): светло-голубой #2
            db #0B      ; CLR_OK          "готово": зелёный #B
            db #07      ; CLR_ED_CAP      редакторы: заголовки колонок (как CLR_HEADER)
            db #06      ; CLR_ED_ROW      номера строк (как номера роу)
            db #0E      ; CLR_ED_VAL      значения (как текст)
            db #04      ; CLR_ED_OFF      выключено / не действует (как соседние паттерны)
            db #0A      ; CLR_ED_LOOP     маркер цикла (как луп)
            db #0F      ; CLR_ED_STEP     FX: шаги таймера - белый
            db #09      ; CLR_ED_TYPE     FX: тип эффекта - оттенок темы #9
            db #04      ; CLR_WIN_SHADOW  тень окна: тёмно-серый на чёрном
Theme_Default_end
    ASSERT Theme_Default_end-Theme_Default <= THEME_ROLES_MAX

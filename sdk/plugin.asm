; =========================================================================
; FT2 PLUGIN SDK  (черновик, формат ещё может меняться)
; =========================================================================
; Плагин подключает только этот файл:
;       include "plugin.asm"
;       PLUGIN_HEADER PLG_EXPORT,"PT3","Pro Tracker 3"
;   PluginMain:
;       ...
;       xor a           ; A = 0 - успех, иначе код ошибки ERR_*
;       ret
;
; Тот же файл подключает и сам трекер - это единственное описание формата.
; Только equ и макросы, кода не генерирует.

FT2_API_VERSION equ 1

; =========================================================================
; КАРТА ПАМЯТИ И ПРАВИЛА
; =========================================================================
; Окно 0 #0000-#3FFF  коре трекера. Плагину: только читать системные
;                     переменные (SV_*) и вызывать API (API_*). Сюда не писать.
;   #3C00-#3CFF       таблица переходов API (фиксированные адреса)
;   #3D00-#3DFF       системные переменные SV_* (фиксированные адреса)
;   #3E00-#3FFF       стек
; Окно 1 #4000-#7FFF  код плагина, org #4000, не переключать.
; Окна 2,3            свободны для плагина. Переключать ТОЛЬКО SETPAGE2/3 и
;                     RESTPAGE2/3, перед выходом вернуть как было.
; Можно использовать страницы: трека (SV_SONG_PAGE), паттернов/сэмплов/
;   орнаментов (через каталоги), буфера (SV_BUF_*), свои рабочие (SV_WORK_*).
;   Остальные страницы не трогать.
; Каталоги (где что лежит) пишет только коре через API_ALLOC_*.
;
; ПРЕРЫВАНИЯ. Музыка играет в IM1 всегда - и в меню, и в плагинах. Чтобы
; ничего не ломалось:
; - Прерывания включены. DI держать коротко, иначе музыка заикается.
; - Окно 0 не переключать никогда (там обработчик IM1 и стек).
; - Страницы - только SETPAGE/RESTPAGE: тень пишется раньше порта, поэтому
;   прерывание посреди макроса ничего не портит. Обработчик прерывания тоже
;   переключает только парными SETPAGE/RESTPAGE и всё возвращает.
; - DMA одна на всех и её дёргает прерывание: только через API_DMA, руками
;   регистры DMA не писать.
; - Порты AY пишет только плеер в прерывании. Плагину AY не трогать.
; - Порт #7FFD не использовать: он меняет Page3 мимо теней SV_PAGES.
; - FMAddr не включать: запись идёт и в RAM окна (в т.ч. в коре).
;   CRAM/SFILE - через DMA.

SYS_API         equ #3C00
SYS_VARS        equ #3D00

; =========================================================================
; ЗАГОЛОВОК ПЛАГИНА (#4000)
; =========================================================================
PLG_EXPORT      equ 1           ; трек -> буфер (компилятор)
PLG_IMPORT      equ 2           ; буфер -> трек (декомпилятор)
PLG_TOOL        equ 3           ; просто инструмент
PLG_DRIVER      equ 4           ; драйвер вывода под конкретное железо
                                ; (AY, AYX-32, своя плата) - !!! интерфейс НЕ РЕШЁН

    MACRO PLUGIN_HEADER type,ext,name
        org #4000
        jp PluginMain           ; #4000 вход
        db "FT2P"               ; #4003 сигнатура
        db FT2_API_VERSION      ; #4007
        db type                 ; #4008
        db ext                  ; #4009 расширение файла, 3 символа
        db name,0               ; #400C имя для меню
    ENDM

; Коды возврата в A
ERR_OK          equ 0
ERR_FORMAT      equ 1           ; не тот / битый файл
ERR_MEMORY      equ 2           ; не хватило памяти
ERR_VERSION     equ 3           ; формат новее, чем умеет плагин
ERR_TOO_BIG     equ 4           ; откомпилированный трек больше COMPILED_MAX

; Откомпилированный трек (вместе с плеером, если он встроен) - не больше 32К:
; плагин сидит в окне 1, под трек - окна 2 и 3, сплошные #8000-#FFFF.
; Буфер - две страницы подряд: SV_BUF_PAGE в окно 2, SV_BUF_PAGE+1 в окно 3.
; Плагин экспорта обязан проверить размер и вернуть ERR_TOO_BIG, а не писать больше.
; Пока окна 2,3 заняты буфером, данные трека читать, временно переключая
; окно парными SETPAGE/RESTPAGE.
COMPILED_MAX    equ 32768

; =========================================================================
; СИСТЕМНЫЕ ПЕРЕМЕННЫЕ (#3D00)
; =========================================================================
SV_API_VERSION  equ SYS_VARS+#00    ; 1  версия API ядра
SV_PAGES        equ SYS_VARS+#01    ; 4  текущие страницы окон 0..3 (тени)
SV_SONG_PAGE    equ SYS_VARS+#05    ; 1  страница трека (заголовок, ордер, каталоги)
SV_BUF_PAGE     equ SYS_VARS+#06    ; 1  первая страница буфера импорта/экспорта
SV_BUF_PAGES    equ SYS_VARS+#07    ; 1  сколько страниц в буфере
SV_BUF_LEN      equ SYS_VARS+#08    ; 3  длина данных в буфере, байт
                                    ;    импорт: заполняет трекер (файл прочитан)
                                    ;    экспорт: заполняет плагин (сколько записать)
SV_WORK_PAGE    equ SYS_VARS+#0B    ; 1  первая рабочая страница плагина
SV_WORK_PAGES   equ SYS_VARS+#0C    ; 1  сколько рабочих страниц
SV_DRAW_PAGE    equ SYS_VARS+#0D    ; 1  текстовая страница, в которую рисовать
                                    ;    (один буфер или задний из двух - решает коре)
SV_FONT         equ SYS_VARS+#0E    ; 1  номер выбранного шрифта
SV_PLAY_SONG    equ SYS_VARS+#0F    ; 1  страница трека, который играет плеер.
                                    ;    Открыто два трека сразу: можно слушать один
                                    ;    (SV_PLAY_SONG) и править другой (SV_SONG_PAGE).
SV_SONG_NUM     equ SYS_VARS+#10    ; 1  номер редактируемого трека, 0..1
SV_MOUSE_COL    equ SYS_VARS+#11    ; 1  мышь: колонка знакоместа 0..89 (обновляется каждый кадр)
SV_MOUSE_ROW    equ SYS_VARS+#12    ; 1  мышь: строка знакоместа 0..35
SV_MOUSE_BUT    equ SYS_VARS+#13    ; 1  мышь: кнопки, 0 - нажата: бит 0 левая, 1 правая, 2 средняя
                                    ; Пиксели - только для спрайта стрелки, работать - в знакоместах.
SV_FRAME_HOOK   equ SYS_VARS+#14    ; 2  адрес процедуры сборки экрана, которую IM1 вызывает
; --- ввод (ведёт IM1; читать - через Key_Get / Mouse_Btn, см. srs/input.asm)
SV_FRAMES       equ SYS_VARS+#16    ; 2  счётчик кадров (+1 в каждом IM1)
SV_KB_DELAY     equ SYS_VARS+#18    ; 1  автоповтор клавиш: задержка, кадров
SV_KB_RATE      equ SYS_VARS+#19    ; 1  автоповтор клавиш: период, кадров
SV_MS_DELAY     equ SYS_VARS+#1A    ; 1  автоповтор кнопок мыши: задержка
SV_MS_RATE      equ SYS_VARS+#1B    ; 1  автоповтор кнопок мыши: период
SV_MS_DBL       equ SYS_VARS+#1C    ; 1  двойной клик: не дольше, кадров
SV_KEY_MODS     equ SYS_VARS+#1D    ; 1  модификаторы сейчас: KM_*
SV_KEY_HEAD     equ SYS_VARS+#1E    ; 1  очередь клавиш: куда пишет IM1 (0..15)
SV_KEY_TAIL     equ SYS_VARS+#1F    ; 1  очередь клавиш: откуда читают (0..15)
SV_MS_COUNT     equ SYS_VARS+#20    ; 12 события кнопок мыши - СЧЁТЧИКИ (IM1 только
                                    ;    увеличивает): по 4 байта на кнопку (левая,
                                    ;    правая, средняя): нажатий, отпусканий,
                                    ;    повторов, двойных
SV_FIELDS       equ SYS_VARS+#2C    ; 2  список полей верхнего уровня (его ставит редактор), 0 - нет
SV_HOVER        equ SYS_VARS+#2E    ; 2  поле под мышью, 0 - нет
SV_FOCUS        equ SYS_VARS+#30    ; 2  поле в фокусе (туда идёт клавиатура), 0 - нет
SV_PRESSED      equ SYS_VARS+#32    ; 2  поле, на котором нажали левую кнопку (до отпускания)
; --- плеер (doc/player.md). Команду и её параметры пишет основной цикл, остальное -
;     только плеер (в IM1)
SV_PLAY_CMD     equ SYS_VARS+#34    ; 1  команда PC_*, плеер берёт и обнуляет
SV_PLAY_CPOS    equ SYS_VARS+#35    ; 1  команда: позиция
SV_PLAY_CROW    equ SYS_VARS+#36    ; 1  команда: роу
SV_PLAY_STATE   equ SYS_VARS+#37    ; 1  PS_*
SV_PLAY_POS     equ SYS_VARS+#38    ; 1  что играет: позиция
SV_PLAY_ROW     equ SYS_VARS+#39    ; 1  ... роу
SV_PLAY_TICK    equ SYS_VARS+#3A    ; 1  тиков до следующей роу
SV_PLAY_SPEED   equ SYS_VARS+#3B    ; 1  тиков на роу
SV_PLAYER       equ SYS_VARS+#3C    ; 1  страница плеера, 0 - нет (IM1 не зовёт)
                                    ;    (трек, который играет, - SV_PLAY_SONG выше)
SV_TOOL         equ SYS_VARS+#3D    ; 1  страница экрана (тулзы), которую коре зовёт следующей:
                                    ;    тулза ставит сюда другую и выходит - смена вкладки
SV_SONG_NEW     equ SYS_VARS+#3E    ; 1  1 - трек в его странице сменился (загрузка).
                                    ;    Вид паттерна перечитывает его при входе и обнуляет
SV_TOOL_ARG     equ SYS_VARS+#3F    ; 1  параметр для тулзы из SV_TOOL (инструменты: 0 - Instr, 1 - Orn)
OPT_LOAD        equ #FF             ;    Setup: при старте только прочитать /FT2/FT2.INI
OPT_HELP        equ 1               ;    Setup: экран Help (клавиши), 0 - настройки
PC_SONG         equ 1               ; команды: сонг с позиции CPOS, роу CROW
PC_PATTERN      equ 2               ;   паттерн позиции CPOS по кругу с роу CROW
PC_STOP         equ 3               ;   стоп и тишина
PC_PREVIEW      equ 4               ;   проба: одна нота из Prv_Row (коре), пока не PC_STOP
PS_STOP         equ 0               ; состояния
PS_SONG         equ 1
PS_PATTERN      equ 2
PS_PREVIEW      equ 3               ; играет проба (канал A первого чипа)
PLAYER_INIT     equ #4000           ; входы плеера (его страница - в окне 1, вторая - в окне 2)
PLAYER_TICK     equ #4003
SV_KEY_DOWN     equ SYS_VARS+#40    ; 32 карта нажатых: бит = код PS/2 (E0-коды +128)
SV_KEY_Q        equ SYS_VARS+#60    ; 32 очередь клавиш: 16 x [код] [флаги KM_* | KF_REPEAT]

KM_SHIFT        equ %00000001       ; модификаторы
KM_CTRL         equ %00000010
KM_ALT          equ %00000100
KF_REPEAT       equ %10000000       ; в событии: автоповтор (иначе - нажатие)

; --- Коды клавиш (PS/2 набор 2, E0-коды +#80) - одни на всех
KEY_UP          equ #75+#80
KEY_DOWN        equ #72+#80
KEY_LEFT        equ #6B+#80
KEY_RIGHT       equ #74+#80
KEY_PGUP        equ #7D+#80
KEY_PGDN        equ #7A+#80
KEY_HOME        equ #6C+#80
KEY_END         equ #69+#80
KEY_ENTER       equ #5A
KEY_BACK        equ #66
KEY_TAB         equ #0D
KEY_ESC         equ #76
KEY_SPACE       equ #29
KEY_MINUS       equ #4E             ; '-'
KEY_PLUS        equ #55             ; '=' (+ без Shift)
KEY_KP_MINUS    equ #7B
KEY_KP_PLUS     equ #79
KEY_F5          equ #03
KEY_F6          equ #0B
KEY_F7          equ #7F             ; F7 (#83) коре сводит в #7F
KEY_F8          equ #0A
KEY_E           equ #24
KEY_T           equ #2C
KEY_A           equ #1C             ; паттерн: off (как VT)
KEY_K           equ #42             ;   стереть ноту
KEY_DEL         equ #71+#80         ; Delete
KEY_INS         equ #70+#80         ; Insert
KEY_I           equ #43
KEY_Y           equ #35
KEY_Z           equ #1A
KEY_C           equ #21
KEY_X           equ #22
KEY_V           equ #2A

; --- Действия (бинды, doc/architecture.md): клавиши к ним - таблица Bind_Tab в коре
; (умолчания - как VT, doc/trackers.md), тулзы перечисляют действия, а не клавиши.
; Номера - только здесь; переназначение - правка Bind_Tab (потом - из INI)
ACT_UP          equ 1               ; навигация
ACT_DOWN        equ 2
ACT_LEFT        equ 3
ACT_RIGHT       equ 4
ACT_PGUP        equ 5
ACT_PGDN        equ 6
ACT_HOME        equ 7
ACT_END         equ 8
ACT_NEXT        equ 9               ; следующий канал (Tab)
ACT_PREV        equ 10              ; предыдущий (Shift+Tab)
ACT_ENTER       equ 11              ; открыть / играть пробу
ACT_DIR_UP      equ 12              ; диск: папка выше
ACT_PLAY_SONG   equ 13              ; F5 - сонг с текущей позиции
ACT_PLAY_START  equ 14              ; F6 - сонг с начала
ACT_PLAY_ROW    equ 15              ; F7 - паттерн по кругу с текущей роу
ACT_PLAY_PAT    equ 16              ; F8 - паттерн по кругу с начала
ACT_STOP        equ 17              ; Esc
ACT_ENV_OPEN    equ 18              ; Ctrl+E - колонка Env чипа
ACT_ENV_NOTE    equ 19              ; Alt+E - период огибающей нотой
ACT_TIMING      equ 20              ; Ctrl+T - полоса времени
ACT_CLEAR       equ 21              ; Delete - поле / выделение - пусто
ACT_AUTOSTEP    equ 22              ; Space - автошаг вкл / выкл
ACT_OCT_1       equ 23              ; Numpad 1..8 - октава ввода (23..30)
ACT_STEP_0      equ 31              ; Ctrl+0..9 - шаг (31..40)
ACT_INS_TRK     equ 41              ; Insert - вставить строку трека (Instr / Orn - строку)
ACT_INS_PAT     equ 42              ; Ctrl+I - вставить строку паттерна (Instr / Orn - строку)
ACT_DEL_TRK     equ 43              ; Backspace - удалить строку трека (Instr / Orn - строку)
ACT_DEL_PAT     equ 44              ; Ctrl+Backspace, Ctrl+Y - удалить строку паттерна
ACT_UNDO        equ 45              ; Ctrl+Z - отмена (в пределах канала)
ACT_REDO        equ 46              ; Ctrl+Shift+Z - повтор
ACT_SEL_UP      equ 47              ; Shift+стрелки, PgUp / PgDn - выделение
ACT_SEL_DOWN    equ 48
ACT_SEL_LEFT    equ 49
ACT_SEL_RIGHT   equ 50
ACT_SEL_PGUP    equ 51
ACT_SEL_PGDN    equ 52
ACT_SEL_ALL     equ 53              ; Ctrl+A
ACT_COPY        equ 54              ; Ctrl+C
ACT_CUT         equ 55              ; Ctrl+X
ACT_PASTE       equ 56              ; Ctrl+V
ACT_TR_UP       equ 57              ; Numpad + - полутон вверх
ACT_TR_DN       equ 58              ; Numpad - - вниз
ACT_TR_OCT_UP   equ 59              ; Ctrl+Numpad + - октава вверх
ACT_TR_OCT_DN   equ 60              ; Ctrl+Numpad - - вниз
MB_LEFT         equ 0               ; номер кнопки мыши (смещение в SV_MS_COUNT / 4)
MB_RIGHT        equ 1
MB_MIDDLE       equ 2
ME_PRESS        equ 0               ; смещение счётчика события у кнопки
ME_RELEASE      equ 1
ME_REPEAT       equ 2
ME_DOUBLE       equ 3

; --- ПОЛЯ (doc/architecture.md, п.2-3). Поле - прямоугольник экрана и его обработчик.
; Список полей - записи подряд, конец - байт FLD_END. Дети - такой же список.
FLD_X           equ 0               ; 1  колонка (знакоместа)
FLD_Y           equ 1               ; 1  строка
FLD_W           equ 2               ; 1  ширина
FLD_H           equ 3               ; 1  высота
FLD_FLAGS       equ 4               ; 1  FF_*
FLD_PAGE        equ 5               ; 1  страница обработчика (окно 1), 0 - коре
FLD_HANDLER     equ 6               ; 2  адрес обработчика
FLD_KIDS        equ 8               ; 2  список дочерних полей, 0 - нет
FLD_PARAM       equ 10              ; 2  что угодно для обработчика
FLD_SIZE        equ 12
FLD_END         equ #FF             ; конец списка (вместо FLD_X)
FF_FOCUS        equ %00000001       ; поле берёт фокус по нажатию (клавиатура - ему)
FF_HAND         equ %00000010       ; над полем курсор - лапка (кликабельное)

; События поля. Обработчик: A - событие, IX - поле, C - параметр:
;   EV_KEY - B код клавиши, C флаги (KM_*, KF_REPEAT); EV_WHEEL - C дельта колеса.
; Выход: CF=1 - событие съедено (для EV_KEY: дальше по контекстам не идёт).
; Портить можно всё.
EV_HOVER_IN     equ 1               ; мышь вошла в поле
EV_HOVER_OUT    equ 2               ; вышла
EV_PRESS        equ 3               ; левая нажата над полем
EV_RELEASE      equ 4               ; левая отпущена (полю, где нажимали)
EV_CLICK        equ 5               ; отпущена над тем же полем, где нажали
EV_DOUBLE       equ 6               ; двойной клик
EV_REPEAT       equ 7               ; левая держится: автоповтор (полю, где нажимали)
EV_RCLICK       equ 8               ; правая нажата над полем
EV_WHEEL        equ 9               ; колесо над полем
EV_KEY          equ 10              ; клавиша (полю в фокусе)
EV_FOCUS_IN     equ 11              ; поле получило фокус
EV_FOCUS_OUT    equ 12              ; потеряло
    ASSERT SV_KEY_Q+32 <= THEME_ATTR
                                    ;    каждый кадр (после мыши и музыки), 0 - нет.
                                    ;    Ставит активный редактор. В ней: только DMA через
                                    ;    set_ports_int и короткая запись, страницы - SETPAGE/RESTPAGE.
                                    ; #16-#7F резерв

; =========================================================================
; ЭКРАН (текстовый режим 90x36)
; =========================================================================
; Рисовать только в SV_DRAW_PAGE: строка экрана = 256 байт,
; +0..+127 коды символов, +128..+255 атрибуты. Закончил кадр - API_FRAME_DONE.
; Номер страницы брать через регистр: ld a,(SV_DRAW_PAGE) / SETPAGE3 a
SCR_COLS        equ 90
SCR_ROWS        equ 36
SCR_ATTR        equ 128             ; смещение атрибутов в строке

; --- значки интерфейса в шрифте FT2 (коды 00-1F, остальное - CP866)
; Кнопка - 2 знакоместа подряд: код и код+1 (рамка 15x7).
; У [+], [-], Unique и Clone есть нажатый вид: код+BTN_PRESSED - та же, сдвинута на точку
; вниз-вправо. Шрифт для FT2 обязан иметь их по этим кодам.
GLYPH_CHK_OFF   equ #01             ; галочка выключена
GLYPH_CHK_ON    equ #07             ; галочка включена
GLYPH_BTN_PLUS  equ #02             ; [+] раскрыть         (#02-#03, нажатая #12-#13)
GLYPH_BTN_MINUS equ #04             ; [-] свернуть         (#04-#05, нажатая #14-#15)
BTN_PRESSED     equ #10             ; код нажатой кнопки = код + BTN_PRESSED
GLYPH_BTN_UNIQUE equ #08            ; ордер: Make Unique   (#08-#09, нажатая #18-#19)
GLYPH_BTN_PLAY  equ #0A             ; ▶  плей              (#0A-#0B)
GLYPH_BTN_STOP  equ #0C             ; ■  стоп              (#0C-#0D)
GLYPH_BTN_CLONE equ #0E             ; ордер: Clone         (#0E-#0F, нажатая #1E-#1F)
GLYPH_BTN_RES1  equ #12             ; занято: нажатая [+]  (#12-#13)
GLYPH_BTN_RES2  equ #14             ; занято: нажатая [-]  (#14-#15)
GLYPH_VOL       equ #16             ; клетка полосы громкости
GLYPH_DEL       equ #17             ; ×  удалить строку     (#17)
GLYPH_BTN_RES4  equ #1C             ;                      (#1C-#1D)
GLYPH_ARROW_R   equ #10             ; ►  (CP866, не трогаем)
GLYPH_ARROW_L   equ #11             ; ◄
GLYPH_RIGHT     equ #1A             ; →
GLYPH_LEFT      equ #1B             ; ←
; #00 - конец строки, #06 - пока занят заливкой макета

; =========================================================================
; ЦВЕТА: роли -> атрибуты текстового режима (#3D80)
; =========================================================================
; Никаких конкретных цветов в коде - только роль:
;       ld a,(THEME_ATTR+CLR_NOTE)      ; paper<<4 | ink
; Что лежит в таблице (и какая палитра в CRAM) - забота настроек трекера.
; !!! список ролей предварительный, дополняется по мере появления экранов
THEME_ATTR      equ SYS_VARS+#80    ; 128 ролей по байту
THEME_ROLES_MAX equ 128

CLR_BG          equ 0               ; фон
CLR_TEXT        equ 1               ; обычный текст
CLR_TITLE       equ 2               ; заголовки, рамки
CLR_NOTE        equ 3               ; ноты
CLR_INSTR       equ 4               ; номер инструмента
CLR_PARAM       equ 5               ; огибающая/орнамент/громкость
CLR_CMD         equ 6               ; команды
CLR_EMPTY       equ 7               ; пустые поля "---"
CLR_ROW_NUM     equ 8               ; номера строк
CLR_ROW_BEAT    equ 9               ; выделенные строки (каждая N-я)
CLR_CURSOR      equ 10              ; курсор
CLR_SELECT      equ 11              ; выделение
CLR_PLAY_ROW    equ 12              ; играющая строка
CLR_MUTED       equ 13              ; заглушенный канал
CLR_ERROR       equ 14              ; сообщения об ошибке
CLR_HEADER      equ 15              ; плашка заголовков колонок
CLR_ENVSHAPE    equ 16              ; форма огибающей в канале
CLR_ORNAMENT    equ 17              ; орнамент
CLR_VOLUME      equ 18              ; громкость
CLR_ENVPER      equ 19              ; период огибающей (колонка чипа)
CLR_NOISE       equ 20              ; шум (колонка чипа)
CLR_BUTTON      equ 21              ; кнопки (N + - и т.п.)
CLR_LOOP        equ 22              ; маркер повтора в ордер-листе
CLR_ORD_CUR     equ 23              ; стрелки текущей позиции ордер-листа
CLR_PATNUM      equ 24              ; номера паттернов в ордер-листе
CLR_EDIT_ROW    equ 25              ; строка редактирования: берётся только фон (paper),
                                    ; цвета символов остаются свои
CLR_SEP         equ 26              ; внутренние разделители колонок (мягче рамки)
CLR_SB_TRACK    equ 27              ; скроллбар: дорожка
CLR_SB_THUMB    equ 28              ; скроллбар: ползунок
CLR_HOVER       equ 29              ; поле под мышью (надпись, значение, кнопка)
CLR_HEAD_BG     equ 30              ; полоса заголовков паттерна: фон
CLR_HEAD_TEXT   equ 31              ;   подписи, заголовки колонок
CLR_TOP_VALUE   equ 32              ; шапка: значения
CLR_HEAD_LINE   equ 33              ;   рамки на её фоне
CLR_HEAD_HI     equ 34              ;   выделенное: активная вкладка, заголовок в фокусе
CLR_HEAD_BTN    equ 35              ;   кнопки [-][+] на её фоне
CLR_TOP_BG      equ 36              ; шапка: фон (один на всю шапку, не как у полосы заголовков)
CLR_TOP_TEXT    equ 37              ;   подписи, вкладки
CLR_TOP_HI      equ 38              ;   выделенное: активная вкладка, выбранный трек
CLR_TOP_BTN     equ 39              ;   кнопки [-][+]
CLR_BAR         equ 40              ; строка 0 шапки: полоса, вкладки, Help, About
CLR_BAR_TITLE   equ 41              ;   название программы

; =========================================================================
; API (#3C00, по 3 байта на вход: jp ...)
; =========================================================================
; Регистры на входе/выходе указаны у каждого. Если не сказано - портят AF,BC.
API_SONG_RESET  equ SYS_API+0*3     ; очистить трек перед импортом
                                    ; API_ALLOC_*: страницу берут из общего пула (он один
                                    ; на оба открытых трека) и пишут в каталог трека
                                    ; SV_SONG_PAGE.
API_ALLOC_PAT   equ SYS_API+1*3     ; in: A - номер паттерна
                                    ; out: A - страница, L - смещение слота,
                                    ;      CY=1 - нет памяти
API_ALLOC_SMP   equ SYS_API+2*3     ; in: A - номер сэмпла, C - длина в строках
                                    ; out: A - страница, HL - адрес в окне 3, CY=1 - нет памяти
API_ALLOC_ORN   equ SYS_API+3*3     ; как API_ALLOC_SMP, для орнамента
API_PRINT       equ SYS_API+4*3     ; in: HL - строка с 0 на конце (статус-строка)
API_PROGRESS    equ SYS_API+5*3     ; in: A - 0..255 прогресс
API_DMA         equ SYS_API+6*3     ; in: HL - таблица портов (ст. байт порта, данные, ..., #FF)
                                    ; ждёт конца текущей DMA, пишет порты при DI.
                                    ; Окончания своей DMA не ждёт. Портит AF,BC,HL
API_DMA_WAIT    equ SYS_API+7*3     ; дождаться окончания DMA. Портит AF,BC
API_FRAME_DONE  equ SYS_API+8*3     ; кадр нарисован в SV_DRAW_PAGE - показать.
                                    ; После вызова SV_DRAW_PAGE может смениться,
                                    ; перечитать перед следующим рисованием.
API_SET_FONT    equ SYS_API+9*3     ; in: A - номер шрифта из банка. Портит всё, кроме IX,IY
API_APPLY_GLYPHS equ SYS_API+10*3   ; положить значки интерфейса (GLYPH_*) поверх шрифта.
                                    ; Вызывать после API_SET_FONT.

; =========================================================================
; ПЕРЕКЛЮЧЕНИЕ СТРАНИЦ
; =========================================================================
; SETPAGEn page - сохранить текущую страницу окна n на стек и включить page
; RESTPAGEn     - вернуть со стека. Парные как push/pop. Портят A, BC.
; page - число, регистр или (hl). Переменную - только через регистр:
;       ld a,(SV_SONG_PAGE)
;       SETPAGE3 a              ; НЕ SETPAGE3 (SV_SONG_PAGE) - соберётся молча, но неверно

    MACRO SETPAGE win,page
        ld b,page
        ld a,(SV_PAGES+win)
        push af
        ld a,b
        ld (SV_PAGES+win),a
        ld bc,#10AF+win*#100
        out (c),a
    ENDM

    MACRO RESTPAGE win
        pop af
        ld (SV_PAGES+win),a
        ld bc,#10AF+win*#100
        out (c),a
    ENDM

    MACRO SETPAGE2 page
        SETPAGE 2,page
    ENDM
    MACRO SETPAGE3 page
        SETPAGE 3,page
    ENDM
    MACRO RESTPAGE2
        RESTPAGE 2
    ENDM
    MACRO RESTPAGE3
        RESTPAGE 3
    ENDM

; =========================================================================
; СТРАНИЦА ТРЕКА (номер в SV_SONG_PAGE), смещения от начала страницы
; =========================================================================
SONG_HDR        equ #0000           ; заголовок, 256 байт
SH_SIGN         equ SONG_HDR+#00    ; 4  "FT2S"
SH_FORMAT       equ SONG_HDR+#04    ; 1  версия формата
SH_CHIPS        equ SONG_HDR+#05    ; 1  1 или 2 чипа
SH_SPEED        equ SONG_HDR+#06    ; 1  начальная скорость
SH_TUNING       equ SONG_HDR+#07    ; 1  таблица нот
SH_INS_PAGE     equ SONG_HDR+#08    ; 1  страница инструментов и орнаментов (doc/instruments.md)
SH_STEP         equ SONG_HDR+#09    ; 1  шаг курсора при вводе (новый трек - 4)
SH_DEVICE       equ SONG_HDR+#0A    ; 1  тип чипа: 0 AY, 1 YM, 2 AYX-32, 3 наша плата (чипов - SH_CHIPS)
SH_STEREO       equ SONG_HDR+#0B    ; 1  стерео: 0..4 - ABC ACB BAC BCA CAB (как в VT)
SH_PATTERNS     equ SONG_HDR+#0C    ; 1  число паттернов
SH_SAMPLES      equ SONG_HDR+#0D    ; 1  число сэмплов (инструментов)
SH_ORNAMENTS    equ SONG_HDR+#0E    ; 1  число орнаментов
SH_FXS          equ SONG_HDR+#0F    ; 1  число FX
SH_ENVMODE      equ SONG_HDR+#10    ; 1  огибающая: 0 FT - период ведёт канал с огибающей, 1 PT - смещения
                                    ;    сэмплов всех каналов чипа складываются (как PT3)
SH_NAME         equ SONG_HDR+#20    ; 32 имя трека
SH_AUTHOR       equ SONG_HDR+#40    ; 32 автор
SH_FILE         equ SONG_HDR+#60    ; 32 имя файла (последний Load / Save), 0 на конце
                                    ; #60-#FF резерв

ORDER_LIST      equ #0100           ; ордер-лист
ORD_LAST        equ ORDER_LIST+0    ; 1  номер последней позиции (длина = ORD_LAST+1)
ORD_LOOP        equ ORDER_LIST+1    ; 1  позиция повтора
ORD_POS         equ ORDER_LIST+2    ; 256 номеров паттернов, по байту на позицию
ORD_SIZE        equ 1
ORDER_MAX       equ 256

; --- лимиты трекера. Подобраны так, чтобы трек можно было откомпилировать
; и сыграть; длинную вещь - делить на несколько треков, а не раздувать лимиты.
PATTERNS_MAX    equ 64              ; номера 0..63
SAMPLES_MAX     equ 32              ; номера 1..32, 0 - текущий / нет
ORNAMENTS_MAX   equ 16              ; номера 1..16 и 0 - пустой (как в FT и PT3)
FXS_MAX         equ 32              ; номера 1..32, 0 - без FX

PAT_CATALOG     equ #0300           ; по номеру паттерна, 2 байта
PC_PAGE         equ 0               ; страница, 0 - паттерна нет
PC_LEN          equ 1               ; длина паттерна в роу (1..64)
PC_SIZE         equ 2

; Каталоги сэмплов, орнаментов и FX - по номеру, запись 0 не используется.
SC_PAGE         equ 0               ; страница, 0 - нет
SC_ADDR         equ 1               ; 2 адрес в странице
SC_LEN          equ 3               ; длина в строках
SC_SIZE         equ 4

SMP_CATALOG     equ PAT_CATALOG+PATTERNS_MAX*PC_SIZE
ORN_CATALOG     equ SMP_CATALOG+(SAMPLES_MAX+1)*SC_SIZE
FX_CATALOG      equ ORN_CATALOG+(ORNAMENTS_MAX+1)*SC_SIZE
                                    ; FX - отдельные объекты, инструмент хранит номер FX
                                    ; (0 - без FX, как в обычном треке), один FX может
                                    ; использоваться в нескольких инструментах.
                                    ; В паттернах FX не участвуют.
                                    ; !!! формат самих FX НЕ РЕШЁН
SONG_CAT_END    equ FX_CATALOG+(FXS_MAX+1)*SC_SIZE

; =========================================================================
; ИНСТРУМЕНТЫ И ОРНАМЕНТЫ - как в Fast Tracker (doc/formats/ftc.md, doc/instruments.md)
; =========================================================================
; Все инструменты и орнаменты трека - ОДНА страница 16К: плеер ставит её в окно
; один раз за тик. Блок = заголовок как в FTC + строки + хвост (FX, имя).
;   инструмент n (0..31 = номер 1..32): #0000 + n*INS_BLOCK
;   орнамент   n (0..15 = номер 1..16): ORN_BASE + n*ORN_BLOCK
OH_LEN          equ 0               ; 1  конец (копия OH_END: длина для редактора/декомпилятора)
OH_LOOP         equ 1               ; 1  строка цикла
OH_END          equ 2               ; 1  последняя строка (длина-1)
OH_ROWS         equ 3               ; строки

; --- инструмент (сэмпл): строка 5 байт, как в FTC, + ретриггер в свободном бите
INS_ROWS_MAX    equ 64
INS_ROW_SIZE    equ 5
INS_BLOCK       equ 384             ; 3 + 64*5 = 323, дальше хвост
INS_FX          equ 324             ; 1  номер FX (0 - без FX)
INS_NAME        equ 336             ; 16 имя
    ASSERT OH_ROWS+INS_ROWS_MAX*INS_ROW_SIZE <= INS_FX
    ASSERT INS_NAME+16 <= INS_BLOCK
; строка:
IR_NOISE        equ 0               ; 7 шум накоплением, 6 шум ВЫКЛ, 4..0 смещение шума
IR_TONE         equ 1               ; 2 смещение тона 12 бит (младший первым); в старшем:
                                    ;   7 тон накоплением, 6 тон ВЫКЛ, 4 ретриггер огибающей
IR_VOL          equ 3               ; 7 огибающая накоплением, 6 огибающая ВКЛ, 5 слайд
                                    ;   громкости, 4 слайд вниз, 3..0 громкость
IR_ENV          equ 4               ; смещение периода огибающей со знаком (вычитается)
IRB_ACC         equ 7               ; биты (в байтах шума, старшем тона, громкости)
IRB_OFF         equ 6               ; шум / тон выключен; у огибающей - ВКЛ
IRB_RETRIG      equ 4               ; ретриггер (старший байт тона) - наше, в FTC свободен
IRB_SLIDE       equ 5
IRB_SLIDE_DOWN  equ 4

; --- орнамент: строка 2 байта, как имидж FTC
ORN_ROWS_MAX    equ 64
ORN_ROW_SIZE    equ 2
ORN_BLOCK       equ 256             ; 3 + 64*2 = 131, дальше имя
ORN_NAME        equ 144             ; 16 имя
ORN_BASE        equ SAMPLES_MAX*INS_BLOCK      ; #3000
    ASSERT OH_ROWS+ORN_ROWS_MAX*ORN_ROW_SIZE <= ORN_NAME
    ASSERT ORN_BASE+ORNAMENTS_MAX*ORN_BLOCK == #4000
; строка:
OR_NOISE        equ 0               ; 7 шум накоплением, 6 нота накоплением, 4..0 смещение шума
OR_NOTE         equ 1               ; смещение ноты, полутоны со знаком

SONG_EDITSTATE  equ #1000           ; состояние редактора этого трека (курсор, позиция,
SONG_EDITSTATE_SIZE equ #400        ; режим вида...) - ТОЛЬКО трекер, плагинам не трогать.
                                    ; При переключении треков всё возвращается как было.
                                    ; дальше до #3FFF резерв
    ASSERT SONG_CAT_END <= SONG_EDITSTATE

    ASSERT ORD_POS+ORDER_MAX*ORD_SIZE <= PAT_CATALOG
    ASSERT SONG_CAT_END <= #4000

; =========================================================================
; ПАТТЕРН
; =========================================================================
; Паттерн = одна страница 16К. Роу = полоса 256 байт страницы, т.е.
; H = база окна + роу, следующая роу - inc h. В полосе:
;   L   0..111  данные: 2 чипа по CHIP_SIZE
;   L 112..252  текст роу (готовый вид для экрана) - ТОЛЬКО трекер, плагинам не
;               трогать: трекер перерисовывает его сам после записи в данные
;   L 253..254  текст номера роу
; 0 в любом поле данных = пусто / оставить текущее.

PAT_ROWS_MAX    equ 64

; --- канал, 16 байт
CH_NOTE         equ 0           ; 0 - пусто, 1..96 ноты, NOTE_CMD.. команды ноты
CH_SAMPLE       equ 1
CH_ENVSHAPE     equ 2
CH_ORNAMENT     equ 3           ; номер+1: 0 - пусто (не менять), 1 - орнамент 0 (пустой),
                                ;   2..17 - орнаменты 1..16
CH_VOLUME       equ 4
                                ; +5 резерв
CH_CMD          equ 6           ; 2 команды по CMD_SIZE: +6 +8
CH_CMDS         equ 2
                                ; +10..+15 резерв
CH_SIZE         equ 16

; --- команда, 2 байта. Что в них - решают плеер и компилятор, трекер их только
; хранит и показывает (4 hex: первый байт, второй байт). 0,0 - пусто.
CMD_SIZE        equ 2

; Коды команд - ТОЛЬКО через эти имена (конвертеры, плеер): поменяли код здесь -
; после пересборки все поняли. Раскладка - doc/commands.md. Два байта делятся по-разному:
;   код 1..E: байт 0 = код<<4 | задержка (или X), байт 1 = параметр (или YZ) - 12 бит;
;   код F:    байт 0 = #F0 | подкод (CMDX_*), байт 1 = параметр - 8 бит, ещё 16 команд.
; Номера VT (1..6, 9..B) - как в VT / PT3.
CMD_GLIS_DOWN   equ #1          ; частота вниз: задержка, шаг (период +шаг)
CMD_GLIS_UP     equ #2          ; частота вверх
CMD_PORTA       equ #3          ; портаменто к ноте: задержка, шаг
CMD_SMP_OFS     equ #4          ; сэмпл с позиции: параметр - строка
CMD_ORN_OFS     equ #5          ; орнамент с позиции
CMD_ONOFF       equ #6          ; звук вкл / выкл: параметр - вкл<<4 | выкл (тиков)
CMD_VOL_SLIDE   equ #7          ; слайд громкости: задержка, вверх<<4 | вниз
CMD_VIBRATO     equ #8          ; вибрато: задержка, скорость<<4 | глубина
CMD_ENV_DOWN    equ #9          ; частота огибающей вниз: задержка, шаг
CMD_ENV_UP      equ #A          ; частота огибающей вверх
CMD_SPEED       equ #B          ; скорость: параметр - тиков на роу
CMD_ARP         equ #C          ; арпеджио: шагов, сдвиг1<<4 | сдвиг2 (полутоны)
                                ; #D, #E - резерв (12 бит)
CMD_EXT         equ #F          ; расширенные: подкод в младшем полубайте байта 0
CMDX_RETRIG     equ #0          ;   ретриггер огибающей и тона (FT 500): параметр - 0
CMDX_DETUNE     equ #1          ;   детюн: сдвиг периода со знаком
CMDX_DELAY      equ #2          ;   задержка ноты: тиков
                                ;   #3..#F - резерв (FX и прочее)

    ASSERT CH_CMD+CH_CMDS*CMD_SIZE <= CH_SIZE

NOTE_EMPTY      equ 0
NOTE_FIRST      equ 1           ; C-1 (как PT3/VT), 12 нот x 8 октав: C-1..B-8
NOTE_COUNT      equ 12*8
NOTE_LAST       equ NOTE_FIRST+NOTE_COUNT-1
NOTE_CMD        equ NOTE_LAST+1
NOTE_OFF        equ NOTE_CMD

; --- строка чипа: заголовок 8 байт + 3 канала
CHIP_ENVPER     equ 0           ; 2 период огибающей (младший, старший)
CHIP_ENV2       equ 2           ; 2 огибающая-2 (младший, старший)
CHIP_NOISE      equ 4           ; 1 шум: 0 - пусто, шум 0 - #20 (плеер берёт биты 4..0)
CHIP_ENVNOTE    equ 5           ; 1 период огибающей нотой: ставится при вводе
                                ;   (0 - нет; бит 7 - нота неточная)
                                ; +6..+7 резерв
CHIP_HDR_SIZE   equ 8
CHIP_CH_A       equ CHIP_HDR_SIZE
CHIP_CH_B       equ CHIP_CH_A+CH_SIZE
CHIP_CH_C       equ CHIP_CH_B+CH_SIZE
CHIP_SIZE       equ CHIP_CH_C+CH_SIZE   ; 56

CHIPS_MAX       equ 2
PAT_DATA_SIZE   equ CHIP_SIZE*CHIPS_MAX ; 112
PAT_TEXT        equ PAT_DATA_SIZE       ; текст роу - сразу за данными
    ASSERT CHIP_SIZE == 56

; =========================================================================
; СЭМПЛ, ОРНАМЕНТ
; =========================================================================
; !!! НЕ РЕШЕНО: формат строки сэмпла и орнамента

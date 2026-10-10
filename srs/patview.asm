; =========================================================================
; ПРОСМОТР ПАТТЕРНА, 6 КАНАЛОВ - тулза (окно 1, #4000)
; =========================================================================
;
; ПАМЯТЬ. Паттерн = страница 16К, роу = полоса 256 байт (H = #80 + роу в окне 2):
;   L   0..111  данные (2 чипа по CHIP_SIZE, формат - sdk/plugin.asm)
;   L 112..252  ТЕКСТ роу - готовый вид всех полей во всю ширину
;   L 253..254  текст номера роу
; Текст делает основной цикл (Row_To_Text) - при создании паттерна и при
; правке клетки. На экран сам текст не пересчитывается никогда.
;
; ЭКРАН КАЖДЫЙ КАДР (IM1, после музыки и мыши) собирается заново целиком:
;   1. поля   - DMA-"черепица": на каждый кусок роу одного паттерна (склейка) по
;               одной транзакции на элемент, сразу на все строки куска;
;   2. атрибуты - DMA из строк-шаблонов (тусклый / активный паттерн / строка
;               редактирования), кусками одинакового состояния;
;   3. разделители и цвет номеров роу - процессором поверх.
; Отслеживания изменений на экране нет: что в страницах паттернов, то и видно.
;
; ЧЕРЕПИЦА. DMA ходит словами: кусок округляем до чётных колонок, лишний знак
; с краю попадает только на колонку-разделитель (между элементами ровно одна),
; а разделители рисуются поверх (п.3). Чтобы округление работало, сдвиг
; "колонка в тексте -> колонка на экране" у каждого элемента чётный в любой
; раскладке: всё, что добавляется при открытии элемента, чётной ширины (+6, +10).
;
; РАСКЛАДКА. Открыт один элемент (канал под курсором или Env чипа), остальные
; закрыты. Закрытое = начало открытого, т.е. меняется только длина куска:
;   элемент   текст в странице                закрыт  открыт
;   Env       "0134 1F 0000 "  период шум огиб-2   7      13
;   канал     "C-4 A1FE 1234 5678" нота инстр к1 к2 8      18
;   экран: │r05кн│00│Env│A│B│C║Env│D│E│F│   (кн - кнопки ордера, колонки 4..5)
;          ордер 7, номер роу 3, дальше элементы с │ после каждого:
;          всё закрыто: 10 + 2*7 + 6*8 + 8 = 80, открыт канал +10 = 90 из 90
;
; Клавиши PS/2 (таблица Hotkeys):
;   стрелки, PgUp/PgDn, Tab - роу и канал, Ctrl+E - открыть Env чипа,
;   F5..F8, Esc - плей и стоп как в VT, Ctrl+T полоса времени.
;   Колесо - роу, Ctrl/Shift + колесо - канал. Мышь: [+]/[-] в заголовке,
;   кнопки ордера Unique / - / + / Clone у текущей позиции.
; =========================================================================
    MODULE patview

; паттерн n текущего трека - страница Trk_Pat+n (Pat_Page, коре)
PAT_BASE_H      equ #80             ; страница паттерна - в окне 2
SCR_BASE_H      equ #C0             ; текстовая страница - в окне 3
LINE_W          equ 128             ; знакомест в строке текстовой страницы
VIEW_LINE       equ 4               ; верхняя рамка с заголовками (над ней - шапка, srs/head.asm)
VIEW_ROWS       equ 30              ; роу на экране: строки 5..34
VIEW_CENTER     equ VIEW_ROWS/2     ; строка редактирования - по центру
FIRST_LINE      equ VIEW_LINE+1
EDIT_LINE       equ FIRST_LINE+VIEW_CENTER
BOTTOM_LINE     equ FIRST_LINE+VIEW_ROWS

; Невидимые строки текстовой страницы - шаблоны
TPL_LINE        equ 36              ; символы: пустая роу (пробелы + разделители)
                                    ; атрибуты: строка 36 - тусклый, 37 - активный,
                                    ; 38 - строка редактирования
ST_BASE         equ 0               ; состояния строки = смещение строки-шаблона
ST_ACTIVE       equ 1
ST_EDIT         equ 2

; Колонки экрана
ORD_X           equ 0               ; ордер: "│r05", кнопки в 4..5, │ в колонке 6
ORD_BTN_X       equ 4               ; кнопки ордера (2 знакоместа)
ROWNUM_X        equ 7               ; номер роу: 2 знака
CONT_X          equ 10              ; отсюда - элементы паттерна
DRAW_X0         equ 6               ; DMA символов/атрибутов - с этой колонки (чётная)
DRAW_X1         equ 90              ; ... по эту (не включая)
DRAW_WORDS      equ (DRAW_X1-DRAW_X0)/2

; Текст роу в странице паттерна (см. шапку)
;   L 112..180  БЛОК: закрытые части всех элементов подряд - ровно экранный вид
;               при "всё закрыто" (экранные колонки CONT_X..CX_END-1, разделители - пробелы)
;   L 181..253  РАСШИРЕНИЯ: что добавляется при открытии (Env " 0000 ", канал
;               " 1234 5678"). Каждое лежит на колонке той же чётности, что и
;               экранная колонка, куда оно встаёт - DMA сдвигает только на чётное
; Экран из блока: ничего не открыто - 1 черепица (весь блок); открыт элемент -
; 3: блок до него включительно, его расширение, блок после него со сдвигом.
TX_BLOCK        equ PAT_TEXT        ; = экранная колонка CONT_X
CX_END          equ CONT_X+69       ; правая рамка при "всё закрыто"
TX_BLOCK_W      equ CX_END-CONT_X   ; 69
; Колонка элемента при "всё закрыто" (в блоке: TX_BLOCK + CX - CONT_X)
CX_ENV1         equ CONT_X
CX_A            equ CONT_X+8
CX_B            equ CONT_X+17
CX_C            equ CONT_X+26
CX_ENV2         equ CONT_X+35
CX_D            equ CONT_X+43
CX_E            equ CONT_X+52
CX_F            equ CONT_X+61
; Расширения в строке страницы: сначала встающие на нечётную колонку, потом на чётную
EX_ENV1         equ 181             ; встаёт на 17
EX_B            equ 187             ; 35
EX_D            equ 197             ; 61
EX_F            equ 207             ; 79
EX_A            equ 218             ; 26
EX_C            equ 228             ; 44
EX_ENV2         equ 238             ; 52
EX_E            equ 244             ; 70
W_ENV_EXT       equ W_ENV_OPEN-W_ENV_CLOSED   ; 6
W_CH_EXT        equ W_CH_OPEN-W_CH_CLOSED     ; 10
    ASSERT TX_BLOCK+TX_BLOCK_W <= EX_ENV1
    ASSERT EX_E+W_CH_EXT <= 256
    ; чётность: расширение лежит на колонке той же чётности, что и место на экране
    ASSERT ((CX_ENV1+W_ENV_CLOSED-EX_ENV1)&1) == 0 && ((CX_B+W_CH_CLOSED-EX_B)&1) == 0
    ASSERT ((CX_D+W_CH_CLOSED-EX_D)&1) == 0 && ((CX_F+W_CH_CLOSED-EX_F)&1) == 0
    ASSERT ((CX_A+W_CH_CLOSED-EX_A)&1) == 0 && ((CX_C+W_CH_CLOSED-EX_C)&1) == 0
    ASSERT ((CX_ENV2+W_ENV_CLOSED-EX_ENV2)&1) == 0 && ((CX_E+W_CH_CLOSED-EX_E)&1) == 0
    ASSERT ((CONT_X-TX_BLOCK)&1) == 0

ITEMS           equ 8               ; Env, A, B, C, Env, D, E, F
ITEM_NONE       equ #FF
W_ENV_CLOSED    equ 7
W_ENV_OPEN      equ 13
W_CH_CLOSED     equ 8
W_CH_OPEN       equ 18

BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_UP          equ #C1             ; ┴
BOX_DOWN        equ #C2             ; ┬
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘
BOX_V2          equ #BA             ; ║ между чипами
BOX_DOWN2       equ #D2             ; ╥
BOX_UP2         equ #D0             ; ╨
ARROW_R         equ #10             ; ►

; Полоса времени: на каждый шаг фон своим цветом, высота цвета = время шага
BAND_BG         equ 0
BAND_TILES      equ 1               ; IM1: поля (черепица)          - красный
BAND_ATTR       equ 2               ; IM1: атрибуты                 - жёлтый
BAND_SEPS       equ 3               ; IM1: разделители, номера      - зелёный
BAND_INPUT      equ 4               ; ввод, таблица роу             - синий
BAND_LAYOUT     equ 5               ; смена раскладки               - фиолетовый
BAND_ORDER      equ 7               ; ордер                         - белый

    MACRO BAND_I n                  ; из IM1
        ld a,(Timing)
        or a
        ld a,n
        call nz,Band_Int
    ENDM
    MACRO BAND_M n                  ; из основного цикла
        ld a,n
        call Band_Main
    ENDM

    PLUGIN_HEADER PLG_TOOL,"   ","Pattern view 6ch"

; =========================================================================
; СТАРТ И ОСНОВНОЙ ЦИКЛ
; =========================================================================
PluginMain
        ld hl,(Pal_Bg)              ; цвет фона темы - для полосы времени
        ld (Band_Bg),hl
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        xor a                       ; X-офсет текстового режима не используем
        ld bc,GXOFFSL
        out (c),a
        ld bc,GXOFFSH
        out (c),a
        ld a,(Pv_Started)           ; первый вход - таблицы и тестовый трек
        or a
        jr nz,.again
        inc a
        ld (Pv_Started),a
        call Build_Row_A
        call Init_RowNum            ; страница номеров роу
        ld a,1                      ; трек - из его страницы (пустой - Song_New в коре)
        ld (SV_SONG_NEW),a
.again  ld a,(SV_SONG_NEW)          ; трек загрузили (вкладка Disk) - перечитать
        or a
        call nz,Song_Reload
        call Head_Load              ; шапка: значения трека
        call View_Chips             ; 3 или 6 каналов - по треку
        call Head_Draw              ; шапка: рамки, подписи, кнопки
        call Head_Sprites           ; шапка: кнопки транспорта - спрайты
        call Build_Layout           ; раскладка (хук IM1 ещё не стоит)
        call Draw_Order
        call Build_Row_Tab
        ld hl,Pv_Fields             ; поля вида, фокус - паттерну
        call Fld_Init
        ld hl,F_Pat
        call Fld_Set_Focus
        ld hl,Compose               ; вывод - в IM1, каждый кадр
        ld (SV_FRAME_HOOK),hl
        call Int_Line_Set

Main_Loop
        BAND_M BAND_BG
        halt
        BAND_M BAND_INPUT
        call Handle_Keys
        call Ln_Check               ; отпустили клавишу ввода - строка молчит
        call En_Check               ; отпустили Enter - стоп
        call Head_Show              ; шапка: значения (srs/head.asm)
        call Mem_Show               ; свободная память - в нижней строке
        call Time_Tick              ; время игры
        call Fld_Update             ; мышь и колесо - полям (коре, srs/fields.asm)
        ld a,(Pv_Exit)              ; выбрали другую вкладку - выходим в коре
        or a
        jr nz,Pv_Leave
        call Play_Step
        call Build_Row_Tab
        ld a,(Layout_Pending)       ; сменился открытый элемент
        or a
        jr z,.nolayout
        BAND_M BAND_LAYOUT
        call Relayout
.nolayout
        ld a,(Order_Pending)        ; сменилась позиция
        or a
        jr z,Main_Loop
        BAND_M BAND_ORDER
        call Draw_Order
        jr Main_Loop

;-------- Выход в коре (другая вкладка, её страница - уже в SV_TOOL): IM1 больше
; не рисует паттерн, окно 3 - как было при входе (PluginMain)
Pv_Leave
        xor a
        ld (Pv_Exit),a
        call Band_Main              ; полоса времени: фон - обычный (иначе в тулзах он
                                    ;   остаётся цветом последнего шага)
        di
        ld hl,0
        ld (SV_FRAME_HOOK),hl
        ei
        RESTPAGE3
        ret

; --- состояние
Pv_Started      db 0                ; 1 - таблицы и тестовый трек уже есть (вход не первый)
Pv_Exit         db 0                ; 1 - выйти из основного цикла в коре
Cur_Chan        db 0                ; канал под курсором 0..5
Env_Open        db 0                ; 1 - открыт Env чипа курсора, а не канал
Open_Item       db 1                ; открытый элемент 0..7, ITEM_NONE - нет
Layout_Pending  db 0
Layout_Busy     db 0                ; 1 - раскладка меняется, IM1 паттерн не рисует
Order_Pending   db 0
Pat_Loops       db 0                ; сколько раз паттерн прокрутился в плее паттерна
Cur_Row         db 0
Cur_Pos         db 0
Loop_Pos        db 0
Ord_Last        db 0
Play_Tick       db 0
Env_As_Note     db 0                ; 1 - период огибающей показывать нотой (Alt+E)
Timing          db 0                ; полоса времени: 0 - выкл (по умолчанию), 1 - вкл (Ctrl+T)

; =========================================================================
; IM1, КАЖДЫЙ КАДР: экран паттерна целиком
; =========================================================================
Compose
        ld a,(Layout_Busy)
        or a
        ret nz
        ld a,(Win_Busy)             ; окно рисуют - кадр пропустить
        or a
        ret nz
        ld a,(SV_DRAW_PAGE)         ; экран - в окно 3 (для прохода процессором)
        SETPAGE3 a
        ld a,(Tpl_Repl)             ; раскладка сменилась - размножить шаблоны
        or a
        call nz,Tpl_Replicate
        call Head_Copy              ; 0. шапка - из буфера (srs/head.asm)
        BAND_I BAND_TILES
        call Draw_Chars             ; 1. поля: черепица и пустые строки
        BAND_I BAND_ATTR
        call Draw_Attrs             ; 2. атрибуты из шаблонов
        BAND_I BAND_SEPS
        call Draw_Seps              ; 3. разделители, цвет номеров роу
        call Draw_Sel               ; 4. выделение
        call Draw_Cursor            ; 5. курсор - поверх
        call Win_Blit               ; 6. окно (About, меню) - поверх всего
        RESTPAGE3
        ld a,(Timing)               ; вернуть цвет основного цикла
        or a
        ret z
        ld a,(Band_Cur)
        jp Band_Int

; --- общие для проходов
R_Ptr           dw 0                ; следующая запись таблицы роу
R_Idx           db 0                ; номер экранной строки (0..26) следующего куска
R_Start         db 0                ; первая строка куска
R_N             db 0                ; строк в куске
R_Page          db 0                ; страница паттерна куска (0 - пусто)
R_H             db 0                ; H первой роу куска
R_State         db 0                ; состояние куска (для атрибутов)

;-------- 1. ПОЛЯ. Таблица роу -> куски "одна страница, роу подряд" или "пусто"
Draw_Chars
        ld hl,(Row_Tab_Show)
        xor a
        ld (R_Idx),a
.run    ld a,(R_Idx)
        cp VIEW_ROWS
        ret nc
        ld (R_Start),a
        ld a,(hl)                   ; страница
        ld (R_Page),a
        inc hl
        ld a,(hl)                   ; H
        ld (R_H),a
        inc hl
        inc hl
        ld c,1                      ; C - строк в куске
.ext    ld a,(R_Start)              ; продлеваем, пока та же страница и роу подряд
        add a,c
        cp VIEW_ROWS
        jr nc,.go
        ld a,(R_Page)
        cp (hl)
        jr nz,.go
        or a
        jr z,.next                  ; пустые - подряд всегда
        inc hl
        ld a,(R_H)
        add a,c
        cp (hl)
        dec hl
        jr nz,.go
.next   inc hl
        inc hl
        inc hl
        inc c
        jr .ext
.go     ld a,c
        ld (R_N),a
        ld a,(R_Start)
        add a,c
        ld (R_Idx),a
        push hl
        ld a,(R_Page)
        or a
        jr z,.blank
        call Tile_Run
        jr .done
.blank  call Blank_Run
.done   pop hl
        jr .run

;-------- Кусок роу одного паттерна: номер роу + черепицы раскладки, каждая -
; одна DMA сразу на все строки куска. Прямой код: D - строка источника, E -
; строка экрана, остальное - числа в командах (их подставляет Build_Tiles).
; Число блоков и страница приёмника DMA помнит между переносами - пишем раз.
; Черепица: ждём DMA, 7 out - колонка/строка источника, колонка/строка
; приёмника, длина, страница источника (L), пуск.
    MACRO TILE scol,dcol,len
        call dma_wait               ; +0  (C = #AF после dma_wait)
        ld a,scol                   ; +3, число - +4
        ld b,high DMASADDRL
        out (c),a
        ld a,d                      ; строка источника
        ld b,high DMASADDRH
        out (c),a
        ld a,dcol                   ; +14, число - +15
        ld b,high DMADADDRL
        out (c),a
        ld a,e                      ; строка экрана
        ld b,high DMADADDRH
        out (c),a
        ld a,len                    ; +25, число - +26
        ld b,high DMALEN
        out (c),a
        ld a,l                      ; страница источника - каждый раз: адрес DMA -
        ld b,high DMASADDRX         ; счётчик, после роу 63 он уходит в следующую
        out (c),a                   ; страницу
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a                   ; пуск
    ENDM
TILE_SCOL       equ 4               ; где в черепице числа
TILE_DCOL       equ 15
TILE_LEN        equ 26
TILE_SIZE       equ 42

Tile_Run
        ld a,(R_H)                  ; D - строка источника (роу)
        sub PAT_BASE_H
        ld d,a
        ld a,(R_Start)              ; E - строка экрана
        add a,FIRST_LINE
        ld e,a
        call dma_wait               ; общие для куска регистры
        ld a,(R_N)
        dec a
        ld b,high DMANUM            ; блоков-1
        out (c),a
        ld a,(SV_DRAW_PAGE)
        ld b,high DMADADDRX         ; страница экрана
        out (c),a
        ld l,PAGE_ROWNUM            ; L - страница источника: номер роу - из страницы номеров
        TILE ROWNUM_X&#FE, ROWNUM_X&#FE, 1  ; колонки 6..9: номер + края на разделители
        ld a,(R_Page)               ; дальше - из страницы паттерна
        ld l,a
Tile_0  TILE 0,0,0                  ; черепицы раскладки (Build_Tiles)
    ASSERT $-Tile_0 == TILE_SIZE
Tile_1  TILE 0,0,0
Tile_2  TILE 0,0,0
        ret

;-------- Кусок пустых строк: символы пустой роу из страницы тусклого шаблона
Blank_Run
        ld a,PAGE_VIEW_TPL+ST_BASE
        ld h,DRAW_X0
        jp Tpl_Run

;-------- 2. АТРИБУТЫ. Куски одинакового состояния -> строка-шаблон этого состояния
Draw_Attrs
        ld hl,(Row_Tab_Show)
        xor a
        ld (R_Idx),a
.run    ld a,(R_Idx)
        cp VIEW_ROWS
        ret nc
        ld (R_Start),a
        call Row_State              ; A - состояние строки R_Idx, HL - на следующую запись
        ld (R_State),a
        ld c,1
.ext    ld a,(R_Start)
        add a,c
        cp VIEW_ROWS
        jr nc,.go
        ld (R_Idx),a
        push hl
        call Row_State
        pop de
        ld b,a
        ld a,(R_State)
        cp b
        ex de,hl                    ; HL - снова на эту запись
        jr nz,.go
        inc hl
        inc hl
        inc hl
        inc c
        jr .ext
.go     ld a,c
        ld (R_N),a
        ld a,(R_Start)
        add a,c
        ld (R_Idx),a
        push hl
        ld a,(R_State)              ; страница шаблона этого состояния
        add a,PAGE_VIEW_TPL
        ld h,DRAW_X0+SCR_ATTR
        call Tpl_Run
        pop hl
        jr .run

; A = состояние строки R_Idx по записи (HL): пусто/тусклый -> ST_BASE, активный
; паттерн -> ST_ACTIVE, центр -> ST_EDIT. HL += 3
Row_State
        ld a,(R_Idx)
        cp VIEW_CENTER
        jr nz,.data
        inc hl
        inc hl
        inc hl
        ld a,ST_EDIT
        ret
.data   ld a,(hl)                   ; страница: 0 - пусто
        inc hl
        inc hl
        or a
        jr z,.base
        ld a,(hl)                   ; состояние из таблицы роу
        inc hl
        ret
.base   inc hl
        ld a,ST_BASE
        ret

;-------- После смены раскладки: в каждой странице шаблона строка 0 -> строки
; 1..26, с перекрытием (блок k копирует строку k в k+1, которую уже переписал
; блок k-1). Одна DMA на страницу, раз за смену раскладки
Tpl_Repl        db 0
Tpl_Replicate
        xor a
        ld (Tpl_Repl),a
        ld a,PAGE_VIEW_TPL+ST_BASE
        call .one
        ld a,PAGE_VIEW_TPL+ST_ACTIVE
        call .one
        ld a,PAGE_VIEW_TPL+ST_EDIT
.one    ld l,a
        call dma_wait               ; C = #AF
        ld a,l
        ld b,high DMASADDRX         ; источник и приёмник - эта страница
        out (c),a
        ld b,high DMADADDRX
        out (c),a
        xor a
        ld b,high DMASADDRL         ; строка 0 -> строка 1, с колонки 0
        out (c),a
        ld b,high DMASADDRH
        out (c),a
        ld b,high DMADADDRL
        out (c),a
        inc a
        ld b,high DMADADDRH
        out (c),a
        ld a,127                    ; вся строка: 128 слов
        ld b,high DMALEN
        out (c),a
        ld a,VIEW_ROWS-2            ; блоков-1: строки 1..26
        ld b,high DMANUM
        out (c),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a
        ret

;-------- Кусок одинаковых строк из страницы шаблона: ОДНА DMA на весь кусок.
; В странице шаблона строки 0..26 одинаковые - берём с 0-й, сколько надо.
; A - страница шаблона, H - колонка (DRAW_X0 - символы, +SCR_ATTR - атрибуты).
; Прямой код: 9 out, без таблиц.
Tpl_Run
        ld l,a
        call dma_wait               ; C = #AF
        ld a,l
        ld b,high DMASADDRX         ; источник: страница шаблона, строка 0
        out (c),a
        ld a,h
        ld b,high DMASADDRL
        out (c),a
        xor a
        ld b,high DMASADDRH
        out (c),a
        ld a,h                      ; приёмник: та же колонка, строка куска
        ld b,high DMADADDRL
        out (c),a
        ld a,(R_Start)
        add a,FIRST_LINE
        ld b,high DMADADDRH
        out (c),a
        ld a,(SV_DRAW_PAGE)
        ld b,high DMADADDRX
        out (c),a
        ld a,DRAW_WORDS-1
        ld b,high DMALEN
        out (c),a
        ld a,(R_N)
        dec a
        ld b,high DMANUM
        out (c),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a                   ; пуск
        ret

;-------- 3. РАЗДЕЛИТЕЛИ (их колонки перекрыты черепицей) и цвет номеров роу
;-------- 4. Курсор: поле Cur_Field открытого элемента на строке редактирования - цветом
; курсора. Мигающий (Cur_Blink, Setup) - половину из каждых 32 кадров не рисуем
Draw_Cursor
        ld a,(Cur_Blink)
        or a
        jr z,.on
        ld a,(SV_FRAMES)
        and 16
        ret nz
.on     ld a,(Env_Open)             ; таблица полей элемента
        or a
        ld hl,Cf_Chan
        jr z,$+5
        ld hl,Cf_Env
        ld a,(Cur_Field)
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)                   ; колонка в элементе
        inc hl
        ld b,(hl)                   ; ширина
        ld a,(Open_Item)            ; + колонка элемента
        ld hl,Item_Col
        call Arr_Get
        add a,e
        add a,SCR_ATTR
        ld l,a
        ld h,SCR_BASE_H+EDIT_LINE
        ld a,(THEME_ATTR+CLR_CURSOR)
.c      ld (hl),a
        inc l
        djnz .c
        ret

Draw_Seps
        ld hl,Seps                  ; колонка, символ
        ld a,(Seps_N)
        ld b,a
.s      ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld l,e
        ld h,SCR_BASE_H+FIRST_LINE
        DUP VIEW_ROWS
        ld (hl),a
        inc h
        EDUP
        pop hl
        djnz .s

        ld hl,(Row_Tab_Show)        ; цвет номера роу: готовый по номеру, центр - свой
        ld d,SCR_BASE_H+FIRST_LINE
        ld b,0
.r      ld a,(hl)                   ; страница: 0 - пусто, цвет не важен
        inc hl
        or a
        ld a,(hl)                   ; H
        inc hl
        inc hl
        jr z,.n
        sub PAT_BASE_H
        push hl
        ld l,a
        ld h,high Row_A
        ld a,(hl)
        pop hl
        ld c,a
        ld a,b
        cp VIEW_CENTER
        jr nz,.put
        ld a,(THEME_ATTR+CLR_EDIT_ROW)
        ld c,a
.put    ld e,ROWNUM_X+SCR_ATTR
        ld a,c
        ld (de),a
        inc e
        ld (de),a
.n      inc d
        inc b
        ld a,b
        cp VIEW_ROWS
        jr c,.r
        ret

; =========================================================================
; РАСКЛАДКА: по открытому элементу - колонки элементов, черепицы, разделители,
; шаблоны строк, рамки и подписи. При смене открытого элемента.
; =========================================================================
Vis_Items       db ITEMS            ; видно элементов: 8 (2 чипа) или 4 (1 чип) - View_Chips
Blk_End         db CX_END           ; правая рамка блока "всё закрыто" для видимых элементов
Ch_Last         db 5                ; последний канал для курсора: 5 или 2
Item_Col        ds ITEMS            ; колонка элемента на экране
Item_W          ds ITEMS            ; ширина на экране
Lay_End         db 0                ; колонка последнего разделителя (правая рамка)

; Элемент при "всё закрыто": колонка экрана и где лежит его расширение
Item_CX         db CX_ENV1, CX_A, CX_B, CX_C, CX_ENV2, CX_D, CX_E, CX_F
Item_EX         db EX_ENV1, EX_A, EX_B, EX_C, EX_ENV2, EX_D, EX_E, EX_F
SEPS_MAX        equ ITEMS+2
Seps_N          db 0
Seps            ds SEPS_MAX*2       ; колонка, символ
Sep_Attr        ds SEPS_MAX         ; цвет разделителя (для шаблонов)

;-------- Из основного цикла: открытый элемент сменился. Без DI: DMA тут нет,
; а IM1 паттерн не рисует, пока Layout_Busy (музыка и мышь при этом идут)
Relayout
        xor a
        ld (Layout_Pending),a
        ld a,1
        ld (Layout_Busy),a
        call Build_Layout
        xor a
        ld (Layout_Busy),a
        ret

Build_Layout
        call Calc_Open
        ; --- колонки элементов и разделители
        xor a
        ld (Seps_N),a
        ld e,DRAW_X0                ; разделитель ордер | номер роу
        ld a,BOX_V
        ld d,CLR_TITLE
        call Add_Sep
        ld e,CONT_X-1               ; разделитель номер роу | элементы
        ld a,BOX_V
        ld d,CLR_SEP
        call Add_Sep
        ld b,0                      ; B - элемент
        ld e,CONT_X                 ; E - колонка
.it     ld a,b
        ld hl,Item_Col
        call Arr_Set_E
        call Item_Width             ; D - ширина
        ld a,b
        ld hl,Item_W
        push de
        ld e,d
        call Arr_Set_E
        pop de
        ld a,e                      ; разделитель после элемента
        add a,d
        ld e,a
        ld a,(Vis_Items)            ; последний видимый элемент - правая рамка
        dec a
        cp b
        jr z,.outer
        ld a,b
        cp 3
        ld a,BOX_V
        jr nz,$+4
        ld a,BOX_V2
        ld d,CLR_SEP
        jr .sep
.outer  ld a,e
        ld (Lay_End),a
        ld a,BOX_V
        ld d,CLR_TITLE
.sep    push bc
        call Add_Sep
        pop bc
        inc e
        inc b
        ld a,b
        ld hl,Vis_Items
        cp (hl)
        jr c,.it

        call Build_Templates        ; шаблоны строк (символы пустой роу, атрибуты)
        call Build_Tiles            ; черепицы: числа в прямой код Tile_0..2
        call Build_Head_Kids        ; поля кнопок [+]/[-] - на новые колонки
        call Clear_Right            ; правее рамки - остатки прошлой раскладки
        call Draw_Frame             ; рамки и подписи
        ret

;-------- Строки роу: колонки правее правой рамки - пробелы цветом фона.
; Черепица туда не пишет, а при сужении раскладки там остаётся старое
Clear_Right
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld h,SCR_BASE_H+FIRST_LINE
        ld d,VIEW_ROWS
.r      ld a,(Lay_End)
        inc a
        ld l,a
.c      ld (hl),' '
        set 7,l
        ld (hl),c
        res 7,l
        inc l
        bit 7,l
        jr z,.c                     ; до колонки 127
        inc h
        dec d
        jr nz,.r
        ret

; Открытый элемент: Env чипа курсора или канал курсора
Calc_Open
        ld a,(Cur_Chan)             ; канал -> элемент: 0..2 -> 1..3, 3..5 -> 5..7
        inc a
        cp 4
        jr c,$+3
        inc a
        ld b,a
        ld a,(Env_Open)
        or a
        ld a,b
        jr z,.set
        and 4                       ; Env этого чипа: 0 или 4
.set    ld (Cursor_Item),a          ; под курсором - всегда, открыт - он же
        ld (Open_Item),a
        ret

Cursor_Item     db 1                ; элемент под курсором (фокус), открыт он или нет
Cur_Field       db 0                ; поле курсора в элементе (Cf_Chan / Cf_Env)

; Поля курсора в открытом элементе: колонка от начала элемента, ширина.
; Канал "C-4 A1FE 1234 5678": нота, сэмпл, огибающая, орнамент, громкость, цифры двух команд.
; Env чипа "0134 1F 0000": цифры периода, шума, огибающей-2
Cf_Chan         db 0,3, 4,1, 5,1, 6,1, 7,1, 9,1, 10,1, 11,1, 12,1, 14,1, 15,1, 16,1, 17,1
CF_CHAN_N       equ ($-Cf_Chan)/2
Cf_Env          db 0,1, 1,1, 2,1, 3,1, 5,1, 6,1, 8,1, 9,1, 10,1, 11,1
CF_ENV_N        equ ($-Cf_Env)/2

;-------- Сколько чипов у трека (Song_Chips, шапка) -> что видно в паттерне.
; 1 чип: Env, A, B, C (данные второго чипа в паттерне остаются, просто не видны).
; После - Build_Layout (или Need_Layout)
HIDDEN_X        equ 200             ; колонка кнопок скрытых элементов - за экраном
View_Chips
        ld a,(Song_Chips)
        cp 2
        jr c,.one
        ld a,ITEMS                  ; 2 чипа: все 8 элементов
        ld (Vis_Items),a
        ld a,CX_END
        ld (Blk_End),a
        ld a,5
        ld (Ch_Last),a
        ret
.one    ld a,4                      ; 1 чип: Env, A, B, C
        ld (Vis_Items),a
        ld a,CX_ENV2-1              ; правая рамка - на месте разделителя чипов
        ld (Blk_End),a
        ld a,2
        ld (Ch_Last),a
        ld a,(Cur_Chan)             ; курсор был на втором чипе - на канал C
        cp 3
        ret c
        ld a,2
        ld (Cur_Chan),a
        ret

; B - элемент -> D - ширина на экране
Item_Width
        ld a,b
        and 3
        ld d,W_ENV_CLOSED
        jr z,$+4
        ld d,W_CH_CLOSED
        ld a,(Open_Item)
        cp b
        ret nz
        ld a,d                      ; открыт: Env 7->13, канал 8->18
        cp W_ENV_CLOSED
        ld d,W_ENV_OPEN
        ret z
        ld d,W_CH_OPEN
        ret

;-------- Черепицы раскладки -> числа в прямой код Tile_0..2 (Tile_Run).
; Ничего не открыто: 1 черепица - весь блок закрытых частей.
; Открыт элемент k: блок до него включительно, его расширение, блок после него
; (со сдвигом на ширину расширения). Неиспользуемые черепицы отрезаются "ret".
Build_Tiles
        ld ix,Tile_0
        ld a,(Open_Item)
        cp ITEM_NONE
        jr nz,.open
        ld a,(Blk_End)              ; весь блок видимых элементов
        sub CONT_X
        ld d,a
        ld e,CONT_X
        ld c,TX_BLOCK
        call Set_Tile
        ld a,#C9                    ; Tile_1, Tile_2 - не нужны
        ld (Tile_1),a
        ret

.open   ld b,a                      ; B - открытый элемент
        ld hl,Item_CX               ; конец его закрытой части при "всё закрыто"
        call Arr_Get
        ld c,a
        ld a,b
        and 3
        ld a,W_ENV_CLOSED
        jr z,$+4
        ld a,W_CH_CLOSED
        add a,c
        ld (BT_End),a
        ; 1) блок от начала до конца закрытой части открытого
        sub CONT_X
        ld d,a
        ld e,CONT_X
        ld c,TX_BLOCK
        call Set_Tile
        ; 2) расширение открытого - сразу за его закрытой частью
        ld a,b
        ld hl,Item_EX
        call Arr_Get
        ld c,a
        ld a,b
        and 3
        ld d,W_ENV_EXT
        jr z,$+4
        ld d,W_CH_EXT
        ld a,(BT_End)
        ld e,a
        ld ix,Tile_1
        call Set_Tile
        ; 3) блок после открытого: с его разделителя до правой рамки, сдвинут на
        ;    ширину расширения. У последнего элемента (F) - нечего
        ld a,(BT_End)
        ld hl,Blk_End
        cp (hl)
        jr nc,.last
        ld e,a                      ; колонка в блоке
        sub CONT_X
        add a,TX_BLOCK
        ld c,a
        ld a,(Blk_End)
        sub e
        ld h,a                      ; H - ширина
        ld a,e
        add a,d                     ; + ширина расширения (D ещё от п.2)
        ld e,a
        ld d,h
        ld ix,Tile_2
        call Set_Tile
        ld a,#CD                    ; все три в работе
        ld (Tile_1),a
        ld (Tile_2),a
        ret
.last   ld a,#CD
        ld (Tile_1),a
        ld a,#C9                    ; Tile_2 - не нужна
        ld (Tile_2),a
        ret

BT_End          db 0

; Черепица IX: E - колонка экрана, D - ширина, C - колонка в тексте.
; DMA ходит словами: нечётное начало - на знак ВПРАВО (там пробел-разделитель: его
; даёт хвост соседней черепицы, рамку рисует Draw_Seps), длина - вверх до целых слов.
; Влево нельзя: слева у черепиц за открытым элементом - его последнее поле (громкость)
Set_Tile
        ld a,e
        and 1                       ; H - сдвиг до чётного
        ld h,a
        ld a,c
        add a,h
        ld (ix+TILE_SCOL),a         ; колонка в тексте
        ld a,e
        add a,h
        ld (ix+TILE_DCOL),a         ; колонка на экране
        ld a,d                      ; слов-1 = (ширина - сдвиг + 1) / 2 - 1
        sub h
        inc a
        srl a
        dec a
        ld (ix+TILE_LEN),a
        ret

Add_Sep
        push af
        ld a,(Seps_N)
        ld c,a
        add a,a
        ld hl,Seps
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),e
        inc hl
        pop af
        ld (hl),a
        ld a,c
        ld hl,Sep_Attr
        push de
        ld e,d
        call Arr_Set_E
        pop de
        ld hl,Seps_N
        inc (hl)
        ret

; A - индекс, HL - массив, E - значение
Arr_Set_E
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),e
        ret

;-------- Шаблоны в строках 36..38 текстовой страницы (окно 3):
; символы строки 36 - пустая роу: пробелы и разделители;
; атрибуты 36 - тусклый (всё CLR_EMPTY), 37 - активный (цвета полей), 38 - строка
; редактирования (всё CLR_EDIT_ROW). Разделители - своим цветом в 36 и 37.
Build_Templates
        ld h,SCR_BASE_H+TPL_LINE    ; символы: пробелы
        ld l,0
        ld b,LINE_W
        ld a,' '
.c      ld (hl),a
        inc l
        djnz .c
        ld a,(THEME_ATTR+CLR_BG)    ; атрибуты трёх шаблонов - фон
        ld c,a
        ld h,SCR_BASE_H+TPL_LINE+ST_BASE
        call .fill
        ld h,SCR_BASE_H+TPL_LINE+ST_ACTIVE
        call .fill
        ld h,SCR_BASE_H+TPL_LINE+ST_EDIT   ; (правее рамки - фон, а не прошлая раскладка)
        call .fill
        ld a,(THEME_ATTR+CLR_EDIT_ROW)  ; строка редактирования - один цвет
        ld c,a
        ld h,SCR_BASE_H+TPL_LINE+ST_EDIT
        ld l,DRAW_X0+SCR_ATTR
        ld a,(Lay_End)
        sub DRAW_X0-1
        ld b,a
.e      ld (hl),c
        inc l
        djnz .e
        ; --- тусклый: всё от номера роу до правой рамки - CLR_EMPTY
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld c,a
        ld h,SCR_BASE_H+TPL_LINE+ST_BASE
        ld l,ROWNUM_X+SCR_ATTR
        ld a,(Lay_End)
        sub ROWNUM_X-1
        ld b,a
.d      ld (hl),c
        inc l
        djnz .d
        ; --- активный: поля по ролям
        ld b,0
.it     push bc
        ld a,b
        ld hl,Item_Col
        call Arr_Get
        add a,SCR_ATTR
        ld e,a
        ld d,SCR_BASE_H+TPL_LINE+ST_ACTIVE
        ld a,b                      ; описание полей: Env/канал, закрыт/открыт
        and 3
        ld hl,D_Env0
        jr z,$+5
        ld hl,D_Ch0
        ld a,(Open_Item)
        cp b
        jr nz,.f
        ld a,b
        and 3
        ld hl,D_Env1
        jr z,.f
        ld hl,D_Ch1
.f      ld a,(hl)                   ; ширина, роль; конец - 0
        or a
        jr z,.fe
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        add a,low THEME_ATTR
        ld l,a
        ld h,high THEME_ATTR
        ld a,(hl)
        pop hl
.fw     ld (de),a
        inc e
        djnz .fw
        jr .f
.fe     pop bc
        inc b
        ld a,b
        ld hl,Vis_Items             ; только видимые элементы
        cp (hl)
        jr c,.it
        ; --- номер роу в активном: тусклым (свой цвет ставит Draw_Seps)
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld ((SCR_BASE_H+TPL_LINE+ST_ACTIVE)*256+ROWNUM_X+SCR_ATTR),a
        ld ((SCR_BASE_H+TPL_LINE+ST_ACTIVE)*256+ROWNUM_X+1+SCR_ATTR),a
        ; --- разделители: символ в строку пустой роу, цвет в оба шаблона
        ld hl,Seps
        ld a,(Seps_N)
        ld b,a
        ld c,0
.s      ld e,(hl)                   ; колонка
        inc hl
        ld a,(hl)                   ; символ
        inc hl
        push hl
        ld h,SCR_BASE_H+TPL_LINE
        ld l,e
        ld (hl),a
        ld a,c
        ld hl,Sep_Attr
        call Arr_Get
        add a,low THEME_ATTR
        ld l,a
        ld h,high THEME_ATTR
        ld a,(hl)
        ld h,SCR_BASE_H+TPL_LINE+ST_BASE
        set 7,e
        ld l,e
        ld (hl),a
        inc h
        ld (hl),a
        pop hl
        inc c
        djnz .s
        ; --- строки 36..38 -> строка 0 страниц шаблонов (символы и атрибуты целиком);
        ;     на строки 1..26 их размножит IM1 одной DMA на страницу (Tpl_Replicate)
        SETPAGE2 PAGE_VIEW_TPL+ST_BASE
        ld hl,(SCR_BASE_H+TPL_LINE+ST_BASE)*256
        call .line0
        RESTPAGE2
        SETPAGE2 PAGE_VIEW_TPL+ST_ACTIVE
        ld hl,(SCR_BASE_H+TPL_LINE+ST_ACTIVE)*256
        call .line0
        RESTPAGE2
        SETPAGE2 PAGE_VIEW_TPL+ST_EDIT
        ld hl,(SCR_BASE_H+TPL_LINE+ST_EDIT)*256
        call .line0
        RESTPAGE2
        ld a,1
        ld (Tpl_Repl),a
        ret
.line0  ld de,PAT_BASE_H*256        ; страница шаблона - в окне 2, строка 0
        ld bc,256
        ldir
        ret

.fill   ld l,SCR_ATTR               ; H - строка, C - цвет: все атрибуты
        ld b,LINE_W
.ff     ld (hl),c
        inc l
        djnz .ff
        ret

; Поля элемента по ролям: ширина, роль (CLR_BG - промежуток). Конец - 0
D_Env0          db 4,CLR_ENVPER, 1,CLR_BG, 2,CLR_NOISE, 0
D_Env1          db 4,CLR_ENVPER, 1,CLR_BG, 2,CLR_NOISE, 1,CLR_BG, 4,CLR_ENVPER, 1,CLR_BG, 0
D_Ch0           db 3,CLR_NOTE, 1,CLR_BG, 1,CLR_INSTR, 1,CLR_ENVSHAPE, 1,CLR_ORNAMENT, 1,CLR_VOLUME, 0
D_Ch1           db 3,CLR_NOTE, 1,CLR_BG, 1,CLR_INSTR, 1,CLR_ENVSHAPE, 1,CLR_ORNAMENT, 1,CLR_VOLUME
                db 1,CLR_BG, 4,CLR_CMD, 1,CLR_BG, 4,CLR_CMD, 0

; =========================================================================
; РАМКИ И ПОДПИСИ (строки 7 и 35), при смене раскладки
; =========================================================================
Draw_Frame
        ld a,(THEME_ATTR+CLR_HEAD_LINE) ; верх - полоса заголовков: цвета шапки
        ld (HL_Line),a
        ld a,(THEME_ATTR+CLR_HEAD_BG)
        ld (HL_Out),a
        ld a,BOX_TL                 ; ┌──┬──┐
        ld (HL_CornerL),a
        ld a,BOX_TR
        ld (HL_CornerR),a
        ld a,BOX_DOWN
        ld (HL_Junction),a
        ld a,BOX_DOWN2
        ld (HL_Junction2),a
        ld d,SCR_BASE_H+VIEW_LINE
        call Draw_HLine
        ld a,(THEME_ATTR+CLR_TITLE)  ; низ - обычные цвета
        ld (HL_Line),a
        ld a,(THEME_ATTR+CLR_BG)
        ld (HL_Out),a
        ld a,BOX_BL                 ; └──┴──┘
        ld (HL_CornerL),a
        ld a,BOX_BR
        ld (HL_CornerR),a
        ld a,BOX_UP
        ld (HL_Junction),a
        ld a,BOX_UP2
        ld (HL_Junction2),a
        ld d,SCR_BASE_H+BOTTOM_LINE
        call Draw_HLine

        ld hl,F_Order               ; "Ord" - ярче, когда ордер в фокусе
        call Is_Focus
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_HEAD_HI)
        ld c,a
        ld d,SCR_BASE_H+VIEW_LINE
        ld e,ORD_X+1
        ld hl,Txt_Order
        call PutStr
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)    ; остальные подписи
        ld c,a
        ld e,ROWNUM_X
        ld hl,Txt_Rw
        call PutStr
        ld b,0
.t      push bc
        ld a,b                      ; подпись элемента
        ld hl,Item_Col
        call Arr_Get
        ld e,a
        ld a,b
        and 3
        ld hl,Txt_Env
        jr z,.p
        ld a,b                      ; элемент -> буква канала: 1..3 -> A..C, 5..7 -> D..F
        cp 4
        jr c,$+3
        dec a
        add a,'A'-1
        ld (Txt_Ch_L),a
        ld hl,Txt_Ch
.p      push hl                     ; паттерн не в фокусе - выделенного заголовка нет
        ld hl,F_Pat
        call Is_Focus
        pop hl
        ld a,ITEM_NONE
        jr nz,$+5
        ld a,(Cursor_Item)          ; элемент под курсором - заголовок ярче (фокус)
        cp b
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_HEAD_HI)
        ld c,a
        call PutStr
        pop bc
        push bc
        ld a,b                      ; кнопка [+] / [-] - двумя последними знаками элемента
        ld hl,Item_Col
        call Arr_Get
        ld e,a
        ld a,b
        ld hl,Item_W
        call Arr_Get
        add a,e
        sub 2
        ld e,a
        ld a,(Open_Item)
        cp b
        ld a,GLYPH_BTN_PLUS
        jr nz,$+4
        ld a,GLYPH_BTN_MINUS
        call PutBtn_Head
        pop bc
        inc b
        ld a,b
        ld hl,Vis_Items             ; только видимые элементы
        cp (hl)
        jr c,.t
        ret

Txt_Order       db "Order",0
Txt_Rw          db "Rw",0
Txt_Env         db "Env",0
Txt_Ch          db "Ch:"
Txt_Ch_L        db "A",0

; D - строка. Стыки - под разделителями строки-шаблона (символы строки 36)
Draw_HLine
        ld h,SCR_BASE_H+TPL_LINE
        ld e,0
.l      ld a,(HL_Line)
        ld c,a
        ld a,e
        or a
        jr z,.cl
        ld a,(Lay_End)
        cp e
        jr z,.cr
        jr c,.out                   ; правее рамки - пусто
        ld l,e
        ld a,(hl)
        cp BOX_V2
        jr z,.j2
        cp BOX_V
        ld a,BOX_H
        jr nz,.put
        ld a,(HL_Junction)
        jr .put
.j2     ld a,(HL_Junction2)
        jr .put
.cl     ld a,(HL_CornerL)
        jr .put
.cr     ld a,(HL_CornerR)
        jr .put
.out    ld a,(HL_Out)
        ld c,a
        ld a,' '
.put    call PutCh
        ld a,e
        cp LINE_W
        jr c,.l
        ret

HL_Line         db 0                ; цвет линии и подписей рамки (Draw_Frame)
HL_Out          db 0                ; цвет правее рамки
HL_CornerL      db 0
HL_CornerR      db 0
HL_Junction     db 0
HL_Junction2    db 0

;-------- Ордер-лист прямо на экран (колонки 0..5), при смене позиции.
; "│r05", у текущей позиции вместо левой линии - "►". За концом - "│   ".
; Колонки 4..5 - пробелы, у текущей позиции - кнопки ордера (│ в колонке 6 -
; разделитель, его рисует IM1)
Draw_Order
        xor a
        ld (Order_Pending),a
        ld d,SCR_BASE_H+FIRST_LINE
        ld a,(Cur_Pos)
        sub VIEW_CENTER
        ld b,a                      ; B - позиция
        ld a,VIEW_ROWS
.l      push af
        ld e,ORD_X
        ld a,(Cur_Pos)              ; линия или стрелка текущей
        cp b
        jr z,.cur
        call PutBar
        jr .item
.cur    ld a,(THEME_ATTR+CLR_ORD_CUR)
        ld c,a
        ld a,ARROW_R
        call PutCh
.item   ld a,(Ord_Last)
        cp b
        jr nc,.pos
        ld a,(THEME_ATTR+CLR_BG)    ; за концом - пусто
        ld c,a
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        jr .bar
.pos    ld a,(THEME_ATTR+CLR_LOOP)  ; r - позиция повтора
        ld c,a
        ld a,(Loop_Pos)
        cp b
        ld a,' '
        jr nz,$+4
        ld a,'r'
        call PutCh
        ld a,(THEME_ATTR+CLR_PATNUM)
        ld c,a
        ld a,b
        ld hl,Ord_List
        call Arr_Get
        call PutHex2
.bar    ld a,(THEME_ATTR+CLR_BG)    ; место кнопок - пусто
        ld c,a
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        inc d
        inc b
        pop af
        dec a
        jp nz,.l
        ld b,0                      ; кнопки - у текущей позиции (она в центре)
.btn    ld a,b
        ld hl,OB_Row
        call Arr_Get
        add a,SCR_BASE_H
        ld d,a
        ld e,ORD_BTN_X
        ld a,b
        ld hl,OB_Glyph
        call Arr_Get
        call PutBtn
        inc b
        ld a,b
        cp ORD_BTNS
        jr c,.btn
        ret

; Кнопки ордера (как в Bitphase): строка экрана, значок, действие
ORD_BTNS        equ 4
OB_ID           equ ITEMS           ; номера кнопок мыши: 0..7 - элементы, дальше ордер
OB_Row          db EDIT_LINE-2, EDIT_LINE-1, EDIT_LINE+1, EDIT_LINE+2
OB_Glyph        db GLYPH_BTN_UNIQUE, GLYPH_BTN_MINUS, GLYPH_BTN_PLUS, GLYPH_BTN_CLONE
OB_Act          dw O_Unique, O_Remove, O_Add, O_Clone

; =========================================================================
; ТАБЛИЦА РОУ: на каждую экранную строку 3 байта - страница паттерна,
; #80+роу, состояние (ST_BASE / ST_ACTIVE). Страница 0 - роу пустая.
; Активный = роу текущей позиции в текущем проходе. Строится в свободный буфер,
; указатель меняется одной командой - IM1 всегда видит целую таблицу.
; =========================================================================
Row_Tab_A       ds VIEW_ROWS*3
Row_Tab_B       ds VIEW_ROWS*3
Row_Tab_Show    dw Row_Tab_A        ; по ней рисует IM1
Row_Tab_Build   dw Row_Tab_B        ; эту строим

T_Pos           db 0                ; позиция и роу, по которым идём
T_Row           db 0
T_Pass          db 0                ; проход: 0 - текущий, +-1 - соседние
T_Dead          db 0                ; 1 - дальше пусто

Build_Row_Tab
        ld ix,(Row_Tab_Build)       ; IX - запись текущей роу (центр)
        ld de,VIEW_CENTER*3
        add ix,de
        push ix
        call T_From_Cur
        call Put_Entry
        ld b,VIEW_CENTER            ; вверх от текущей
.up     push bc
        ld de,-3
        add ix,de
        call Step_Back
        call Put_Entry
        pop bc
        djnz .up
        pop ix                      ; вниз от текущей
        call T_From_Cur
        ld b,VIEW_ROWS-1-VIEW_CENTER
.dn     push bc
        ld de,3
        add ix,de
        call Step_Fwd
        call Put_Entry
        pop bc
        djnz .dn
        ld hl,(Row_Tab_Show)        ; готово - меняем местами
        ld de,(Row_Tab_Build)
        ld (Row_Tab_Show),de        ; одна команда - IM1 не застанет половину
        ld (Row_Tab_Build),hl
        ret

T_From_Cur
        ld a,(Cur_Pos)
        ld (T_Pos),a
        ld a,(Cur_Row)
        ld (T_Row),a
        xor a
        ld (T_Pass),a
        ld (T_Dead),a
        ret

; (IX) = запись для T_Pos/T_Row, или пусто
Put_Entry
        ld a,(T_Dead)
        or a
        jr z,.ok
        ld (ix+0),0
        ret
.ok     call T_Pat
        call Pat_Page
        ld (ix+0),a
        ld a,(T_Row)
        add a,PAT_BASE_H
        ld (ix+1),a
        ld a,(T_Pass)               ; активный - только текущая позиция в текущем проходе
        or a
        ld a,ST_BASE
        jr nz,.st
        ld a,(Cur_Pos)
        ld b,a
        ld a,(T_Pos)
        cp b
        ld a,ST_BASE
        jr nz,.st
        ld a,ST_ACTIVE
.st     ld (ix+2),a
        ret

T_Pat                               ; A = паттерн позиции T_Pos. Портит HL
        ld a,(T_Pos)
        ld hl,Ord_List
        jp Arr_Get

T_Len                               ; A = длина паттерна позиции T_Pos. Портит HL
        call T_Pat
        ld hl,Pat_Len
        jp Arr_Get

; Роу назад. Сонг: в конец предыдущей позиции, до нулевой. Паттерн по кругу:
; в конец того же паттерна, проход -1; выше первого прохода плея - пусто
Step_Back
        ld a,(T_Dead)
        or a
        ret nz
        ld a,(T_Row)
        or a
        jr z,.edge
        dec a
        ld (T_Row),a
        ret
.edge   ld a,(SV_PLAY_STATE)        ; паттерн по кругу - или по ордеру (стоп, сонг)
        cp PS_PATTERN
        jr nz,.song
        ld a,(Pat_Loops)            ; паттерн: проходы до первого - пусто
        ld b,a
        ld a,(T_Pass)
        add a,b
        jr z,T_Kill
        ld hl,T_Pass
        dec (hl)
        jr .last
.song   ld a,(T_Pos)
        or a
        jr z,T_Kill
        dec a
        ld (T_Pos),a
        ld hl,T_Pass                ; другая позиция - уже не активная
        dec (hl)
.last   call T_Len
        dec a
        ld (T_Row),a
        ret

T_Kill  ld a,1
        ld (T_Dead),a
        ret

; Роу вперёд. Сонг: на начало следующей позиции, после последней - на позицию
; повтора. Паттерн по кругу: на начало того же, проход +1
Step_Fwd
        ld a,(T_Dead)
        or a
        ret nz
        ld a,(T_Row)
        inc a
        ld (T_Row),a
        ld b,a
        call T_Len
        ld c,a
        ld a,b
        cp c
        ret c                       ; ещё внутри паттерна
        xor a
        ld (T_Row),a
        ld hl,T_Pass                ; другой проход/позиция - не активный
        inc (hl)
        ld a,(SV_PLAY_STATE)
        cp PS_PATTERN
        ret z                       ; паттерн по кругу
        ld a,(Ord_Last)
        ld b,a
        ld a,(T_Pos)
        inc a
        cp b
        jr c,.pos
        jr z,.pos
        ld a,(Loop_Pos)
.pos    ld (T_Pos),a
        ret

; =========================================================================
; ТЕКСТ РОУ в странице паттерна. H - роу (страница - в окне 2).
; По таблице полей Txt_Fields: тип, смещение данных, колонка текста.
; Пробелы между полями кладёт Init_Pat_Text один раз.
; =========================================================================
F_HEX16         equ 1               ; 2 байта, старший первым, 4 hex; 0 - "...."
F_NOISE         equ 2               ; 1 байт, 2 hex; 0 - ".."
F_NOTE          equ 3               ; нота, 3 знака
F_SYM           equ 4               ; сэмпл, 1 знак (1..W)
F_HX1           equ 5               ; огибающая/громкость, 1 hex
F_CMD           equ 6               ; команда: 2 байта как лежат, 4 hex; 0,0 - "...."
F_ORN           equ 8               ; орнамент, 1 знак: номер+1 (0..W), 0 - "."
F_ENVP          equ 7               ; период огибающей: 4 hex, а в режиме Env_As_Note -
                                    ; нота (CHIP_ENVNOTE) "E-4 ", если она есть

    ; Поле: тип, смещение данных в роу, колонка текста в строке страницы.
    ; Закрытые части - в блоке (TX_BLOCK + экранная колонка при "всё закрыто" -
    ; CONT_X), расширения - на своих местах EX_*.
    MACRO TXT_ENV src,cx,ex             ; Env: "0134 1F" + расширение " 0000 "
        db F_ENVP,  (src)+CHIP_ENVPER, TX_BLOCK+(cx)-CONT_X
        db F_NOISE, (src)+CHIP_NOISE,  TX_BLOCK+(cx)-CONT_X+5
        db F_HEX16, (src)+CHIP_ENV2,   (ex)+1
    ENDM
    MACRO TXT_CH src,cx,ex              ; канал: "C-4 A1FE" + расширение " 1234 5678"
        db F_NOTE, (src)+CH_NOTE,      TX_BLOCK+(cx)-CONT_X
        db F_SYM,  (src)+CH_SAMPLE,    TX_BLOCK+(cx)-CONT_X+4
        db F_HX1,  (src)+CH_ENVSHAPE,  TX_BLOCK+(cx)-CONT_X+5
        db F_ORN,  (src)+CH_ORNAMENT,  TX_BLOCK+(cx)-CONT_X+6
        db F_HX1,  (src)+CH_VOLUME,    TX_BLOCK+(cx)-CONT_X+7
        db F_CMD,  (src)+CH_CMD,       (ex)+1
        db F_CMD,  (src)+CH_CMD+CMD_SIZE, (ex)+6
    ENDM

Txt_Fields
        TXT_ENV 0,                      CX_ENV1, EX_ENV1
        TXT_CH  CHIP_CH_A,              CX_A,    EX_A
        TXT_CH  CHIP_CH_B,              CX_B,    EX_B
        TXT_CH  CHIP_CH_C,              CX_C,    EX_C
        TXT_ENV CHIP_SIZE,              CX_ENV2, EX_ENV2
        TXT_CH  CHIP_SIZE+CHIP_CH_A,    CX_D,    EX_D
        TXT_CH  CHIP_SIZE+CHIP_CH_B,    CX_E,    EX_E
        TXT_CH  CHIP_SIZE+CHIP_CH_C,    CX_F,    EX_F
        db 0

; H - роу. Портит всё, кроме H
Row_To_Text
        ld ix,Txt_Fields
; H - роу, IX - таблица полей (как Txt_Fields). Портит всё, кроме H
Row_Fields
.f      ld a,(ix+0)                 ; тип, 0 - конец
        or a
        ret z
        ld l,(ix+1)                 ; данные: C - байт, B - следующий
        ld c,(hl)
        inc l
        ld b,(hl)
        ld l,(ix+2)                 ; L - куда текст
        inc ix
        inc ix
        inc ix
        dec a
        jr z,.hex16
        dec a
        jr z,.noise
        dec a
        jr z,.note
        dec a
        jr z,.sym
        dec a
        jr z,.hx1
        dec a
        jr z,.cmd
        dec a
        jp z,.envp
        ld a,c                      ; орнамент: номер+1 - 0 ".", 1 "0", дальше 1..W
        or a
        jr z,.sym
        dec c
        jr nz,.sym
        ld (hl),'0'
        jr .f
.cmd    ld a,b                      ; команда: байт C, потом B
        or c
        jr z,.dots4
        ld a,c
        call Txt_Hex2
        ld a,b
        call Txt_Hex2
        jr .f
.hex16  ld a,b                      ; 16 бит: старший B, потом младший C
        or c
        jr z,.dots4
        ld a,b
        call Txt_Hex2
        ld a,c
        call Txt_Hex2
        jr .f
.dots4  ld a,'.'
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        jr .f
.noise  ld e,c                      ; 2 знака из HexD_T (0 - "..")
        ld d,high HexD_T
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        jr .f
.note   ld e,c                      ; 3 знака из Note_T
        ld d,high Note_T
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        jr .f
.sym    ld e,c
        ld d,high Sym_T
        ld a,(de)
        ld (hl),a
        jp .f
.hx1    ld e,c
        ld d,high Hx1_T
        ld a,(de)
        ld (hl),a
        jp .f
.envp   ld a,(Env_As_Note)          ; период огибающей: режим нот выключен - 4 hex
        or a
        jr z,.hex16
        ld e,l                      ; нота огибающей - в том же чипе, CHIP_ENVNOTE
        ld a,(ix-2)                 ; (смещение данных этого поля - запись уже пройдена)
        add a,CHIP_ENVNOTE-CHIP_ENVPER
        ld l,a
        ld a,(hl)
        ld l,e
        or a
        jr z,.hex16                 ; ноты нет (период вводили числом) - 4 hex
        ld e,a                      ; "E-4 ": 3 знака из Note_T и пробел
        ld d,high Note_T
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        inc l
        ld (hl),' '
        jp .f

; A -> 2 hex в (HL), L += 2. Портит DE
Txt_Hex2
        ld e,a
        ld d,high Hex_T
        ld a,(de)
        ld (hl),a
        inc l
        inc d
        ld a,(de)
        ld (hl),a
        inc l
        ret

; Паттерн в окне 2: текст всех 64 роу - пробелы, номер роу, поля
Init_Pat_Text
        ld h,PAT_BASE_H
.r      ld l,PAT_TEXT               ; пробелы
        ld a,' '
.s      ld (hl),a
        inc l
        jr nz,.s
        call Row_To_Text
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        ret

;-------- Страница номеров роу: строка r, колонки ROWNUM_X..+1 = "rr". Одна на
; всех: номер роу на экран идёт черепицей отсюда, а не из страницы паттерна
Init_RowNum
        SETPAGE2 PAGE_ROWNUM
        ld h,PAT_BASE_H
.r      ld a,h
        sub PAT_BASE_H
        ld l,ROWNUM_X
        call Txt_Hex2
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        RESTPAGE2
        ret

; =========================================================================
; ВВОД
; =========================================================================
; Горячие клавиши вида паттерна: действие (ACT_*, клавиши к нему - Bind_Tab в коре),
; обработчик. Конец - 0. Автоповтор даёт коре (Key_Get).

Hotkeys db ACT_PLAY_SONG           ; общие действия вида (F5..F8, Esc - как в VT)
        dw K_PlaySong               ; сонг с текущей позиции
        db ACT_PLAY_START
        dw K_PlayStart              ; сонг с начала
        db ACT_PLAY_ROW
        dw K_PlayPatRow             ; паттерн с текущей роу
        db ACT_PLAY_PAT
        dw K_PlayPat                ; паттерн с начала
        db ACT_STOP
        dw K_Stop
        db ACT_ENV_OPEN
        dw K_EnvOpen                ; открыть Env чипа
        db ACT_ENV_NOTE
        dw K_EnvNote                ; период огибающей нотой / числом
        db ACT_TIMING
        dw K_Timing                 ; полоса времени
        db 0

;-------- Нижняя строка справа: "Free: NN pages" - свободные страницы (постоянное число)
MEM_X           equ 90-15
Mem_Show
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,MEM_X+256*(SCR_BASE_H+BOTTOM_LINE)
        ld hl,Txt_Free
        jp PutStr

;-------- Все события клавиатуры за кадр: сначала полю в фокусе (навигация
; паттерна или ордера), не съело - общей таблице Hotkeys
Handle_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld b,a
        ld (HK_Code),bc
        call Fld_Key                ; полю в фокусе
        jr c,.k
        ld bc,(HK_Code)
        ld hl,Hotkeys
        call Keys_Table
        jr .k
HK_Code         dw 0

; Роу курсора: по полотну (сонг) или по кругу (плей паттерна)
K_RowUp call T_From_Cur
        call Step_Back
        jr T_To_Cur
K_RowDn call T_From_Cur
        call Step_Fwd
T_To_Cur
        ld a,(T_Dead)
        or a
        ret nz
        ld a,(T_Pass)               ; плей паттерна: прошёл круг
        ld hl,Pat_Loops
        add a,(hl)
        ld (hl),a
        ld a,(T_Row)
        ld (Cur_Row),a
        ld a,(T_Pos)
        ld hl,Cur_Pos
        cp (hl)
        ret z
        ld (hl),a
        ld a,1                      ; позиция сменилась - перерисовать ордер
        ld (Order_Pending),a
        ret

PAGE_ROWS       equ 16              ; PgUp/PgDn - на столько роу (по полотну)
K_PageUp
        ld b,PAGE_ROWS
.l      push bc
        call K_RowUp
        pop bc
        djnz .l
        ret
K_PageDn
        ld b,PAGE_ROWS
.l      push bc
        call K_RowDn
        pop bc
        djnz .l
        ret

K_ChLeft
        ld a,(Cur_Chan)
        or a
        ret z
        dec a
        jr Set_Chan
K_ChRight
        ld a,(Cur_Chan)
        ld hl,Ch_Last               ; последний канал: 5 или 2 (1 чип)
        cp (hl)
        ret nc
        inc a
Set_Chan
        ld (Cur_Chan),a
        xor a
        ld (Env_Open),a
        ld (Cur_Field),a
Need_Layout
        ld a,1
        ld (Layout_Pending),a
        ret
K_EnvOpen
        ld hl,Env_Open
        ld a,(hl)
        xor 1
        ld (hl),a
        xor a                       ; курсор - на первое поле
        ld (Cur_Field),a
        jr Need_Layout

;-------- Влево / вправо: поле курсора; за краем элемента - соседний элемент (как в VT)
K_FieldLeft
        ld a,(Cur_Field)
        or a
        jr z,.prev
        dec a
        ld (Cur_Field),a
        ret
.prev   ld a,(Cursor_Item)          ; предыдущий элемент - на его последнее поле
        or a
        ret z
        dec a
        call Item_Go
        call Fields_N
        dec a
        ld (Cur_Field),a
        ret
K_FieldRight
        call Fields_N
        dec a
        ld hl,Cur_Field
        cp (hl)
        jr z,.next
        inc (hl)
        ret
.next   ld a,(Vis_Items)            ; следующий элемент - на первое поле
        dec a
        ld hl,Cursor_Item
        cp (hl)
        ret z
        ld a,(hl)
        inc a
        call Item_Go
        xor a
        ld (Cur_Field),a
        ret

; A - сколько полей у элемента под курсором (по Env_Open)
Fields_N
        ld a,(Env_Open)
        or a
        ld a,CF_CHAN_N
        ret z
        ld a,CF_ENV_N
        ret

; A - элемент 0..7 (Env1, A, B, C, Env2, D, E, F) -> курсор на нём, раскладка - заново
Item_Go
        ld b,a
        and 3
        jr nz,.ch
        ld a,b                      ; Env чипа: канал - первый этого чипа (0 или 3)
        rrca
        ld c,a
        rrca
        add a,c
        ld (Cur_Chan),a
        ld a,1
        ld (Env_Open),a
        jr Need_Layout
.ch     ld a,b                      ; канал: 1..3 -> 0..2, 5..7 -> 3..5
        dec a
        cp 4
        jr c,$+3
        dec a
        ld (Cur_Chan),a
        xor a
        ld (Env_Open),a
        jr Need_Layout

;-------- Огибающая нотой: переключить режим и переписать текст периода огибающей
; (только эти 2 поля) во всех роу всех паттернов. Экран сам подхватит со
; следующего кадра - он из текста страниц.
ER_Pat          db 0                ; номер паттерна - в памяти: SETPAGE через стек

K_EnvNote
        ld hl,Env_As_Note
        ld a,(hl)
        xor 1
        ld (hl),a
        xor a
        ld (ER_Pat),a
.p      ld a,(ER_Pat)               ; паттерн есть?
        ld hl,Pat_Exists
        call Arr_Get
        or a
        jr z,.next
        ld a,(ER_Pat)
        call Pat_Page
        SETPAGE2 a
        ld h,PAT_BASE_H             ; все роу
.r      ld ix,Txt_EnvP
        call Row_Fields
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        RESTPAGE2
.next   ld hl,ER_Pat
        inc (hl)
        ld a,(hl)
        cp PATTERNS_MAX
        jr c,.p
        ret

; Поля периода огибающей обоих чипов (для K_EnvNote)
Txt_EnvP
        db F_ENVP, CHIP_ENVPER,           TX_BLOCK+CX_ENV1-CONT_X
        db F_ENVP, CHIP_SIZE+CHIP_ENVPER, TX_BLOCK+CX_ENV2-CONT_X
        db 0

; Плей / стоп - как в VT
K_PlayStart                         ; сонг с первой позиции
        xor a
        ld (Cur_Pos),a
        inc a                       ; позиция сменилась - перерисовать ордер
        ld (Order_Pending),a
; Играет ли и что - только у плеера (SV_PLAY_STATE), своих копий у вида нет
K_PlaySong                          ; сонг с начала текущей позиции
        ld a,PC_SONG
        jr Play_From0
K_PlayPat                           ; текущий паттерн по кругу с начала
        ld a,PC_PATTERN
Play_From0
        ld b,a
        xor a
        ld (Cur_Row),a
        ld a,b
        jr Play_Go
K_PlayPatRow                        ; текущий паттерн по кругу с текущей роу
        ld a,PC_PATTERN
        jr Play_Go
K_Continue                          ; продолжить сонг с текущего места (для кнопки)
        ld a,PC_SONG
; A - команда плееру (PC_SONG / PC_PATTERN), откуда - Cur_Pos, Cur_Row
Play_Go
        ld (Play_Cmd),a
        xor a
        ld (Pat_Loops),a
        ld (Play_Tick),a
        call Time_Reset             ; время игры - с нуля
        ld a,(Cur_Pos)              ; команда плееру: откуда (сначала параметры,
        ld (SV_PLAY_CPOS),a         ; команда - последней: IM1 может влезть)
        ld a,(Cur_Row)
        ld (SV_PLAY_CROW),a
        ld a,(Play_Cmd)
        ld (SV_PLAY_CMD),a
        ret
K_Stop  xor a                       ; стоп: остаёмся где стоим, полотно - по ордеру
        ld (Pat_Loops),a
        ld a,PC_STOP
        ld (SV_PLAY_CMD),a
        ret

Play_Cmd        db 0

K_Timing
        ld hl,Timing
        ld a,(hl)
        xor 1
        ld (hl),a
        jr nz,Int_Line_Set
        ld (hl),1                   ; выключили - вернуть обычный фон
        xor a
        call Band_Main
        xor a
        ld (Timing),a

; С полосой времени INT - на первой видимой строке растра, иначе цвета IM1
; уходят в гашение (строки 0..31) и их не видно. Без полосы - на месте (0).
INT_LINE_VISIBLE equ 32
Int_Line_Set
        ld a,(Timing)
        or a
        jr z,$+4
        ld a,INT_LINE_VISIBLE
        ld bc,VSINTL
        out (c),a
        xor a
        ld bc,VSINTH
        out (c),a
        ret

; =========================================================================
; ПОЛЯ ВИДА ПАТТЕРНА (коре: srs/fields.asm). Мышь и фокус - через поля:
;   ордер    - колонки 0..5: фокус, клик по позиции, колесо и стрелки - позиции;
;              дети - 4 кнопки ордера;
;   заголовки - строка 7: дети - кнопки [+]/[-] элементов (строит Build_Layout);
;   паттерн  - фокус, колесо (с Ctrl/Shift - каналы), навигационные клавиши.
; Кнопки - как в Windows: нажал - вдавлена, увёл мышь - отжалась, вернул -
; снова вдавлена, отпустил над ней - сработала.
; =========================================================================
    MACRO FIELD x,y,w,h,flags,handler,kids,param
        db x,y,w,h,flags,PAGE_TOOL_PATVIEW
        dw handler,kids,param
    ENDM

Pv_Fields
        FIELD 0,0,LINE_W,VIEW_LINE, 0, 0, Head_Fields, 0     ; шапка (srs/head.asm), строки 0..6
F_Order FIELD ORD_X,FIRST_LINE,DRAW_X0,VIEW_ROWS, FF_FOCUS, Ord_Field, Ord_Kids, 0
        FIELD 0,VIEW_LINE,LINE_W,1,                0,        0,         Head_Kids, 0
F_Pat   FIELD DRAW_X0,FIRST_LINE,DRAW_X1-DRAW_X0,VIEW_ROWS, FF_FOCUS, Pat_Field, 0, 0
        db FLD_END

Ord_Kids                            ; кнопки ордера: параметр - номер кнопки (Btn_*)
        FIELD ORD_BTN_X,EDIT_LINE-2,2,1, FF_HAND, Btn_Field, 0, OB_ID+0
        FIELD ORD_BTN_X,EDIT_LINE-1,2,1, FF_HAND, Btn_Field, 0, OB_ID+1
        FIELD ORD_BTN_X,EDIT_LINE+1,2,1, FF_HAND, Btn_Field, 0, OB_ID+2
        FIELD ORD_BTN_X,EDIT_LINE+2,2,1, FF_HAND, Btn_Field, 0, OB_ID+3
        db FLD_END

Head_Kids                           ; кнопки [+]/[-] элементов: колонки - Build_Head_Kids
        DUP ITEMS
        FIELD 0,VIEW_LINE,2,1, FF_HAND, Btn_Field, 0, 0
        EDUP
        db FLD_END

;-------- Кнопки заголовков - на свои колонки (после смены раскладки):
; два последних знака элемента, параметр - номер элемента
Build_Head_Kids
        ld ix,Head_Kids
        ld b,0
.it     ld a,b
        ld hl,Item_Col
        call Arr_Get
        ld c,a
        ld a,b
        ld hl,Item_W
        call Arr_Get
        add a,c
        sub 2
        ld (ix+FLD_X),a
        ld a,b                      ; скрытый элемент (второй чип при 3ch) - кнопка за экраном
        ld hl,Vis_Items
        cp (hl)
        jr c,.vis
        ld (ix+FLD_X),HIDDEN_X
.vis
        ld (ix+FLD_PARAM),b
        ld de,FLD_SIZE
        add ix,de
        inc b
        ld a,b
        cp ITEMS
        jr c,.it
        ret

;-------- Кнопка (заголовка или ордера). Параметр поля - номер кнопки (Btn_Show/Action)
Btn_Field
        ld e,(ix+FLD_PARAM)
        cp EV_PRESS
        ld a,1
        jp z,Btn_Show
        ld a,(Fc_Ev)
        cp EV_RELEASE
        ld a,0
        jp z,Btn_Show
        ld a,(Fc_Ev)
        cp EV_CLICK
        jp z,Btn_Action
        ld a,(Fc_Ev)                ; держат и мышь ушла / вернулась
        cp EV_HOVER_OUT
        ld c,0
        jr z,.held
        cp EV_HOVER_IN
        ret nz
        ld c,1
.held   push ix                     ; это та кнопка, которую держат?
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ret nz
        ld e,(ix+FLD_PARAM)
        ld a,c
        jp Btn_Show

;-------- Ордер: клик по позиции - выбрать её, колесо и стрелки - позиции
Ord_Field
        cp EV_PRESS
        jr z,.click
        cp EV_WHEEL
        jr z,.wheel
        cp EV_KEY
        jr z,.key
        cp EV_FOCUS_IN
        jr z,.focus
        cp EV_FOCUS_OUT
        ret nz
.focus  jp Draw_Frame               ; заголовок "Ord" - ярче в фокусе
.click  ld a,(SV_MOUSE_COL)         ; по кнопкам (колонки 4..5) - не выбор
        cp ORD_BTN_X
        ret nc
        ld a,(SV_MOUSE_ROW)         ; строка -> позиция (текущая - в центре)
        sub EDIT_LINE
        ld b,a
        ld a,(Cur_Pos)
        add a,b
        ld b,a
        ld a,(Ord_Last)
        cp b
        ret c                       ; за концом ордера
        ld a,b
        jr Ord_Go
.wheel  ld a,c                      ; колесо: вверх - назад по ордеру
        or a
        jp m,Ord_Next
        jr Ord_Prev
.key    ld hl,Ord_Keys
        jp Keys_Table

Ord_Keys
        db ACT_UP
        dw Ord_Prev
        db ACT_DOWN
        dw Ord_Next
        db 0

Ord_Prev
        ld a,(Cur_Pos)
        or a
        ret z
        dec a
        jr Ord_Go
Ord_Next
        ld a,(Ord_Last)
        ld b,a
        ld a,(Cur_Pos)
        cp b
        ret nc
        inc a
; A - позиция: она текущая, с роу 0
Ord_Go  ld (Cur_Pos),a
        jp Ord_Changed

;-------- Паттерн: колесо - роу (с Ctrl/Shift - каналы), клавиши навигации
Pat_Field
        cp EV_PRESS
        jp z,Pat_Click
        cp EV_RCLICK
        jp z,Pat_Menu
        cp EV_WHEEL
        jr z,.wheel
        cp EV_KEY
        jr z,.key
        cp EV_FOCUS_IN
        jr z,.focus
        cp EV_FOCUS_OUT
        ret nz
.focus  jp Draw_Frame               ; заголовок элемента под курсором - ярче в фокусе
.key    ld hl,Pat_Keys
        call Keys_Table
        ret c
        jp Pat_Type                 ; не навигация - ввод в клетку
.wheel  ld a,(SV_KEY_MODS)          ; Ctrl или Shift - колесо по каналам
        and KM_CTRL|KM_SHIFT
        jr nz,.ch
        ld a,c
        or a
        jp m,K_RowDn
        jp K_RowUp
.ch     ld a,c
        or a
        jp m,K_ChRight
        jp K_ChLeft

;-------- Ввод в клетку под курсором: клавиша B, флаги C. CF - наша.
; Поле ноты (как VT): пианино - октава из шапки (Cur_Octave), Shift - на октаву выше;
; A - off, K - стереть ноту. Остальные поля - цифры (как их показывает текст роу).
; После ввода - строка звучит, курсор вниз на шаг (Step, если включён)
Pt_Key          db 0                ; клавиша ввода (строка звучит, пока её держат)
Pat_Type
        ld a,b
        ld (Pt_Key),a
        ld a,(Env_Open)
        or a
        jp nz,Pt_Env
        ld a,(Cur_Field)
        or a
        jp nz,Pt_Chan
        ld a,b
        cp KEY_A
        jr z,.off
        cp KEY_K
        jr z,.clr
        push bc
        call Piano_Get              ; A - полутон
        pop bc
        ret nc
        ld e,a                      ; нота = (октава-1)*12 + полутон + NOTE_FIRST
        ld a,(Cur_Octave)
        dec a
        ld d,a
        add a,a
        add a,d
        add a,a
        add a,a
        add a,e
        bit 0,c                     ; Shift (KM_SHIFT) - на октаву выше
        jr z,$+4
        add a,12
        cp NOTE_COUNT
        ret nc                      ; выше B-8 - мимо
        add a,NOTE_FIRST
        jr .put
.off    ld a,NOTE_OFF
        jr .put
.clr    xor a                       ; NOTE_EMPTY
.put    ld (Cp_Val),a
        ld a,CH_NOTE
        jp Pt_Byte
    ASSERT KM_SHIFT == 1 && NOTE_EMPTY == 0

; Поле канала 1..12: сэмпл, огибающая, орнамент, громкость, цифры двух команд
Pt_Chan
        ld a,(Cur_Field)
        cp 5
        jr nc,.cmd
        cp 2
        jr z,.env
        cp 3
        jr z,.orn
        jr nc,.vol
        call Key_Sym                ; 1 - сэмпл: 1..9, A..W (0 - пусто)
        ret nc
        cp SAMPLES_MAX+1
        ret nc
        ld (Cp_Val),a
        ld a,CH_SAMPLE
        jr Pt_Byte
.env    call Key_Hex                ; 2 - форма огибающей: 1..E, F - выкл (0 - пусто)
        ret nc
        ld (Cp_Val),a
        ld a,CH_ENVSHAPE
        jr Pt_Byte
.orn    call Key_Sym                ; 3 - орнамент n (0..16) -> n+1
        ret nc
        cp ORNAMENTS_MAX+1
        ret nc
        inc a
        ld (Cp_Val),a
        ld a,CH_ORNAMENT
        jr Pt_Byte
.vol    call Key_Hex                ; 4 - громкость 1..F (0 - пусто)
        ret nc
        ld (Cp_Val),a
        ld a,CH_VOLUME
        jr Pt_Byte
.cmd    call Key_Hex                ; 5..12 - цифра команды: 4 hex на команду
        ret nc
        ld (Cp_Val),a
        ld a,(Cur_Field)
        sub 5                       ; цифра k 0..7: команда k/4, байт (k/2)&1, полубайт k&1
        ld c,a
        srl a                       ; байт: CH_CMD + k/2 (команды по 2 байта подряд)
        add a,CH_CMD
        jr Pt_Nib
    ASSERT CMD_SIZE == 2

; Поле Env чипа 0..9: цифры периода (4), шума (2), огибающей-2 (4)
Pt_Env
        call Key_Hex
        ret nc
        ld (Cp_Val),a
        ld a,(Cur_Field)
        cp 4
        jr c,.per
        cp 6
        jr c,.noise
        sub 6                       ; огибающая-2: как период
        ld c,a
        ld a,CHIP_ENV2
        jr .word
.per    ld c,a                      ; период: числом - нота огибающей больше не нужна
        xor a
        ld (Cp_EnvNote),a
        ld a,CHIP_ENVPER
.word   ld (Cp_Fld),a               ; цифра k 0..3 слова (старший байт - +1): k 0,1 -> +1
        ld a,c
        cp 2
        ld a,(Cp_Fld)
        jr nc,$+3
        inc a
        jr Pt_Nib
.noise  sub 4                       ; шум: 0 - пусто, шум 0 - #20, 1..#1F - как есть
        ld (Cp_Digit),a
        ld hl,Op_Noise
        jr Pt_Do

; Cp_Val -> байт A клетки (канал или заголовок чипа - по Env_Open)
Pt_Byte ld (Cp_Fld),a
        ld hl,Op_Byte
        jr Pt_Do
; Cp_Val -> полубайт байта A: C чётный - старший, нечётный - младший
Pt_Nib  ld (Cp_Fld),a
        ld a,c
        ld (Cp_Digit),a
        ld hl,Op_Nib
; HL - правка (Op_*): сделать, строка звучит, курсор - на шаг вниз
Pt_Do   ld (Cp_Op),hl
        call Ud_Save                ; отмена: колонка - до правки
        call Cell_Edit
        call Play_Line
        call Step_Cur
        scf
        ret

;-------- Delete: поле под курсором - пусто (команда - оба байта, период - слово)
K_Clear
        xor a
        ld (Cp_Val),a
        ld a,(Env_Open)
        or a
        jr nz,.env
        ld a,(Cur_Field)            ; канал: поле -> байт (команда - Op_Word)
        ld hl,Clr_Chan
        call Arr_Get
        ld (Cp_Fld),a
        ld hl,Op_Byte
        ld a,(Cur_Field)
        cp 5
        jr c,.do
        ld hl,Op_Word
        jr .do
.env    ld a,(Cur_Field)            ; Env: период, шум, огибающая-2
        ld hl,Clr_Env
        call Arr_Get
        ld (Cp_Fld),a
        ld hl,Op_Byte
        cp CHIP_NOISE
        jr z,.do
        ld hl,Op_Word
        xor a                       ; период - и нота огибающей
        ld (Cp_EnvNote),a
.do     ld (Cp_Op),hl
        call Ud_Save
        jp Cell_Edit
; поле курсора -> байт клетки
Clr_Chan        db CH_NOTE, CH_SAMPLE, CH_ENVSHAPE, CH_ORNAMENT, CH_VOLUME
                db CH_CMD, CH_CMD, CH_CMD, CH_CMD
                db CH_CMD+CMD_SIZE, CH_CMD+CMD_SIZE, CH_CMD+CMD_SIZE, CH_CMD+CMD_SIZE
    ASSERT $-Clr_Chan == CF_CHAN_N
Clr_Env         db CHIP_ENVPER, CHIP_ENVPER, CHIP_ENVPER, CHIP_ENVPER, CHIP_NOISE, CHIP_NOISE
                db CHIP_ENV2, CHIP_ENV2, CHIP_ENV2, CHIP_ENV2
    ASSERT $-Clr_Env == CF_ENV_N

;-------- Клавиша B -> цифра. CF - цифра, A - значение. Key_Hex: 0..F; Key_Sym: 0..9, A..W
; = 0..32 (как Sym_T). Портит HL
Key_Hex
        call Key_Sym
        ret nc
        cp 16
        ret                         ; CF - меньше 16
Key_Sym
        ld h,high Key_Chars         ; код -> символ (0 - не символ)
        ld l,b
        ld a,b
        or a
        ret m                       ; E0-коды - не цифры (CF = 0)
        ld a,(hl)
        sub '0'
        jr c,.no
        cp 10
        ret c                       ; 0..9
        sub 'a'-'0'
        jr c,.no
        add a,10                    ; a..w -> 10..32
        cp 33
        ret
.no     or a                        ; CF = 0
        ret

;-------- Правка клетки: роу Cur_Row паттерна текущей позиции - в окне 2, HL - начало канала
; курсора (Env - начало чипа), вызвать Cp_Op, потом текст роу заново (экран - со следующего кадра)
Cp_Op           dw 0                ; правка (Op_*): HL - начало, Cp_Fld - байт
Cp_Val          db 0
Cp_Fld          db 0
Cp_Digit        db 0
Cp_EnvNote      db 1                ; 0 - период ввели числом: CHIP_ENVNOTE стереть
Cell_Edit
        ld a,(Cur_Pos)              ; страница паттерна позиции
        ld hl,Ord_List
        call Arr_Get
        call Pat_Page
        SETPAGE2 a
        ld a,(Cur_Chan)             ; чип
        ld b,0
        cp 3
        jr c,.c
        sub 3
        ld b,CHIP_SIZE
.c      ld c,a                      ; C - канал в чипе
        ld a,(Env_Open)
        or a
        ld a,b                      ; Env - заголовок чипа
        jr nz,.l
        ld a,c                      ; канал: *CH_SIZE
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,CHIP_CH_A
.l      ld l,a
        ld a,(Cur_Row)
        add a,PAT_BASE_H
        ld h,a
        ld ix,(Cp_Op)
        call .op
        ld a,(Cp_EnvNote)           ; период числом - нота огибающей стёрта
        or a
        jr nz,.t
        inc a
        ld (Cp_EnvNote),a
        ld a,(Env_Open)
        or a
        jr z,.t
        ld a,(Cur_Chan)
        cp 3
        ld a,CHIP_ENVNOTE
        jr c,$+4
        add a,CHIP_SIZE
        ld l,a
        ld (hl),0
.t      call Row_To_Text            ; H - роу
        RESTPAGE2
        ret
.op     jp (ix)
    ASSERT CH_SIZE == 16

; Правки: HL - начало канала / чипа, Cp_Fld - байт, Cp_Val - значение. HL не портят
Op_Byte push hl                     ; байт = значение
        ld a,(Cp_Fld)
        add a,l
        ld l,a
        ld a,(Cp_Val)
        ld (hl),a
        pop hl
        ret
Op_Word push hl                     ; слово = 0
        ld a,(Cp_Fld)
        add a,l
        ld l,a
        xor a
        ld (hl),a
        inc l
        ld (hl),a
        pop hl
        ret
Op_Nib  push hl                     ; полубайт: Cp_Digit чётный - старший
        ld a,(Cp_Fld)
        add a,l
        ld l,a
        ld a,(Cp_Digit)
        rrca
        ld a,(Cp_Val)
        jr c,.lo
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(hl)
        and #0F
        jr .put
.lo     ld c,a
        ld a,(hl)
        and #F0
.put    or c
        ld (hl),a
        pop hl
        ret
Op_Noise
        push hl                     ; шум: цифра Cp_Digit (0 - старшая) числа 0..#1F
        ld a,CHIP_NOISE
        add a,l
        ld l,a
        ld a,(hl)                   ; 0 и #20 - шум 0
        and #1F
        ld b,a
        ld a,(Cp_Digit)
        or a
        ld a,(Cp_Val)
        jr nz,.lo
        and 1                       ; старшая - 0 или 1
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,b
        and #0F
        jr .put
.lo     ld c,a
        ld a,b
        and #10
.put    or c
        jr nz,$+4
        ld a,#20                    ; шум 0
        ld (hl),a
        pop hl
        ret

;-------- Строка звучит (как VT): роу курсора, чип курсора - пробой плеера, пока держат
; клавишу ввода (Ln_Check). Только когда плеер стоит или уже играет пробу
Ln_Key          db 0                ; клавиша, пока держат - звучит (0 - нет)
Play_Line
        ld a,(SV_PLAY_STATE)
        or a
        jr z,.go
        cp PS_PREVIEW
        ret nz                      ; играет сонг / паттерн - не мешаем
.go     ld a,(Pt_Key)
        ld (Ln_Key),a
        ld a,(Cur_Pos)              ; роу курсора - в Prv_Row (коре)
        ld hl,Ord_List
        call Arr_Get
        call Pat_Page
        SETPAGE2 a
        ld a,(Cur_Chan)             ; чип курсора
        cp 3
        ld a,0
        jr c,$+4
        ld a,CHIP_SIZE
        ld l,a
        ld a,(Cur_Row)
        add a,PAT_BASE_H
        ld h,a
        ld de,Prv_Row
        ld bc,CHIP_SIZE
        ldir
        RESTPAGE2
        ld a,PC_PREVIEW             ; команда - последней (IM1 может влезть)
        ld (SV_PLAY_CMD),a
        ret

;-------- Каждый кадр: клавишу ввода отпустили - проба строки молчит
Ln_Check
        ld a,(Ln_Key)
        or a
        ret z
        call Key_Down               ; NZ - держат
        ret nz
        xor a
        ld (Ln_Key),a
        ld a,(SV_PLAY_STATE)        ; молчит только проба (сонг не трогаем)
        cp PS_PREVIEW
        ret nz
        ld a,PC_STOP
        ld (SV_PLAY_CMD),a
        ret

;-------- Строки (как VT): Insert - вставить строку трека, Backspace - удалить строку трека;
; Ctrl+I и Ctrl+Backspace, Ctrl+Y - то же для всей роу паттерна. Строки ниже курсора
; сдвигаются в пределах длины паттерна (за длиной - пропадает / приходит пустая)
Ln_Ofs          db 0                ; кусок роу: начало
Ln_Size         db 0                ;   длина
Ln_Len          db 0                ; длина паттерна
Ln_Pat          db 0                ; номер паттерна позиции
K_InsTrk
        call Ud_Save
        call Trk_Part
        jr Ln_Ins
K_InsPat
        call Ud_Reset               ; вся роу паттерна - отмены нет
        call Pat_Part
        jr Ln_Ins
K_DelTrk
        call Ud_Save
        call Trk_Part
        jp Ln_Del
K_DelPat
        call Ud_Reset
        call Pat_Part
        jp Ln_Del

; Кусок - элемент курсора: канал (CH_SIZE) или заголовок чипа (Env)
Trk_Part
        ld a,(Cur_Chan)
        ld b,0
        cp 3
        jr c,.c
        sub 3
        ld b,CHIP_SIZE
.c      ld c,a
        ld a,(Env_Open)
        or a
        ld a,b
        ld e,CHIP_HDR_SIZE
        jr nz,.s
        ld a,c                      ; канал: *CH_SIZE
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,CHIP_CH_A
        ld e,CH_SIZE
.s      ld (Ln_Ofs),a
        ld a,e
        ld (Ln_Size),a
        ret
; Кусок - вся роу (данные обоих чипов)
Pat_Part
        xor a
        ld (Ln_Ofs),a
        ld a,PAT_DATA_SIZE
        ld (Ln_Size),a
        ret

; Номер и длина паттерна позиции -> Ln_Pat, Ln_Len; A - его страница
Ln_Page
        ld a,(Cur_Pos)
        ld hl,Ord_List
        call Arr_Get
        ld (Ln_Pat),a
        ld hl,Pat_Len
        call Arr_Get
        ld (Ln_Len),a
        ld a,(Ln_Pat)
        jp Pat_Page

;-------- Вставить: роу r = роу r-1 для r = длина-1 .. курсор+1, роу курсора - пусто
Ln_Ins
        call Ln_Page
        SETPAGE2 a
        ld a,(Ln_Len)
        dec a
        ld b,a                      ; B - роу r
.m      ld a,(Cur_Row)
        cp b
        jr nc,.clr                  ; r <= курсора - всё
        ld a,b
        add a,PAT_BASE_H
        ld d,a
        dec a
        ld h,a
        call Ln_Copy
        dec b
        jr .m
.clr    ld a,(Cur_Row)
        call Ln_Zero
        call Ln_Text
        RESTPAGE2
        ret

;-------- Удалить: роу r = роу r+1 для r = курсор .. длина-2, последняя - пусто
Ln_Del
        call Ln_Page
        SETPAGE2 a
        ld a,(Cur_Row)
        ld b,a                      ; B - роу r
.m      ld a,(Ln_Len)
        dec a
        cp b
        jr z,.clr                   ; r = последней - всё
        jr c,.clr
        ld a,b
        add a,PAT_BASE_H
        ld d,a
        inc a
        ld h,a
        call Ln_Copy
        inc b
        jr .m
.clr    ld a,(Ln_Len)
        dec a
        call Ln_Zero
        call Ln_Text
        RESTPAGE2
        ret

; Кусок роу H -> роу D (страница - в окне 2). B цел
Ln_Copy
        push bc
        ld a,(Ln_Ofs)
        ld l,a
        ld e,a
        ld a,(Ln_Size)
        ld c,a
        ld b,0
        ldir
        pop bc
        ret
; Кусок роу A - нули
Ln_Zero
        add a,PAT_BASE_H
        ld h,a
        ld a,(Ln_Ofs)
        ld l,a
        ld a,(Ln_Size)
        ld b,a
.z      ld (hl),0
        inc l
        djnz .z
        ret
; Текст роу от курсора до конца паттерна - заново
Ln_Text
        ld a,(Cur_Row)
        add a,PAT_BASE_H
        ld h,a
.t      call Row_To_Text            ; H цел
        inc h
        ld a,(Ln_Len)
        add a,PAT_BASE_H
        cp h
        jr z,.e
        jr nc,.t
.e      ret

;-------- ОТМЕНА (5 шагов, только в пределах канала): перед правкой колонка элемента
; курсора (64 роу по 16 / 8 байт) и курсор - в кольцо записей (PAGE_EDBUF, окно 3).
; Ctrl+Z - колонку паттерна и записи поменять местами, курсор - как был; Ctrl+Shift+Z -
; поменять обратно (повтор). Операции на всю роу паттерна отмену сбрасывают
UD_N            equ 5
UD_HDR          equ 16
UD_REC          equ UD_HDR+PAT_ROWS_MAX*CH_SIZE ; 1040
UD_BASE         equ #C000           ; кольцо - в начале PAGE_EDBUF (окно 3)
UD_PAT          equ 0               ; запись: паттерн, кусок роу, курсор
UD_OFS          equ 1
UD_SIZE         equ 2
UD_POS          equ 3
UD_ROW          equ 4
UD_CHAN         equ 5
UD_ENV          equ 6
UD_FIELD        equ 7
    ASSERT UD_N*UD_REC <= #2000     ; дальше в странице - буфер обмена

Ud_Head         db 0                ; запись для следующей правки (0..UD_N-1)
Ud_Count        db 0                ; сколько можно отменить
Ud_Redo         db 0                ; сколько можно повторить
Ud_Rec          dw 0                ; адрес записи (окно 3)

Ud_Reset
        xor a
        ld (Ud_Count),a
        ld (Ud_Redo),a
        ret

; A - номер записи -> Ud_Rec
Ud_Addr
        ld hl,UD_BASE
        ld de,UD_REC
        or a
        jr z,.s
.m      add hl,de
        dec a
        jr nz,.m
.s      ld (Ud_Rec),hl
        ret

;-------- Перед правкой канала курсора: колонка и курсор - в запись Ud_Head
Ud_Save
        call Trk_Part               ; Ln_Ofs, Ln_Size - элемент курсора
        call Ln_Page                ; Ln_Pat; A - страница паттерна
        ld (Ud_PPage),a
        ld a,(Ud_Head)
        call Ud_Addr
        ld a,(Ud_PPage)
        SETPAGE2 a
        ld a,PAGE_EDBUF
        SETPAGE3 a
        ld ix,(Ud_Rec)              ; заголовок
        ld a,(Ln_Pat)
        ld (ix+UD_PAT),a
        ld a,(Ln_Ofs)
        ld (ix+UD_OFS),a
        ld a,(Ln_Size)
        ld (ix+UD_SIZE),a
        ld a,(Cur_Pos)
        ld (ix+UD_POS),a
        ld a,(Cur_Row)
        ld (ix+UD_ROW),a
        ld a,(Cur_Chan)
        ld (ix+UD_CHAN),a
        ld a,(Env_Open)
        ld (ix+UD_ENV),a
        ld a,(Cur_Field)
        ld (ix+UD_FIELD),a
        ld de,UD_HDR                ; колонка: 64 роу подряд
        add ix,de
        ld d,ixh
        ld e,ixl
        ld h,PAT_BASE_H
.r      ld a,(Ln_Ofs)
        ld l,a
        ld a,(Ln_Size)
        ld c,a
        ld b,0
        ldir
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        RESTPAGE3
        RESTPAGE2
        ld a,(Ud_Head)              ; кольцо: следующая
        inc a
        cp UD_N
        jr c,$+3
        xor a
        ld (Ud_Head),a
        ld a,(Ud_Count)
        cp UD_N
        jr nc,$+3
        inc a
        ld (Ud_Count),a
        xor a                       ; новая правка - повторять нечего
        ld (Ud_Redo),a
        ret
Ud_PPage        db 0

;-------- Ctrl+Z: последняя запись - колонку поменять местами, курсор - туда
K_Undo
        ld a,(Ud_Count)
        or a
        ret z
        dec a
        ld (Ud_Count),a
        ld hl,Ud_Redo
        inc (hl)
        ld a,(Ud_Head)              ; назад по кольцу
        or a
        jr nz,$+4
        ld a,UD_N
        dec a
        ld (Ud_Head),a
        jr Ud_Swap
;-------- Ctrl+Shift+Z: повтор - та же запись, обратно
K_Redo
        ld a,(Ud_Redo)
        or a
        ret z
        dec a
        ld (Ud_Redo),a
        ld hl,Ud_Count
        inc (hl)
        ld a,(Ud_Head)
        push af
        inc a                       ; вперёд по кольцу
        cp UD_N
        jr c,$+3
        xor a
        ld (Ud_Head),a
        pop af
; Запись A: колонка паттерна <-> колонка записи, курсор - из записи, текст роу заново
Ud_Swap
        call Ud_Addr
        ld a,PAGE_EDBUF             ; заголовок - сначала (страница паттерна - из него)
        SETPAGE3 a
        ld ix,(Ud_Rec)
        ld a,(ix+UD_PAT)
        ld (Ln_Pat),a
        ld a,(ix+UD_OFS)
        ld (Ln_Ofs),a
        ld a,(ix+UD_SIZE)
        ld (Ln_Size),a
        ld a,(ix+UD_POS)
        ld (Cur_Pos),a
        ld a,(ix+UD_ROW)
        ld (Cur_Row),a
        ld a,(ix+UD_CHAN)
        ld (Cur_Chan),a
        ld a,(ix+UD_ENV)
        ld (Env_Open),a
        ld a,(ix+UD_FIELD)
        ld (Cur_Field),a
        RESTPAGE3
        ld a,(Ln_Pat)
        call Pat_Page
        SETPAGE2 a
        ld a,PAGE_EDBUF
        SETPAGE3 a
        ld ix,(Ud_Rec)
        ld de,UD_HDR
        add ix,de
        ld d,ixh
        ld e,ixl
        ld h,PAT_BASE_H
.r      ld a,(Ln_Ofs)
        ld l,a
        ld a,(Ln_Size)
        ld b,a
.s      ld a,(de)                   ; байт: поменять местами
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc l
        inc de
        djnz .s
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        RESTPAGE3
        ld h,PAT_BASE_H             ; текст всех роу паттерна
.t      call Row_To_Text
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.t
        RESTPAGE2
        ld a,1                      ; позиция могла смениться - ордер и раскладку заново
        ld (Order_Pending),a
        jp Need_Layout

;-------- ВЫДЕЛЕНИЕ И БУФЕР ОБМЕНА (как VT, по клеткам: канал или Env чипа целиком).
; Выделение - прямоугольник в паттерне позиции Sel_Pos: роу A..B, элементы A..B (0..7).
; Shift + стрелки / PgUp / PgDn, Shift + клик - выделить; Ctrl+A - весь паттерн;
; движение без Shift - снять. Ctrl+C / X / V, Delete, Numpad +/- (Ctrl - октава) - над
; выделением (нет - над клеткой курсора). Буфер обмена - в PAGE_EDBUF за отменой
CLIP_HDR        equ #DF00           ; окно 3: строк, элементов, вид элементов (8)
CLIP_DATA       equ #E000           ;   клетки: роу по 8 элементов по 16 байт
CLIP_ROW        equ 8*CH_SIZE
    ASSERT UD_BASE+UD_N*UD_REC <= CLIP_HDR && CLIP_DATA+PAT_ROWS_MAX*CLIP_ROW <= #10000

Sel_On          db 0                ; 1 - есть выделение
Sel_Pos         db 0                ; в паттерне какой позиции
Sel_RA          db 0                ; угол A (откуда начали): роу, элемент
Sel_IA          db 0
Sel_RB          db 0                ; угол B (курсор): роу, элемент
Sel_IB          db 0
Rg_R0           db 0                ; кусок для операции: роу R0..R1, элементы I0..I1
Rg_R1           db 0
Rg_I0           db 0
Rg_I1           db 0

;-------- A - элемент под курсором (как Calc_Open, но сразу, без раскладки)
Cur_Item
        ld a,(Cur_Chan)             ; канал -> элемент: 0..2 -> 1..3, 3..5 -> 5..7
        inc a
        cp 4
        jr c,$+3
        inc a
        ld b,a
        ld a,(Env_Open)
        or a
        ld a,b
        ret z
        and 4                       ; Env этого чипа: 0 или 4
        ret

; A - элемент 0..7 -> A - начало в роу, B - размер (Env - заголовок чипа, канал - CH_SIZE)
Item_Ofs
        ld c,0                      ; чип
        cp 4
        jr c,.c
        sub 4
        ld c,CHIP_SIZE
.c      or a
        jr nz,.ch
        ld a,c
        ld b,CHIP_HDR_SIZE
        ret
.ch     dec a                       ; канал: CHIP_CH_A + n*CH_SIZE
        add a,a
        add a,a
        add a,a
        add a,a
        add a,CHIP_CH_A
        add a,c
        ld b,CH_SIZE
        ret

;-------- Снять / начать / продолжить выделение
Sel_Off
        xor a
        ld (Sel_On),a
        ret
Sel_Begin
        ld a,(Sel_On)
        or a
        ret nz
        inc a
        ld (Sel_On),a
        ld a,(Cur_Pos)
        ld (Sel_Pos),a
        ld a,(Cur_Row)
        ld (Sel_RA),a
        call Cur_Item
        ld (Sel_IA),a
; Угол B - курсор (ушёл в другую позицию - выделение снять)
Sel_Ext
        ld a,(Cur_Pos)
        ld hl,Sel_Pos
        cp (hl)
        jr nz,Sel_Off
        ld a,(Cur_Row)
        ld (Sel_RB),a
        call Cur_Item
        ld (Sel_IB),a
        ret

; Движение без Shift - снять выделение и двигать
K_Up    call Sel_Off
        jp K_RowUp
K_Down  call Sel_Off
        jp K_RowDn
K_PgUpN call Sel_Off
        jp K_PageUp
K_PgDnN call Sel_Off
        jp K_PageDn
K_Left  call Sel_Off
        jp K_FieldLeft
K_Right call Sel_Off
        jp K_FieldRight
; С Shift - выделять: строки - роу, влево / вправо - по элементам
K_SelUp call Sel_Begin
        call K_RowUp
        jr Sel_Ext
K_SelDn call Sel_Begin
        call K_RowDn
        jr Sel_Ext
K_SelPU call Sel_Begin
        call K_PageUp
        jr Sel_Ext
K_SelPD call Sel_Begin
        call K_PageDn
        jr Sel_Ext
K_SelLt call Sel_Begin
        call Cur_Item
        or a
        jr z,Sel_Ext
        dec a
        call Item_Go
        jr Sel_Ext
K_SelRt call Sel_Begin
        call Cur_Item
        inc a
        ld hl,Vis_Items
        cp (hl)
        jr nc,Sel_Ext
        call Item_Go
        jr Sel_Ext
;-------- Ctrl+A: весь паттерн
K_SelAll
        ld a,1
        ld (Sel_On),a
        ld a,(Cur_Pos)
        ld (Sel_Pos),a
        xor a
        ld (Sel_RA),a
        ld (Sel_IA),a
        call Ln_Page                ; Ln_Len
        ld a,(Ln_Len)
        dec a
        ld (Sel_RB),a
        ld a,(Vis_Items)
        dec a
        ld (Sel_IB),a
        ret

;-------- Кусок для операции -> Rg_*: выделение (углы по порядку, роу - не за длиной)
; или клетка курсора. Ln_Len, Ln_Pat - паттерна позиции
Rg_Get
        call Ln_Page
        ld a,(Sel_On)
        or a
        jr z,.cur
        ld a,(Sel_Pos)
        ld hl,Cur_Pos
        cp (hl)
        jr nz,.cur
        ld a,(Sel_RA)
        ld b,a
        ld a,(Sel_RB)
        call .ord
        ld (Rg_R0),a
        ld a,c
        ld (Rg_R1),a
        ld a,(Sel_IA)
        ld b,a
        ld a,(Sel_IB)
        call .ord
        ld (Rg_I0),a
        ld a,c
        ld (Rg_I1),a
        ld a,(Ln_Len)               ; роу - не за длиной паттерна
        dec a
        ld hl,Rg_R1
        cp (hl)
        ret nc
        ld (hl),a
        ret
.cur    ld a,(Cur_Row)
        ld (Rg_R0),a
        ld (Rg_R1),a
        call Cur_Item
        ld (Rg_I0),a
        ld (Rg_I1),a
        ret
; A, B -> A - меньший, C - больший
.ord    cp b
        ld c,b
        ret c
        ld c,a
        ld a,b
        ret

; Перед правкой куска: один элемент и он под курсором - отмена его колонки, иначе - без отмены
Rg_Undo
        ld a,(Rg_I0)
        ld hl,Rg_I1
        cp (hl)
        jp nz,Ud_Reset
        ld b,a
        call Cur_Item
        cp b
        jp nz,Ud_Reset
        jp Ud_Save

;-------- Обход куска Rg_*: на каждую клетку Rg_Op(HL - клетка в паттерне (окно 2), DE - она
; в буфере обмена (окно 3), B - размер, C - элемент 0..7). Потом текст роу куска заново
Rg_Op           dw 0
Rg_Walk
        ld a,(Ln_Pat)
        call Pat_Page
        SETPAGE2 a
        ld a,PAGE_EDBUF
        SETPAGE3 a
        ld a,(Rg_R0)
        ld (Rw_R),a
.r      ld a,(Rg_I0)
        ld (Rw_I),a
.i      ld a,(Rw_I)
        call Item_Ofs               ; A - начало, B - размер
        ld (Rw_Ofs),a
        ld a,(Rw_R)                 ; буфер: (роу - R0) * CLIP_ROW + (элемент - I0) * 16
        ld hl,Rg_R0
        sub (hl)
        ld l,a
        ld h,0
        add hl,hl                   ; *128
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(Rw_I)
        ld de,Rg_I0
        ex de,hl
        sub (hl)
        ex de,hl
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,CLIP_DATA/256
        add hl,de
        ex de,hl                    ; DE - буфер
        ld a,(Rw_R)
        add a,PAT_BASE_H
        ld h,a
        ld a,(Rw_Ofs)
        ld l,a                      ; HL - клетка
        ld a,(Rw_I)
        ld c,a
        ld ix,(Rg_Op)
        call .op
        ld a,(Rw_I)
        ld hl,Rg_I1
        cp (hl)
        inc a
        ld (Rw_I),a
        jr c,.i
        ld a,(Rw_R)
        ld hl,Rg_R1
        cp (hl)
        inc a
        ld (Rw_R),a
        jr c,.r
        RESTPAGE3
        ld a,(Rg_R0)                ; текст роу куска
        add a,PAT_BASE_H
        ld h,a
.t      call Row_To_Text
        inc h
        ld a,(Rg_R1)
        add a,PAT_BASE_H+1
        cp h
        jr nz,.t
        RESTPAGE2
        ret
.op     jp (ix)
Rw_R            db 0
Rw_I            db 0
Rw_Ofs          db 0
    ASSERT CLIP_ROW == 128 && (CLIP_DATA & 255) == 0

; Клетки: в буфер / нули / транспонировать ноту (канал, нота 1..96)
Op_ToClip
        ld c,b
        ld b,0
        ldir
        ret
Op_Zero
        ld (hl),0
        inc l
        djnz Op_Zero
        ret
Op_Transp
        ld a,c                      ; Env - нот нет
        and 3
        ret z
        ld a,(hl)                   ; CH_NOTE: 1..96, остальное (пусто, off) - мимо
        or a
        ret z
        cp NOTE_LAST+1
        ret nc
        ld b,a
        ld a,(Tr_Delta)
        add a,b
        cp NOTE_FIRST
        ret c                       ; ниже C-1 - не трогаем (и перенос через 0)
        cp NOTE_LAST+1
        ret nc                      ; выше B-8 - не трогаем
        ld (hl),a
        ret
Tr_Delta        db 0
    ASSERT CH_NOTE == 0

;-------- Ctrl+C: кусок - в буфер (заголовок: строк, элементов, вид каждого: Env или канал)
K_Copy
        call Rg_Get
Clip_Save
        ld a,PAGE_EDBUF
        SETPAGE3 a
        ld a,(Rg_R1)
        ld hl,Rg_R0
        sub (hl)
        inc a
        ld (CLIP_HDR),a
        ld a,(Rg_I1)
        ld hl,Rg_I0
        sub (hl)
        inc a
        ld (CLIP_HDR+1),a
        ld b,a                      ; вид: элемент & 3 (0 - Env)
        ld a,(Rg_I0)
        ld hl,CLIP_HDR+2
.k      ld c,a
        and 3
        ld (hl),a
        inc hl
        ld a,c
        inc a
        djnz .k
        RESTPAGE3
        ld hl,Op_ToClip
        ld (Rg_Op),hl
        jp Rg_Walk

;-------- Ctrl+X: в буфер и нули
K_Cut
        call Rg_Get
        call Clip_Save
        call Rg_Undo
        jr Rg_Clear
;-------- Delete: есть выделение - кусок нули, нет - поле курсора (K_Clear)
K_Del
        ld a,(Sel_On)
        or a
        jp z,K_Clear
        call Rg_Get
        call Rg_Undo
Rg_Clear
        ld hl,Op_Zero
        ld (Rg_Op),hl
        jp Rg_Walk

;-------- Numpad + / - (Ctrl - на октаву): ноты куска
K_TrUp  ld a,1
        jr K_Tr
K_TrDn  ld a,-1
        jr K_Tr
K_TrOU  ld a,12
        jr K_Tr
K_TrOD  ld a,-12
K_Tr    ld (Tr_Delta),a
        call Rg_Get
        call Rg_Undo
        ld hl,Op_Transp
        ld (Rg_Op),hl
        jp Rg_Walk

;-------- Ctrl+V: буфер - с клетки курсора вправо и вниз; элемент - только того же вида
; (Env в Env, канал в канал), за длиной паттерна и за видимыми элементами - мимо
K_Paste
        call Ln_Page
        ld a,PAGE_EDBUF             ; размер буфера
        SETPAGE3 a
        ld a,(CLIP_HDR)
        ld (Ps_Rows),a
        ld a,(CLIP_HDR+1)
        ld (Ps_Items),a
        RESTPAGE3
        ld a,(Ps_Rows)
        or a
        ret z                       ; пусто
        cp PAT_ROWS_MAX+1
        ret nc                      ; не наш (страницу затёрла загрузка)
        ld a,(Ps_Items)
        or a
        ret z
        cp 9
        ret nc
        ld a,(Cur_Row)              ; кусок назначения: роу, элементы
        ld (Rg_R0),a
        ld hl,Ps_Rows
        add a,(hl)
        dec a
        ld hl,Ln_Len
        cp (hl)
        jr c,$+4
        ld a,(hl)
        dec a
        ld (Rg_R1),a
        call Cur_Item
        ld (Rg_I0),a
        ld hl,Ps_Items
        add a,(hl)
        dec a
        ld hl,Vis_Items
        cp (hl)
        jr c,$+4
        ld a,(hl)
        dec a
        ld (Rg_I1),a
        call Rg_Undo
        ld hl,Op_Paste
        ld (Rg_Op),hl
        jp Rg_Walk
Ps_Rows         db 0
Ps_Items        db 0
; Клетка из буфера (DE) - в паттерн (HL), если вид тот же: Env в Env, канал в канал
Op_Paste
        push hl
        ld a,c                      ; вид в буфере: CLIP_HDR+2 + (элемент - I0)
        ld hl,Rg_I0
        sub (hl)
        add a,low (CLIP_HDR+2)
        ld l,a
        ld h,high CLIP_HDR
        ld a,(hl)                   ; 0 - Env
        or a
        ld a,c
        jr z,.env
        and 3                       ; из канала - только в канал
        pop hl
        ret z
        jr .cp
.env    and 3                       ; из Env - только в Env
        pop hl
        ret nz
.cp     ex de,hl
        ld c,b
        ld b,0
        ldir
        ret

;-------- Правая кнопка: меню (как VT) - пункт = действие редактора
Pat_Menu
        ld hl,Pm_Items
        call Win_Menu               ; A - пункт, #FF - ничего
        cp #FF
        ret z
        add a,a
        ld hl,Pm_Act
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
Pm_Items
        db 21, 13                   ; ширина, пунктов
        db CLR_TOP_TEXT,"Copy",0
        db CLR_TOP_TEXT,"Cut",0
        db CLR_TOP_TEXT,"Paste",0
        db CLR_TOP_TEXT,"Delete",0
        db CLR_TOP_TEXT,"Insert track line",0
        db CLR_TOP_TEXT,"Delete track line",0
        db CLR_TOP_TEXT,"Insert row",0
        db CLR_TOP_TEXT,"Delete row",0
        db CLR_TOP_TEXT,"Transpose +1",0
        db CLR_TOP_TEXT,"Transpose -1",0
        db CLR_TOP_TEXT,"Octave up",0
        db CLR_TOP_TEXT,"Octave down",0
        db CLR_TOP_TEXT,"Select all",0
        db WIN_END
Pm_Act  dw K_Copy, K_Cut, K_Paste, K_Del, K_InsTrk, K_DelTrk, K_InsPat, K_DelPat
        dw K_TrUp, K_TrDn, K_TrOU, K_TrOD, K_SelAll
    ASSERT ($-Pm_Act)/2 == 13

;-------- Клик в паттерн: с Shift - выделить от курсора до клика, без - снять выделение
Pat_Click
        ld a,(SV_KEY_MODS)
        and KM_SHIFT
        jr z,.n
        call Sel_Begin
        call Pat_Press
        jp Sel_Ext
.n      call Sel_Off
        jp Pat_Press

;-------- 4. Выделение (IM1, экран - в окне 3): клетки куска - цветом выделения. Роу паттерна
; позиции курсора стоят от строки редактирования подряд: роу r - строка EDIT_LINE + r - курсор
Ds_X0           db 0
Ds_W            db 0
Draw_Sel
        ld a,(Sel_On)
        or a
        ret z
        ld a,(Sel_Pos)
        ld hl,Cur_Pos
        cp (hl)
        ret nz
        ld a,(Sel_IA)               ; колонки: от первого элемента до конца последнего
        ld b,a
        ld a,(Sel_IB)
        call Rg_Get.ord             ; A - первый, C - последний
        ld (Ds_X0),a
        ld a,c
        ld hl,Item_W
        call Arr_Get
        ld b,a
        ld a,c
        ld hl,Item_Col
        call Arr_Get
        add a,b                     ; за последним
        ld b,a
        ld a,(Ds_X0)
        ld hl,Item_Col
        call Arr_Get
        ld (Ds_X0),a
        ld c,a
        ld a,b
        sub c
        ld (Ds_W),a
        ld a,(Sel_RA)               ; роу
        ld b,a
        ld a,(Sel_RB)
        call Rg_Get.ord
        ld b,a                      ; B - роу, C - последняя
.r      ld a,EDIT_LINE              ; строка экрана; не видна - мимо
        add a,b
        ld hl,Cur_Row
        sub (hl)
        cp FIRST_LINE
        jr c,.n
        cp FIRST_LINE+VIEW_ROWS
        jr nc,.n
        add a,SCR_BASE_H
        ld h,a
        ld a,(Ds_X0)
        add a,SCR_ATTR
        ld l,a
        ld a,(Ds_W)
        ld d,a
        ld a,(THEME_ATTR+CLR_SELECT)
.c      ld (hl),a
        inc l
        dec d
        jr nz,.c
.n      ld a,b
        cp c
        inc b
        jr c,.r
        ret


;-------- Numpad 1..8: октава ввода (номер - из сработавшего действия)
K_Oct   ld a,(Kt_Act)
        sub ACT_OCT_1-1
        ld (Cur_Octave),a
        ret

;-------- Ctrl+0..9: шаг, автошаг - вкл (как в VT); шаг - в трек
K_Step  ld a,(Kt_Act)
        sub ACT_STEP_0
        ld (Cur_Step),a
        ld a,1
        ld (Auto_Step),a
        jp Hd_Save

;-------- Enter: паттерн по кругу с текущей роу, пока держат (как в VT; En_Check - отпустили)
En_Key          db 0                ; клавиша, пока держат - играет (0 - нет)
K_PlayHold
        ld a,(En_Key)               ; автоповтор - уже играет
        or a
        ret nz
        ld a,(Kt_Key)
        ld (En_Key),a
        jp K_PlayPatRow
En_Check
        ld a,(En_Key)
        or a
        ret z
        call Key_Down               ; NZ - держат
        ret nz
        xor a
        ld (En_Key),a
        jp K_Stop

;-------- После ввода: курсор вниз на Cur_Step роу (если шаг включён - Auto_Step)
Step_Cur
        ld a,(Auto_Step)
        or a
        ret z
        ld a,(Cur_Step)
        or a
        ret z
        ld b,a
.s      push bc
        call K_RowDn
        pop bc
        djnz .s
        ret

;-------- Клик в паттерн (как в Bitphase): по Y - роу едут на столько, насколько клик выше
; или ниже строки редактирования; по X - курсор в поле под мышью (другой элемент - открыть)
Pp_Off          db 0                ; колонка клика в элементе
Pat_Press
        ld a,(SV_MOUSE_ROW)
        sub EDIT_LINE
        jr z,.x
        jr c,.up
        ld b,a                      ; ниже - вниз
.dn     push bc
        call K_RowDn
        pop bc
        djnz .dn
        jr .x
.up     neg                         ; выше - вверх
        ld b,a
.u      push bc
        call K_RowUp
        pop bc
        djnz .u
.x      ld a,(SV_MOUSE_COL)         ; элемент, в чьих колонках клик
        ld c,a
        ld a,(Vis_Items)
        ld b,a
        ld e,0                      ; E - элемент
.it     ld a,e
        ld hl,Item_Col
        call Arr_Get
        ld d,a
        ld a,c                      ; колонка в элементе
        sub d
        jr c,.nx
        ld d,a
        ld a,e
        ld hl,Item_W
        call Arr_Get
        cp d
        jr z,.nx
        jr c,.nx                    ; правее элемента
        ld a,d
        ld (Pp_Off),a
        ld a,e                      ; другой элемент - курсор туда
        ld hl,Cursor_Item
        cp (hl)
        call nz,Item_Go
        ld a,(Pp_Off)
        call Field_At
        ld (Cur_Field),a
        ret
.nx     inc e
        djnz .it
        ret

; A - колонка в элементе -> A - поле под ней (на пробеле - поле левее). По Env_Open
Field_At
        ld c,a
        ld a,(Env_Open)
        or a
        ld hl,Cf_Chan
        ld b,CF_CHAN_N
        jr z,$+7
        ld hl,Cf_Env
        ld b,CF_ENV_N
        ld e,0                      ; E - поле левее или под колонкой
        ld d,0                      ; D - номер поля
.f      ld a,c
        cp (hl)                     ; поле правее колонки - хватит
        jr c,.done
        ld e,d
        inc hl
        inc hl
        inc d
        djnz .f
.done   ld a,e
        ret

; Навигация по паттерну - только когда он в фокусе
Pat_Keys
        db ACT_UP
        dw K_Up
        db ACT_DOWN
        dw K_Down
        db ACT_PGUP
        dw K_PgUpN
        db ACT_PGDN
        dw K_PgDnN
        db ACT_LEFT
        dw K_Left
        db ACT_RIGHT
        dw K_Right
        db ACT_SEL_UP               ; выделение, буфер обмена, транспонирование
        dw K_SelUp
        db ACT_SEL_DOWN
        dw K_SelDn
        db ACT_SEL_LEFT
        dw K_SelLt
        db ACT_SEL_RIGHT
        dw K_SelRt
        db ACT_SEL_PGUP
        dw K_SelPU
        db ACT_SEL_PGDN
        dw K_SelPD
        db ACT_SEL_ALL
        dw K_SelAll
        db ACT_COPY
        dw K_Copy
        db ACT_CUT
        dw K_Cut
        db ACT_PASTE
        dw K_Paste
        db ACT_TR_UP
        dw K_TrUp
        db ACT_TR_DN
        dw K_TrDn
        db ACT_TR_OCT_UP
        dw K_TrOU
        db ACT_TR_OCT_DN
        dw K_TrOD
        db ACT_NEXT
        dw K_ChRight
        db ACT_PREV
        dw K_ChLeft
        db ACT_CLEAR
        dw K_Del                    ; выделение - кусок, нет - поле
        db ACT_AUTOSTEP
        dw H_AutoStep               ; Space - автошаг (как кнопка Step в шапке)
        db ACT_UNDO
        dw K_Undo
        db ACT_REDO
        dw K_Redo
        db ACT_INS_TRK
        dw K_InsTrk
        db ACT_INS_PAT
        dw K_InsPat
        db ACT_DEL_TRK
        dw K_DelTrk
        db ACT_DEL_PAT
        dw K_DelPat
        db ACT_ENTER
        dw K_PlayHold               ; Enter - паттерн с курсора, пока держат
        db ACT_OCT_1
        dw K_Oct
        db ACT_OCT_1+1
        dw K_Oct
        db ACT_OCT_1+2
        dw K_Oct
        db ACT_OCT_1+3
        dw K_Oct
        db ACT_OCT_1+4
        dw K_Oct
        db ACT_OCT_1+5
        dw K_Oct
        db ACT_OCT_1+6
        dw K_Oct
        db ACT_OCT_1+7
        dw K_Oct
        db ACT_STEP_0
        dw K_Step
        db ACT_STEP_0+1
        dw K_Step
        db ACT_STEP_0+2
        dw K_Step
        db ACT_STEP_0+3
        dw K_Step
        db ACT_STEP_0+4
        dw K_Step
        db ACT_STEP_0+5
        dw K_Step
        db ACT_STEP_0+6
        dw K_Step
        db ACT_STEP_0+7
        dw K_Step
        db ACT_STEP_0+8
        dw K_Step
        db ACT_STEP_0+9
        dw K_Step
        db 0

Btn_Shown       db 0                ; 1 - кнопка, которую держат, нарисована вдавленной

; Кнопка E (элемент 0..7 или OB_ID+n) вдавленной (A=1) или обычной (A=0).
; Рисуем, только когда вид меняется
Btn_Show
        ld hl,Btn_Shown
        cp (hl)
        ret z
        ld (hl),a
        ld c,a                      ; C - вдавлена?
        ld b,e
        ld a,b
        cp OB_ID
        jr nc,.ord
        ld hl,Item_Col
        call Arr_Get
        ld e,a
        ld a,b
        ld hl,Item_W
        call Arr_Get
        add a,e
        sub 2
        ld e,a
        ld d,SCR_BASE_H+VIEW_LINE
        ld a,(Open_Item)            ; [-] у открытого, [+] у остальных
        cp b
        ld a,GLYPH_BTN_PLUS
        jr nz,$+4
        ld a,GLYPH_BTN_MINUS
.press  bit 0,c
        jr z,$+4
        add a,BTN_PRESSED
        ld l,a                      ; L - значок: SETPAGE3 портит A и BC
        ld a,(SV_DRAW_PAGE)         ; кнопка - прямо на экране (окно 3)
        SETPAGE3 a
        ld a,d                      ; в полосе заголовков - цветом шапки
        cp SCR_BASE_H+VIEW_LINE
        ld a,l
        jr nz,.ord_btn
        call PutBtn_Head
        jr .shown
.ord_btn
        call PutBtn
.shown  RESTPAGE3
        ret
.ord    sub OB_ID                   ; кнопка ордера: её строка и значок
        ld b,a
        ld hl,OB_Row
        call Arr_Get
        add a,SCR_BASE_H
        ld d,a
        ld e,ORD_BTN_X
        ld a,b
        ld hl,OB_Glyph
        call Arr_Get
        jr .press

; Сработала кнопка E: элемента - [-] у открытого закрыть, [+] открыть;
; ордера - её действие из OB_Act
Btn_Action
        ld a,e
        sub OB_ID
        jr c,.item
        add a,a                     ; кнопка ордера: переход по OB_Act
        ld hl,OB_Act
        call Arr_Get
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.item   ld b,e
        ld a,(Open_Item)
        cp b
        jr z,.close
        ld a,b                      ; [+] - открыть: Env чипа или канал
        and 3
        jr z,.env
        ld a,b                      ; элемент -> канал: 1..3 -> 0..2, 5..7 -> 3..5
        dec a
        cp 4
        jr c,$+3
        dec a
        jp Set_Chan
.env    ld a,b                      ; Env: курсор на канал A этого чипа + Env
        rrca
        rrca
        and 1
        ld c,a
        add a,a
        add a,c                     ; 0 или 3
        ld (Cur_Chan),a
        ld a,1
        ld (Env_Open),a
        jp Need_Layout
.close  ld a,ITEM_NONE              ; ничего не открыто
        ld (Open_Item),a
        ld a,1                      ; раскладка без Calc_Open
        ld (Layout_Busy),a
        call Build_Layout_Keep
        xor a
        ld (Layout_Busy),a
        ret

; Как Build_Layout, но открытый элемент не пересчитывается
Build_Layout_Keep
        ld hl,Calc_Open             ; временно "ret" вместо Calc_Open
        ld a,(hl)
        push af
        push hl
        ld (hl),#C9
        call Build_Layout
        pop hl
        pop af
        ld (hl),a
        ret


;-------- Проигрывание: полотно идёт за плеером (SV_PLAY_POS / ROW)
Play_Step                           ; полотно - за плеером: он на другой роу - шаг вниз
        ld a,(SV_PLAY_CMD)          ; команду плеер ещё не взял - его роу старая:
        or a                        ; не шагаем, иначе курсор убежит вперёд и будет
        ret nz                      ; догонять плеер по кругу каждый кадр
        ld a,(SV_PLAY_STATE)
        or a
        ret z
        ld a,(SV_PLAY_ROW)
        ld hl,Cur_Row
        cp (hl)
        jp nz,K_RowDn
        ld a,(SV_PLAY_POS)
        ld hl,Cur_Pos
        cp (hl)
        ret z
        jp K_RowDn

; =========================================================================
; КНОПКИ ОРДЕРА (как в Bitphase). Номера паттернов руками не ведём: новый
; паттерн - следующий свободный номер.
;   Unique - у текущей позиции новый номер с копией паттерна (другие позиции
;            со старым номером не меняются)
;   Remove - убрать текущую позицию (паттерн остаётся; последнюю не убрать)
;   Add    - новый пустой паттерн - после текущей позиции, она становится текущей
;   Clone  - копия паттерна текущей позиции - после неё, становится текущей
; Нет свободного номера или ордер полон - кнопка ничего не делает.
; =========================================================================
O_New           db 0                ; номер нового паттерна

O_Add   call Ord_Room
        ret c
        call Pat_Free
        ret c
        ld (O_New),a
        call Pat_Empty
        jr Ord_Insert

O_Clone call Ord_Room
        ret c
        call Pat_Free
        ret c
        ld (O_New),a
        call Pat_Dup
        jr Ord_Insert

O_Unique
        call Pat_Free
        ret c
        ld (O_New),a
        call Pat_Dup
        ld a,(Cur_Pos)              ; текущая позиция - на новый номер
        ld hl,Ord_List
        call Arr_Get
        ld a,(O_New)
        ld (hl),a
        jp Ord_Changed

O_Remove
        ld a,(Ord_Last)             ; последнюю не убрать
        or a
        ret z
        ld a,(Cur_Pos)              ; позиции после текущей - на одну назад
        ld hl,Ord_List+1
        call Arr_Get                ; HL - позиция Cur_Pos+1
        ld d,h
        ld e,l
        dec de
        ld a,(Cur_Pos)
        ld b,a
        ld a,(Ord_Last)
        sub b                       ; сколько их (0 - текущая была последней)
        jr z,.cut
        ld c,a
        ld b,0
        ldir
.cut    ld hl,Ord_Last
        dec (hl)
        ld a,(Cur_Pos)              ; повтор после текущей - на одну назад
        ld b,a
        ld a,(Loop_Pos)
        cp b
        jr z,.lp
        jr c,.lp
        dec a
.lp     ld b,(hl)                   ; позиции не дальше последней
        cp b
        jr c,$+3
        ld a,b
        ld (Loop_Pos),a
        ld a,(Cur_Pos)
        cp b
        jr c,$+3
        ld a,b
        ld (Cur_Pos),a
        jr Ord_Changed

; CF - ордер полон, вставлять некуда
Ord_Room
        ld a,(Ord_Last)
        cp ORD_VIEW_MAX-1
        ccf
        ret

; Паттерн O_New - в ордер после текущей позиции, она становится текущей
Ord_Insert
        ld a,(Cur_Pos)              ; позиции после текущей - на одну вперёд
        ld b,a
        ld a,(Ord_Last)
        sub b                       ; сколько их
        jr z,.put
        ld c,a
        ld a,(Ord_Last)
        ld hl,Ord_List
        call Arr_Get                ; HL - последняя
        ld d,h
        ld e,l
        inc de
        ld b,0
        lddr
.put    ld hl,Ord_Last
        inc (hl)
        ld a,(Cur_Pos)              ; новая - текущая
        inc a
        ld (Cur_Pos),a
        ld b,a
        ld hl,Ord_List
        call Arr_Get
        ld a,(O_New)
        ld (hl),a
        ld a,(Loop_Pos)             ; повтор после старой текущей - на одну вперёд
        cp b
        jr c,Ord_Changed
        inc a
        ld (Loop_Pos),a
Ord_Changed                         ; новая позиция - с роу 0, ордер перерисовать
        call Song_Sync              ; ордер и каталог - в страницу трека (для плеера)
        xor a
        ld (Cur_Row),a
        ld (Pat_Loops),a
        inc a
        ld (Order_Pending),a
        ret

; A = свободный номер паттерна, CF - свободных нет
Pat_Free
        ld hl,Pat_Exists
        ld b,0
.l      ld a,(hl)
        or a
        jr z,.ok
        inc hl
        inc b
        ld a,b
        cp PATTERNS_MAX
        jr c,.l
        scf
        ret
.ok     ld a,b                      ; CF = 0 после or a
        ret

; Паттерн O_New - пустой: данные 0, текст, длина по умолчанию
Pat_Empty
        ld a,(O_New)
        call Pat_Page
        SETPAGE2 a
        ld h,PAT_BASE_H             ; данные всех роу - 0
.r      ld l,0
        ld b,PAT_DATA_SIZE
.c      ld (hl),0
        inc l
        djnz .c
        inc h
        ld a,h
        cp PAT_BASE_H+PAT_ROWS_MAX
        jr c,.r
        call Init_Pat_Text
        RESTPAGE2
        ld e,PAT_ROWS_MAX
        jr Pat_Mark

; Паттерн O_New = копия паттерна текущей позиции (страница целиком, длина)
Pat_Dup
        ld a,(Cur_Pos)
        ld hl,Ord_List
        call Arr_Get
        ld (PC_Src),a
        ld hl,Pat_Len
        call Arr_Get
        push af
        call Pat_Copy
        pop af
        ld e,a
; Паттерн O_New есть, длина E
Pat_Mark
        ld a,(O_New)
        ld hl,Pat_Len
        call Arr_Set_E
        ld a,(O_New)
        ld hl,Pat_Exists
        ld e,1
        jp Arr_Set_E

;-------- Страница паттерна PC_Src -> страница O_New. DMA, 4 куска по 16 роу
; (4К, ~9000 T). Каждый кусок - сразу после halt: IM1 только что отработал,
; до следующего - кадр, DMA наша, порты пишем без DI.
PC_Src          db 0
PC_Row          db 0

Pat_Copy
        xor a
        ld (PC_Row),a
.k      halt
        call dma_wait               ; C = #AF
        ld a,(PC_Src)
        call Pat_Page
        ld b,high DMASADDRX
        out (c),a
        ld a,(O_New)
        call Pat_Page
        ld b,high DMADADDRX
        out (c),a
        xor a                       ; с колонки 0, строка = роу
        ld b,high DMASADDRL
        out (c),a
        ld b,high DMADADDRL
        out (c),a
        ld a,(PC_Row)
        ld b,high DMASADDRH
        out (c),a
        ld b,high DMADADDRH
        out (c),a
        ld a,127                    ; 256 байт
        ld b,high DMALEN
        out (c),a
        ld a,15                     ; 16 роу
        ld b,high DMANUM
        out (c),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a
        ld a,(PC_Row)
        add a,16
        ld (PC_Row),a
        cp PAT_ROWS_MAX
        jr c,.k
        jp dma_wait

; =========================================================================
; ПОЛОСА ВРЕМЕНИ
; =========================================================================
BAND_W          equ PALET_NUM*16    ; слово CRAM

; A - цвет. Из IM1 (своя таблица DMA)
Band_Int
        add a,a
        add a,low (Band_Colors-#4000)
        ld (Band_T+1),a
        ld a,high (Band_Colors-#4000)
        adc a,0
        ld (Band_T+3),a
        ld hl,Band_T
        jp set_ports_int

; A - цвет. Из основного цикла: запоминаем, IM1 в конце вернёт его
Band_Main
        ld (Band_Cur),a
        ld b,a
        ld a,(Timing)
        or a
        ret z
        ld a,b
        add a,a
        add a,low (Band_Colors-#4000)
        ld (Band_TM+1),a
        ld a,high (Band_Colors-#4000)
        adc a,0
        ld (Band_TM+3),a
        ld hl,Band_TM
        jp set_ports

Band_Cur        db 0

Band_T  db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,PAGE_TOOL_PATVIEW
        db high DMADADDRL,(BAND_W&127)*2, high DMADADDRH,BAND_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
Band_TM db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,PAGE_TOOL_PATVIEW
        db high DMADADDRL,(BAND_W&127)*2, high DMADADDRH,BAND_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF

        ALIGN 2                     ; цвет: младший gggBBbbb, старший 0RRrrrGG
Band_Colors
Band_Bg         dw 0                ; 0 - обычный фон (копия из палитры)
                db %00000000, %01100000     ; 1 красный
                db %00000000, %01100011     ; 2 жёлтый
                db %00000000, %00000011     ; 3 зелёный
                db %00011000, %00000000     ; 4 синий
                db %00011000, %01100000     ; 5 фиолетовый
                db %00011000, %00000011     ; 6 голубой
                db %00011000, %01100011     ; 7 белый
                db %00000000, %01100001     ; 8 оранжевый - замер DMA

    include "srs/head.asm"

; =========================================================================
; ТРЕК В ВИДЕ: копии из страницы трека (Song_Reload), правки - обратно (Song_Sync)
; =========================================================================
Pat_Len         ds PATTERNS_MAX,PAT_ROWS_MAX    ; длина паттерна
Pat_Exists      ds PATTERNS_MAX,0               ; 1 - паттерн есть (номер занят)
Ord_List        ds ORD_VIEW_MAX,0             ; ордер: номера паттернов
ORD_VIEW_MAX  equ 255             ; позиций в виде (длина ордера - байт: 1..255)

;-------- Трек для плеера: страница текущего трека - скорость, страница
; инструментов, ордер, повтор, каталог паттернов (страница и длина). Пока трек
; живёт в переменных вида (Ord_List, Pat_Len...) - копируем туда при каждой правке
Cur_Step        db NEW_SONG_STEP    ; шаг курсора (копия SH_STEP, её кладёт Head_Load)

Song_Sync
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Ord_Last)
        ld (#8000+ORD_LAST),a
        ld a,(Loop_Pos)
        ld (#8000+ORD_LOOP),a
        ld hl,Ord_List
        ld de,#8000+ORD_POS
        ld bc,ORD_VIEW_MAX
        ldir
        ld hl,#8000+PAT_CATALOG     ; каталог: страница (0 - нет), длина
        ld de,Pat_Len
        ld ix,Pat_Exists
        ld c,0                      ; C - номер паттерна
.p      ld a,(ix+0)
        or a
        jr z,.none
        ld a,c
        call Pat_Page
.none   ld (hl),a
        inc hl
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        inc ix
        inc c
        ld a,c
        cp PATTERNS_MAX
        jr c,.p
        RESTPAGE2
        ret


;-------- Трек загрузили (тулза диска, srs/diskview.asm): страница трека - правда,
; вид берёт из неё ордер, повтор и каталог паттернов, текст роу строит заново.
; Паттерн n - в странице Trk_Pat+n (загрузка кладёт его туда же)
Song_Reload
        call Ud_Reset               ; отмена - другого трека
        xor a
        ld (SV_SONG_NEW),a
        ld (Cur_Pos),a
        ld (Cur_Row),a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(#8000+ORD_LAST)       ; позиций - не больше, чем держит вид
        cp ORD_VIEW_MAX
        jr c,$+4
        ld a,ORD_VIEW_MAX-1
        ld (Ord_Last),a
        ld b,a
        ld a,(#8000+ORD_LOOP)       ; повтор - не за последней
        cp b
        jr c,.lp
        jr z,.lp
        xor a
.lp     ld (Loop_Pos),a
        ld hl,#8000+ORD_POS
        ld de,Ord_List
        ld bc,ORD_VIEW_MAX
        ldir
        ld hl,#8000+PAT_CATALOG     ; каталог: есть ли паттерн, длина
        ld de,Pat_Len
        ld ix,Pat_Exists
        ld b,PATTERNS_MAX
.p      ld a,(hl)                   ; страница: 0 - нет
        or a
        jr z,$+4
        ld a,1
        ld (ix+0),a
        inc hl
        ld a,(hl)                   ; длина: 0 - считаем 64
        or a
        jr nz,$+4
        ld a,PAT_ROWS_MAX
        ld (de),a
        inc hl
        inc de
        inc ix
        djnz .p
        RESTPAGE2
        xor a                       ; текст роу всех паттернов, что есть
        ld (Rl_Pat),a
.t      ld a,(Rl_Pat)
        ld hl,Pat_Exists
        call Arr_Get
        or a
        jr z,.next
        ld a,(Rl_Pat)
        call Pat_Page
        SETPAGE2 a
        call Init_Pat_Text
        RESTPAGE2
.next   ld hl,Rl_Pat
        inc (hl)
        ld a,(hl)
        cp PATTERNS_MAX
        jr c,.t
        ret
Rl_Pat          db 0

; =========================================================================
; Простой вывод (рамки, ордер). PutCh, PutStr, PutHex2 - в коре (srs/text.asm)
; =========================================================================
PutBar
        push bc
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,BOX_V
        call PutCh
        pop bc
        ret

; Кнопка A (2 знакоместа: A, A+1; нажатая - A+BTN_PRESSED) цветом CLR_BUTTON. E += 2
PutBtn
        push bc
        ld b,a
        ld a,(THEME_ATTR+CLR_BUTTON)
Pb_Draw ld c,a
        ld a,b                      ; левая половина
        call PutCh
        ld a,b                      ; правая
        inc a
        call PutCh
        pop bc
        ret

; То же цветом шапки (CLR_HEAD_BTN): кнопки в шапке и в полосе заголовков паттерна
PutBtn_Head
        push bc
        ld b,a
        ld a,(THEME_ATTR+CLR_HEAD_BTN)
        jr Pb_Draw

; HL - поле. Z - оно в фокусе. Портит A, HL
Is_Focus
        push de
        ld de,(SV_FOCUS)
        or a
        sbc hl,de
        pop de
        ret

;-------- Цвет номера роу: каждая 4-я своим цветом (оба - готовые из темы)
Build_Row_A
        ld h,high Row_A
        ld l,0
.r      ld a,l
        and 3
        ld a,(THEME_ATTR+CLR_ROW_NUM)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_ROW_BEAT)
        ld (hl),a
        inc l
        jr nz,.r
        ret

; =========================================================================
; ТАБЛИЦЫ-ПЛОСКОСТИ (каждая 256 байт на границе 256, индекс - само значение)
; hex-цифра d -> символ: '0'+d+((d+6)>>4)*7
; =========================================================================
        ALIGN 256
Note_T  db '.'                      ; 0 "...", 1..96 "C-1".."B-8" (как PT3/VT, период - Note_Per), 97 "OFF", дальше "???"
        DUP 8
        db "CCDDEFFGGAAB"
        EDUP
        db 'O'
        ds 256-98,'?'
        db '.'
        DUP 8
        db "-#-#--#-#-#-"
        EDUP
        db 'F'
        ds 256-98,'?'
        db '.'
        DUP 8,O
        DUP 12
        db '1'+O
        EDUP
        EDUP
        db 'F'
        ds 256-98,'?'

Hex_T   DUP 256,N                   ; 2 hex всегда
        db '0'+(N>>4)+(((N>>4)+6)>>4)*7
        EDUP
        DUP 256,N
        db '0'+(N&15)+(((N&15)+6)>>4)*7
        EDUP

HexD_T  db '.'                      ; 2 hex, 0 = ".."; #20 (шум 0 - CHIP_NOISE) = "00"
        DUP 255,N
        IF N+1 == #20
        db '0'
        ELSE
        db '0'+((N+1)>>4)+((((N+1)>>4)+6)>>4)*7
        ENDIF
        EDUP
        db '.'
        DUP 255,N
        db '0'+((N+1)&15)+((((N+1)&15)+6)>>4)*7
        EDUP

Row_A   ds 256                      ; цвет номера роу

Sym_T   db '.'                      ; 0 ".", 1..9, A..W, дальше "?"
        DUP 9,I
        db '1'+I
        EDUP
        DUP 23,I
        db 'A'+I
        EDUP
        ds 256-33,'?'

Hx1_T   db '.'                      ; 0 ".", 1..F, дальше "?"
        DUP 15,I
        db '0'+(I+1)+(((I+1)+6)>>4)*7
        EDUP
        ds 256-16,'?'
Tables_End

    ASSERT Hex_T == Note_T+3*256
    ASSERT HexD_T == Hex_T+2*256
    ASSERT Row_A == HexD_T+2*256
    ASSERT Sym_T == Row_A+256
    ASSERT Hx1_T == Sym_T+256
    ASSERT Tables_End == Hx1_T+256

    ENDMODULE

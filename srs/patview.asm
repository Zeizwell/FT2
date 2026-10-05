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

PAT_PAGE        equ PAGE_POOL       ; паттерн n = страница PAT_PAGE+n (пока один трек)
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
BAND_DMATEST    equ 8               ; замер: DMA-заливка 4К         - оранжевый

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
        ld hl,(Palette_Data)        ; цвет фона - для полосы времени
        ld (Band_Bg),hl
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        xor a                       ; X-офсет текстового режима не используем
        ld bc,GXOFFSL
        out (c),a
        ld bc,GXOFFSH
        out (c),a
        call Build_Row_A
        call Init_RowNum            ; страница номеров роу
        call Test_Song              ; тестовые паттерны (данные + текст) и ордер
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
        ld a,(Timing)               ; замер: DMA-заливка 4К (оранжевый)
        or a
        call nz,Bench_Dma_Fill
        BAND_M BAND_INPUT
        call Handle_Keys
        call Dbg_Show               ; отладка ввода - временно
        call Head_Show              ; шапка: значения (srs/head.asm)
        call Time_Tick              ; время игры
        call Fld_Update             ; мышь и колесо - полям (коре, srs/fields.asm)
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

; --- состояние
Cur_Chan        db 0                ; канал под курсором 0..5
Env_Open        db 0                ; 1 - открыт Env чипа курсора, а не канал
Open_Item       db 1                ; открытый элемент 0..7, ITEM_NONE - нет
Layout_Pending  db 0
Layout_Busy     db 0                ; 1 - раскладка меняется, IM1 паттерн не рисует
Order_Pending   db 0
Playing         db 0
Src_Mode        db 1                ; 1 - полотно по ордеру (сонг, стоп), 0 - паттерн по кругу
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
; DMA ходит словами: начало вниз до чётного (в тексте - на столько же), длина -
; вверх до целых слов. Лишний знак с краёв падает на колонку-разделитель
Set_Tile
        ld a,e
        and 1                       ; H - сдвиг до чётного
        ld h,a
        ld a,c
        sub h
        ld (ix+TILE_SCOL),a         ; колонка в тексте
        ld a,e
        sub h
        ld (ix+TILE_DCOL),a         ; колонка на экране
        ld a,d                      ; слов-1 = (ширина + сдвиг + 1) / 2 - 1
        add a,h
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
        ld hl,Test_Order
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
        add a,PAT_PAGE
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
        ld hl,Test_Order
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
.edge   ld a,(Src_Mode)
        or a
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
        ld a,(Src_Mode)
        or a
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
F_SYM           equ 4               ; сэмпл/орнамент, 1 знак (1..W)
F_HX1           equ 5               ; огибающая/громкость, 1 hex
F_CMD           equ 6               ; команда: 2 байта как лежат, 4 hex; 0,0 - "...."
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
        db F_SYM,  (src)+CH_ORNAMENT,  TX_BLOCK+(cx)-CONT_X+6
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
        jr nz,.envp
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
        jr .f
.hx1    ld e,c
        ld d,high Hx1_T
        ld a,(de)
        ld (hl),a
        jr .f
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
; Горячие клавиши вида паттерна: код PS/2 (E0-коды +128), модификаторы (KM_*,
; точное совпадение), обработчик. Конец - 0. Автоповтор даёт коре (Key_Get).
K_UP            equ #75+#80         ; стрелки, PgUp/PgDn - E0-коды
K_DOWN          equ #72+#80
K_LEFT          equ #6B+#80
K_RIGHT         equ #74+#80
K_PGUP          equ #7D+#80
K_PGDN          equ #7A+#80
K_TAB           equ #0D
K_ESC           equ #76
K_F5            equ #03
K_F6            equ #0B
K_F7            equ #7F             ; F7 (#83) коре сводит в #7F
K_F8            equ #0A
K_E             equ #24
K_T             equ #2C
K_D             equ #23

Hotkeys db K_F5,    0               ; общие клавиши вида; F5..F8, Esc - как в VT
        dw K_PlaySong               ; сонг с текущей позиции
        db K_F6,    0
        dw K_PlayStart              ; сонг с начала
        db K_F7,    0
        dw K_PlayPatRow             ; паттерн с текущей роу
        db K_F8,    0
        dw K_PlayPat                ; паттерн с начала
        db K_ESC,   0
        dw K_Stop
        db K_E,     KM_CTRL
        dw K_EnvOpen                ; Ctrl+E - открыть Env чипа
        db K_E,     KM_ALT
        dw K_EnvNote                ; Alt+E - период огибающей нотой / числом
        db K_T,     KM_CTRL
        dw K_Timing                 ; Ctrl+T - полоса времени
        db K_D,     KM_CTRL
        dw K_DiskTest               ; Ctrl+D - проверка диска (временно)
        db 0

;-------- Все события клавиатуры за кадр: сначала полю в фокусе (навигация
; паттерна или ордера), не съело - общей таблице Hotkeys
Handle_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld (Dbg_Key),a              ; отладка: последнее событие (Dbg_Show)
        ld b,a
        ld a,c
        ld (Dbg_Flags),a
        ld (HK_Code),bc
        call Fld_Key                ; полю в фокусе
        jr c,.k
        ld bc,(HK_Code)
        ld hl,Hotkeys
        call Keys_Table
        jr .k
HK_Code         dw 0

;-------- ОТЛАДКА ВВОДА (временно): на нижней рамке слева "K:код флаги M:модификаторы"
; код - последнее событие клавиатуры (PS/2, E0 +128), флаги - KM_* | KF_REPEAT,
; M - SV_KEY_MODS сейчас (1 Shift, 2 Ctrl, 4 Alt)
Dbg_Key         db 0
Dbg_Flags       db 0
Dbg_Show
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld d,SCR_BASE_H+BOTTOM_LINE
        ld e,1
        ld hl,Txt_Dbg_K
        call PutStr
        ld a,(Dbg_Key)
        call PutHex2
        ld a,' '
        call PutCh
        ld a,(Dbg_Flags)
        call PutHex2
        ld hl,Txt_Dbg_M
        call PutStr
        ld a,(SV_KEY_MODS)
        call PutHex2
        ld hl,Txt_Dbg_D             ; результат проверки диска: A и флаги
        call PutStr
        ld a,(Dbg_Disk+1)
        call PutHex2
        ld a,' '
        call PutCh
        ld a,(Dbg_Disk)
        jp PutHex2
Txt_Dbg_K       db "K:",0
Txt_Dbg_M       db " M:",0
Txt_Dbg_D       db " D:",0

;-------- ПРОВЕРКА ДИСКА (временно, Ctrl+D): смонтировать карту, найти в корне
; папку TMPFT (туда build.bat кладёт ft2.spg). Только чтение. Результат -
; в отладочной строке "D:AA FF": A и флаги последнего вызова драйвера.
;   монтирование: A=0, Z - готово;  поиск: найдено - A=1, NZ, CF=0 (FF = ..00..);
;   не найдено - Z, CF=0; ошибка - CF=1 (FF нечётный)
Dbg_Disk        dw #FFFF            ; ещё не проверяли - "FF FF"
Dt_Name         db #10,"TMPFT",0    ; #10 - ищем каталог

K_DiskTest
        call Disk_Mount
        jr nz,.res
        ld ix,DK_FIND+#100          ; IXH=1 - имя по HL скопировать к переходнику
        ld hl,Dt_Name
        call Disk_Call
.res    push af
        pop hl
        ld (Dbg_Disk),hl
        ret

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
Need_Layout
        ld a,1
        ld (Layout_Pending),a
        ret
K_EnvOpen
        ld hl,Env_Open
        ld a,(hl)
        xor 1
        ld (hl),a
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
        add a,PAT_PAGE
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
K_PlaySong                          ; сонг с начала текущей позиции
        ld a,1
        ld (Src_Mode),a
        jr Play_From0
K_PlayPat                           ; текущий паттерн по кругу с начала
        xor a
        ld (Src_Mode),a
Play_From0
        xor a
        ld (Cur_Row),a
        jr Play_Go
K_PlayPatRow                        ; текущий паттерн по кругу с текущей роу
        xor a
        ld (Src_Mode),a
Play_Go
        xor a
        ld (Pat_Loops),a
        ld (Play_Tick),a
        ld a,1
        ld (Playing),a
        call Time_Reset             ; время игры - с нуля
        ld a,(Cur_Pos)              ; команда плееру: откуда (сначала параметры,
        ld (SV_PLAY_CPOS),a         ; команда - последней: IM1 может влезть)
        ld a,(Cur_Row)
        ld (SV_PLAY_CROW),a
        ld a,(Src_Mode)
        or a
        ld a,PC_SONG
        jr nz,$+4
        ld a,PC_PATTERN
        ld (SV_PLAY_CMD),a
        ret
K_Stop  xor a                       ; стоп: остаёмся где стоим, полотно - по ордеру
        ld (Playing),a
        ld (Pat_Loops),a
        inc a
        ld (Src_Mode),a
        ld a,PC_STOP
        ld (SV_PLAY_CMD),a
        ret
K_Continue                          ; продолжить сонг с текущего места (для кнопки)
        ld a,1
        ld (Src_Mode),a
        jr Play_Go

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
        db K_UP,   0
        dw Ord_Prev
        db K_DOWN, 0
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
        jp Keys_Table
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

; Навигация по паттерну - только когда он в фокусе
Pat_Keys
        db K_UP,    0
        dw K_RowUp
        db K_DOWN,  0
        dw K_RowDn
        db K_PGUP,  0
        dw K_PageUp
        db K_PGDN,  0
        dw K_PageDn
        db K_LEFT,  0
        dw K_ChLeft
        db K_RIGHT, 0
        dw K_ChRight
        db K_TAB,   0
        dw K_ChRight
        db K_TAB,   KM_SHIFT
        dw K_ChLeft
        db 0

;-------- Таблица клавиш: HL - таблица (код, модификаторы точно, обработчик; конец 0),
; B - код, C - флаги события. Выход: CF - клавиша наша (обработчик вызван)
Keys_Table
        ld a,c
        and KM_SHIFT|KM_CTRL|KM_ALT ; повтор и нажатие для таблицы одинаковы
        ld c,a
.f      ld a,(hl)                   ; код, 0 - конец таблицы
        or a
        ret z                       ; не наша (CF = 0)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)                   ; модификаторы
        dec hl
        cp c
        jr nz,.n
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call .jp
        scf
        ret
.n      inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.jp     jp (hl)

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
        ld a,(Playing)
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
        ld hl,Test_Order
        call Arr_Get
        ld a,(O_New)
        ld (hl),a
        jp Ord_Changed

O_Remove
        ld a,(Ord_Last)             ; последнюю не убрать
        or a
        ret z
        ld a,(Cur_Pos)              ; позиции после текущей - на одну назад
        ld hl,Test_Order+1
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
        cp ORDER_TEST_MAX-1
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
        ld hl,Test_Order
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
        ld hl,Test_Order
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
        add a,PAT_PAGE
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
        ld hl,Test_Order
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
        add a,PAT_PAGE
        ld b,high DMASADDRX
        out (c),a
        ld a,(O_New)
        add a,PAT_PAGE
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
; ПОЛОСА ВРЕМЕНИ И ЗАМЕР DMA
; =========================================================================
BAND_W          equ PALET_NUM*16    ; слово CRAM

;-------- Замер: DMA FILL 4К (16 строк по 256) в свободную страницу, фон оранжевый
Bench_Dma_Fill
        BAND_M BAND_DMATEST
        ld hl,Bench_T
        call set_ports
        call dma_wait
        BAND_M BAND_BG
        ret

Bench_T db high DMASADDRL,(Bench_Zero-#4000)&255, high DMASADDRH,(Bench_Zero-#4000)>>8
        db high DMASADDRX,PAGE_TOOL_PATVIEW
        db high DMADADDRL,0, high DMADADDRH,0, high DMADADDRX,PAGE_BENCH
        db high DMALEN,127, high DMANUM,15, high DMACTR,DMA_FILL|DMA_DALGN, #FF

        ALIGN 2
Bench_Zero      dw 0

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
; ТЕСТОВЫЙ ТРЕК: 8 паттернов разной длины, длинный ордер (для плея сонга).
; Все поля непустые (худший случай), значения зависят от паттерна, роу и
; канала - сразу видно, откуда строка.
; =========================================================================
TEST_PATS       equ 8
Pat_Len         db 64,16,32,1,48,8,64,24   ; длина паттерна 0..7
                ds PATTERNS_MAX-TEST_PATS,64
Pat_Exists      ds TEST_PATS,1       ; 1 - паттерн есть (номер занят)
                ds PATTERNS_MAX-TEST_PATS,0
Test_Order      db 0,1,2,3,3,3,4,5,5,6,1,7,2,0,3,4,6,5,7,1,2,0,6,7
TEST_ORD_N      equ $-Test_Order
                ds ORDER_TEST_MAX-TEST_ORD_N,0
ORDER_TEST_MAX  equ 64

Test_Song
        call Song_Clear             ; новый трек: заголовок (скорость, шаг 4...)
        call Test_Instr             ; инструменты и орнаменты - в их страницу
        ld a,TEST_ORD_N-1
        ld (Ord_Last),a
        ld a,2                      ; повтор - с позиции 2
        ld (Loop_Pos),a
        xor a                       ; номер паттерна - в памяти: SETPAGE работает
        ld (TF_Pat),a               ; через стек, push/pop вокруг него нельзя
.p      ld a,(TF_Pat)
        add a,PAT_PAGE
        SETPAGE2 a                  ; страница паттерна - в окно 2
        call Test_Fill
        call Init_Pat_Text
        RESTPAGE2
        ld hl,TF_Pat
        inc (hl)
        ld a,(hl)
        cp TEST_PATS
        jr c,.p
        jp Song_Sync                ; трек - в его страницу (для плеера)

;-------- Трек для плеера: страница трека PAGE_SONG1 - скорость, страница
; инструментов, ордер, повтор, каталог паттернов (страница и длина). Пока трек
; живёт в переменных вида (Test_Order, Pat_Len...) - копируем туда при каждой правке
NEW_SONG_SPEED  equ 3               ; новый трек: скорость
NEW_SONG_STEP   equ 4               ;   шаг курсора при вводе
NEW_SONG_FORMAT equ 1
NEW_SONG_DEVICE equ 0               ;   тип чипа: AY (чипов - CHIPS_MAX, 6 каналов)

;-------- Новый трек: заголовок страницы трека PAGE_SONG1 - нули, подпись, формат,
; чипы, скорость, шаг, страница инструментов. Ордер и каталог - Song_Sync
Song_Clear
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld hl,#8000+SONG_HDR        ; заголовок - нули
        ld de,#8000+SONG_HDR+1
        ld bc,255
        ld (hl),0
        ldir
        ld hl,Txt_Sign
        ld de,#8000+SH_SIGN
        ld bc,4
        ldir
        ld a,NEW_SONG_FORMAT
        ld (#8000+SH_FORMAT),a
        ld a,CHIPS_MAX
        ld (#8000+SH_CHIPS),a
        ld a,NEW_SONG_SPEED
        ld (#8000+SH_SPEED),a
        ld a,NEW_SONG_DEVICE
        ld (#8000+SH_DEVICE),a
        ld a,NEW_SONG_STEP
        ld (#8000+SH_STEP),a
        ld a,PAGE_INS1
        ld (#8000+SH_INS_PAGE),a
        RESTPAGE2
        ld a,NEW_SONG_STEP          ; шаг - и в переменную вида (шапка, ввод)
        ld (Cur_Step),a
        ret
Txt_Sign        db "FT2S"
Cur_Step        db NEW_SONG_STEP    ; шаг курсора (копия SH_STEP)

Song_Sync
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld a,(Ord_Last)
        ld (#8000+ORD_LAST),a
        ld a,(Loop_Pos)
        ld (#8000+ORD_LOOP),a
        ld hl,Test_Order
        ld de,#8000+ORD_POS
        ld bc,ORDER_TEST_MAX
        ldir
        ld hl,#8000+PAT_CATALOG     ; каталог: страница (0 - нет), длина
        ld de,Pat_Len
        ld ix,Pat_Exists
        ld c,0                      ; C - номер паттерна
.p      ld a,(ix+0)
        or a
        jr z,.none
        ld a,c
        add a,PAT_PAGE
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

TF_Pat          db 0

;-------- Тестовые инструменты и орнаменты (формат FTC, sdk/plugin.asm) - в страницу
; инструментов трека PAGE_INS1. Остальные номера - по умолчанию (Ins_Clear)
Test_Instr
        ld a,PAGE_INS1
        call Ins_Clear
        ld ix,Ti_List
.l      ld l,(ix+0)                 ; блок, 0 - конец
        ld h,(ix+1)
        ld a,h
        or l
        ret z
        ld e,(ix+2)                 ; смещение в странице
        ld d,(ix+3)
        ld c,(ix+4)                 ; длина
        ld b,(ix+5)
        ld a,PAGE_INS1
        push ix
        call Ins_Put
        pop ix
        ld de,6
        add ix,de
        jr .l

Ti_List dw Ti_Pluck,  0*INS_BLOCK, TI_LEN   ; инструмент 1
        dw Ti_Drum,   1*INS_BLOCK, TI_LEN   ; 2
        dw Ti_Bass,   2*INS_BLOCK, TI_LEN   ; 3
        dw Ti_Vib,    3*INS_BLOCK, TI_LEN   ; 4
        dw To_Major,  ORN_BASE+0*ORN_BLOCK, TO_LEN  ; орнамент 1
        dw To_Minor,  ORN_BASE+1*ORN_BLOCK, TO_LEN  ; 2
        dw To_Octave, ORN_BASE+2*ORN_BLOCK, TO_LEN  ; 3
        dw 0
TI_LEN          equ INS_NAME+16     ; хвост дальше имени - нули (Ins_Clear)
TO_LEN          equ ORN_NAME+16

    ; Строка инструмента: шум (7 накопл, 6 ВЫКЛ, 4..0), тон мл, тон ст (7 накопл,
    ; 6 ВЫКЛ, 4 ретриггер, 3..0), громкость (7 накопл огиб, 6 огиб ВКЛ, 5 слайд,
    ; 4 вниз, 3..0), смещение огибающей
    MACRO TI_TAIL blk,name
        ds blk+INS_FX-$,0
        db 0                        ; без FX
        ds blk+INS_NAME-$,0
        db name
        ds blk+INS_NAME+16-$,' '
    ENDM
    MACRO TO_TAIL blk,name
        ds blk+ORN_NAME-$,0
        db name
        ds blk+ORN_NAME+16-$,' '
    ENDM

Ti_Pluck                            ; затухание 15..0, цикл на тишине
        db 15,15,15
.v = 15
        DUP 16
        db #40,0,0,.v,0
.v = .v-1
        EDUP
        TI_TAIL Ti_Pluck,"Pluck"
Ti_Drum                             ; шум без тона, громкость вниз, шум растёт
        db 7,7,7
        db #00,0,#40,15,0
        db #02,0,#40,13,0
        db #04,0,#40,11,0
        db #06,0,#40,9,0
        db #08,0,#40,7,0
        db #0A,0,#40,5,0
        db #0C,0,#40,3,0
        db #40,0,#40,0,0            ; тишина, цикл
        TI_TAIL Ti_Drum,"Drum"
Ti_Bass                             ; тон + огибающая
        db 0,0,0
        db #40,0,0,#40|15,0
        TI_TAIL Ti_Bass,"EnvBass"
Ti_Vib                              ; вибрато: тон накоплением +1 +1 -1 -1
        db 3,0,3
        db #40,#01,#80,15,0
        db #40,#01,#80,15,0
        db #40,#FF,#8F,15,0         ; -1 в 12 битах
        db #40,#FF,#8F,15,0
        TI_TAIL Ti_Vib,"Vibrato"

    ; Строка орнамента: шум (7 накопл шума, 6 накопл ноты, 4..0), смещение ноты
To_Major
        db 2,0,2
        db 0,0, 0,4, 0,7
        TO_TAIL To_Major,"Major"
To_Minor
        db 2,0,2
        db 0,0, 0,3, 0,7
        TO_TAIL To_Minor,"Minor"
To_Octave
        db 1,0,1
        db 0,0, 0,12
        TO_TAIL To_Octave,"Octave"

; Паттерн в окне 2 (номер - TF_Pat): все 64 роу данных
Test_Fill
        ld h,PAT_BASE_H
        ld c,0                      ; C - роу
.row    ld l,0
        ld b,CHIPS_MAX
.chip   push bc
        ld (hl),c                   ; период огибающей: мл = роу, ст = паттерн+1
        inc l
        ld a,(TF_Pat)
        inc a
        ld (hl),a
        inc l
        ld a,(TF_Pat)               ; огибающая-2: мл = паттерн, ст = роу
        ld (hl),a
        inc l
        ld (hl),c
        inc l
        ld a,c                      ; шум 1..32
        and #1F
        inc a
        ld (hl),a
        inc l
        ld a,c                      ; нота огибающей: в каждой 4-й роу (роу+1), иначе 0
        and 3
        ld a,0
        jr nz,$+4
        ld a,c
        inc a
        ld (hl),a
        inc l
        ld (hl),0                   ; резерв
        inc l
        ld (hl),0
        inc l
        ld b,3                      ; 3 канала
.ch     push bc
        ld a,b                      ; нота: (роу + канал*11 + паттерн*5) mod 96 + 1
        add a,a
        add a,a
        add a,a
        add a,b
        add a,b
        add a,b
        add a,c
        ld e,a
        ld a,(TF_Pat)
        ld d,a
        add a,a
        add a,a
        add a,d
        add a,e
.mod    cp NOTE_COUNT
        jr c,.nok
        sub NOTE_COUNT
        jr .mod
.nok    inc a
        ld (hl),a
        inc l
        ld a,(TF_Pat)               ; сэмпл = паттерн+1 (видно, чей паттерн)
        inc a
        ld (hl),a
        inc l
        ld a,c                      ; огибающая 1..15
        and #0E
        inc a
        ld (hl),a
        inc l
        ld a,c                      ; орнамент 1..16
        add a,b
        and #0F
        inc a
        ld (hl),a
        inc l
        ld a,c                      ; громкость 8..15
        and 7
        add a,8
        ld (hl),a
        inc l
        ld (hl),0                   ; резерв
        inc l
        ld a,b                      ; команда 1: канал*16 + паттерн, роу
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(TF_Pat)
        add a,e
        ld (hl),a
        inc l
        ld (hl),c
        inc l
        ld (hl),c                   ; команда 2: роу, #A0 + канал
        inc l
        ld a,b
        add a,#A0
        ld (hl),a
        inc l
        ld a,l                      ; резерв канала
        add a,CH_SIZE-CH_CMD-CH_CMDS*CMD_SIZE
        ld l,a
        pop bc
        djnz .ch
        pop bc
        dec b
        jp nz,.chip
        inc h
        inc c
        ld a,c
        cp PAT_ROWS_MAX
        jp c,.row
        ret

; =========================================================================
; Простой вывод (рамки, ордер)
; =========================================================================
; HL - строка, конец 0. C - цвет. На выходе HL - на 0
PutStr
.l      ld a,(hl)
        or a
        ret z
        call PutCh
        inc hl
        jr .l

PutHex2
        push af
        rrca
        rrca
        rrca
        rrca
        and #0F
        call HexDigit
        call PutCh
        pop af
        and #0F
        call HexDigit
        jp PutCh

HexDigit
        cp 10
        jr c,.d
        add a,7
.d      add a,'0'
        ret

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

; Символ A цветом C в DE (D - строка, E - колонка), цвет на +128. E++
PutCh
        ld (de),a
        set 7,e
        ld a,c
        ld (de),a
        res 7,e
        inc e
        ret

; HL - поле. Z - оно в фокусе. Портит A, HL
Is_Focus
        push de
        ld de,(SV_FOCUS)
        or a
        sbc hl,de
        pop de
        ret

; A - индекс, HL - массив байт -> A = массив[индекс]
Arr_Get
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
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
Note_T  db '.'                      ; 0 "...", 1..96 "C-0".."B-7", 97 "OFF", дальше "???"
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
        db '0'+O
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

HexD_T  db '.'                      ; 2 hex, 0 = ".."
        DUP 255,N
        db '0'+((N+1)>>4)+((((N+1)>>4)+6)>>4)*7
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

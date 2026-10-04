; =========================================================================
; ПРОСМОТР ПАТТЕРНА - тулза (окно 1, #4000)
;
; Виды: компакт / нормал / фулл, адаптив (канал под курсором на уровень шире).
; 1 или 2 чипа. Если не влезает - сначала без пробела перед │, иначе
; горизонтальный скролл по полям и скроллбар в нижней рамке.
;
; Скорость:
;  - при смене вида (Relayout) считается раскладка и ГЕНЕРИРУЕТСЯ код строки:
;    для каждого видимого поля копируется шаблон (T_*) с подставленными
;    смещением в паттерне и колонкой экрана. Вывод строки - call Row_Code,
;    прямой код без таблиц раскладки и переходов;
;  - поля - через таблицы-плоскости на границе 256 (значение в L, плоскость в H,
;    следующий символ - inc h, последняя плоскость - атрибут);
;  - статика (рамки, пробелы, атрибуты) - строка-шаблон в невидимой строке 63
;    текстовой страницы, разливается DMA. Каждый кадр пишутся только данные.
;
; Тест: 1/2/3 вид, 4 адаптив, 5 1/2 чипа, Q/A строка, O/P канал, K/L скролл,
; W по кругу, Space проигрывание, T полоса времени (фон на время отрисовки),
; колесо - строка, мышь - перетаскивание скроллбара.
; =========================================================================
    MODULE patview

PAT_PAGE        equ PAGE_POOL       ; временно: первая страница пула
PAT_SLOT        equ 0               ; слот паттерна в полосе
PAT_BASE_H      equ #80             ; страница паттернов - в окне 2
SCR_BASE_H      equ #C0             ; экран - в окне 3
VIEW_LINE       equ 7               ; строка экрана с заголовком (верхняя рамка)
VIEW_ROWS       equ 27              ; видимых строк паттерна (экран 8..34)
VIEW_CENTER     equ VIEW_ROWS/2     ; текущая строка - по центру
EDIT_LINE       equ VIEW_LINE+1+VIEW_CENTER
BOTTOM_LINE     equ VIEW_LINE+VIEW_ROWS+1
TEMPLATE_LINE   equ 63              ; невидимая строка текстовой страницы - шаблон

ORD_COL         equ 0
ORD_W           equ 8               ; "│r►05◄N│"
ROWCOL_W        equ 6               ; "│ 00 │" - номер строки, не скроллится
FIT_W           equ SCR_COLS-(ORD_W+1)-ROWCOL_W     ; место под каналы, когда всё влезает

ARROW_R         equ #10             ; ►
ARROW_L         equ #11             ; ◄
BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_UP          equ #C1             ; ┴
BOX_DOWN        equ #C2             ; ┬
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘
BOX_THUMB       equ #CD             ; ═ ползунок скроллбара

MODE_COMPACT    equ 0
MODE_NORMAL     equ 1
MODE_FULL       equ 2

TEST_ORD_LAST   equ 3

    PLUGIN_HEADER PLG_TOOL,"   ","Pattern view"

PluginMain
        ld hl,(Palette_Data)        ; цвет фона - для полосы времени (окно 2 ещё стартовое)
        ld (Band_Bg),hl
        SETPAGE2 PAT_PAGE
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        call Test_Fill
        call Build_Attr_Tables
        ld a,1
        ld (Need_Layout),a

Main_Loop
        halt
        call Timing_On
        call Handle_Keys
        call Handle_Mouse
        call Play_Step
        ld a,(Need_Layout)
        or a
        call nz,Relayout
        call Draw_Rows
        call Draw_Order
        call Highlight_Edit_Row
        call Timing_Off
        jr Main_Loop

; --- состояние вида
View_Mode       db MODE_COMPACT
View_Chips      db 2
View_Adapt      db 1
View_Wrap       db 0                ; 0 - над/под паттерном пусто, 1 - по кругу
Cur_Chan        db 0                ; канал под курсором 0..5
Cursor_Moved    db 0
HScroll         db 0                ; первое видимое поле (при скролле)
Cur_Row         db 0
Cur_Pos         db 0
Loop_Pos        db 0
Test_Order      db 0,0,0,0
Playing         db 0
Play_Tick       db 0
Timing          db 1
Need_Layout     db 1

; =========================================================================
; ТЕСТОВЫЙ ПАТТЕРН: 2 чипа, ноты, инструменты, команды, огибающая, шум
; =========================================================================
Test_Fill
        ld h,PAT_BASE_H             ; очистка: 64 полосы по PAT_WIDTH байт
        ld b,PAT_ROWS_MAX
.clr    ld l,PAT_SLOT
        ld c,PAT_WIDTH
        xor a
.clr1   ld (hl),a
        inc l
        dec c
        jr nz,.clr1
        inc h
        djnz .clr

        ld h,PAT_BASE_H
        ld c,0                      ; номер строки
.row    ld a,c                      ; A: каждые 4 строки C-4, C#4, ...
        and 3
        jr nz,.no_a
        ld a,c
        rrca
        rrca
        and #0F
        cp 12
        jr c,$+4
        sub 12
        add a,NOTE_FIRST+12*4
        ld l,PAT_SLOT+CHIP_CH_A+CH_NOTE
        ld (hl),a
        inc l
        ld (hl),1                   ; сэмпл 1
        ld l,PAT_SLOT+CHIP_CH_A+CH_VOLUME
        ld (hl),15
.no_a   ld a,c                      ; A: команда 1 каждые 8 строк со сдвигом 4
        and 7
        cp 4
        jr nz,.no_ac
        ld l,PAT_SLOT+CHIP_CH_A+CH_CMD
        ld (hl),1
        inc l
        ld (hl),#10
.no_ac  ld a,c                      ; B: G-3 каждые 8 со сдвигом 2
        and 7
        cp 2
        jr nz,.no_b
        ld l,PAT_SLOT+CHIP_CH_B+CH_NOTE
        ld (hl),NOTE_FIRST+12*3+7
        inc l
        ld (hl),2
        ld l,PAT_SLOT+CHIP_CH_B+CH_ORNAMENT
        ld (hl),3
.no_b   ld a,c                      ; B: команды 1 и 2 каждые 16 со сдвигом 6
        and 15
        cp 6
        jr nz,.no_bc
        ld l,PAT_SLOT+CHIP_CH_B+CH_CMD
        ld (hl),3
        inc l
        ld (hl),#02
        inc l
        ld (hl),#01
        inc l
        ld (hl),5
        inc l
        ld (hl),#FF
.no_bc  ld a,c                      ; C: C-2 каждые 16, команда 3 каждые 32
        and 15
        jr nz,.no_c
        ld l,PAT_SLOT+CHIP_CH_C+CH_NOTE
        ld (hl),NOTE_FIRST+12*2
        inc l
        ld (hl),10
        inc l
        ld (hl),8
        ld l,PAT_SLOT+CHIP_CH_C+CH_VOLUME
        ld (hl),12
        ld a,c
        and 31
        jr nz,.no_c
        ld l,PAT_SLOT+CHIP_CH_C+CH_CMD+6
        ld (hl),10
        inc l
        ld (hl),#34
        inc l
        ld (hl),#12
.no_c   ld a,c                      ; D (чип 2): A-3 каждые 4 со сдвигом 2
        and 3
        cp 2
        jr nz,.no_d
        ld l,PAT_SLOT+CHIP_SIZE+CHIP_CH_A+CH_NOTE
        ld (hl),NOTE_FIRST+12*3+9
        inc l
        ld (hl),4
        ld l,PAT_SLOT+CHIP_SIZE+CHIP_CH_A+CH_VOLUME
        ld (hl),10
        ld l,PAT_SLOT+CHIP_SIZE+CHIP_CH_A+CH_CMD
        ld (hl),7
        inc l
        ld (hl),#01
.no_d   ld a,c                      ; E: E-5 каждые 8
        and 7
        jr nz,.no_e
        ld l,PAT_SLOT+CHIP_SIZE+CHIP_CH_B+CH_NOTE
        ld (hl),NOTE_FIRST+12*5+4
        inc l
        ld (hl),5
        ld l,PAT_SLOT+CHIP_SIZE+CHIP_CH_B+CH_ORNAMENT
        ld (hl),2
.no_e   inc h
        inc c
        ld a,c
        cp PAT_ROWS_MAX
        jp c,.row

        ld hl,(PAT_BASE_H+34)*256+PAT_SLOT+CHIP_CH_A+CH_NOTE
        ld (hl),NOTE_OFF
        ld hl,PAT_BASE_H*256+PAT_SLOT+CHIP_ENVPER
        ld (hl),#2D                 ; огибающая #012D
        inc l
        ld (hl),#01
        ld l,PAT_SLOT+CHIP_ENVCMD   ; команда огибающей 2 #0080
        ld (hl),2
        inc l
        ld (hl),#80
        ld l,PAT_SLOT+CHIP_NOISE
        ld (hl),#0A
        ld hl,(PAT_BASE_H+8)*256+PAT_SLOT+CHIP_SIZE+CHIP_ENVPER
        ld (hl),#40                 ; чип 2: огибающая #0040 в строке 8
        ld hl,(PAT_BASE_H+16)*256+PAT_SLOT+CHIP_SIZE+CHIP_NOISE
        ld (hl),#1F                 ; чип 2: шум #1F в строке 16
        ret

; =========================================================================
; РАСКЛАДКА - только при смене вида
; =========================================================================
; Типы полей
TY_ROWNUM       equ 0
TY_NOTE         equ 1
TY_SAMPLE       equ 2
TY_ENV          equ 3
TY_ORN          equ 4
TY_VOL          equ 5
TY_NOISE        equ 6
TY_ENVPER       equ 7
TY_CMD          equ 8
TY_BAR          equ #80

Type_W          db 2,3,1,1,1,1,2,4,5    ; ширина поля на экране по типу

; Поля групп по уровню: тип, смещение в группе, пробел перед; конец #FF
GF_Chip0        db TY_ENVPER,CHIP_ENVPER,0, #FF
GF_Chip1        db TY_ENVPER,CHIP_ENVPER,0, TY_NOISE,CHIP_NOISE,1, #FF
GF_Chip2        db TY_ENVPER,CHIP_ENVPER,0, TY_NOISE,CHIP_NOISE,1, TY_CMD,CHIP_ENVCMD,1, #FF
GF_Ch0          db TY_NOTE,CH_NOTE,0, TY_SAMPLE,CH_SAMPLE,1, TY_ENV,CH_ENVSHAPE,0
                db TY_ORN,CH_ORNAMENT,0, TY_VOL,CH_VOLUME,0, #FF
GF_Ch1          db TY_NOTE,CH_NOTE,0, TY_SAMPLE,CH_SAMPLE,1, TY_ENV,CH_ENVSHAPE,0
                db TY_ORN,CH_ORNAMENT,0, TY_VOL,CH_VOLUME,0, TY_CMD,CH_CMD,1, #FF
GF_Ch2          db TY_NOTE,CH_NOTE,0, TY_SAMPLE,CH_SAMPLE,1, TY_ENV,CH_ENVSHAPE,0
                db TY_ORN,CH_ORNAMENT,0, TY_VOL,CH_VOLUME,0, TY_CMD,CH_CMD,1
                db TY_CMD,CH_CMD+CMD_SIZE,1, TY_CMD,CH_CMD+2*CMD_SIZE,1, #FF
GF_Chip_Tab     dw GF_Chip0,GF_Chip1,GF_Chip2
GF_Ch_Tab       dw GF_Ch0,GF_Ch1,GF_Ch2

; Раскладка: элементы по 4 байта - тип, x (в содержимом), ширина, смещение в паттерне
LAY_MAX         equ 80
Lay             ds LAY_MAX*4
Lay_N           db 0
Lay_X           db 0
Lay_W           db 0                ; ширина содержимого
FieldX          ds 64               ; x каждого поля - для скролла по полям
Fld_N           db 0
GRP_MAX         equ 8
Grp_X           ds GRP_MAX          ; x ведущего пробела группы
Grp_End         ds GRP_MAX          ; x │ в конце группы
Grp_First       ds GRP_MAX          ; первое поле группы
Grp_Kind        ds GRP_MAX          ; 0 - чип, 1 - канал
Grp_Num         ds GRP_MAX          ; номер чипа / канала
Grp_N           db 0
Trail_Pad       db 1                ; пробел перед │ в конце группы
EG_Base         db 0
EG_Kind         db 0
EG_Num          db 0
BL_Chip         db 0

; Размещение
Scroll_Mode     db 0
Blk_X0          db 0                ; левая │ колонки номера строки
Win_X           db 0                ; первая колонка содержимого на экране
Blk_End         db 0                ; правая │ блока
WinC            db 0                ; колонок под содержимое
Off             db 0                ; x содержимого, с которого начинается окно
Max_Scroll      db 0
Thumb_X         db 0
Thumb_W         db 0
Scroll_Map      ds 80               ; колонка в окне -> HScroll (для мыши)
Map_I           db 0
Map_Ptr         dw 0

Relayout
        xor a
        ld (Need_Layout),a
        ld a,1                      ; с пробелами
        ld (Trail_Pad),a
        call Build_Layout
        ld a,(Lay_W)
        cp FIT_W+1
        jr c,.fit
        xor a                       ; без пробела перед │
        ld (Trail_Pad),a
        call Build_Layout
        ld a,(Lay_W)
        cp FIT_W+1
        jr c,.fit
        ld a,1                      ; не влезает - с пробелами и скроллом
        ld (Trail_Pad),a
        call Build_Layout
        call Place_Scroll
        jr .placed
.fit    call Place_Fit
.placed call Gen_Code
        call Build_Template
        call Fill_Rows
        call Draw_Top
        call Draw_Titles
        call Draw_Bottom
        jp Draw_Scrollbar

;-------- Раскладка всех групп: чип, 3 канала, [чип, 3 канала]
Build_Layout
        xor a
        ld (Lay_N),a
        ld (Fld_N),a
        ld (Grp_N),a
        ld (Lay_X),a
        ld ix,Lay
        ld a,(View_Chips)
        ld b,a
        xor a
.chip   push bc
        ld (BL_Chip),a
        rrca                        ; чип*64
        rrca
        ld (EG_Base),a
        xor a
        ld (EG_Kind),a
        ld a,(BL_Chip)
        ld (EG_Num),a
        ld a,(View_Mode)
        ld hl,GF_Chip_Tab
        call Get_List
        call Emit_Group

        ld c,0                      ; канал в чипе
.ch     push bc
        ld a,(BL_Chip)
        ld b,a
        add a,a
        add a,b
        add a,c                     ; номер канала 0..5
        ld (EG_Num),a
        ld b,a
        ld a,(View_Mode)            ; уровень, с адаптивом - на 1 шире у курсора
        ld e,a
        ld a,(View_Adapt)
        or a
        jr z,.lv
        ld a,(Cur_Chan)
        cp b
        jr nz,.lv
        ld a,e
        cp MODE_FULL
        jr nc,.lv
        inc e
.lv     ld a,e
        ld hl,GF_Ch_Tab
        call Get_List
        ld a,(BL_Chip)              ; смещение канала: чип*64 + CHIP_CH_A + канал*16
        rrca
        rrca
        ld b,a
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,CHIP_CH_A
        add a,b
        ld (EG_Base),a
        ld a,1
        ld (EG_Kind),a
        call Emit_Group
        pop bc
        inc c
        ld a,c
        cp 3
        jr c,.ch

        pop bc
        ld a,(BL_Chip)
        inc a
        djnz .chip
        ld a,(Lay_X)
        ld (Lay_W),a
        ret

; HL - таблица dw, A - индекс -> HL = элемент
Get_List
        add a,a
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
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

; A - индекс, HL - массив, C - значение -> массив[индекс] = C
Arr_Set
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),c
        ret

;-------- Группа: ведущий пробел, поля, [пробел], │. HL - поля группы
Emit_Group
        push hl
        ld a,(Lay_X)
        ld c,a
        ld a,(Grp_N)
        ld hl,Grp_X
        call Arr_Set
        ld a,(Fld_N)
        ld c,a
        ld a,(Grp_N)
        ld hl,Grp_First
        call Arr_Set
        ld a,(EG_Kind)
        ld c,a
        ld a,(Grp_N)
        ld hl,Grp_Kind
        call Arr_Set
        ld a,(EG_Num)
        ld c,a
        ld a,(Grp_N)
        ld hl,Grp_Num
        call Arr_Set
        pop hl

        ld a,(Lay_X)                ; ведущий пробел
        inc a
        ld (Lay_X),a
.f      ld a,(hl)
        cp #FF
        jr z,.end
        ld (ix+0),a                 ; тип
        ld e,a
        inc hl
        ld a,(EG_Base)              ; смещение в паттерне
        add a,(hl)
        add a,PAT_SLOT
        ld (ix+3),a
        inc hl
        ld a,(hl)                   ; пробел перед полем?
        inc hl
        or a
        jr z,.ns
        ld a,(Lay_X)
        inc a
        ld (Lay_X),a
.ns     ld a,(Lay_X)
        ld (ix+1),a
        push hl
        ld c,a                      ; FieldX[Fld_N] = x
        ld a,(Fld_N)
        ld hl,FieldX
        call Arr_Set
        ld a,(Fld_N)
        inc a
        ld (Fld_N),a
        ld a,e                      ; ширина
        ld hl,Type_W
        call Arr_Get
        pop hl
        ld (ix+2),a
        ld c,a
        ld a,(Lay_X)
        add a,c
        ld (Lay_X),a
        ld bc,4
        add ix,bc
        ld a,(Lay_N)
        inc a
        ld (Lay_N),a
        jr .f

.end    ld a,(Trail_Pad)            ; [пробел] и │
        ld c,a
        ld a,(Lay_X)
        add a,c
        ld (ix+0),TY_BAR
        ld (ix+1),a
        ld (ix+2),1
        ld (ix+3),0
        ld c,a
        inc a
        ld (Lay_X),a
        ld de,4
        add ix,de
        ld a,(Lay_N)
        inc a
        ld (Lay_N),a
        ld a,(Grp_N)                ; Grp_End = x │
        ld hl,Grp_End
        call Arr_Set
        ld a,(Grp_N)
        inc a
        ld (Grp_N),a
        ret

;-------- Всё влезает: по центру, без скролла
Place_Fit
        xor a
        ld (Scroll_Mode),a
        ld (HScroll),a
        ld (Off),a
        ld (Cursor_Moved),a
        ld a,(Lay_W)
        ld (WinC),a
        ld b,a
        ld a,FIT_W
        sub b
        srl a
        add a,ORD_W+1
        ld (Blk_X0),a
        add a,ROWCOL_W
        ld (Win_X),a
        add a,b
        dec a
        ld (Blk_End),a
        ret

;-------- Не влезает: окно до правого края, скролл по полям
Place_Scroll
        ld a,1
        ld (Scroll_Mode),a
        ld a,ORD_W+1
        ld (Blk_X0),a
        add a,ROWCOL_W
        ld (Win_X),a
        ld a,SCR_COLS-1
        ld (Blk_End),a
        ld a,SCR_COLS-1-(ORD_W+1+ROWCOL_W)
        ld (WinC),a

        ld hl,FieldX                ; Max_Scroll: первое поле, с которого остаток влезает
        ld c,0
.m      ld a,(Lay_W)
        sub (hl)
        inc a                       ; W - (x-1)
        ld b,a
        ld a,(WinC)
        cp b
        jr nc,.mf
        inc hl
        inc c
        ld a,(Fld_N)
        cp c
        jr nz,.m
        dec c
.mf     ld a,c
        ld (Max_Scroll),a

        ld a,(Cursor_Moved)         ; курсор сменил канал - его группа должна быть видна
        or a
        jr z,.clamp
        xor a
        ld (Cursor_Moved),a
        call Cursor_Group           ; A - группа
        ld (PS_G),a
        call Calc_Off
        ld b,a                      ; B - Off
        ld a,(PS_G)
        ld hl,Grp_X
        call Arr_Get
        cp b
        jr c,.show                  ; начало группы левее окна
        ld a,(PS_G)
        ld hl,Grp_End
        call Arr_Get
        sub b
        ld hl,WinC
        cp (hl)
        jr c,.clamp                 ; конец группы влезает
.show   ld a,(PS_G)
        ld hl,Grp_First
        call Arr_Get
        ld (HScroll),a
.clamp  ld a,(Max_Scroll)
        ld c,a
        ld a,(HScroll)
        cp c
        jr c,$+3
        ld a,c                      ; HScroll > Max - прижимаем
        ld (HScroll),a
        call Calc_Off
        ld (Off),a

        ld a,(WinC)                 ; ползунок: ширина = WinC*WinC/W, не меньше 2
        ld e,a
        call Mul8
        ld a,(Lay_W)
        ld c,a
        call Div16_8
        ld a,l
        cp 2
        jr nc,$+4
        ld a,2
        ld (Thumb_W),a
        ld a,(Max_Scroll)           ; позиция = HScroll*(WinC-Thumb_W)/Max
        or a
        jr z,.tx
        ld c,a
        ld a,(Thumb_W)
        ld b,a
        ld a,(WinC)
        sub b
        ld e,a
        ld a,(HScroll)
        push bc
        call Mul8
        pop bc
        call Div16_8
        ld a,l
.tx     ld (Thumb_X),a

        ld hl,Scroll_Map            ; колонка в окне -> HScroll: (i*Max + (WinC-1)/2)/(WinC-1)
        ld (Map_Ptr),hl
        xor a
        ld (Map_I),a
.mp     ld a,(Max_Scroll)
        ld e,a
        ld a,(Map_I)
        call Mul8
        ld a,(WinC)
        dec a
        ld c,a
        srl a
        ld e,a
        ld d,0
        add hl,de
        call Div16_8
        ld a,l
        ld hl,(Map_Ptr)
        ld (hl),a
        inc hl
        ld (Map_Ptr),hl
        ld a,(Map_I)
        inc a
        ld (Map_I),a
        ld hl,WinC
        cp (hl)
        jr c,.mp
        ret

PS_G            db 0

; A = FieldX[HScroll]-1
Calc_Off
        ld a,(HScroll)
        ld hl,FieldX
        call Arr_Get
        dec a
        ret

; A = группа канала под курсором: чип*4 + 1 + канал в чипе
Cursor_Group
        ld a,(Cur_Chan)
        cp 3
        jr c,.c1
        add a,4-3+1
        ret
.c1     inc a
        ret

; HL = A*E. Портит B,D
Mul8
        ld hl,0
        ld d,h
        ld b,8
.l      add hl,hl
        add a,a
        jr nc,.n
        add hl,de
.n      djnz .l
        ret

; HL = HL/C, A - остаток. Портит B
Div16_8
        xor a
        ld b,16
.l      add hl,hl
        rla
        cp c
        jr c,.n
        sub c
        inc l
.n      djnz .l
        ret

;-------- Генерация кода строки: номер строки + шаблон каждого видимого поля
Gen_Code
        ld de,Row_Code
        ld hl,T_ROWNUM
        ld bc,T_ROWNUM_E-T_ROWNUM
        push de
        ldir
        pop ix
        ld a,(Blk_X0)
        add a,2
        ld (ix+3),a

        ld iy,Lay
        ld a,(Lay_N)
        ld b,a
.e      push bc
        ld a,(iy+0)
        cp TY_BAR
        jr z,.next
        ld (GC_T),a
        ld a,(Off)                  ; видно ли поле: x >= Off и x-Off+w <= WinC
        ld c,a
        ld a,(iy+1)
        sub c
        jr c,.next
        ld (GC_Rel),a
        add a,(iy+2)
        ld c,a
        ld a,(WinC)
        cp c
        jr c,.next

        ld a,(GC_T)                 ; шаблон: адрес и длина
        ld c,a
        add a,a
        add a,c
        ld hl,TT
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        push bc
        pop hl
        ld c,a
        ld b,0
        push de
        ldir
        pop ix
        ld a,(iy+3)                 ; подставляем смещение в паттерне
        ld (ix+1),a
        ld a,(Win_X)                ; и колонку экрана
        ld c,a
        ld a,(GC_Rel)
        add a,c
        ld (ix+3),a
.next   ld bc,4
        add iy,bc
        pop bc
        djnz .e
        ld a,#C9                    ; ret
        ld (de),a
        ret

GC_T            db 0
GC_Rel          db 0

; Шаблоны полей по типу: адрес, длина
TT      dw T_ROWNUM
        db T_ROWNUM_E-T_ROWNUM
        dw T_NOTE
        db T_NOTE_E-T_NOTE
        dw T_SAMPLE
        db T_SAMPLE_E-T_SAMPLE
        dw T_ENV
        db T_ENV_E-T_ENV
        dw T_ORN
        db T_ORN_E-T_ORN
        dw T_VOL
        db T_VOL_E-T_VOL
        dw T_NOISE
        db T_NOISE_E-T_NOISE
        dw T_ENVPER
        db T_ENVPER_E-T_ENVPER
        dw T_CMD
        db T_CMD_E-T_CMD

;-------- Строка-шаблон (статика) в невидимой строке TEMPLATE_LINE
Build_Template
        ld h,SCR_BASE_H+TEMPLATE_LINE
        ld l,0
        ld b,SCR_COLS
        ld a,' '
.c      ld (hl),a
        inc l
        djnz .c
        ld l,SCR_ATTR
        ld b,SCR_COLS
        ld a,(THEME_ATTR+CLR_BG)
.a      ld (hl),a
        inc l
        djnz .a

        ld d,h
        ld e,ORD_COL                ; рамки ордер-листа
        call PutBar
        ld e,ORD_W-1
        call PutBar
        ld a,(Blk_X0)               ; рамки колонки номера строки
        ld e,a
        call PutBar
        ld a,(Win_X)
        dec a
        ld e,a
        call PutBar

        ld iy,Lay                   ; видимые │ групп
        ld a,(Lay_N)
        ld b,a
.e      ld a,(iy+0)
        cp TY_BAR
        jr nz,.n
        ld a,(Off)
        ld c,a
        ld a,(iy+1)
        sub c
        jr c,.n
        ld c,a
        ld a,(WinC)
        dec a
        cp c
        jr c,.n                     ; правее окна
        ld a,(Win_X)
        add a,c
        ld e,a
        call PutBar
.n      ld de,4
        add iy,de
        ld d,SCR_BASE_H+TEMPLATE_LINE
        djnz .e

        ld a,(Scroll_Mode)          ; при скролле - правая рамка у края экрана
        or a
        ret z
        ld a,(Blk_End)
        ld e,a
        jp PutBar

;-------- Шаблон -> все строки паттерна: DMA в первую, потом с перекрытием N -> N+1
Fill_Rows
        ld a,TEMPLATE_LINE
        ld e,VIEW_LINE+1
        ld c,0
        ld b,DMA_RAM
        call Dma_Lines
        ld a,VIEW_LINE+1
        ld e,VIEW_LINE+2
        ld c,VIEW_ROWS-2
        ld b,DMA_RAM|DMA_SALGN|DMA_DALGN
        jp Dma_Lines

;-------- Строка экрана D - из шаблона (строка вне паттерна)
Blank_Line
        ld a,d
        sub SCR_BASE_H
        ld e,a
        ld a,TEMPLATE_LINE
        ld c,0
        ld b,DMA_RAM

;-------- DMA строк текстовой страницы целиком (256 байт)
; A - строка-источник, E - строка-приёмник, C - блоков-1, B - DMACtrl
Dma_Lines
        ld (Dma_T+3),a
        ld a,e
        ld (Dma_T+9),a
        ld a,c
        ld (Dma_T+15),a
        ld a,b
        ld (Dma_T+17),a
        ld a,(SV_DRAW_PAGE)
        ld (Dma_T+5),a
        ld (Dma_T+11),a
        ld hl,Dma_T
        call set_ports
        jp dma_wait

Dma_T   db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,0
        db high DMADADDRL,0, high DMADADDRH,0, high DMADADDRX,0
        db high DMALEN,127, high DMANUM,0, high DMACTR,0, #FF

; =========================================================================
; ШАБЛОНЫ ПОЛЕЙ - копируются в Row_Code. Начало у всех одно:
;   +0 ld c,смещение в паттерне   (подставляется в +1)
;   +2 ld e,колонка экрана        (подставляется в +3)
; Вход: B - строка паттерна (#80+строка), D - строка экрана. Только jr внутри.
; =========================================================================
T_ROWNUM                            ; номер строки: из B, цвет - каждая 4-я
        ld c,0
        ld e,0
        ld a,b
        sub PAT_BASE_H
        ld l,a
        ld h,high Hex_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        ld h,high Row_A
        ld a,(hl)
        set 7,e
        ld (de),a
        dec e
        ld (de),a
T_ROWNUM_E

T_NOTE                              ; нота: 3 плоскости символов + атрибут
        ld c,0
        ld e,0
        ld a,(bc)
        ld l,a
        ld h,high Note_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        inc h
        ld a,(hl)
        set 7,e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
T_NOTE_E

    MACRO TPL_ONE tab,attr          ; один знак + атрибут из плоскости tab+attr
        ld c,0
        ld e,0
        ld a,(bc)
        ld l,a
        ld h,high tab
        ld a,(hl)
        ld (de),a
        ld h,(high tab)+attr
        ld a,(hl)
        set 7,e
        ld (de),a
    ENDM

T_SAMPLE
        TPL_ONE Sym_T,1
T_SAMPLE_E
T_ENV
        TPL_ONE Hx1_T,1
T_ENV_E
T_ORN
        TPL_ONE Sym_T,2
T_ORN_E
T_VOL
        TPL_ONE Hx1_T,2
T_VOL_E

T_NOISE                             ; 2 hex, 0 = "--"
        ld c,0
        ld e,0
        ld a,(bc)
        ld l,a
        ld h,high HexD_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        inc h
        ld a,(hl)
        set 7,e
        ld (de),a
        dec e
        ld (de),a
T_NOISE_E

T_ENVPER                            ; период огибающей, 16 бит; 0 = "----"
        ld c,0
        ld e,0
        ld a,(bc)                   ; младший
        inc c
        ld h,a
        ld a,(bc)                   ; старший
        ld l,a
        or h
        jr z,.empty
        ld a,h
        push af
        ld h,high Hex_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        inc e
        pop af
        ld l,a
        ld h,high Hex_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        ld a,(THEME_ATTR+CLR_ENVPER)
        jr .attr
.empty  ld a,'-'
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        ld a,(THEME_ATTR+CLR_EMPTY)
.attr   set 7,e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
T_ENVPER_E

T_CMD                               ; команда: код (символ 1..W) + параметр 4 hex; код 0 = "-----"
        ld c,0
        ld e,0
        ld a,(bc)
        or a
        jr z,.empty
        ld l,a
        ld h,high Sym_T
        ld a,(hl)
        ld (de),a
        inc e
        inc c
        inc c
        ld a,(bc)                   ; параметр, старший
        ld l,a
        ld h,high Hex_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        inc e
        dec c
        ld a,(bc)                   ; параметр, младший
        ld l,a
        ld h,high Hex_T
        ld a,(hl)
        ld (de),a
        inc e
        inc h
        ld a,(hl)
        ld (de),a
        ld a,(THEME_ATTR+CLR_CMD)
        jr .attr
.empty  ld a,'-'
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        ld a,(THEME_ATTR+CLR_EMPTY)
.attr   set 7,e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
T_CMD_E

; =========================================================================
; КАЖДЫЙ КАДР
; =========================================================================
Draw_Rows
        ld a,(Cur_Row)
        sub VIEW_CENTER
        ld (Row_Iter),a
        ld d,SCR_BASE_H+VIEW_LINE+1
        ld a,VIEW_ROWS
.l      push af
        push de
        ld a,(Row_Iter)
        cp PAT_ROWS_MAX
        jr c,.ok
        ld hl,View_Wrap             ; вне паттерна: по кругу или пусто
        bit 0,(hl)
        jr z,.blank
        and PAT_ROWS_MAX-1
.ok     add a,PAT_BASE_H
        ld b,a
        call Row_Code
        jr .next
.blank  call Blank_Line
.next   pop de
        ld hl,Row_Iter
        inc (hl)
        inc d
        pop af
        dec a
        jr nz,.l
        ret

Row_Iter        db 0

;-------- Ордер-лист слева. Все клетки пишутся каждый кадр (список едет)
Draw_Order
        ld d,SCR_BASE_H+VIEW_LINE+1
        ld a,(Cur_Pos)
        sub VIEW_CENTER
        ld b,a                      ; B - позиция
        ld a,VIEW_ROWS
.l      push af
        ld e,ORD_COL
        call PutBar
        ld a,b
        cp TEST_ORD_LAST+1
        jr c,.item
        ld a,(THEME_ATTR+CLR_BG)    ; за концом списка - пусто
        ld c,a
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        ld a,' '
        call PutCh
        jr .buttons
.item   ld a,(THEME_ATTR+CLR_LOOP)
        ld c,a
        ld a,(Loop_Pos)
        cp b
        ld a,' '
        jr nz,$+4
        ld a,'r'
        call PutCh
        ld a,(THEME_ATTR+CLR_ORD_CUR)
        ld c,a
        ld a,(Cur_Pos)
        cp b
        ld a,' '
        jr nz,$+4
        ld a,ARROW_R
        call PutCh
        ld a,(THEME_ATTR+CLR_PATNUM)
        ld c,a
        ld a,b
        ld hl,Test_Order
        call Arr_Get
        call PutHex2
        ld a,(THEME_ATTR+CLR_ORD_CUR)
        ld c,a
        ld a,(Cur_Pos)
        cp b
        ld a,' '
        jr nz,$+4
        ld a,ARROW_L
        call PutCh
.buttons
        ld e,ORD_COL+6
        ld a,(Cur_Pos)              ; кнопки у текущей и двух под ней
        neg
        add a,b
        cp 3
        jr c,.btn
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,' '
        jr .put
.btn    ld hl,Order_Buttons
        call Arr_Get
        push af
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        pop af
.put    call PutCh
        call PutBar
        inc d
        inc b
        pop af
        dec a
        jp nz,.l
        ret

Order_Buttons   db "N+-"

;-------- Подсветка строки редактирования: фон из CLR_EDIT_ROW, ink свой
Highlight_Edit_Row
        ld a,(THEME_ATTR+CLR_EDIT_ROW)
        and #F0
        ld c,a
        ld a,(Blk_X0)
        ld b,a
        ld a,(Blk_End)
        sub b
        inc a
        ld e,a                      ; сколько колонок
        ld a,b
        add a,SCR_ATTR
        ld l,a
        ld h,SCR_BASE_H+EDIT_LINE
        ld b,e
.l      ld a,(hl)
        and #0F
        or c
        ld (hl),a
        inc l
        djnz .l
        ret

; =========================================================================
; РАМКИ, ЗАГОЛОВКИ, СКРОЛЛБАР - при смене вида
; =========================================================================
Draw_Top                            ; ┌──┬──┐ по строке заголовка
        ld a,BOX_TL
        ld (HL_CornerL),a
        ld a,BOX_TR
        ld (HL_CornerR),a
        ld a,BOX_DOWN
        ld (HL_Junction),a
        ld d,SCR_BASE_H+VIEW_LINE
        ld h,SCR_BASE_H+VIEW_LINE+1
        jr Draw_HLine

Draw_Bottom                         ; └──┴──┘ под последней строкой
        ld a,BOX_BL
        ld (HL_CornerL),a
        ld a,BOX_BR
        ld (HL_CornerR),a
        ld a,BOX_UP
        ld (HL_Junction),a
        ld d,SCR_BASE_H+BOTTOM_LINE
        ld h,SCR_BASE_H+TEMPLATE_LINE   ; вертикали - как в шаблоне строки

; D - строка, где рисуем; H - строка, где смотрим вертикали
Draw_HLine
        ld e,0
.l      ld a,e
        cp ORD_W
        jr c,.in
        ld a,(Blk_X0)
        ld c,a
        ld a,e
        cp c
        jr c,.out
        ld a,(Blk_End)
        cp e
        jr c,.out
.in     ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld l,e
        ld a,(hl)
        cp BOX_V
        ld a,BOX_H
        jr nz,.put
        ld a,e                      ; вертикаль: угол или стык
        cp ORD_COL
        jr z,.cl
        cp ORD_W-1
        jr z,.cr
        ld a,(Blk_X0)
        cp e
        jr z,.cl
        ld a,(Blk_End)
        cp e
        jr z,.cr
        ld a,(HL_Junction)
        jr .put
.cl     ld a,(HL_CornerL)
        jr .put
.cr     ld a,(HL_CornerR)
        jr .put
.out    ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,' '
.put    call PutCh
        ld a,e
        cp SCR_COLS
        jr c,.l
        ret

HL_CornerL      db 0
HL_CornerR      db 0
HL_Junction     db 0

;-------- Подписи на верхней линии: Order, Rw, у каждой видимой группы - имя
Draw_Titles
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld d,SCR_BASE_H+VIEW_LINE
        ld e,ORD_COL+1
        ld hl,Txt_Order
        call PutStr
        ld a,(Blk_X0)
        inc a
        ld e,a
        ld hl,Txt_Rw
        call PutStr
        ld b,0
.g      ld a,(Grp_N)
        cp b
        ret z
        push bc
        ld a,b
        ld hl,Grp_X
        call Arr_Get
        ld hl,Off
        sub (hl)
        jr c,.skip                  ; левее окна
        ld e,a
        add a,6
        ld hl,WinC
        cp (hl)
        jr nc,.skip                 ; не влезает справа
        ld a,(Win_X)
        add a,e
        ld e,a
        ld a,b
        ld hl,Grp_Kind
        call Arr_Get
        or a
        ld hl,Txt_Env
        jr z,.put
        ld a,b
        ld hl,Grp_Num
        call Arr_Get
        add a,'A'
        ld (Txt_Ch_L),a
        ld hl,Txt_Ch
.put    ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        call PutStr
.skip   pop bc
        inc b
        jr .g

Txt_Order       db "Order ",0
Txt_Rw          db " Rw ",0
Txt_Env         db " Env ",0
Txt_Ch          db " Ch:"
Txt_Ch_L        db "A ",0

;-------- Скроллбар в нижней рамке: ═ ползунок (только при скролле)
Draw_Scrollbar
        ld a,(Scroll_Mode)
        or a
        ret z
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld d,SCR_BASE_H+BOTTOM_LINE
        ld a,(Win_X)
        ld b,a
        ld a,(Thumb_X)
        add a,b
        ld e,a
        ld a,(Thumb_W)
        ld b,a
.l      ld a,BOX_THUMB
        call PutCh
        djnz .l
        ret

; =========================================================================
; ВВОД
; =========================================================================
; Клавиша: старший байт порта #xxFE, маска, обработчик. Конец - 0
Key_Tab db #F7,%00001
        dw K_Mode0                  ; 1
        db #F7,%00010
        dw K_Mode1                  ; 2
        db #F7,%00100
        dw K_Mode2                  ; 3
        db #F7,%01000
        dw K_Adapt                  ; 4
        db #F7,%10000
        dw K_Chips                  ; 5
        db #FB,%00001
        dw K_RowUp                  ; Q
        db #FD,%00001
        dw K_RowDn                  ; A
        db #DF,%00010
        dw K_ChLeft                 ; O
        db #DF,%00001
        dw K_ChRight                ; P
        db #BF,%00100
        dw K_ScLeft                 ; K
        db #BF,%00010
        dw K_ScRight                ; L
        db #FB,%00010
        dw K_Wrap                   ; W
        db #7F,%00001
        dw K_Play                   ; Space
        db #FB,%10000
        dw K_Timing                 ; T
        db 0
KEYS_N          equ 14
Keys_Prev       ds KEYS_N

Handle_Keys
        ld hl,Key_Tab
        ld ix,Keys_Prev
.k      ld a,(hl)
        or a
        ret z
        inc hl
        in a,(#FE)
        and (hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        jr z,.down
        ld (ix+0),0
        jr .next
.down   ld a,(ix+0)                 ; только на нажатие, не на удержание
        ld (ix+0),1
        or a
        jr nz,.next
        push hl
        push ix
        ex de,hl
        call .jp
        pop ix
        pop hl
.next   inc ix
        jr .k
.jp     jp (hl)

K_Mode0 xor a
        jr Set_Mode
K_Mode1 ld a,MODE_NORMAL
        jr Set_Mode
K_Mode2 ld a,MODE_FULL
Set_Mode
        ld (View_Mode),a
        xor a
        ld (HScroll),a
Dirty   ld a,1
        ld (Need_Layout),a
        ret
K_Adapt ld hl,View_Adapt
        ld a,(hl)
        xor 1
        ld (hl),a
        jr Dirty
K_Chips ld hl,View_Chips
        ld a,(hl)
        xor 3                       ; 1 <-> 2
        ld (hl),a
        cp 2
        jr z,.ok
        ld a,(Cur_Chan)
        cp 3
        jr c,.ok
        ld a,2
        ld (Cur_Chan),a
.ok     xor a
        ld (HScroll),a
        jr Dirty
K_RowUp ld hl,Cur_Row
        dec (hl)
        jr Row_Wrap
K_RowDn ld hl,Cur_Row
        inc (hl)
Row_Wrap
        ld a,(hl)
        and PAT_ROWS_MAX-1
        ld (hl),a
        ret
K_ChLeft
        ld a,(Cur_Chan)
        or a
        ret z
        dec a
Set_Chan
        ld (Cur_Chan),a
        ld a,1
        ld (Cursor_Moved),a
        jr Dirty
K_ChRight
        ld a,(View_Chips)
        ld b,a
        add a,a
        add a,b
        dec a                       ; последний канал
        ld b,a
        ld a,(Cur_Chan)
        cp b
        ret nc
        inc a
        jr Set_Chan
K_ScLeft
        ld a,(HScroll)
        or a
        ret z
        dec a
        ld (HScroll),a
        jr Dirty
K_ScRight
        ld a,(HScroll)
        ld hl,Max_Scroll
        cp (hl)
        ret nc
        inc a
        ld (HScroll),a
        jr Dirty
K_Wrap  ld hl,View_Wrap
        jr Toggle
K_Play  ld hl,Playing
        jr Toggle
K_Timing
        ld hl,Timing
Toggle  ld a,(hl)
        xor 1
        ld (hl),a
        ret

;-------- Мышь: колесо - строка, левая кнопка на нижней рамке - скроллбар
Handle_Mouse
        call Mouse_Get_Wheel
        or a
        jr z,.nowheel
        ld b,a
        ld a,(Cur_Row)
        sub b
        and PAT_ROWS_MAX-1
        ld (Cur_Row),a
.nowheel
        ld a,(Scroll_Mode)
        or a
        ret z
        ld a,(MOUSE_BUT)
        rrca
        ret c                       ; бит 0 = 1 - левая не нажата
        ld hl,(CUR_MY+1)            ; строка = Y/8
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        cp BOTTOM_LINE
        ret nz
        ld hl,(CUR_MX+1)            ; колонка = X/4
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ld hl,Win_X
        sub (hl)
        ret c
        ld hl,WinC
        cp (hl)
        ret nc
        ld hl,Scroll_Map
        call Arr_Get
        ld hl,HScroll
        cp (hl)
        ret z
        ld (hl),a
        jp Dirty

;-------- Имитация проигрывания: строка каждые 3 кадра
Play_Step
        ld a,(Playing)
        or a
        ret z
        ld hl,Play_Tick
        inc (hl)
        ld a,(hl)
        cp 3
        ret c
        ld (hl),0
        ld hl,Cur_Row
        inc (hl)
        jp Row_Wrap

;-------- Полоса времени: фон (палитра PALET_NUM, цвет 0) на время отрисовки
BAND_W          equ PALET_NUM*16    ; слово CRAM
Timing_On
        ld a,(Timing)
        or a
        ret z
        ld hl,Band_On_T
        jp set_ports
Timing_Off
        ld hl,Band_Off_T
        jp set_ports

Band_On_T
        db high DMASADDRL,(Band_Red-#4000)&255, high DMASADDRH,(Band_Red-#4000)>>8
        db high DMASADDRX,PAGE_TOOL_PATVIEW
        db high DMADADDRL,(BAND_W&127)*2, high DMADADDRH,BAND_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
Band_Off_T
        db high DMASADDRL,(Band_Bg-#4000)&255, high DMASADDRH,(Band_Bg-#4000)>>8
        db high DMASADDRX,PAGE_TOOL_PATVIEW
        db high DMADADDRL,(BAND_W&127)*2, high DMADADDRH,BAND_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF

        ALIGN 2
Band_Red        db %00000000, %01100000     ; красный (0RRrrrGG / gggBBbbb)
Band_Bg         dw 0

;-------- Плоскости атрибутов из темы: значение 0 - "пусто", остальное - цвет поля
Build_Attr_Tables
        ld a,(THEME_ATTR+CLR_NOTE)
        ld h,(high Note_T)+3
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_NOISE)
        ld h,(high HexD_T)+2
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_INSTR)
        ld h,(high Sym_T)+1
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_ORNAMENT)
        ld h,(high Sym_T)+2
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_ENVSHAPE)
        ld h,(high Hx1_T)+1
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_VOLUME)
        ld h,(high Hx1_T)+2
        call Fill_Attr_Plane
        ld h,high Row_A             ; номер строки: каждая 4-я выделена
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

Fill_Attr_Plane
        ld l,0
.f      ld (hl),a
        inc l
        jr nz,.f
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld (hl),a
        ret

; =========================================================================
; Простой вывод (статика, ордер-лист)
; =========================================================================
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

; Символ A атрибутом C в DE (D - строка, E - колонка), атрибут на +128. E++
PutCh
        ld (de),a
        set 7,e
        ld a,c
        ld (de),a
        res 7,e
        inc e
        ret

; =========================================================================
; ТАБЛИЦЫ-ПЛОСКОСТИ (каждая 256 байт на границе 256, индекс - само значение)
; hex-цифра d -> символ: '0'+d+((d+6)>>4)*7
; =========================================================================
        ALIGN 256
Note_T  db '-'                      ; 0 "---", 1..96 "C-0".."B-7", 97 "OFF", дальше "???"
        DUP 8
        db "CCDDEFFGGAAB"
        EDUP
        db 'O'
        ds 256-98,'?'
        db '-'
        DUP 8
        db "-#-#--#-#-#-"
        EDUP
        db 'F'
        ds 256-98,'?'
        db '-'
        DUP 8,O
        DUP 12
        db '0'+O
        EDUP
        EDUP
        db 'F'
        ds 256-98,'?'
        ds 256                      ; атрибут

Hex_T   DUP 256,N                   ; 2 hex всегда
        db '0'+(N>>4)+(((N>>4)+6)>>4)*7
        EDUP
        DUP 256,N
        db '0'+(N&15)+(((N&15)+6)>>4)*7
        EDUP

HexD_T  db '-'                      ; 2 hex, 0 = "--"
        DUP 255,N
        db '0'+((N+1)>>4)+((((N+1)>>4)+6)>>4)*7
        EDUP
        db '-'
        DUP 255,N
        db '0'+((N+1)&15)+((((N+1)&15)+6)>>4)*7
        EDUP
        ds 256                      ; атрибут шума

Row_A   ds 256                      ; атрибут номера строки

Sym_T   db '-'                      ; 0 "-", 1..9, A..W, дальше "?"
        DUP 9,I
        db '1'+I
        EDUP
        DUP 23,I
        db 'A'+I
        EDUP
        ds 256-33,'?'
        ds 256                      ; атрибут сэмпла
        ds 256                      ; атрибут орнамента

Hx1_T   db '-'                      ; 0 "-", 1..F, дальше "?"
        DUP 15,I
        db '0'+(I+1)+(((I+1)+6)>>4)*7
        EDUP
        ds 256-16,'?'
        ds 256                      ; атрибут огибающей
        ds 256                      ; атрибут громкости
Tables_End

    ASSERT Hex_T == Note_T+4*256
    ASSERT HexD_T == Hex_T+2*256
    ASSERT Row_A == HexD_T+3*256
    ASSERT Sym_T == Row_A+256
    ASSERT Hx1_T == Sym_T+3*256
    ASSERT Tables_End == Hx1_T+3*256

; Сгенерированный код строки
ROW_CODE_MAX    equ 3072
Row_Code        ds ROW_CODE_MAX

    ENDMODULE

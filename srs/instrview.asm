; =========================================================================
; ИНСТРУМЕНТЫ И ОРНАМЕНТЫ - тулза (окно 1, #4000, страница PAGE_TOOL_INSTR).
; Вкладки Instr и Orn - одна тулза, режим Iv_Mode (с вкладки - SV_TOOL_ARG).
; =========================================================================
; ЭКРАН (строки 0..3 - копия шапки; клик по ней - вкладки / назад в вид паттерна):
;   слева    - список: номер (как в паттерне, 1..W) и имя; клик - выбрать;
;   середина - Name, Len, Loop; кнопки Clone Copy Paste Clear Unloop < >;
;              строки текущего, курсор - клавиатура и мышь;
;   справа   - библиотека (каталог диска) - потом.
; Строка инструмента (формат FTC, sdk/plugin.asm IR_*):
;   L  Rw  TNE  ±тон^  шум^  ±огиб^  V слайд R  полоса громкости
;   L - строка цикла (клик в колонку L - цикл сюда), ^ - накопление, R - ретриггер.
; Строка орнамента: L Rw ±нота^ (десятичная, полутоны) шум^ и полоса смещения ноты.
; Клавиши редактора: стрелки, PgUp/PgDn, Home/End; hex-цифры - в числа; '-' / '=' -
; знак (у слайда - вниз / вверх); пробел - переключить флаг. Tab - редактор <-> Name.
;
; Данные - прямо в странице инструментов трека (SH_INS_PAGE), она в окне 2 на всё
; время работы. Экран рисуется из неё заново после каждой правки (Iv_Dirty).
; =========================================================================
    MODULE instrview

IV_SCR_H        equ TL_SCR_H        ; текстовая страница - в окне 3
IV_TOP          equ TL_TOP          ; первая строка экрана тулзы

; --- список (слева)
LI_X            equ 0               ; рамка: колонки 0..20
LI_W            equ 21
LI_ROW0         equ IV_TOP+1        ; первая строка списка
LI_ROWS         equ 29
LI_NAME_X       equ 3               ; номер - в колонке 1, имя - 16 знаков

; --- редактор (середина)
ED_X            equ 21              ; рамка: колонки 21..69, внутри 22..68
ED_W            equ 49
ED_IN_X         equ ED_X+1
ED_IN_W         equ ED_W-2
NM_Y            equ IV_TOP+1        ; Name, Len, Loop
NM_L            equ 23
NM_V            equ 28              ; имя - 16 знаков
NAME_LEN        equ 16
LEN_L           equ 46              ; Len [-]nn[+]
LEN_M           equ 50
LEN_V           equ 52
LEN_P           equ 54
LOOP_L          equ 57              ; Loop [-]nn[+]
LOOP_M          equ 62
LOOP_V          equ 64
LOOP_P          equ 66
BT_Y            equ IV_TOP+3        ; кнопки
CAP_Y           equ IV_TOP+5        ; заголовки колонок
ER_ROW0         equ IV_TOP+6        ; первая строка данных
ER_ROWS         equ 24              ; строк на экране (до TL_LAST-2)
ER_LOOP_X       equ 22              ; L
ER_NUM_X        equ 23              ; номер строки
ER_DATA_X       equ 26              ; данные
BAR_X           equ 49              ; инструмент: полоса громкости (15)
OB_X            equ 36              ; орнамент: полоса смещения ноты
OB_MID          equ 52              ;   её середина (смещение 0), видно ±16
OB_HALF         equ 16

; --- библиотека (справа)
LB_X            equ 70
LB_W            equ 20

; --- вид колонки курсора
KD_BIT          equ 0               ; флаг: байт строки, маска
KD_TSIGN        equ 1               ; знак тона
KD_TONE         equ 2               ; цифра тона: сдвиг 8 / 4 / 0
KD_NOISE        equ 3               ; цифра шума: вес #10 / #01
KD_ESIGN        equ 4               ; знак смещения огибающей
KD_ENV          equ 5               ; цифра огибающей: вес #10 / #01
KD_VOL          equ 6               ; громкость
KD_SLIDE        equ 7               ; слайд громкости: нет -> вверх -> вниз
KD_NSIGN        equ 8               ; орнамент: знак ноты
KD_NOTE         equ 9               ; орнамент: десятичная цифра ноты: вес 10 / 1
CL_SIZE         equ 4               ; колонка: экран, вид, байт, параметр

; --- клавиши (PS/2, E0-коды +#80)
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
KEY_SPACE       equ #29
KEY_MINUS       equ #4E             ; '-'
KEY_PLUS        equ #55             ; '=' (+ без Shift)
KEY_KP_MINUS    equ #7B
KEY_KP_PLUS     equ #79
PG_STEP         equ 8               ; PgUp / PgDn - строк

    MACRO IV_FIELD x,y,w,h,flags,handler,param
        db x,y,w,h,flags,PAGE_TOOL_INSTR
        dw handler,0,param
    ENDM

; =========================================================================
; ВХОД (коре: Tools_Loop -> Call_Tool)
; =========================================================================
Iv_Start
        ld a,(SV_DRAW_PAGE)         ; экран - в окно 3 на всё время работы
        SETPAGE3 a
        ld a,(SV_SONG_PAGE)         ; страница инструментов - из заголовка трека
        SETPAGE2 a
        ld a,(#8000+SH_INS_PAGE)
        ld (Iv_Page),a
        RESTPAGE2
        ld a,(Iv_Page)              ; инструменты - в окно 2 на всё время работы
        SETPAGE2 a
        ld a,(SV_TOOL_ARG)          ; Instr / Orn - с вкладки
        call Iv_Set_Mode
        call Tr_Active              ; кнопки транспорта - по плееру
        ld hl,Iv_Fields
        call Fld_Init
        ld hl,F_Edit
        call Fld_Set_Focus

Iv_Loop
        halt
        call Iv_Keys
        call Fld_Update
        ld a,(Iv_Exit)              ; другая вкладка - выходим в коре
        or a
        jr nz,Iv_Leave
        ld a,(Iv_Dirty)
        or a
        call nz,Iv_Draw
        call Iv_Buttons             ; кнопки - каждый кадр (под мышью - подсветка)
        jr Iv_Loop

;-------- Выход в коре (страница следующей тулзы - уже в SV_TOOL)
Iv_Leave
        xor a
        ld (Iv_Exit),a
        call Tool_Clear             ; экран - под вид паттерна
        RESTPAGE2
        RESTPAGE3
        ret

; --- состояние
Iv_Page         db 0                ; страница инструментов и орнаментов трека
Iv_Mode         db 0                ; 0 - инструменты, 1 - орнаменты
Iv_Exit         db 0                ; 1 - выйти в коре
Iv_Dirty        db 0                ; 1 - перерисовать экран
Iv_Num          db 0                ; текущий номер (0.. = номер 1..) в этом режиме
Iv_Nums         db 0,0              ; запомненный номер каждого режима
Iv_LTop         db 0                ; первая строка списка
Ed_Row          db 0                ; курсор: строка
Ed_Col          db 0                ;   колонка (номер в таблице колонок)
Ed_Top          db 0                ; первая видимая строка
Iv_Clip_Mode    db 0                ; буфер Copy: 0 - пуст, 1 - инструмент, 2 - орнамент
Iv_Clip         ds INS_BLOCK

;-------- Режим A (0 - Instr, 1 - Orn): номер этого режима, шапка, экран заново
Iv_Set_Mode
        ld b,a
        ld a,(Iv_Mode)              ; номер старого режима - запомнить
        ld hl,Iv_Nums
        call Hl_Add_A
        ld a,(Iv_Num)
        ld (hl),a
        ld a,b
        ld (Iv_Mode),a
        ld hl,Iv_Nums               ; номер нового
        call Hl_Add_A
        ld a,(hl)
        ld (Iv_Num),a
        xor a
        ld (Iv_LTop),a
        ld (Ed_Col),a
        call Iv_Head
        call Tool_Clear
        jp Iv_Select

; =========================================================================
; ДАННЫЕ: адреса в странице (окно 2)
; =========================================================================
; HL - на (HL+A). Портит A
Hl_Add_A
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ret

;-------- A - сколько номеров в режиме (32 / 16)
Iv_Count
        ld a,(Iv_Mode)
        or a
        ld a,SAMPLES_MAX
        ret z
        ld a,ORNAMENTS_MAX
        ret

;-------- A - номер (0..) -> HL - его блок. Портит A, DE
Iv_Addr
        ld l,a
        ld a,(Iv_Mode)
        or a
        jr nz,.orn
        ld h,0                      ; инструмент: #8000 + n*384 (n*128*3)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        set 7,h
        ret
.orn    ld a,l                      ; орнамент: #8000 + ORN_BASE + n*256
        add a,#80+high ORN_BASE
        ld h,a
        ld l,0
        ret

;-------- HL - блок текущего. Портит A, DE
Iv_Block
        ld a,(Iv_Num)
        jr Iv_Addr

;-------- A - строка -> HL - она в текущем блоке. Портит A, DE
Iv_Row_Addr
        push af
        call Iv_Block
        pop af
        ld e,a
        ld d,0
        inc hl                      ; OH_ROWS
        inc hl
        inc hl
        add hl,de                   ; *2
        add hl,de
        ld a,(Iv_Mode)
        or a
        ret nz                      ; орнамент - 2 байта
        add hl,de                   ; инструмент - 5
        add hl,de
        add hl,de
        ret

;-------- HL - имя текущего (16 знаков). Портит A, DE
Iv_Name_Addr
        call Iv_Block
        ld de,INS_NAME
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld de,ORN_NAME
        add hl,de
        ret

;-------- A - последняя строка текущего (длина-1)
Iv_End
        call Iv_Block
        inc hl
        inc hl                      ; OH_END
        ld a,(hl)
        ret

;-------- IX - строка курсора
Iv_Cur_Row
        ld a,(Ed_Row)
        call Iv_Row_Addr
        push hl
        pop ix
        ret

;-------- Таблица колонок режима: HL - таблица, B - сколько колонок
Iv_Cols
        ld a,(Iv_Mode)
        or a
        ld hl,Ins_Cols
        ld b,INS_COLS
        ret z
        ld hl,Orn_Cols
        ld b,ORN_COLS
        ret

;-------- IY - колонка курсора в таблице
Iv_Cur_Col
        call Iv_Cols
        ld a,(Ed_Col)
        add a,a
        add a,a                     ; *CL_SIZE
        call Hl_Add_A
        push hl
        pop iy
        ret

; Колонки курсора: экран, вид, байт строки, параметр
Ins_Cols
        db 26, KD_BIT,   IR_TONE+1, 1<<IRB_OFF      ; T - тон (бит - "выкл")
        db 27, KD_BIT,   IR_NOISE,  1<<IRB_OFF      ; N - шум (бит - "выкл")
        db 28, KD_BIT,   IR_VOL,    1<<IRB_OFF      ; E - огибающая (бит - "вкл")
        db 30, KD_TSIGN, 0, 0                       ; тон: знак
        db 31, KD_TONE,  0, 8                       ;   цифры
        db 32, KD_TONE,  0, 4
        db 33, KD_TONE,  0, 0
        db 34, KD_BIT,   IR_TONE+1, 1<<IRB_ACC      ;   накопление
        db 36, KD_NOISE, 0, #10                     ; шум: цифры
        db 37, KD_NOISE, 0, #01
        db 38, KD_BIT,   IR_NOISE,  1<<IRB_ACC      ;   накопление
        db 40, KD_ESIGN, 0, 0                       ; огибающая: знак
        db 41, KD_ENV,   0, #10                     ;   цифры
        db 42, KD_ENV,   0, #01
        db 43, KD_BIT,   IR_VOL,    1<<IRB_ACC      ;   накопление
        db 45, KD_VOL,   0, 0                       ; громкость
        db 46, KD_SLIDE, 0, 0                       ; слайд
        db 47, KD_BIT,   IR_TONE+1, 1<<IRB_RETRIG   ; ретриггер огибающей
INS_COLS        equ ($-Ins_Cols)/CL_SIZE
Orn_Cols
        db 26, KD_NSIGN, 0, 0                       ; нота: знак
        db 27, KD_NOTE,  0, 10                      ;   десятки
        db 28, KD_NOTE,  0, 1                       ;   единицы
        db 29, KD_BIT,   OR_NOISE, #40              ;   накопление
        db 31, KD_NOISE, 0, #10                     ; шум: цифры
        db 32, KD_NOISE, 0, #01
        db 33, KD_BIT,   OR_NOISE, #80              ;   накопление
ORN_COLS        equ ($-Orn_Cols)/CL_SIZE

; =========================================================================
; ЭКРАН
; =========================================================================
;-------- Шапка: вкладка режима - выбранной
Iv_Head
        ld a,(Iv_Mode)
        or a
        ld hl,IV_TAB_INSTR
        ld b,5
        jr z,.go
        ld hl,IV_TAB_ORN
        ld b,3
.go     jp Tool_Head
IV_TAB_INSTR    equ IV_SCR_H*256+128+patview.HD_TAB_INSTR
IV_TAB_ORN      equ IV_SCR_H*256+128+patview.HD_TAB_ORN

;-------- Весь экран тулзы
Iv_Draw
        xor a
        ld (Iv_Dirty),a
        call Iv_Frames
        call Iv_Draw_List
        call Iv_Draw_Top
        call Iv_Draw_Caps
        jp Iv_Draw_Rows

;-------- Рамки и их заголовки
Iv_Frames
        ld a,LI_X
        ld (Bx_X),a
        ld a,LI_W
        ld (Bx_W),a
        call Tool_Box
        ld a,ED_X
        ld (Bx_X),a
        ld a,ED_W
        ld (Bx_W),a
        call Tool_Box
        ld a,LB_X
        ld (Bx_X),a
        ld a,LB_W
        ld (Bx_W),a
        call Tool_Box
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,LI_X+2+256*(IV_SCR_H+IV_TOP)
        ld hl,Txt_Instruments
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld hl,Txt_Ornaments
        call PutStr
        ld de,LB_X+2+256*(IV_SCR_H+IV_TOP)
        ld hl,Txt_Library
        jp PutStr

;-------- Список: LI_ROWS строк с номера Iv_LTop
Li_Idx          db 0
Iv_Draw_List
        ld a,(Iv_LTop)
        ld (Li_Idx),a
        ld d,IV_SCR_H+LI_ROW0
.row    push de
        call Iv_List_Row
        pop de
        ld hl,Li_Idx
        inc (hl)
        inc d
        ld a,d
        cp IV_SCR_H+LI_ROW0+LI_ROWS
        jr c,.row
        ret

; Строка D: номер Li_Idx (за концом - пустая)
Li_Row          db 0
Iv_List_Row
        ld a,d
        ld (Li_Row),a
        ld e,LI_X+1
        call Iv_Count
        ld b,a
        ld a,(Li_Idx)
        cp b
        ret nc                      ; за концом - пусто (рамку уже очистили)
        ld hl,Iv_Num                ; текущий - выделен
        cp (hl)
        ld a,(THEME_ATTR+CLR_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld a,(Li_Idx)               ; номер - как в паттерне
        call Num_Sym
        call PutCh
        ld a,' '
        call PutCh
        ld a,(Li_Idx)               ; имя
        call Iv_Addr
        ld de,INS_NAME
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld de,ORN_NAME
        add hl,de
        ld a,(Li_Row)
        ld d,a
        ld e,LI_NAME_X
        ld b,NAME_LEN
        jp Put_Name

;-------- Имя: HL - 16 знаков (0 - конец), B - ширина, дополнить пробелами
Put_Name
.c      ld a,(hl)
        or a
        jr z,.sp
        call PutCh
        inc hl
        djnz .c
        ret
.sp     ld a,' '
        call PutCh
        djnz .sp
        ret

;-------- A - номер (0..) -> символ, как в паттерне: 1..9, A..W
Num_Sym
        inc a
        cp 10
        jr c,.d
        add a,'A'-10-'0'
.d      add a,'0'
        ret

;-------- Верх редактора: Name, Len, Loop
Iv_Draw_Top
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld de,NM_L+256*(IV_SCR_H+NM_Y)
        ld hl,Txt_Name
        call PutStr
        ld e,LEN_L
        ld hl,Txt_Len
        call PutStr
        ld e,LOOP_L
        ld hl,Txt_Loop
        call PutStr
        ld hl,(SV_FOCUS)            ; имя: в фокусе - цветом курсора
        ld de,F_Name
        or a
        sbc hl,de
        ld a,(THEME_ATTR+CLR_SELECT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        call Iv_Name_Addr
        ld de,NM_V+256*(IV_SCR_H+NM_Y)
        ld b,NAME_LEN
        call Put_Name
        ld a,(THEME_ATTR+CLR_TEXT)  ; длина и цикл
        ld c,a
        call Iv_End
        inc a
        ld de,LEN_V+256*(IV_SCR_H+NM_Y)
        call PutHex2
        call Iv_Block
        inc hl                      ; OH_LOOP
        ld a,(hl)
        ld de,LOOP_V+256*(IV_SCR_H+NM_Y)
        jp PutHex2

;-------- Заголовки колонок
Iv_Draw_Caps
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,ED_IN_X+256*(IV_SCR_H+CAP_Y)
        ld b,ED_IN_W
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld e,ER_NUM_X
        ld hl,Txt_Caps_Ins
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld hl,Txt_Caps_Orn
        jp PutStr

;-------- Строки: ER_ROWS с Ed_Top, за концом - пусто; потом курсор
Er_Idx          db 0
Iv_Draw_Rows
        ld a,(Ed_Top)
        ld (Er_Idx),a
        ld d,IV_SCR_H+ER_ROW0
.row    push de
        call Er_Blank
        call Iv_End
        ld hl,Er_Idx
        cp (hl)
        jr c,.next                  ; за концом
        pop de
        push de
        ld a,(hl)
        call Er_Head                ; E - на данные
        push de
        ld a,(Er_Idx)
        call Iv_Row_Addr
        push hl
        pop ix
        pop de
        ld a,(Iv_Mode)
        or a
        jr nz,.orn
        call Ir_Body
        jr .next
.orn    call Or_Body
.next   pop de
        ld hl,Er_Idx
        inc (hl)
        inc d
        ld a,d
        cp IV_SCR_H+ER_ROW0+ER_ROWS
        jr c,.row
        jp Er_Cursor

; Строка D (внутри рамки) - пробелы. E - на начало, DE сохраняет
Er_Blank
        push de
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld e,ED_IN_X
        ld b,ED_IN_W
.sp     ld a,' '
        call PutCh
        djnz .sp
        pop de
        ret

; L (строка цикла) и номер строки A. D - строка экрана, на выходе E - на данных
Er_Head
        ld b,a
        push de
        call Iv_Block
        pop de
        inc hl                      ; OH_LOOP
        ld a,(THEME_ATTR+CLR_LOOP)
        ld c,a
        ld e,ER_LOOP_X
        call Loop_Char
        call PutCh
        ld a,(THEME_ATTR+CLR_ROW_NUM)
        ld c,a
        ld a,b
        call PutHex2
        ld e,ER_DATA_X
        ret

; Скобка цикла для строки B: HL - на OH_LOOP (за ним OH_END). A - символ:
; ┌ - строка цикла, │ - внутри, └ - конец; цикл на конце - '[', вне цикла - пробел
Loop_Char
        ld a,b
        cp (hl)                     ; выше цикла
        ld a,' '
        ret c
        inc hl
        ld a,(hl)                   ; ниже конца - не бывает (строк за концом не рисуем)
        dec hl
        cp b
        jr z,.end
        ld a,(hl)
        cp b
        ld a,BOX_V                  ; │
        ret nz
        ld a,BOX_TL                 ; ┌
        ret
.end    ld a,(hl)
        cp b
        ld a,BOX_BL                 ; └
        ret nz
        ld a,'['                    ; цикл из одной строки
        ret

;-------- Строка инструмента: IX - строка, DE - экран (колонка ER_DATA_X)
Ir_Body
        ld a,(THEME_ATTR+CLR_INSTR) ; T N E
        ld c,a
        ld a,(ix+IR_TONE+1)
        ld b,1<<IRB_OFF
        ld hl,'.'*256+'T'
        call Put_If
        ld a,(ix+IR_NOISE)
        ld hl,'.'*256+'N'
        call Put_If
        ld a,(ix+IR_VOL)
        ld hl,'E'*256+'.'
        call Put_If
        inc e
        ld a,(THEME_ATTR+CLR_NOTE)  ; тон: знак, 3 цифры, накопление
        ld c,a
        call Tone_Get
        call PutCh
        ld a,h
        call HexDigit
        call PutCh
        ld a,l
        call PutHex2
        ld a,(ix+IR_TONE+1)
        call Put_Acc
        inc e
        ld a,(THEME_ATTR+CLR_NOISE) ; шум: 2 цифры, накопление
        ld c,a
        ld a,(ix+IR_NOISE)
        and #1F
        call PutHex2
        ld a,(ix+IR_NOISE)
        call Put_Acc
        inc e
        ld a,(THEME_ATTR+CLR_ENVPER) ; огибающая: знак, 2 цифры, накопление
        ld c,a
        ld a,(ix+IR_ENV)
        call Sign_Get
        call PutCh
        ld a,l
        call PutHex2
        ld a,(ix+IR_VOL)
        call Put_Acc
        inc e
        ld a,(THEME_ATTR+CLR_VOLUME) ; громкость, слайд, ретриггер
        ld c,a
        ld a,(ix+IR_VOL)
        and #0F
        call HexDigit
        call PutCh
        ld a,(THEME_ATTR+CLR_PARAM)
        ld c,a
        ld a,(ix+IR_VOL)
        call Slide_Char
        call PutCh
        ld a,(ix+IR_TONE+1)
        ld b,1<<IRB_RETRIG
        ld hl,'R'*256+'.'
        call Put_If
        ld a,(THEME_ATTR+CLR_VOLUME) ; полоса громкости
        ld c,a
        ld e,BAR_X
        ld a,(ix+IR_VOL)
        and #0F
        ret z
        ld b,a
.bar    ld a,#DB                    ; █
        call PutCh
        djnz .bar
        ret

;-------- Строка орнамента: IX - строка, DE - экран (колонка ER_DATA_X)
Or_Body
        ld a,(THEME_ATTR+CLR_NOTE)  ; нота: знак, 2 десятичные цифры, накопление
        ld c,a
        ld a,(ix+OR_NOTE)
        call Sign_Get
        call PutCh
        ld a,l
        call Dec2
        ld a,(ix+OR_NOISE)
        ld b,#40
        ld hl,'^'*256+'.'
        call Put_If
        inc e
        ld a,(THEME_ATTR+CLR_NOISE) ; шум: 2 цифры, накопление
        ld c,a
        ld a,(ix+OR_NOISE)
        and #1F
        call PutHex2
        ld a,(ix+OR_NOISE)
        call Put_Acc
        ld a,(THEME_ATTR+CLR_EMPTY) ; полоса: точки, середина, смещение
        ld c,a
        ld e,OB_X
        ld b,OB_HALF*2+1
.dot    ld a,#FA                    ; ·
        call PutCh
        djnz .dot
        ld a,(THEME_ATTR+CLR_SEP)
        ld c,a
        ld e,OB_MID
        ld a,BOX_V
        call PutCh
        ld a,(THEME_ATTR+CLR_ORNAMENT)
        ld c,a
        ld a,(ix+OR_NOTE)           ; смещение, не дальше ±OB_HALF
        or a
        jp p,.pos
        cp -OB_HALF
        jr nc,.put
        ld a,-OB_HALF
        jr .put
.pos    cp OB_HALF+1
        jr c,.put
        ld a,OB_HALF
.put    add a,OB_MID
        ld e,a
        ld a,#DB                    ; █
        jp PutCh

; A - байт, B - маска: бит есть - символ H, нет - L
Put_If
        and b
        ld a,h
        jr nz,$+3
        ld a,l
        jp PutCh

; Накопление - бит 7 байта A: '^' или '.'
Put_Acc
        rlca
        ld a,'^'
        jr c,$+4
        ld a,'.'
        jp PutCh

; Слайд громкости из байта A: '.' нет, '+' вверх, '-' вниз
Slide_Char
        bit IRB_SLIDE,a
        ld b,a
        ld a,'.'
        ret z
        bit IRB_SLIDE_DOWN,b
        ld a,'+'
        ret z
        ld a,'-'
        ret

; A - знаковый байт -> L - модуль, A - знак ('+' / '-')
Sign_Get
        ld l,a
        or a
        ld a,'+'
        ret p
        ld a,l
        neg
        ld l,a
        ld a,'-'
        ret

; A - 0..99 -> две десятичные цифры (больше 99 - "99")
Dec2
        cp 100
        jr c,$+4
        ld a,99
        ld b,'0'-1
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld l,a
        ld a,b
        call PutCh
        ld a,l
        jp PutCh

;-------- Тон строки IX (12 бит со знаком) -> HL - модуль, A - знак. Портит A
Tone_Get
        ld a,(ix+IR_TONE+1)
        and #0F
        ld h,a
        ld l,(ix+IR_TONE)
        bit 3,h
        ld a,'+'
        ret z
        ld a,l                      ; минус: модуль = #1000 - HL
        cpl
        ld l,a
        ld a,h
        cpl
        and #0F
        ld h,a
        inc hl
        ld a,'-'
        ret

;-------- Курсор: ячейка цветом курсора (редактор не в фокусе - выделения)
Er_Cursor
        ld a,(Ed_Top)               ; строка видна?
        ld b,a
        ld a,(Ed_Row)
        sub b
        ret c
        cp ER_ROWS
        ret nc
        add a,IV_SCR_H+ER_ROW0
        ld d,a
        call Iv_Cur_Col
        ld a,(iy+0)
        or #80                      ; атрибут
        ld e,a
        ld hl,(SV_FOCUS)
        push de
        ld de,F_Edit
        or a
        sbc hl,de
        pop de
        ld a,(THEME_ATTR+CLR_CURSOR)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld (de),a
        ret

;-------- Кнопки: под мышью - подсветка, держат - нажата. [-]/[+] - значки
Iv_Buttons
        ld hl,Btn_Glyphs
.g      ld e,(hl)                   ; поле
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.text
        push de
        pop ix
        ld e,(hl)                   ; колонка, значок
        inc hl
        ld b,(hl)
        inc hl
        push hl
        call Btn_State              ; Z - нажата
        ld a,b
        jr nz,$+4
        add a,BTN_PRESSED
        ld b,a
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld d,IV_SCR_H+NM_Y
        ld a,b
        call PutCh
        ld a,b
        inc a
        call PutCh
        pop hl
        jr .g
.text   ld hl,Btn_Texts
.t      ld e,(hl)                   ; поле
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        push de
        pop ix
        ld e,(hl)                   ; колонка
        inc hl
        ld a,(hl)                   ; текст
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push hl
        call Btn_State
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr c,.put
        ld a,(THEME_ATTR+CLR_HOVER)
        jr nz,.put
        ld a,(THEME_ATTR+CLR_CURSOR)
.put    ld c,a
        ld d,IV_SCR_H+BT_Y
        pop hl
        call PutStr
        pop hl
        inc hl
        jr .t

; Кнопка IX: CF - не под мышью; иначе Z - нажата, NZ - только под мышью. E сохраняет
Btn_State
        push de
        push ix
        pop hl
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        jr nz,.out
        push ix
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ld a,h                      ; Z - нажата, CF = 0
        or l
        pop de
        ret
.out    pop de
        scf
        ret

Btn_Glyphs
        dw F_LenM
        db LEN_M, GLYPH_BTN_MINUS
        dw F_LenP
        db LEN_P, GLYPH_BTN_PLUS
        dw F_LoopM
        db LOOP_M, GLYPH_BTN_MINUS
        dw F_LoopP
        db LOOP_P, GLYPH_BTN_PLUS
        dw 0
Btn_Texts
        dw F_Clone
        db BC_X
        dw Txt_Clone
        dw F_Copy
        db BY_X
        dw Txt_Copy
        dw F_Paste
        db BP_X
        dw Txt_Paste
        dw F_Clear
        db BL_X
        dw Txt_Clear
        dw F_Unloop
        db BU_X
        dw Txt_Unloop
        dw F_Prev
        db BV_X
        dw Txt_Prev
        dw F_Next
        db BN_X
        dw Txt_Next
        dw 0

; --- кнопки в строке BT_Y: колонка и ширина (текст с пробелами по краям)
BC_X            equ 23              ; " Clone "
BY_X            equ 31              ; " Copy "
BP_X            equ 38              ; " Paste "
BL_X            equ 46              ; " Clear "
BU_X            equ 54              ; " Unloop "
BV_X            equ 63              ; " < "
BN_X            equ 66              ; " > "

; =========================================================================
; ПОЛЯ
; =========================================================================
Iv_Fields
        IV_FIELD patview.HD_PLAY_X,   patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 0  ; ⇄ паттерн по кругу
        IV_FIELD patview.HD_PLAY_X+4, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 1  ; |◀ сонг с начала
        IV_FIELD patview.HD_PLAY_X+8, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 2  ; ▶ сонг
        IV_FIELD patview.HD_PLAY_X+12,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 3  ; ▷ паттерн с роу
        IV_FIELD patview.HD_PLAY_X+16,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 4  ; ■ стоп
        IV_FIELD patview.HD_TAB_INSTR,patview.HD_TABS_Y,5,1, FF_HAND, Iv_TabEv, 0   ; Instr
        IV_FIELD patview.HD_TAB_ORN,  patview.HD_TABS_Y,3,1, FF_HAND, Iv_TabEv, 1   ; Orn
        IV_FIELD patview.HD_TAB_DISK, patview.HD_TABS_Y,4,1, FF_HAND, Iv_TabEv, 2   ; Disk
        IV_FIELD 0,0,90,IV_TOP, 0, Iv_TabEv, 3                          ; остальная шапка: назад
F_List  IV_FIELD LI_X+1,LI_ROW0,LI_W-2,LI_ROWS, 0, Iv_ListEv, 0       ; список
F_Name  IV_FIELD NM_V,NM_Y,NAME_LEN,1, FF_FOCUS|FF_HAND, Iv_NameEv, 0 ; имя
F_LenM  IV_FIELD LEN_M,NM_Y,2,1, FF_HAND, Iv_BtnEv, 0                 ; Len -
F_LenP  IV_FIELD LEN_P,NM_Y,2,1, FF_HAND, Iv_BtnEv, 1                 ; Len +
F_LoopM IV_FIELD LOOP_M,NM_Y,2,1, FF_HAND, Iv_BtnEv, 2                ; Loop -
F_LoopP IV_FIELD LOOP_P,NM_Y,2,1, FF_HAND, Iv_BtnEv, 3                ; Loop +
F_Clone IV_FIELD BC_X,BT_Y,7,1, FF_HAND, Iv_BtnEv, 4
F_Copy  IV_FIELD BY_X,BT_Y,6,1, FF_HAND, Iv_BtnEv, 5
F_Paste IV_FIELD BP_X,BT_Y,7,1, FF_HAND, Iv_BtnEv, 6
F_Clear IV_FIELD BL_X,BT_Y,7,1, FF_HAND, Iv_BtnEv, 7
F_Unloop IV_FIELD BU_X,BT_Y,8,1, FF_HAND, Iv_BtnEv, 8
F_Prev  IV_FIELD BV_X,BT_Y,3,1, FF_HAND, Iv_BtnEv, 9                  ; < предыдущий
F_Next  IV_FIELD BN_X,BT_Y,3,1, FF_HAND, Iv_BtnEv, 10                 ; > следующий
F_Edit  IV_FIELD ED_IN_X,ER_ROW0,ED_IN_W,ER_ROWS, FF_FOCUS, Iv_EditEv, 0 ; строки
        db FLD_END

;-------- Шапка: Instr / Orn - режим, Disk - тулза диска, остальное - вид паттерна
Iv_TabEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        cp 2
        jr nc,.out
        ld hl,Iv_Mode               ; тот же режим - ничего
        cp (hl)
        ret z
        call Iv_Set_Mode
        ld hl,F_Edit
        jp Fld_Set_Focus
.out    ld b,PAGE_TOOL_DISK
        jr z,.go
        ld b,PAGE_TOOL_PATVIEW
.go     ld a,b
        ld (SV_TOOL),a
        ld a,1
        ld (Iv_Exit),a
        ret

;-------- Кнопки
Iv_BtnEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        add a,a
        ld hl,Btn_Act
        call Hl_Add_A
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .jp
        jp Iv_Changed
.jp     jp (hl)

Btn_Act dw Len_Dn, Len_Up, Loop_Dn, Loop_Up
        dw Iv_Clone, Iv_Copy, Iv_Paste, Iv_Clear, Iv_Unloop, Iv_Prev, Iv_Next

;-------- Список: нажали - выбрать, колесо - листать
Iv_ListEv
        cp EV_PRESS
        jr z,.press
        cp EV_WHEEL
        ret nz
        ld hl,Iv_LTop               ; вниз (C < 0) - дальше
        call Iv_Count
        sub LI_ROWS                 ; последняя первая строка списка
        ret c
        ret z
        ld b,a
        bit 7,c
        jr z,.up
        ld a,(hl)
        cp b
        ret nc
        inc (hl)
        jp Iv_Changed
.up     ld a,(hl)
        or a
        ret z
        dec (hl)
        jp Iv_Changed
.press  ld a,(SV_MOUSE_ROW)         ; строка -> номер
        sub LI_ROW0
        ld hl,Iv_LTop
        add a,(hl)
        ld b,a
        call Iv_Count
        cp b
        ret c
        ret z
        ld a,b
        ld (Iv_Num),a
        jp Iv_Select

;-------- Строки: нажали - курсор (флаг, полоса, L - сразу правка), колесо, клавиши
Iv_EditEv
        cp EV_PRESS
        jr z,.press
        cp EV_WHEEL
        jr z,.wheel
        cp EV_KEY
        jp z,Ed_Key
        cp EV_FOCUS_IN
        jr z,.focus
        cp EV_FOCUS_OUT
        ret nz
.focus  jp Iv_Changed
.wheel  bit 7,c                     ; вниз - строка ниже
        call nz,Ed_Down
        bit 7,c
        call z,Ed_Up
        jp Iv_Changed
.press  ld a,(SV_MOUSE_ROW)         ; строка
        sub ER_ROW0
        ld hl,Ed_Top
        add a,(hl)
        ld b,a
        call Iv_End
        cp b
        ret c                       ; за концом
        ld a,b
        ld (Ed_Row),a
        ld a,(SV_MOUSE_COL)
        cp ER_LOOP_X                ; колонка L - цикл сюда
        jr nz,.col
        call Iv_Block
        inc hl
        ld (hl),b
        jp Iv_Changed
.col    ld c,a                      ; колонка курсора с такой же колонкой экрана
        call Iv_Cols
        ld e,0
.f      ld a,(hl)
        cp c
        jr z,.hit
        inc hl
        inc hl
        inc hl
        inc hl
        inc e
        djnz .f
        ld a,(Iv_Mode)              ; инструмент: полоса - громкость
        or a
        jp nz,Iv_Changed
        ld a,c
        sub BAR_X
        jp c,Iv_Changed
        cp 15
        jp nc,Iv_Changed
        inc a
        ld b,a
        call Iv_Cur_Row
        ld a,(ix+IR_VOL)
        and #F0
        or b
        ld (ix+IR_VOL),a
        jp Iv_Changed
.hit    ld a,e
        ld (Ed_Col),a
        inc hl                      ; флаг и слайд - переключить сразу
        ld a,(hl)
        cp KD_BIT
        jr z,.tog
        cp KD_SLIDE
        jp nz,Iv_Changed
.tog    call Ed_Toggle
        jp Iv_Changed

;-------- Имя: буквы, Backspace (Enter, Tab - фокус в строки)
Iv_NameEv
        cp EV_FOCUS_IN
        jr z,.redraw
        cp EV_FOCUS_OUT
        jr z,.redraw
        cp EV_KEY
        ret nz
        ld a,b
        cp KEY_BACK
        jr z,.back
        cp KEY_ENTER
        jr z,.done
        cp KEY_TAB                  ; Tab - не наш (фокус - в Iv_Keys)
        ret z
        or a                        ; E0-коды - не буквы
        ret m
        ld h,high Key_Chars         ; код -> символ (0 - не символ)
        ld l,a
        ld a,(hl)
        or a
        ret z
        bit 0,c                     ; Shift: буквы - заглавные, минус - подчёркивание
        jr z,.put
        cp '-'
        jr nz,.up
        ld a,'_'
        jr .put
.up     cp 'a'
        jr c,.put
        cp 'z'+1
        jr nc,.put
        sub 'a'-'A'
.put    ld b,a
        call Iv_Name_Len            ; HL - на конец, A - длина
        cp NAME_LEN
        jr nc,.eat
        ld (hl),b
        jr .redraw
.back   call Iv_Name_Len
        or a
        jr z,.eat
        dec hl
        ld (hl),0
        jr .redraw
.done   ld hl,F_Edit
        call Fld_Set_Focus
.redraw call Iv_Changed
.eat    scf                         ; клавиша - наша
        ret

; HL - первый 0 имени (или за 16-м знаком), A - длина. BC сохраняет
Iv_Name_Len
        call Iv_Name_Addr
        ld e,0
.l      ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc e
        ld a,e
        cp NAME_LEN
        jr c,.l
.e      ld a,e
        ret

;-------- Клавиши: полю в фокусе; Tab - фокус строки <-> имя
Iv_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld b,a
        push bc
        call Fld_Key
        pop bc
        jr c,.k
        ld a,b
        cp KEY_TAB
        jr nz,.k
        ld hl,(SV_FOCUS)
        ld de,F_Edit
        or a
        sbc hl,de
        ld hl,F_Name
        jr z,$+5
        ld hl,F_Edit
        call Fld_Set_Focus
        jr .k

; =========================================================================
; РЕДАКТОР СТРОК
; =========================================================================
;-------- Клавиша B (флаги C) полю строк. Выход: CF - наша
Ed_Key
        ld hl,Ed_Keys
        push bc
        call Keys_Table
        pop bc
        jr c,.ok
        ld a,b                      ; цифры, знаки, пробел - в колонку курсора
        call Ed_Type
        ret nc
.ok     call Iv_Changed
        scf
        ret

Ed_Keys db KEY_UP,    0
        dw Ed_Up
        db KEY_DOWN,  0
        dw Ed_Down
        db KEY_LEFT,  0
        dw Ed_Left
        db KEY_RIGHT, 0
        dw Ed_Right
        db KEY_PGUP,  0
        dw Ed_PgUp
        db KEY_PGDN,  0
        dw Ed_PgDn
        db KEY_HOME,  0
        dw Ed_Home
        db KEY_END,   0
        dw Ed_EndK
        db 0

Ed_Up   ld hl,Ed_Row
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr Ed_Show
Ed_Down call Iv_End
        ld hl,Ed_Row
        cp (hl)
        ret z
        inc (hl)
        jr Ed_Show
Ed_PgUp ld a,(Ed_Row)
        sub PG_STEP
        jr nc,$+3
        xor a
        ld (Ed_Row),a
        jr Ed_Show
Ed_PgDn ld a,(Ed_Row)
        add a,PG_STEP
        ld (Ed_Row),a
        jr Ed_Clamp
Ed_Home xor a
        ld (Ed_Row),a
        jr Ed_Show
Ed_EndK call Iv_End
        ld (Ed_Row),a
        jr Ed_Show
Ed_Left ld hl,Ed_Col
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
Ed_Right
        call Iv_Cols
        ld hl,Ed_Col
        ld a,(hl)
        inc a
        cp b
        ret nc
        ld (hl),a
        ret

;-------- Курсор - не за концом блока, колонка - в таблице; строка курсора - видна
Ed_Clamp
        call Iv_End
        ld hl,Ed_Row
        cp (hl)
        jr nc,.col
        ld (hl),a
.col    call Iv_Cols
        ld a,(Ed_Col)
        cp b
        jr c,Ed_Show
        ld a,b
        dec a
        ld (Ed_Col),a
Ed_Show
        ld hl,Ed_Top
        ld a,(Ed_Row)
        cp (hl)
        jr nc,.low
        ld (hl),a                   ; выше экрана - он с курсора
        ret
.low    sub ER_ROWS-1               ; ниже экрана - курсор в последней строке
        ret c
        cp (hl)
        ret c
        ld (hl),a
        ret

;-------- Ввод в колонку курсора: A - код клавиши. Выход: CF - наша
Ed_Type
        push af
        call Iv_Cur_Row             ; IX - строка, IY - колонка
        call Iv_Cur_Col
        xor a                       ; знак - от клавиши, не "наоборот"
        ld (Ed_Space),a
        pop af
        cp KEY_SPACE                ; пробел - флаг, слайд, знак
        jr z,.space
        cp KEY_MINUS
        jr z,.minus
        cp KEY_KP_MINUS
        jr z,.minus
        cp KEY_PLUS
        jr z,.plus
        cp KEY_KP_PLUS
        jr z,.plus
        call Hex_Key                ; цифра 0..15, CF - не цифра
        ccf
        ret nc
        ld b,a
        ld a,(iy+1)                 ; вид колонки
        cp KD_TONE
        jp z,Ty_Tone
        cp KD_NOISE
        jp z,Ty_Noise
        cp KD_ENV
        jp z,Ty_Env
        cp KD_VOL
        jp z,Ty_Vol
        cp KD_NOTE
        jp z,Ty_Note
        or a                        ; остальным цифры не нужны
        ret
.space  ld a,(iy+1)
        cp KD_BIT
        jr z,Ed_Toggle_Ok
        cp KD_SLIDE
        jr z,Ed_Toggle_Ok
        ld a,1                      ; знак - наоборот
        ld (Ed_Space),a
        jr .sign
.minus  ld b,'-'
        ld a,(iy+1)
        cp KD_SLIDE
        jr nz,.sign
        ld a,(ix+IR_VOL)            ; слайд вниз
        or 1<<IRB_SLIDE|1<<IRB_SLIDE_DOWN
        ld (ix+IR_VOL),a
        scf
        ret
.plus   ld b,'+'
        ld a,(iy+1)
        cp KD_SLIDE
        jr nz,.sign
        ld a,(ix+IR_VOL)            ; слайд вверх
        and ~(1<<IRB_SLIDE_DOWN)
        or 1<<IRB_SLIDE
        ld (ix+IR_VOL),a
        scf
        ret
.sign   ld a,(iy+1)                 ; B - знак (от пробела - Ed_Space, "наоборот")
        cp KD_TSIGN
        jp z,Sg_Tone
        cp KD_ESIGN
        jp z,Sg_Env
        cp KD_NSIGN
        jp z,Sg_Note
        or a
        ret
Ed_Toggle_Ok
        call Ed_Toggle
        scf
        ret

;-------- Флаг / слайд колонки курсора - переключить
Ed_Toggle
        call Iv_Cur_Row
        call Iv_Cur_Col
        ld a,(iy+1)
        cp KD_SLIDE
        jr z,.slide
        ld a,(iy+2)                 ; KD_BIT: байт строки, маска
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ld a,(iy+3)
        xor (hl)
        ld (hl),a
        ret
.slide  ld a,(ix+IR_VOL)            ; нет -> вверх -> вниз -> нет
        bit IRB_SLIDE,a
        jr z,.on
        bit IRB_SLIDE_DOWN,a
        jr nz,.off
        set IRB_SLIDE_DOWN,a
        jr .st
.on     set IRB_SLIDE,a
        res IRB_SLIDE_DOWN,a
        jr .st
.off    and ~(1<<IRB_SLIDE|1<<IRB_SLIDE_DOWN)
.st     ld (ix+IR_VOL),a
        ret

;-------- Код клавиши A -> цифра 0..15 (A..F - hex). CF - не цифра
Hex_Key
        or a
        scf
        ret m                       ; E0-коды
        ld h,high Key_Chars
        ld l,a
        ld a,(hl)
        sub '0'
        ret c
        cp 10
        ccf
        ret nc
        sub 'a'-'0'
        ret c
        cp 6
        ccf
        ret c
        add a,10
        ret

;-------- Цифры: B - цифра, IX - строка, IY - колонка (параметр - вес / сдвиг). CF = 1
Ty_Tone call Tone_Get               ; HL - модуль, A - знак
        push af
        ld a,(iy+3)
        cp 8
        jr z,.hi
        cp 4
        ld a,l
        jr z,.mid
        and #F0                     ; младшая
        or b
        jr .lo
.mid    and #0F                     ; средняя
        rlc b
        rlc b
        rlc b
        rlc b
        or b
.lo     ld l,a
        jr .put
.hi     ld h,b                      ; старшая
.put    pop af
        call Tone_Put
        scf
        ret

Ty_Noise
        ld a,(ix+IR_NOISE)          ; шум 0..31: старшая цифра - 0/1
        ld c,a
        and #1F
        bit 4,(iy+3)
        jr z,.lo
        and #0F
        bit 0,b
        jr z,.st
        or #10
        jr .st
.lo     and #10
        or b
.st     ld b,a
        ld a,c
        and #E0
        or b
        ld (ix+IR_NOISE),a
        scf
        ret

Ty_Env  ld a,(ix+IR_ENV)            ; L - модуль, A - знак
        call Sign_Get
        ld c,a
        ld a,(iy+3)
        cp #10
        ld a,l
        jr z,.hi
        and #F0
        or b
        jr .put
.hi     and #0F
        rlc b
        rlc b
        rlc b
        rlc b
        or b
.put    ld l,a
        ld a,c
        jp Env_Put

Ty_Vol  ld a,(ix+IR_VOL)
        and #F0
        or b
        ld (ix+IR_VOL),a
        scf
        ret

Ty_Note ld a,b                      ; десятичная цифра
        cp 10
        ccf
        ret nc                      ; A..F - не наши (CF = 0)
        ld a,(ix+OR_NOTE)           ; L - модуль, C - знак
        call Sign_Get
        ld c,a
        ld a,l                      ; десятки, единицы
        ld d,-1
.t      inc d
        sub 10
        jr nc,.t
        add a,10
        ld e,a
        ld a,(iy+3)
        cp 10
        jr z,.hi
        ld e,b
        jr .sum
.hi     ld d,b
.sum    ld a,d                      ; модуль = d*10+e
        add a,a
        ld l,a
        add a,a
        add a,a
        add a,l
        add a,e
        ld l,a
        ld a,c
        jp Note_Put

;-------- Знак: B - '+' / '-' ('-' от пробела - "наоборот"). CF = 1
Sg_Tone call Tone_Get
        call Sign_New
        call Tone_Put
        scf
        ret
Sg_Env  ld a,(ix+IR_ENV)
        call Sign_Get
        call Sign_New
        jr Env_Put
Sg_Note ld a,(ix+OR_NOTE)
        call Sign_Get
        call Sign_New
        jr Note_Put

; A - знак сейчас, B - что нажали -> A - новый знак (пробел: наоборот)
Sign_New
        ld c,a
        ld a,(Ed_Space)
        or a
        ld a,b
        ret z
        ld a,c
        cp '-'
        ld a,'+'
        ret z
        ld a,'-'
        ret
Ed_Space        db 0                ; 1 - знак от пробела (ставит Ed_Type)

;-------- Тон: HL - модуль, A - знак -> в строку IX (+ не больше #7FF, - не больше #800)
Tone_Put
        cp '-'
        ld a,h
        jr z,.neg
        cp 8
        jr c,.st
        ld hl,#7FF
        jr .st
.neg    cp 8
        jr c,.ng
        ld hl,#800
.ng     ld a,l                      ; #1000 - HL
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
.st     ld (ix+IR_TONE),l
        ld a,h
        and #0F
        ld h,a
        ld a,(ix+IR_TONE+1)
        and #F0
        or h
        ld (ix+IR_TONE+1),a
        ret

;-------- Огибающая / нота: L - модуль, A - знак -> знаковый байт в строку IX. CF = 1
Env_Put call Byte_Signed
        ld (ix+IR_ENV),a
        scf
        ret
Note_Put
        ld h,a
        ld a,l                      ; нота - не больше 99
        cp 100
        jr c,$+4
        ld l,99
        ld a,h
        call Byte_Signed
        ld (ix+OR_NOTE),a
        scf
        ret

; L - модуль, A - знак -> A - знаковый байт (+ не больше #7F, - не больше #80)
Byte_Signed
        cp '-'
        ld a,l
        jr z,.neg
        cp #80
        ret c
        ld a,#7F
        ret
.neg    cp #81
        jr c,$+4
        ld a,#80
        neg
        ret

; =========================================================================
; ДЕЙСТВИЯ
; =========================================================================
;-------- Что-то поменяли - перерисовать
Iv_Changed
        ld a,1
        ld (Iv_Dirty),a
        ret

;-------- Выбран другой номер: курсор в его пределах, список - чтобы был виден
Iv_Select
        call Ed_Clamp
        ld hl,Iv_LTop
        ld a,(Iv_Num)
        cp (hl)
        jr nc,.low
        ld (hl),a
        jr Iv_Changed
.low    sub LI_ROWS-1
        jr c,Iv_Changed
        cp (hl)
        jr c,Iv_Changed
        ld (hl),a
        jr Iv_Changed

Iv_Prev ld hl,Iv_Num
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr Iv_Select
Iv_Next call Iv_Count
        ld hl,Iv_Num
        dec a
        cp (hl)
        ret z
        inc (hl)
        jr Iv_Select

;-------- Длина: + - новая строка - копия последней; - - цикл не за концом
Len_Up  call Iv_End
        cp INS_ROWS_MAX-1           ; у орнамента столько же (ORN_ROWS_MAX)
        ret nc
        call Row_Copy_Last
        call Iv_Block
        inc hl
        inc hl
        inc (hl)                    ; OH_END
        ld a,(hl)
        dec hl
        dec hl
        ld (hl),a                   ; OH_LEN - копия
        ret
Len_Dn  call Iv_Block
        inc hl
        inc hl
        ld a,(hl)                   ; OH_END
        or a
        ret z
        dec a
        ld (hl),a
        dec hl
        dec hl
        ld (hl),a
        inc hl                      ; OH_LOOP - не за концом
        cp (hl)
        jr nc,.ok
        ld (hl),a
.ok     jp Ed_Clamp

    ASSERT INS_ROWS_MAX == ORN_ROWS_MAX

; Строка end+1 = строка end
Row_Copy_Last
        call Iv_End
        push af
        call Iv_Row_Addr
        pop af
        push hl
        inc a
        call Iv_Row_Addr
        ex de,hl
        pop hl
        call Row_Size
        ldir
        ret

; BC - байт в строке режима
Row_Size
        ld bc,INS_ROW_SIZE
        ld a,(Iv_Mode)
        or a
        ret z
        ld bc,ORN_ROW_SIZE
        ret

Loop_Dn call Iv_Block
        inc hl
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
Loop_Up call Iv_Block
        inc hl
        ld a,(hl)
        inc hl
        cp (hl)                     ; не дальше конца
        ret nc
        dec hl
        inc (hl)
        ret

;-------- Clear: одна строка (инструмент - "тон, громкость 15", орнамент - нули)
Iv_Clear
        call Iv_Block
        xor a
        ld (hl),a                   ; длина 1, цикл 0
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        push hl
        pop ix
        call Row_Default
        jp Ed_Clamp

; Строка IX - пустая строка режима
Row_Default
        ld a,(Iv_Mode)
        or a
        jr nz,.orn
        ld (ix+IR_NOISE),1<<IRB_OFF ; шум выключен
        ld (ix+IR_TONE),0           ; тон 0
        ld (ix+IR_TONE+1),0
        ld (ix+IR_VOL),15           ; громкость 15
        ld (ix+IR_ENV),0
        ret
.orn    ld (ix+OR_NOISE),0
        ld (ix+OR_NOTE),0
        ret

;-------- Unloop: в конце - строка "тишина" (у орнамента - без смещения), цикл на ней
Iv_Unloop
        call Iv_End
        cp INS_ROWS_MAX-1
        ret nc
        call Len_Up                 ; новая строка
        call Iv_End
        call Iv_Row_Addr
        push hl
        pop ix
        call Row_Default
        ld a,(Iv_Mode)
        or a
        jr nz,.loop
        ld (ix+IR_TONE+1),1<<IRB_OFF ; тон выключен, громкость 0
        ld (ix+IR_VOL),0
.loop   call Iv_End
        call Iv_Block
        inc hl
        ld (hl),a
        ret

;-------- Copy / Paste: блок целиком через буфер
Iv_Copy call Iv_Block
        ld de,Iv_Clip
        call Block_Size
        ldir
        ld a,(Iv_Mode)
        inc a
        ld (Iv_Clip_Mode),a
        ret
Iv_Paste
        ld a,(Iv_Mode)              ; буфер - этого режима
        inc a
        ld hl,Iv_Clip_Mode
        cp (hl)
        ret nz
        call Iv_Block
        ex de,hl
        ld hl,Iv_Clip
        call Block_Size
        ldir
        jp Ed_Clamp

; BC - размер блока режима
Block_Size
        ld bc,INS_BLOCK
        ld a,(Iv_Mode)
        or a
        ret z
        ld bc,ORN_BLOCK
        ret

;-------- Clone: копия в первый свободный номер, переход на него.
; Свободный - одна строка, она пустая (как после Clear), имени нет
Iv_Clone
        call Iv_Count
        ld b,a
        ld c,0
.f      ld a,c
        ld hl,Iv_Num
        cp (hl)
        jr z,.n
        push bc
        call Iv_Free
        pop bc
        jr z,.got
.n      inc c
        djnz .f
        ret                         ; свободных нет
.got    ld a,c                      ; текущий -> в свободный C
        push af
        call Iv_Addr
        push hl
        call Iv_Block
        pop de
        call Block_Size
        ldir
        pop af
        ld (Iv_Num),a
        jp Iv_Select

; Номер A свободен? Z - да. Портит всё, кроме C
Iv_Free
        call Iv_Addr
        push hl
        pop ix
        ld a,(ix+OH_END)
        or (ix+OH_LOOP)
        ret nz
        ld de,Ins_Empty
        ld b,INS_ROW_SIZE
        ld a,(Iv_Mode)
        or a
        jr z,.cmp
        ld de,Orn_Empty
        ld b,ORN_ROW_SIZE
.cmp    push ix                     ; строка 0
        pop hl
        inc hl
        inc hl
        inc hl
.c      ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        djnz .c
        push ix                     ; имя пустое
        pop hl
        ld de,INS_NAME
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld de,ORN_NAME
        add hl,de
        ld a,(hl)
        or a
        ret
Ins_Empty       db 1<<IRB_OFF,0,0,15,0
Orn_Empty       db 0,0

; =========================================================================
; ТЕКСТЫ
; =========================================================================
Txt_Instruments db "Instruments",0
Txt_Ornaments   db "Ornaments",0
Txt_Library     db "Library",0
Txt_Name        db "Name",0
Txt_Len         db "Len",0
Txt_Loop        db "Loop",0
Txt_Caps_Ins    db "Rw TNE Tone  Ns  Env  VsR Volume",0
Txt_Caps_Orn    db "Rw Note Ns  Offset",0
Txt_Clone       db " Clone ",0
Txt_Copy        db " Copy ",0
Txt_Paste       db " Paste ",0
Txt_Clear       db " Clear ",0
Txt_Unloop      db " Unloop ",0
Txt_Prev        db " < ",0
Txt_Next        db " > ",0

    ENDMODULE

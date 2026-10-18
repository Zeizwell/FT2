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
ER_ROWS         equ 22              ; строк на экране (ниже - проба)
ER_LOOP_X       equ 22              ; L
ER_NUM_X        equ 23              ; номер строки
ER_DATA_X       equ 26              ; данные
BAR_X           equ 49              ; инструмент: полоса громкости (15)
ER_INS_X        equ 65              ; иконки строки: + вставить (копию под ней), x удалить
ER_DEL_X        equ 67
    ASSERT BAR_X+15 < ER_INS_X && ER_DEL_X < ED_IN_X+ED_IN_W
OB_X            equ 36              ; орнамент: полоса смещения ноты
OB_MID          equ 52              ;   её середина (смещение 0), видно ±16
OB_HALF         equ 16

; --- проба ноты (низ редактора): ▶ нота  Oct  Orn/Ins  Vol  Env
SEP_Y           equ ER_ROW0+ER_ROWS ; разделитель ├──┤
PV_Y            equ SEP_Y+1         ; строка пробы
    ASSERT PV_Y == TL_LAST-2
PV_PLAY         equ 22              ; ▶ (2 знака)
PV_NOTE         equ 25              ; нота (3 знака)
PV_OCT          equ 29              ; подписи; [-] - +3, значение - +5, [+] - +6
PV_ORN          equ 38
PV_VOL          equ 47
PV_ENV          equ 56

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
KD_HEX          equ 10              ; FX: hex-цифра байта строки: вес #10 / #01
KD_MIX          equ 11              ; FX: Mix - выкл -> SID -> Sync
KD_PCT          equ 12              ; FX: скважность ШИМ (полубайт, %): hex-цифра, +/- - шаг
KD_UDEC         equ 13              ; FX: байт 0..параметр, десятичный: цифры, +/- - шаг
KD_SDEC         equ 14              ; FX: байт со знаком, десятичный: цифры, +/- - знак
CL_SIZE         equ 4               ; колонка: экран, вид, байт, параметр

; --- FX: подвкладки Mix / FM / Env FM (строка между кнопками и заголовками колонок)
SUB_Y           equ IV_TOP+4
SUB_MIX_X       equ 23              ; " Mix "
SUB_FM_X        equ 29              ; " FM "
SUB_EFM_X       equ 34              ; " Env FM "
SW_L            equ 43              ; свип ШИМ на весь FX: "Sw" форма, "St" [-]фаза%[+], "Kp"
SW_V            equ 46
ST_L            equ 50
ST_M            equ 53
ST_V            equ 55
ST_P            equ 59
KP_X            equ 62
    ASSERT KP_X+2 < ED_X+ED_W-1
    ASSERT SUB_Y == BT_Y+1 && SUB_Y+1 == CAP_Y
; --- FX (режим 2): номер FX инструмента - на верхней рамке редактора (режим Instr)
FXN_L           equ 52              ; "FX" [-]nn[+]
FXN_M           equ 55
FXN_V           equ 58
FXN_P           equ 61
    ASSERT FXN_P+2 < ED_X+ED_W-1

; клавиши (KEY_*) и действия (ACT_*) - в sdk/plugin.asm
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
        ld a,(Iv_Mode)              ; FX - макет: клавиши редактору не отдаём
        cp 2
        call nz,Iv_Keys
        call Fld_Update
        ld a,(Iv_Exit)              ; другая вкладка - выходим в коре
        or a
        jr nz,Iv_Leave
        ld a,(Prv_Key)              ; проба с клавиатуры: отпустили - тишина
        or a
        call nz,Prv_Check
        ld a,(Iv_Dirty)
        or a
        call nz,Iv_Draw
        ld a,(Iv_Mode)              ; FX - макет: кнопок и иконок редактора нет
        cp 2
        jr z,Iv_Loop
        call Iv_Buttons             ; кнопки - каждый кадр (под мышью - подсветка)
        call Er_Icons_All           ; иконки строк - так же
        call Prv_Btn                ; ▶ - горит, пока звучит проба
        jr Iv_Loop

;-------- Выход в коре (страница следующей тулзы - уже в SV_TOOL)
Iv_Leave
        xor a
        ld (Iv_Exit),a
        ld a,(Prv_Key)              ; держали ноту пробы - тишина
        or a
        call nz,Prv_Stop
        call Tool_Clear             ; экран - под вид паттерна
        RESTPAGE2
        RESTPAGE3
        ret

; --- состояние
Iv_Page         db 0                ; страница инструментов и орнаментов трека (FX - следующая)
Iv_Mode         db 0                ; 0 - инструменты, 1 - орнаменты, 2 - FX
Iv_Exit         db 0                ; 1 - выйти в коре
Iv_Dirty        db 0                ; 1 - перерисовать экран
Iv_Num          db 0                ; текущий номер (0.. = номер 1..) в этом режиме
Iv_Nums         db 0,0,0            ; запомненный номер каждого режима
Fx_Sub          db 0                ; FX: подвкладка 0 - Mix, 1 - FM, 2 - Env FM
Iv_LTop         db 0                ; первая строка списка
Ed_Row          db 0                ; курсор: строка
Ed_Col          db 0                ;   колонка (номер в таблице колонок)
Ed_Top          db 0                ; первая видимая строка
Iv_Clip_Mode    db 0                ; буфер Copy: 0 - пуст, иначе режим+1
Iv_Clip         ds FX_BLOCK         ; самый большой блок
    ASSERT FX_BLOCK >= INS_BLOCK && FX_BLOCK >= ORN_BLOCK

;-------- Режим A (0 - Instr, 1 - Orn, 2 - FX): номер этого режима, страница в окне 2, экран заново
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
        ld a,(Iv_Page)              ; окно 2: FX - страница за инструментами
        ld b,a
        ld a,(Iv_Mode)
        cp 2
        ld a,b
        jr nz,$+3
        inc a
        SWAPPAGE2 a
        xor a
        ld (Iv_LTop),a
        ld (Ed_Col),a
        call Iv_Head
        call Tool_Clear
        call Iv_Frames              ; рамки и заголовки колонок - один раз,
        call Iv_Draw_Caps           ;   дальше только содержимое
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

;-------- A - сколько номеров в режиме (32 / 16 / 32)
Iv_Count
        ld a,(Iv_Mode)
        or a
        ld a,SAMPLES_MAX
        ret z
        ld a,(Iv_Mode)
        dec a
        ld a,ORNAMENTS_MAX
        ret z
        ld a,FXS_MAX
        ret

;-------- A - номер (0..) -> HL - его блок. Портит A, DE
Iv_Addr
        ld l,a
        ld a,(Iv_Mode)
        cp 2
        jr z,.fx
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
.fx     ld h,0                      ; FX: #8000 + n*448 = n*512 - n*64
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h                      ; DE - n*64
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl                   ; n*512
        or a
        sbc hl,de
        set 7,h
        ret
    ASSERT FX_BLOCK == 512-64

;-------- HL - блок текущего. Портит A, DE
Iv_Block
        ld a,(Iv_Num)
        jr Iv_Addr

;-------- A - строка -> HL - она в текущем блоке (строка - Row_Size байт). Портит A, DE
Iv_Row_Addr
        push bc
        push af
        call Iv_Block
        pop af
        ld e,a
        ld d,0
        inc hl                      ; OH_ROWS
        inc hl
        inc hl
        call Row_Size
.m      add hl,de                   ; строка * размер
        dec c
        jr nz,.m
        pop bc
        ret

;-------- DE - смещение имени в блоке режима. Портит A
Name_Ofs
        ld de,INS_NAME
        ld a,(Iv_Mode)
        or a
        ret z
        ld de,ORN_NAME
        dec a
        ret z
        ld de,FX_NAME
        ret

;-------- HL - имя текущего (16 знаков). Портит A, DE
Iv_Name_Addr
        call Iv_Block
        call Name_Ofs
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
        dec a
        ld hl,Orn_Cols
        ld b,ORN_COLS
        ret z
        ld a,(Fx_Sub)               ; FX - по подвкладке
        or a
        ld hl,Fx_Cols_Mix
        ld b,FX_MIX_COLS
        ret z
        dec a
        ld hl,Fx_Cols_Fm
        ld b,FX_FM_COLS
        ret z
        ld hl,Fx_Cols_Efm
        ld b,FX_FM_COLS
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
; FX, подвкладка Mix: Mix, ШИМ min и max (%), свип, полутоны, детюн, таблица, L (за тоном)
Fx_Cols_Mix
        db 26, KD_MIX,   0, 0
        db 32, KD_PCT,   FR_PWM, #01                ; min
        db 37, KD_PCT,   FR_PWM, #10                ; max
        db 42, KD_UDEC,  FR_SWEEP, 255
        db 47, KD_SDEC,  FR_MIX+FE_SEMI, 0
        db 52, KD_SDEC,  FR_MIX+FE_RAW, 0
        db 55, KD_UDEC,  FR_MIX+FE_TAB, TAB_MAX
        db 57, KD_BIT,   FR_FLAGS, 1<<FXB_FOLLOW
FX_MIX_COLS     equ ($-Fx_Cols_Mix)/CL_SIZE
; FX, подвкладки FM и Env FM: вкл, полутоны, детюн, таблица, шаги (semi / per)
Fx_Cols_Fm
        db 26, KD_BIT,   FR_FLAGS, 1<<FXB_FM
        db 32, KD_SDEC,  FR_FM+FE_SEMI, 0
        db 37, KD_SDEC,  FR_FM+FE_RAW, 0
        db 40, KD_UDEC,  FR_FM+FE_TAB, TAB_MAX
        db 42, KD_BIT,   FR_FLAGS, 1<<FXB_FMPER
FX_FM_COLS      equ ($-Fx_Cols_Fm)/CL_SIZE
Fx_Cols_Efm
        db 26, KD_BIT,   FR_FLAGS, 1<<FXB_EFM
        db 32, KD_SDEC,  FR_EFM+FE_SEMI, 0
        db 37, KD_SDEC,  FR_EFM+FE_RAW, 0
        db 40, KD_UDEC,  FR_EFM+FE_TAB, TAB_MAX
        db 42, KD_BIT,   FR_FLAGS, 1<<FXB_EFMPER
    ASSERT ($-Fx_Cols_Efm)/CL_SIZE == FX_FM_COLS

; =========================================================================
; ЭКРАН
; =========================================================================
;-------- Шапка - как есть, без подсветки вкладки (и так видно, что это редактор)
Iv_Head
        ld b,0
        jp Tool_Head

;-------- Весь экран тулзы
Iv_Draw
        xor a
        ld (Iv_Dirty),a
        ld a,(Iv_Mode)              ; FX - пока пробный макет (srs/fxmaket.asm)
        cp 2
        jp z,Fe_Draw
        call Iv_Draw_List
        call Iv_Draw_Top
        call Fx_Subs
        call Sw_Draw
        call Prv_Draw
        jp Iv_Draw_Rows

;-------- FX: подвкладки Mix / FM / Env FM, текущая - цветом курсора
Fx_Subs
        ld a,(Iv_Mode)
        cp 2
        ret nz
        ld de,SUB_MIX_X+256*(IV_SCR_H+SUB_Y)
        ld hl,Txt_Sub_Mix
        xor a
        call .one
        ld e,SUB_FM_X
        ld hl,Txt_Sub_Fm
        ld a,1
        call .one
        ld e,SUB_EFM_X
        ld hl,Txt_Sub_Efm
        ld a,2
.one    ld b,a
        ld a,(Fx_Sub)
        cp b
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        jp PutStr

;-------- FX: свип ШИМ на весь FX - форма, стартовая фаза, "не сбрасывать на новой ноте"
Sw_Draw
        ld a,(Iv_Mode)
        cp 2
        ret nz
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld de,SW_L+256*(IV_SCR_H+SUB_Y)
        ld hl,Txt_Sw
        call PutStr
        ld e,ST_L
        ld hl,Txt_St
        call PutStr
        call Sw_Addr                ; форма
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld a,(hl)
        and 7
        cp 5
        jr c,$+4
        ld a,5
        ld b,a
        add a,a
        add a,b
        push hl
        ld hl,Sw_Names
        call Hl_Add_A
        ld de,SW_V+256*(IV_SCR_H+SUB_Y)
        ld b,3
.n      ld a,(hl)
        call PutCh
        inc hl
        djnz .n
        pop hl
        inc hl                      ; фаза: %
        ld a,(hl)
        push hl
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl                   ; *4
        push hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; *32
        ld d,h
        ld e,l
        add hl,hl                   ; *64
        add hl,de
        pop de
        add hl,de                   ; *100
        ld a,h                      ; /256
        ld de,ST_V+256*(IV_SCR_H+SUB_Y)
        call Put_Dec3
        ld a,'%'
        call PutCh
        pop hl
        dec hl                      ; Kp - не сбрасывать на новой ноте
        bit 3,(hl)
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        ld de,KP_X+256*(IV_SCR_H+SUB_Y)
        ld hl,Txt_Kp
        jp PutStr
Sw_Names        db "TriSinUp Dn Sqr???"

; HL - байт формы свипа текущего FX (за ним - фаза)
Sw_Addr
        call Iv_Block
        ld de,FX_SWEEP
        add hl,de
        ret

;-------- Клики: форма по кругу, фаза -/+ (шаг 16 = 6%), Kp
Iv_SwEv
        cp EV_CLICK
        ret nz
        ld a,(Iv_Mode)
        cp 2
        ret nz
        call Sw_Addr
        ld a,(ix+FLD_PARAM)
        or a
        jr nz,.st
        ld a,(hl)                   ; форма: 0..4 по кругу, бит 3 - как был
        ld b,a
        and 7
        inc a
        cp 5
        jr c,$+3
        xor a
        ld c,a
        ld a,b
        and %11111000
        or c
        ld (hl),a
        jp Iv_Changed
.st     cp 3
        jr z,.kp
        inc hl                      ; фаза: 1 - минус, 2 - плюс
        cp 1
        ld a,(hl)
        jr nz,.pl
        sub 16
        jr nc,$+3
        xor a
        jr .sv
.pl     add a,16
        jr nc,$+4
        ld a,#F0
.sv     ld (hl),a
        jp Iv_Changed
.kp     ld a,(hl)
        xor 8
        ld (hl),a
        jp Iv_Changed

;-------- Клик по подвкладке FX
Iv_SubEv
        cp EV_CLICK
        ret nz
        ld a,(Iv_Mode)
        cp 2
        ret nz
        ld a,(ix+FLD_PARAM)
        ld (Fx_Sub),a
        call Iv_Draw_Caps
        call Ed_Clamp
        jp Iv_Changed

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
        jr z,.ttl
        ld hl,Txt_Ornaments
        dec a
        jr z,.ttl
        ld hl,Txt_Fx
.ttl    call PutStr
        ld de,LB_X+2+256*(IV_SCR_H+IV_TOP)
        ld hl,Txt_Library
        call PutStr
        jp Prv_Frame

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
        call Name_Ofs
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
        call PutHex2
        ld a,(Iv_Mode)              ; инструмент: номер его FX - на рамке (0 - без FX)
        or a
        ret nz
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FXN_L+256*(IV_SCR_H+IV_TOP)
        ld hl,Txt_Fx
        call PutStr
        call Fx_Ref
        ld a,(hl)
        ld de,FXN_V+256*(IV_SCR_H+IV_TOP)
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
        jp z,PutStr
        ld hl,Txt_Caps_Orn
        dec a
        jp z,PutStr
        ld a,(Fx_Sub)               ; FX - по подвкладке
        or a
        ld hl,Txt_Caps_Mix
        jp z,PutStr
        ld hl,Txt_Caps_Fm
        jp PutStr

;-------- Строки: ER_ROWS с Ed_Top, за концом - пусто; потом курсор
Er_Idx          db 0
Iv_Draw_Rows
        ld a,(Ed_Top)
        ld (Er_Idx),a
        ld d,IV_SCR_H+ER_ROW0
.row    push de
        call Iv_End
        ld hl,Er_Idx
        cp (hl)
        jr nc,.data
        pop de                      ; за концом - пусто
        push de
        call Er_Blank
        jr .next
.data   pop de
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
        jr .ico
.orn    dec a
        jr nz,.fx
        call Or_Body
        jr .ico
.fx     call Fx_Body
.ico    pop de                      ; иконки вставить / удалить
        push de
        call Er_Icons
.next   pop de
        ld hl,Er_Idx
        inc (hl)
        inc d
        ld a,d
        cp IV_SCR_H+ER_ROW0+ER_ROWS
        jr c,.row
        jp Er_Cursor

;-------- Иконки всех видимых строк с данными - каждый кадр (под мышью - подсветка)
Er_Icons_All
        call Iv_End
        ld hl,Ed_Top
        sub (hl)                    ; строк с данными на экране - 1
        ret c
        cp ER_ROWS
        jr c,$+4
        ld a,ER_ROWS-1
        inc a
        ld b,a
        ld d,IV_SCR_H+ER_ROW0
.r      push bc
        call Er_Icons
        pop bc
        inc d
        djnz .r
        ret

; Иконки строки D: + (вставить) и крестик (удалить). Портит B, C, E
Er_Icons
        ld e,ER_INS_X
        ld a,'+'
        call Er_Icon
        ld e,ER_DEL_X
        ld a,GLYPH_DEL
; Значок A в колонку E строки D: под мышью - CLR_HOVER
Er_Icon
        ld b,a
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld a,(SV_MOUSE_COL)
        cp e
        jr nz,.put
        ld a,(SV_MOUSE_ROW)
        add a,IV_SCR_H
        cp d
        jr nz,.put
        ld a,(THEME_ATTR+CLR_HOVER)
        ld c,a
.put    ld a,b
        jp PutCh

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
        ld a,(ix+IR_VOL)            ; клетки - громкость, остальное до 15 - пробелы
        and #0F
        ld b,a
        ld a,15
        sub b
        ld l,a
        inc b
        jr .bn
.bar    ld a,GLYPH_VOL              ; клетка с зазором
        call PutCh
.bn     djnz .bar
        ld b,l
        inc b
        jr .sn
.sp     ld a,' '
        call PutCh
.sn     djnz .sp
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

;-------- Строка FX по подвкладке: IX - строка, DE - экран (колонка ER_DATA_X)
Fx_Body
        push de                     ; сначала - пробелы до иконок (у подвкладок разные колонки)
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld b,ER_INS_X-ER_DATA_X
.cl     ld a,' '
        call PutCh
        djnz .cl
        pop de
        ld a,(Fx_Sub)
        or a
        jr nz,.fm
        ld a,(THEME_ATTR+CLR_INSTR) ; Mix: --- / SID / BUZ
        ld c,a
        ld a,(ix+FR_FLAGS)
        and FXF_MIX
        ld b,a
        add a,a
        add a,b
        ld hl,Mix_Words
        call Hl_Add_A
        ld b,3
.w      ld a,(hl)
        call PutCh
        inc hl
        djnz .w
        ld a,(THEME_ATTR+CLR_PARAM) ; ШИМ min, max - проценты
        ld c,a
        ld e,30
        ld a,(ix+FR_PWM)
        and #0F
        call Put_Pct
        ld e,35
        ld a,(ix+FR_PWM)
        rrca
        rrca
        rrca
        rrca
        and #0F
        call Put_Pct
        ld e,40                     ; свип
        ld a,(ix+FR_SWEEP)
        call Put_Dec3
        ld a,(THEME_ATTR+CLR_VOLUME) ; полутоны, детюн, таблица
        ld c,a
        ld e,44
        ld a,FR_MIX
        call Fx_Triple
        ld a,(THEME_ATTR+CLR_INSTR) ; L - таймеры за тоном
        ld c,a
        ld e,57
        ld a,(ix+FR_FLAGS)
        ld b,1<<FXB_FOLLOW
        ld hl,'L'*256+'.'
        jp Put_If
.fm     dec a                       ; FM / Env FM: вкл, полутоны, детюн, таблица, шаги
        ld a,FR_FM
        ld b,1<<FXB_FM|1<<FXB_FMPER
        jr z,.f
        ld a,FR_EFM
        ld b,1<<FXB_EFM|1<<FXB_EFMPER
.f      ld (Fb_Ofs),a
        ld a,b
        ld (Fb_Bits),a
        ld a,(THEME_ATTR+CLR_INSTR)
        ld c,a
        ld a,(ix+FR_FLAGS)          ; вкл - младший бит пары
        ld hl,Fb_Bits
        and (hl)
        ld b,a
        ld a,(hl)
        and ~(1<<FXB_FMPER|1<<FXB_EFMPER)
        and b
        ld hl,Txt_On
        jr nz,$+5
        ld hl,Txt_Off
        call PutStr
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld e,29
        ld a,(Fb_Ofs)
        call Fx_Triple3
        ld a,(THEME_ATTR+CLR_PARAM) ; шаги таблицы: полутоны / период
        ld c,a
        ld e,42
        ld a,(ix+FR_FLAGS)
        ld hl,Fb_Bits
        and (hl)
        and 1<<FXB_FMPER|1<<FXB_EFMPER
        ld hl,Txt_Semi
        jp z,PutStr
        ld hl,Txt_Per
        jp PutStr
Fb_Ofs          db 0
Fb_Bits         db 0
Mix_Words       db "---SIDBUZ???"
Txt_On          db "on",0
Txt_Off         db "--",0
Txt_Semi        db "semi",0
Txt_Per         db "per ",0

; Mix: A - смещение тройки, E - колонка полутонов: "+12   +1 01" (полутоны 44..47, детюн 49..52,
; таблица 54..55)
Fx_Triple
        push ix
        pop hl
        call Hl_Add_A
        ld a,(hl)
        push hl
        call Put_SDec
        inc e
        pop hl
        inc hl
        ld a,(hl)
        push hl
        call Put_SDec
        inc e
        pop hl
        inc hl
        ld a,(hl)
        jp Dec2
; FM: то же с колонки 29: полутоны 29..32, детюн 34..37, таблица 39..40
Fx_Triple3 equ Fx_Triple

;-------- Скважность: полубайт A (16 ступеней) -> "nn%" (3 знака и %)
Put_Pct
        ld hl,Pct_T
        call Hl_Add_A
        ld a,(hl)
        call Put_Dec3
        ld a,'%'
        jp PutCh
Pct_T   db 0,3,7,10,13,17,20,23,27,30,33,37,40,43,47,50   ; n*50/15: d и 100-d звучат одинаково

;-------- A - 0..255 -> 3 знака, справа (пробелы слева). Портит HL, B
Put_Dec3
        call Fmt_Dec
        ld hl,Dec_Buf
        ld b,3
.c      ld a,(hl)
        call PutCh
        inc hl
        djnz .c
        ret

;-------- A - байт со знаком -> 4 знака: знак у числа, справа ("  +7", " -12"; 0 - "   0")
Put_SDec
        ld l,a
        or a
        ld h,' '
        jr z,.m
        ld h,'+'
        jp p,.m
        ld h,'-'
        neg
        ld l,a
.m      ld a,l
        push hl
        call Fmt_Dec                ; Dec_Buf: 3 знака
        pop hl
        ld a,' '                    ; знак - перед первой цифрой
        ld (Dec_Buf-1),a
        push de
        ld de,Dec_Buf-1
.f      inc de
        ld a,(de)
        cp ' '
        jr z,.f
        dec de
        ld a,h
        ld (de),a
        pop de
        ld hl,Dec_Buf-1
        ld b,4
.c      ld a,(hl)
        call PutCh
        inc hl
        djnz .c
        ret

;-------- A - 0..255 -> Dec_Buf: 3 знака, пробелы слева (хотя бы одна цифра)
        db 0                        ; место под знак (Put_SDec)
Dec_Buf ds 3
Fmt_Dec
        push bc
        ld hl,Dec_Buf
        ld b,'0'-1                  ; сотни
.h      inc b
        sub 100
        jr nc,.h
        add a,100
        ld c,a
        ld a,b
        cp '0'
        jr nz,$+4
        ld a,' '
        ld (hl),a
        inc hl
        ld a,c
        ld b,'0'-1                  ; десятки
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        cp '0'
        jr nz,.tp
        dec hl                      ; ноль десятков: пробел, если сотен нет
        ld a,(hl)
        inc hl
        cp ' '
        ld a,'0'
        jr nz,.tp
        ld a,' '
.tp     ld (hl),a
        inc hl
        ld (hl),c
        pop bc
        ret

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
        call Bg_List
        ld a,(Iv_Mode)              ; номер FX - только у инструмента
        or a
        ld hl,Btn_Fx_Glyphs
        call z,Bg_List
        ld a,(Iv_Mode)              ; фаза свипа -/+ - только у FX
        cp 2
        ld hl,Btn_Sw_Glyphs
        call z,Bg_List
        jr Bt_Texts
; значки списка HL (поле; колонка, строка, значок), конец - 0
Bg_List
.g      ld e,(hl)                   ; поле
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        push de
        pop ix
        ld e,(hl)                   ; колонка, строка, значок
        inc hl
        ld a,(hl)
        ld (Bg_Row),a
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
        ld a,(Bg_Row)
        add a,IV_SCR_H
        ld d,a
        ld a,b
        call PutCh
        ld a,b
        inc a
        call PutCh
        pop hl
        jr .g
; надписи кнопок: под мышью - подсветка, держат - нажата
Bt_Texts
        ld hl,Btn_Texts
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

Bg_Row          db 0
Btn_Glyphs                          ; поле; колонка, строка, значок
        dw F_LenM
        db LEN_M, NM_Y, GLYPH_BTN_MINUS
        dw F_LenP
        db LEN_P, NM_Y, GLYPH_BTN_PLUS
        dw F_LoopM
        db LOOP_M, NM_Y, GLYPH_BTN_MINUS
        dw F_LoopP
        db LOOP_P, NM_Y, GLYPH_BTN_PLUS
        dw F_OctM
        db PV_OCT+3, PV_Y, GLYPH_BTN_MINUS
        dw F_OctP
        db PV_OCT+6, PV_Y, GLYPH_BTN_PLUS
        dw F_OrnM
        db PV_ORN+3, PV_Y, GLYPH_BTN_MINUS
        dw F_OrnP
        db PV_ORN+6, PV_Y, GLYPH_BTN_PLUS
        dw F_VolM
        db PV_VOL+3, PV_Y, GLYPH_BTN_MINUS
        dw F_VolP
        db PV_VOL+6, PV_Y, GLYPH_BTN_PLUS
        dw F_EnvM
        db PV_ENV+3, PV_Y, GLYPH_BTN_MINUS
        dw F_EnvP
        db PV_ENV+6, PV_Y, GLYPH_BTN_PLUS
        dw 0
Btn_Sw_Glyphs
        dw F_SwM
        db ST_M, SUB_Y, GLYPH_BTN_MINUS
        dw F_SwP
        db ST_P, SUB_Y, GLYPH_BTN_PLUS
        dw 0
Btn_Fx_Glyphs
        dw F_FxM
        db FXN_M, IV_TOP, GLYPH_BTN_MINUS
        dw F_FxP
        db FXN_P, IV_TOP, GLYPH_BTN_PLUS
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
        IV_FIELD patview.HD_TAB_INSTR,patview.HD_TABS_Y,5,1, FF_HAND, Iv_TabEv, 0   ; Instr
        IV_FIELD patview.HD_TAB_ORN,  patview.HD_TABS_Y,3,1, FF_HAND, Iv_TabEv, 1   ; Orn
        IV_FIELD patview.HD_TAB_FX,   patview.HD_TABS_Y,2,1, FF_HAND, Iv_TabEv, 6   ; FX
        IV_FIELD patview.HD_TAB_DISK, patview.HD_TABS_Y,4,1, FF_HAND, Iv_TabEv, 2   ; Disk
        IV_FIELD patview.HD_TAB_SETUP,patview.HD_TABS_Y,5,1, FF_HAND, Iv_TabEv, 4   ; Setup
        IV_FIELD patview.HD_HELP_X,   patview.HD_TABS_Y,4,1, FF_HAND, Iv_TabEv, 5   ; Help
        IV_FIELD patview.HD_ABOUT_X,  patview.HD_TABS_Y,5,1, FF_HAND, Win_AboutEv, 0  ; About
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
F_FxM   IV_FIELD FXN_M,IV_TOP,2,1, FF_HAND, Iv_BtnEv, 11              ; FX инструмента -
F_FxP   IV_FIELD FXN_P,IV_TOP,2,1, FF_HAND, Iv_BtnEv, 12              ;                +
F_SubM  IV_FIELD SUB_MIX_X,SUB_Y,5,1, FF_HAND, Iv_SubEv, 0           ; FX: Mix
F_SubF  IV_FIELD SUB_FM_X,SUB_Y,4,1, FF_HAND, Iv_SubEv, 1            ;     FM
F_SubE  IV_FIELD SUB_EFM_X,SUB_Y,8,1, FF_HAND, Iv_SubEv, 2           ;     Env FM
F_SwShp IV_FIELD SW_V,SUB_Y,3,1, FF_HAND, Iv_SwEv, 0                ; FX: форма свипа
F_SwM   IV_FIELD ST_M,SUB_Y,2,1, FF_HAND, Iv_SwEv, 1                ;     фаза -
F_SwP   IV_FIELD ST_P,SUB_Y,2,1, FF_HAND, Iv_SwEv, 2                ;          +
F_SwKp  IV_FIELD KP_X,SUB_Y,2,1, FF_HAND, Iv_SwEv, 3                ;     Kp
F_Edit  IV_FIELD ED_IN_X,ER_ROW0,ED_IN_W,ER_ROWS, FF_FOCUS, Iv_EditEv, 0 ; строки
F_Play  IV_FIELD PV_PLAY,PV_Y,2,1, FF_HAND, Prv_PlayEv, 0             ; ▶ - пока держат
F_OctM  IV_FIELD PV_OCT+3,PV_Y,2,1, FF_HAND, Prv_BtnEv, 0             ; Oct -
F_OctP  IV_FIELD PV_OCT+6,PV_Y,2,1, FF_HAND, Prv_BtnEv, 1             ;     +
F_OrnM  IV_FIELD PV_ORN+3,PV_Y,2,1, FF_HAND, Prv_BtnEv, 2             ; Orn / Ins -
F_OrnP  IV_FIELD PV_ORN+6,PV_Y,2,1, FF_HAND, Prv_BtnEv, 3             ;           +
F_VolM  IV_FIELD PV_VOL+3,PV_Y,2,1, FF_HAND, Prv_BtnEv, 4             ; Vol -
F_VolP  IV_FIELD PV_VOL+6,PV_Y,2,1, FF_HAND, Prv_BtnEv, 5             ;     +
F_EnvM  IV_FIELD PV_ENV+3,PV_Y,2,1, FF_HAND, Prv_BtnEv, 6             ; Env -
F_EnvP  IV_FIELD PV_ENV+6,PV_Y,2,1, FF_HAND, Prv_BtnEv, 7             ;     +
F_Test  IV_FIELD ED_IN_X,PV_Y,ED_IN_W,1, FF_FOCUS, Prv_KeyEv, 0       ; строка пробы: пианино
        db FLD_END

;-------- Шапка: Instr / Orn - режим, Disk - тулза диска, остальное - вид паттерна
Iv_TabEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        cp 6                        ; FX - режим 2
        jr z,.fx
        cp 2
        jr nc,.out
.mode   ld hl,Iv_Mode               ; тот же режим - ничего
        cp (hl)
        ret z
        call Iv_Set_Mode
        ld hl,F_Edit
        jp Fld_Set_Focus
.fx     ld a,2
        jr .mode
.out    ld b,PAGE_TOOL_DISK
        jr z,.go
        ld b,PAGE_TOOL_PATVIEW
        cp 4
        jr c,.go
        sub 4                       ; 4 - Setup (0), 5 - Help (OPT_HELP)
        ld (SV_TOOL_ARG),a
        ld b,PAGE_TOOL_OPT
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
        dw Fx_Dn, Fx_Up

;-------- Номер FX инструмента: - / + (0 - без FX). Только в режиме Instr
Fx_Dn   call Fx_Ref
        ret nz
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
Fx_Up   call Fx_Ref
        ret nz
        ld a,(hl)
        cp FXS_MAX
        ret nc
        inc (hl)
        ret
; HL - номер FX текущего инструмента; NZ - не режим Instr
Fx_Ref  call Iv_Block
        ld de,INS_FX
        add hl,de
        ld a,(Iv_Mode)
        or a
        ret

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
        cp ER_INS_X                 ; иконки: вставить / удалить строку
        jr z,.ins
        cp ER_DEL_X
        jr z,.del
        cp ER_NUM_X+2               ; колонка L и номер строки - цикл сюда
        jr nc,.col
        call Iv_Block
        inc hl
        ld (hl),b
        jp Iv_Changed
.col    ld c,a                      ; колонка курсора с такой же колонкой экрана (FX - в поле
        call Iv_Cols                ;   до 4 знаков левее неё)
        ld e,0
.f      ld a,(Iv_Mode)
        cp 2
        ld a,(hl)
        jr nz,.eq
        sub c
        cp 4
        jr c,.hit
        jr .nx
.eq     cp c
        jr z,.hit
.nx
        inc hl
        inc hl
        inc hl
        inc hl
        inc e
        djnz .f
        ld a,(Iv_Mode)              ; инструмент: полоса - громкость
        or a
        jp nz,Iv_Changed
        ld a,c                      ; колонка перед полосой - 0, клетки - 1..15
        sub BAR_X-1
        jp c,Iv_Changed
        cp 16
        jp nc,Iv_Changed
        ld b,a
        call Iv_Cur_Row
        ld a,(ix+IR_VOL)
        and #F0
        or b
        ld (ix+IR_VOL),a
        jp Iv_Changed
.ins    call Row_Ins
        jp Iv_Changed
.del    call Row_Del
        jp Iv_Changed
.hit    ld a,e
        ld (Ed_Col),a
        inc hl                      ; флаг и слайд - переключить сразу
        ld a,(hl)
        cp KD_BIT
        jr z,.tog
        cp KD_SLIDE
        jr z,.tog
        cp KD_MIX
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
        ld hl,(SV_FOCUS)            ; строки -> проба -> имя -> строки
        ld de,F_Edit
        or a
        sbc hl,de
        ld hl,F_Test
        jr z,.set
        ld hl,(SV_FOCUS)
        ld de,F_Test
        or a
        sbc hl,de
        ld hl,F_Name
        jr z,.set
        ld hl,F_Edit
.set    call Fld_Set_Focus
        jr .k

; =========================================================================
; РЕДАКТОР СТРОК
; =========================================================================
;-------- Клавиша B (флаги C) полю строк. Выход: CF - наша
Ed_Key
        ld a,(Iv_Mode)              ; FX: Backspace / Delete в числе - стереть цифру / всё
        cp 2
        jr nz,.k
        ld a,b
        cp KEY_BACK
        jr z,.er
        cp KEY_DEL
        jr nz,.k
.er     push bc
        call Fx_Erase
        pop bc
        jr c,.ok
.k      ld hl,Ed_Keys
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

Ed_Keys db ACT_UP
        dw Ed_Up
        db ACT_DOWN
        dw Ed_Down
        db ACT_LEFT
        dw Ed_Left
        db ACT_RIGHT
        dw Ed_Right
        db ACT_PGUP
        dw Ed_PgUp
        db ACT_PGDN
        dw Ed_PgDn
        db ACT_HOME
        dw Ed_Home
        db ACT_END
        dw Ed_EndK
        db ACT_ENTER
        dw Ed_Enter
        db ACT_INS_TRK              ; вставить / удалить строку (как VT: Insert, Ctrl+I /
        dw Row_Ins                  ;   Backspace, Ctrl+Y)
        db ACT_INS_PAT
        dw Row_Ins
        db ACT_DEL_TRK
        dw Row_Del
        db ACT_DEL_PAT
        dw Row_Del
        db 0

;-------- Enter: нота строки пробы (Prv_Note), пока держат (отпустили - Prv_Check).
; Автоповтор - мимо: нота уже звучит
Ed_Enter
        ld a,(Prv_Key)
        cp KEY_ENTER
        ret z
        ld a,KEY_ENTER
        ld (Prv_Key),a
        ld a,(Prv_Note)
        jp Prv_Play

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
        cp KD_HEX
        jp z,Ty_Hex
        cp KD_PCT
        jp z,Ty_Pct
        cp KD_UDEC
        jp z,Ty_UDec
        cp KD_SDEC
        jp z,Ty_SDec
        or a                        ; остальным цифры не нужны
        ret
.space  ld a,(iy+1)
        cp KD_BIT
        jr z,Ed_Toggle_Ok
        cp KD_SLIDE
        jr z,Ed_Toggle_Ok
        cp KD_MIX
        jr z,Ed_Toggle_Ok
        ld a,1                      ; знак - наоборот
        ld (Ed_Space),a
        jr .sign
.minus  ld b,'-'
        ld a,(iy+1)
        cp KD_PCT
        jp z,Dn_Pct
        cp KD_UDEC
        jp z,Dn_UDec
        cp KD_SLIDE
        jr nz,.sign
        ld a,(ix+IR_VOL)            ; слайд вниз
        or 1<<IRB_SLIDE|1<<IRB_SLIDE_DOWN
        ld (ix+IR_VOL),a
        scf
        ret
.plus   ld b,'+'
        ld a,(iy+1)
        cp KD_PCT
        jp z,Up_Pct
        cp KD_UDEC
        jp z,Up_UDec
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
        cp KD_SDEC
        jp z,Sg_SDec
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
        cp KD_MIX
        jr z,.mix
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
.mix    ld a,(ix+FR_FLAGS)          ; Mix: выкл -> SID -> Sync -> выкл
        ld b,a
        and FXF_MIX
        inc a
        cp FXF_SYNC+1
        jr c,$+3
        xor a
        ld c,a
        ld a,b
        and ~FXF_MIX
        or c
        ld (ix+FR_FLAGS),a
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

;-------- FX: hex-цифра B в байт строки (iy+2), вес (iy+3) - #10 / #01
Ty_Hex  ld a,(iy+2)
        push ix
        pop hl
        call Hl_Add_A
        ld a,(iy+3)
        cp #10
        ld a,(hl)
        jr z,.hi
        and #F0
        or b
        jr .st
.hi     and #0F
        rlc b
        rlc b
        rlc b
        rlc b
        or b
.st     ld (hl),a
        scf
        ret

;-------- FX: стереть в числовом поле курсора: B - Backspace (последнюю цифру) или Delete (всё).
; Выход: CF - поле числовое, стёрли
Fx_Erase
        call Iv_Cur_Row
        call Iv_Cur_Col
        ld a,(iy+1)
        cp KD_PCT
        jr z,.pct
        cp KD_UDEC
        jr z,.dec
        cp KD_SDEC
        jr z,.dec
        or a                        ; не число - не наша
        ret
.pct    xor a                       ; скважность - 0
        jp Ty_Pct.put0
.dec    call Fx_Fld
        ld a,b
        cp KEY_DEL
        jr z,.zero
        ld a,(iy+1)                 ; без знака (свип, таблица): / 10
        cp KD_UDEC
        jr nz,.sgn
        ld a,(hl)
        ld b,-1
.u      inc b
        sub 10
        jr nc,.u
        ld (hl),b
        scf
        ret
.sgn
        ld a,(hl)                   ; Backspace: модуль / 10, знак тот же
        push hl
        call Sign_Get
        ld c,a
        ld a,l
        ld b,-1
.d      inc b
        sub 10
        jr nc,.d
        ld l,b
        ld a,c
        call Byte_Signed
        pop hl
        ld (hl),a
        scf
        ret
.zero   ld (hl),0
        scf
        ret

;-------- FX: HL - байт колонки IY в строке IX
Fx_Fld  ld a,(iy+2)
        push ix
        pop hl
        jp Hl_Add_A

;-------- Скважность: hex-цифра B - полубайт (iy+3: #10 - max, #01 - min); +/- - шаг
Ty_Pct  call Fx_Fld
        ld a,b
        jr .put
.put0   push af
        call Fx_Fld
        pop af
.put    ld b,a                      ; B - полубайт 0..15
        ld a,(iy+3)
        cp #10
        ld a,(hl)
        jr z,.hi
        and #F0
        or b
        jr .st
.hi     and #0F
        rlc b
        rlc b
        rlc b
        rlc b
        or b
.st     ld (hl),a
        scf
        ret
Dn_Pct  call Pct_Get
        or a
        jr z,Fx_Eat
        dec a
        jr Ty_Pct.put
Up_Pct  call Pct_Get
        cp 15
        jr nc,Fx_Eat
        inc a
        jr Ty_Pct.put
; A - полубайт колонки, HL - байт
Pct_Get call Fx_Fld
        ld a,(iy+3)
        cp #10
        ld a,(hl)
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo     and #0F
        ret
Fx_Eat  scf                         ; клавиша наша, менять нечего
        ret

;-------- Байт 0..(iy+3), десятичный: цифра B вдвигается справа (за максимум - начать с неё);
; +/- - шаг
Ty_UDec ld a,b
        cp 10
        ret nc                      ; A..F - не наши
        call Fx_Fld
        push hl
        ld a,(hl)
        call Mod100x10              ; HL = (A mod 100)*10
        ld a,b
        call Hl_Add_A
        ld a,h
        or a
        ld a,l
        pop hl
        jr nz,.new
        cp (iy+3)
        jr c,.st
        jr z,.st
.new    ld a,b
.st     ld (hl),a
        scf
        ret
Dn_UDec call Fx_Fld
        ld a,(hl)
        or a
        jr z,Fx_Eat
        dec (hl)
        scf
        ret
Up_UDec call Fx_Fld
        ld a,(hl)
        cp (iy+3)
        jr nc,Fx_Eat
        inc (hl)
        scf
        ret

;-------- Байт со знаком, десятичный: цифра B вдвигается в модуль (за 127 - начать с неё), знак тот же
Ty_SDec ld a,b
        cp 10
        ret nc
        call Fx_Fld
        push hl
        ld a,(hl)
        call Sign_Get               ; L - модуль, A - знак
        ld c,a
        ld a,l
        call Mod100x10
        ld a,b
        call Hl_Add_A
        ld a,h
        or a
        jr nz,.new
        ld a,l
        cp 128
        jr c,.ok
.new    ld l,b
.ok     ld a,c
        call Byte_Signed
        pop hl
        ld (hl),a
        scf
        ret
Sg_SDec call Fx_Fld
        push hl
        ld a,(hl)
        call Sign_Get
        call Sign_New
        call Byte_Signed
        pop hl
        ld (hl),a
        scf
        ret

; A -> HL = (A mod 100) * 10. Портит A, DE
Mod100x10
        cp 100
        jr c,.m
        sub 100
        jr Mod100x10
.m      ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ret

Ty_Vol  ld a,(ix+IR_VOL)
        and #F0
        or b
        ld (ix+IR_VOL),a
        scf
        ret

Ty_Note ld a,b                      ; десятичная цифра
        cp 10
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
Len_Up  call Rows_Last
        ld b,a
        call Iv_End
        cp b
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

;-------- Вставить: строки курсор..конец - вниз на одну (под курсорной - её копия, как Len +).
; Цикл за курсором - вместе со строками
Row_Ins call Rows_Last
        ld b,a
        call Iv_End
        cp b
        ret nc
        call Row_Size
        ld (Ri_Size),bc
        call Iv_End                 ; Ri_End - за последней строкой
        inc a
        call Iv_Row_Addr
        ld (Ri_End),hl
        ld a,(Ed_Row)
        call Iv_Row_Addr
        ex de,hl
        ld hl,(Ri_End)              ; BC - байт от курсорной до конца
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(Ri_End)              ; с последнего байта - на строку ниже
        dec hl
        ld de,(Ri_Size)
        ex de,hl
        add hl,de
        ex de,hl
        lddr
        call Iv_Block
        inc hl                      ; OH_LOOP: за курсором - +1
        ld a,(Ed_Row)
        cp (hl)
        jr nc,$+3
        inc (hl)
        inc hl
        inc (hl)                    ; OH_END
        ld a,(hl)
        dec hl
        dec hl
        ld (hl),a                   ; OH_LEN - копия
        ret

;-------- Удалить строку курсора: строки ниже - вверх на одну. Одну строку не удаляем.
; Цикл за курсором - вместе со строками, не за концом
Row_Del call Iv_End
        or a
        ret z
        inc a                       ; Ri_End - за последней строкой
        call Iv_Row_Addr
        ld (Ri_End),hl
        ld a,(Ed_Row)               ; источник - строка под курсором
        inc a
        call Iv_Row_Addr
        ld (Ri_Src),hl
        ex de,hl
        ld hl,(Ri_End)              ; BC - байт до конца (у последней - 0)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,(Ed_Row)
        call Iv_Row_Addr
        ex de,hl
        ld hl,(Ri_Src)
        ld a,b
        or c
        jr z,.hdr
        ldir
.hdr    call Iv_Block
        inc hl                      ; OH_LOOP: за курсором - -1
        ld a,(Ed_Row)
        cp (hl)
        jr nc,$+3
        dec (hl)
        inc hl
        dec (hl)                    ; OH_END
        ld a,(hl)
        dec hl
        cp (hl)                     ; цикл - не за концом
        jr nc,$+3
        ld (hl),a
        dec hl
        ld (hl),a                   ; OH_LEN - копия
        jp Ed_Clamp

Ri_Size         dw 0
Ri_End          dw 0
Ri_Src          dw 0

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
        dec a
        ret z
        ld bc,FX_ROW_SIZE
        ret

; A - последняя возможная строка режима (строк - 1)
Rows_Last
        ld a,(Iv_Mode)
        cp 2
        ld a,INS_ROWS_MAX-1         ; у орнамента столько же
        ret nz
        ld a,FX_ROWS_MAX-1
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
.orn    dec a
        jr nz,.fx
        ld (ix+OR_NOISE),0
        ld (ix+OR_NOTE),0
        ret
.fx     push ix                     ; FX: нули - эффектов нет
        pop hl
        ld b,FX_ROW_SIZE
.z      ld (hl),0
        inc hl
        djnz .z
        ret

;-------- Unloop: в конце - строка "тишина" (у орнамента - без смещения), цикл на ней
Iv_Unloop
        call Rows_Last
        ld b,a
        call Iv_End
        cp b
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
        dec a
        ret z
        ld bc,FX_BLOCK
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
        dec a
        jr z,.cmp
        ld de,Fx_Empty
        ld b,FX_ROW_SIZE
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
        call Name_Ofs
        add hl,de
        ld a,(hl)
        or a
        ret
Ins_Empty       db 1<<IRB_OFF,0,0,15,0
Orn_Empty       db 0,0
Fx_Empty        ds FX_ROW_SIZE

; =========================================================================
; ПРОБА НОТЫ: строка внизу редактора. В фокусе - пианино (держишь - звучит),
; ▶ - текущая нота, пока держат кнопку мыши. Плееру - строка Prv_Row (коре) и
; команда PC_PREVIEW, отпустили - PC_STOP. Инструмент - текущий (на вкладке Orn -
; последний выбранный инструмент), орнамент - Orn пробы (на вкладке Orn - текущий).
; =========================================================================
Prv_Note        db 37               ; последняя нота (C-4)
Prv_Oct         db 4                ; октава пианино 1..8
Prv_Orn         db 0                ; орнамент пробы на вкладке Instr: 0 - нет, 1..16
Prv_Vol         db 15               ; громкость 1..15
Prv_Env         db 0                ; форма огибающей: 0 - выкл, 1..14
Prv_Key         db 0                ; клавиша, которой играем (0 - нет)

;-------- Рамка: разделитель ├──┤, ▶ и подписи (один раз)
Prv_Frame
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld de,ED_X+256*(IV_SCR_H+SEP_Y)
        ld a,#C3                    ; ├
        call PutCh
        ld b,ED_W-2
.h      ld a,BOX_H
        call PutCh
        djnz .h
        ld a,#B4                    ; ┤
        call PutCh
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld de,PV_PLAY+256*(IV_SCR_H+PV_Y)
        ld a,GLYPH_BTN_PLAY
        call PutCh
        ld a,GLYPH_BTN_PLAY+1
        call PutCh
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld e,PV_OCT
        ld hl,Txt_Oct
        call PutStr
        ld e,PV_ORN
        ld hl,Txt_Orn
        ld a,(Iv_Mode)
        or a
        jr z,$+5
        ld hl,Txt_Ins
        call PutStr
        ld e,PV_VOL
        ld hl,Txt_Vol
        call PutStr
        ld e,PV_ENV
        ld hl,Txt_Env
        jp PutStr

;-------- Значения: нота (в фокусе - цветом курсора), октава, Orn/Ins, громкость, форма
Prv_Draw
        ld hl,(SV_FOCUS)
        ld de,F_Test
        or a
        sbc hl,de
        ld a,(THEME_ATTR+CLR_NOTE)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        ld de,PV_NOTE+256*(IV_SCR_H+PV_Y)
        ld a,(Prv_Note)
        call Note_Str
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld e,PV_OCT+5
        ld a,(Prv_Oct)
        add a,'0'
        call PutCh
        ld e,PV_ORN+5               ; Instr: орнамент ('0' - нет); Orn: инструмент
        ld a,(Iv_Mode)
        or a
        jr nz,.ins
        ld a,(Prv_Orn)
        or a
        ld a,'0'
        jr z,.put
        ld a,(Prv_Orn)
        dec a
        call Num_Sym
        jr .put
.ins    ld a,(Iv_Nums)
        call Num_Sym
.put    call PutCh
        ld e,PV_VOL+5
        ld a,(Prv_Vol)
        call HexDigit
        call PutCh
        ld e,PV_ENV+5               ; форма: '-' - выкл
        ld a,(Prv_Env)
        or a
        ld a,'-'
        jr z,.env
        ld a,(Prv_Env)
        call HexDigit
.env    jp PutCh

; A - нота 1..96 -> 3 знака ("C-4"), E++
Note_Str
        dec a
        ld b,'1'
.o      cp 12
        jr c,.n
        sub 12
        inc b
        jr .o
.n      add a,a
        ld hl,Note_Names
        call Hl_Add_A
        ld a,(hl)
        call PutCh
        inc hl
        ld a,(hl)
        call PutCh
        ld a,b
        jp PutCh
Note_Names      db "C-C#D-D#E-F-F#G-G#A-A#B-"

;-------- Сыграть ноту A: Prv_Row (коре) - строка одного чипа, команда плееру
Prv_Play
        ld (Prv_Note),a
        ld hl,Prv_Row               ; всё пусто
        ld b,CHIP_SIZE
.z      ld (hl),0
        inc hl
        djnz .z
        ld a,#20                    ; шум 0 (в паттерне шум 0 - #20)
        ld (Prv_Row+CHIP_NOISE),a
        ld a,(Prv_Note)
        ld (Prv_Row+CHIP_CH_A+CH_NOTE),a
        ld a,(Iv_Mode)              ; инструмент и орнамент - номер+1 (орнамент 1 - пустой)
        or a
        jr nz,.orn
        ld a,(Iv_Num)
        inc a
        ld (Prv_Row+CHIP_CH_A+CH_SAMPLE),a
        ld a,(Prv_Orn)
        inc a
        jr .ost
.orn    ld a,(Iv_Nums)
        inc a
        ld (Prv_Row+CHIP_CH_A+CH_SAMPLE),a
        ld a,(Iv_Mode)              ; FX: орнамента нет
        cp 2
        ld a,1
        jr z,.ost
        ld a,(Iv_Num)
        add a,2
.ost    ld (Prv_Row+CHIP_CH_A+CH_ORNAMENT),a
        ld a,(Prv_Vol)
        ld (Prv_Row+CHIP_CH_A+CH_VOLUME),a
        ld a,(Prv_Env)              ; форма: 0 - выкл (в паттерне - 15)
        or a
        jr nz,$+4
        ld a,15
        ld (Prv_Row+CHIP_CH_A+CH_ENVSHAPE),a
        ld a,PC_PREVIEW             ; команда - последней (IM1 может влезть)
        ld (SV_PLAY_CMD),a
        jp Iv_Changed

;-------- Кнопка ▶ (каждый кадр): звучит проба (мышь, пианино, Enter) - цветом курсора
Prv_Btn
        ld a,(SV_PLAY_STATE)
        cp PS_PREVIEW
        ld a,(THEME_ATTR+CLR_BUTTON)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        ld de,PV_PLAY+256*(IV_SCR_H+PV_Y)
        ld a,GLYPH_BTN_PLAY
        call PutCh
        ld a,GLYPH_BTN_PLAY+1
        jp PutCh

;-------- Тишина
Prv_Stop
        ld a,PC_STOP
        ld (SV_PLAY_CMD),a
        ret

;-------- Каждый кадр, пока играет клавиша: отпустили - тишина
Prv_Check
        call Key_Down               ; A - код; NZ - держат
        ret nz
        xor a
        ld (Prv_Key),a
        jr Prv_Stop

;-------- ▶: нажали - текущая нота, отпустили - тишина
Prv_PlayEv
        cp EV_PRESS
        jr nz,.rel
        ld a,(Prv_Note)
        jp Prv_Play
.rel    cp EV_RELEASE
        ret nz
        jr Prv_Stop

;-------- Строка пробы в фокусе: пианино (две октавы с Prv_Oct), автоповтор - мимо
Prv_KeyEv
        cp EV_FOCUS_IN
        jp z,Iv_Changed
        cp EV_FOCUS_OUT
        jp z,Iv_Changed
        cp EV_KEY
        ret nz
        ld hl,Piano
.f      ld a,(hl)                   ; код, полутон; конец - 0
        or a
        ret z                       ; не пианино (CF = 0)
        cp b
        inc hl
        ld a,(hl)
        inc hl
        jr nz,.f
        bit 7,c                     ; KF_REPEAT - нота уже звучит
        jr nz,.eat
        ld e,a                      ; нота = (октава-1)*12 + полутон + 1
        ld a,(Prv_Oct)
        dec a
        ld d,a
        add a,a
        add a,d
        add a,a
        add a,a
        add a,e
        inc a
        cp NOTE_COUNT+1
        jr nc,.eat
        ld e,a
        ld a,b
        ld (Prv_Key),a
        ld a,e
        call Prv_Play
.eat    scf
        ret
    ASSERT KF_REPEAT == #80

; Пианино - таблица Piano в коре (srs/input.asm)

;-------- Кнопки пробы: октава, орнамент / инструмент, громкость, форма
Prv_BtnEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        ld b,a
        srl a                       ; что: 0 октава, 1 Orn/Ins, 2 громкость, 3 форма
        add a,a
        add a,a                     ; *4: переменная, минимум, максимум
        ld hl,Prv_Lims
        call Hl_Add_A
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(Iv_Mode)              ; Orn/Ins на вкладке Orn - инструмент 0..31
        or a
        jr z,.go
        ld a,b
        srl a
        cp 1
        jr nz,.go
        ld de,Iv_Nums
        ld hl,Prv_Ins_Lim
.go     ld a,(de)                   ; значение
        bit 0,b
        jr nz,.up
        cp (hl)                     ; - : не меньше минимума
        ret z
        dec a
        jr .st
.up     inc hl
        cp (hl)                     ; + : не больше максимума
        ret z
        inc a
.st     ld (de),a
        jp Iv_Changed

Prv_Lims
        dw Prv_Oct
        db 1, 8
        dw Prv_Orn
        db 0, ORNAMENTS_MAX
        dw Prv_Vol
        db 1, 15
        dw Prv_Env
        db 0, 14
Prv_Ins_Lim     db 0, SAMPLES_MAX-1

; =========================================================================
; ТЕКСТЫ
; =========================================================================
Txt_Instruments db "Instruments",0
Txt_Ornaments   db "Ornaments",0
Txt_Fx          db "FX",0
Txt_Library     db "Library",0
Txt_Name        db "Name",0
Txt_Len         db "Len",0
Txt_Loop        db "Loop",0
Txt_Caps_Ins    db "Rw TNE Tone  Ns  Env  VsR Volume",0
Txt_Caps_Orn    db "Rw Note Ns  Offset",0
Txt_Caps_Mix    db "Rw Mix  Min  Max Swp Semi  Det Tb L",0
Txt_Caps_Fm     db "Rw On Semi  Det Tb Step",0
Txt_Sub_Mix     db " Mix ",0
Txt_Sub_Fm      db " FM ",0
Txt_Sub_Efm     db " Env FM ",0
Txt_Sw          db "Sw",0
Txt_St          db "St",0
Txt_Kp          db "Kp",0
Txt_Clone       db " Clone ",0
Txt_Copy        db " Copy ",0
Txt_Paste       db " Paste ",0
Txt_Clear       db " Clear ",0
Txt_Unloop      db " Unloop ",0
Txt_Prev        db " < ",0
Txt_Next        db " > ",0
Txt_Oct         db "Oct",0
Txt_Orn         db "Orn",0
Txt_Ins         db "Ins",0
Txt_Vol         db "Vol",0
Txt_Env         db "Env",0


Txt_FxmTitle    db " FX ",0

FXM_DIV         equ 19              ; колонка черты за списком FX
FXM_DIV2        equ 60              ; колонка черты перед кнопками
FXM_SEP         equ 4               ; строка макета под шапкой - линия
;-------- Черта за списком (┬ │ … ┴) и линия под шапкой (├──┤) цветом рамок
Fxm_Lines_Hd
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld de,FXM_DIV+256*(IV_SCR_H+IV_TOP)
        ld e,FXM_DIV2
        ld a,#C2
        call PutCh
        ld e,FXM_DIV
        ld a,#C2                    ; ┬ на верхней рамке
        call PutCh
        ld b,FXM_SEP
.v      inc d                       ; │ вниз до линии - обе черты
        ld e,FXM_DIV
        ld a,#B3
        call PutCh
        ld e,FXM_DIV2
        ld a,#B3
        call PutCh
        djnz .v
        inc d                       ; линия: ├ ─── ┴ ─── ┤
        ld e,0
        ld a,#C3
        call PutCh
.h      ld a,e
        cp FXM_DIV
        ld a,#C1
        jr z,.put
        ld a,e
        cp FXM_DIV2
        ld a,#C1
        jr z,.put
        ld a,e
        cp 89
        ld a,#B4
        jr z,.put
        ld a,#C4
.put    call PutCh
        ld a,e
        cp 90
        jr c,.h
        ret

    include "srs/fxedit.asm"       ; редактор FX (реворк): отрисовка

    ENDMODULE

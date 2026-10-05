; =========================================================================
; ШАПКА (строки 0..VIEW_LINE-1 над паттерном), свой фон CLR_HEAD_BG
;   строка 0: вкладки экранов | кнопки транспорта (спрайты 16x16, строки 0..1) |
;             время игры, Chip: тип и 3ch / 6ch
;   строка 1: File: имя файла | ... | Stereo:, Tune:
;   строка 2: верхняя линия рамки, по ней: Song: имя, By: автор
;   строка 3: нижняя линия рамки, по ней - как пишем в паттерн: Speed:, Size:,
;             Octave:, Step:, Env as Note, Auto Env (вплотную к паттерну)
; Подписи - CLR_HEAD_TEXT, значения - на своём фоне CLR_HEAD_VALUE (как поле ввода).
; Всё рисуется в буфер (невидимые строки HD_BUF_LINE..), с подсветкой под мышью;
; IM1 копирует буфер на экран одной DMA (Head_Copy). Поля - Head_Fields.
; Значения трека - копии из страницы трека (Song_*), меняются - Hd_Save пишет туда.
; =========================================================================

HD_BUF_LINE     equ 48              ; буфер: невидимые строки текстовой страницы
HD_SCR_H        equ SCR_BASE_H+HD_BUF_LINE
HD_W            equ 90              ; ширина шапки
; --- строка 0
HD_TABS_Y       equ 0
HD_PLAY_X       equ 38              ; кнопки транспорта - спрайты 16x16 (38..57, строки 0..1)
HD_TIME_X       equ 59              ; время игры "mm:ss"
HD_CHIP_L       equ 65              ; "Chip:"
HD_CHIP_X       equ 70              ; тип чипа (9 знаков)
HD_CHAN_X       equ 80              ; "3ch" / "6ch"
; --- строка 1
HD_ROW_FILE     equ 1
HD_FILE_L       equ 1               ; "File:"
HD_FILE_X       equ 7               ; имя файла (30)
HD_STEREO_L     equ 59              ; "Stereo:"
HD_STEREO_X     equ 66              ; 3 знака
HD_TUNE_L       equ 70              ; "Tune:"
HD_TUNE_X       equ 75              ; 7 знаков
; --- строка 2: верх рамки
HD_ROW_SONG     equ 2
HD_SONG_L       equ 1               ; "Song:"
HD_NAME_X       equ 6               ; имя (32)
HD_BY_L         equ 39              ; "By:"
HD_AUTH_X       equ 42              ; автор (32)
; --- строка 3: низ рамки, параметры ввода
HD_ROW_EDIT     equ 3
HD_SPEED_L      equ 1               ; "Speed:"
HD_SPEED_X      equ 7               ; 2 знака, кнопки - +2
HD_LEN_L        equ 14              ; "Size:" - длина паттерна
HD_LEN_X        equ 19
HD_OCT_L        equ 26              ; "Octave:"
HD_OCT_X        equ 33              ; 1 цифра, кнопки - +1
HD_STEP_L       equ 39              ; "Step:" + галочка (шаг вкл/выкл)
HD_STEPCHK_X    equ 44
HD_STEP_X       equ 45              ; 2 знака, кнопки - +2
HD_ENVNOTE_L    equ 52              ; "Env as Note" + галочка (вся надпись - поле)
HD_ENVNOTE_X    equ 63
HD_AUTO_L       equ 65              ; "Auto Env" + галочка
HD_AUTO_X       equ 73
HD_RATIO_X      equ 75              ; "1:1" - клик по кругу
    ASSERT VIEW_LINE == HD_ROW_EDIT+1 ; шапка - строки 0..3, паттерн - сразу под ней

; --- значения
Song_Speed      db 3
Song_Tuning     db 0
Song_Device     db 0                ; тип чипа: AY
Song_Chips      db 2                ; чипов: 1 (3 канала) или 2 (6 каналов)
Song_Stereo     db 0
Cur_Octave      db 4
Auto_Env        db 0
Auto_Step       db 1                ; шаг при вводе: 1 - курсор идёт на Cur_Step роу
Auto_Ratio      db 0                ; номер в Hd_Ratios
TUNINGS         equ 2
DEVICES         equ 4
STEREOS         equ 3
RATIOS          equ 8

; Названия - по фиксированной ширине
Hd_Tunings      db "1.75MHz"
                db "Classic"
Hd_Devices      db "AY       "
                db "YM       "
                db "AYX-32   "
                db "FT2 board"
Hd_Stereos      db "ABC","ACB","BAC"
; Соотношения автоогибающей A:B - как в Vortex Tracker II (StdAutoEnv, main.pas).
; Период огибающей = период ноты * A / B / 16 (пила, формы 8 и 12) или / 32
; (треугольник, 10 и 14); другие формы автоогибающая не трогает (CHILDWIN.PAS)
Hd_Ratios       db "1:1","3:4","1:2","1:4","3:1","5:2","2:1","3:2"

;-------- Значения трека - из страницы трека (после Song_Clear / загрузки)
Head_Load
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld a,(#8000+SH_SPEED)
        ld (Song_Speed),a
        ld a,(#8000+SH_TUNING)
        ld (Song_Tuning),a
        ld a,(#8000+SH_DEVICE)
        ld (Song_Device),a
        ld a,(#8000+SH_CHIPS)
        ld (Song_Chips),a
        ld a,(#8000+SH_STEREO)
        ld (Song_Stereo),a
        ld a,(#8000+SH_STEP)
        ld (Cur_Step),a
        RESTPAGE2
        ret

;-------- Значения трека - в страницу трека (поменяли в шапке)
Hd_Save
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld a,(Song_Speed)
        ld (#8000+SH_SPEED),a
        ld a,(Song_Tuning)
        ld (#8000+SH_TUNING),a
        ld a,(Song_Device)
        ld (#8000+SH_DEVICE),a
        ld a,(Song_Chips)
        ld (#8000+SH_CHIPS),a
        ld a,(Song_Stereo)
        ld (#8000+SH_STEREO),a
        ld a,(Cur_Step)
        ld (#8000+SH_STEP),a
        RESTPAGE2
        ret

; =========================================================================
; РИСОВАНИЕ (в буфер)
; =========================================================================
;-------- Раз при старте: фон шапки, линии рамки (строки 2 и 3)
Head_Draw
        ld a,(THEME_ATTR+CLR_HEAD_BG)
        ld c,a
        ld d,HD_SCR_H               ; строки 0..VIEW_LINE-1: пробелы фоном шапки
.f      ld e,0
.fc     ld a,' '
        call PutCh
        bit 7,e
        jr z,.fc
        inc d
        ld a,d
        cp HD_SCR_H+VIEW_LINE
        jr c,.f
        ld a,(THEME_ATTR+CLR_HEAD_LINE)
        ld c,a
        ld d,HD_SCR_H+HD_ROW_SONG   ; верх рамки: ┌───┐
        ld a,BOX_TL
        ld b,BOX_TR
        call .line
        ld d,HD_SCR_H+HD_ROW_EDIT   ; низ рамки: └───┘
        ld a,BOX_BL
        ld b,BOX_BR
; Линия во всю ширину: A - левый угол, B - правый, D - строка. Цвет C
.line   ld e,0
        call PutCh
.h      ld a,BOX_H
        call PutCh
        ld a,e
        cp HD_W-1
        jr c,.h
        ld a,b
        jp PutCh

; Надписи: строка, колонка, роль цвета, текст, 0. Конец - #FF
Hd_Static
        db HD_TABS_Y,1,CLR_HEAD_HI,"Pattern",0
        db HD_TABS_Y,10,CLR_HEAD_TEXT,"Instr",0
        db HD_TABS_Y,17,CLR_HEAD_TEXT,"Orn",0
        db HD_TABS_Y,22,CLR_HEAD_TEXT,"FX",0
        db HD_TABS_Y,26,CLR_HEAD_TEXT,"Disk",0
        db HD_TABS_Y,32,CLR_HEAD_TEXT,"Setup",0
        db HD_TABS_Y,HD_CHIP_L,CLR_HEAD_TEXT,"Chip:",0
        db HD_ROW_FILE,HD_FILE_L,CLR_HEAD_TEXT,"File:",0
        db HD_ROW_FILE,HD_FILE_X,CLR_HEAD_VALUE,"..............................",0
        db HD_ROW_FILE,HD_STEREO_L,CLR_HEAD_TEXT,"Stereo:",0
        db HD_ROW_FILE,HD_TUNE_L,CLR_HEAD_TEXT,"Tune:",0
        db HD_ROW_SONG,HD_SONG_L,CLR_HEAD_TEXT,"Song:",0
        db HD_ROW_SONG,HD_NAME_X,CLR_HEAD_VALUE,"................................",0
        db HD_ROW_SONG,HD_BY_L,CLR_HEAD_TEXT,"By:",0
        db HD_ROW_SONG,HD_AUTH_X,CLR_HEAD_VALUE,"................................",0
        db HD_ROW_EDIT,HD_SPEED_L,CLR_HEAD_TEXT,"Speed:",0
        db HD_ROW_EDIT,HD_LEN_L,CLR_HEAD_TEXT,"Size:",0
        db HD_ROW_EDIT,HD_OCT_L,CLR_HEAD_TEXT,"Octave:",0
        db HD_ROW_EDIT,HD_STEP_L,CLR_HEAD_TEXT,"Step:",0
        db HD_ROW_EDIT,HD_ENVNOTE_L,CLR_HEAD_TEXT,"Env as Note",0
        db HD_ROW_EDIT,HD_AUTO_L,CLR_HEAD_TEXT,"Auto Env",0
        db #FF

;-------- Каждый кадр: надписи, значения, кнопки, подсветка под мышью
Head_Show
        ld hl,Hd_Static             ; надписи
.s      ld a,(hl)
        cp #FF
        jr z,.values
        add a,HD_SCR_H
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        add a,low THEME_ATTR
        ld l,a
        ld h,high THEME_ATTR
        ld c,(hl)
        pop hl
        call PutStr
        inc hl
        jr .s
.values ld a,(THEME_ATTR+CLR_HEAD_VALUE) ; значения - на своём фоне
        ld c,a
        ld a,(SV_PLAY_STATE)        ; скорость: играет - плеера, иначе трека
        or a
        ld a,(SV_PLAY_SPEED)
        jr nz,$+5
        ld a,(Song_Speed)
        ld de,HD_SPEED_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call PutHex2
        ld a,(Cur_Pos)              ; длина паттерна текущей позиции
        ld hl,Test_Order
        call Arr_Get
        ld hl,Pat_Len
        call Arr_Get
        ld de,HD_LEN_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call PutHex2
        ld a,(Cur_Octave)           ; октава
        add a,'0'
        ld de,HD_OCT_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call PutCh
        ld a,(Auto_Step)            ; шаг: галочка, сразу за ней значение
        ld de,HD_STEPCHK_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call Hd_Check
        ld a,(Cur_Step)
        call PutHex2
        ld a,(Env_As_Note)          ; галочки
        ld de,HD_ENVNOTE_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call Hd_Check
        ld a,(Auto_Env)
        ld de,HD_AUTO_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call Hd_Check
        ld a,(Auto_Ratio)           ; соотношение автоогибающей
        ld hl,Hd_Ratios
        ld b,3
        ld de,HD_RATIO_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call Hd_Name
        ld a,(Song_Device)          ; тип чипа, каналов
        ld hl,Hd_Devices
        ld b,9
        ld de,HD_CHIP_X+256*(HD_SCR_H+HD_TABS_Y)
        call Hd_Name
        ld a,(Song_Chips)
        cp 2
        ld a,"3"
        jr c,$+4
        ld a,"6"
        ld de,HD_CHAN_X+256*(HD_SCR_H+HD_TABS_Y)
        call PutCh
        ld a,"c"
        call PutCh
        ld a,"h"
        call PutCh
        ld a,(Song_Stereo)          ; стерео, таблица нот
        ld hl,Hd_Stereos
        ld b,3
        ld de,HD_STEREO_X+256*(HD_SCR_H+HD_ROW_FILE)
        call Hd_Name
        ld a,(Song_Tuning)
        ld hl,Hd_Tunings
        ld b,7
        ld de,HD_TUNE_X+256*(HD_SCR_H+HD_ROW_FILE)
        call Hd_Name
        ld a,(THEME_ATTR+CLR_HEAD_TEXT) ; время игры mm:ss
        ld c,a
        ld de,HD_TIME_X+256*(HD_SCR_H+HD_TABS_Y)
        ld a,(Tm_Min)
        call Hd_Dec2
        ld a,':'
        call PutCh
        ld a,(Tm_Sec)
        call Hd_Dec2
        call Hd_Buttons             ; кнопки [-][+]
        call Tr_Hover_Update        ; кнопки транспорта: светлая под мышью
        jp Hd_Hover                 ; подсветка поля под мышью


; A - номер, HL - таблица названий по B знаков, DE - куда. Цвет C
Hd_Name
        or a
        jr z,.p
        push bc
        ld c,b
        ld b,0
.m      add hl,bc
        dec a
        jr nz,.m
        pop bc
.p      ld a,(hl)
        call PutCh
        inc hl
        djnz .p
        ret

; A - 0/1 -> галочка в DE
Hd_Check
        or a
        ld a,GLYPH_CHK_OFF
        jr z,$+4
        ld a,GLYPH_CHK_ON
        jp PutCh

; A - 0..99 -> 2 десятичные цифры в DE
Hd_Dec2
        ld b,'0'-1
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        call PutCh
        pop af
        jp PutCh

;-------- Кнопки [-][+]: вдавлена, пока её держат и мышь над ней (как в Windows)
Hd_Buttons
        ld ix,Head_Fields
.b      ld a,(ix+FLD_X)
        cp FLD_END
        ret z
        ld a,(ix+FLD_FLAGS)         ; кнопка - флаг HF_BUTTON
        and HF_BUTTON
        jr z,.n
        push ix                     ; вдавлена: на ней нажали и мышь над ней
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ld b,0
        jr nz,.show
        add hl,de
        ld de,(SV_HOVER)
        sbc hl,de                   ; CF = 0 после or a / add
        jr nz,.show
        inc b
.show   ld a,(ix+FLD_Y)
        add a,HD_SCR_H
        ld d,a
        ld e,(ix+FLD_X)
        ld a,(ix+FLD_PARAM)         ; чётная - [-], нечётная - [+]
        rrca
        ld a,GLYPH_BTN_MINUS
        jr nc,$+4
        ld a,GLYPH_BTN_PLUS
        bit 0,b
        jr z,$+4
        add a,BTN_PRESSED
        call PutBtn_Head
.n      ld de,FLD_SIZE
        add ix,de
        jr .b

;-------- Подсветка: поле шапки под мышью - атрибуты CLR_HOVER на всю его ширину
Hd_Hover
        ld hl,(SV_HOVER)            ; поле шапки? (адрес внутри Head_Fields)
        ld de,Head_Fields
        or a
        sbc hl,de
        ret c
        ld de,Head_Fields_End-Head_Fields
        sbc hl,de
        ret nc
        ld ix,(SV_HOVER)
        ld a,(ix+FLD_Y)
        add a,HD_SCR_H
        ld h,a
        ld a,(ix+FLD_X)
        or SCR_ATTR
        ld l,a
        ld b,(ix+FLD_W)
        ld a,(THEME_ATTR+CLR_HOVER)
.a      ld (hl),a
        inc l
        djnz .a
        ret

;-------- Время игры: каждый кадр основного цикла, пока играет (сброс - Play_Go)
Tm_Frm          db 0
Tm_Sec          db 0
Tm_Min          db 0

Time_Tick
        ld a,(Playing)
        or a
        ret z
        ld hl,Tm_Frm
        inc (hl)
        ld a,(hl)
        cp 50
        ret c
        ld (hl),0
        inc hl                      ; секунды
        inc (hl)
        ld a,(hl)
        cp 60
        ret c
        ld (hl),0
        inc hl                      ; минуты, до 99
        ld a,(hl)
        cp 99
        ret nc
        inc (hl)
        ret

Time_Reset
        xor a
        ld (Tm_Frm),a
        ld (Tm_Sec),a
        ld (Tm_Min),a
        ret

; =========================================================================
; ПОЛЯ ШАПКИ: клик - действие Hd_Act[параметр]. Кнопки - флаг HF_BUTTON
; (их рисует Hd_Buttons: чётный параметр - [-], нечётный - [+]).
; Надпись + галочка - одно поле: кликать можно по надписи.
; =========================================================================
HF_BUTTON       equ %10000000       ; флаг поля (FLD_FLAGS): кнопка [-]/[+]

Head_Fields
        FIELD HD_SPEED_X+2,HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 0  ; Speed -
        FIELD HD_SPEED_X+4,HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 1  ;       +
        FIELD HD_OCT_X+1,  HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 2  ; Octave -
        FIELD HD_OCT_X+3,  HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 3  ;        +
        FIELD HD_STEP_X+2, HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 4  ; Step -
        FIELD HD_STEP_X+4, HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 5  ;      +
        FIELD HD_LEN_X+2,  HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 6  ; Len -
        FIELD HD_LEN_X+4,  HD_ROW_EDIT,2,1, HF_BUTTON|FF_HAND, Hd_Field, 0, 7  ;     +
        FIELD HD_RATIO_X,  HD_ROW_EDIT,3,1, FF_HAND, Hd_Field, 0, 8          ; соотношение - по кругу
        FIELD HD_TUNE_X,   HD_ROW_FILE,7,1, FF_HAND, Hd_Field, 0, 9           ; таблица нот - по кругу
        FIELD HD_CHIP_X,   HD_TABS_Y, 9,1, FF_HAND, Hd_Field, 0, 10          ; тип чипа - по кругу
        FIELD HD_CHAN_X,   HD_TABS_Y, 3,1, FF_HAND, Hd_Field, 0, 20          ; 3 / 6 каналов
        FIELD HD_STEREO_X, HD_ROW_FILE,3,1, FF_HAND, Hd_Field, 0, 11          ; стерео - по кругу
        FIELD HD_ENVNOTE_L,HD_ROW_EDIT,HD_ENVNOTE_X-HD_ENVNOTE_L+1,1, FF_HAND, Hd_Field, 0, 12 ; Env as Note
        FIELD HD_AUTO_L,   HD_ROW_EDIT,HD_AUTO_X-HD_AUTO_L+1,1, FF_HAND, Hd_Field, 0, 13       ; Auto Env
        FIELD HD_STEP_L,   HD_ROW_EDIT,HD_STEPCHK_X-HD_STEP_L+1,1, FF_HAND, Hd_Field, 0, 14    ; шаг вкл/выкл
Tr_Fields                           ; кнопки транспорта (спрайты Tr_*), подряд
        FIELD HD_PLAY_X,   HD_TABS_Y, 4,2, FF_HAND, Hd_Field, 0, 15          ; ⇄ паттерн по кругу (F8)
        FIELD HD_PLAY_X+4, HD_TABS_Y, 4,2, FF_HAND, Hd_Field, 0, 16          ; |◀ сонг с начала (F6)
        FIELD HD_PLAY_X+8, HD_TABS_Y, 4,2, FF_HAND, Hd_Field, 0, 17          ; ▶ сонг с позиции (F5)
        FIELD HD_PLAY_X+12,HD_TABS_Y, 4,2, FF_HAND, Hd_Field, 0, 18          ; ▷ паттерн с роу (F7)
        FIELD HD_PLAY_X+16,HD_TABS_Y, 4,2, FF_HAND, Hd_Field, 0, 19          ; ■ стоп (Esc)
Head_Fields_End
        db FLD_END

Hd_Act  dw H_SpdDn, H_SpdUp, H_OctDn, H_OctUp, H_StepDn, H_StepUp
        dw H_LenDn, H_LenUp, H_RatUp
        dw H_Tune, H_Chip, H_Stereo, K_EnvNote, H_AutoEnv, H_AutoStep
        dw K_PlayPat, K_PlayStart, K_PlaySong, K_PlayPatRow, K_Stop
        dw H_Chips

;-------- Поле шапки: клик - действие (вид нажатой кнопки рисует Hd_Buttons)
Hd_Field
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        add a,a
        ld hl,Hd_Act
        call Arr_Get
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

;-------- Действия
H_SpdDn ld hl,Song_Speed            ; скорость 1..255
        ld a,(hl)
        dec a
        ret z
        ld (hl),a
        jp Hd_Save
H_SpdUp ld hl,Song_Speed
        ld a,(hl)
        inc a
        ret z
        ld (hl),a
        jp Hd_Save
H_OctDn ld hl,Cur_Octave            ; октава 1..8
        ld a,(hl)
        cp 2
        ret c
        dec (hl)
        ret
H_OctUp ld hl,Cur_Octave
        ld a,(hl)
        cp 8
        ret nc
        inc (hl)
        ret
H_StepDn
        ld hl,Cur_Step              ; шаг 0..64
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jp Hd_Save
H_StepUp
        ld hl,Cur_Step
        ld a,(hl)
        cp PAT_ROWS_MAX
        ret nc
        inc (hl)
        jp Hd_Save
H_LenDn ld b,-1                     ; длина паттерна текущей позиции 1..64
        jr H_Len
H_LenUp ld b,1
H_Len   ld a,(Cur_Pos)
        ld hl,Test_Order
        call Arr_Get
        ld hl,Pat_Len
        call Arr_Get                ; HL - на длину
        add a,b
        ret z                       ; 0 - нельзя
        cp PAT_ROWS_MAX+1
        ret nc
        ld (hl),a
        ld hl,Cur_Row               ; курсор - не за концом
        cp (hl)
        jr z,.cut
        jr nc,.ok
.cut    dec a
        ld (hl),a
.ok     jp Song_Sync
        ret
H_RatUp ld hl,Auto_Ratio
        ld b,RATIOS
        jr Hd_Cycle
H_Tune  ld hl,Song_Tuning
        ld b,TUNINGS
        call Hd_Cycle
        jp Hd_Save
H_Chip  ld hl,Song_Device
        ld b,DEVICES
        call Hd_Cycle
        jp Hd_Save
H_Stereo
        ld hl,Song_Stereo
        ld b,STEREOS
        call Hd_Cycle
        jp Hd_Save
H_Chips                             ; 1 <-> 2 чипа: 3 / 6 каналов в паттерне и в плеере
        ld a,(Song_Chips)
        xor 3
        ld (Song_Chips),a
        call Hd_Save
        call View_Chips
        jp Need_Layout
H_AutoStep
        ld hl,Auto_Step
        jr Hd_Toggle
H_AutoEnv
        ld hl,Auto_Env
Hd_Toggle                           ; (HL) = 0 <-> 1
        ld a,(hl)
        xor 1
        ld (hl),a
        ret

; (HL) = (HL)+1 по кругу 0..B-1
Hd_Cycle
        ld a,(hl)
        inc a
        cp b
        jr c,$+3
        xor a
        ld (hl),a
        ret

; =========================================================================
; КНОПКИ ТРАНСПОРТА - СПРАЙТЫ (как у Bitphase: светлый значок на скруглённой
; подложке). Спрайт 16x8 = 4 знакоместа x 1 строка (пиксель спрайта - пол знакоместа
; по ширине). Графика - в странице спрайтов: ряд тайлов 2 (строки 16..23) - обычные,
; ряд 4 (строки 32..47) - под мышью. Описатели - SFILE, записи 0..4; стрелка мыши -
; запись 5 (позже в списке - выше, srs/mouse.asm).
; =========================================================================
TR_BUTTONS      equ 5
TR_ROW_N        equ 2               ; ряд тайлов: обычные (строки битмапа 16..31)
TR_ROW_H        equ 4               ;             под мышью (строки 32..47)
TR_PAL          equ #D0             ; палитра 13 (как у текста и стрелки)
TR_SFILE_SLOT   equ 0               ; записи SFILE кнопок 0..4; стрелка мыши - 5 (позже - поверх)

;-------- Раз при старте: графику - в страницу спрайтов, описатели - в SFILE
Head_Sprites
        SETPAGE3 PAGE_SPRITE
        ld hl,Tr_Gfx_N
        ld de,#C000+TR_ROW_N*8*256
        call .copy
        ld hl,Tr_Gfx_H
        ld de,#C000+TR_ROW_H*8*256
        call .copy
        RESTPAGE3
        ld a,#FF                    ; ни одна не под мышью
        ld (Tr_Hover),a
        jp Tr_Send
; HL - значки подряд (по 16 строк x 8 байт), DE - строка битмапа: значок k - с байта 8k
.copy   ld c,0                      ; C - смещение значка в строке битмапа
.ic     push de
        ld a,e
        add a,c
        ld e,a
        ld b,16                     ; 16 строк по 8 байт (16 точек, 2 на байт)
.row    push bc
        push de
        ld bc,8
        ldir
        pop de
        inc d                       ; строка битмапа - 256 байт
        pop bc
        djnz .row
        pop de
        ld a,c
        add a,8
        ld c,a
        cp TR_BUTTONS*8
        jr c,.ic
        ret

;-------- Каждый кадр (Head_Show): кнопка под мышью - светлая картинка
Tr_Hover        db #FF

Tr_Hover_Update
        ld b,#FF                    ; B - номер кнопки под мышью
        ld ix,Tr_Fields
        ld c,0
.f      push ix
        pop hl
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        jr nz,.n
        ld b,c
.n      ld de,FLD_SIZE
        add ix,de
        inc c
        ld a,c
        cp TR_BUTTONS
        jr c,.f
        ld a,(Tr_Hover)             ; не сменилась - ничего
        cp b
        ret z
        ld a,b
        ld (Tr_Hover),a
        ld hl,Tr_SAT+4              ; тайлы: под мышью - из ряда TR_ROW_H
        ld c,0
.t      ld a,c
        cp b
        ld a,low (TR_ROW_N*64)      ; тайл: младший байт и палитра | старшие биты
        ld e,TR_PAL|high (TR_ROW_N*64)
        jr nz,.nh
        ld a,low (TR_ROW_H*64)
        ld e,TR_PAL|high (TR_ROW_H*64)
.nh     add a,c
        add a,c
        ld (hl),a
        inc hl
        ld (hl),e
        ld de,5
        add hl,de
        inc c
        ld a,c
        cp TR_BUTTONS
        jr c,.t
; Описатели кнопок - в SFILE (DMA, из основного цикла)
Tr_Send
        ld hl,Tr_Dma
        jp set_ports

; Описатели (SFILE: Y, флаги Y, X, флаги X, тайл, палитра | тайл ст.)
        ALIGN 2
Tr_SAT
.k = 0
        DUP TR_BUTTONS
        db 0, SP_ACT|SP_SIZE16, (HD_PLAY_X+.k*4)*4, SP_SIZE16, TR_ROW_N*64+.k*2, TR_PAL
.k = .k+1
        EDUP
Tr_SAT_End

Tr_Dma  db high DMASADDRL, low (Tr_SAT-#4000)
        db high DMASADDRH, high (Tr_SAT-#4000)
        db high DMASADDRX, PAGE_TOOL_PATVIEW
        db high DMADADDRL, TR_SFILE_SLOT*6  ; SFILE: записи 0..4 (5 - стрелка мыши)
        db high DMADADDRH, 0
        db high DMADADDRX, 0
        db high DMALEN, (Tr_SAT_End-Tr_SAT)/2-1
        db high DMANUM, 0
        db high DMACTR, DMA_RAM_SFILE
        db #FF

Tr_Gfx_N                            ; обычные: грань #4, кромки #6 / #1, значок #B
; LOOP
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#4B,#44,#44,#41   ; LFFFFFFFFIFFFFFD
        db #64,#44,#BB,#BB,#BB,#BB,#44,#41   ; LFFFIIIIIIIIFFFD
        db #64,#44,#44,#44,#4B,#44,#44,#41   ; LFFFFFFFFIFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#BB,#BB,#BB,#BB,#44,#41   ; LFFFIIIIIIIIFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; START
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#4B,#44,#44,#B4,#44,#41   ; LFFFFIFFFFIFFFFD
        db #64,#44,#4B,#44,#4B,#B4,#44,#41   ; LFFFFIFFFIIFFFFD
        db #64,#44,#4B,#44,#BB,#B4,#44,#41   ; LFFFFIFFIIIFFFFD
        db #64,#44,#4B,#4B,#BB,#B4,#44,#41   ; LFFFFIFIIIIFFFFD
        db #64,#44,#4B,#4B,#BB,#B4,#44,#41   ; LFFFFIFIIIIFFFFD
        db #64,#44,#4B,#44,#BB,#B4,#44,#41   ; LFFFFIFFIIIFFFFD
        db #64,#44,#4B,#44,#4B,#B4,#44,#41   ; LFFFFIFFFIIFFFFD
        db #64,#44,#4B,#44,#44,#B4,#44,#41   ; LFFFFIFFFFIFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; PLAY
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#44,#BB,#44,#44,#44,#41   ; LFFFFFIIFFFFFFFD
        db #64,#44,#44,#BB,#B4,#44,#44,#41   ; LFFFFFIIIFFFFFFD
        db #64,#44,#44,#BB,#BB,#44,#44,#41   ; LFFFFFIIIIFFFFFD
        db #64,#44,#44,#BB,#BB,#44,#44,#41   ; LFFFFFIIIIFFFFFD
        db #64,#44,#44,#BB,#B4,#44,#44,#41   ; LFFFFFIIIFFFFFFD
        db #64,#44,#44,#BB,#44,#44,#44,#41   ; LFFFFFIIFFFFFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; FROM
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#44,#BB,#44,#44,#44,#41   ; LFFFFFIIFFFFFFFD
        db #64,#44,#44,#B4,#B4,#44,#44,#41   ; LFFFFFIFIFFFFFFD
        db #64,#44,#44,#B4,#4B,#44,#44,#41   ; LFFFFFIFFIFFFFFD
        db #64,#44,#44,#B4,#4B,#44,#44,#41   ; LFFFFFIFFIFFFFFD
        db #64,#44,#44,#B4,#B4,#44,#44,#41   ; LFFFFFIFIFFFFFFD
        db #64,#44,#44,#BB,#44,#44,#44,#41   ; LFFFFFIIFFFFFFFD
        db #64,#44,#44,#B4,#44,#44,#44,#41   ; LFFFFFIFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; STOP
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#4B,#BB,#BB,#B4,#44,#41   ; LFFFFIIIIIIFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #64,#44,#44,#44,#44,#44,#44,#41   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
Tr_Gfx_H                            ; под мышью: грань #7
; LOOP
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#7B,#77,#77,#71   ; LFFFFFFFFIFFFFFD
        db #67,#77,#BB,#BB,#BB,#BB,#77,#71   ; LFFFIIIIIIIIFFFD
        db #67,#77,#77,#77,#7B,#77,#77,#71   ; LFFFFFFFFIFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#BB,#BB,#BB,#BB,#77,#71   ; LFFFIIIIIIIIFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; START
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#7B,#77,#77,#B7,#77,#71   ; LFFFFIFFFFIFFFFD
        db #67,#77,#7B,#77,#7B,#B7,#77,#71   ; LFFFFIFFFIIFFFFD
        db #67,#77,#7B,#77,#BB,#B7,#77,#71   ; LFFFFIFFIIIFFFFD
        db #67,#77,#7B,#7B,#BB,#B7,#77,#71   ; LFFFFIFIIIIFFFFD
        db #67,#77,#7B,#7B,#BB,#B7,#77,#71   ; LFFFFIFIIIIFFFFD
        db #67,#77,#7B,#77,#BB,#B7,#77,#71   ; LFFFFIFFIIIFFFFD
        db #67,#77,#7B,#77,#7B,#B7,#77,#71   ; LFFFFIFFFIIFFFFD
        db #67,#77,#7B,#77,#77,#B7,#77,#71   ; LFFFFIFFFFIFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; PLAY
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#77,#BB,#77,#77,#77,#71   ; LFFFFFIIFFFFFFFD
        db #67,#77,#77,#BB,#B7,#77,#77,#71   ; LFFFFFIIIFFFFFFD
        db #67,#77,#77,#BB,#BB,#77,#77,#71   ; LFFFFFIIIIFFFFFD
        db #67,#77,#77,#BB,#BB,#77,#77,#71   ; LFFFFFIIIIFFFFFD
        db #67,#77,#77,#BB,#B7,#77,#77,#71   ; LFFFFFIIIFFFFFFD
        db #67,#77,#77,#BB,#77,#77,#77,#71   ; LFFFFFIIFFFFFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; FROM
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#77,#BB,#77,#77,#77,#71   ; LFFFFFIIFFFFFFFD
        db #67,#77,#77,#B7,#B7,#77,#77,#71   ; LFFFFFIFIFFFFFFD
        db #67,#77,#77,#B7,#7B,#77,#77,#71   ; LFFFFFIFFIFFFFFD
        db #67,#77,#77,#B7,#7B,#77,#77,#71   ; LFFFFFIFFIFFFFFD
        db #67,#77,#77,#B7,#B7,#77,#77,#71   ; LFFFFFIFIFFFFFFD
        db #67,#77,#77,#BB,#77,#77,#77,#71   ; LFFFFFIIFFFFFFFD
        db #67,#77,#77,#B7,#77,#77,#77,#71   ; LFFFFFIFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.
; STOP
        db #06,#66,#66,#66,#66,#66,#66,#60   ; .LLLLLLLLLLLLLL.
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#7B,#BB,#BB,#B7,#77,#71   ; LFFFFIIIIIIFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #67,#77,#77,#77,#77,#77,#77,#71   ; LFFFFFFFFFFFFFFD
        db #01,#11,#11,#11,#11,#11,#11,#10   ; .DDDDDDDDDDDDDD.

;-------- IM1, в начале сборки кадра: буфер шапки (строки HD_BUF_LINE..) -> строки
; 0..VIEW_LINE-1 экрана, символы и атрибуты, одной DMA
Head_Copy
        call dma_wait               ; C = #AF
        ld a,(SV_DRAW_PAGE)         ; та же страница: источник и приёмник
        ld b,high DMASADDRX
        out (c),a
        ld b,high DMADADDRX
        out (c),a
        xor a                       ; с колонки 0
        ld b,high DMASADDRL
        out (c),a
        ld b,high DMADADDRL
        out (c),a
        ld a,HD_BUF_LINE            ; строка буфера -> строка 0
        ld b,high DMASADDRH
        out (c),a
        xor a
        ld b,high DMADADDRH
        out (c),a
        ld a,127                    ; вся строка 256 байт
        ld b,high DMALEN
        out (c),a
        ld a,VIEW_LINE-1            ; строк 0..VIEW_LINE-1
        ld b,high DMANUM
        out (c),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a
        ret

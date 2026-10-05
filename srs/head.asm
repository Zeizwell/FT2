; =========================================================================
; ШАПКА (строки 0..VIEW_LINE-1 над паттерном), один свой фон CLR_TOP_BG
;   строка 0: вкладки | кнопки транспорта по центру (спрайты 16x16, строки 0..1) |
;             трек 1 / 2 | Help, About, стерео (ABC) - в правом углу, без подписи
;   строка 1: File: имя файла | (кнопки) | Chip:, Tune:
;   строка 2: Song: имя, By: автор
;   строка 3: как пишем в паттерн: Speed:, Size:, Octave:, Step:, Env as Note,
;             Auto Env, 3ch / 6ch (вплотную к паттерну)
; Данные трека (трек 1 / 2 переключает их все): файл, имя, автор, Chip, Tune,
; стерео, Speed, 3ch / 6ch. Остальное в строке 3 - общие настройки ввода.
; Подписи - CLR_TOP_TEXT, значения - CLR_TOP_VALUE, на том же фоне.
; Всё рисуется в буфер (невидимые строки HD_BUF_LINE..), с подсветкой под мышью;
; IM1 копирует буфер на экран одной DMA (Head_Copy). Поля - Head_Fields.
; Значения трека - копии из страницы трека (Song_*), меняются - Hd_Save пишет туда.
; =========================================================================

HD_BUF_LINE     equ 48              ; буфер: невидимые строки текстовой страницы
HD_SCR_H        equ SCR_BASE_H+HD_BUF_LINE
HD_W            equ 90              ; ширина шапки
; --- строка 0
HD_TABS_Y       equ 0
HD_TABS_X       equ 1               ; вкладки
HD_PLAY_Y       equ 0               ; кнопки транспорта - спрайты 16x16 (35..54, строки 0..1)
HD_PLAY_X       equ 35
HD_TRK_X        equ 57              ; трек "1 2" (выбранный - выделен)
HD_HELP_X       equ 76              ; "Help"
HD_ABOUT_X      equ 81              ; "About"
HD_STEREO_X     equ 87              ; стерео "ABC" - в правом углу
; --- строка 1
HD_ROW_FILE     equ 1
HD_FILE_L       equ 1               ; "File:"
HD_FILE_X       equ 7               ; имя файла (28)
HD_CHIP_L       equ 56              ; "Chip:"
HD_CHIP_X       equ 62              ; тип чипа (9 знаков)
HD_TUNE_L       equ 73              ; "Tune:"
HD_TUNE_X       equ 79              ; 7 знаков
; --- строка 2
HD_ROW_SONG     equ 2
HD_SONG_L       equ 1               ; "Song:"
HD_NAME_X       equ 7               ; имя (32)
HD_BY_L         equ 41              ; "By:"
HD_AUTH_X       equ 45              ; автор (32)
; --- строка 3: параметры ввода
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
HD_CHAN_X       equ 80              ; "3ch" / "6ch"
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
Cur_Track       db 0                ; трек в шапке: 0 / 1 (в памяти пока один)
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
;-------- Раз при старте: вся шапка - одним фоном (свой, не как у полосы заголовков паттерна)
Head_Draw
        ld a,(THEME_ATTR+CLR_TOP_BG)
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
        ret

; Надписи: строка, колонка, роль цвета, текст, 0. Конец - #FF
Hd_Static
        db HD_TABS_Y,HD_TABS_X,CLR_TOP_HI,"Pattern",0
        db HD_TABS_Y,HD_TABS_X+8,CLR_TOP_TEXT,"Instr",0
        db HD_TABS_Y,HD_TABS_X+14,CLR_TOP_TEXT,"Orn",0
        db HD_TABS_Y,HD_TABS_X+18,CLR_TOP_TEXT,"FX",0
        db HD_TABS_Y,HD_TABS_X+21,CLR_TOP_TEXT,"Disk",0
        db HD_TABS_Y,HD_TABS_X+26,CLR_TOP_TEXT,"Setup",0
        db HD_ROW_FILE,HD_FILE_L,CLR_TOP_TEXT,"File:",0
        db HD_ROW_FILE,HD_FILE_X,CLR_TOP_VALUE,"............................",0
        db HD_TABS_Y,HD_HELP_X,CLR_TOP_TEXT,"Help",0
        db HD_TABS_Y,HD_ABOUT_X,CLR_TOP_TEXT,"About",0
        db HD_ROW_FILE,HD_CHIP_L,CLR_TOP_TEXT,"Chip:",0
        db HD_ROW_FILE,HD_TUNE_L,CLR_TOP_TEXT,"Tune:",0
        db HD_ROW_SONG,HD_SONG_L,CLR_TOP_TEXT,"Song:",0
        db HD_ROW_SONG,HD_NAME_X,CLR_TOP_VALUE,"................................",0
        db HD_ROW_SONG,HD_BY_L,CLR_TOP_TEXT,"By:",0
        db HD_ROW_SONG,HD_AUTH_X,CLR_TOP_VALUE,"................................",0
        db HD_ROW_EDIT,HD_SPEED_L,CLR_TOP_TEXT,"Speed:",0
        db HD_ROW_EDIT,HD_LEN_L,CLR_TOP_TEXT,"Size:",0
        db HD_ROW_EDIT,HD_OCT_L,CLR_TOP_TEXT,"Octave:",0
        db HD_ROW_EDIT,HD_STEP_L,CLR_TOP_TEXT,"Step:",0
        db HD_ROW_EDIT,HD_ENVNOTE_L,CLR_TOP_TEXT,"Env as Note",0
        db HD_ROW_EDIT,HD_AUTO_L,CLR_TOP_TEXT,"Auto Env",0
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
.values ld a,(THEME_ATTR+CLR_TOP_VALUE) ; значения - на своём фоне
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
        ld de,HD_CHIP_X+256*(HD_SCR_H+HD_ROW_FILE)
        call Hd_Name
        ld a,(Song_Chips)
        cp 2
        ld a,"3"
        jr c,$+4
        ld a,"6"
        ld de,HD_CHAN_X+256*(HD_SCR_H+HD_ROW_EDIT)
        call PutCh
        ld a,"c"
        call PutCh
        ld a,"h"
        call PutCh
        ld a,(Song_Stereo)          ; стерео, таблица нот
        ld hl,Hd_Stereos
        ld b,3
        ld de,HD_STEREO_X+256*(HD_SCR_H+HD_TABS_Y)
        call Hd_Name
        ld a,(Song_Tuning)
        ld hl,Hd_Tunings
        ld b,7
        ld de,HD_TUNE_X+256*(HD_SCR_H+HD_ROW_FILE)
        call Hd_Name
        call Hd_Track               ; трек "1 2"
        call Hd_Buttons             ; кнопки [-][+]
        call Tr_State_Update        ; кнопки транспорта: нажата, активна, под мышью
        jp Hd_Hover                 ; подсветка поля под мышью


; Трек "1 2": выбранный - цветом активной вкладки, другой - как подписи
Hd_Track
        ld a,(Cur_Track)
        or a
        ld a,(THEME_ATTR+CLR_TOP_HI)    ; трек 1: выбран - яркий
        ld b,a
        ld a,(THEME_ATTR+CLR_TOP_TEXT)
        jr z,.put
        ld c,b                      ; трек 2: цвета наоборот
        ld b,a
        ld a,c
.put    ld c,b                      ; "1" - цветом B
        ld b,a                      ; "2" - цветом A
        ld de,HD_TRK_X+256*(HD_SCR_H+HD_TABS_Y)
        ld a,'1'
        call PutCh
        inc e
        ld c,b
        ld a,'2'
        jp PutCh

; Кнопка A ([-] / [+], 2 знакоместа) цветом кнопок шапки CLR_TOP_BTN. E += 2
PutBtn_Top
        push bc
        ld b,a
        ld a,(THEME_ATTR+CLR_TOP_BTN)
        jp Pb_Draw

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
        call PutBtn_Top
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
        FIELD HD_CHIP_X,   HD_ROW_FILE,9,1, FF_HAND, Hd_Field, 0, 10          ; тип чипа - по кругу
        FIELD HD_CHAN_X,   HD_ROW_EDIT,3,1, FF_HAND, Hd_Field, 0, 20          ; 3 / 6 каналов
        FIELD HD_STEREO_X, HD_TABS_Y,  3,1, FF_HAND, Hd_Field, 0, 11          ; стерео - по кругу
        FIELD HD_ENVNOTE_L,HD_ROW_EDIT,HD_ENVNOTE_X-HD_ENVNOTE_L+1,1, FF_HAND, Hd_Field, 0, 12 ; Env as Note
        FIELD HD_AUTO_L,   HD_ROW_EDIT,HD_AUTO_X-HD_AUTO_L+1,1, FF_HAND, Hd_Field, 0, 13       ; Auto Env
        FIELD HD_STEP_L,   HD_ROW_EDIT,HD_STEPCHK_X-HD_STEP_L+1,1, FF_HAND, Hd_Field, 0, 14    ; шаг вкл/выкл
        FIELD HD_TRK_X,    HD_TABS_Y, 1,1, FF_HAND, Hd_Field, 0, 21          ; трек 1
        FIELD HD_TRK_X+2,  HD_TABS_Y, 1,1, FF_HAND, Hd_Field, 0, 22          ; трек 2
        FIELD HD_HELP_X,   HD_TABS_Y, 4,1, FF_HAND, Hd_Field, 0, 23          ; Help - пока ничего
        FIELD HD_ABOUT_X,  HD_TABS_Y, 5,1, FF_HAND, Hd_Field, 0, 23          ; About - пока ничего
        FIELD HD_TABS_X+21,HD_TABS_Y, 4,1, FF_HAND, Hd_Field, 0, 24          ; вкладка Disk
Tr_Fields                           ; кнопки транспорта (спрайты Tr_*), подряд
        FIELD HD_PLAY_X,   HD_PLAY_Y, 4,2, FF_HAND, Hd_Field, 0, 15          ; ⇄ паттерн по кругу (F8)
        FIELD HD_PLAY_X+4, HD_PLAY_Y, 4,2, FF_HAND, Hd_Field, 0, 16          ; |◀ сонг с начала (F6)
        FIELD HD_PLAY_X+8, HD_PLAY_Y, 4,2, FF_HAND, Hd_Field, 0, 17          ; ▶ сонг с позиции (F5)
        FIELD HD_PLAY_X+12,HD_PLAY_Y, 4,2, FF_HAND, Hd_Field, 0, 18          ; ▷ паттерн с роу (F7)
        FIELD HD_PLAY_X+16,HD_PLAY_Y, 4,2, FF_HAND, Hd_Field, 0, 19          ; ■ стоп (Esc)
Head_Fields_End
        db FLD_END

Hd_Act  dw H_SpdDn, H_SpdUp, H_OctDn, H_OctUp, H_StepDn, H_StepUp
        dw H_LenDn, H_LenUp, H_RatUp
        dw H_Tune, H_Chip, H_Stereo, K_EnvNote, H_AutoEnv, H_AutoStep
        dw K_PlayPat, K_PlayStart, K_PlaySong, K_PlayPatRow, K_Stop
        dw H_Chips, H_Trk1, H_Trk2, Hd_Nop, H_TabDisk

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
H_Trk1  xor a                       ; трек в шапке (второй в памяти - потом)
        ld (Cur_Track),a
        ret
H_Trk2  ld a,1
        ld (Cur_Track),a
Hd_Nop  ret                         ; Help, About - пока ничего
H_TabDisk                           ; вкладка Disk: выйти из вида в тулзу диска
        ld a,PAGE_TOOL_DISK
        ld (SV_TOOL),a
        ld a,1
        ld (Pv_Exit),a
        ret
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
; КНОПКИ ТРАНСПОРТА - СПРАЙТЫ 16x16 (4 знакоместа x 2 строки - квадрат: пиксель
; спрайта вдвое уже знакоместа). Выпуклые: светлая кромка сверху-слева, тёмная
; снизу-справа. Состояния (каждый кадр, Tr_State_Update):
;   нажата  - держат мышь над ней: кромки наоборот, значок на точку вниз-вправо;
;   активна - режим играет: ▶ - сонг, ⇄ - паттерн (у остальных, у ■ - нет);
;   под мышью - грань светлее; иначе - обычная.
; Графика рисуется при старте (Head_Sprites) в страницу спрайтов, ряд тайлов 2
; (строки 16..31), наборы рядом:
; обычные с байта 0, под мышью - 40, нажатые - 80, активные - 120 (по 5 кнопок
; по 8 байт). Тайл кнопки k в наборе v = 2*64 + v*10 + 2k.
; Описатели - SFILE, записи 0..4; стрелка мыши - запись 5 (позже - поверх).
; =========================================================================
TR_BUTTONS      equ 5
TR_ROW          equ 2               ; ряд тайлов
TR_SET_W        equ TR_BUTTONS*8    ; байт на набор в строке битмапа
TR_PAL          equ #D0             ; палитра 13 (как у текста и стрелки)
TR_SFILE_SLOT   equ 0               ; записи SFILE кнопок 0..4; стрелка мыши - 5
TRV_NORMAL      equ 0               ; наборы (v)
TRV_HOVER       equ 1
TRV_PRESSED     equ 2
TRV_ACTIVE      equ 3
TR_K_LOOP       equ 0               ; кнопки (k)
TR_K_PLAY       equ 2

;-------- Раз при старте: 4 набора кнопок рисуются в страницу спрайтов, описатели - в SFILE.
; Кнопка: грань, кромки (светлая сверху-слева, тёмная снизу-справа; нажата - наоборот),
; углы прозрачные, значок 8x8 с точки (4,4) (нажата - (5,5))
TG_LIGHT        equ #B              ; светлая кромка
TG_DARK         equ #1              ; тёмная кромка
TG_INK          equ #1              ; значок

; Наборы по порядку TRV_*: грань, нажата
Tr_Sets db #9,0                     ; обычная: серая
        db #6,0                     ; под мышью: светлее
        db #9,1                     ; нажата
        db #D,0                     ; активна (играет): зелёная

; Значки 8x8, бит 7 - левая точка: ⇄, |◀, ▶, ▷, ■
Tr_Icons
        db %00000100,%11111111,%00000100,%00000000,%00000000,%00100000,%11111111,%00100000
        db %01000010,%01000110,%01001110,%01011110,%01011110,%01001110,%01000110,%01000010
        db %00100000,%00110000,%00111000,%00111100,%00111100,%00111000,%00110000,%00100000
        db %00100000,%00110000,%00101000,%00100100,%00100100,%00101000,%00110000,%00100000
        db %00000000,%01111110,%01111110,%01111110,%01111110,%01111110,%01111110,%00000000

Tg_Face db 0                        ; цвет грани набора
Tg_Press db 0                       ; 1 - нажатый набор
Tg_R    db 0                        ; строка кнопки 0..15
Tg_M    dw 0                        ; строка значка по колонкам 0..15 (бит 15 - колонка 0)

Head_Sprites
        SETPAGE3 PAGE_SPRITE
        ld hl,Tr_Sets
        ld de,#C000+TR_ROW*8*256    ; E - байт кнопки в строке битмапа
        ld b,4
.set    push bc
        ld a,(hl)                   ; набор: грань, нажата
        ld (Tg_Face),a
        inc hl
        ld a,(hl)
        ld (Tg_Press),a
        inc hl
        push hl
        ld hl,Tr_Icons
        ld b,TR_BUTTONS
.btn    push bc
        call Tg_Button
        pop bc
        djnz .btn
        pop hl
        pop bc
        djnz .set
        RESTPAGE3
        jp Tr_Send

; Кнопка 16x16: HL - значок (8 байт), DE - её левый верхний байт. HL += 8, E += 8
Tg_Button
        push de
        xor a
.row    ld (Tg_R),a
        call Tg_Mask
        ld c,0                      ; C - колонка
.byte   call Tg_Pix                 ; левая точка - старший полубайт
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        inc c
        call Tg_Pix                 ; правая - младший
        or b
        ld (de),a
        inc e
        inc c
        ld a,c
        cp 16
        jr c,.byte
        ld a,e                      ; в начало кнопки, следующая строка (256 байт)
        sub 8
        ld e,a
        inc d
        ld a,(Tg_R)
        inc a
        cp 16
        jr c,.row
        pop de
        ld a,e                      ; следующая кнопка - правее на 8 байт
        add a,8
        ld e,a
        ld bc,8
        add hl,bc
        ret

; Строка значка для строки Tg_R -> Tg_M (сдвинута на колонку 4, нажатая - 5)
Tg_Mask
        push hl
        ld a,(Tg_Press)
        ld b,a
        ld a,(Tg_R)
        sub 4
        sub b                       ; строка значка: r - 4 - P
        ld c,0
        cp 8                        ; вне 0..7 - пусто
        jr nc,.put
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld c,(hl)
.put    ld h,c                      ; колонки 0..7 ...
        ld l,0
        ld a,4                      ; ... -> 4+P..11+P
        add a,b
        ld b,a
.sh     srl h
        rr l
        djnz .sh
        ld (Tg_M),hl
        pop hl
        ret

; Цвет точки (Tg_R, C) -> A. Звать подряд по колонкам 0..15 (берёт бит из Tg_M).
; B не трогает
Tg_Pix
        push hl
        ld hl,(Tg_M)                ; бит значка этой колонки - в CF
        add hl,hl
        ld (Tg_M),hl
        ld a,TG_INK
        jr c,.ret
        ld a,(Tg_R)
        or a
        jr z,.top
        cp 15
        jr z,.bot
        ld a,c
        or a
        jr z,.lt
        cp 15
        jr z,.dk
        ld a,(Tg_Face)              ; внутри - грань
        jr .ret
.top    ld a,c                      ; верх: углы прозрачные
        or a
        jr z,.ret
        cp 15
        jr nz,.lt
.zero   xor a
        jr .ret
.bot    ld a,c                      ; низ: углы прозрачные
        or a
        jr z,.zero
        cp 15
        jr z,.zero
.dk     ld a,(Tg_Press)             ; низ, право: тёмная, нажата - светлая
        or a
        ld a,TG_DARK
        jr z,.ret
        ld a,TG_LIGHT
        jr .ret
.lt     ld a,(Tg_Press)             ; верх, лево: светлая, нажата - тёмная
        or a
        ld a,TG_LIGHT
        jr z,.ret
        ld a,TG_DARK
.ret    pop hl
        ret

;-------- Каждый кадр (Head_Show): состояние каждой кнопки -> её тайл; сменилось -
; описатели заново в SFILE
Tr_Chg          db 0                ; 1 - тайл какой-то кнопки сменился
Tr_Hv           db 0                ; 1 - кнопка под мышью

Tr_State_Update
        xor a
        ld (Tr_Chg),a
        ld ix,Tr_Fields             ; IX - поле кнопки
        ld iy,Tr_SAT+4              ; IY - тайл в её описателе
        ld c,0                      ; C - номер кнопки
.k      push ix                     ; под мышью?
        pop hl
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        ld a,0
        jr nz,$+3
        inc a
        ld (Tr_Hv),a
        push ix                     ; нажата: на ней нажали и мышь над ней
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        jr nz,.act
        ld a,(Tr_Hv)
        or a
        ld a,TRV_PRESSED
        jr nz,.tile
.act    ld a,(SV_PLAY_STATE)        ; активна: ▶ - играет сонг, ⇄ - паттерн
        ld e,a
        ld a,c
        cp TR_K_PLAY
        jr nz,.loop
        ld a,e
        cp PS_SONG
        jr .isact
.loop   cp TR_K_LOOP
        jr nz,.hov
        ld a,e
        cp PS_PATTERN
.isact  ld a,TRV_ACTIVE
        jr z,.tile
.hov    ld a,(Tr_Hv)                ; под мышью - 1, иначе 0 (TRV_HOVER / TRV_NORMAL)
.tile   ld e,a                      ; тайл = TR_ROW*64 + v*10 + 2k
        add a,a
        add a,a
        add a,e
        add a,a
        add a,TR_ROW*64
        add a,c
        add a,c
        cp (iy+0)
        jr z,.same
        ld (iy+0),a
        ld a,1
        ld (Tr_Chg),a
.same   ld de,6
        add iy,de
        ld de,FLD_SIZE
        add ix,de
        inc c
        ld a,c
        cp TR_BUTTONS
        jr c,.k
        ld a,(Tr_Chg)
        or a
        ret z
; Описатели кнопок - в SFILE (DMA, из основного цикла)
Tr_Send
        ld hl,Tr_Dma
        jp set_ports

; Описатели (SFILE: Y, флаги Y, X, флаги X, тайл, палитра | тайл ст.)
        ALIGN 2
Tr_SAT
.k = 0
        DUP TR_BUTTONS
        db HD_PLAY_Y*8, SP_ACT|SP_SIZE16, (HD_PLAY_X+.k*4)*4, SP_SIZE16, TR_ROW*64+.k*2, TR_PAL
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

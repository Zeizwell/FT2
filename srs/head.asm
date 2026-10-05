; =========================================================================
; ШАПКА (строки 0..6 над паттерном) - вариант 1, согласован с пользователем:
;   строка 0: вкладки экранов, транспорт, время игры;
;   Song (трек): имя, автор, скорость, таблица нот, вывод (чип), стерео;
;   Edit (как пишем в паттерн): октава, шаг, длина паттерна, Env as Note,
;   автоогибающая и её соотношение.
; Рамки и подписи рисуются раз (Head_Draw), значения - каждый кадр (Head_Show).
; Кнопки [-][+] и значения - поля (srs/fields.asm), список Head_Fields.
; Значения трека - копии из страницы трека (Song_*), меняются - Hd_Save пишет туда.
; =========================================================================

; --- колонки и строки (по рисунку варианта 1)
HD_TABS_Y       equ 0
HD_PLAY_X       equ 52              ; ►Song ►Pat ►Row ■
HD_TIME_X       equ 72              ; время игры "mm:ss"
HD_BOX_Y        equ 1               ; рамки блоков: строки 1..6
HD_BOX_H        equ 6
HD_SONG_X       equ 0               ; блок Song: колонки 0..44
HD_EDIT_X       equ 45              ; блок Edit: колонки 45..89
HD_BOX_W        equ 45
HD_NAME_Y       equ 2               ; Song
HD_NAME_X       equ 2
HD_AUTH_Y       equ 3
HD_AUTH_X       equ 5
HD_SPEED_Y      equ 4
HD_SPEED_X      equ 8               ; значение; [-][+] - сразу за ним
HD_TUNE_X       equ 31              ; значение таблицы нот (7 знаков)
HD_CHIP_Y       equ 5
HD_CHIP_X       equ 7               ; значение вывода (10 знаков)
HD_STEREO_X     equ 31              ; значение стерео (3 знака)
HD_OCT_Y        equ 2               ; Edit
HD_OCT_X        equ 54
HD_STEP_X       equ 67
HD_LEN_X        equ 80
HD_ENV_Y        equ 3
HD_ENVNOTE_X    equ 58              ; галочка Env as Note
HD_AUTO_X       equ 70              ; галочка Auto Env
HD_RATIO_X      equ 72              ; соотношение "1:1"

; --- значения
Song_Speed      db 3
Song_Tuning     db 0
Song_Device     db 1                ; TurboSound
Song_Stereo     db 0
Cur_Octave      db 4
Auto_Env        db 0
Auto_Ratio      db 0                ; номер в Hd_Ratios
TUNINGS         equ 2
DEVICES         equ 4
STEREOS         equ 3
RATIOS          equ 8

; Названия - по фиксированной ширине
Hd_Tunings      db "1.75MHz"
                db "Classic"
Hd_Devices      db "AY        "
                db "TurboSound"
                db "AYX-32    "
                db "FT2 board "
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
        ld a,(Song_Stereo)
        ld (#8000+SH_STEREO),a
        ld a,(Cur_Step)
        ld (#8000+SH_STEP),a
        RESTPAGE2
        ret

; =========================================================================
; РИСОВАНИЕ
; =========================================================================
;-------- Раз при старте: вкладки, транспорт, рамки, подписи, кнопки
Head_Draw
        ld hl,Hd_Static             ; строки: строка, колонка, роль цвета, текст, 0
.s      ld a,(hl)                   ; конец - #FF
        cp #FF
        jr z,.boxes
        add a,SCR_BASE_H
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
.boxes  ld e,HD_SONG_X              ; рамки блоков
        ld hl,Txt_Hd_Song
        call Hd_Box
        ld e,HD_EDIT_X
        ld hl,Txt_Hd_Edit
        call Hd_Box
        ld ix,Head_Fields           ; кнопки: поля с обработчиком Hb_Field
.b      ld a,(ix+FLD_X)
        cp FLD_END
        ret z
        ld l,(ix+FLD_HANDLER)
        ld h,(ix+FLD_HANDLER+1)
        ld de,Hb_Field
        or a
        sbc hl,de
        jr nz,.nb
        xor a                       ; отпущенная
        call Hb_Show
.nb     ld de,FLD_SIZE
        add ix,de
        jr .b

; Рамка блока: E - колонка, HL - заголовок. Строки HD_BOX_Y..+HD_BOX_H-1,
; ширина HD_BOX_W
Hb_X0           db 0

Hd_Box
        ld a,e
        ld (Hb_X0),a
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld d,SCR_BASE_H+HD_BOX_Y    ; верх: ┌Заголовок────┐
        ld a,BOX_TL
        call PutCh
        call PutStr
        ld a,(Hb_X0)                ; линия до правого угла
        add a,HD_BOX_W-1
        ld b,a
.top    ld a,e
        cp b
        jr nc,.tr
        ld a,BOX_H
        call PutCh
        jr .top
.tr     ld a,BOX_TR
        call PutCh
        ld b,HD_BOX_H-2             ; бока
.side   inc d
        ld a,(Hb_X0)
        ld e,a
        ld a,BOX_V
        call PutCh
        ld a,(Hb_X0)
        add a,HD_BOX_W-1
        ld e,a
        ld a,BOX_V
        call PutCh
        djnz .side
        inc d                       ; низ: └─────┘
        ld a,(Hb_X0)
        ld e,a
        ld a,BOX_BL
        call PutCh
        ld b,HD_BOX_W-2
.bot    ld a,BOX_H
        call PutCh
        djnz .bot
        ld a,BOX_BR
        jp PutCh

; Статика: строка, колонка, роль цвета, текст, 0. Конец - #FF
Hd_Static
        db HD_TABS_Y,1,CLR_ORD_CUR,"Pattern",0
        db HD_TABS_Y,10,CLR_HEADER,"Instr",0
        db HD_TABS_Y,17,CLR_HEADER,"Orn",0
        db HD_TABS_Y,22,CLR_HEADER,"FX",0
        db HD_TABS_Y,26,CLR_HEADER,"Disk",0
        db HD_TABS_Y,32,CLR_HEADER,"Setup",0
        db HD_TABS_Y,HD_PLAY_X,CLR_BUTTON,ARROW_R,"Song",0
        db HD_TABS_Y,HD_PLAY_X+6,CLR_BUTTON,ARROW_R,"Pat",0
        db HD_TABS_Y,HD_PLAY_X+11,CLR_BUTTON,ARROW_R,"Row",0
        db HD_TABS_Y,HD_PLAY_X+16,CLR_BUTTON,#FE,0      ; ■ (CP866)
        db HD_NAME_Y,HD_NAME_X,CLR_EMPTY,"................................",0
        db HD_AUTH_Y,HD_NAME_X,CLR_HEADER,"by",0
        db HD_AUTH_Y,HD_AUTH_X,CLR_EMPTY,"................................",0
        db HD_SPEED_Y,2,CLR_HEADER,"Speed",0
        db HD_SPEED_Y,24,CLR_HEADER,"Tuning",0
        db HD_CHIP_Y,2,CLR_HEADER,"Chip",0
        db HD_CHIP_Y,24,CLR_HEADER,"Stereo",0
        db HD_OCT_Y,47,CLR_HEADER,"Octave",0
        db HD_OCT_Y,62,CLR_HEADER,"Step",0
        db HD_OCT_Y,76,CLR_HEADER,"Len",0
        db HD_ENV_Y,47,CLR_HEADER,"Env as Note",0
        db HD_ENV_Y,62,CLR_HEADER,"Auto Env",0
        db #FF

Txt_Hd_Song     db "Song",0
Txt_Hd_Edit     db "Edit",0

;-------- Каждый кадр: значения
Head_Show
        ld a,(THEME_ATTR+CLR_PATNUM)
        ld c,a
        ld a,(SV_PLAY_STATE)        ; скорость: играет - плеера, иначе трека
        or a
        ld a,(SV_PLAY_SPEED)
        jr nz,$+5
        ld a,(Song_Speed)
        ld de,HD_SPEED_X+256*(SCR_BASE_H+HD_SPEED_Y)
        call PutHex2
        ld a,(Song_Tuning)          ; таблица нот: 7 знаков
        ld hl,Hd_Tunings
        ld b,7
        ld de,HD_TUNE_X+256*(SCR_BASE_H+HD_SPEED_Y)
        call Hd_Name
        ld a,(Song_Device)          ; вывод: 10 знаков
        ld hl,Hd_Devices
        ld b,10
        ld de,HD_CHIP_X+256*(SCR_BASE_H+HD_CHIP_Y)
        call Hd_Name
        ld a,(Song_Stereo)          ; стерео: 3 знака
        ld hl,Hd_Stereos
        ld b,3
        ld de,HD_STEREO_X+256*(SCR_BASE_H+HD_CHIP_Y)
        call Hd_Name
        ld a,(Cur_Octave)           ; октава: 1 цифра
        add a,'0'
        ld de,HD_OCT_X+256*(SCR_BASE_H+HD_OCT_Y)
        call PutCh
        ld a,(Cur_Step)             ; шаг
        ld de,HD_STEP_X+256*(SCR_BASE_H+HD_OCT_Y)
        call PutHex2
        ld a,(Cur_Pos)              ; длина паттерна текущей позиции
        ld hl,Test_Order
        call Arr_Get
        ld hl,Pat_Len
        call Arr_Get
        ld de,HD_LEN_X+256*(SCR_BASE_H+HD_OCT_Y)
        call PutHex2
        ld a,(Auto_Ratio)           ; соотношение автоогибающей
        ld hl,Hd_Ratios
        ld b,3
        ld de,HD_RATIO_X+256*(SCR_BASE_H+HD_ENV_Y)
        call Hd_Name
        ld a,(Env_As_Note)          ; галочки
        ld de,HD_ENVNOTE_X+256*(SCR_BASE_H+HD_ENV_Y)
        call Hd_Check
        ld a,(Auto_Env)
        ld de,HD_AUTO_X+256*(SCR_BASE_H+HD_ENV_Y)
        call Hd_Check
        ld a,(THEME_ATTR+CLR_HEADER) ; время игры mm:ss
        ld c,a
        ld de,HD_TIME_X+256*(SCR_BASE_H+HD_TABS_Y)
        ld hl,Tm_Min
        ld a,(hl)
        call Hd_Dec2
        ld a,':'
        call PutCh
        ld a,(Tm_Sec)
        jp Hd_Dec2

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
; ПОЛЯ ШАПКИ
; =========================================================================
; Параметр поля - номер действия (Hd_Act). У кнопок ещё вид: чётные - [-], нечётные - [+]
HA_SPD_DN       equ 0
HA_TUNE         equ 10

Head_Fields
        FIELD HD_SPEED_X+2,HD_SPEED_Y,2,1, 0, Hb_Field, 0, 0   ; Speed -
        FIELD HD_SPEED_X+4,HD_SPEED_Y,2,1, 0, Hb_Field, 0, 1   ;       +
        FIELD HD_OCT_X+1,  HD_OCT_Y,  2,1, 0, Hb_Field, 0, 2   ; Octave -
        FIELD HD_OCT_X+3,  HD_OCT_Y,  2,1, 0, Hb_Field, 0, 3   ;        +
        FIELD HD_STEP_X+2, HD_OCT_Y,  2,1, 0, Hb_Field, 0, 4   ; Step -
        FIELD HD_STEP_X+4, HD_OCT_Y,  2,1, 0, Hb_Field, 0, 5   ;      +
        FIELD HD_LEN_X+2,  HD_OCT_Y,  2,1, 0, Hb_Field, 0, 6   ; Len -
        FIELD HD_LEN_X+4,  HD_OCT_Y,  2,1, 0, Hb_Field, 0, 7   ;     +
        FIELD HD_RATIO_X+3,HD_ENV_Y,  2,1, 0, Hb_Field, 0, 8   ; соотношение -
        FIELD HD_RATIO_X+5,HD_ENV_Y,  2,1, 0, Hb_Field, 0, 9   ;             +
        FIELD HD_TUNE_X,   HD_SPEED_Y,7,1, 0, Hv_Field, 0, 10  ; таблица нот - по кругу
        FIELD HD_CHIP_X,   HD_CHIP_Y,10,1, 0, Hv_Field, 0, 11  ; вывод - по кругу
        FIELD HD_STEREO_X, HD_CHIP_Y, 3,1, 0, Hv_Field, 0, 12  ; стерео - по кругу
        FIELD HD_ENVNOTE_X,HD_ENV_Y,  1,1, 0, Hv_Field, 0, 13  ; Env as Note
        FIELD HD_AUTO_X,   HD_ENV_Y,  1,1, 0, Hv_Field, 0, 14  ; Auto Env
        FIELD HD_PLAY_X,   HD_TABS_Y, 5,1, 0, Hv_Field, 0, 15  ; ►Song
        FIELD HD_PLAY_X+6, HD_TABS_Y, 4,1, 0, Hv_Field, 0, 16  ; ►Pat
        FIELD HD_PLAY_X+11,HD_TABS_Y, 4,1, 0, Hv_Field, 0, 17  ; ►Row
        FIELD HD_PLAY_X+16,HD_TABS_Y, 1,1, 0, Hv_Field, 0, 18  ; ■
        db FLD_END

Hd_Act  dw H_SpdDn, H_SpdUp, H_OctDn, H_OctUp, H_StepDn, H_StepUp
        dw H_LenDn, H_LenUp, H_RatDn, H_RatUp
        dw H_Tune, H_Chip, H_Stereo, K_EnvNote, H_AutoEnv
        dw K_PlaySong, K_PlayPat, K_PlayPatRow, K_Stop

;-------- Кнопка [-]/[+]: нажал - вдавлена, увёл мышь - отжалась, отпустил над ней -
; действие (как Btn_Field)
Hb_Field
        cp EV_PRESS
        ld b,1
        jr z,Hb_Show_A
        cp EV_RELEASE
        ld b,0
        jr z,Hb_Show_A
        cp EV_CLICK
        jr z,Hd_Do
        ld b,0                      ; держат и мышь ушла / вернулась
        cp EV_HOVER_OUT
        jr z,.held
        cp EV_HOVER_IN
        ret nz
        ld b,1
.held   push ix
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ret nz
Hb_Show_A
        ld a,b
; Кнопка поля IX: A=1 - вдавлена, 0 - обычная
Hb_Show
        ld b,a
        ld a,(ix+FLD_Y)
        add a,SCR_BASE_H
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
        jp PutBtn

;-------- Значение (по кругу), галочка, транспорт: клик - действие
Hv_Field
        cp EV_CLICK
        ret nz
; Действие поля IX (Hd_Act[параметр])
Hd_Do
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
H_RatDn ld hl,Auto_Ratio            ; соотношение по кругу назад
        ld a,(hl)
        or a
        jr nz,$+4
        ld a,RATIOS
        dec a
        ld (hl),a
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
H_AutoEnv
        ld hl,Auto_Env
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

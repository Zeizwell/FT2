; =========================================================================
; РЕДАКТОР FX (реворк FX, doc/fx-row.md). Шаг 2: только отрисовка из данных, раскладка - как в
; макете (srs/fxmaket.asm). Данные: строки - страница Trk_Fx, заголовки и таблицы - Trk_FxT,
; имена - страница трека (SONG_FX_NAMES). Текущий FX - Iv_Num, подвкладка - Fx_Sub.
; Окно 2 у тулзы занято страницей инструментов - чужие страницы ставим на время копии (Fe_Copy).
; =========================================================================
FE_LIST_ROWS    equ 4               ; список FX: строк (колонки 1..17, скролл - 18)
FE_MID          equ 21              ; средний блок: имя, Len / Loop, свип, подвкладки
FE_BTN          equ 62              ; кнопки
FE_CAP          equ IV_TOP+6        ; заголовки колонок (под линией шапки)
FE_ROW0         equ IV_TOP+7        ; первая строка FX
FE_ROWS         equ TL_LAST-1-FE_ROW0   ; строк FX на экране (до нижней рамки)
; колонки строки: Mix
FE_RW           equ 1               ; номер строки (hex)
FE_LP           equ 3               ; L - строка цикла
FE_MIX          equ 5               ; ---, SID, Buz
FE_MAX          equ 9               ; скважность max / min (4 знака)
FE_MIN          equ 14
FE_SWP          equ 19              ; скорость свипа (3)
FE_SEMI         equ 23              ; детюн: полутоны, сырой (по 4)
FE_DET          equ 29
FE_LN           equ 35              ; длина (2)
FE_STEPS        equ 39              ; шаги: hex-цифра и пробел
; колонки строки: FM / Env FM
FE_ON           equ 4               ; on / --
FE_FSEMI        equ 7               ; детюн: полутоны, сырой (по 4)
FE_FDET         equ 12
FE_UNIT         equ 17              ; semi / per
FE_FLN          equ 22              ; длина (2)
FE_FSTEPS       equ 25              ; шаги по 4 знака: semi - "+12", per - "+0C"

Fe_Hdr          ds FXH_SIZE         ; заголовок текущего FX
Fe_Name         ds 17               ; имя (16 и 0)
Fe_Row          ds FXR_SIZE         ; строка, которую рисуем
Fe_Tab          ds FXT_SIZE         ; её таблица
Fe_Len          dw 0
Fe_LTop         db 0                ; список FX: первая видимая
Fe_Rn           db 0                ; номер рисуемой строки
Fe_Ln           db 0                ; её длина (шагов)
Fe_Off          db 0                ; FM / Env FM: смещение полей в строке (FXR_FM / FXR_EFM)
Fe_OnBit        db 0                ;   маска "вкл" в FXR_FLAGS
Fe_PerBit       db 0                ;   маска "в единицах периода"

;-------- Неизменное - один раз при входе в FX: рамка, заголовок, кнопки, черты блоков
Fe_Frame
        xor a                       ; общая рамка тулзы, внутри - пробелы
        ld (Bx_X),a
        ld a,90
        ld (Bx_W),a
        call Tool_Box
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,2+256*(IV_SCR_H+IV_TOP)
        ld hl,Txt_FxmTitle
        call PutStr
        call Fe_Btns
        jp Fxm_Lines_Hd

;-------- Содержимое (по изменению, Iv_Dirty): список, средний блок, строки. Рамку не трогает
Fe_Draw
        call Fe_Load
        call Fe_List
        call Fe_Mid
        jp Fe_Rows

;-------- A - страница, HL - откуда (окно 2), DE - куда, BC - сколько. SETPAGE портит BC
Fe_Copy
        ld (Fe_Len),bc
        SETPAGE2 a
        ld bc,(Fe_Len)
        ldir
        RESTPAGE2
        ret

;-------- Заголовок и имя текущего FX -> Fe_Hdr, Fe_Name
Fe_Load
        ld a,(Iv_Num)               ; заголовок: FXH_BASE + n*8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#8000+FXH_BASE
        add hl,de
        ld de,Fe_Hdr
        ld bc,FXH_SIZE
        ld a,(Trk_FxT)
        call Fe_Copy
        ld a,(Fe_Hdr+FXH_END)       ; строк не больше 32
        and FX_ROWS_MAX-1
        ld (Fe_Hdr+FXH_END),a
        ld a,(Iv_Num)
        ld de,Fe_Name
; A - номер FX, DE - куда: имя (16 знаков) и 0
Fe_Get_Name
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,#8000+SONG_FX_NAMES
        add hl,de
        pop de
        push de
        ld bc,16
        ld a,(SV_SONG_PAGE)
        call Fe_Copy
        pop hl
        ld bc,16
        add hl,bc
        ld (hl),0
        ret
    ASSERT FXH_SIZE == 8

;-------- A - строка текущего FX -> Fe_Row (адрес: n*512 + r*16)
Fe_Get_Row
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(Iv_Num)
        add a,a
        add a,#80
        add a,h
        ld h,a
        ld de,Fe_Row
        ld bc,FXR_SIZE
        ld a,(Trk_Fx)
        jp Fe_Copy
    ASSERT FXR_BLOCK == 512

;-------- A - номер таблицы -> Fe_Tab
Fe_Get_Tab
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        set 7,h
        ld de,Fe_Tab
        ld bc,FXT_SIZE
        ld a,(Trk_FxT)
        jp Fe_Copy

; =========================================================================
; ШАПКА
; =========================================================================
;-------- Список FX: 4 строки "nn имя", текущий - цветом выделения; справа ^ █ v
Fe_List
        ld a,(Iv_Num)               ; текущий - в видимых строках
        ld hl,Fe_LTop
        cp (hl)
        jr nc,.lo
        ld (hl),a
.lo     sub FE_LIST_ROWS-1
        jr c,.ok
        cp (hl)
        jr c,.ok
        ld (hl),a
.ok     ld b,0                      ; строка списка
.row    push bc
        ld a,b
        add a,IV_SCR_H+IV_TOP+1
        ld d,a
        ld e,1
        ld a,(Fe_LTop)
        add a,b
        ld (Fe_Rn),a
        ld hl,Iv_Num
        cp (hl)
        ld a,(THEME_ATTR+CLR_ED_VAL)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld a,(Fe_Rn)                ; номер 01..32
        inc a
        call Dec2
        ld a,' '
        call PutCh
        push de
        ld a,(Fe_Rn)                ; имя - 14 знаков
        ld de,Fe_LName
        call Fe_Get_Name
        pop de
        ld hl,Fe_LName
        ld b,14
        call Put_Name
        pop bc
        push bc
        ld a,(THEME_ATTR+CLR_ED_OFF) ; скролл: ^ сверху, v снизу, █ - где текущий
        ld c,a
        ld a,b
        or a
        ld a,'^'
        jr z,.sc
        ld a,b
        cp FE_LIST_ROWS-1
        ld a,'v'
        jr z,.sc
        ld a,(Iv_Num)               ; ползунок: строка 1 - первая половина, 2 - вторая
        cp FXS_MAX/2               ;   (C - первая половина)
        ld a,2
        sbc a,0
        cp b
        ld a,' '
        jr nz,.sc
        ld a,#DB
.sc     call PutCh
        pop bc
        inc b
        ld a,b
        cp FE_LIST_ROWS
        jr c,.row
        ret

;-------- Средний блок: Name, Len / Loop, свип, подвкладки
Fe_Mid
        ld a,(THEME_ATTR+CLR_ED_CAP)
        ld c,a
        ld de,FE_MID+256*(IV_SCR_H+IV_TOP+1)
        ld hl,Txt_FeName
        call PutStr
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
        ld hl,Fe_Name
        ld b,16
        call Put_Name
        ld a,(THEME_ATTR+CLR_ED_CAP) ; Len -nn+   Loop -nn+
        ld c,a
        ld de,FE_MID+256*(IV_SCR_H+IV_TOP+2)
        ld hl,Txt_FeLen
        call PutStr
        ld a,(Fe_Hdr+FXH_END)
        inc a
        call Fe_Val2
        ld hl,Txt_FeLoop
        call PutStr
        ld a,(Fe_Hdr+FXH_LOOP)
        call Fe_Val2
        ld de,FE_MID+256*(IV_SCR_H+IV_TOP+3)  ; Sweep: Tri  Start -nnn+  Kp
        ld hl,Txt_FeSweep
        call PutStr
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
        ld a,(Fe_Hdr+FXH_SWSHAPE)
        call Fe_Shape
        ld a,(THEME_ATTR+CLR_ED_CAP)
        ld c,a
        ld hl,Txt_FeStart
        call PutStr
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
        ld a,(Fe_Hdr+FXH_SWPHASE)
        call Put_Dec3
        ld a,(THEME_ATTR+CLR_ED_CAP)
        ld c,a
        ld a,'+'
        call PutCh
        inc e
        inc e
        ld a,(Fe_Hdr+FXH_FLAGS)     ; Kp: включено - цветом выделения
        rrca
        ld a,(THEME_ATTR+CLR_ED_OFF)
        jr nc,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld hl,Txt_FeKp
        call PutStr
        ld de,FE_MID+256*(IV_SCR_H+IV_TOP+4)  ; [ Mix ]  [ FM ]  [ Env FM ]
        ld hl,Txt_FeSubs
        ld b,0
.sub    ld a,(Fx_Sub)
        cp b
        ld a,(THEME_ATTR+CLR_BUTTON)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        call PutStr
        inc hl
        inc e
        inc e
        inc b
        ld a,b
        cp 3
        jr c,.sub
        ret

;-------- "-nn+": A - число, значение цветом значений, -/+ - цветом подписей (C)
Fe_Val2
        push af
        ld a,'-'
        call PutCh
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld b,c
        ld c,a
        pop af
        push bc
        call Dec2
        pop bc
        ld c,b
        ld a,'+'
        jp PutCh

;-------- Форма свипа A (номер таблицы): пресет 1..5 - имя, иначе "Tnn" (hex)
Fe_Shape
        or a
        jr z,.t
        cp FXT_PRESETS
        jr nc,.t
        dec a
        ld l,a
        add a,a
        add a,l
        ld hl,Txt_FeShapes
        call Hl_Add_A
        ld b,3
.c      ld a,(hl)
        call PutCh
        inc hl
        djnz .c
        ret
.t      push af
        ld a,'T'
        call PutCh
        pop af
        jp PutHex2

;-------- Кнопки (справа): пока только надписи
Fe_Btns
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld de,FE_BTN+256*(IV_SCR_H+IV_TOP+1)
        ld hl,Txt_FeBtn1
        call PutStr
        ld de,FE_BTN+256*(IV_SCR_H+IV_TOP+2)
        ld hl,Txt_FeBtn2
        call PutStr
        ld de,FE_BTN+256*(IV_SCR_H+IV_TOP+3)
        ld hl,Txt_FeBtn3
        jp PutStr

; =========================================================================
; СТРОКИ FX
; =========================================================================
;-------- Заголовки колонок подвкладки и строки 0..последняя
Fe_Rows
        ld d,IV_SCR_H+FE_CAP
        call Fe_Clr_Row
        ld a,(THEME_ATTR+CLR_ED_CAP)
        ld c,a
        ld de,1+256*(IV_SCR_H+FE_CAP)
        ld a,(Fx_Sub)               ; заголовки: Mix / FM / Env FM
        ld hl,Txt_FeCapMix
        or a
        jr z,.cap
        ld hl,Txt_FeCapFm
        dec a
        jr z,.cap
        ld hl,Txt_FeCapEfm
.cap    call PutStr
        ld a,(Fx_Sub)               ; FM / Env FM: где поля и биты
        cp 2
        ld a,FXR_FM
        ld bc,(1<<FXRB_FMPER)*256+(1<<FXRB_FM)
        jr nz,.fm
        ld a,FXR_EFM
        ld bc,(1<<FXRB_EFMPER)*256+(1<<FXRB_EFM)
.fm     ld (Fe_Off),a
        ld a,c
        ld (Fe_OnBit),a
        ld a,b
        ld (Fe_PerBit),a
        xor a
.row    ld (Fe_Rn),a
        cp FE_ROWS                  ; все строки экрана
        ret nc
        add a,IV_SCR_H+FE_ROW0      ; строка - пустая (старое не остаётся)
        ld d,a
        call Fe_Clr_Row
        ld a,(Fe_Rn)                ; дальше последней строки FX - пусто
        ld hl,Fe_Hdr+FXH_END
        cp (hl)
        jr z,.go
        jr nc,.next
.go     call Fe_Get_Row
        ld a,(Fe_Rn)
        add a,IV_SCR_H+FE_ROW0
        ld d,a
        call Fe_Row_Head
        ld a,(Fx_Sub)
        or a
        call z,Fe_Mix_Row
        ld a,(Fx_Sub)
        or a
        call nz,Fe_Fm_Row
.next   ld a,(Fe_Rn)
        inc a
        jr .row

;-------- Строка экрана D - пробелы (колонки 1..88)
Fe_Clr_Row
        ld e,1
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
.c      ld a,' '
        call PutCh
        ld a,e
        cp 89
        jr c,.c
        ret

;-------- Номер строки (hex) и L у строки цикла. D - строка экрана
Fe_Row_Head
        ld e,FE_RW
        ld a,(THEME_ATTR+CLR_ED_ROW)
        ld c,a
        ld a,(Fe_Rn)
        call PutHex2
        ld a,(Fe_Rn)
        ld hl,Fe_Hdr+FXH_LOOP
        cp (hl)
        ret nz
        ld e,FE_LP
        ld a,(THEME_ATTR+CLR_ED_LOOP)
        ld c,a
        ld a,'L'
        jp PutCh

;-------- Строка Mix: тип, скважность max / min, свип, детюн, длина, шаги (hex)
Fe_Mix_Row
        ld e,FE_MIX
        ld a,(Fe_Row+FXR_FLAGS)
        and FXR_MIXMASK
        jr nz,.on
        ld a,(THEME_ATTR+CLR_ED_OFF) ; выключен - "---", остальное не рисуем
        ld c,a
        ld hl,Txt_FeOff3
        jp PutStr
.on     dec a                       ; SID / Buz / ???
        ld l,a
        add a,a
        add a,l
        ld hl,Txt_FeMix
        call Hl_Add_A
        ld a,(THEME_ATTR+CLR_ED_TYPE)
        ld c,a
        ld b,3
.t      ld a,(hl)
        call PutCh
        inc hl
        djnz .t
        ld a,(Fe_Row+FXR_LEN1)      ; длина: 1..16
        and 15
        inc a
        ld (Fe_Ln),a
        cp 2                        ; PWM и свип - только при 2 шагах
        ld a,(THEME_ATTR+CLR_ED_VAL)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_ED_OFF)
        ld c,a
        ld e,FE_MAX
        ld a,(Fe_Row+FXR_PWM)
        rrca
        rrca
        rrca
        rrca
        and 15
        call Put_Pct
        ld e,FE_MIN
        ld a,(Fe_Row+FXR_PWM)
        and 15
        call Put_Pct
        ld e,FE_SWP
        ld a,(Fe_Row+FXR_SWP)
        call Put_Dec3
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
        ld e,FE_SEMI
        ld a,(Fe_Row+FXR_MIX)
        call Put_SDec
        ld e,FE_DET
        ld a,(Fe_Row+FXR_MIX+1)
        call Put_SDec
        ld e,FE_LN
        ld a,(Fe_Ln)
        call Dec2
        push de
        ld a,(Fe_Row+FXR_MIX+2)     ; шаги - из таблицы
        call Fe_Get_Tab
        pop de
        ld e,FE_STEPS
        ld a,(THEME_ATTR+CLR_ED_STEP)
        ld c,a
        ld hl,Fe_Tab
        ld a,(Fe_Ln)
        ld b,a
.s      ld a,(hl)
        and 15
        call HexDigit
        call PutCh
        inc e
        inc hl
        djnz .s
        ret

;-------- Строка FM / Env FM (Fe_Off, Fe_OnBit, Fe_PerBit): вкл, детюн, единицы, длина, шаги
Fe_Fm_Row
        ld e,FE_ON
        ld a,(Fe_OnBit)
        ld hl,Fe_Row+FXR_FLAGS
        and (hl)
        jr nz,.on
        ld a,(THEME_ATTR+CLR_ED_OFF) ; выключен - "--"
        ld c,a
        ld hl,Txt_FeOff2
        jp PutStr
.on     ld a,(THEME_ATTR+CLR_ED_TYPE)
        ld c,a
        ld hl,Txt_FeOn
        call PutStr
        ld a,(THEME_ATTR+CLR_ED_VAL)
        ld c,a
        ld a,(Fe_Off)               ; детюн: полутоны, сырой
        ld hl,Fe_Row
        call Hl_Add_A
        ld e,FE_FSEMI
        ld a,(hl)
        push hl
        call Put_SDec
        pop hl
        inc hl
        ld e,FE_FDET
        ld a,(hl)
        push hl
        call Put_SDec
        pop hl
        inc hl
        ld a,(hl)                   ; номер таблицы
        ld (Fe_TabN),a
        ld e,FE_UNIT                ; единицы шагов: semi / per
        ld a,(Fe_PerBit)
        ld hl,Fe_Row+FXR_FLAGS
        and (hl)
        ld (Fe_Per),a
        ld hl,Txt_FeSemi
        jr z,$+5
        ld hl,Txt_FePer
        call PutStr
        ld a,(Fx_Sub)               ; длина: FM - LEN1 7..4, Env FM - LEN2 3..0
        cp 2
        ld a,(Fe_Row+FXR_LEN2)
        jr z,.l
        ld a,(Fe_Row+FXR_LEN1)
        rrca
        rrca
        rrca
        rrca
.l      and 15
        inc a
        ld (Fe_Ln),a
        ld e,FE_FLN
        call Dec2
        push de
        ld a,(Fe_TabN)              ; шаги - из таблицы
        call Fe_Get_Tab
        pop de
        ld e,FE_FSTEPS
        ld a,(THEME_ATTR+CLR_ED_STEP)
        ld c,a
        ld hl,Fe_Tab
        ld a,(Fe_Ln)
        ld b,a
.s      push hl
        push bc
        ld a,(Fe_Per)
        or a
        ld a,(hl)
        jr nz,.per
        call Put_SDec               ; полутоны - десятичные: "  +7", " +12"
        jr .nx
.per    call Fe_SHex                ; период - hex: " +0C"
.nx     pop bc
        pop hl
        inc hl
        djnz .s
        ret

;-------- A - байт со знаком -> " +0C" (4 знака, hex)
Fe_SHex
        ld l,a
        ld a,' '
        call PutCh
        ld a,l
        ld h,'+'
        or a
        jp p,.p
        ld h,'-'
        neg
.p      ld l,a
        ld a,h
        call PutCh
        ld a,l
        jp PutHex2

Fe_TabN         db 0
Fe_Per          db 0                ; не 0 - шаги в единицах периода
Fe_LName        ds 17               ; имя для списка

Txt_FeName      db "Name: ",0
Txt_FeLen       db "Len ",0
Txt_FeLoop      db "   Loop ",0
Txt_FeSweep     db "Sweep: ",0
Txt_FeStart     db "  Start -",0
Txt_FeKp        db "Kp",0
Txt_FeSubs      db "[ Mix ]",0,"[ FM ]",0,"[ Env FM ]",0
Txt_FeShapes    db "TriSinUp Dn Sqr"   ; таблицы 1..5 пресета
Txt_FeBtn1      db "[Clone] [Copy] [Paste]",0
Txt_FeBtn2      db "[Clear] [Unloop]",0
Txt_FeBtn3      db "[Save]  [Load]",0
Txt_FeCapMix    db "Rw  Mix  Max  Min Swp Semi   Det  Ln  Steps (hex)",0
Txt_FeCapFm     db "Rw FM Semi  Det Unit Ln Steps (semi - dec, per - hex)",0
Txt_FeCapEfm    db "Rw EF Semi  Det Unit Ln Steps (semi - dec, per - hex)",0
Txt_FeMix       db "SIDBuz???"
Txt_FeOff3      db "---",0
Txt_FeOff2      db "--",0
Txt_FeOn        db "on",0
Txt_FeSemi      db "semi",0
Txt_FePer       db "per ",0

; =========================================================================
; ПОЛЯ ШАПКИ FX (шаг 3а): выбор FX, Len / Loop, свип, Kp, подвкладки
; =========================================================================
;-------- Список: клик - выбрать, колесо - соседний
Fe_ListEv
        cp EV_WHEEL
        jr z,Fe_Wheel
        cp EV_PRESS
        ret nz
        ld a,(SV_MOUSE_ROW)         ; строка списка -> номер FX
        sub IV_TOP+1
        ret c
        cp FE_LIST_ROWS
        ret nc
        ld hl,Fe_LTop
        add a,(hl)
        jr Fe_SetNum
Fe_Wheel
        ld a,c                      ; вниз (C < 0) - следующий
        or a
        jp m,Fe_Next
Fe_Prev
        ld a,(Iv_Num)
        or a
        ret z
        dec a
        jr Fe_SetNum
Fe_Next
        ld a,(Iv_Num)
        inc a
        cp FXS_MAX
        ret nc
Fe_SetNum
        ld (Iv_Num),a
Fe_Dirty
        ld a,1
        ld (Iv_Dirty),a
        ret

;-------- Скролл списка: ^ - предыдущий, v - следующий, середина - к началу / ко второй половине
Fe_ScrEv
        cp EV_WHEEL
        jr z,Fe_Wheel
        cp EV_PRESS
        jr z,.p
        cp EV_REPEAT
        ret nz
.p      ld a,(SV_MOUSE_ROW)
        sub IV_TOP+1
        jr z,Fe_Prev
        cp FE_LIST_ROWS-1
        jr z,Fe_Next
        dec a                       ; 1 - первая половина, 2 - вторая
        ld a,0
        jr z,Fe_SetNum
        ld a,FXS_MAX/2
        jr Fe_SetNum

;-------- Заголовок FX: 0 Len-, 1 Len+, 2 Loop-, 3 Loop+, 4 форма свипа, 5 Start-, 6 Start+, 7 Kp
Fe_HdrEv
        cp EV_REPEAT                ; держат: повтор - только у +/-
        jr z,.rep
        cp EV_PRESS
        ret nz
        jr .go
.rep    ld a,(ix+FLD_PARAM)
        cp 4
        ret z
        cp 7
        ret z
.go     ld a,(ix+FLD_PARAM)
        or a
        jr z,.lenm
        dec a
        jr z,.lenp
        dec a
        jr z,.loopm
        dec a
        jr z,.loopp
        dec a
        jr z,.shape
        dec a
        jr z,.stm
        dec a
        jr z,.stp
        ld a,(Fe_Hdr+FXH_FLAGS)     ; Kp - переключить
        xor 1
        ld (Fe_Hdr+FXH_FLAGS),a
        jr Fe_Put_Hdr
.lenm   ld a,(Fe_Hdr+FXH_END)       ; Len - (цикл - не дальше конца)
        or a
        ret z
        dec a
        ld (Fe_Hdr+FXH_END),a
        ld hl,Fe_Hdr+FXH_LOOP
        cp (hl)
        jr nc,Fe_Put_Hdr
        ld (hl),a
        jr Fe_Put_Hdr
.lenp   ld a,(Fe_Hdr+FXH_END)       ; Len +
        cp FX_ROWS_MAX-1
        ret nc
        inc a
        ld (Fe_Hdr+FXH_END),a
        jr Fe_Put_Hdr
.loopm  ld a,(Fe_Hdr+FXH_LOOP)      ; Loop -
        or a
        ret z
        dec a
        ld (Fe_Hdr+FXH_LOOP),a
        jr Fe_Put_Hdr
.loopp  ld a,(Fe_Hdr+FXH_LOOP)      ; Loop + (до конца)
        ld hl,Fe_Hdr+FXH_END
        cp (hl)
        ret nc
        inc a
        ld (Fe_Hdr+FXH_LOOP),a
        jr Fe_Put_Hdr
.shape  ld a,(Fe_Hdr+FXH_SWSHAPE)   ; форма: Tri -> Sin -> Up -> Dn -> Sqr -> Tri
        inc a
        cp FXT_PRESETS
        jr c,$+4
        ld a,FXT_TRI
        ld (Fe_Hdr+FXH_SWSHAPE),a
        jr Fe_Put_Hdr
.stm    ld a,(Fe_Hdr+FXH_SWPHASE)   ; Start -8 / +8 (по кругу 0..255)
        sub 8
        jr .st
.stp    ld a,(Fe_Hdr+FXH_SWPHASE)
        add a,8
.st     ld (Fe_Hdr+FXH_SWPHASE),a
; Fe_Hdr - в заголовок текущего FX (страница Trk_FxT), перерисовать
Fe_Put_Hdr
        ld a,(Iv_Num)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#8000+FXH_BASE
        add hl,de
        ex de,hl
        ld hl,Fe_Hdr
        ld bc,FXH_SIZE
        ld a,(Trk_FxT)
        call Fe_Copy
        jp Fe_Dirty

;-------- Подвкладки Mix / FM / Env FM
Fe_SubEv
        cp EV_PRESS
        ret nz
        ld a,(ix+FLD_PARAM)
        ld (Fx_Sub),a
        jp Fe_Dirty

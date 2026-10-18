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
FE_RW           equ 2               ; номер строки (hex)
FE_LP           equ 1               ; скобка цикла (как в инструменте: Loop_Char)
FE_MIX          equ 5               ; ---, SID, Buz
FE_MAX          equ 9               ; скважность max / min (4 знака)
FE_MIN          equ 14
FE_SWP          equ 19              ; скорость свипа (3)
FE_SEMI         equ 23              ; детюн: полутоны, сырой (по 4)
FE_DET          equ 29
FE_LN           equ 35              ; длина (2)
FE_STEPS        equ 39              ; шаги: hex-цифра и пробел
; колонки строки: FM / Env FM
FE_ON           equ 5               ; on / --
FE_FSEMI        equ 8               ; детюн: полутоны, сырой (по 4)
FE_FDET         equ 13
FE_UNIT         equ 18              ; semi / per
FE_FLN          equ 23              ; длина (2)
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
        call Fe_RowSb               ; скроллбар строк - на правой рамке
        call Vsb_Draw

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
        ld a,(THEME_ATTR+CLR_TEXT)
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
        ld hl,Iv_Num               ; цвет - заново (SETPAGE в Fe_Get_Name портит C)
        ld a,(Fe_Rn)
        cp (hl)
        ld a,(THEME_ATTR+CLR_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld hl,Fe_LName
        ld b,14
        call Put_Name
        pop bc
        inc b
        ld a,b
        cp FE_LIST_ROWS
        jr c,.row
        call Fe_ListSb              ; скроллбар списка - стандарт (Vsb_Draw)
        jp Vsb_Draw

;-------- Скроллбар списка FX: колонка 18, строки шапки, 32 FX, видно 4
Fe_ListSb
        ld a,18
        ld (Vsb_Col),a
        ld a,IV_SCR_H+IV_TOP+1
        ld (Vsb_Top),a
        ld a,FE_LIST_ROWS
        ld (Vsb_H),a
        ld (Vsb_Vis),a
        ld a,FXS_MAX
        ld (Vsb_Total),a
        ld a,(Fe_LTop)
        ld (Vsb_First),a
        ret

;-------- Скроллбар строк FX: на правой рамке (как в Turbo Vision), строк - длина FX
Fe_RowSb
        ld a,89
        ld (Vsb_Col),a
        ld a,IV_SCR_H+FE_ROW0
        ld (Vsb_Top),a
        ld a,FE_ROWS
        ld (Vsb_H),a
        ld (Vsb_Vis),a
        ld a,(Fe_Hdr+FXH_END)
        inc a
        ld (Vsb_Total),a
        ld a,(Ed_Top)
        ld (Vsb_First),a
        ret

;-------- Средний блок: Name, Len / Loop, свип, подвкладки
Fe_Mid
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FE_MID+256*(IV_SCR_H+IV_TOP+1)
        ld hl,Txt_FeName
        call PutStr
        ld hl,(SV_FOCUS)            ; имя - как в инструменте: в фокусе - цветом курсора
        push de
        ld de,F_FeName
        or a
        sbc hl,de
        pop de
        ld a,(THEME_ATTR+CLR_SELECT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld c,a
        ld hl,Fe_Name
        ld b,16
        call Put_Name
        ld a,(THEME_ATTR+CLR_HEADER) ; Len -nn+   Loop -nn+
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
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld a,(Fe_Hdr+FXH_SWSHAPE)
        call Fe_Shape
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld hl,Txt_FeStart
        call PutStr
        call Fe_Minus
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld a,(Fe_Hdr+FXH_SWPHASE)
        call Put_Dec3
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        call Fe_Plus
        inc e
        inc e
        ld a,(Fe_Hdr+FXH_FLAGS)     ; Kp: включено - цветом выделения
        rrca
        ld a,(THEME_ATTR+CLR_HEAD_TEXT) ; как Kp в инструменте
        jr nc,$+5
        ld a,(THEME_ATTR+CLR_CURSOR)
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

;-------- "[-]nn[+]": A - число; кнопки - наши значки в 2 знака (цвет C), число - цветом значений
Fe_Val2
        push af
        call Fe_Minus
        ld a,(THEME_ATTR+CLR_TEXT)
        ld b,c
        ld c,a
        pop af
        push bc
        call Dec2
        pop bc
        ld c,b
        jp Fe_Plus

;-------- Значки кнопок [-] / [+] (2 знака, GLYPH_BTN_*), цвет кнопок
Fe_Minus
        ld a,GLYPH_BTN_MINUS
        jr Fe_Glyph
Fe_Plus
        ld a,GLYPH_BTN_PLUS
Fe_Glyph
        push bc                     ; цвет кнопок (как в инструменте), свой C - вернуть
        push af
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        pop af
        push af                     ; PutCh портит A
        call PutCh
        pop af
        inc a
        call PutCh
        pop bc
        ret

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
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FE_RW+256*(IV_SCR_H+FE_CAP)
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
        xor a                       ; строка экрана 0..FE_ROWS-1, строка FX - Ed_Top + она
.row    ld (Fe_I),a
        cp FE_ROWS                  ; все строки экрана
        ret nc
        add a,IV_SCR_H+FE_ROW0      ; строка - пустая (старое не остаётся)
        ld d,a
        call Fe_Clr_Row
        ld a,(Ed_Top)
        ld hl,Fe_I
        add a,(hl)
        ld (Fe_Rn),a                ; дальше последней строки FX - пусто
        ld hl,Fe_Hdr+FXH_END
        cp (hl)
        jr z,.go
        jr nc,.next
.go     call Fe_Get_Row
        ld a,(Fe_I)
        add a,IV_SCR_H+FE_ROW0
        ld d,a
        call Fe_Row_Head
        ld a,(Fx_Sub)
        or a
        call z,Fe_Mix_Row
        ld a,(Fx_Sub)
        or a
        call nz,Fe_Fm_Row
        ld a,(Fe_Rn)                ; строка курсора - курсор поверх
        ld hl,Ed_Row
        cp (hl)
        jr nz,.next
        ld a,(Fe_I)
        add a,IV_SCR_H+FE_ROW0
        ld d,a
        call Fe_Cursor
.next   ld a,(Fe_I)
        inc a
        jr .row
Fe_I            db 0                ; строка экрана

;-------- Строка экрана D - пробелы (колонки 1..88)
Fe_Clr_Row
        ld e,1
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
.c      ld a,' '
        call PutCh
        ld a,e
        cp 89
        jr c,.c
        ret

;-------- Скобка цикла (как в инструменте) и номер строки (hex). D - строка экрана
Fe_Row_Head
        ld a,(Fe_Hdr+FXH_LOOP)       ; Loop_Char ждёт [цикл, последняя]
        ld (Fe_LE),a
        ld a,(Fe_Hdr+FXH_END)
        ld (Fe_LE+1),a
        ld a,(Fe_Rn)
        ld b,a
        ld hl,Fe_LE
        call Loop_Char
        ld e,FE_LP
        push af
        ld a,(THEME_ATTR+CLR_LOOP)
        ld c,a
        pop af
        call PutCh
        ld a,(THEME_ATTR+CLR_ROW_NUM)
        ld c,a
        ld a,(Fe_Rn)
        jp PutHex2
Fe_LE           ds 2

;-------- Строка Mix: тип, скважность max / min, свип, детюн, длина, шаги (hex)
Fe_Mix_Row
        ld e,FE_MIX
        ld a,(Fe_Row+FXR_FLAGS)
        and FXR_MIXMASK
        jr nz,.on
        ld a,(THEME_ATTR+CLR_EMPTY) ; выключен - "---", остальное не рисуем
        ld c,a
        ld hl,Txt_FeOff3
        jp PutStr
.on     dec a                       ; SID / Buz / ???
        ld l,a
        add a,a
        add a,l
        ld hl,Txt_FeMix
        call Hl_Add_A
        ld a,(THEME_ATTR+CLR_INSTR)
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
        ld a,(THEME_ATTR+CLR_PARAM)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_EMPTY)
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
        ld a,(THEME_ATTR+CLR_VOLUME)
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
        ld a,(THEME_ATTR+CLR_PARAM)
        ld c,a
        ld hl,Fe_Tab
        ld b,FXT_SIZE               ; все 16 шагов: за длиной - тускло
.s      call Fe_Step_Clr
        ld a,(hl)
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
        ld a,(THEME_ATTR+CLR_EMPTY) ; выключен - "--"
        ld c,a
        ld hl,Txt_FeOff2
        jp PutStr
.on     ld a,(THEME_ATTR+CLR_INSTR)
        ld c,a
        ld hl,Txt_FeOn
        call PutStr
        ld a,(THEME_ATTR+CLR_VOLUME)
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
        ld a,(THEME_ATTR+CLR_PARAM)
        ld c,a
        ld hl,Fe_Tab
        ld b,FXT_SIZE               ; все 16 шагов: за длиной - тускло
.s      call Fe_Step_Clr
        push hl
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
Txt_FeLoop      db "  Loop ",0
Txt_FeSweep     db "Sweep: ",0
Txt_FeStart     db "  Start ",0
Txt_FeKp        db "Kp",0
Txt_FeSubs      db "[ Mix ]",0,"[ FM ]",0,"[ Env FM ]",0
Txt_FeShapes    db "TriSinUp Dn Sqr"   ; таблицы 1..5 пресета
Txt_FeBtn1      db "[Clone] [Copy] [Paste]",0
Txt_FeBtn2      db "[Clear] [Unloop]",0
Txt_FeBtn3      db "[Save]  [Load]",0
Txt_FeCapMix    db "Rw Mix  Max  Min Swp Semi   Det  Ln  Steps (hex)",0
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
        call Fe_Load                ; его заголовок (длина) - для курсора
        call Ed_Clamp               ; курсор - в пределах строк этого FX
Fe_Dirty
        ld a,1
        ld (Iv_Dirty),a
        ret

;-------- Скроллбар списка: ▲ / ▼ - соседний FX, дорожка выше / ниже ползунка - на 4, колесо - соседний
Fe_ScrEv
        cp EV_WHEEL
        jp z,Fe_Wheel
        cp EV_PRESS
        jr z,.p
        cp EV_REPEAT
        ret nz
.p      call Fe_ListSb
        call Vsb_Calc
        ld a,(SV_MOUSE_ROW)
        call Vsb_Hit
        or a
        jp z,Fe_Prev
        cp 4
        jp z,Fe_Next
        cp 2
        ret z                       ; на ползунке - ничего
        ld a,(Iv_Num)               ; выше - на 4 назад, ниже - на 4 вперёд
        jr nc,.dn
        sub FE_LIST_ROWS
        jr nc,$+3
        xor a
        jp Fe_SetNum
.dn     add a,FE_LIST_ROWS
        cp FXS_MAX
        jr c,$+4
        ld a,FXS_MAX-1
        jp Fe_SetNum

;-------- Скроллбар строк FX (правая рамка): ▲ / ▼ - строка, дорожка - страница, колесо - строка
Fe_RScrEv
        cp EV_WHEEL
        jr z,.wh
        cp EV_PRESS
        jr z,.p
        cp EV_REPEAT
        ret nz
.p      call Fe_RowSb
        call Vsb_Calc
        ld a,(SV_MOUSE_ROW)
        call Vsb_Hit
        or a
        jr z,.up
        cp 4
        jr z,.dn
        cp 2
        ret z
        jr c,.pu
        call Ed_PgDn
        jp Iv_Changed
.pu     call Ed_PgUp
        jp Iv_Changed
.up     call Ed_Up
        jp Iv_Changed
.dn     call Ed_Down
        jp Iv_Changed
.wh     bit 7,c
        jr nz,.dn
        jr .up

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
        call Ed_Clamp               ; длина могла стать меньше - курсор в строки
        jp Fe_Dirty

;-------- Подвкладки Mix / FM / Env FM
Fe_SubEv
        cp EV_PRESS
        ret nz
        ld a,(ix+FLD_PARAM)
        ld (Fx_Sub),a
        call Ed_Clamp               ; колонка - в пределах подвкладки
        jp Fe_Dirty

;-------- Клавиши FX: всё - полю в фокусе (строки FX: Ed_Key), общие - как везде (Fld_Key)
Fe_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld b,a
        push bc
        call Fld_Key                ; полю в фокусе (строки, имя) и общим клавишам
        pop bc
        jr c,.k
        ld a,b                      ; Tab - фокус: строки <-> имя
        cp KEY_TAB
        jr nz,.k
        ld hl,(SV_FOCUS)
        ld de,F_FeEdit
        or a
        sbc hl,de
        ld hl,F_FeName
        jr z,$+5
        ld hl,F_FeEdit
        call Fld_Set_Focus
        jr .k
Fe_First
        xor a
        jp Fe_SetNum
Fe_Last
        ld a,FXS_MAX-1
        jp Fe_SetNum

; =========================================================================
; СТРОКИ FX: КУРСОР И ВВОД (шаг 3б) - общий движок редактора (Ed_Key, Ed_Type, Ed_Row / Ed_Col);
; колонки нового формата - здесь. Колонка: экран (ПРАВЫЙ край поля, как у старых FX), вид, байт, параметр
; =========================================================================
Fe_Cols_Mix
        db FE_MIX+2,  KD_MIX,  FXR_FLAGS, 0
        db FE_MAX+3,  KD_PCT,  FXR_PWM, #10             ; max
        db FE_MIN+3,  KD_PCT,  FXR_PWM, #01             ; min
        db FE_SWP+2,  KD_UDEC, FXR_SWP, 255
        db FE_SEMI+3, KD_SDEC, FXR_MIX, 0               ; детюн: полутоны
        db FE_DET+3,  KD_SDEC, FXR_MIX+1, 0             ;   сырой
        db FE_LN+1,   KD_LEN,  FXR_LEN1, #01            ; длина Mix
        DUP 16, I                                       ; шаги: по знаку через пробел
        db FE_STEPS+2*I, KD_STEP, FXR_MIX+2, I
        EDUP
FE_MIX_COLS     equ ($-Fe_Cols_Mix)/CL_SIZE
Fe_Cols_Fm
        db FE_ON+1,    KD_BIT,  FXR_FLAGS, 1<<FXRB_FM
        db FE_FSEMI+3, KD_SDEC, FXR_FM, 0
        db FE_FDET+3,  KD_SDEC, FXR_FM+1, 0
        db FE_UNIT+3,  KD_BIT,  FXR_FLAGS, 1<<FXRB_FMPER
        db FE_FLN+1,   KD_LEN,  FXR_LEN1, #10           ; длина FM - старший полубайт
        DUP 16, I                                       ; шаги: по 4 знака
        db FE_FSTEPS+4*I+3, KD_STEP, FXR_FM+2, I
        EDUP
FE_FM_COLS      equ ($-Fe_Cols_Fm)/CL_SIZE
Fe_Cols_Efm
        db FE_ON+1,    KD_BIT,  FXR_FLAGS, 1<<FXRB_EFM
        db FE_FSEMI+3, KD_SDEC, FXR_EFM, 0
        db FE_FDET+3,  KD_SDEC, FXR_EFM+1, 0
        db FE_UNIT+3,  KD_BIT,  FXR_FLAGS, 1<<FXRB_EFMPER
        db FE_FLN+1,   KD_LEN,  FXR_LEN2, #01
        DUP 16, I
        db FE_FSTEPS+4*I+3, KD_STEP, FXR_EFM+2, I
        EDUP
    ASSERT ($-Fe_Cols_Efm)/CL_SIZE == FE_FM_COLS
    ASSERT FXR_FLAGS == FR_FLAGS        ; Mix (KD_MIX) пишет FR_FLAGS: биты те же

;-------- Поле строк: клавиши - общему редактору, колесо - строка, клик - строка и колонка;
; клик по скобке / номеру - цикл сюда (как в инструменте)
Fe_EditEv
        cp EV_KEY
        jp z,Ed_Key
        cp EV_WHEEL
        jr z,.wh
        cp EV_FOCUS_IN
        jp z,Iv_Changed
        cp EV_PRESS
        ret nz
        ld a,(SV_MOUSE_ROW)         ; строка
        sub FE_ROW0
        ld hl,Ed_Top
        add a,(hl)
        ld b,a
        call Iv_End
        cp b
        ret c                       ; за концом
        ld a,b
        ld (Ed_Row),a
        ld a,(SV_MOUSE_COL)
        cp FE_RW+2                  ; скобка и номер - цикл сюда
        jr nc,.col
        ld a,b
        ld (Fe_Hdr+FXH_LOOP),a
        jp Fe_Put_Hdr
.col    ld c,a                      ; колонка: поле до 4 знаков левее правого края
        call Iv_Cols
        ld e,0
.f      ld a,(hl)
        sub c
        cp 4
        jr c,.hit
        inc hl
        inc hl
        inc hl
        inc hl
        inc e
        djnz .f
        jp Iv_Changed
.hit    ld a,e
        ld (Ed_Col),a
        jp Iv_Changed
.wh     bit 7,c                     ; вниз - строка ниже
        call nz,Ed_Down
        bit 7,c
        call z,Ed_Up
        jp Iv_Changed

;-------- Курсор: колонка Ed_Col строки D (экран) - цветом курсора, ширина - по виду колонки
Fe_Cursor
        push de
        call Iv_Cur_Col             ; IY - колонка
        pop de
        ld a,(iy+1)                 ; ширина поля
        cp KD_STEP                  ; шаг: Mix - 1 знак, FM / Env FM - 4
        jr nz,.nst
        ld b,1
        ld a,(iy+2)
        cp FXR_MIX+2
        jr z,.w
        ld b,4
        jr .w
.nst
        ld b,3
        cp KD_MIX
        jr z,.w
        cp KD_UDEC
        jr z,.w
        ld b,2
        cp KD_LEN
        jr z,.w
        ld b,4
        cp KD_BIT
        jr nz,.w
        ld a,(iy+3)                 ; флаг: semi / per - 4 знака, on - 2
        and (1<<FXRB_FMPER)|(1<<FXRB_EFMPER)
        jr nz,.w
        ld b,2
.w      ld a,(iy+0)                 ; левый край = правый - ширина + 1
        sub b
        inc a
        or #80                      ; атрибуты
        ld e,a
        ld a,(THEME_ATTR+CLR_CURSOR)
.p      ld (de),a
        inc e
        djnz .p
        ret

;-------- Цвет шага: B - сколько шагов осталось (16..1). Шаг в длине - CLR_PARAM, за ней - CLR_EMPTY. C - цвет
Fe_Step_Clr
        ld a,FXT_SIZE
        sub b                       ; номер шага
        push hl
        ld hl,Fe_Ln
        cp (hl)
        pop hl
        ld a,(THEME_ATTR+CLR_PARAM)
        jr c,$+5
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld c,a
        ret

; =========================================================================
; ШАГИ ТАЙМЕРА (шаг 4): ввод в шаг под курсором. Таблица строки - своя: если её номер
; ещё у кого-то (другая строка, другой эффект, форма свипа) или это пресет - строка получает
; копию в свободном номере (музыкант номеров не видит). Склеивать одинаковые - при компиляции.
; Окно 2 - страница строк FX (Trk_Fx), таблицы - Trk_FxT (на время записи)
; =========================================================================
Fe_SMode        db 0                ; 0 - Mix (hex 0..15), 1 - полутоны (дес.), 2 - период (hex)
Fe_T            db 0                ; номер таблицы строки
Fe_SIdx         db 0                ; шаг
Fe_SVal         db 0
Fe_New          db 0
Fe_K            db 0                ; клавиша

;-------- Клавиша B: в шаг под курсором. CF - наша (Ed_Key перерисует), NC - не шаг / не наша
Fe_StepKey
        ld a,b                      ; клавиша - в память (Iv_Cur_Col портит B)
        ld (Fe_K),a
        call Iv_Cur_Col
        ld a,(iy+1)
        cp KD_STEP
        jr z,.go
        or a
        ret
.go     call Iv_Cur_Row             ; IX - строка
        call Fe_Step_Get            ; Fe_SVal, Fe_SMode
        ld a,(Fe_K)
        cp KEY_DEL
        jr z,.zero
        cp KEY_BACK
        jr z,.back
        cp KEY_MINUS
        jr z,.minus
        cp KEY_KP_MINUS
        jr z,.minus
        cp KEY_PLUS
        jp z,.plus
        cp KEY_KP_PLUS
        jp z,.plus
        call Hex_Key                ; цифра 0..15; не цифра - не наша (стрелки и т.п.)
        ccf
        ret nc
        ld c,a
        ld a,(Fe_SMode)
        or a
        ld a,c                      ; Mix: цифра - значение
        jp z,.put
        call Fe_Abs                 ; FM: дописать справа (полутоны - *10, период - *16)
        ld b,a
        ld a,(Fe_SMode)
        dec a
        jr nz,.hex
        ld a,c
        cp 10
        ccf
        ret c                       ; полутоны - только 0..9 (съели)
        ld a,b
        add a,a                     ; *10
        add a,a
        add a,b
        add a,a
        jr c,.only
        add a,c
        jr c,.only
        jr .lim
.hex    ld a,b
        cp 8                        ; *16 больше 127 - с нуля
        jr nc,.only
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
.lim    cp 128
        jr c,.sg
.only   ld a,c
.sg     ld b,a                      ; знак - как был
        ld a,(Fe_SVal)
        or a
        ld a,b
        jp p,.put
        neg
        jr .put
.zero   xor a
        jr .put
.back   ld a,(Fe_SMode)             ; Mix - 0; FM - модуль / 10 (/16), знак тот же
        or a
        jr z,.zero
        call Fe_Abs
        ld b,a
        ld a,(Fe_SMode)
        dec a
        ld a,b
        jr nz,.b16
        ld b,-1
.d10    inc b
        sub 10
        jr nc,.d10
        ld a,b
        jr .sg
.b16    rrca
        rrca
        rrca
        rrca
        and 15
        jr .sg
.minus  ld a,(Fe_SMode)             ; Mix - на 1 меньше; FM - знак минус
        or a
        jr nz,.neg
        ld a,(Fe_SVal)
        or a
        jr z,.put
        dec a
        jr .put
.neg    call Fe_Abs
        neg
        jr .put
.plus   ld a,(Fe_SMode)             ; Mix - на 1 больше; FM - знак плюс
        or a
        jr nz,.pos
        ld a,(Fe_SVal)
        cp 15
        jr nc,.put
        inc a
        jr .put
.pos    call Fe_Abs
.put    call Fe_Step_Put
        scf
        ret

;-------- A = |Fe_SVal|
Fe_Abs
        ld a,(Fe_SVal)
        or a
        ret p
        neg
        ret

;-------- Шаг под курсором (IX - строка, IY - колонка) -> Fe_T, Fe_SIdx, Fe_SVal, Fe_SMode
Fe_Step_Get
        ld a,(iy+3)
        ld (Fe_SIdx),a
        ld a,(iy+2)                 ; байт строки - номер таблицы
        push ix
        pop hl
        call Hl_Add_A
        ld a,(hl)
        ld (Fe_T),a
        ld a,(iy+2)                 ; режим: Mix / полутоны / период
        cp FXR_MIX+2
        ld c,0
        jr z,.m
        cp FXR_FM+2
        ld a,1<<FXRB_FMPER
        jr z,$+4
        ld a,1<<FXRB_EFMPER
        and (ix+FXR_FLAGS)
        ld c,1
        jr z,.m
        ld c,2
.m      ld a,c
        ld (Fe_SMode),a
        call Fe_Tab_Addr            ; HL - шаг в странице таблиц
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld a,(hl)
        ld (Fe_SVal),a
        RESTPAGE2
        ret

;-------- HL = #8000 + Fe_T*16 + Fe_SIdx (страница таблиц - в окне 2). Портит A
Fe_Tab_Addr
        ld a,(Fe_T)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(Fe_SIdx)
        or l
        ld l,a
        set 7,h
        ret

;-------- A - новое значение шага: таблица строки - своя (Fe_Own), записать
Fe_Step_Put
        ld (Fe_SVal),a
        call Fe_Own
        ret c                       ; свободных номеров нет - не пишем
        call Fe_Tab_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld a,(Fe_SVal)
        ld (hl),a
        RESTPAGE2
        ret

;-------- Таблица Fe_T строки (IX, байт - IY+2) - только её: пресет или ещё чья-то - копия в
; свободный номер, номер - в строку. CF - свободных нет
Fe_Own
        call Fe_Count
        ld a,(Fe_T)
        cp FXT_PRESETS
        jr c,.copy                  ; пресет - не трогаем
        ld l,a
        ld h,high Fe_Cnt
        ld a,(hl)
        cp 2
        ccf
        ret nc                      ; только у этой строки - своя (CF = 0)
.copy   ld hl,Fe_Cnt+FXT_PRESETS    ; свободный: никем не взят
.f      ld a,(hl)
        or a
        jr z,.got
        inc l
        jr nz,.f
        scf                         ; все заняты
        ret
.got    ld a,l
        ld (Fe_New),a
        ld a,(Trk_FxT)              ; копия: таблица Fe_T -> Fe_New
        SETPAGE2 a
        ld a,(Fe_T)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        set 7,h
        ld a,(Fe_New)
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        set 7,h
        ex de,hl
        ld bc,FXT_SIZE
        ldir
        RESTPAGE2
        ld a,(Fe_New)               ; строке - новый номер
        ld (Fe_T),a
        ld c,a
        ld a,(iy+2)
        push ix
        pop hl
        call Hl_Add_A
        ld (hl),c
        or a
        ret

;-------- Сколько раз взят каждый номер таблицы -> Fe_Cnt (до 255): строки всех FX (Mix, FM, Env FM -
; все 32 строки, и выключенные) и формы свипа. Окно 2 - страница строк FX
Fe_Count
        ld hl,Fe_Cnt
.z      ld (hl),0
        inc l
        jr nz,.z
        ld hl,#8000+FXR_MIX+2       ; строки: 32 FX * 32 = 1024 (4 раза по 256)
        ld c,FXS_MAX*FX_ROWS_MAX/256
        ld b,0
.r      ld a,(hl)                   ; Mix
        call .inc
        ld de,FXR_FM-FXR_MIX
        add hl,de
        ld a,(hl)                   ; FM
        call .inc
        add hl,de
        ld a,(hl)                   ; Env FM
        call .inc
        ld de,FXR_SIZE-2*(FXR_FM-FXR_MIX)
        add hl,de
        djnz .r
        dec c
        jr nz,.r
        ld a,(Trk_FxT)              ; формы свипа - из заголовков
        SETPAGE2 a
        ld hl,#8000+FXH_BASE+FXH_SWSHAPE
        ld b,FXS_MAX
.h      ld a,(hl)
        call .inc
        ld de,FXH_SIZE
        add hl,de
        djnz .h
        RESTPAGE2
        ret
.inc    push hl
        ld l,a
        ld h,high Fe_Cnt
        ld a,(hl)
        inc a
        jr z,$+3
        ld (hl),a
        pop hl
        ret
    ASSERT FXR_EFM-FXR_FM == FXR_FM-FXR_MIX
    ASSERT FXS_MAX*FX_ROWS_MAX == 1024

        ALIGN 256
Fe_Cnt          ds 256              ; счётчики номеров таблиц (на границе 256)

; =========================================================================
; СТРОКИ И КНОПКИ FX (шаг 5): вставка / удаление строк (клавиши как в инструменте - Row_Ins /
; Row_Del зовут сюда), Clone / Copy / Paste / Clear / Unloop. Строки FX - в окне 2 (Trk_Fx)
; =========================================================================
;-------- Вставить: под строкой курсора - её копия (строки ниже - вниз), последняя +1
Fe_Row_Ins
        ld a,(Fe_Hdr+FXH_END)
        cp FX_ROWS_MAX-1
        ret nc                      ; уже 32
        ld hl,Ed_Row                ; строк сдвигать: последняя - курсор + 1
        sub (hl)
        inc a
        call Fe_Rows16              ; BC - байт
        push bc
        ld a,(Fe_Hdr+FXH_END)       ; с конца последней строки - на строку ниже
        call Iv_Row_Addr
        ld de,FXR_SIZE-1
        add hl,de
        ld d,h
        ld e,l
        ld a,FXR_SIZE
        call Hl_Add_A
        ex de,hl
        pop bc
        lddr
        ld hl,Fe_Hdr+FXH_END        ; строк +1
        inc (hl)
        ld a,(Ed_Row)               ; цикл ниже курсора - за своей строкой
        ld hl,Fe_Hdr+FXH_LOOP
        cp (hl)
        jr nc,.p
        inc (hl)
.p      jp Fe_Put_Hdr

;-------- Удалить строку курсора: ниже - вверх, последняя - нули, строк -1
Fe_Row_Del
        ld a,(Fe_Hdr+FXH_END)
        or a
        ret z                       ; последняя строка не удаляется
        ld hl,Ed_Row                ; сдвигать: последняя - курсор
        sub (hl)
        jr z,.last
        call Fe_Rows16
        push bc
        ld a,(Ed_Row)
        inc a
        call Iv_Row_Addr            ; откуда - строка ниже
        push hl
        ld a,(Ed_Row)
        call Iv_Row_Addr            ; куда - строка курсора
        ex de,hl
        pop hl
        pop bc
        ldir
.last   ld a,(Fe_Hdr+FXH_END)       ; последняя - нули
        call Iv_Row_Addr
        ld b,FXR_SIZE
.z      ld (hl),0
        inc hl
        djnz .z
        ld hl,Fe_Hdr+FXH_END
        dec (hl)
        ld a,(Ed_Row)               ; цикл ниже курсора - за своей строкой, не за концом
        ld hl,Fe_Hdr+FXH_LOOP
        cp (hl)
        jr nc,.e
        dec (hl)
.e      ld a,(Fe_Hdr+FXH_END)
        cp (hl)
        jr nc,.p
        ld (hl),a
.p      jp Fe_Put_Hdr

;-------- BC = A * 16 (байт в A строках)
Fe_Rows16
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ret

;-------- Кнопки справа: 0 Clone, 1 Copy, 2 Paste, 3 Clear, 4 Unloop (5 Save, 6 Load - позже)
Fe_BtnEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        or a
        jr z,Fe_Clone
        dec a
        jp z,Fe_CopyB
        dec a
        jp z,Fe_Paste
        dec a
        jp z,Fe_Clear
        dec a
        jp z,Fe_Unloop
        ret

;-------- Clone: текущий -> в первый пустой FX, он и становится текущим
Fe_Clone
        ld c,0
.f      ld a,(Iv_Num)
        cp c
        jr z,.n
        ld a,c
        push bc
        call Fe_Free
        pop bc
        jr z,.got
.n      inc c
        ld a,c
        cp FXS_MAX
        jr c,.f
        ret                         ; пустых нет
.got    push bc
        call Fe_CopyB               ; текущий - в буфер
        pop bc
        ld a,c
        ld (Iv_Num),a
        call Fe_Paste               ; буфер - в новый
        ld a,(Iv_Num)
        jp Fe_SetNum

;-------- FX A пустой? (строки - нули, заголовок - как у нового, имени нет). Z - да
Fe_Free
        ld (Fe_FN),a
        add a,a                     ; строки: #8000 + n*512, 512 байт
        add a,#80
        ld h,a
        ld l,0
        ld bc,FXR_BLOCK
.r      ld a,(hl)
        or a
        ret nz
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.r
        ld a,(Fe_FN)                ; заголовок
        call Fe_Hdr_Addr
        ld de,Fe_Tmp
        ld bc,FXH_SIZE
        ld a,(Trk_FxT)
        call Fe_Copy
        ld hl,Fe_Tmp
        ld a,(Fe_Tmp+FXH_SWSHAPE)
        xor FXT_TRI
        or (hl)
        inc hl
        or (hl)
        ld hl,Fe_Tmp+FXH_SWPHASE
        or (hl)
        inc hl
        or (hl)
        ret nz
        ld a,(Fe_FN)                ; имя
        ld de,Fe_Tmp
        call Fe_Get_Name
        ld a,(Fe_Tmp)
        or a
        ret
Fe_FN           db 0
Fe_Tmp          ds 17

;-------- A - номер FX -> HL - его заголовок (#8000 + FXH_BASE + n*8, страница Trk_FxT)
Fe_Hdr_Addr
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#8000+FXH_BASE
        add hl,de
        ret

;-------- Copy: строки, заголовок и имя текущего - в буфер
Fe_CopyB
        ld a,(Iv_Num)               ; строки
        add a,a
        add a,#80
        ld h,a
        ld l,0
        ld de,Fe_Clip
        ld bc,FXR_BLOCK
        ldir
        ld hl,Fe_Hdr                ; заголовок
        ld de,Fe_Clip+FXR_BLOCK
        ld bc,FXH_SIZE
        ldir
        ld hl,Fe_Name               ; имя
        ld de,Fe_Clip+FXR_BLOCK+FXH_SIZE
        ld bc,16
        ldir
        ld a,1
        ld (Fe_ClipOk),a
        ret

;-------- Paste: буфер - в текущий (строки, заголовок, имя)
Fe_Paste
        ld a,(Fe_ClipOk)
        or a
        ret z
        ld a,(Iv_Num)
        add a,a
        add a,#80
        ld d,a
        ld e,0
        ld hl,Fe_Clip
        ld bc,FXR_BLOCK
        ldir
        ld hl,Fe_Clip+FXR_BLOCK
        ld de,Fe_Hdr
        ld bc,FXH_SIZE
        ldir
        ld hl,Fe_Clip+FXR_BLOCK+FXH_SIZE
        ld de,Fe_Name
        ld bc,16
        ldir
        call Fe_Put_Name
        jp Fe_Put_Hdr

;-------- Имя Fe_Name - в страницу трека (SONG_FX_NAMES + n*16)
Fe_Put_Name
        ld a,(Iv_Num)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#8000+SONG_FX_NAMES
        add hl,de
        ex de,hl
        ld hl,Fe_Name
        ld bc,16
        ld a,(SV_SONG_PAGE)
        jp Fe_Copy

;-------- Clear: строки - нули, заголовок - как у нового (имя остаётся)
Fe_Clear
        ld a,(Iv_Num)
        add a,a
        add a,#80
        ld h,a
        ld l,0
        ld d,h
        ld e,1
        ld (hl),0
        ld bc,FXR_BLOCK-1
        ldir
        ld hl,Fe_Hdr
        ld b,FXH_SIZE
.z      ld (hl),0
        inc hl
        djnz .z
        ld a,FXT_TRI
        ld (Fe_Hdr+FXH_SWSHAPE),a
        xor a
        ld (Ed_Row),a
        jp Fe_Put_Hdr

;-------- Unloop: в конец - пустая строка (эффекты выкл), цикл - на неё: FX доиграл и молчит
Fe_Unloop
        ld a,(Fe_Hdr+FXH_END)
        cp FX_ROWS_MAX-1
        ret nc
        inc a
        ld (Fe_Hdr+FXH_END),a
        ld (Fe_Hdr+FXH_LOOP),a
        call Iv_Row_Addr
        ld b,FXR_SIZE
.z      ld (hl),0
        inc hl
        djnz .z
        jp Fe_Put_Hdr

Fe_ClipOk       db 0                ; 1 - в буфере FX
Fe_Clip         ds FXR_BLOCK+FXH_SIZE+16

;-------- Имя FX - как в инструменте (Iv_NameEv): буквы, Shift - заглавные, Backspace, Enter - к строкам
Fe_NameEv
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
        cp KEY_TAB                  ; Tab - не наш (фокус - в Fe_Keys)
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
        call Fe_Name_Len            ; HL - на конец, A - длина
        cp 16
        jr nc,.eat
        ld (hl),b
        jr .save
.back   call Fe_Name_Len
        or a
        jr z,.eat
        dec hl
        ld (hl),0
.save   call Fe_Put_Name            ; в страницу трека
        jr .redraw
.done   ld hl,F_FeEdit
        call Fld_Set_Focus
.redraw call Iv_Changed
.eat    scf                         ; клавиша - наша
        ret

; HL - первый 0 имени (или за 16-м знаком), A - длина. BC сохраняет
Fe_Name_Len
        ld hl,Fe_Name
        ld e,0
.l      ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc e
        ld a,e
        cp 16
        jr c,.l
.e      ld a,e
        ret

; =========================================================================
; ВЕРТИКАЛЬНЫЙ СКРОЛЛБАР - стандарт (как был в паттерне, f16da38; как в DOS / Turbo Vision):
; ▲ сверху, ▼ снизу, дорожка ▒ (CLR_SB_TRACK), ползунок ▓ (CLR_SB_THUMB) - длина = доля видимой части
; =========================================================================
SB_TRACK        equ #B1             ; ▒ дорожка
SB_THUMB        equ #B2             ; ▓ ползунок
Vsb_Col         db 0                ; колонка
Vsb_Top         db 0                ; первая строка экрана (с IV_SCR_H)
Vsb_H           db 0                ; высота со стрелками (не меньше 3)
Vsb_Total       db 0                ; всего строк
Vsb_Vis         db 0                ; видно строк
Vsb_First       db 0                ; первая видимая
Vsb_Len         db 0                ; ползунок: длина
Vsb_Pos         db 0                ;   начало на дорожке

;-------- Длина и место ползунка по Vsb_* -> Vsb_T, Vsb_Len, Vsb_Pos
Vsb_Calc
        ld a,(Vsb_H)                ; дорожка = высота - 2 стрелки
        sub 2
        ld (Vsb_T),a
        ld a,(Vsb_Total)            ; всё видно - ползунок во всю дорожку
        ld hl,Vsb_Vis
        cp (hl)
        jr z,.all
        jr nc,.part
.all    ld a,(Vsb_T)
        ld (Vsb_Len),a
        xor a
        ld (Vsb_Pos),a
        ret
.part   ld a,(Vsb_T)                ; длина = дорожка * видно / всего (не меньше 1)
        ld hl,Vsb_Vis
        ld e,(hl)
        call Vsb_Mul                ; HL = A * E
        ld a,(Vsb_Total)
        call Vsb_Div                ; A = HL / A
        or a
        jr nz,$+3
        inc a
        ld (Vsb_Len),a
        ld b,a                      ; начало = (дорожка - длина) * первая / (всего - видно)
        ld a,(Vsb_T)
        sub b
        ld hl,Vsb_First
        ld e,(hl)
        call Vsb_Mul
        ld a,(Vsb_Vis)
        ld b,a
        ld a,(Vsb_Total)
        sub b
        call Vsb_Div
        ld (Vsb_Pos),a
        ret

;-------- Нарисовать по Vsb_*
Vsb_Draw
        call Vsb_Calc
        ld a,(Vsb_Top)              ; ▲
        ld d,a
        ld a,(Vsb_Col)
        ld e,a
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,GLYPH_SCR_UP
        call PutCh
        ld b,0                      ; дорожка: клетка B
.t      ld a,b
        ld hl,Vsb_T
        cp (hl)
        jr nc,.dn
        inc d
        ld a,(Vsb_Col)
        ld e,a
        ld a,b                      ; в ползунке: Pos <= B < Pos + Len
        ld hl,Vsb_Pos
        sub (hl)
        jr c,.tr
        ld hl,Vsb_Len
        cp (hl)
        jr nc,.tr
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,SB_THUMB
        jr .put
.tr     ld a,(THEME_ATTR+CLR_SB_TRACK)
        ld c,a
        ld a,SB_TRACK
.put    call PutCh
        inc b
        jr .t
.dn     inc d                       ; ▼
        ld a,(Vsb_Col)
        ld e,a
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,GLYPH_SCR_DOWN
        jp PutCh
Vsb_T           db 0                ; длина дорожки

;-------- HL = A * E
Vsb_Mul
        ld hl,0
        ld d,0
        or a
        ret z
.m      add hl,de
        dec a
        jr nz,.m
        ret

;-------- A = HL / A (A > 0, частное < 256)
Vsb_Div
        ld e,a
        ld d,0
        ld a,-1
        or a
.d      inc a
        sbc hl,de
        jr nc,.d
        ret

;-------- Где клик по скроллбару: A - строка экрана (без IV_SCR_H) -> A: 0 - ▲, 1 - дорожка выше
; ползунка, 2 - ползунок, 3 - ниже, 4 - ▼ (по последней отрисовке)
Vsb_Hit
        ld hl,Vsb_Top
        add a,IV_SCR_H
        sub (hl)
        ld b,a
        or a
        ld a,0
        ret z                       ; ▲
        ld a,(Vsb_H)
        dec a
        cp b
        ld a,4
        ret z                       ; ▼
        ld a,b                      ; клетка дорожки
        dec a
        ld hl,Vsb_Pos
        sub (hl)
        ld a,1
        ret c                       ; выше ползунка
        ld a,b
        dec a
        sub (hl)
        ld hl,Vsb_Len
        cp (hl)
        ld a,2
        ret c                       ; на ползунке
        ld a,3
        ret

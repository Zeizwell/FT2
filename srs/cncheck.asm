; =========================================================================
; CHECK: выбранный FT2 - во второй слот, сравнить с текущим треком (проверка контейнера)
; Сравниваем то, что пишет контейнер (srs/ft2c.asm): шапку, ордер, каталог и роу паттернов,
; инструменты, орнаменты, FX, таблицы. Текущий трек - окно 2, второй слот - окно 3
; (тот же адрес + #4000). Итог - строкой сообщения: "OK" или число отличий и первое
; =========================================================================
CK_HEAD         equ 0               ; что сравниваем (Ck_Reg) - и имя в сообщении (Ck_Names)
CK_ORD          equ 1
CK_CAT          equ 2               ; дальше - с номером
CK_PAT          equ 3
CK_INS          equ 4               ; дальше - номер с 1
CK_ORN          equ 5
CK_FX           equ 6
CK_TAB          equ 7               ; номер - с 0
CK_FXH          equ 8
CK_FXN          equ 9
CK_INSN         equ 10

Ck_On           db 0                ; 1 - идёт Check: Dv_Loaded остаётся в диске
Ck_Ok           db 0                ; 1 - файл загрузился
Ck_Slot         db 0                ; текущий трек
Ck_Song2        db 0                ; страницы второго слота
Ck_Ins2         db 0
Ck_Orn2         db 0
Ck_Fx2          db 0
Ck_FxT2         db 0
Ck_Reg          db 0                ; что сравниваем (CK_*)
Ck_N            db 0                ; номер паттерна / инструмента ...
Ck_Row          db 0                ; роу паттерна
Ck_Base         dw 0                ; начало объекта в окне 2 (смещение отличия - от него)
Ck_P1           db 0                ; паттерн: страница в треке
Ck_P2           db 0                ;   во втором слоте
Ck_Len          db 0                ;   длина
Ck_Cnt          dw 0                ; отличий (до #FFFF)
Ck_FReg         db 0                ; первое отличие: что, номер, роу, смещение
Ck_FN           db 0
Ck_FRow         db 0
Ck_FOff         dw 0
Ck_Txt          ds 40               ; сообщение

;-------- Кнопка Check
Dv_Check
        ld a,(Dv_Mounted)
        or a
        ret z
        ld hl,(Dv_Count)
        ld a,h
        or l
        ret z
        ld hl,(Dv_Sel)              ; выбранный файл - только FT2
        call Dv_Spec_Rec
        ld a,(Dv_Spec)
        cp FD_DIR
        jr z,.notft
        call Dv_Ext
        cp 1
        jr z,.ft2
.notft  ld hl,Txt_CkFt2
        jp Dv_Error
.ft2    ld a,(SV_SONG_NUM)          ; второй слот - его страницы, грузим туда
        ld (Ck_Slot),a
        xor 1
        call Song_Select
        ld a,(SV_SONG_PAGE)
        ld (Ck_Song2),a
        ld a,(Trk_Ins)
        ld (Ck_Ins2),a
        ld a,(Trk_Orn)
        ld (Ck_Orn2),a
        ld a,(Trk_Fx)
        ld (Ck_Fx2),a
        ld a,(Trk_FxT)
        ld (Ck_FxT2),a
        ld a,1
        ld (Ck_On),a
        xor a
        ld (Ck_Ok),a
        call Dv_Load
        xor a
        ld (Ck_On),a
        ld a,(Ck_Slot)              ; назад - текущий трек
        call Song_Select
        ld a,(Ck_Ok)                ; не загрузился - сообщение уже стоит
        or a
        ret z
        ld hl,Txt_CkRun             ; статус - сразу
        call Dv_Busy
        call Ck_All
        jp Ck_Msg

;-------- Сравнить всё
Ck_All
        ld hl,0
        ld (Ck_Cnt),hl
        ld a,(SV_SONG_PAGE)         ; шапка, ордер
        SETPAGE2 a
        ld a,(Ck_Song2)
        SETPAGE3 a
        call Ck_Head
        call Ck_Order
        call Ck_FxN
        call Ck_InsN
        RESTPAGE3
        RESTPAGE2
        call Ck_Pats                ; каталог и роу паттернов
        ld a,(Trk_Ins)              ; инструменты
        SETPAGE2 a
        ld a,(Ck_Ins2)
        SETPAGE3 a
        call Ck_Ins
        RESTPAGE3
        RESTPAGE2
        ld a,(Trk_Orn)              ; орнаменты
        SETPAGE2 a
        ld a,(Ck_Orn2)
        SETPAGE3 a
        call Ck_Orn
        RESTPAGE3
        RESTPAGE2
        ld a,(Trk_FxT)              ; заголовки FX и таблицы
        SETPAGE2 a
        ld a,(Ck_FxT2)
        SETPAGE3 a
        call Ck_FxH
        call Ck_Tab
        RESTPAGE3
        RESTPAGE2
        ld a,(Trk_Fx)               ; строки FX
        SETPAGE2 a
        ld a,(Ck_Fx2)
        SETPAGE3 a
        call Ck_Fx
        RESTPAGE3
        RESTPAGE2
        ret

;-------- Шапка: поля контейнера (Head_Fields), имя, автор
Ck_Head
        ld a,CK_HEAD
        ld (Ck_Reg),a
        ld hl,#8000
        ld (Ck_Base),hl
        ld hl,Head_Fields
        ld b,HEAD_FIELDS
.f      push bc
        push hl
        ld l,(hl)
        ld h,#80
        ld bc,1
        call Ck_Mem
        pop hl
        pop bc
        inc hl
        djnz .f
        ld hl,#8000+SH_NAME
        ld b,32
        call Ck_Str
        ld hl,#8000+SH_AUTHOR
        ld b,32
        jp Ck_Str

;-------- Ордер: последняя позиция, цикл, позиции 0..последняя
Ck_Order
        ld a,CK_ORD
        ld (Ck_Reg),a
        ld hl,#8000+ORDER_LIST
        ld (Ck_Base),hl
        ld a,(#8000+ORD_LAST)
        ld c,a
        ld b,0
        inc bc
        inc bc
        inc bc
        jp Ck_Mem

;-------- Паттерны: каталог (есть ли, длина), потом роу 0..длина-1
Ck_Pats
        xor a
        ld (Ck_N),a
.n      ld a,CK_CAT
        ld (Ck_Reg),a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Ck_Song2)
        SETPAGE3 a
        call Ck_CatN
        RESTPAGE3
        RESTPAGE2
        ld a,(Ck_P1)                ; есть в обоих - роу
        or a
        jr z,.next
        ld a,(Ck_P2)
        or a
        jr z,.next
        ld a,CK_PAT
        ld (Ck_Reg),a
        ld a,(Ck_P1)
        SETPAGE2 a
        ld a,(Ck_P2)
        SETPAGE3 a
        call Ck_Rows
        RESTPAGE3
        RESTPAGE2
.next   ld hl,Ck_N
        inc (hl)
        ld a,(hl)
        cp PATTERNS_MAX
        jp c,.n
        ret
    ASSERT low PAT_CATALOG == 0

; Каталог паттерна Ck_N: страницы -> Ck_P1 / Ck_P2, длина -> Ck_Len. Есть только в одном -
; отличие (+0), Ck_P1 = 0; длина разная - отличие (+1)
Ck_CatN
        ld a,(Ck_N)
        add a,a
        ld l,a
        ld h,#80+high PAT_CATALOG
        ld (Ck_Base),hl
        ld a,(hl)
        ld (Ck_P1),a
        inc hl
        ld a,(hl)
        ld (Ck_Len),a
        dec hl
        set 6,h
        ld a,(hl)
        ld (Ck_P2),a
        res 6,h
        ld b,a
        ld a,(Ck_P1)
        or a
        jr z,.no1
        ld a,b
        or a
        jr nz,.len
        jr .bad
.no1    ld a,b
        or a
        ret z
.bad    xor a                       ; только в одном - роу не сравниваем
        ld (Ck_P1),a
        jp Ck_Bad
.len    inc hl
        ld bc,1
        jp Ck_Mem

; Роу 0..Ck_Len-1: данные (FT2_PAT_ROW байт), текст не сравниваем
Ck_Rows
        xor a
        ld (Ck_Row),a
.r      ld a,(Ck_Row)
        cp PAT_ROWS_MAX
        ret nc
        ld hl,Ck_Len
        cp (hl)
        ret nc
        add a,#80
        ld h,a
        ld l,0
        ld (Ck_Base),hl
        ld bc,FT2_PAT_ROW
        call Ck_Mem
        ld hl,Ck_Row
        inc (hl)
        jr .r

;-------- Инструменты: заголовок, строки 0..последняя, FX (имена - Ck_InsN)
Ck_Ins
        ld a,CK_INS
        ld (Ck_Reg),a
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
        call Ins_Addr
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld bc,OH_ROWS
        call Ck_Mem
        ld ix,(Cn_Addr)
        ld a,(ix+OH_END)            ; строки: (последняя+1) * 5
        inc a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Ck_Mem
        ld hl,(Cn_Addr)
        ld de,INS_FX
        add hl,de
        ld bc,1
        call Ck_Mem
        ld a,(Ck_N)
        inc a
        cp SAMPLES_MAX
        jr c,.n
        ret
    ASSERT INS_ROW_SIZE == 5

;-------- Орнаменты, FX: как пишет Ser_Rows
Ck_Orn
        ld a,CK_ORN
        ld (Ck_Reg),a
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
        call Orn_Addr
        call Ck_Obj
        ld a,(Ck_N)
        inc a
        cp ORNAMENTS_MAX
        jr c,.n
        ret

;-------- Строки FX 0..последняя (последняя - из заголовка, Ck_Ends)
Ck_Fx
        ld a,CK_FX
        ld (Ck_Reg),a
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
        call Fxr_Addr
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld a,(Ck_N)
        ld e,a
        ld d,0
        ld hl,Ck_Ends
        add hl,de
        ld a,(hl)
        ld (Cn_Rows),a
        call Fx_Rows_Len
        ld hl,(Cn_Addr)
        call Ck_Mem
        ld a,(Ck_N)
        inc a
        cp FXS_MAX
        jr c,.n
        ret

; Блок Cn_Addr: заголовок, строки (Cn_RowSz байт), имя (Cn_NameOfs)
Ck_Obj
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld bc,OH_ROWS
        call Ck_Mem
        ld ix,(Cn_Addr)
        ld a,(ix+OH_END)            ; строки: (последняя+1) * размер
        inc a
        ld e,a
        ld d,0
        ld hl,0
        ld a,(Cn_RowSz)
        ld b,a
.mul    add hl,de
        djnz .mul
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Ck_Mem
        ld hl,(Cn_Addr)
        ld de,(Cn_NameOfs)
        add hl,de
        ld b,16
        jp Ck_Str

;-------- Заголовки FX (FXH_SAVED байт); последняя строка трека в памяти - в Ck_Ends
Ck_FxH
        ld a,CK_FXH
        ld (Ck_Reg),a
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
        call Fxh_Addr
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld a,(hl)
        and FX_ROWS_MAX-1
        ld c,a
        ld a,(Ck_N)
        ld e,a
        ld d,0
        ld hl,Ck_Ends
        add hl,de
        ld (hl),c
        ld hl,(Cn_Addr)
        ld bc,FXH_SAVED
        call Ck_Mem
        ld a,(Ck_N)
        inc a
        cp FXS_MAX
        jr c,.n
        ret

;-------- Имена FX (страница трека)
Ck_FxN
        ld a,CK_FXN
        ld b,FXS_MAX
        ld hl,Fxn_Addr
        jr Ck_Names16

;-------- Имена инструментов (страница трека)
Ck_InsN
        ld a,CK_INSN
        ld b,SAMPLES_MAX
        ld hl,Insn_Addr

;-------- Имена по 16: A - что (CK_*), B - сколько, HL - адрес имени Cn_N (-> Cn_Addr)
Ck_Names16
        ld (Ck_Reg),a
        ld a,b
        ld (.max+1),a
        ld (.addr+1),hl
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
.addr   call 0
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld b,16
        call Ck_Str
        ld a,(Ck_N)
        inc a
.max    cp 0
        jr c,.n
        ret

;-------- Таблицы FX: 256 по 16 значений
Ck_Tab
        ld a,CK_TAB
        ld (Ck_Reg),a
        xor a
.n      ld (Ck_N),a
        ld (Cn_N),a
        call Fxt_Addr
        ld hl,(Cn_Addr)
        ld (Ck_Base),hl
        ld bc,FXT_SIZE
        call Ck_Mem
        ld a,(Ck_N)
        inc a
        jr nz,.n                    ; 0..255
        ret
Ck_Ends         ds FXS_MAX          ; последняя строка каждого FX (трек в памяти)

;-------- HL (окно 2) - BC байт сравнить с тем же + #4000 (окно 3)
Ck_Mem
        ld a,b
        or c
        ret z
        ld d,h
        ld e,l
        set 6,d
.c      ld a,(de)
        cp (hl)
        call nz,Ck_Bad
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.c
        ret

;-------- Строка HL (до 0, не больше B знаков) - так же
Ck_Str
.c      ld d,h
        ld e,l
        set 6,d
        ld a,(de)
        cp (hl)
        call nz,Ck_Bad
        ld a,(hl)
        or a
        ret z
        inc hl
        djnz .c
        ret

;-------- Отличие по адресу HL: счёт; первое - запомнить где. Портит A, HL / DE / BC целы
Ck_Bad
        push hl
        ld hl,(Ck_Cnt)
        ld a,h
        and l
        inc a
        jr z,.out                   ; #FFFF - больше не считаем
        ld a,h
        or l
        inc hl
        ld (Ck_Cnt),hl
        jr nz,.out                  ; не первое - только счёт
        pop hl
        push hl
        push de
        ld de,(Ck_Base)
        or a
        sbc hl,de
        ld (Ck_FOff),hl
        ld a,(Ck_Reg)
        ld (Ck_FReg),a
        ld a,(Ck_N)
        ld (Ck_FN),a
        ld a,(Ck_Row)
        ld (Ck_FRow),a
        pop de
.out    pop hl
        ret

;-------- Сообщение: "Check OK ..." или "Diff NNNN, first: pat 05 row 16 +06"
Ck_Msg
        ld hl,(Ck_Cnt)
        ld a,h
        or l
        ld hl,Txt_CkSame
        jp z,Dv_Ok
        ld de,Ck_Txt
        ld hl,Txt_CkDiff
        call Ck_Cpy
        ld a,(Ck_Cnt+1)
        call Ck_Hex
        ld a,(Ck_Cnt)
        call Ck_Hex
        ld hl,Txt_CkFirst
        call Ck_Cpy
        ld a,(Ck_FReg)              ; что
        add a,a
        ld l,a
        ld h,0
        ld bc,Ck_Names
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call Ck_Cpy
        ld a,(Ck_FReg)              ; шапка, ордер - без номера
        cp CK_CAT
        jr c,.off
        ld a,' '
        ld (de),a
        inc de
        ld a,(Ck_FReg)
        cp CK_INS
        jr c,.n0
        cp CK_TAB
        jr z,.n0
        ld a,(Ck_FN)
        inc a                       ; инструменты, орнаменты, FX - с 1; таблицы - с 0
        jr .nh
.n0     ld a,(Ck_FN)
.nh
        call Ck_Hex
        ld a,(Ck_FReg)              ; паттерн - и роу
        cp CK_PAT
        jr nz,.off
        ld hl,Txt_CkRow
        call Ck_Cpy
        ld a,(Ck_FRow)
        call Ck_Hex
.off    ld hl,Txt_CkOff             ; смещение в объекте
        call Ck_Cpy
        ld a,(Ck_FOff+1)
        or a
        call nz,Ck_Hex
        ld a,(Ck_FOff)
        call Ck_Hex
        xor a
        ld (de),a
        ld hl,Txt_CkBad             ; "Checking... differ", отличия - строкой ниже
        call Dv_Error
        ld hl,Ck_Txt
        jp Dv_Error

; Строка HL -> DE (без 0)
Ck_Cpy
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr Ck_Cpy

; A -> 2 hex в DE
Ck_Hex
        push af
        rrca
        rrca
        rrca
        rrca
        and #0F
        call HexDigit
        ld (de),a
        inc de
        pop af
        and #0F
        call HexDigit
        ld (de),a
        inc de
        ret

Ck_Names        dw Txt_CkHead,Txt_CkOrd,Txt_CkCat,Txt_CkPat,Txt_CkIns,Txt_CkOrn,Txt_CkFx,Txt_CkTab,Txt_CkFxH,Txt_CkFxN,Txt_CkInsN
Txt_CkHead      db "head",0
Txt_CkOrd       db "order",0
Txt_CkCat       db "pat cat",0
Txt_CkPat       db "pat",0
Txt_CkIns       db "ins",0
Txt_CkOrn       db "orn",0
Txt_CkFx        db "fx",0
Txt_CkTab       db "table",0
Txt_CkFxH       db "fx head",0
Txt_CkFxN       db "fx name",0
Txt_CkInsN      db "ins name",0
Txt_CkRow       db " row ",0
Txt_CkOff       db " +",0
Txt_CkDiff      db "Diff ",0
Txt_CkFirst     db ", first: ",0
Txt_CkRun       db "Checking...",0
Txt_CkSame      db "OK: file = memory",0
Txt_CkBad       db "differ",0
Txt_CkFt2       db "Check: select an FT2 file",0

; =========================================================================
; ИМПОРТ FTC (Fast Tracker ZX 1.0x) в трек 1. Часть тулзы диска, на общих частях
; импорта PT3 (srs/pt3imp.asm). Формат - doc/formats/ftc.md, сверено с
; конвертером Vortex Tracker (FTC2VTM).
; =========================================================================
; Что куда:
;   заголовок  - темп, цикл, описание (42 знака): режем на имя и автора по " BY "
;                или по пробелу (Fc_Split);
;   сэмплы 0..31 -> инструменты 1..32 (формат у нас тот же - копия; строк больше
;                64 - обрезаем);
;   орнаменты 1..16 -> 1..16 (тот же формат), 0 и 17..32 - не берём (Pt_Lost);
;   ордер      - пары (паттерн, транспозиция): каждая пара - свой наш паттерн,
;                транспозиция прибавлена к нотам;
;   треки      - нота, сэмпл, громкость, огибающая (период - в заголовок чипа),
;                орнамент (выключает огибающую), шум (в заголовок чипа), команды:
;                темп, глиссандо, портаменто.
; Пропуск строк #40..#5F - конец строки и n строк без чтения (только до следующей
; ноты - у PT2 он постоянный).
; =========================================================================

; --- заголовок модуля
FC_NAME         equ #08             ; 42 имя (32) + автор
FC_TONES        equ #32             ; таблица нот: 2 - 1.75 МГц, иначе классика
FC_TEMPO        equ #45
FC_LOOP         equ #46
FC_PATS         equ #4B             ; 2 смещение таблицы паттернов (по 6 байт: A, B, C)
FC_SAMPLES      equ #52             ; 32 x 2 смещения сэмплов 0..31
FC_ORNS         equ #92             ; 33 x 2 смещения орнаментов 0..32
FC_ORDER        equ #D4             ; пары (паттерн, транспозиция); бит 7 паттерна - конец

Fc_Trans        db 0                ; транспозиция паттерна, который разбираем

;-------- Импорт. Выход - сообщение (Dv_Ok / Dv_Error)
Ftc_Import
        xor a
        ld (Pt_Lost),a
        ld hl,0
        ld (Pt_Base),hl
        inc a
        ld (Pt_Chips),a
        ld hl,FC_ORDER              ; ордер пустой - не FTC (трек не трогаем)
        call Pt_Get
        bit 7,a
        ld hl,Txt_BadFtc
        jp nz,Dv_Error
        call Song_Clear
        call Fc_Header
        ld a,(Trk_Ins)
        call Ins_Clear
        ld a,(Trk_Ins)
        ld (Ps_Page),a
        call Fc_Samples
        call Fc_Ornaments
        call Fc_Order
        call Fc_Patterns
        ld hl,Txt_FtcCut
        jp Pt_Done

;-------- Заголовок трека: темп, имя, автор; ордер и каталоги - нули
Fc_Header
        ld hl,FC_TEMPO
        call Pt_Get
        or a
        jr nz,$+4
        ld a,NEW_SONG_SPEED
        ld (Ph_Tempo),a
        ld hl,FC_TONES              ; таблица нот: 2 - 1.75 МГц, иначе классика (1.77)
        call Pt_Get
        cp 2
        ld a,0
        jr z,$+3
        inc a
        ld (Ph_Tune),a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Ph_Tempo)
        ld (#8000+SH_SPEED),a
        ld a,(Ph_Tune)
        ld (#8000+SH_TUNING),a
        ld a,1
        ld (#8000+SH_CHIPS),a
        ld hl,#8000+ORDER_LIST
        ld de,#8000+ORDER_LIST+1
        ld bc,SONG_CAT_END-ORDER_LIST-1
        ld (hl),0
        ldir
        RESTPAGE2
        call Fc_Split               ; описание (42) -> имя и автор
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,Fc_Txt                ; имя: Fc_Txt[0..Fc_Cut)
        ld a,(Fc_Cut)
        ld de,#8000+SH_NAME
        call Fc_Put32
        ld hl,Fc_Txt                ; автор: Fc_Txt[Fc_By..Fc_Len)
        ld a,(Fc_By)
        call Hl_Add_A
        ld a,(Fc_Len)
        ld b,a
        ld a,(Fc_By)
        neg
        add a,b
        ld de,#8000+SH_AUTHOR
        call Fc_Put32
        RESTPAGE2
        ret

;-------- A знаков с HL (не больше 32) в DE, до 32 - пробелы
Fc_Put32
        cp 33
        jr c,$+4
        ld a,32
        ld c,a
        ld b,32
.c      ld a,c
        or a
        ld a,' '
        jr z,.p
        ld a,(hl)
        inc hl
        dec c
.p      ld (de),a
        inc de
        djnz .c
        ret

;-------- Описание FTC (42 знака) -> Fc_Txt и границы: имя - [0, Fc_Cut), автор -
; [Fc_By, Fc_Len). Есть " BY " - режем по нему; иначе длиннее 32 - по последнему
; пробелу в первых 32 знаках; иначе всё - имя
FC_TXT_LEN      equ 42
Fc_Txt          ds FC_TXT_LEN
Fc_Len          db 0
Fc_Cut          db 0
Fc_By           db 0

Fc_Split
        ld hl,FC_NAME
        ld de,Fc_Txt
        ld b,FC_TXT_LEN
.r      call Pt_Get
        ld (de),a
        inc de
        djnz .r
        ld b,FC_TXT_LEN             ; длина без хвостовых пробелов и нулей
.t      ld hl,Fc_Txt-1
        ld a,b
        call Hl_Add_A
        ld a,(hl)
        cp ' '+1
        jr nc,.len
        djnz .t
.len    ld a,b
        ld (Fc_Len),a
        ld (Fc_Cut),a               ; пока - всё имя
        ld (Fc_By),a
        ld c,0                      ; " BY " с позиции C
.f      ld a,c
        add a,4
        ld hl,Fc_Len
        cp (hl)
        jr z,$+4
        jr nc,.nby
        ld hl,Fc_Txt
        ld a,c
        call Hl_Add_A
        ld a,(hl)
        cp ' '
        jr nz,.fn
        inc hl
        ld a,(hl)
        or #20
        cp 'b'
        jr nz,.fn
        inc hl
        ld a,(hl)
        or #20
        cp 'y'
        jr nz,.fn
        inc hl
        ld a,(hl)
        cp ' '
        jr nz,.fn
        ld a,c                      ; нашли
        ld (Fc_Cut),a
        add a,4
        ld (Fc_By),a
        ret
.fn     inc c
        jr .f
.nby    ld a,(Fc_Len)               ; не длиннее 32 - всё имя
        cp 33
        ret c
        ld c,32                     ; последний пробел в первых 32
.s      ld hl,Fc_Txt
        ld a,c
        call Hl_Add_A
        ld a,(hl)
        cp ' '
        jr z,.sp
        dec c
        jr nz,.s
        ld a,32                     ; пробела нет - 32 и остальное
        ld (Fc_Cut),a
        ld (Fc_By),a
        ret
.sp     ld a,c
        ld (Fc_Cut),a
        inc a
        ld (Fc_By),a
        ret

; =========================================================================
; СЭМПЛЫ И ОРНАМЕНТЫ: блоки как у нас - копия (строк не больше 64)
; =========================================================================
;-------- Сэмплы 0..31 -> инструменты 1..32 (блок = номер сэмпла)
Fc_Samples
        xor a
        ld (Ps_K),a
.k      ld a,(Ps_K)
        add a,a
        ld l,a
        ld h,0
        ld de,FC_SAMPLES
        add hl,de
        call Pt_Get16               ; DE - сэмпл в модуле
        ld a,d
        or e
        jr z,.next
        ld a,(Ps_K)                 ; блок: #8000 + k*384
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld h,l
        ld l,0
        srl h
        rr l
        set 7,h
        ex de,hl                    ; HL - в модуле, DE - блок
        ld a,INS_ROW_SIZE
        call Fc_Block
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp SAMPLES_MAX
        jr c,.k
        ret

;-------- Орнаменты 1..16 -> наши 1..16 (блок номер-1); 17..32 - не влезают
Fc_Ornaments
        ld a,1
        ld (Ps_K),a
.k      ld a,(Ps_K)
        add a,a
        ld l,a
        ld h,0
        ld de,FC_ORNS
        add hl,de
        call Pt_Get16
        ld a,d
        or e
        jr z,.next
        ld a,(Ps_K)                 ; блок: #8000 + ORN_BASE + (номер-1)*256
        dec a
        add a,#80+high ORN_BASE
        ld h,a
        ld l,0
        ex de,hl
        ld a,ORN_ROW_SIZE
        call Fc_Block
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp ORNAMENTS_MAX+1
        jr c,.k
        ret

;-------- Блок FTC: HL - в модуле (+0 копия конца, +1 цикл, +2 конец, строки),
; DE - наш блок (окно 2), A - байт в строке. Строк больше 64 - обрезаем (Pt_Lost)
Fc_Size         db 0
Fc_Block
        ld (Fc_Size),a
        inc hl                      ; +0 - копия, берём +2
        call Pt_Get                 ; цикл
        ld (Ph_Loop),a
        call Pt_Get                 ; конец -> длина
        inc a
        jr nz,.len
        ld a,INS_ROWS_MAX+1         ; конец 255 - длина 256: обрежем
.len    call Ps_Head_Len            ; заголовок блока, Ps_Rows, Ps_Dst
        ld a,(Ps_Page)
        SETPAGE2 a
.row    ld a,(Fc_Size)
        ld b,a
.b      call Pt_Get
        ld de,(Ps_Dst)
        ld (de),a
        inc de
        ld (Ps_Dst),de
        djnz .b
        ld a,(Ps_Rows)
        dec a
        ld (Ps_Rows),a
        jr nz,.row
        RESTPAGE2
        ret
    ASSERT INS_ROWS_MAX == ORN_ROWS_MAX

; =========================================================================
; ОРДЕР: пары (паттерн, транспозиция) -> наши паттерны
; =========================================================================
Fc_Order
        xor a
        ld (Pm_Count),a
        ld (Po_Count),a
        ld hl,FC_LOOP
        call Pt_Get
        ld (Po_Loop),a
        ld hl,FC_ORDER
.pos    ld a,(Po_Count)
        cp 255
        ret nc
        call Pt_Get                 ; паттерн; бит 7 - конец
        bit 7,a
        ret nz
        ld (Po_Key1),a
        call Pt_Get                 ; транспозиция
        ld (Po_Key2),a
        push hl
        call Pm_Find
        pop hl
        jr c,.full
        push hl
        ld hl,Po_Count
        ld c,(hl)
        inc (hl)
        ld hl,Po_Pos
        ld b,0
        add hl,bc
        ld (hl),a
        pop hl
        jr .pos
.full   ld hl,Pt_Lost
        set PL_PATS,(hl)
        ret

; =========================================================================
; ПАТТЕРНЫ
; =========================================================================
Fc_Patterns
        xor a
        ld (Pp_N),a
        ld (Pp_Chip),a
.p      ld a,(Pm_Count)
        ld hl,Pp_N
        cp (hl)
        ret z
        ld a,(hl)
        call Pat_Page
        SETPAGE2 a
        call Pat_Zero
        ld a,(Pp_N)                 ; транспозиция этой пары
        ld hl,Pm_P2
        call Arr_Get
        ld (Fc_Trans),a
        ld a,(Pp_N)
        ld hl,Pm_P1
        call Arr_Get
        call Fc_Decode
        call Pp_Noise0              ; шум на роу 0 - как у трекеров (база с нуля)
        or a
        jr nz,$+3
        inc a
        ld c,a
        ld a,(Pp_N)
        ld hl,Pm_Len
        call Hl_Add_A
        ld (hl),c
        RESTPAGE2
        ld hl,Pp_N
        inc (hl)
        jr .p

;-------- Паттерн A -> роу паттерна в окне 2. Выход: A - роу (канал A дошёл до #FF
; или до PAT_ROWS_MAX). Pc_Cnt - строк до следующего чтения канала
Fc_Decode
        ld l,a                      ; треки: таблица паттернов + номер*6
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        push hl
        ld hl,FC_PATS
        call Pt_Get16
        pop hl
        add hl,de
        ld de,Pc_Ptr
        ld b,3
.tr     push de
        call Pt_Get16
        ex (sp),hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex (sp),hl
        pop de
        djnz .tr
        ld hl,Pc_Cnt                ; читать - сразу
        ld (hl),1
        inc hl
        ld (hl),1
        inc hl
        ld (hl),1
        xor a
        ld (Pp_Row),a
.row    xor a
        ld (Pp_Ch),a
.ch     ld hl,Pc_Cnt
        call Pc_Var
        dec (hl)
        jr nz,.nch
        ld a,(Pp_Ch)                ; канал A: #FF - конец паттерна
        or a
        jr nz,.parse
        call Pc_Peek_Byte
        inc a
        jr z,.end
.parse  call Fc_Row_Ch              ; A - строк до следующего чтения
        ld e,a
        ld hl,Pc_Cnt
        call Pc_Var
        ld (hl),e
.nch    ld hl,Pp_Ch
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.ch
        ld hl,Pp_Row
        inc (hl)
        ld a,(hl)
        cp PAT_ROWS_MAX
        jr nz,.row
        ld a,(Pc_Cnt)               ; канал A следующей строкой кончается - всё влезло
        cp 1
        jr nz,.cut
        call Pc_Peek_Byte
        inc a
        jr z,.end
.cut    ld hl,Pt_Lost
        set PL_ROWS,(hl)
.end    ld a,(Pp_Row)
        ret

;-------- Строка канала Pp_Ch -> клетка роу Pp_Row. Выход: A - через сколько строк
; читать канал снова (1 - со следующей)
Fc_Row_Ch
        ld hl,Pc_Ptr
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,1
        ld (Fc_Next),a
        xor a
        ld (Fc_Porta),a
.cmd    call Pt_Get
        cp #20
        jp c,.smp
        cp #30
        jp c,.vol
        jp z,.off
        cp #3F
        jp c,.env
        jp z,.eoff
        cp #60
        jp c,.skp
        cp #CC
        jp c,.note
        cp #ED
        jp c,.orn
        jp z,.glis
        cp #EE
        jp z,.porta
        cp #EF
        jp z,.noise
        call Pt_Get                 ; #F0..#FF: темп
        ld e,a
        ld d,CMD_SPEED<<4
        call P2_Cmd
        jp .cmd
.smp    inc a                       ; #00..#1F: сэмпл k -> инструмент k+1
        ld c,CH_SAMPLE
        call Pr_Put
        jp .cmd
.vol    sub #20                     ; #20..#2F: громкость (0 - как 1, у нас 0 - пусто)
        jr nz,$+3
        inc a
        ld c,CH_VOLUME
        call Pr_Put
        jp .cmd
.off    ld a,NOTE_OFF               ; #30: звук выкл, конец строки
        ld c,CH_NOTE
        call Pr_Put
        jp .end
.env    sub #30                     ; #31..#3E: форма, период (младший первым)
        ld c,CH_ENVSHAPE
        call Pr_Put
        call Pt_Get16
        push hl
        ld c,CHIP_ENVPER
        call Pr_Chip_Fld
        ld (hl),e
        inc l
        ld (hl),d
        pop hl
        jp .cmd
.eoff   call Pr_EnvOff              ; #3F
        jp .cmd
.skp    sub #40-1                   ; #40..#5F: конец строки, n строк без чтения
        ld (Fc_Next),a
        jp .end
.note   sub #60                     ; #60..#CB: нота + транспозиция (не выше B-8)
        ld b,a
        ld a,(Fc_Trans)
        add a,b
        jr c,.top
        cp NOTE_COUNT
        jr c,.nt
.top    ld a,NOTE_COUNT-1
.nt     add a,NOTE_FIRST
        ld c,CH_NOTE
        call Pr_Put
        ld a,(Fc_Porta)             ; портаменто - к этой ноте
        or a
        jp z,.end
        ld e,a
        ld d,CMD_PORTA<<4|1
        call P2_Cmd
        xor a
        ld (Fc_Porta),a
        jp .end
.orn    sub #CC                     ; #CC..#EC: орнамент 0..32 (наши - 1..16)
        jr z,.orn0
        cp ORNAMENTS_MAX+1
        jr c,.orns
        push hl
        ld hl,Pt_Lost
        set PL_LEN,(hl)
        pop hl
.orn0   xor a                       ; 0 и не влезшие - пустой
.orns   call Pr_Orn
        push hl                     ; огибающую выключает (если в клетке её нет)
        call Pr_Cell
        ld a,l
        add a,CH_ENVSHAPE
        ld l,a
        ld a,(hl)
        pop hl
        or a
        call z,Pr_EnvOff
        jp .cmd
.glis   call Pt_Get16               ; #ED: глиссандо, шаг - слово со знаком
        ld a,e
        bit 7,d
        ld d,CMD_GLIS_DOWN<<4|1
        jr z,.gp
        neg
        ld d,CMD_GLIS_UP<<4|1
.gp     ld e,a
        call P2_Cmd
        jp .cmd
.porta  call Pt_Get                 ; #EE: портаменто к ноте этой строки
        ld (Fc_Porta),a
        jp .cmd
.noise  call Pt_Get                 ; #EF: шум
        and #1F
        call Pr_Noise
        jp .cmd
.end    ex de,hl                    ; позиция в треке - на место
        ld hl,Pc_Ptr
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(Fc_Next)
        ret

Fc_Next         db 1                ; через сколько строк читать канал снова
Fc_Porta        db 0                ; портаменто к ноте этой строки (0 - нет)

Txt_FtcCut      db "FTC cut:",0
Txt_BadFtc      db "Bad FTC",0

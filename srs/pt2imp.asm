; =========================================================================
; ИМПОРТ PT2 (Pro Tracker 2.x) в трек 1. Часть тулзы диска, рядом с импортом PT3
; (srs/pt3imp.asm): общие чтение модуля (Pt_Get), ордер (Pm_Find, Pt_Song_Order),
; клетки роу (Pr_Put...), конец импорта (Pt_Done).
; Формат - doc/formats/pt2.md, сверено с конвертером Vortex Tracker (PT22VTM).
; =========================================================================
; Что куда:
;   заголовок - темп, имя (30 знаков); автора в PT2 нет;
;   сэмплы 1..31 -> инструменты 1..31 (сэмпл 0 в PT2 не описан - им глушат канал);
;   орнаменты 1..15 -> 1..15;
;   треки - нота, сэмпл, огибающая (период - в заголовок чипа), орнамент (он же
;   выключает огибающую), громкость, шум (в заголовок чипа), команды: темп,
;   глиссандо, портаменто, выкл команд.
; Громкость 0 в клетку не кладём (у нас 0 - "пусто").
; =========================================================================

; --- заголовок модуля
P2_TEMPO        equ 0
P2_LOOP         equ 2
P2_SAMPLES      equ 3               ; 32 x 2 смещения сэмплов 0..31
P2_ORNS         equ 67              ; 16 x 2 смещения орнаментов 0..15
P2_PATS         equ 99              ; 2 смещение таблицы паттернов (по 6 байт: A, B, C)
P2_NAME         equ 101             ; 30 имя
P2_ORDER        equ 131             ; номера паттернов, конец - 128 и больше
P2_NAME_LEN     equ 30

;-------- Импорт. Выход - сообщение (Dv_Ok / Dv_Error)
Pt2_Import
        xor a
        ld (Pt_Lost),a
        ld hl,0
        ld (Pt_Base),hl
        inc a
        ld (Pt_Chips),a
        ld hl,P2_ORDER              ; ордер пустой - не PT2 (трек не трогаем)
        call Pt_Get
        cp 128
        ld hl,Txt_BadPt2
        jp nc,Dv_Error
        call Song_Clear             ; новый трек
        call P2_Header
        ld a,(Trk_Ins)              ; инструменты и орнаменты - пустые, потом PT2
        call Ins_Clear
        ld a,(Trk_Ins)
        ld (Ps_Page),a
        call P2_Samples
        call P2_Ornaments
        call P2_Order
        call P2_Patterns
        ld hl,Txt_Pt2Cut
        jp Pt_Done

;-------- Заголовок трека: темп, имя; ордер и каталоги - нули
P2_Header
        ld hl,P2_TEMPO
        call Pt_Get
        or a
        jr nz,$+4
        ld a,NEW_SONG_SPEED
        ld (Ph_Tempo),a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Ph_Tempo)
        ld (#8000+SH_SPEED),a
        ld a,1
        ld (#8000+SH_CHIPS),a
        ld hl,#8000+ORDER_LIST
        ld de,#8000+ORDER_LIST+1
        ld bc,SONG_CAT_END-ORDER_LIST-1
        ld (hl),0
        ldir
        ld hl,#8000+SH_NAME         ; имя: 30 знаков, остальное - пробелы
        ld (hl),' '
        ld de,#8000+SH_NAME+1
        ld bc,31
        ldir
        ld hl,#8000+SH_AUTHOR       ; автора нет
        ld (hl),' '
        ld de,#8000+SH_AUTHOR+1
        ld bc,31
        ldir
        ld hl,P2_NAME
        ld de,#8000+SH_NAME
        ld b,P2_NAME_LEN
.c      call Pt_Get
        ld (de),a
        inc de
        djnz .c
        RESTPAGE2
        ret

; =========================================================================
; СЭМПЛЫ И ОРНАМЕНТЫ
; =========================================================================
;-------- Сэмплы 1..31 -> инструменты 1..31 (блок номер-1)
P2_Samples
        ld a,1
        ld (Ps_K),a
.k      ld a,(Ps_K)
        add a,a
        ld l,a
        ld h,0
        ld de,P2_SAMPLES
        add hl,de
        call Pt_Get16               ; DE - сэмпл в модуле (0 - нет)
        ld a,d
        or e
        jr z,.next
        ld a,(Ps_K)                 ; блок: #8000 + (номер-1)*384
        dec a
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl                   ; *384 = (*3)*128
        add hl,bc
        ld h,l
        ld l,0
        srl h
        rr l
        set 7,h
        ex de,hl                    ; HL - в модуле, DE - блок
        call P2_Sample
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp SAMPLES_MAX
        jr c,.k
        ret

;-------- Заголовок блока PT2: длина, потом цикл (у PT3 наоборот). HL - в модуле
P2_Head
        call Pt_Get                 ; длина
        push af
        call Pt_Get                 ; цикл
        ld (Ph_Loop),a
        pop af
        jp Ps_Head_Len

;-------- Сэмпл: HL - в модуле (длина, цикл, строки по 3), DE - наш блок (окно 2)
P2_Sample
        call P2_Head
        ld a,(Ps_Page)
        SETPAGE2 a
.row    call Pt_Get                 ; b0: шум N4..N0, знак тона, маска тона, маска шума
        ld (Ps_B0),a
        call Pt_Get                 ; b1: амплитуда, тон 11..8
        ld (Ps_B1),a
        call Pt_Get                 ; b2: тон 7..0
        push hl
        ld e,a
        call P2_Row
        pop hl
        ld hl,Ps_Rows
        dec (hl)
        jr nz,.row
        RESTPAGE2
        ret

;-------- Строка сэмпла PT2 (Ps_B0, Ps_B1, E - тон 7..0) -> 5 байт в Ps_Dst (окно 2)
P2_Row
        ld hl,(Ps_Dst)
        ld a,(Ps_B0)                ; шум: бит 0 = 1 - выкл, иначе N4..N0 - смещение
        bit 0,a
        ld c,1<<IRB_OFF
        jr nz,.nz
        rrca
        rrca
        rrca
        and #1F
        ld c,a
.nz     ld (hl),c                   ; IR_NOISE
        inc hl
        ld a,(Ps_B1)                ; тон: 12 бит, бит 2 b0 = 0 - со знаком минус
        and #0F
        ld d,a                      ; DE - модуль
        ld a,(Ps_B0)
        bit 2,a
        jr nz,.pos
        xor a                       ; DE = #1000 - DE (12 бит)
        sub e
        ld e,a
        ld a,0
        sbc a,d
        and #0F
        ld d,a
.pos    ld (hl),e                   ; IR_TONE
        inc hl
        ld a,(Ps_B0)                ; бит 1 = 1 - тон выкл
        and 2
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                     ; -> бит 6 (IRB_OFF)
        or d
        ld (hl),a
        inc hl
        ld a,(Ps_B1)                ; IR_VOL: амплитуда, огибающая разрешена (её
        rrca                        ;   включает канал командой паттерна)
        rrca
        rrca
        rrca
        and #0F
        or 1<<IRB_OFF
        ld (hl),a
        inc hl
        ld (hl),0                   ; IR_ENV: смещения нет
        inc hl
        ld (Ps_Dst),hl
        ret
    ASSERT IRB_OFF == 6

;-------- Орнаменты 1..15 -> наши 1..15 (блок номер-1)
P2_Ornaments
        ld a,1
        ld (Ps_K),a
.k      ld a,(Ps_K)
        add a,a
        ld l,a
        ld h,0
        ld de,P2_ORNS
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
        call P2_Head                ; длина, цикл; строки - как у PT3 (по байту)
        call Po_Orn_Rows
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp ORNAMENTS_MAX
        jr c,.k
        ret

; =========================================================================
; ОРДЕР: позиции PT2 (номер паттерна, конец - 128 и больше) -> наши паттерны
; =========================================================================
P2_Order
        xor a
        ld (Pm_Count),a
        ld (Po_Count),a
        ld hl,P2_LOOP
        call Pt_Get
        ld (Po_Loop),a
        ld hl,P2_ORDER
.pos    ld a,(Po_Count)             ; не больше 255 позиций
        cp 255
        ret nc
        call Pt_Get
        cp 128
        ret nc
        ld (Po_Key1),a
        ld a,#FF                    ; чип один
        ld (Po_Key2),a
        push hl
        call Pm_Find                ; A - наш номер, CF - некуда
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
P2_Patterns
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
        ld a,(Pp_N)
        ld hl,Pm_P1
        call Arr_Get
        call P2_Decode
        or a                        ; длина: пустой паттерн - 1 роу
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

;-------- Паттерн A -> роу паттерна в окне 2. Выход: A - роу (канал A дошёл до #00
; или до PAT_ROWS_MAX). Пропуск строк: Pc_Skip - сколько строк до следующей (1 - каждая)
P2_Decode
        ld l,a                      ; треки: таблица паттернов + номер*6
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        push hl
        ld hl,P2_PATS
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
        ld hl,Pc_Skip               ; пропуск 1, счётчик 1
        ld b,6
.one    ld (hl),1
        inc hl
        djnz .one
    ASSERT Pc_Cnt == Pc_Skip+3
        xor a
        ld (Pp_Row),a
.row    xor a
        ld (Pp_Ch),a
.ch     ld hl,Pc_Cnt                ; пропуск строк
        call Pc_Var
        dec (hl)
        jr nz,.nch
        ld a,(Pp_Ch)                ; канал A: #00 - конец паттерна
        or a
        jr nz,.parse
        call Pc_Peek_Byte
        or a
        jr z,.end
.parse  call P2_Row_Ch
        ld hl,Pc_Skip               ; счётчик - заново (Pc_Var портит A)
        call Pc_Var
        ld e,(hl)
        ld hl,Pc_Cnt
        call Pc_Var
        ld (hl),e
.nch    ld hl,Pp_Ch
        inc (hl)
        ld a,(hl)
        cp 3
        jp c,.ch
        ld hl,Pp_Row
        inc (hl)
        ld a,(hl)
        cp PAT_ROWS_MAX
        jp nz,.row
        call Pc_Peek_End            ; канал A на следующей строке кончается - всё влезло
        jp z,.end
        ld hl,Pt_Lost
        set PL_ROWS,(hl)
.end    ld a,(Pp_Row)
        ret

; Канал A: байт по его позиции
Pc_Peek_Byte
        ld hl,(Pc_Ptr)
        jp Pt_Get

;-------- Строка канала Pp_Ch: байты трека до конца строки -> клетка роу Pp_Row
P2_Row_Ch
        ld hl,Pc_Ptr                ; HL - позиция в треке
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.cmd    call Pt_Get
        cp #E1
        jp nc,.smp
        cp #E0
        jp z,.off
        cp #80
        jp nc,.note
        cp #7F
        jp z,.eoff
        cp #71
        jp nc,.env
        cp #70
        jp z,.end
        cp #60
        jp nc,.orn
        cp #20
        jp nc,.skp
        cp #10
        jp nc,.vol
        cp #0F
        jp z,.tempo
        cp #0E
        jp z,.glis
        cp #0D
        jp z,.porta
        cp #0C
        jp z,.cmdoff
        call Pt_Get                 ; #00..#0B: шум (в заголовок чипа)
        and #1F
        call Pr_Noise
        jp .cmd
.smp    sub #E0                     ; #E1..#FF: сэмпл 1..31
        ld c,CH_SAMPLE
        call Pr_Put
        jp .cmd
.off    ld a,NOTE_OFF               ; #E0: звук выкл, конец строки
        jp .putn
.note   sub #80-NOTE_FIRST          ; #80..#DF: нота, конец строки
.putn   ld c,CH_NOTE
        call Pr_Put
        jp .end
.eoff   call Pr_EnvOff              ; #7F: огибающая выкл
        jp .cmd
.env    sub #70                     ; #71..#7E: форма 1..14, период (младший первым)
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
.orn    sub #60                     ; #60..#6F: орнамент; огибающую выключает
        call Pr_Orn
        push hl
        call Pr_Cell
        ld a,l
        add a,CH_ENVSHAPE
        ld l,a
        ld a,(hl)
        pop hl
        or a
        call z,Pr_EnvOff
        jp .cmd
.skp    sub #20-1                   ; #20..#5F: пропуск 0..63 -> до следующей 1..64
        ld e,a
        push hl
        ld hl,Pc_Skip
        call Pc_Var
        ld (hl),e
        pop hl
        jp .cmd
.vol    sub #10                     ; #10..#1F: громкость (0 - не кладём)
        jp z,.cmd
        ld c,CH_VOLUME
        call Pr_Put
        jp .cmd
.tempo  call Pt_Get                 ; #0F: темп
        ld e,a
        ld d,CMD_SPEED<<4
        jp .put
.glis   call Pt_Get                 ; #0E: глиссандо, знак - направление
        ld d,CMD_GLIS_DOWN<<4|1
        or a
        jp p,.gp
        neg
        ld d,CMD_GLIS_UP<<4|1
.gp     ld e,a
        jp .put
.porta  call Pt_Get                 ; #0D: портаменто: шаг, разница периодов (не нужна)
        or a
        jp p,$+5
        neg
        ld e,a
        ld d,CMD_PORTA<<4|1
        push de
        call Pt_Get16
        pop de
        jp .put
.cmdoff ld de,CMD_GLIS_DOWN<<12     ; #0C: команды выкл (глиссандо 0)
.put    call P2_Cmd
        jp .cmd
.end    ex de,hl                    ; позиция в треке - на место
        ld hl,Pc_Ptr
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; Команда DE (D - код<<4 | задержка, E - параметр) - в свободное место клетки
; (мест нет - Pt_Lost). HL цел
P2_Cmd  push hl
        call Pr_Cell
        ld a,l
        add a,CH_CMD
        ld l,a
        ld b,CH_CMDS
.f      ld a,(hl)
        or a
        jr z,.got
        inc l
        inc l
        djnz .f
        ld hl,Pt_Lost
        set PL_CMDS,(hl)
        pop hl
        ret
.got    ld (hl),d
        inc l
        ld (hl),e
        pop hl
        ret

Txt_Pt2Cut      db "PT2 cut:",0
Txt_BadPt2      db "Bad PT2",0

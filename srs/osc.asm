; =========================================================================
; ОСЦИЛЛЯТОРЫ (doc/todo.md п.25): 6 окон 48x32 внизу экрана поверх текста - слой тайлов T0.
; Вторая страница плеера (окно 2). У окна свои 6x4 тайлов (кадр окон - строки битмапа
; спрайтов 288..319), карта ставится раз при входе в вид паттерна. Каждый кадр (Osc_Tick -
; IM1 сразу после тика плеера) окно собирает DMA по регистрам канала:
;   громкость v (огибающая - 15): верх - 15-v уровней по 2 строки - заливка нулями (прозрачно);
;   ниже - строка меандра (Osc_MRows, по периоду тона; тон выкл - сплошная) и её размножение
;   на 2v строк; строка 31 - линия нуля.
; Строки меандра - srs/oscgen.asm (раз при старте); цвет полос - из темы (Osc_Pal).
; =========================================================================

Ow_W            db 0                ; окно 0..5

;-------- Вход в вид паттерна: цвет полос из темы, карта окон, слой T0 - вкл
Osc_Init
        call Osc_Pal
        ld a,PAGE_TILEMAP           ; карта: всё - тайл 0 (прозрачный), окна - их тайлы
        SETPAGE3 a
        ld hl,#C000
        ld de,#C001
        ld bc,#3FFF
        ld (hl),0
        ldir
        ld hl,#C000+OSC_MAPROW*256  ; ряды 32..35, окно - 6 тайлов и зазор
        ld de,(OSC_TROW*64)|OSC_PAL ; тайлы ряда: окна подряд по 6
        ld c,4
.ty     push hl
        push de
        ld b,6
.w      push bc
        ld b,OSC_TW
.tx     ld (hl),e
        inc l
        ld (hl),d
        inc l
        inc de
        djnz .tx
        inc l                       ; зазор - тайл 0
        inc l
        pop bc
        djnz .w
        pop de
        pop hl
        inc h                       ; ряд карты ниже
        ld a,e                      ; ряд тайлов ниже: +64
        add a,64
        ld e,a
        jr nc,$+3
        inc d
        dec c
        jr nz,.ty
        RESTPAGE3
        ld bc,TMPAGE                ; слой T0: карта, графика, сдвиг, палитра
        ld a,PAGE_TILEMAP
        out (c),a
        ld bc,T0GPAGE
        ld a,PAGE_SPRITE
        out (c),a
        ld bc,T0XOFFSL
        ld a,low OSC_XOFFS
        out (c),a
        ld bc,T0XOFFSH
        ld a,high OSC_XOFFS
        out (c),a
        ld bc,T0YOFFSL
        xor a
        out (c),a
        ld bc,T0YOFFSH
        out (c),a
        ld bc,PALSEL                ; тайлам - палитра 3 (с палитрой в слове тайла - OSC_PALN)
        ld a,PALET_NUM|(3<<PAL_T0PAL_BS)|(3<<PAL_T1PAL_BS)
        out (c),a
        ld bc,TSCONFIG              ; спрайты + тайлы T0; тайл 0 прозрачный (бит T0ZEN - наоборот,
        ld a,TSU_SEN|TSU_T0EN       ;   показать тайл 0: video_ts.v tile_valid)
        out (c),a
        ret

;-------- Цвет полос (палитра OSC_PALN, цвет 1): цвет нот темы (ink CLR_NOTE) - слово из
; Pal_Data выбранной темы, в CRAM - DMA. Цвет 0 - прозрачный
Osc_Pal
        ld a,(THEME_ATTR+CLR_NOTE)
        and #0F
        call .col
        ld (Op_Buf),de
        ld hl,Op_Dma
        jp set_ports
; A - номер цвета темы -> DE - его слово (Pal_Data + тема*32 + номер*2)
.col    add a,a
        ld e,a
        ld a,(Cur_Palette)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,0
        ld de,Pal_Data
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

OSC_CRAM        equ OSC_PALN*16+OSC_COL_W   ; цвет полос в палитре тайлов
Op_Dma  db high DMASADDRL,low (Op_Buf-#8000), high DMASADDRH,high (Op_Buf-#8000), high DMASADDRX,PAGE_PLAYER2
        db high DMADADDRL,(OSC_CRAM&127)*2, high DMADADDRH,OSC_CRAM>>7, high DMADADDRX,0
        db high DMALEN,1-1, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
        ALIGN 2                     ; DMA берёт адрес словами
Op_Buf          ds 2                ; слово цвета полос
Osc_Zero        dw 0                ; заливка: прозрачно
Osc_Line        dw OSC_COL_W*#1111  ;   линия нуля

;-------- Выход из вида паттерна: тайлы - выкл
Osc_Off
        ld bc,TSCONFIG
        ld a,TSU_SEN
        out (c),a
        ret

;-------- Кадр (IM1 после тика плеера, страницы плеера - в окнах 1 и 2): окна по регистрам
Osc_Tick
        xor a
        ld (Ow_W),a
        ld hl,Pl_Regs               ; чип 1 - окна 0..2
        call .chip
        ld hl,Pl_Regs2              ; чип 2 - окна 3..5
.chip   ld b,0                      ; B - канал 0..2
.ch     push bc
        push hl
        call Osc_Win
        pop hl
        pop bc
        ld a,(Ow_W)
        inc a
        ld (Ow_W),a
        inc b
        ld a,b
        cp 3
        jr c,.ch
        ret

; Окно Ow_W, канал B: HL - регистры чипа (L = 0)
Osc_Win
        ld l,7                      ; тон выкл (бит B микшера) - сплошная
        ld a,(hl)
        ld c,b
        inc c
.r      rrca
        dec c
        jr nz,.r
        ld a,OSC_SOLID
        jr c,.pat
        ld a,b                      ; период R(2B): рисунок по старшим 8 битам из 12
        add a,a
        ld l,a
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld c,a
        inc l
        ld a,(hl)
        and #0F
        rlca
        rlca
        rlca
        rlca
        or c
        push hl
        ld l,a
        ld h,high Osc_PT
        ld a,(hl)
        pop hl
.pat    push hl                     ; строка рисунка: Osc_MRows + p*24 -> источник DMA
        ld l,a
        ld h,0
        add hl,hl                   ; *24 = *8*3
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,Osc_MRows-#8000
        add hl,de
        ld (Ow_Src),hl
        pop hl
        ld a,b                      ; громкость: огибающая - 15
        add a,8
        ld l,a
        ld a,(hl)
        bit 4,a
        ld a,15
        jr nz,.v
        ld a,(hl)
        and #0F
.v      add a,a                     ; строк меандра 2v
        ld (Ow_N),a
        ld a,(Ow_W)                 ; колонка окна в кадре: окно*24
        add a,a
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        ld (Od_DL),a
        ; 1. верх - нули: строки 0..30-2v (31-2v строк)
        ld hl,Osc_Zero-#8000
        ld a,PAGE_PLAYER2
        call Od_Src
        ld a,OSC_FBROW
        ld (Od_DH),a
        ld a,(Ow_N)
        cpl
        add a,31                    ; 30-2v = блоков-1
        ld (Od_NUM),a
        ld a,DMA_FILL|DMA_DALGN
        call Od_Go
        ; 2. меандр: строка 31-2v - строка рисунка, ниже - её размножение (2v-1 строк)
        ld a,(Ow_N)
        or a
        jr z,.line
        ld hl,(Ow_Src)
        ld a,PAGE_PLAYER2
        call Od_Src
        ld a,(Ow_N)
        cpl
        add a,OSC_FBROW+32          ; 31-2v
        ld (Od_DH),a
        ld (Ow_Row),a
        xor a
        ld (Od_NUM),a
        ld a,DMA_RAM
        call Od_Go
        ld a,(Ow_Row)               ; размножение: строка N -> N+1 (перекрытие)
        ld h,a
        ld a,(Od_DL)
        ld l,a
        ld a,OSC_FBPAGE
        call Od_Src
        ld a,(Ow_Row)
        inc a
        ld (Od_DH),a
        ld a,(Ow_N)
        sub 2
        ld (Od_NUM),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        call Od_Go
        ; 3. линия нуля - строка 31
.line   ld hl,Osc_Line-#8000
        ld a,PAGE_PLAYER2
        call Od_Src
        ld a,OSC_FBROW+31
        ld (Od_DH),a
        xor a
        ld (Od_NUM),a
        ld a,DMA_FILL
; A - DMACTR: пуск (set_ports_int ждёт прошлую DMA)
Od_Go   ld (Od_CTR),a
        ld hl,Od_T
        jp set_ports_int
; HL - источник в странице (H - строка 0..63, L - байт), A - страница
Od_Src  ld (Od_SX),a
        ld a,l
        ld (Od_SL),a
        ld a,h
        ld (Od_SH),a
        ret

Ow_Src          dw 0                ; строка рисунка (в странице)
Ow_N            db 0                ; строк меандра (2v)
Ow_Row          db 0                ; его первая строка в кадре
; DMA окна: приёмник - кадр окон (OSC_FBPAGE), строка 256 байт, длина - строка окна
Od_T    db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,0
        db high DMADADDRL,0, high DMADADDRH,0, high DMADADDRX,OSC_FBPAGE
        db high DMALEN,OSC_WB/2-1, high DMANUM,0, high DMACTR,0, #FF
Od_SL   equ Od_T+1
Od_SH   equ Od_T+3
Od_SX   equ Od_T+5
Od_DL   equ Od_T+7
Od_DH   equ Od_T+9
Od_NUM  equ Od_T+15
Od_CTR  equ Od_T+17

; Строки меандра (srs/oscgen.asm, раз при старте): рисунок p - 24 байта
        ALIGN 2
Osc_MRows       ds OSC_PATS*OSC_WB

; Период тона / 16 -> рисунок: полупериод полос по октавам (логарифм периода 28..3344 ->
; 1..14 точек, ~2 точки на октаву)
        ALIGN 256
Osc_PT  db 0,0,1,2,3,3,4,4,4,5,5,5,5,6,6,6
        db 6,6,6,7,7,7,7,7,7,7,7,7,8,8,8,8
        db 8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9
        db 9,9,9,9,9,9,9,9,9,9,10,10,10,10,10,10
        db 10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10
        db 10,10,10,11,11,11,11,11,11,11,11,11,11,11,11,11
        db 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
        db 11,11,11,11,11,11,11,11,12,12,12,12,12,12,12,12
        db 12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        db 12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12
        db 12,12,12,12,12,12,12,12,12,12,12,12,12,12,13,13
        db 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13
        db 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13
        db 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13
        db 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13
        db 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13

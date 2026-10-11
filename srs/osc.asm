; =========================================================================
; ОСЦИЛЛЯТОРЫ (doc/todo.md п.25): 2 ряда по 3 окна 96x32 внизу экрана (ряд - чип) поверх
; текста - слой тайлов T0. Вторая страница плеера (окно 2). У окна свои 12x4 тайлов (кадр окон -
; строки битмапа спрайтов 288..351), карта ставится раз при входе в вид паттерна. Каждый кадр (Osc_Tick -
; IM1 сразу после тика плеера) окно собирает DMA по регистрам канала:
;   громкость v (огибающая - 15): верх - 15-v уровней по 2 строки - заливка нулями (прозрачно);
;   ниже - строка меандра (Osc_MRows, по периоду тона; тон выкл - сплошная) и её размножение
;   на 2v строк; строка 31 - линия нуля.
; Строки меандра - srs/oscgen.asm (раз при старте); цвет полос - из темы (Osc_Pal).
; =========================================================================

Ow_R0           db 0                ; строка кадра окон чипа в его странице

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
        ld hl,#C000+OSC_MAPROW*256  ; чип 1: ряды карты 28..31
        ld de,(OSC_TROW*64)|OSC_PAL
        call .rows
        ld hl,#C000+(OSC_MAPROW+4)*256  ; чип 2: ряды 32..35
        ld de,((OSC_TROW+4)*64)|OSC_PAL
        call .rows
        RESTPAGE3
        jr .regs
; HL - ряд карты, DE - слово первого тайла: 4 ряда, в каждом 3 окна по OSC_TW тайлов и зазор
.rows   ld c,4
.ty     push hl
        push de
        ld b,3
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
        ret
.regs   ld bc,TMPAGE                ; слой T0: карта, графика, сдвиг, палитра
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
        ld hl,Ow_Fr                 ; кадр - для строк шума
        inc (hl)
        ld a,OSC_FBPAGE             ; чип 1: кадр окон - строки 32..63 страницы
        ld (Od_DX),a
        ld a,OSC_FBROW
        ld (Ow_R0),a
        xor a
        ld (Ow_Ch),a
        ld hl,Pl_Regs
        call Oe_Upd
        ld hl,Pl_Regs
        call .chip
        ld a,OSC_FBPAGE+1           ; чип 2: строки 0..31 следующей
        ld (Od_DX),a
        xor a
        ld (Ow_R0),a
        inc a
        ld (Ow_Ch),a
        ld hl,Pl_Regs2
        call Oe_Upd
        ld hl,Pl_Regs2
.chip   ld b,0                      ; B - канал 0..2
.ch     push bc
        push hl
        call Osc_Win
        pop hl
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.ch
        ret

; Окно канала B: HL - регистры чипа (L = 0); кадр окон чипа - Od_DX, Ow_R0; Ow_Ch - чип
Osc_Win
        ld l,7                      ; микшер (0 - вкл): после B+1 сдвигов CF - тон, бит 2 - шум
        ld a,(hl)
        ld c,b
        inc c
.r      rrca
        dec c
        jr nz,.r
        ld c,0                      ; C: бит 0 - тон вкл, бит 1 - шум вкл
        jr c,$+4
        set 0,c
        bit 2,a
        jr nz,$+4
        set 1,c
        ld a,c
        ld (Ow_TN),a
        ld a,OSC_SOLID              ; рисунок меандра: тон выкл - сплошной, иначе по периоду
        bit 0,c
        jr z,.pat
        ld a,b                      ; период R(2B): по старшим 8 битам из 12
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
.pat    ld (Ow_P),a
        ld a,b                      ; громкость; с огибающей (бит 4) - по её форме
        add a,8
        ld l,a
        ld a,(hl)
        bit 4,a
        jp z,.vol
        ld l,13
        ld a,(hl)
        and #0F
        ld e,a
        push hl
        ld hl,Oe_G
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)                   ; группа формы
        pop hl
        cp OE_LOOP
        jr c,.one
        ld a,(Ow_TN)                ; периодическая: тон вкл - меандр во всю высоту,
        rrca                        ;   тон выкл - картинка формы
        ld a,15
        jr c,.v
        ld a,e                      ; формы 8, 10, 12, 14 -> страница картинок
        sub 8
        rrca
        and 3
        push hl
        ld hl,Oe_Pg
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        pop hl
        jr .pic
.one    ld a,(Ow_Ch)                ; одиночная - её уровень сейчас (Oe_Upd)
        ld hl,Oe_Lv
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        jr .v
; картинка формы (страница C) на всё окно: цикл - как у тона 16*E (индекс таблицы - E),
; 2*полупериод -> ближайшая из OSC_SAWS длин
.pic    ld a,c
        ld (Od_SX),a
        ld l,12                     ; E больше 255 - самая длинная
        ld a,(hl)
        or a
        ld a,OSC_SOLID-1
        jr nz,.se
        dec l
        ld l,(hl)
        ld h,high Osc_PT
        ld a,(hl)
.se     ld hl,Osc_SL                ; полупериод -> картинка k
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld c,0                      ; место: полоса C = k/OSC_SPB, A = k%OSC_SPB
.dv     cp OSC_SPB
        jr c,.dd
        sub OSC_SPB
        inc c
        jr .dv
.dd     ld e,a                      ; байт: *48
        add a,a
        add a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld (Od_SL),a
        ld a,c                      ; строка: полоса*32
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld (Od_SH),a
        call .col                   ; приёмник: окно, строки 0..30
        ld a,(Ow_R0)
        ld (Od_DH),a
        ld a,30
        ld (Od_NUM),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        call Od_Go
        jp .line
.vol    and #0F
.v      add a,a                     ; строк 2v
        ld (Ow_N),a
        ; строка-источник: тон - меандр, шум - строка шума, тон и шум - AND, ничего - сплошная
        ld a,(Ow_P)                 ; меандр: Osc_MRows + p*48
        call .r48
        ld de,Osc_MRows
        add hl,de
        ld a,(Ow_TN)
        bit 1,a                     ; шума нет - меандр (или сплошная)
        jr z,.src
        push hl
        ld a,(Ow_Fr)                ; строка шума: (кадр + канал) mod OSC_NOISE
        add a,b
        and OSC_NOISE-1
        call .r48
        ld de,Osc_NRows
        add hl,de
        ex de,hl                    ; DE - шум
        pop hl                      ; HL - меандр
        ld a,(Ow_TN)
        rrca
        jr c,.and
        ex de,hl                    ; только шум
        jr .src
.and    push bc                     ; тон и шум: точка - где оба (AND) -> Ow_Tmp
        ld bc,Ow_Tmp
        ld a,OSC_WB
.an     push af
        ld a,(de)
        and (hl)
        ld (bc),a
        inc hl
        inc de
        inc bc
        pop af
        dec a
        jr nz,.an
        pop bc
        ld hl,Ow_Tmp
.src    ld a,h                      ; источник DMA - в странице (окно 2: -#8000)
        sub #80
        ld h,a
        ld (Ow_Src),hl
        call .col
        ; 1. верх - нули: строки 0..30-2v (31-2v строк)
        ld hl,Osc_Zero-#8000
        ld a,PAGE_PLAYER2
        call Od_Src
        ld a,(Ow_R0)
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
        ld c,a
        ld a,(Ow_R0)
        add a,32
        add a,c                     ; 31-2v
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
        ld a,(Od_DX)
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
        ld a,(Ow_R0)
        add a,31
        ld (Od_DH),a
        xor a
        ld (Od_NUM),a
        ld a,DMA_FILL
        jp Od_Go
; колонка окна в кадре: канал B * 48 -> приёмник DMA
.col    ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        add a,a
        add a,c
        ld (Od_DL),a
        ret
; A -> HL = A*48 (строка окна). Портит DE
.r48    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ret

;-------- Одиночная огибающая чипа Ow_Ch (HL - регистры, L = 0): шагов с записи R13 - счёт
; кадров (OE_STEP за кадр) / E, до 16; уровень по форме -> Oe_Lv
OE_STEP         equ 2187            ; 1.75 МГц / 50 / 16: шаг огибающей - 16*E тактов
OE_LOOP         equ 4               ; группа: периодическая
; Группа формы: 0 - вниз и 0, 1 - вверх и 0, 2 - вниз и 15, 3 - вверх и 15, 4 - периодическая
Oe_G    db 0,0,0,0, 1,1,1,1, 4,0,4,2, 4,3,4,1
Oe_Pg   db PAGE_OSCSAW,PAGE_OSCTRI1,PAGE_OSCSAW2,PAGE_OSCTRI2  ; картинки форм 8, 10, 12, 14
Oe_Acc  dw 0,0                      ; счёт по чипу
Oe_Lv   db 0,0                      ; уровень по чипу
Oe_Sh   db 0
Oe_Upd
        ld l,13                     ; форма
        ld a,(hl)
        and #0F
        ld (Oe_Sh),a
        ld l,11                     ; DE - период E (0 - как 1)
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,d
        or e
        jr nz,$+3
        inc e
        ld l,PR_R13W                ; C - R13 записан в этом тике: счёт с нуля
        ld c,(hl)
        ld a,(Ow_Ch)
        add a,a
        ld hl,Oe_Acc
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        or a
        jr z,.add
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        dec hl
        jr .cnt
.add    ld a,(hl)                   ; + кадр (до #FFFF)
        add a,low OE_STEP
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,high OE_STEP
        ld (hl),a
        dec hl
        jr nc,.cnt
        ld (hl),#FF
        inc hl
        ld (hl),#FF
        dec hl
.cnt    ld c,(hl)                   ; шагов = счёт / E, до 16
        inc hl
        ld b,(hl)
        xor a
.st     cp 16
        jr nc,.got
        ld h,b
        ld l,c
        or a
        sbc hl,de
        jr c,.got
        ld b,h
        ld c,l
        inc a
        jr .st
.got    ld b,a
        ld a,(Oe_Sh)
        ld hl,Oe_G
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)                   ; C - группа
        ld a,b
        cp 16
        jr nc,.end
        bit 0,c                     ; идёт: вверх - шаги, вниз - 15-шаги
        jr nz,.lv
        ld a,15
        sub b
        jr .lv
.end    bit 1,c                     ; кончилось: группы 2, 3 - 15, остальные - 0
        ld a,0
        jr z,.lv
        ld a,15
.lv     ld b,a
        ld a,(Ow_Ch)
        ld hl,Oe_Lv
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),b
        ret
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
Ow_TN           db 0                ; бит 0 - тон вкл, бит 1 - шум вкл
Ow_P            db 0                ; рисунок меандра
Ow_Ch           db 0                ; чип 0, 1
Ow_Fr           db 0                ; кадр (строки шума)
; DMA окна: приёмник - кадр окон (OSC_FBPAGE), строка 256 байт, длина - строка окна
Od_T    db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,0
        db high DMADADDRL,0, high DMADADDRH,0, high DMADADDRX,OSC_FBPAGE
        db high DMALEN,OSC_WB/2-1, high DMANUM,0, high DMACTR,0, #FF
Od_SL   equ Od_T+1
Od_SH   equ Od_T+3
Od_SX   equ Od_T+5
Od_DL   equ Od_T+7
Od_DX   equ Od_T+11

; Полупериод (рисунок 0..47) -> картинка пилы с ближайшей длиной цикла 2*(p+1) (Og_SawL:
; 4, 6, 8, 12, 16, 24, 32, 48, 64, 96)
Osc_SL  db 0,0,1,2,3,3,4,4,4,5,5,5,5,6,6,6
        db 6,6,6,7,7,7,7,7,7,7,7,8,8,8,8,8
        db 8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,9
    ASSERT $-Osc_SL == OSC_SOLID
Od_DH   equ Od_T+9
Od_NUM  equ Od_T+15
Od_CTR  equ Od_T+17

; Строки меандра (srs/oscgen.asm, раз при старте): рисунок p - 48 байт
        ALIGN 2
Osc_MRows       ds OSC_PATS*OSC_WB
Osc_NRows       ds OSC_NOISE*OSC_WB ; строки шума (srs/oscgen.asm)
Ow_Tmp          ds OSC_WB           ; тон AND шум - строка кадра

; Период тона / 16 -> рисунок: полупериод 48*(P/3344)^0.71 точек - от 1 (P 14, самая высокая)
; до 48 (полокна, самая низкая); октава - в 1.6 раза
        ALIGN 256
Osc_PT  db 0,0,1,2,2,3,3,4,4,4,5,5,6,6,6,7
        db 7,7,8,8,8,9,9,9,10,10,10,10,11,11,11,12
        db 12,12,12,13,13,13,14,14,14,14,15,15,15,15,16,16
        db 16,16,17,17,17,17,18,18,18,18,19,19,19,19,19,20
        db 20,20,20,21,21,21,21,21,22,22,22,22,23,23,23,23
        db 23,24,24,24,24,25,25,25,25,25,26,26,26,26,26,27
        db 27,27,27,27,28,28,28,28,28,29,29,29,29,29,30,30
        db 30,30,30,31,31,31,31,31,32,32,32,32,32,32,33,33
        db 33,33,33,34,34,34,34,34,35,35,35,35,35,35,36,36
        db 36,36,36,37,37,37,37,37,37,38,38,38,38,38,38,39
        db 39,39,39,39,40,40,40,40,40,40,41,41,41,41,41,41
        db 42,42,42,42,42,42,43,43,43,43,43,43,44,44,44,44
        db 44,44,45,45,45,45,45,45,46,46,46,46,46,46,47,47
        db 47,47,47,47,47,47,47,47,47,47,47,47,47,47,47,47
        db 47,47,47,47,47,47,47,47,47,47,47,47,47,47,47,47
        db 47,47,47,47,47,47,47,47,47,47,47,47,47,47,47,47

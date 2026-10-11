; =========================================================================
; ОСЦИЛЛЯТОРЫ (doc/todo.md п.25): 6 окон 56x32 внизу экрана поверх текста - слой тайлов T0.
; Вторая страница плеера (окно 2). Тайлы генерируются раз (Osc_Init - вход в вид паттерна,
; заново - только если сменились цвета темы): на каждый рисунок (полосы шириной 1..28 точек
; по периоду тона; OSC_SOLID - сплошной: тон выкл) - 4 уровня заполнения снизу (2, 4, 6, 8
; точек), по 7 тайлов в ряд, и тайл фона. Каждый кадр (Osc_Tick - IM1 сразу после тика
; плеера) - только номера тайлов в карту: окно = 4 ряда по 7. Высота - громкость*2 точек,
; огибающая - вся высота (32).
; Графика - в странице спрайтов (свободные ряды тайлов OSC_TROW..), карта - PAGE_TILEMAP.
; =========================================================================
OSC_TROW        equ 40              ; первый ряд сгенерированных тайлов (битмап спрайтов, y 320)
OSC_PATS        equ 29              ; рисунков: 0..27 - полосы шириной 1..28, 28 - сплошной
OSC_SOLID       equ 28
OSC_GROUPS      equ OSC_PATS*4      ; групп по 7 тайлов: рисунок*4 + уровень-1
OSC_GPR         equ 9               ; групп в ряду тайлов (63 тайла из 64)
OSC_BGROW       equ OSC_TROW+(OSC_GROUPS+OSC_GPR-1)/OSC_GPR    ; ряд тайла фона
OSC_MAPROW      equ 32              ; ряд карты = строка экрана 256: окна - ряды 32..35
OSC_XOFFS       equ 512-12          ; окна - 42 тайла (336 точек) по центру 360
OSC_PAL         equ 1<<12           ; палитра тайла 1 (+ PALSEL тайлов 3) = палитра 13 текста
    ASSERT OSC_BGROW*8+8 <= 448     ; ниже - строки 448..511 (запас)

Osc_Col         dw #FFFF            ; цвета, с которыми сгенерированы тайлы: E - полосы, D - фон
Osc_WB          db 0                ; байт полос (две точки)
Osc_BB          db 0                ;   фона
Osc_Row         ds 28               ; строка рисунка: 56 точек
Osc_BgRow       ds 28               ;   фона
Og_P            db 0                ; генерация: рисунок
Og_L            db 0                ;   уровень 1..4
Og_GA           dw 0                ;   адрес группы в Osc_GA
Os_W            db 0                ; полосы: ширина
Os_C            db 0                ;   счётчик точек
Os_On           db 0                ;   0 - полоса, 1 - фон
Ow_H            db 0                ; окно: высота 0..32
Ow_P            db 0                ;   рисунок

;-------- Вход в вид паттерна: тайлы (если сменились цвета), пустая карта, слой T0 - вкл
Osc_Init
        ld a,(THEME_ATTR+CLR_NOTE)  ; цвета темы: полосы - нота (ink), фон - фон темы (paper)
        and #0F
        ld e,a
        ld a,(THEME_ATTR+CLR_BG)
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld d,a
        ld hl,(Osc_Col)
        or a
        sbc hl,de
        jr z,.map                   ; те же - тайлы уже есть
        ld (Osc_Col),de
        call Osc_Gen
.map    ld a,PAGE_TILEMAP           ; карта - пустая (тайл 0 прозрачный: текст виден)
        SETPAGE3 a
        ld hl,#C000
        ld de,#C001
        ld bc,#3FFF
        ld (hl),0
        ldir
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
        ld bc,PALSEL                ; тайлам - палитра 3 (с палитрой тайла 1 - это 13)
        ld a,PALET_NUM|(3<<PAL_T0PAL_BS)|(3<<PAL_T1PAL_BS)
        out (c),a
        ld bc,TSCONFIG              ; спрайты + тайлы T0 (тайл 0 - прозрачный)
        ld a,TSU_SEN|TSU_T0EN|TSU_T0ZEN
        out (c),a
        ret

;-------- Выход из вида паттерна: тайлы - выкл
Osc_Off
        ld bc,TSCONFIG
        ld a,TSU_SEN
        out (c),a
        ret

;-------- Тайлы всех рисунков и уровней + тайл фона (цвета - Osc_Col)
Osc_Gen
        ld a,(Osc_Col)              ; байты по две точки
        call .dup
        ld (Osc_WB),a
        ld a,(Osc_Col+1)
        call .dup
        ld (Osc_BB),a
        ld hl,Osc_BgRow             ; строка фона
        ld b,28
.bgr    ld (hl),a
        inc hl
        djnz .bgr
        ld hl,Osc_GA
        ld (Og_GA),hl
        xor a
        ld (Og_P),a
.p      ld a,(Og_P)                 ; рисунок -> Osc_Row
        call Osc_Stripe
        ld a,1
        ld (Og_L),a
.l      ld hl,(Og_GA)               ; группа: адрес и страница в битмапе
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (Og_GA),hl
        SETPAGE3 a
        ld a,(Og_L)                 ; заполнено 2L строк снизу: с 8-2L
        add a,a
        neg
        add a,8
        ld c,a
        ld b,0                      ; B - строка тайла 0..7
.y      push bc
        ld a,b
        cp c
        ld hl,Osc_BgRow
        jr c,$+5
        ld hl,Osc_Row
        push de
        ld bc,28                    ; 7 тайлов подряд - 28 байт строки битмапа
        ldir
        pop de
        inc d                       ; следующая строка битмапа (+256)
        pop bc
        inc b
        ld a,b
        cp 8
        jr c,.y
        RESTPAGE3
        ld hl,Og_L
        inc (hl)
        ld a,(hl)
        cp 5
        jr c,.l
        ld hl,Og_P
        inc (hl)
        ld a,(hl)
        cp OSC_PATS
        jr c,.p
        ld a,PAGE_SPRITE+OSC_BGROW*8/64     ; тайл фона
        SETPAGE3 a
        ld hl,#C000+(OSC_BGROW*8%64)*256
        ld a,(Osc_BB)
        ld b,8
.bg     ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        dec l
        dec l
        dec l
        inc h
        djnz .bg
        RESTPAGE3
        ret
; A - цвет 0..15 -> A*#11 (две точки)
.dup    ld b,a
        rlca
        rlca
        rlca
        rlca
        or b
        ret

;-------- A - рисунок -> Osc_Row: 56 точек (старший полубайт - левая точка): полосы шириной
; A+1 (сначала цвет полос, потом фон), OSC_SOLID - сплошной
Osc_Stripe
        ld hl,Osc_Row
        cp OSC_SOLID
        jr nz,.st
        ld a,(Osc_WB)
        ld b,28
.s      ld (hl),a
        inc hl
        djnz .s
        ret
.st     inc a
        ld (Os_W),a
        ld (Os_C),a
        xor a
        ld (Os_On),a
        ld b,28
.b      call .px                    ; левая точка
        rlca
        rlca
        rlca
        rlca
        ld c,a
        call .px                    ; правая
        or c
        ld (hl),a
        inc hl
        djnz .b
        ret
; очередная точка -> A (цвет), счёт полосы
.px     ld a,(Os_On)
        or a
        ld a,(Osc_Col)              ; полоса
        jr z,$+5
        ld a,(Osc_Col+1)            ; фон
        push af
        ld a,(Os_C)
        dec a
        jr nz,.k
        ld a,(Os_On)                ; полоса кончилась - другая
        xor 1
        ld (Os_On),a
        ld a,(Os_W)
.k      ld (Os_C),a
        pop af
        ret

;-------- Кадр (IM1 после тика плеера, страницы плеера - в окнах 1 и 2): окна по регистрам
Osc_Tick
        ld a,PAGE_TILEMAP
        SETPAGE3 a
        ld hl,Pl_Regs               ; чип 1 - окна 0..2
        ld de,#C000+OSC_MAPROW*256
        call .chip
        ld hl,Pl_Regs2              ; чип 2 - окна 3..5
        ld de,#C000+OSC_MAPROW*256+3*7*2
        call .chip
        RESTPAGE3
        ret
; HL - регистры чипа (L = 0), DE - карта окна канала A
.chip   ld b,0                      ; B - канал 0..2
.ch     push bc
        push de
        push hl
        call Osc_Win
        pop hl
        pop de
        pop bc
        ld a,e                      ; окно правее - 7 тайлов
        add a,7*2
        ld e,a
        inc b
        ld a,b
        cp 3
        jr c,.ch
        ret

; Окно канала B: HL - регистры чипа (L = 0), DE - карта (ряд 32, его колонка)
Osc_Win
        ld l,7                      ; тон выкл (бит B микшера) - сплошной
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
.pat    ld (Ow_P),a
        ld a,b                      ; высота: огибающая - вся, иначе громкость*2
        add a,8
        ld l,a
        ld a,(hl)
        bit 4,a
        ld a,32
        jr nz,.h
        ld a,(hl)
        and #0F
        add a,a
.h      ld (Ow_H),a
        sub 24                      ; 4 ряда сверху вниз: заполнение ряда - высота минус
        call .row                   ;   ряды ниже (8 на ряд)
        ld a,(Ow_H)
        sub 16
        call .row
        ld a,(Ow_H)
        sub 8
        call .row
        ld a,(Ow_H)
; A - заполнение ряда (0 и меньше - фон, больше 8 - 8): 7 номеров тайлов в карту (DE),
; DE - на ряд ниже
.row    or a
        jp m,.bg
        jr z,.bg
        cp 9
        jr c,$+4
        ld a,8
        rrca                        ; уровень 1..4 -> группа рисунок*4 + уровень-1
        dec a
        ld l,a
        ld a,(Ow_P)
        add a,a
        add a,a
        add a,l
        add a,a                     ; слово таблицы
        ld l,a
        ld h,high Osc_GT
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld b,7                      ; 7 тайлов подряд
.t      ld a,l
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        inc hl
        djnz .t
        jr .next
.bg     ld hl,(OSC_BGROW*64)|OSC_PAL
        ld b,7
.tb     ld a,l
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        djnz .tb
.next   ld a,e                      ; ряд карты ниже
        sub 7*2
        ld e,a
        inc d
        ret

; Группа тайлов -> адрес и страница её первой строки в битмапе спрайтов (окно 3)
    MACRO OSC_GA_GEN
Ok = 0
    DUP OSC_GROUPS
Oy = (OSC_TROW + Ok/OSC_GPR)*8
        dw #C000 + (Oy%64)*256 + (Ok%OSC_GPR)*7*4
        db PAGE_SPRITE + Oy/64
Ok = Ok + 1
    EDUP
    ENDM
Osc_GA  OSC_GA_GEN

; Группа тайлов -> слово карты её первого тайла (номер + палитра)
    MACRO OSC_GT_GEN
Ok = 0
    DUP OSC_GROUPS
        dw ((OSC_TROW + Ok/OSC_GPR)*64 + (Ok%OSC_GPR)*7) | OSC_PAL
Ok = Ok + 1
    EDUP
    ENDM
        ALIGN 256
Osc_GT  OSC_GT_GEN
    ASSERT high Osc_GT == high (Osc_GT+OSC_GROUPS*2-1)

; Период тона / 16 -> рисунок: ширина полос по логарифму периода (14..3344 -> 1..28 точек)
        ALIGN 256
Osc_PT  db 0,2,5,6,8,9,9,10,11,11,12,12,13,13,14,14
        db 14,14,15,15,15,16,16,16,16,16,17,17,17,17,17,17
        db 18,18,18,18,18,18,18,19,19,19,19,19,19,19,19,20
        db 20,20,20,20,20,20,20,20,20,20,21,21,21,21,21,21
        db 21,21,21,21,21,21,22,22,22,22,22,22,22,22,22,22
        db 22,22,22,22,22,22,23,23,23,23,23,23,23,23,23,23
        db 23,23,23,23,23,23,23,23,23,24,24,24,24,24,24,24
        db 24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,25
        db 25,25,25,25,25,25,25,25,25,25,25,25,25,25,25,25
        db 25,25,25,25,25,25,25,25,25,25,25,26,26,26,26,26
        db 26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26
        db 26,26,26,26,26,26,26,26,26,26,26,26,26,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27

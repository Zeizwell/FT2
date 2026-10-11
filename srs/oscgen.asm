; =========================================================================
; ОСЦИЛЛЯТОРЫ: генерация тайлов - раз при старте (стартовый код, страница #02: после запуска
; не нужен). Точки - постоянные номера цветов: 1 - полосы, 2 - фон; сами цвета - палитра
; тайлов OSC_PALN, её два цвета из темы ставит Osc_Pal (srs/osc.asm) при входе в вид паттерна.
; На каждый рисунок (полосы шириной 1..28 точек по периоду тона; OSC_SOLID - сплошной: тон
; выкл) - 4 уровня заполнения снизу (2, 4, 6, 8 точек), по 7 тайлов в ряд, и тайл фона.
; Графика - в свободных рядах тайлов страниц спрайтов (OSC_TROW..).
; =========================================================================
OSC_TROW        equ 40              ; первый ряд сгенерированных тайлов (битмап спрайтов, y 320)
OSC_PATS        equ 29              ; рисунков: 0..27 - полосы шириной 1..28, 28 - сплошной
OSC_SOLID       equ 28
OSC_GROUPS      equ OSC_PATS*4      ; групп по 7 тайлов: рисунок*4 + уровень-1
OSC_GPR         equ 9               ; групп в ряду тайлов (63 тайла из 64)
OSC_BGROW       equ OSC_TROW+(OSC_GROUPS+OSC_GPR-1)/OSC_GPR    ; ряд тайла фона
OSC_MAPROW      equ 32              ; ряд карты = строка экрана 256: окна - ряды 32..35
OSC_XOFFS       equ 512-12          ; окна - 42 тайла (336 точек) по центру 360
OSC_PALN        equ 14              ; палитра тайлов: PALSEL тайлов 3, палитра в слове 2
OSC_PAL         equ (OSC_PALN&3)<<12
OSC_COL_W       equ 1               ; номер цвета полос
OSC_COL_BG      equ 2               ;   фона
    ASSERT OSC_BGROW*8+8 <= 448     ; ниже - строки 448..511 (запас)
    ASSERT OSC_PALN != PALET_NUM

Osc_Row         ds 28               ; строка рисунка: 56 точек
Osc_BgRow       ds 28               ;   фона
Og_P            db 0                ; рисунок
Og_L            db 0                ; уровень 1..4
Og_GA           dw 0                ; адрес группы в Osc_GA
Os_W            db 0                ; полосы: ширина
Os_C            db 0                ;   счётчик точек
Os_On           db 0                ;   0 - полоса, 1 - фон

;-------- Тайлы всех рисунков и уровней + тайл фона
Osc_Gen
        ld hl,Osc_BgRow             ; строка фона
        ld b,28
.bgr    ld (hl),OSC_COL_BG*#11
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
        ld b,8
.bg     ld (hl),OSC_COL_BG*#11
        inc l
        ld (hl),OSC_COL_BG*#11
        inc l
        ld (hl),OSC_COL_BG*#11
        inc l
        ld (hl),OSC_COL_BG*#11
        dec l
        dec l
        dec l
        inc h
        djnz .bg
        RESTPAGE3
        ret

;-------- A - рисунок -> Osc_Row: 56 точек (старший полубайт - левая точка): полосы шириной
; A+1 (сначала цвет полос, потом фон), OSC_SOLID - сплошной
Osc_Stripe
        ld hl,Osc_Row
        cp OSC_SOLID
        jr nz,.st
        ld b,28
.s      ld (hl),OSC_COL_W*#11
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
; очередная точка -> A (номер цвета), счёт полосы
.px     ld a,(Os_On)
        or a
        ld a,OSC_COL_W
        jr z,$+4
        ld a,OSC_COL_BG
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

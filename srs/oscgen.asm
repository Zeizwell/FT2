; =========================================================================
; ОСЦИЛЛЯТОРЫ: генерация тайлов - раз при старте (стартовый код, страница #02: после запуска
; не нужен). Залитые полосы (под маску огибающей вторым слоем): точка 1 - полоса (цвет из темы,
; палитра тайлов OSC_PALN, ставит Osc_Pal), 0 - прозрачно (виден текст). На каждый рисунок
; (полосы шириной 1..28 точек по периоду тона; OSC_SOLID - сплошной: тон выкл) - OSC_VARS
; вариантов ряда (заполнение снизу 2..8 строк; для нижнего ряда - с линией нуля), по 7 тайлов,
; и группа "только линия" (громкость 0). Над волной в карте - тайл 0. Графика TSU - 4 бита на точку.
; Графика - в свободных рядах тайлов страниц спрайтов (OSC_TROW..).
; =========================================================================
OSC_TROW        equ 36              ; первый ряд тайлов (битмап спрайтов, y 288): верх страниц - курсор и
                                    ;   кнопки транспорта (Head_Sprites рисует их позже и затирал тайлы)
OSC_PATS        equ 29              ; рисунков: 0..27 - полосы шириной 1..28, 28 - сплошной
OSC_SOLID       equ 28
OSC_VARS        equ 8               ; вариантов ряда: 0..3 - заполнен снизу на 2, 4, 6, 8 строк;
                                    ;   4..7 - нижний ряд окна: то же + линия нуля (строка 7)
OSC_GBASE       equ OSC_PATS*OSC_VARS   ; группа "только линия" (громкость 0)
OSC_GROUPS      equ OSC_GBASE+1     ; групп по 7 тайлов: рисунок*OSC_VARS + вариант, + линия
OSC_GPR         equ 9               ; групп в ряду тайлов (63 тайла из 64)
OSC_MAPROW      equ 32              ; ряд карты = строка экрана 256: окна - ряды 32..35
OSC_XOFFS       equ 512-8           ; окна - 42 тайла (336 точек): слева 8, справа 16 - сдвиг кратен 8
                                    ;   (дробный сдвиг тайлов давал черту у правого края)
OSC_PALN        equ 14              ; палитра тайлов: PALSEL тайлов 3, палитра в слове 2
OSC_PAL         equ (OSC_PALN&3)<<12
OSC_COL_W       equ 1               ; номер цвета полос
OSC_COL_BG      equ 0               ;   прозрачно
    ASSERT (OSC_TROW+(OSC_GROUPS+OSC_GPR-1)/OSC_GPR)*8 <= 512
    ASSERT OSC_PALN != PALET_NUM

Osc_Row         ds 28               ; строка рисунка: 56 точек
Osc_BgRow       ds 28               ;   прозрачная (0)
Osc_LineRow     ds 28               ;   линия нуля (сплошная)
Og_Var          db 0                ; вариант группы
Og_P            db 0                ; рисунок
Og_L            db 0                ; вариант 0..7
Og_GA           dw 0                ; адрес группы в Osc_GA
Os_W            db 0                ; полосы: ширина
Os_C            db 0                ;   счётчик точек
Os_On           db 0                ;   0 - полоса, 1 - фон

;-------- Тайлы всех рисунков и вариантов + группа "только линия"
Osc_Gen
        ld hl,Osc_LineRow           ; линия нуля
        ld b,28
.ln     ld (hl),OSC_COL_W*#11
        inc hl
        djnz .ln
        ld hl,Osc_GA
        ld (Og_GA),hl
        xor a
        ld (Og_P),a
.p      ld a,(Og_P)                 ; рисунок -> Osc_Row
        call Osc_Stripe
        xor a
        ld (Og_L),a
.l      ld a,(Og_L)
        call Og_Group
        ld hl,Og_L
        inc (hl)
        ld a,(hl)
        cp OSC_VARS
        jr c,.l
        ld hl,Og_P
        inc (hl)
        ld a,(hl)
        cp OSC_PATS
        jr c,.p
        ld a,OSC_VARS               ; "только линия": строки 0..6 прозрачны

; A - вариант (OSC_VARS - только линия): очередная группа Osc_GA, 8 строк
Og_Group
        ld (Og_Var),a
        ld hl,(Og_GA)               ; группа: адрес и страница в битмапе
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (Og_GA),hl
        SETPAGE3 a
        ld c,8                      ; C - первая строка полос: 8 - 2*(уровень)
        ld a,(Og_Var)
        cp OSC_VARS
        jr nc,.f
        and 3
        inc a
        add a,a
        neg
        add a,8
        ld c,a
.f      ld b,0                      ; B - строка тайла 0..7
.y      push bc
        ld a,(Og_Var)               ; нижний ряд (вариант 4 и больше): строка 7 - линия
        cp 4
        jr c,.ny
        ld a,b
        cp 7
        ld hl,Osc_LineRow
        jr z,.cp
.ny     ld a,b                      ; полосы - с первой строки, выше - прозрачно
        cp c
        ld hl,Osc_BgRow
        jr c,.cp
        ld hl,Osc_Row
.cp     push de
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

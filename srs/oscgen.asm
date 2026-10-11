; =========================================================================
; ОСЦИЛЛЯТОРЫ: генерация - раз при старте (стартовый код, страница #02: после запуска не
; нужен). Строки меандра (Osc_MRows, вторая страница плеера): на рисунок p - одна строка окна
; 96 точек: полосы шириной p+1 точек (0..27 - по периоду тона), 28 - сплошная (тон выкл).
; Точки 4 бита: 1 - полоса (цвет нот темы, палитра тайлов OSC_PALN), 0 - прозрачно (текст виден).
; Окно каждый кадр собирает DMA (srs/osc.asm).
; =========================================================================
OSC_W           equ 96              ; точек в окне
OSC_WB          equ OSC_W/2         ; байт строки окна
OSC_TW          equ OSC_W/8         ; тайлов в окне (ряд из 3 окон по 12 - 36 в строке: больше TSU в
                                    ;   текстовом режиме за строку не успевает)
OSC_H           equ 32              ; строк в окне: 0..30 - громкость (по 2 на уровень), 31 - линия нуля
OSC_PATS        equ 29              ; рисунков: 0..27 - полупериод 1..28 точек, 28 - сплошной
OSC_SOLID       equ 28
OSC_FBPAGE      equ PAGE_SPRITE+4   ; окна чипа 1: строки 32..63 страницы (битмап 288..319), чипа 2 -
                                    ;   строки 0..31 следующей (320..351)
OSC_FBROW       equ 32
OSC_TROW        equ 36              ; ряд тайлов окон чипа 1 (чипа 2 - +4)
OSC_MAPROW      equ 28              ; ряд карты окон чипа 1 = строка экрана 224 (чипа 2 - +4: 256)
OSC_XOFFS       equ 512-24          ; ряд: 3 окна по 96 через 8 (304) по центру 360, сдвиг кратен 8
OSC_PALN        equ 14              ; палитра тайлов: PALSEL тайлов 3, палитра в слове 2
OSC_PAL         equ (OSC_PALN&3)<<12
OSC_COL_W       equ 1               ; номер цвета полосы (0 - прозрачно)
    ASSERT OSC_PALN != PALET_NUM

Og_Row          ds OSC_WB           ; строка рисунка
Og_P            db 0                ; рисунок
Os_W            db 0                ; полупериод
Os_C            db 0                ;   счётчик точек
Os_On           db 0                ;   0 - полоса, 1 - промежуток

;-------- Строки меандра всех рисунков - в Osc_MRows (вторая страница плеера, через окно 3)
Osc_Gen
        ld a,PAGE_PLAYER2
        SETPAGE3 a
        ld de,Osc_MRows-#8000+#C000
        xor a
        ld (Og_P),a
.p      push de
        ld a,(Og_P)
        call Osc_Stripe
        pop de
        ld hl,Og_Row
        ld bc,OSC_WB
        ldir
        ld hl,Og_P
        inc (hl)
        ld a,(hl)
        cp OSC_PATS
        jr c,.p
        RESTPAGE3
        ret

;-------- A - рисунок -> Og_Row: 96 точек (старший полубайт - левая), полоса / промежуток по
; полупериоду A+1, сначала полоса; OSC_SOLID - сплошная полоса
Osc_Stripe
        ld hl,Og_Row
        cp OSC_SOLID
        jr nz,.st
        ld b,OSC_WB
.s      ld (hl),OSC_COL_W*#11
        inc hl
        djnz .s
        ret
.st     inc a
        ld (Os_W),a
        ld (Os_C),a
        xor a
        ld (Os_On),a
        ld b,OSC_WB
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
; очередная точка -> A (номер цвета), счёт полупериода
.px     ld a,(Os_On)
        or a
        ld a,OSC_COL_W
        jr z,$+3
        xor a
        push af
        ld a,(Os_C)
        dec a
        jr nz,.k
        ld a,(Os_On)                ; полупериод кончился - другой
        xor 1
        ld (Os_On),a
        ld a,(Os_W)
.k      ld (Os_C),a
        pop af
        ret

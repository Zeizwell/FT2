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
OSC_PATS        equ 49              ; рисунков: 0..47 - полупериод 1..48 точек (до полокна), 48 - сплошной
OSC_SOLID       equ 48
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
        jp Og_Saws                  ; и картинки пилы

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

;-------- Пила огибающей: картинки на всё окно (96 x 31 строк, строка 31 - линия нуля - не
; трогаем) для OSC_SAWS длин цикла (Og_SawL); вниз (форма 8) - PAGE_OSCSAW, вверх (12) -
; PAGE_OSCSAW2. Место картинки k: строка (k/OSC_SPB)*32, байт (k%OSC_SPB)*OSC_WB.
; Уровень 0..15 -> высота столбца уровень*2+1 строк; точка 1 - под кривой, 0 - прозрачно
OSC_SAWS        equ 10
OSC_SPB         equ 256/OSC_WB      ; картинок в полосе страницы
    ASSERT (OSC_SAWS+OSC_SPB-1)/OSC_SPB*32 <= 64
Og_SawL         db 4,6,8,12,16,24,32,48,64,96   ; длина цикла в точках
Og_H            ds OSC_W            ; высота столбца (строк снизу)
Og_K            db 0
Og_S            db 0                ; 0 - вниз, 1 - вверх
Og_L            db 0
Og_Y            db 0

Og_Saws
        xor a
        ld (Og_S),a
.s      xor a
        ld (Og_K),a
.k      ld a,(Og_K)                 ; длина цикла
        ld hl,Og_SawL
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (Og_L),a
        call Og_Heights
        ld a,(Og_K)                 ; место: полоса C = k/OSC_SPB, A = k%OSC_SPB
        ld c,0
.dv     cp OSC_SPB
        jr c,.dd
        sub OSC_SPB
        inc c
        jr .dv
.dd     ld b,a                      ; байт: A*OSC_WB (48 = 16*3)
        add a,a
        add a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,c                      ; строка: полоса*32
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,#C0
        ld d,a
        ld a,(Og_S)
        or a
        ld a,PAGE_OSCSAW
        jr z,$+4
        ld a,PAGE_OSCSAW2
        SETPAGE3 a
        xor a
        ld (Og_Y),a
.y      push de                     ; строка y (0 - верх): точка - если y + высота >= 31
        ld hl,Og_H
        ld b,OSC_WB
.x      push bc
        ld a,(Og_Y)                 ; левая
        add a,(hl)
        cp 31
        ld c,OSC_COL_W<<4
        jr nc,$+4
        ld c,0
        inc hl
        ld a,(Og_Y)                 ; правая
        add a,(hl)
        cp 31
        ld a,OSC_COL_W
        jr nc,$+3
        xor a
        or c
        ld (de),a
        inc hl
        inc e
        pop bc
        djnz .x
        pop de
        inc d
        ld hl,Og_Y
        inc (hl)
        ld a,(hl)
        cp 31
        jr c,.y
        RESTPAGE3
        ld hl,Og_K
        inc (hl)
        ld a,(hl)
        cp OSC_SAWS
        jp c,.k
        ld hl,Og_S
        inc (hl)
        ld a,(hl)
        cp 2
        jp c,.s
        ret

; Og_L, Og_S -> Og_H[x]: t = x mod L, f = 16*t/L; уровень - вниз 15-f, вверх f; высота уровень*2+1
Og_Heights
        ld hl,Og_H
        ld c,0                      ; C - x
.x      ld a,(Og_L)
        ld b,a
        ld a,c
.m      cp b
        jr c,.mm
        sub b
        jr .m
.mm     push hl
        push bc
        ld l,a                      ; 16*t / L
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(Og_L)
        ld c,a
        ld b,0
        xor a
.d      or a
        sbc hl,bc
        jr c,.dd
        inc a
        jr .d
.dd     pop bc
        pop hl
        cp 16
        jr c,$+4
        ld a,15
        ld b,a
        ld a,(Og_S)
        or a
        ld a,b
        jr nz,.up
        ld a,15
        sub b
.up     add a,a
        inc a
        ld (hl),a
        inc hl
        inc c
        ld a,c
        cp OSC_W
        jr c,.x
        ret

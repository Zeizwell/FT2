; =========================================================================
; ОСЦИЛЛЯТОРЫ: генерация - раз при старте (стартовый код, страница #02: после запуска не
; нужен). Полоса меандра (Osc_Strip, вторая страница плеера) - одна длинная, как в индикаторе FT:
; полупериод плавно растёт по ней (в точке x - как у периода x/4), окно тона берёт 96 точек с
; места 4*период; Osc_Solid - сплошная строка (тон выкл).
; Точки 4 бита: 1 - полоса (цвет нот темы, палитра тайлов OSC_PALN), 0 - прозрачно (текст виден).
; Окно каждый кадр собирает DMA (srs/osc.asm).
; =========================================================================
OSC_W           equ 96              ; точек в окне
OSC_WB          equ OSC_W/2         ; байт строки окна
OSC_TW          equ OSC_W/8         ; тайлов в окне (ряд из 3 окон по 12 - 36 в строке: больше TSU в
                                    ;   текстовом режиме за строку не успевает)
OSC_H           equ 32              ; строк в окне: 0..30 - громкость (по 2 на уровень), 31 - линия нуля
OSC_SOLID       equ 48              ; полупериодов в Osc_PT: 0..47 - 1..48 точек (картинки огибающей)
OSC_STRIP       equ 4096*2+OSC_WB   ; полоса меандра: период 0..4095 по 4 точки + хвост на окно
OSC_FBPAGE      equ PAGE_SPRITE+4   ; окна чипа 1: строки 32..63 страницы (битмап 288..319), чипа 2 -
                                    ;   строки 0..31 следующей (320..351)
OSC_FBROW       equ 32
OSC_TROW        equ 36              ; ряд тайлов окон чипа 1 (чипа 2 - +4)
OSC_MAPROW      equ 28              ; ряд карты окон чипа 1 = строка экрана 224 (чипа 2 - +4: 256)
OSC_XOFFS       equ 512-24          ; ряд: 3 окна по 96 через 8 (304) по центру 360, сдвиг кратен 8
OSC_PALN        equ 14              ; палитра тайлов: PALSEL тайлов 3, палитра в слове 2
OSC_PAL         equ (OSC_PALN&3)<<12
OSC_COL_W       equ 1               ; номер цвета полосы (0 - прозрачно)
OSC_COL_BG      equ 2               ; номер цвета фона (маска огибающей: над кривой)
OSC_NOISE       equ 8               ; строк шума (случайные точки; кадр - следующая)
    ASSERT OSC_PALN != PALET_NUM

Og_X            dw 0                ; точка полосы
Og_Acc          dw 0                ; полупериод: накопление с дробной частью (как GetStep в FT)
Os_C            db 0                ;   счётчик точек
Os_On           db 0                ;   0 - полоса, 1 - промежуток

;-------- Полоса меандра, сплошная строка и строки шума - во вторую страницу плеера (окно 3)
Osc_Gen
        ld a,PAGE_PLAYER2
        SETPAGE3 a
        ld hl,0
        ld (Og_X),hl
        ld (Og_Acc),hl
        xor a                       ; сначала полоса, полупериод - первый шаг
        ld (Os_On),a
        call Og_Step
        ld de,Osc_Strip-#8000+#C000
        ld bc,OSC_STRIP
.st     push bc
        call Og_Px                  ; левая точка
        rlca
        rlca
        rlca
        rlca
        ld c,a
        call Og_Px                  ; правая
        or c
        ld (de),a
        inc de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.st
        ld b,OSC_WB                 ; сплошная строка (DE - сразу за полосой)
.so     ld a,OSC_COL_W*#11
        ld (de),a
        inc de
        djnz .so
        ld de,Osc_NRows-#8000+#C000 ; строки шума: случайные точки (LFSR)
        ld bc,OSC_NOISE*OSC_WB
.nz     push bc
        call Og_Bit                 ; левая точка
        rlca
        rlca
        rlca
        rlca
        ld c,a
        call Og_Bit                 ; правая
        or c
        ld (de),a
        inc de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.nz
        RESTPAGE3
        jp Og_Saws                  ; и маски огибающей

; Случайная точка -> A: OSC_COL_W или 0 (LFSR 16 бит). Портит HL
Og_Rnd          dw #ACE1
Og_Bit  ld hl,(Og_Rnd)
        srl h
        rr l
        jr nc,.z
        ld a,h
        xor #B4
        ld h,a
        ld (Og_Rnd),hl
        ld a,OSC_COL_W
        ret
.z      ld (Og_Rnd),hl
        xor a
        ret

;-------- Очередная точка полосы -> A (номер цвета); полупериод кончился - другой (Og_Step)
Og_Px   ld hl,(Og_X)
        inc hl
        ld (Og_X),hl
        ld a,(Os_On)
        or a
        ld a,OSC_COL_W
        jr z,$+3
        xor a
        push af
        ld hl,Os_C
        dec (hl)
        jr nz,.k
        ld a,(Os_On)
        xor 1
        ld (Os_On),a
        call Og_Step
.k      pop af
        ret

; Полупериод в точке Og_X -> Os_C: накопление += x + 32 (период x/4: шаг 4P+32 как в FT, /256),
; целая часть - точки (не меньше 1), дробная остаётся
Og_Step push de
        ld hl,(Og_X)
        ld de,32
        add hl,de
        ld de,(Og_Acc)
        add hl,de
        ld a,h
        ld h,0
        ld (Og_Acc),hl
        or a
        jr nz,$+3
        inc a
        ld (Os_C),a
        pop de
        ret

;-------- Маски огибающей: картинки на всё окно (96 x 31 строк, строка 31 - линия нуля - не
; трогаем) для OSC_SAWS длин цикла (Og_SawL); вниз (форма 8) - PAGE_OSCSAW, вверх (12) -
; PAGE_OSCSAW2. Место картинки k: строка (k/OSC_SPB)*32, байт (k%OSC_SPB)*OSC_WB.
; Уровень 0..15 -> высота столбца уровень*2+1 строк; под кривой 0 (меандр виден), над - цвет фона
; (OSC_COL_BG): блиттер кладёт маску поверх меандра - псевдо-AND
OSC_SAWS        equ 10
OSC_SPB         equ 256/OSC_WB      ; картинок в полосе страницы
    ASSERT (OSC_SAWS+OSC_SPB-1)/OSC_SPB*32 <= 64
Og_SawL         db 4,6,8,12,16,24,32,48,64,96   ; длина цикла в точках
Og_H            ds OSC_W            ; высота столбца (строк снизу)
Og_K            db 0
Og_S            db 0                ; форма: 0 - пила вниз, 1 - вверх, 2 - треугольник вниз-вверх, 3 - вверх-вниз
Og_SPg          db PAGE_OSCSAW,PAGE_OSCSAW2,PAGE_OSCTRI1,PAGE_OSCTRI2  ; их страницы
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
        ld a,(Og_S)                 ; страница формы
        ld hl,Og_SPg
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        SETPAGE3 a
        xor a
        ld (Og_Y),a
.y      push de                     ; строка y (0 - верх): фон - если y + высота < 31
        ld hl,Og_H
        ld b,OSC_WB
.x      push bc
        ld a,(Og_Y)                 ; левая
        add a,(hl)
        cp 31
        ld c,0
        jr nc,$+4
        ld c,OSC_COL_BG<<4
        inc hl
        ld a,(Og_Y)                 ; правая
        add a,(hl)
        cp 31
        ld a,0                      ; флаги не трогает
        jr nc,$+4
        ld a,OSC_COL_BG
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
        cp 4
        jp c,.s
        ret

; Og_L, Og_S -> Og_H[x]: f = 16*t/L (t - место в склоне); пила: t = x mod L, уровень вниз 15-f,
; вверх f; треугольник: t = x mod 2L, два склона (вниз-вверх или вверх-вниз). Высота уровень*2+1
Og_Heights
        ld hl,Og_H
        ld c,0                      ; C - x
.x      ld a,(Og_L)
        ld b,a
        ld a,(Og_S)                 ; треугольник: период - 2 склона
        cp 2
        jr c,$+4
        sla b
        ld a,c
.m      cp b
        jr c,.mm
        sub b
        jr .m
.mm     ld e,0                      ; E - 1: второй склон (t-L)
        ld b,a
        ld a,(Og_L)
        ld d,a
        ld a,b
        cp d
        jr c,.sl
        sub d
        inc e
.sl     push hl
        push bc
        push de
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
.dd     pop de
        pop bc
        pop hl
        cp 16
        jr c,$+4
        ld a,15
        ld b,a
        ld a,(Og_S)                 ; направление: 0 - вниз (15-f), 1 - вверх (f); пила - по форме,
        cp 2                        ;   треугольник: (форма-2) xor склон
        jr c,.dir
        and 1
        xor e
.dir    or a
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

; =========================================================================
; ПРИМИТИВЫ ИНТЕРФЕЙСА (часть коре, doc/ui.md, слой 1): рисуют только они, элементы (окно, группа,
; кнопка...) - на них. Прямоугольник - Pr_X, Pr_Y, Pr_W, Pr_H (Pr_Y - строка в окне 3: #C0 + y,
; у шапки - её буфер); цвет - C (готовый атрибут роли: THEME_ATTR + CLR_*). Экран - в окне 3.
; =========================================================================
BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘

Pr_X            db 0
Pr_Y            db 0
Pr_W            db 0
Pr_H            db 0

;-------- Прямоугольник из HL: x, y (уже с #C0), w, h -> Pr_X..Pr_H. HL += 4
Pr_Rect
        ld de,Pr_X
        ld bc,4
        ldir
        ret

;-------- Залить прямоугольник знаком A цветом C
Pr_Fill
        ld (.ch+1),a
        ld a,(Pr_Y)
        ld d,a
        ld a,(Pr_H)
        ld b,a
.r      push bc
        ld a,(Pr_X)
        ld e,a
        ld a,(Pr_W)
        ld b,a
.ch     ld a,' '                    ; (знак - сюда)
        call PutCh
        djnz .ch
        inc d
        pop bc
        djnz .r
        ret

;-------- Прямоугольник - только атрибуты цветом C (знаки под ним остаются): тень, подсветка
Pr_Attr
        ld a,(Pr_Y)
        ld h,a
        ld a,(Pr_H)
        ld b,a
.r      ld a,(Pr_X)
        or 128
        ld l,a
        push bc
        ld a,(Pr_W)
        ld b,a
.c      ld (hl),c
        inc l
        djnz .c
        pop bc
        inc h
        djnz .r
        ret

;-------- Рамка ┌─┐│└─┘ по прямоугольнику цветом C; внутри не трогает
Pr_Box
        ld a,(Pr_Y)                 ; верх
        ld d,a
        ld a,BOX_TL
        ld b,BOX_TR
        call .line
        ld a,(Pr_H)                 ; бока
        sub 2
        jr z,.bot
        ld b,a
.s      inc d
        ld a,(Pr_X)
        ld e,a
        ld a,BOX_V
        call PutCh
        ld a,(Pr_X)
        ld hl,Pr_W
        add a,(hl)
        dec a
        ld e,a
        ld a,BOX_V
        call PutCh
        djnz .s
.bot    inc d                       ; низ
        ld a,BOX_BL
        ld b,BOX_BR
; строка D: A - левый угол, B - правый, между - ─
.line   push bc
        push af
        ld a,(Pr_X)
        ld e,a
        pop af
        call PutCh
        ld a,(Pr_W)
        sub 2
        ld b,a
.h      ld a,BOX_H
        call PutCh
        djnz .h
        pop bc
        ld a,b
        jp PutCh

;-------- Линия ─ с DE, B знаков, цвет C
Pr_HLine
        ld a,BOX_H
        call PutCh
        djnz Pr_HLine
        ret

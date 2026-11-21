; =========================================================================
; ВЕРТИКАЛЬНЫЙ СКРОЛЛБАР (часть коре, стандарт, doc/ui.md; перенесён из редактора FX) (как был в паттерне, f16da38; как в DOS / Turbo Vision):
; ▲ сверху, ▼ снизу, дорожка ▒ (CLR_SB_TRACK), ползунок ▓ (CLR_SB_THUMB) - длина = доля видимой части
; =========================================================================
SB_TRACK        equ #B1             ; ▒ дорожка
SB_THUMB        equ #B2             ; ▓ ползунок
Vsb_Col         db 0                ; колонка
Vsb_Top         db 0                ; первая строка экрана (с TL_SCR_H)
Vsb_H           db 0                ; высота со стрелками (не меньше 3)
Vsb_Total       db 0                ; всего строк
Vsb_Vis         db 0                ; видно строк
Vsb_First       db 0                ; первая видимая
Vsb_Len         db 0                ; ползунок: длина
Vsb_Pos         db 0                ;   начало на дорожке

;-------- Длина и место ползунка по Vsb_* -> Vsb_T, Vsb_Len, Vsb_Pos
Vsb_Calc
        ld a,(Vsb_H)                ; дорожка = высота - 2 стрелки
        sub 2
        ld (Vsb_T),a
        ld a,(Vsb_Total)            ; всё видно - ползунок во всю дорожку
        ld hl,Vsb_Vis
        cp (hl)
        jr z,.all
        jr nc,.part
.all    ld a,(Vsb_T)
        ld (Vsb_Len),a
        xor a
        ld (Vsb_Pos),a
        ret
.part   ld a,(Vsb_T)                ; длина = дорожка * видно / всего (не меньше 1)
        ld hl,Vsb_Vis
        ld e,(hl)
        call Vsb_Mul                ; HL = A * E
        ld a,(Vsb_Total)
        call Vsb_Div                ; A = HL / A
        or a
        jr nz,$+3
        inc a
        ld (Vsb_Len),a
        ld b,a                      ; начало = (дорожка - длина) * первая / (всего - видно)
        ld a,(Vsb_T)
        sub b
        ld hl,Vsb_First
        ld e,(hl)
        call Vsb_Mul
        ld a,(Vsb_Vis)
        ld b,a
        ld a,(Vsb_Total)
        sub b
        call Vsb_Div
        ld (Vsb_Pos),a
        ret

;-------- Нарисовать по Vsb_*
Vsb_Draw
        call Vsb_Calc
        ld a,(Vsb_Top)              ; ▲
        ld d,a
        ld a,(Vsb_Col)
        ld e,a
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,GLYPH_SCR_UP
        call PutCh
        ld b,0                      ; дорожка: клетка B
.t      ld a,b
        ld hl,Vsb_T
        cp (hl)
        jr nc,.dn
        inc d
        ld a,(Vsb_Col)
        ld e,a
        ld a,b                      ; в ползунке: Pos <= B < Pos + Len
        ld hl,Vsb_Pos
        sub (hl)
        jr c,.tr
        ld hl,Vsb_Len
        cp (hl)
        jr nc,.tr
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,SB_THUMB
        jr .put
.tr     ld a,(THEME_ATTR+CLR_SB_TRACK)
        ld c,a
        ld a,SB_TRACK
.put    call PutCh
        inc b
        jr .t
.dn     inc d                       ; ▼
        ld a,(Vsb_Col)
        ld e,a
        ld a,(THEME_ATTR+CLR_SB_THUMB)
        ld c,a
        ld a,GLYPH_SCR_DOWN
        jp PutCh
Vsb_T           db 0                ; длина дорожки

;-------- HL = A * E
Vsb_Mul
        ld hl,0
        ld d,0
        or a
        ret z
.m      add hl,de
        dec a
        jr nz,.m
        ret

;-------- A = HL / A (A > 0, частное < 256)
Vsb_Div
        ld e,a
        ld d,0
        ld a,-1
        or a
.d      inc a
        sbc hl,de
        jr nc,.d
        ret

;-------- Где клик по скроллбару: A - строка экрана (без TL_SCR_H) -> A: 0 - ▲, 1 - дорожка выше
; ползунка, 2 - ползунок, 3 - ниже, 4 - ▼ (по последней отрисовке)
Vsb_Hit
        ld hl,Vsb_Top
        add a,TL_SCR_H
        sub (hl)
        ld b,a
        or a
        ld a,0
        ret z                       ; ▲
        ld a,(Vsb_H)
        dec a
        cp b
        ld a,4
        ret z                       ; ▼
        ld a,b                      ; клетка дорожки
        dec a
        ld hl,Vsb_Pos
        sub (hl)
        ld a,1
        ret c                       ; выше ползунка
        ld a,b
        dec a
        sub (hl)
        ld hl,Vsb_Len
        cp (hl)
        ld a,2
        ret c                       ; на ползунке
        ld a,3
        ret

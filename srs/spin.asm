; =========================================================================
; ПОЛЕ ЧИСЛА (часть коре) - одно на всех, как в MilkyTracker: "nn[+][-]". Одно поле на число и
; обе кнопки: ширина поля = знаков числа + 4. Параметр поля (FLD_PARAM) - описание:
;   dw уменьшить, увеличить     ; действия экрана (зовутся со страницей поля в окне 1)
;   db знаков числа, роль цвета кнопок (CLR_*)
; Клик по [+] / [-] - действие, держат - повтор (пока мышь над той же кнопкой), колесо над полем -
; вверх [+], вниз [-]. Число рисует экран, кнопки - Sp_Draw (нажатая - вдавлена).
; =========================================================================
SP_MINUS        equ 0               ; описание: смещения
SP_PLUS         equ 2
SP_DIGITS       equ 4
SP_CLR          equ 5

Sp_Part         db 0                ; кнопка, на которой нажали: 0 - нет, 1 - [+], 2 - [-]

;-------- Обработчик поля числа (IX - поле, A - событие, C - колесо)
Sp_Ev
        cp EV_PRESS
        jr z,.press
        cp EV_REPEAT
        jr z,.rep
        cp EV_RELEASE
        jr z,.rel
        cp EV_WHEEL
        ret nz
        ld a,c                      ; колесо: вверх - [+], вниз - [-]
        or a
        ret z
        ld a,1
        jp p,Sp_Act
        inc a
        jr Sp_Act
.press  call Sp_At                  ; нажали: на какой кнопке
        ld (Sp_Part),a
        jr Sp_Act
.rep    call Sp_At                  ; держат: мышь всё ещё на той же кнопке
        ld hl,Sp_Part
        cp (hl)
        jr z,Sp_Act
        scf
        ret
.rel    xor a
        ld (Sp_Part),a
        scf
        ret

; A - кнопка (1 - [+], 2 - [-], 0 - мимо): действие из описания поля. CF = 1
Sp_Act
        or a
        scf
        ret z
        ld l,(ix+FLD_PARAM)         ; описание
        ld h,(ix+FLD_PARAM+1)
        dec a
        jr nz,.m
        inc hl                      ; [+] - второе слово
        inc hl
.m      ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .go
        scf
        ret
.go     jp (hl)
    ASSERT SP_MINUS == 0 && SP_PLUS == 2

; Кнопка под мышью: A = 1 - [+], 2 - [-], 0 - мимо (число, другое поле). IX - поле
Sp_At
        push ix                     ; мышь над этим полем?
        pop hl
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        ld a,0
        ret nz
        ld l,(ix+FLD_PARAM)         ; колонка от кнопок: X поля + знаков числа
        ld h,(ix+FLD_PARAM+1)
        ld de,SP_DIGITS
        add hl,de
        ld a,(SV_MOUSE_COL)
        sub (ix+FLD_X)
        sub (hl)
        jr c,.no
        cp 2
        ld a,1
        ret c
        ld a,2
        ret
.no     xor a
        ret

;-------- Кнопки поля числа: IX - поле, D - строка экрана (адрес). Нажатая (на ней нажали и мышь
; над ней) - вдавлена
Sp_Draw
        ld l,(ix+FLD_PARAM)
        ld h,(ix+FLD_PARAM+1)
        ld bc,SP_DIGITS
        add hl,bc
        ld a,(ix+FLD_X)             ; E - за числом
        add a,(hl)
        ld e,a
        inc hl                      ; C - цвет кнопок
        ld a,(hl)
        add a,low THEME_ATTR
        ld l,a
        ld h,high THEME_ATTR
        ld c,(hl)
        push de
        call Sp_Down                ; B - вдавленная (0 - нет)
        pop de
        ld a,GLYPH_BTN_PLUS
        dec b
        call Sp_Glyph
        ld a,GLYPH_BTN_MINUS
        dec b
; Значок A (2 знака: A, A+1), Z - вдавлен (+BTN_PRESSED). Цвет C, E += 2
Sp_Glyph
        jr nz,$+4
        add a,BTN_PRESSED
        push af
        call PutCh
        pop af
        inc a
        jp PutCh

; B - вдавленная кнопка поля IX: на ней нажали и мышь над ней (0 - нет). Портит DE, HL
Sp_Down
        ld b,0
        push ix
        pop hl
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ret nz
        call Sp_At
        ld hl,Sp_Part
        cp (hl)
        ret nz
        ld b,a
        ret

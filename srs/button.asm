; =========================================================================
; КНОПКА (часть коре) - одна на всех, как в Turbo Vision: надпись на плашке, под мышью - подсветка,
; держат - нажата. Поле кнопки: флаг FF_BTN, ширина поля = ширина плашки, параметр (FLD_PARAM) -
; описание:
;   dw действие                 ; по клику (страница поля - в окне 1), 0 - нет
;   dw надпись                  ; текст, 0 (с пробелами по краям; остаток плашки - пробелы)
;   db флаги                    ; BF_SHADOW - тень: ▄ справа и ▀ строкой ниже (строка под кнопкой
;                               ;   должна быть свободна); нажатая - на колонку вправо, тени нет
;   db тень, фон                ; роли цвета (CLR_*): тень на фоне под кнопкой и сам фон (с BF_SHADOW)
;   dw после                    ; после действия (перерисовать), 0 - нет
; Цвета плашки: обычная - CLR_BUTTON, под мышью - CLR_HOVER, нажата - CLR_CURSOR.
; Рисует Bn_DrawList (все кнопки списка полей) / Bn_Draw - каждый кадр, чтобы подсветка ходила за мышью.
; =========================================================================
BD_ACT          equ 0               ; описание: смещения
BD_TEXT         equ 2
BD_FLAGS        equ 4
BD_SHADOW       equ 5
BD_BG           equ 6
BD_AFTER        equ 7
BF_SHADOW       equ %00000001
BN_SH_RIGHT     equ #DC             ; ▄ - тень справа
BN_SH_DOWN      equ #DF             ; ▀ - тень снизу

;-------- Обработчик кнопки: клик - действие, потом "после"
Bn_Ev
        cp EV_CLICK
        ret nz
        ld l,(ix+FLD_PARAM)
        ld h,(ix+FLD_PARAM+1)
        push hl
        ld a,(hl)                   ; действие
        inc hl
        ld h,(hl)
        ld l,a
        or h
        push ix                     ; действие может портить IX
        call nz,Bn_Jp
        pop ix
        pop hl
        ld de,BD_AFTER
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        call nz,Bn_Jp
        scf
        ret
Bn_Jp   jp (hl)

;-------- Все кнопки (флаг FF_BTN) списка полей IX; A - строка экрана поля Y = 0
Bn_DrawList
        ld (Bn_Base),a
.f      ld a,(ix+FLD_X)
        cp FLD_END
        ret z
        bit 6,(ix+FLD_FLAGS)        ; FF_BTN
        jr z,.n
        ld a,(Bn_Base)
        add a,(ix+FLD_Y)
        ld d,a
        call Bn_Draw
.n      ld de,FLD_SIZE
        add ix,de
        jr .f
    ASSERT FF_BTN == %01000000
Bn_Base         db 0

;-------- Кнопка IX, D - её строка экрана (адрес)
Bn_Draw
        ld l,(ix+FLD_PARAM)         ; описание - в Bn_D
        ld h,(ix+FLD_PARAM+1)
        push de
        ld de,Bn_D
        ld bc,BD_AFTER
        ldir
        pop de
        push de
        call Bn_State               ; A: 0 - обычная, 1 - под мышью, 2 - нажата
        pop de
        ld (Bn_St),a
        ld hl,THEME_ATTR+CLR_BUTTON
        or a
        jr z,.c
        ld hl,THEME_ATTR+CLR_HOVER
        dec a
        jr z,.c
        ld hl,THEME_ATTR+CLR_CURSOR
.c      ld c,(hl)
        ld e,(ix+FLD_X)
        ld a,(Bn_D+BD_FLAGS)        ; с тенью и нажата: слева - фон, плашка на колонку правее
        and BF_SHADOW
        jr z,.t
        ld a,(Bn_St)
        cp 2
        jr nz,.t
        push bc
        ld a,(Bn_D+BD_BG)
        call Bn_Role
        ld a,' '
        call PutCh
        pop bc
.t      ld hl,(Bn_D+BD_TEXT)        ; надпись, остаток - пробелы
        ld b,(ix+FLD_W)
.ch     ld a,(hl)
        or a
        jr z,.sp
        inc hl
        call PutCh
        djnz .ch
        jr .sh
.sp     ld a,' '
        call PutCh
        djnz .sp
.sh     ld a,(Bn_D+BD_FLAGS)        ; тень
        and BF_SHADOW
        ret z
        ld a,(Bn_St)
        cp 2
        jr z,.down                  ; нажата: справа уже плашка, снизу - фон
        ld a,(Bn_D+BD_SHADOW)       ; справа ▄
        call Bn_Role
        ld a,BN_SH_RIGHT
        call PutCh
        ld a,BN_SH_DOWN             ; снизу ▀ - с колонки x+1
        jr .row
.down   ld a,(Bn_D+BD_BG)
        call Bn_Role
        ld a,' '
.row    inc d
        ld e,(ix+FLD_X)
        inc e
        ld b,(ix+FLD_W)
.r      push af
        call PutCh
        pop af
        djnz .r
        dec d
        ret

; C - готовый цвет роли A (THEME_ATTR + роль)
Bn_Role
        add a,low THEME_ATTR
        ld l,a
        ld h,high THEME_ATTR
        ld c,(hl)
        ret
    ASSERT (THEME_ATTR & 255) + THEME_ROLES_MAX <= 256   ; роли - в одной 256-странице

; Состояние кнопки IX: A = 0 - обычная, 1 - под мышью, 2 - нажата (на ней нажали и мышь над ней)
Bn_State
        push ix
        pop hl
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        ld a,0
        ret nz
        push ix
        pop hl
        ld de,(SV_PRESSED)
        sbc hl,de                   ; CF = 0
        ld a,1
        ret nz
        inc a
        ret

Bn_D            ds BD_AFTER         ; описание рисуемой кнопки
Bn_St           db 0

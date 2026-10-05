; =========================================================================
; ТЕКСТ И ТАБЛИЦЫ: общее для всех экранов (часть коре)
; =========================================================================
; Символ A цветом C в DE (D - строка, E - колонка), цвет на +128. E++
PutCh
        ld (de),a
        set 7,e
        ld a,c
        ld (de),a
        res 7,e
        inc e
        ret

; HL - строка, конец 0. C - цвет. На выходе HL - на 0
PutStr
.l      ld a,(hl)
        or a
        ret z
        call PutCh
        inc hl
        jr .l

PutHex2
        push af
        rrca
        rrca
        rrca
        rrca
        and #0F
        call HexDigit
        call PutCh
        pop af
        and #0F
        call HexDigit
        jp PutCh

HexDigit
        cp 10
        jr c,.d
        add a,7
.d      add a,'0'
        ret

; A - индекс, HL - массив байт -> A = массив[индекс]
Arr_Get
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret

;-------- Таблица клавиш: HL - таблица (код, модификаторы точно, обработчик; конец 0),
; B - код, C - флаги события. Выход: CF - клавиша наша (обработчик вызван)
Keys_Table
        ld a,c
        and KM_SHIFT|KM_CTRL|KM_ALT ; повтор и нажатие для таблицы одинаковы
        ld c,a
.f      ld a,(hl)                   ; код, 0 - конец таблицы
        or a
        ret z                       ; не наша (CF = 0)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)                   ; модификаторы
        dec hl
        cp c
        jr nz,.n
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call .jp
        scf
        ret
.n      inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.jp     jp (hl)


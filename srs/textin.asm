; =========================================================================
; СТРОКА ВВОДА ТЕКСТА (часть коре) - одна на всех: Song / By в шапке, имя инструмента, орнамента,
; FX, имя файла в Disk. Буфер - Ti_Max знаков, 0 - конец (полный - без 0). Курсор - Ti_Pos.
; Клик - курсор на знак под мышью (и за текстом: буква туда - до неё пробелы), буква - вставить под курсор (хвост
; вправо, последний знак уходит), Shift - заглавные и !@#$..., <- -> Home End - курсор, Backspace - знак
; слева, Delete - под курсором, Enter / Esc - готово. Поле в фокусе - одно, состояние - одно.
; Обработчик поля зовёт: EV_FOCUS_IN - Ti_Begin, EV_PRESS - Ti_Click, EV_KEY - Ti_Key
; (перед каждым - Ti_Set: буфер мог переехать), рисует текст и Ti_Cursor.
; =========================================================================
Ti_Buf          dw 0                ; буфер
Ti_Max          db 16               ; знаков в нём
Ti_Pos          db 0                ; курсор 0..Ti_Max-1
Ti_Ch           db 0

TI_MOVE         equ 0               ; Ti_Key: только курсор
TI_EDIT         equ 1               ;   текст сменился - сохранить
TI_DONE         equ 2               ;   Enter / Esc - фокус назад

;-------- HL - буфер, A - знаков в нём
Ti_Set
        ld (Ti_Buf),hl
        ld (Ti_Max),a
        ret

;-------- Фокус пришёл: буфер HL на A знаков, хвост из пробелов - нулями (имена из модулей
; дополнены пробелами), курсор - на первый знак
Ti_Begin
        call Ti_Set
        xor a
        ld (Ti_Pos),a
        ld hl,(Ti_Buf)              ; с последнего знака назад
        ld a,(Ti_Max)
        ld e,a
        ld d,0
        add hl,de
        ld b,a
.t      dec hl
        ld a,(hl)
        cp ' '+1
        ret nc
        ld (hl),0
        djnz .t
        ret

;-------- Клик: A - колонка мыши от начала поля - курсор туда (и за текстом)
Ti_Click
        ld (Ti_Pos),a
; Курсор - не дальше последнего знака поля
Ti_Edge
        ld a,(Ti_Max)
        dec a
        ld hl,Ti_Pos
        cp (hl)
        ret nc
        ld (hl),a
        ret

;-------- A - длина текста (до 0 или Ti_Max). HL, BC целы
Ti_Len
        push hl
        push bc
        ld hl,(Ti_Buf)
        ld a,(Ti_Max)
        ld b,a
        ld c,0
.l      ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        djnz .l
.e      ld a,c
        pop bc
        pop hl
        ret

;-------- Курсор - не дальше конца текста и не дальше последнего знака
Ti_Clamp
        call Ti_Len
        ld hl,Ti_Max
        cp (hl)
        jr c,.m
        ld a,(hl)
        dec a
.m      ld hl,Ti_Pos
        cp (hl)
        ret nc
        ld (hl),a
        ret

;-------- Клавиша B (C - флаги). CF - наша, тогда A: TI_MOVE / TI_EDIT / TI_DONE
Ti_Key
        ld a,b
        cp KEY_ENTER
        jr z,.done
        cp KEY_ESC
        jr z,.done
        cp KEY_LEFT
        jr z,.left
        cp KEY_RIGHT
        jr z,.right
        cp KEY_HOME
        jr z,.home
        cp KEY_END
        jr z,.end
        cp KEY_BACK
        jr z,.back
        cp KEY_DEL
        jr z,.del
        cp KEY_TAB                  ; Tab - не наш (фокус - у тулзы)
        ret z
        or a                        ; E0-коды - не наши (CF = 0)
        ret m
        ld h,high Key_Chars         ; код -> символ (0 - не символ); Shift - таблица за ней
        ld l,a
        bit 0,c
        jr z,$+4
        set 7,l
        ld a,(hl)
        or a
        ret z
.put    call Ti_Ins
        jr .edit
.done   ld a,TI_DONE
        scf
        ret
.left   ld hl,Ti_Pos
        ld a,(hl)
        or a
        jr z,.move
        dec (hl)
        jr .move
.right  ld hl,Ti_Pos                ; вправо - до края поля (и за текстом)
        inc (hl)
        call Ti_Edge
        jr .move
.home   xor a
        ld (Ti_Pos),a
        jr .move
.end    ld a,#FF
        ld (Ti_Pos),a
        call Ti_Clamp
.move   ld a,TI_MOVE
        scf
        ret
.back   ld hl,Ti_Pos                ; знак слева: курсор влево и стереть под ним
        ld a,(hl)
        or a
        jr z,.move
        dec (hl)
.del    call Ti_Del
.edit   ld a,TI_EDIT
        scf
        ret
    ASSERT KM_SHIFT == 1

;-------- Знак A - вставить под курсор: хвост вправо (последний знак уходит), курсор вправо.
; Курсор за текстом - до него пробелы
Ti_Ins
        ld (Ti_Ch),a
        call Ti_Len                 ; A - длина
        ld hl,Ti_Pos
        sub (hl)
        jr nc,.in                   ; курсор в тексте или сразу за ним
        neg                         ; пробелов: курсор - длина
        ld b,a
        call Ti_Here
.sp     dec hl
        ld (hl),' '
        djnz .sp
.in
        call Ti_Here                ; HL - под курсором, A - знаков от курсора до конца буфера - 1
        or a
        jr z,.set
        push hl
        ld hl,(Ti_Buf)              ; с конца: Max-2 -> Max-1, ...
        ld a,(Ti_Max)
        ld e,a
        ld d,0
        add hl,de
        dec hl
        ld d,h
        ld e,l
        dec hl
        ld a,(Ti_Cnt)
        ld c,a
        ld b,0
        lddr
        pop hl
.set    ld a,(Ti_Ch)
        ld (hl),a
        ld hl,Ti_Pos                ; курсор вправо, не дальше последнего знака
        ld a,(Ti_Max)
        dec a
        cp (hl)
        ret z
        inc (hl)
        ret

;-------- Стереть знак под курсором: хвост влево, последний знак - 0
Ti_Del
        call Ti_Len                 ; курсор за текстом - нечего
        ld hl,Ti_Pos
        cp (hl)
        ret z
        ret c
        call Ti_Here
        ld d,h
        ld e,l
        or a
        jr z,.z
        inc hl
        ld c,a
        ld b,0
        ldir
.z      xor a
        ld (de),a
        ret

; HL - знак под курсором, A (и Ti_Cnt) - сколько знаков за ним в буфере (Max-1-Pos)
Ti_Cnt          db 0
Ti_Here
        ld a,(Ti_Pos)
        ld e,a
        ld d,0
        ld hl,(Ti_Buf)
        add hl,de
        ld a,(Ti_Max)
        dec a
        sub e
        ld (Ti_Cnt),a
        ret

;-------- Курсор на экране: DE - начало поля (D - строка экрана, E - колонка), знак под ним -
; цветом курсора (атрибут)
Ti_Cursor
        ld a,(Ti_Pos)
        add a,e
        or SCR_ATTR
        ld l,a
        ld h,d
        ld a,(THEME_ATTR+CLR_CURSOR)
        ld (hl),a
        ret

; =========================================================================
; ЭКРАН ТУЛЗЫ: общее для тулз (диск, инструменты) - часть коре.
; Тулза рисует в текстовую страницу, поставленную в окно 3 (TL_SCR_H).
; Строки 0..TL_TOP-1 - копия шапки из её буфера (рисует вид паттерна).
; =========================================================================
TL_SCR_H        equ #C0             ; текстовая страница - в окне 3
TL_HEAD_H       equ TL_SCR_H+patview.HD_BUF_LINE    ; буфер шапки
TL_TOP          equ patview.VIEW_LINE               ; первая строка экрана тулзы
TL_LAST         equ 35                              ; последняя видимая строка

; --- рамки
BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘

;-------- Шапка: её буфер - в строки 0..TL_TOP-1, вкладка тулзы - выбранной.
; HL - атрибут вкладки на экране, B - её ширина
Tool_Head
        push hl
        push bc
        ld hl,TL_HEAD_H*256
        ld de,TL_SCR_H*256
        ld bc,TL_TOP*256
        ldir
        pop bc
        pop hl
        ld a,(THEME_ATTR+CLR_TOP_HI)
.attr   ld (hl),a
        inc l
        djnz .attr
        ret

;-------- Строки TL_TOP..TL_LAST: пробелы цветом фона
Tool_Clear
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld d,TL_SCR_H+TL_TOP
.r      ld e,0
.s      ld a,' '
        call PutCh
        bit 7,e
        jr z,.s
        inc d
        ld a,d
        cp TL_SCR_H+TL_LAST+1
        jr c,.r
        ret

;-------- Рамка: колонка Bx_X, ширина Bx_W, строки TL_TOP..TL_LAST-1. Внутри - пробелы
Bx_X            db 0
Bx_W            db 0
Tool_Box
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld d,TL_SCR_H+TL_TOP        ; верх ┌──┐
        ld a,BOX_TL
        ld b,BOX_TR
        call .line
        ld d,TL_SCR_H+TL_LAST-1     ; низ └──┘
        ld a,BOX_BL
        ld b,BOX_BR
        call .line
        ld d,TL_SCR_H+TL_TOP+1      ; бока, внутри - пробелы
.side   ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,(Bx_X)
        ld e,a
        ld a,BOX_V
        call PutCh
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,(Bx_W)
        sub 2
        ld b,a
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,BOX_V
        call PutCh
        inc d
        ld a,d
        cp TL_SCR_H+TL_LAST-1
        jr c,.side
        ret
; Линия рамки: A - левый угол, B - правый, D - строка
.line   push bc
        push af
        ld a,(Bx_X)
        ld e,a
        pop af
        call PutCh
        ld a,(Bx_W)
        sub 2
        ld b,a
.h      ld a,BOX_H
        call PutCh
        djnz .h
        pop bc
        ld a,b
        jp PutCh

;-------- Кнопки транспорта (общие для всех тулз), событие поля. Позиция - та, что
; играла последней (курсора паттерна здесь нет): ⇄ - её паттерн по кругу,
; |◀ - сонг с начала, ▶ - сонг с её начала, ▷ - паттерн с её роу, ■ - стоп
Tool_TrEv
        cp EV_CLICK
        ret nz
        ld a,(SV_PLAY_POS)          ; откуда
        ld (SV_PLAY_CPOS),a
        xor a
        ld (SV_PLAY_CROW),a
        ld a,(ix+FLD_PARAM)
        or a
        ld b,PC_PATTERN
        jr z,.cmd
        dec a
        jr nz,.play
        ld (SV_PLAY_CPOS),a         ; |◀ - позиция 0
        ld b,PC_SONG
        jr .cmd
.play   dec a
        ld b,PC_SONG
        jr z,.cmd
        dec a
        jr nz,.stop
        ld a,(SV_PLAY_ROW)          ; ▷ - с роу
        ld (SV_PLAY_CROW),a
        ld b,PC_PATTERN
        jr .cmd
.stop   ld b,PC_STOP
.cmd    ld a,b                      ; команда - последней (IM1 может влезть)
        ld (SV_PLAY_CMD),a
.wait   halt                        ; плеер взял команду - кнопки по состоянию
        ld a,(SV_PLAY_CMD)
        or a
        jr nz,.wait
        jp Tr_Active

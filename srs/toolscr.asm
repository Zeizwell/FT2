; =========================================================================
; ЭКРАН ТУЛЗЫ: общее для тулз (диск, инструменты) - часть коре.
; Тулза рисует в текстовую страницу, поставленную в окно 3 (TL_SCR_H).
; Строки 0..TL_TOP-1 - копия шапки из её буфера (рисует вид паттерна).
; =========================================================================
TL_SCR_H        equ #C0             ; текстовая страница - в окне 3
TL_HEAD_H       equ TL_SCR_H+patview.HD_BUF_LINE    ; буфер шапки
TL_TOP          equ patview.VIEW_LINE               ; первая строка экрана тулзы
TL_LAST         equ 35                              ; последняя видимая строка
TL_TABS_ATTR    equ (TL_SCR_H+patview.HD_TABS_Y)*256+128+patview.HD_TABS_X ; атрибуты вкладок
TL_TABS_W       equ patview.HD_TAB_SETUP+5-patview.HD_TABS_X    ; Instr .. Setup

; --- рамки: знаки и примитивы - srs/prim.asm

;-------- Шапка: её буфер - в строки 0..TL_TOP-1, вкладка тулзы - выбранной.
; HL - атрибут вкладки на экране, B - её ширина (0 - без подсветки)
Tool_Head
        push hl
        push bc
        ld hl,TL_HEAD_H*256
        ld de,TL_SCR_H*256
        ld bc,TL_TOP*256
        ldir
        ld a,(THEME_ATTR+CLR_BAR)       ; вкладки - обычным цветом (в буфере могла
        ld hl,TL_TABS_ATTR              ;   остаться подсветка от клика по ним)
        ld b,TL_TABS_W
.tabs   ld (hl),a
        inc l
        djnz .tabs
        pop bc
        pop hl
        inc b
        dec b
        ret z
        ld a,(THEME_ATTR+CLR_TOP_HI)
.attr   ld (hl),a
        inc l
        djnz .attr
        ret

;-------- Esc во вкладке (Disk, Instr / Orn / FX, Setup, Help) - общая клавиша: закрыть вкладку, назад в вид
; паттерна (основной цикл). Зовёт тулза, когда клавишу не взяло поле. B - клавиша -> CF = 1: Esc, SV_TOOL - вид паттерна
Tool_Esc
        ld a,b
        cp KEY_ESC
        jr z,.esc
        or a                        ; не Esc: CF = 0
        ret
.esc    ld a,PAGE_TOOL_PATVIEW
        ld (SV_TOOL),a
        scf
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

;-------- Рамка: колонка Bx_X, ширина Bx_W, строки TL_TOP..TL_LAST (до низа экрана). Внутри - пробелы
Bx_X            db 0
Bx_W            db 0
Tool_Box                            ; на примитивах (srs/prim.asm): внутри - фон, рамка - цветом заголовка
        ld a,(Bx_X)
        ld (Pr_X),a
        ld a,(Bx_W)
        ld (Pr_W),a
        ld a,TL_SCR_H+TL_TOP
        ld (Pr_Y),a
        ld a,TL_LAST-TL_TOP+1
        ld (Pr_H),a
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,' '
        call Pr_Fill
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        jp Pr_Box

;-------- Кнопки транспорта (общие для всех тулз), событие поля. Позиция - та, что
; играла последней (курсора паттерна здесь нет): ⇄ - её паттерн по кругу,
; |◀ - сонг с начала, ▶ - сонг с её начала, ▷ - паттерн с её роу. Играет с этой
; кнопки (горит ■) - клик - стоп (как в Bitphase)
Tool_TrEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        call Tr_Press               ; Z - играет с неё: стоп
        ld b,PC_STOP
        jr z,.cmd
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

; =========================================================================
; ОКНА (часть коре): прямоугольник поверх экрана - About, потом меню и вопросы.
; Модально: пока окно открыто, клавиатура и мышь - ему (Win_Wait).
; Вид паттерна собирает экран каждый кадр в IM1, поэтому окно снимается в буфер
; (Win_Img) и кладётся поверх в конце кадра (Win_Blit). Под окном - Win_Save,
; при закрытии возвращается (тулзам, которые экран каждый кадр не рисуют).
; Экран - SV_DRAW_PAGE в окне 3: строка = #C0 + y, символы 0..127, атрибуты +128.
; =========================================================================
WIN_W_MAX       equ 48
WIN_H_MAX       equ 16
WIN_SCR_H       equ #C0
WIN_END         equ #FF             ; конец строк окна
WB_TL           equ #DA             ; рамка: ┌ ┐ └ ┘ ─ │
WB_TR           equ #BF
WB_BL           equ #C0
WB_BR           equ #D9
WB_H            equ #C4
WB_V            equ #B3

Win_On          db 0                ; 1 - окно на экране (Win_Blit кладёт его каждый кадр)
Win_Busy        db 0                ; 1 - окно рисуют: вид паттерна кадр не собирает
Win_X           db 0
Win_Y           db 0
Win_W           db 0
Win_H           db 0
Win_Save        ds WIN_W_MAX*WIN_H_MAX*2    ; что было под окном: строки - символы, атрибуты
Win_Img         ds WIN_W_MAX*WIN_H_MAX*2    ; само окно

;-------- Открыть окно HL: x, y, w, h, строки (роль цвета CLR_*, текст, 0), конец - WIN_END
Win_Open
        ld a,1                      ; пока рисуем - вид паттерна кадр не собирает
        ld (Win_Busy),a
        ld de,Win_X                 ; x, y, w, h
        ld bc,4
        ldir
        ld (Wo_Text),hl
; Показать окно Win_X..Win_H, строки - Wo_Text
Win_Show
        ld a,1
        ld (Win_Busy),a
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        xor a                       ; что под окном - в Win_Save
        ld hl,Win_Save
        call Win_Rect
        call Win_Draw
        xor a                       ; окно - в Win_Img
        ld hl,Win_Img
        call Win_Rect
        RESTPAGE3
        ld a,1
        ld (Win_On),a
        xor a
        ld (Win_Busy),a
        ret
Wo_Text         dw 0

;-------- Закрыть: под окном - как было
Win_Close
        ld a,1
        ld (Win_Busy),a
        xor a
        ld (Win_On),a
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        ld a,1
        ld hl,Win_Save
        call Win_Rect
        RESTPAGE3
        xor a
        ld (Win_Busy),a
        ret

;-------- Конец кадра вида паттерна (IM1, экран - в окне 3): окно - поверх
Win_Blit
        ld a,(Win_On)
        or a
        ret z
        ld a,1
        ld hl,Win_Img
        jp Win_Rect

;-------- Ждать (About): клавиша или клик мимо окна - закрыть; клик в окне - ничего.
; Клики за время окна - его, полям под ним не достаются (Win_End)
Win_Wait
        ld a,MB_LEFT                ; старые события кнопки - мимо
        ld hl,Ww_Seen
        call Mouse_Btn
.l      halt
        call Key_Get                ; NZ - клавиша
        jr nz,Win_End
        ld a,MB_LEFT
        ld hl,Ww_Seen
        call Mouse_Btn
        and 1<<ME_PRESS
        jr z,.l
        call Win_In                 ; в окне - ничего
        jr c,.l
; Закрыть: кнопку отпустили, окно убрать, события мыши за время окна - не полям
Win_End
        ld a,MB_LEFT                ; ждать, пока отпустят (отпускание - тоже окну)
        ld hl,Ww_Seen
        call Mouse_Btn
        and #80
        jr z,.up
        halt
        jr Win_End
.up     call Win_Close
        jp Fld_Sync
Ww_Seen         ds 4

; Мышь в окне? CF - да
Win_In
        ld a,(Win_X)
        ld b,a
        ld a,(SV_MOUSE_COL)
        sub b
        jr c,.no                    ; левее - мимо
        ld hl,Win_W
        cp (hl)
        jr nc,.no
        ld a,(Win_Y)
        ld b,a
        ld a,(SV_MOUSE_ROW)
        sub b
        jr c,.no
        ld hl,Win_H
        cp (hl)
        ret                         ; CF - в окне
.no     or a
        ret

;-------- Прямоугольник окна (экран - в окне 3): A = 0 - экран -> буфер HL, 1 - буфер -> экран
Win_Rect
        ld (Wr_Dir),a
        ld (Wr_Buf),hl
        ld a,(Win_Y)
        add a,WIN_SCR_H
        ld (Wr_Row),a
        ld a,(Win_H)
        ld b,a
.r      push bc
        ld a,(Wr_Row)               ; символы строки, потом атрибуты
        ld d,a
        ld a,(Win_X)
        ld e,a
        call .pl
        ld a,(Win_X)
        add a,128
        ld e,a
        call .pl
        ld hl,Wr_Row
        inc (hl)
        pop bc
        djnz .r
        ret
.pl     ld hl,(Wr_Buf)              ; DE - экран, HL - буфер
        ld a,(Win_W)
        ld c,a
        ld b,0
        ld a,(Wr_Dir)
        or a
        jr nz,.to
        ex de,hl                    ; экран -> буфер
        ldir
        ex de,hl
        jr .n
.to     ldir                        ; буфер -> экран
.n      ld (Wr_Buf),hl
        ret
Wr_Dir          db 0
Wr_Buf          dw 0
Wr_Row          db 0

;-------- Рамка, фон и строки окна (экран - в окне 3)
Win_Draw
        ld a,(THEME_ATTR+CLR_HEAD_LINE)
        ld c,a
        ld a,(Win_Y)
        add a,WIN_SCR_H
        ld d,a
        ld a,WB_TL                  ; верх
        ld b,WB_TR
        call .line
        ld a,(Win_H)                ; бока, внутри - пробелы фоном окна
        sub 2
        ld b,a
.m      push bc
        inc d
        ld a,(Win_X)
        ld e,a
        ld a,(THEME_ATTR+CLR_HEAD_LINE)
        ld c,a
        ld a,WB_V
        call PutCh
        ld a,(THEME_ATTR+CLR_TOP_BG)
        ld c,a
        ld a,(Win_W)
        sub 2
        ld b,a
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld a,(THEME_ATTR+CLR_HEAD_LINE)
        ld c,a
        ld a,WB_V
        call PutCh
        pop bc
        djnz .m
        inc d                       ; низ
        ld a,WB_BL
        ld b,WB_BR
        call .line
        ld a,(Win_Y)                ; строки: с x+2, своим цветом
        add a,WIN_SCR_H+1
        ld d,a
        ld hl,(Wo_Text)
.t      ld a,(hl)
        cp WIN_END
        ret z
        inc hl
        push hl
        ld hl,THEME_ATTR
        add a,l
        ld l,a
        ld c,(hl)
        pop hl
        ld a,(Win_X)
        add a,2
        ld e,a
        call PutStr
        inc hl
        inc d
        jr .t
; строка рамки D: A - левый угол, B - правый, между - ─
.line   push bc
        push af
        ld a,(Win_X)
        ld e,a
        pop af
        call PutCh
        ld a,(Win_W)
        sub 2
        ld b,a
.h      ld a,WB_H
        call PutCh
        djnz .h
        pop bc
        ld a,b
        jp PutCh
    ASSERT (THEME_ATTR & 255) == 0 || (THEME_ATTR & 255) + 128 <= 256

;-------- Меню у мыши: HL - ширина, пунктов, строки пунктов (роль, текст, 0). Пункт под
; мышью - подсвечен, Up / Down - тоже; клик или Enter - выбрать, Esc, правая, клик мимо -
; закрыть. Выход: A - пункт 0.., #FF - ничего
Wm_N            db 0                ; пунктов
Wm_Sel          db #FF              ; подсвеченный (#FF - нет)
Wm_SeenR        ds 4
Win_Menu
        ld a,(hl)                   ; ширина, пунктов, строки
        ld (Win_W),a
        inc hl
        ld a,(hl)
        ld (Wm_N),a
        add a,2
        ld (Win_H),a
        inc hl
        ld (Wo_Text),hl
        ld a,(Win_W)                ; x - у мыши, не за правый край
        ld b,a
        ld a,90
        sub b
        ld b,a
        ld a,(SV_MOUSE_COL)
        cp b
        jr c,$+3
        ld a,b
        ld (Win_X),a
        ld a,(Win_H)                ; y - так же, не за низ
        ld b,a
        ld a,36
        sub b
        ld b,a
        ld a,(SV_MOUSE_ROW)
        cp b
        jr c,$+3
        ld a,b
        ld (Win_Y),a
        ld a,#FF
        ld (Wm_Sel),a
        call Win_Show
        ld a,MB_LEFT                ; старые события кнопок - мимо
        ld hl,Ww_Seen
        call Mouse_Btn
        ld a,MB_RIGHT
        ld hl,Wm_SeenR
        call Mouse_Btn
.l      halt
        call Wm_At                  ; мышь над пунктом - подсветить
        cp #FF
        jr z,.k
        ld hl,Wm_Sel
        cp (hl)
        jr z,.k
        ld (hl),a
        call Wm_Redraw
.k      call Key_Get                ; клавиши: Esc, Enter, Up, Down
        jr z,.m
        cp KEY_ESC
        jr z,.none
        cp KEY_ENTER
        jr z,.pick
        cp KEY_UP
        jr z,.up
        cp KEY_DOWN
        jr nz,.l
        ld a,(Wm_Sel)               ; вниз (с #FF - на первый)
        inc a
        ld hl,Wm_N
        cp (hl)
        jr nc,.l
        jr .set
.up     ld a,(Wm_Sel)
        or a
        jr z,.l
        cp #FF
        jr z,.l
        dec a
.set    ld (Wm_Sel),a
        call Wm_Redraw
        jr .l
.m      ld a,MB_LEFT                ; левая: над пунктом - выбрать, мимо - закрыть
        ld hl,Ww_Seen
        call Mouse_Btn
        and 1<<ME_PRESS
        jr z,.r
        call Wm_At
        cp #FF
        jr z,.none
        ld (Wm_Sel),a
        jr .pick
.r      ld a,MB_RIGHT               ; правая - закрыть
        ld hl,Wm_SeenR
        call Mouse_Btn
        and 1<<ME_PRESS
        jr z,.l
.none   ld a,#FF
        ld (Wm_Sel),a
.pick   call Win_End                ; клики за время меню - не полям
        ld a,(Wm_Sel)
        ret

; A - пункт под мышью (#FF - не над пунктом)
Wm_At
        ld a,(Win_X)                ; колонка: внутри рамки
        ld b,a
        ld a,(SV_MOUSE_COL)
        sub b
        jr z,.no
        jr c,.no
        inc a
        ld hl,Win_W
        cp (hl)
        jr nc,.no
        ld a,(Win_Y)                ; строка: пункт
        ld b,a
        ld a,(SV_MOUSE_ROW)
        sub b
        jr z,.no
        jr c,.no
        dec a
        ld hl,Wm_N
        cp (hl)
        ret c
.no     ld a,#FF
        ret

; Окно заново, пункт Wm_Sel - цветом выделения, снимок - в Win_Img
Wm_Redraw
        ld a,1
        ld (Win_Busy),a
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        call Win_Draw
        ld a,(Wm_Sel)
        cp #FF
        jr z,.s
        ld hl,Win_Y                 ; строка пункта
        add a,(hl)
        add a,WIN_SCR_H+1
        ld h,a
        ld a,(Win_X)                ; атрибуты внутри рамки
        add a,128+1
        ld l,a
        ld a,(Win_W)
        sub 2
        ld b,a
        ld a,(THEME_ATTR+CLR_SELECT)
.c      ld (hl),a
        inc l
        djnz .c
.s      xor a
        ld hl,Win_Img
        call Win_Rect
        RESTPAGE3
        xor a
        ld (Win_Busy),a
        ret

;-------- About
Win_About
        ld hl,Wa_Raw+8              ; дата: "ДД.ММ.ГГГГ"
        ld de,Wa_Date
        ld bc,2
        ldir
        inc de
        ld hl,Wa_Raw+5
        ld bc,2
        ldir
        inc de
        ld hl,Wa_Raw
        ld bc,4
        ldir
        ld hl,Win_About_D
        call Win_Open
        jp Win_Wait
; поле шапки "About" в любой тулзе: клик - окно
Win_AboutEv
        cp EV_CLICK
        ret nz
        jp Win_About

Win_About_D
        db 28, 13, 34, 9
        db CLR_TOP_HI,  "     FAST TRACKER 2.01b",0
        db CLR_TOP_TEXT,"         by Orion/DR",0
        db CLR_TOP_TEXT," ",0
        db CLR_TOP_TEXT,"FAT32 driver   Andrew Lazarev",0
        db CLR_TOP_TEXT,"PT3 reference  S.V. Bulba",0
        db CLR_TOP_TEXT,"github.com/Zeizwell/FT2",0
        db CLR_TOP_TEXT,"build "
Wa_Date db "DD.MM.YYYY",0
        db WIN_END
Wa_Raw  db __DATE__                ; дата сборки от ассемблера: "YYYY-MM-DD"

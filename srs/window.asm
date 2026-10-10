; =========================================================================
; ОКНА (часть коре): прямоугольник поверх экрана - About, меню, потом вопросы.
; Модально: пока окно открыто, клавиатура и мышь - ему (Win_Wait, Win_Menu).
; Вид паттерна собирает экран каждый кадр в IM1, поэтому окно снимается в страницу
; PAGE_WINIMG и кладётся поверх в конце кадра DMA (Win_Blit). Что было под окном -
; в PAGE_WINSAVE, при закрытии возвращается. Обе страницы - в раскладке экрана
; (строка 256 байт: символы, атрибуты +128), поэтому пересылка - DMA прямоугольником
; (символы и атрибуты), колонка и ширина окна - чётные (DMA ходит словами).
; Экран - SV_DRAW_PAGE; рисуем процессором в окне 3: строка = #C0 + y.
; =========================================================================
WIN_W_MAX       equ 48
WIN_H_MAX       equ 24
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

;-------- Открыть окно HL: x, y, w, h, строки (роль цвета CLR_*, текст, 0), конец - WIN_END
Win_Open
        ld a,1                      ; пока рисуем - вид паттерна кадр не собирает
        ld (Win_Busy),a
        ld de,Wd_Text               ; строки - текст (HL - описание, не трогаем)
        ld (Wd_Fn),de
        ld de,Win_X                 ; x, y, w, h
        ld bc,4
        ldir
        ld (Wo_Text),hl
; Показать окно Win_X..Win_H, строки - Wo_Text
Win_Show
        ld a,1
        ld (Win_Busy),a
        ld a,(Win_X)                ; DMA: колонка и ширина - чётные
        and #FE
        ld (Win_X),a
        ld a,(Win_W)
        inc a
        and #FE
        ld (Win_W),a
        ld a,(SV_DRAW_PAGE)         ; что под окном - в PAGE_WINSAVE
        ld (Wd_Src),a
        ld a,PAGE_WINSAVE
        ld (Wd_Dst),a
        call Win_DmaM
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        call Win_Draw
        RESTPAGE3
        call Win_Snap               ; окно - в PAGE_WINIMG
        ld a,1
        ld (Win_On),a
        xor a
        ld (Win_Busy),a
        ret
Wo_Text         dw 0

;-------- Окно с экрана - в PAGE_WINIMG (после рисования)
Win_Snap
        ld a,(SV_DRAW_PAGE)
        ld (Wd_Src),a
        ld a,PAGE_WINIMG
        ld (Wd_Dst),a
        jp Win_DmaM

;-------- Закрыть: под окном - как было
Win_Close
        ld a,1
        ld (Win_Busy),a
        xor a
        ld (Win_On),a
        ld a,PAGE_WINSAVE
        ld (Wd_Src),a
        ld a,(SV_DRAW_PAGE)
        ld (Wd_Dst),a
        call Win_DmaM
        xor a
        ld (Win_Busy),a
        ret

;-------- Конец кадра вида паттерна (IM1): окно - поверх, DMA из PAGE_WINIMG
Win_Blit
        ld a,(Win_On)
        or a
        ret z
        ld a,PAGE_WINIMG
        ld (Wd_Src),a
        ld a,(SV_DRAW_PAGE)
        ld (Wd_Dst),a
        xor a                       ; из прерывания: без DI
        jr Win_Dma

;-------- Прямоугольник окна: страница Wd_Src -> Wd_Dst, те же строки и колонки, символы и
; атрибуты - две DMA. Win_DmaM - из основной программы: порты - при DI, ждём конца
Wd_Src          db 0
Wd_Dst          db 0
Wd_Main         db 0                ; 1 - из основной программы
Win_DmaM
        ld a,1
        call Win_Dma
        jp dma_wait                 ; данные нужны сразу (рисуем поверх / снимаем)
Win_Dma
        ld (Wd_Main),a
        ld a,(Win_X)
        call .one
        ld a,(Win_X)
        add a,128
.one    ld l,a
        call dma_wait               ; ждём при EI (долго - только тут)
        ld a,(Wd_Main)
        or a
        jr z,.go
        di
        call dma_wait               ; IM1 мог успеть запустить свою
.go     ld c,#AF
        ld a,(Wd_Src)
        ld b,high DMASADDRX
        out (c),a
        ld a,(Wd_Dst)
        ld b,high DMADADDRX
        out (c),a
        ld a,l                      ; колонка
        ld b,high DMASADDRL
        out (c),a
        ld b,high DMADADDRL
        out (c),a
        ld a,(Win_Y)                ; строка
        ld b,high DMASADDRH
        out (c),a
        ld b,high DMADADDRH
        out (c),a
        ld a,(Win_W)                ; слов в строке - 1
        srl a
        dec a
        ld b,high DMALEN
        out (c),a
        ld a,(Win_H)                ; строк - 1
        dec a
        ld b,high DMANUM
        out (c),a
        ld a,DMA_RAM|DMA_SALGN|DMA_DALGN
        ld b,high DMACTR
        out (c),a                   ; пуск
        ld a,(Wd_Main)
        or a
        ret z
        ei
        ret

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

Wd_N            db 0                ; строк окна ещё можно
Wd_Fn           dw Wd_Text          ; как рисовать строки: Wd_Text / Wd_Menu

;-------- Рамка, фон и строки окна (экран - в окне 3)
Win_Draw                            ; рамка - цветом фона окна (не мелькает поверх паттерна)
        ld a,(THEME_ATTR+CLR_TOP_BG)
        ld c,a
        ld a,(Win_Y)
        add a,WIN_SCR_H
        ld d,a
        ld a,WB_TL                  ; верх
        ld b,WB_TR
        call Wd_Line
        ld a,(Win_H)                ; бока, внутри - пробелы фоном окна
        sub 2
        ld b,a
.m      push bc
        inc d
        ld a,(Win_X)
        ld e,a
        ld a,(THEME_ATTR+CLR_TOP_BG)
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
        ld a,(THEME_ATTR+CLR_TOP_BG)
        ld c,a
        ld a,WB_V
        call PutCh
        pop bc
        djnz .m
        inc d                       ; низ
        ld a,WB_BL
        ld b,WB_BR
        call Wd_Line
        ld hl,(Wd_Fn)               ; строки: текст (About) или пункты меню
        jp (hl)

; Строки текста: роль цвета, текст, 0. С x+2, не больше, чем влезает
Wd_Text
        ld a,(Win_H)
        sub 2
        ld (Wd_N),a
        ld a,(Win_Y)
        add a,WIN_SCR_H+1
        ld d,a
        ld hl,(Wo_Text)
.t      ld a,(Wd_N)
        or a
        ret z
        dec a
        ld (Wd_N),a
        ld a,(hl)
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
Wd_Line push bc
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

;-------- Меню у мыши: HL - ширина, пунктов, пункты (действие ACT_*, текст, 0; WM_SEP). Пункт под
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
        ld hl,Wd_Menu               ; строки - пункты меню
        ld (Wd_Fn),hl
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

;-------- Пункты меню: действие ACT_*, текст, 0 (WM_SEP - разделитель). Справа - первая
; клавиша действия из биндов (как в Help): переназначили - меню показывает новую
WM_SEP          equ #FE
WM_KEYW         equ 12              ; колонка клавиш (Ctrl+Shift+Z) - от правого края
Wd_Menu
        ld a,(Win_H)
        sub 2
        ld (Wd_N),a
        ld a,(Win_Y)
        add a,WIN_SCR_H+1
        ld d,a
        ld hl,(Wo_Text)
.t      ld a,(Wd_N)
        or a
        ret z
        dec a
        ld (Wd_N),a
        ld a,(hl)
        cp WIN_END
        ret z
        inc hl
        cp WM_SEP
        jr nz,.it
        push hl                     ; разделитель: ├───┤
        ld a,(THEME_ATTR+CLR_TOP_BG)
        ld c,a
        ld a,(Win_X)
        ld e,a
        ld a,#C3
        call PutCh
        ld a,(Win_W)
        sub 2
        ld b,a
.h      ld a,WB_H
        call PutCh
        djnz .h
        ld a,#B4
        call PutCh
        pop hl
        inc d
        jr .t
.it     ld (Wm_Act),a
        ld a,(THEME_ATTR+CLR_TOP_TEXT)  ; текст
        ld c,a
        ld a,(Win_X)
        add a,2
        ld e,a
        call PutStr
        inc hl
        push hl
        ld a,(THEME_ATTR+CLR_TOP_VALUE) ; клавиша
        ld c,a
        ld a,(Win_X)
        ld b,a
        ld a,(Win_W)
        add a,b
        sub WM_KEYW+1
        ld e,a
        ld a,(Wm_Act)
        call Key_Of
        pop hl
        inc d
        jr .t
Wm_Act          db 0

;-------- Пункт A меню HL (ширина, пунктов, пункты) -> A - его действие (0 - разделитель)
Wm_Item_Act
        inc hl
        inc hl
        ld b,a
        inc b
.f      dec b
        jr z,.got
        ld a,(hl)                   ; мимо пункта
        inc hl
        cp WM_SEP
        jr z,.f
.s      ld a,(hl)
        inc hl
        or a
        jr nz,.s
        jr .f
.got    ld a,(hl)
        cp WM_SEP
        ret nz
        xor a
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

; Окно заново, пункт Wm_Sel - цветом выделения, снимок - в PAGE_WINIMG
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
.s      RESTPAGE3
        call Win_Snap
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

;-------- Имена клавиш по биндам (Help, меню): из Bind_Tab, вывод - PutCh / PutStr с DE, цвет C
; A - действие: все его клавиши через ", " (с DE). Портит всё, кроме C, D
Keys_Of
        ld (Ko_Act),a
        xor a
        ld (Ko_N),a
        ld hl,Bind_Tab
.f      ld a,(hl)                   ; код, 0 - конец
        or a
        ret z
        ld (Ko_Ptr),hl
        inc hl
        inc hl
        inc hl
        ld a,(Ko_Act)
        cp (hl)
        ld hl,(Ko_Ptr)
        jr nz,.n
        ld a,(Ko_N)                 ; не первая - через запятую
        or a
        jr z,.p
        ld a,','
        call PutCh
        ld a,' '
        call PutCh
.p      ld hl,Ko_N
        inc (hl)
        ld hl,(Ko_Ptr)
        call .one
        ld hl,(Ko_Ptr)
.n      inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.one    push hl                     ; HL - запись бинда: модификаторы, клавиша
        inc hl
        ld a,(hl)
        call Mods_Put
        pop hl
        push hl
        ld a,(hl)
        call Key_Put
        pop hl
        ret
Ko_Act          db 0
Ko_N            db 0
Ko_Ptr          dw 0

; A - действие: его первая клавиша (с модификаторами). Нет бинда - "-"
Key_Of
        ld b,a
        ld hl,Bind_Tab
.f      ld a,(hl)
        or a
        jr z,.none
        push hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        pop hl
        cp b
        jp z,Keys_Of.one
        inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.none   ld a,'-'
        jp PutCh

; A - модификаторы KM_* -> "Ctrl+", "Shift+", "Alt+"
Mods_Put
        ld b,a
        bit 1,b                     ; KM_CTRL
        ld hl,Txt_Ctrl
        call nz,PutStr
        bit 0,b                     ; KM_SHIFT
        ld hl,Txt_Shift
        call nz,PutStr
        bit 2,b                     ; KM_ALT
        ld hl,Txt_Alt
        call nz,PutStr
        ret
    ASSERT KM_SHIFT == 1 && KM_CTRL == 2 && KM_ALT == 4
Txt_Ctrl        db "Ctrl+",0
Txt_Shift       db "Shift+",0
Txt_Alt         db "Alt+",0

; A - код клавиши -> её имя: особые - по таблице, буквы и цифры - из Key_Chars (заглавные)
Key_Put
        ld b,a
        ld hl,Key_Names
.f      ld a,(hl)                   ; код, имя, 0; конец - 0
        or a
        jr z,.ch
        inc hl
        cp b
        jp z,PutStr
.s      ld a,(hl)                   ; мимо имени
        inc hl
        or a
        jr nz,.s
        jr .f
.ch     ld a,b                      ; E0-коды без имени - "?"
        or a
        jp m,.q
        ld h,high Key_Chars
        ld l,a
        ld a,(hl)
        or a
        jr z,.q
        cp 'a'
        jr c,.put
        cp 'z'+1
        jr nc,.put
        sub 'a'-'A'
.put    jp PutCh
.q      ld a,'?'
        jp PutCh

Key_Names
        db KEY_UP,"Up",0,       KEY_DOWN,"Down",0,   KEY_LEFT,"Left",0
        db KEY_RIGHT,"Right",0, KEY_PGUP,"PgUp",0,   KEY_PGDN,"PgDn",0
        db KEY_HOME,"Home",0,   KEY_END,"End",0,     KEY_TAB,"Tab",0
        db KEY_ENTER,"Enter",0, KEY_BACK,"Bksp",0,   KEY_ESC,"Esc",0
        db KEY_SPACE,"Space",0, KEY_DEL,"Del",0,     KEY_INS,"Ins",0
        db KEY_F5,"F5",0,       KEY_F6,"F6",0,       KEY_F7,"F7",0
        db KEY_F8,"F8",0,       KEY_KP_PLUS,"Num+",0, KEY_KP_MINUS,"Num-",0
        db #69,"Num1",0, #72,"Num2",0, #7A,"Num3",0, #6B,"Num4",0
        db #73,"Num5",0, #74,"Num6",0, #6C,"Num7",0, #75,"Num8",0
        db 0

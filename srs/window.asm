; =========================================================================
; ОКНА (часть коре): прямоугольник поверх экрана - About, меню, потом вопросы.
; Модально: пока окно открыто, клавиатура и мышь - ему (Win_Wait, Win_Menu).
; Вид паттерна собирает экран каждый кадр в IM1, поэтому окно снимается в страницу
; PAGE_WINIMG и кладётся поверх в конце кадра DMA (Win_Blit). Что было под окном -
; в PAGE_WINSAVE, при закрытии возвращается. Обе страницы - в раскладке экрана
; (строка 256 байт: символы, атрибуты +128), поэтому пересылка - DMA прямоугольником
; (символы и атрибуты), колонка и ширина окна - чётные (DMA ходит словами).
; Экран - Win_Pg (вид паттерна - SV_DRAW_PAGE, тулза с двойным буфером - видимая страница);
; рисуем процессором в окне 3: строка = #C0 + y.
; Стандартное окно - с описателя (Win_Open): x, y, ширина, высота (с рамкой; x / y = WIN_CENTER -
; по центру экрана), флаги (WF_CONTEXT - контекстное: клик мимо закрывает; без него - обычное: клик
; мимо ничего, закрывают Esc и свои кнопки), заголовок (текст, 0; пусто - без заголовка), строки (роль цвета, текст, 0), конец -
; WIN_END. Рамка с заголовком сверху, тень справа (2 колонки) и снизу (1 строка) - как в Turbo Vision.
; Под окном вместе с тенью - в PAGE_WINSAVE, закрытие возвращает всё как было.
; Модально: пока окно открыто, всё остальное ждёт.
; =========================================================================
WIN_W_MAX       equ 48
WIN_H_MAX       equ 24
WIN_SCR_H       equ #C0
WIN_END         equ #FF             ; конец строк окна
WIN_CENTER      equ #FF             ; x / y в описателе: по центру экрана
WF_CONTEXT      equ %00000001       ; флаг окна: контекстное - клик мимо закрывает
WF_INVERT       equ %00000100       ;   заголовок - сплошной тёмной полосой (CLR_WIN_INV), не шахматкой
WIN_SCR_W       equ 90              ; видимый экран
WIN_SCR_ROWS    equ 36

Win_On          db 0                ; 1 - окно на экране (Win_Blit кладёт его каждый кадр)
Win_Busy        db 0                ; 1 - окно рисуют: вид паттерна кадр не собирает
Win_X           db 0
Win_Y           db 0
Win_W           db 0
Win_H           db 0
Win_Flags       db 0                ; WF_*

;-------- Открыть стандартное окно с описателя HL (см. начало файла)
Win_Open
        ld a,1                      ; пока рисуем - вид паттерна кадр не собирает
        ld (Win_Busy),a
        ld de,Wd_Text               ; строки - текст (HL - описание, не трогаем)
        ld (Wd_Fn),de
        ld de,Win_X                 ; x, y, w, h
        ld bc,4
        ldir
        ld a,(hl)                   ; флаги
        ld (Win_Flags),a
        inc hl
        ld (Wo_Title),hl            ; заголовок - до 0, за ним строки
        xor a
        ld b,a
        ld c,a
        cpir
        ld (Wo_Text),hl
        ld a,(Win_X)                ; по центру
        cp WIN_CENTER
        jr nz,.y
        ld a,(Win_W)
        ld b,a
        ld a,WIN_SCR_W
        sub b
        srl a
        ld (Win_X),a
.y      ld a,(Win_Y)
        cp WIN_CENTER
        jr nz,Win_Show
        ld a,(Win_H)
        ld b,a
        ld a,WIN_SCR_ROWS
        sub b
        srl a
        ld (Win_Y),a
; Показать окно Win_X..Win_H, строки - Wo_Text
Win_Show
        ld a,1
        ld (Win_Busy),a
        ld a,(THEME_ATTR+CLR_WIN_TEXT) ; цвета окна - одни на все окна (свой голубой фон)
        ld (Wd_AF),a
        ld a,(THEME_ATTR+CLR_WIN_TEXT)
        ld (Wd_AB),a
        ld a,(Win_X)                ; DMA: колонка и ширина - чётные
        and #FE
        ld (Win_X),a
        ld a,(Win_W)
        inc a
        and #FE
        ld (Win_W),a
        call Win_Pg                 ; что под окном (и тенью) - в PAGE_WINSAVE
        ld (Wd_Src),a
        ld a,PAGE_WINSAVE
        ld (Wd_Dst),a
        call Win_DmaM
        call Win_Pg
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
Wo_Title        dw Wo_None          ; заголовок окна (пусто - без него)
Wo_None         db 0
Wd_AF           db 0                ; цвет рамки и заголовка (по флагам)
Wd_AB           db 0                ;   фона окна

;-------- A - страница экрана для окна: тулза с двойным буфером - видимая, иначе - SV_DRAW_PAGE
Win_Pg  ld a,(Scr_On)
        or a
        ld a,(SV_DRAW_PAGE)
        ret z
        ld a,(Scr_Show_Pg)
        ret

;-------- Окно с экрана - в PAGE_WINIMG (после рисования)
Win_Snap
        call Win_Pg
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
        call Win_Pg
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
        ld a,(Win_W)                ; слов в строке - 1: окно + 2 колонки тени
        srl a
        ld b,high DMALEN
        out (c),a
        ld a,(Win_H)                ; строк - 1: окно + строка тени
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

;-------- Группа в окне (стандарт): рамка ┌─ Заголовок ──┐ ... └──┘ цветом окна, внутри не трогает.
; HL - описание: x, y, ширина, высота (с рамкой), заголовок (текст, 0). Экран - в окне 3 (строка = #C0 + y)
Gb_Draw
        call Pr_Rect                ; на примитивах (srs/prim.asm): рамка цветом окна
        ld a,(Pr_Y)                 ; y - от верха экрана
        add a,WIN_SCR_H
        ld (Pr_Y),a
        push hl                     ; заголовок
        ld a,(THEME_ATTR+CLR_WIN_TEXT)
        ld c,a
        call Pr_Box
        ld a,(Pr_Y)                 ; " Заголовок " - с x+2 на верхней линии
        ld d,a
        ld a,(Pr_X)
        add a,2
        ld e,a
        ld a,' '
        call PutCh
        pop hl
        call PutStr
        ld a,' '
        jp PutCh

;-------- Ждать (About): клавиша - закрыть; клик мимо - закрыть, если окно контекстное (WF_CONTEXT); в окне - ничего.
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
        call Win_OnClose            ; крестик - закрыть
        jr c,Win_End
        call Win_In                 ; в окне - ничего
        jr c,.l
        ld a,(Win_Flags)            ; мимо: обычное окно - ничего
        and WF_CONTEXT
        jr z,.l
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
Win_Draw                            ; на примитивах (srs/prim.asm): фон, рамка цветом окна, заголовок, тень
        ld a,(Win_X)
        ld (Pr_X),a
        ld a,(Win_Y)
        add a,WIN_SCR_H
        ld (Pr_Y),a
        ld a,(Win_W)
        ld (Pr_W),a
        ld a,(Win_H)
        ld (Pr_H),a
        ld a,(Wd_AB)
        ld c,a
        ld a,' '
        call Pr_Fill
        ld a,(Wd_AF)
        ld c,a
        call Pr_Box
        call Wd_Title
        call Wd_Shadow
        ld hl,(Wd_Fn)               ; строки: текст (About) или пункты меню
        jp (hl)

; Заголовок (пусто - нет): верхняя строка между углами - шахматка, по центру " текст ", справа - крестик
; закрытия [x] (WIN_CLOSE_DX от правого края). Всё - цветом рамки
WB_CHECK        equ #B1             ; ▒ - шахматка заголовка
WIN_CLOSE_DX    equ 4               ; [x] - с колонки x+w-4 (до угла)
Wd_Title
        ld hl,(Wo_Title)
        ld a,(hl)
        or a
        ret z
        ld a,(Win_Flags)            ; строка заголовка - от края до края (без углов): WF_INVERT - сплошная
        and WF_INVERT               ;   тёмная полоса, иначе - шахматка цветом рамки
        ld a,(Wd_AF)
        ld b,WB_CHECK
        jr z,.cl
        ld a,(THEME_ATTR+CLR_WIN_INV)
        ld b,' '
.cl     ld c,a
        ld a,b
        ld (.ch+1),a
        ld a,(Win_Y)
        add a,WIN_SCR_H
        ld d,a
        ld a,(Win_X)
        ld e,a
        ld a,(Win_W)
        ld b,a
.ch     ld a,WB_CHECK               ; (знак полосы - сюда)
        call PutCh
        djnz .ch
        ld hl,(Wo_Title)            ; длина заголовка
        ld b,0
.n      ld a,(hl)
        or a
        jr z,.c
        inc hl
        inc b
        jr .n
.c      ld a,(Win_W)                ; " текст " по центру: x + (w - (длина + 2)) / 2
        sub b
        sub 2
        srl a
        ld hl,Win_X
        add a,(hl)
        ld e,a
        ld a,' '
        call PutCh
        ld hl,(Wo_Title)
        call PutStr
        ld a,' '
        call PutCh
        ld a,(Win_X)                ; крестик [x]
        ld hl,Win_W
        add a,(hl)
        sub WIN_CLOSE_DX
        ld e,a
        ld hl,Txt_WClose
        jp PutStr
Txt_WClose      db "[x]",0

; Мышь на крестике окна с заголовком? CF - да
Win_OnClose
        ld hl,(Wo_Title)
        ld a,(hl)
        or a
        ret z                       ; без заголовка - крестика нет (CF = 0)
        ld a,(Win_Y)
        ld b,a
        ld a,(SV_MOUSE_ROW)
        cp b
        jr nz,.no
        ld a,(Win_X)
        ld hl,Win_W
        add a,(hl)
        sub WIN_CLOSE_DX
        ld b,a
        ld a,(SV_MOUSE_COL)
        sub b
        jr c,.no
        cp 3
        ret                         ; CF - на [x]
.no     or a
        ret

; Тень: атрибуты справа (2 колонки, строки y+1..y+h) и снизу (строка y+h, колонки x+2..x+w+1) -
; цвет тени, знаки под ней остаются
Wd_Shadow
        ld a,(THEME_ATTR+CLR_WIN_SHADOW)
        ld c,a
        ld a,(Win_X)                ; справа: колонки x+w, x+w+1, строки y+1..y+h
        ld hl,Win_W
        add a,(hl)
        ld (Pr_X),a
        ld a,(Win_Y)
        add a,WIN_SCR_H+1
        ld (Pr_Y),a
        ld a,2
        ld (Pr_W),a
        ld a,(Win_H)
        ld (Pr_H),a
        call Pr_Attr
        ld a,(Win_X)                ; снизу: строка y+h, колонки x+2..x+w-1
        add a,2
        ld (Pr_X),a
        ld a,(Win_Y)
        ld hl,Win_H
        add a,(hl)
        add a,WIN_SCR_H
        ld (Pr_Y),a
        ld a,(Win_W)
        sub 2
        ld (Pr_W),a
        ld a,1
        ld (Pr_H),a
        jp Pr_Attr

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
    ASSERT (THEME_ATTR & 255) == 0 || (THEME_ATTR & 255) + 128 <= 256

;-------- Меню у мыши: HL - ширина, пунктов, флаги (WF_*), пункты (действие ACT_*, текст, 0; WM_SEP). Пункт под
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
        ld a,(hl)                   ; флаги
        ld (Win_Flags),a
        inc hl
        ld (Wo_Text),hl
        ld hl,Wo_None               ; меню - без заголовка
        ld (Wo_Title),hl
        ld a,(Win_W)                ; x - у мыши, не за правый край (и тень)
        add a,2
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
.m      ld a,MB_LEFT                ; левая: над пунктом - выбрать; мимо окна - закрыть, если
        ld hl,Ww_Seen               ;   контекстное (WF_CONTEXT); в окне не на пункте - ничего
        call Mouse_Btn
        and 1<<ME_PRESS
        jr z,.r
        call Wm_At
        cp #FF
        jr nz,.it
        call Win_In
        jp c,.l
        ld a,(Win_Flags)
        and WF_CONTEXT
        jp z,.l
        jr .none
.it
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
        ld a,(THEME_ATTR+CLR_WIN_TEXT)
        ld c,a
        ld a,(Win_X)
        ld e,a
        ld a,#C3
        call PutCh
        ld a,(Win_W)
        sub 2
        ld b,a
.h      ld a,BOX_H
        call PutCh
        djnz .h
        ld a,#B4
        call PutCh
        pop hl
        inc d
        jr .t
.it     ld (Wm_Act),a
        ld a,(THEME_ATTR+CLR_WIN_TEXT)  ; текст
        ld c,a
        ld a,(Win_X)
        add a,2
        ld e,a
        call PutStr
        inc hl
        push hl
        ld a,(THEME_ATTR+CLR_WIN_VALUE) ; клавиша
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
        inc hl                      ; ширина, пунктов, флаги
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
        call Win_Pg
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
        db WIN_CENTER, WIN_CENTER, 34, 9, WF_CONTEXT|WF_INVERT
        db "About",0
        db CLR_WIN_TEXT,"FAST TRACKER 2.01b",0
        db CLR_WIN_TEXT,"by Orion/DR",0
        db CLR_WIN_TEXT," ",0
        db CLR_WIN_TEXT,"FAT32 driver   Andrew Lazarev",0
        db CLR_WIN_TEXT,"PT3 reference  S.V. Bulba",0
        db CLR_WIN_TEXT,"github.com/Zeizwell/FT2",0
        db CLR_WIN_TEXT,"build "
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

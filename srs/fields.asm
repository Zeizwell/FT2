; =========================================================================
; ПОЛЯ: наведение, фокус, события мыши и клавиатуры полям. Часть коре.
; =========================================================================
; Поле - прямоугольник экрана в знакоместах + обработчик (формат FLD_* и события
; EV_* - sdk/plugin.asm, схема - doc/architecture.md п.2-3). Редактор ставит свой
; список полей (Fld_Init) и каждый кадр из основного цикла зовёт Fld_Update;
; клавиши - через Fld_Key (сначала полю в фокусе, не съело - своей таблице).
; Поиск: первое совпадение в списке, есть дети - ищем в них, событие - самому
; глубокому. Всё в основном цикле, IM1 не участвует.
; =========================================================================

Fld_Seen_L      ds 4                ; события левой кнопки мыши, которые уже видели
Fld_Seen_R      ds 4                ; правой
Fu_Flags        db 0                ; события левой кнопки в этом кадре (Mouse_Btn)

;-------- Редактор ставит свой список полей. HL - список (0 - нет).
; Наведение, фокус и нажатие сбрасываются; события мыши, что были до этого, - не нам
Fld_Init
        ld (SV_FIELDS),hl
        ld hl,0
        ld (SV_HOVER),hl
        ld (SV_FOCUS),hl
        ld (SV_PRESSED),hl
;-------- События мыши, что уже были, - полям не отдавать (после окна: клики в нём - его)
Fld_Sync
        ld hl,0
        ld (SV_PRESSED),hl
        ld hl,SV_MS_COUNT+MB_LEFT*4 ; уже бывшие события - "видели"
        ld de,Fld_Seen_L
        ld bc,4
        ldir
        ld hl,SV_MS_COUNT+MB_RIGHT*4
        ld de,Fld_Seen_R
        ld bc,4
        ldir
        ret

;-------- Поле под мышью. Выход: HL - поле, 0 - нет (Z). Портит A, BC, DE, IX
Fld_Find
        ld de,0                     ; DE - самое глубокое совпадение
        ld ix,(SV_FIELDS)
        ld a,ixh
        or ixl
        jr z,.end
.l      ld a,(ix+FLD_X)             ; конец списка
        cp FLD_END
        jr z,.end
        ld a,(SV_MOUSE_COL)         ; колонка - x < w
        sub (ix+FLD_X)
        jr c,.n
        cp (ix+FLD_W)
        jr nc,.n
        ld a,(SV_MOUSE_ROW)         ; строка - y < h
        sub (ix+FLD_Y)
        jr c,.n
        cp (ix+FLD_H)
        jr nc,.n
        push ix                     ; попали - запомнить, дальше в детей
        pop de
        ld l,(ix+FLD_KIDS)
        ld h,(ix+FLD_KIDS+1)
        ld a,h
        or l
        jr z,.end
        push hl
        pop ix
        jr .l
.n      ld bc,FLD_SIZE              ; следующее поле этого списка
        add ix,bc
        jr .l
.end    ex de,hl
        ld a,h
        or l
        ret

;-------- Событие полю. HL - поле (0 - никому), A - событие, BC - параметры.
; Страница обработчика - в окно 1 на время вызова (если она уже там - сразу).
; Выход: CF - событие съедено. Портит всё
Fc_Ev           db 0
Fc_BC           dw 0
Fc_Res          db 0

Fld_Call
        ld (Fc_Ev),a
        ld a,h
        or l
        ret z                       ; некому (CF = 0)
        ld (Fc_BC),bc
        push hl
        pop ix                      ; IX - поле, его обработчик - в переход
        ld e,(ix+FLD_HANDLER)
        ld d,(ix+FLD_HANDLER+1)
        ld a,d                      ; обработчика нет (только дети) - событие ничьё
        or e
        ret z
        ld (Fc_Jp+1),de
        ld a,(ix+FLD_PAGE)          ; страница: 0 - коре, или уже в окне 1
        or a
        jr z,Fc_Now
        ld hl,SV_PAGES+1
        cp (hl)
        jr z,Fc_Now
        SETPAGE1 a
        call Fc_Now
        sbc a,a                     ; CF -> память: RESTPAGE портит флаги
        ld (Fc_Res),a
        RESTPAGE1
        ld a,(Fc_Res)
        rra
        ret
Fc_Now  ld a,(Fc_Ev)
        ld bc,(Fc_BC)
Fc_Jp   jp 0

;-------- Фокус - на поле HL (0 - ни на что): старому FOCUS_OUT, новому FOCUS_IN
Fld_Set_Focus
        ld de,(SV_FOCUS)
        or a
        sbc hl,de
        add hl,de
        ret z                       ; то же поле
        push hl
        ex de,hl
        ld a,EV_FOCUS_OUT
        call Fld_Call
        pop hl
        ld (SV_FOCUS),hl
        ld a,EV_FOCUS_IN
        jp Fld_Call

;-------- Нажали на поле HL: поле в фокусе - другое - ему EV_OUTSIDE (клик мимо). Портит всё
Fld_Outside
        ld de,(SV_FOCUS)
        ld a,d
        or e
        ret z                       ; фокуса нет
        or a
        sbc hl,de
        ret z                       ; нажали на него же
        ex de,hl
        ld a,EV_OUTSIDE
        jp Fld_Call

;-------- Клавиша полю в фокусе. B - код, C - флаги. Выход: CF - съело
Fld_Key
        ld hl,(SV_FOCUS)
        ld a,EV_KEY
        jp Fld_Call

;-------- Каждый кадр из основного цикла: наведение, кнопки мыши, колесо
Fld_Update
        call Tr_Watch               ; кнопки транспорта: играть перестало / начало - перерисовать
        ; --- наведение: сменилось поле под мышью - старому уход, новому вход
        call Fld_Find
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        add hl,de
        jr z,.left
        push hl
        ex de,hl
        ld a,EV_HOVER_OUT
        call Fld_Call
        pop hl
        ld (SV_HOVER),hl
        ld a,EV_HOVER_IN
        call Fld_Call

        ; --- форма курсора (каждый кадр): над полем с FF_HAND - лапка, иначе стрелка
.left   ld hl,(SV_HOVER)
        ld a,h
        or l
        ld a,MOUSE_TILE_ARROW
        jr z,.cur
        push hl
        pop ix
        bit 1,(ix+FLD_FLAGS)        ; FF_HAND
        jr z,.cur
        ld a,MOUSE_TILE_HAND
.cur    ld (MOUSE_TILE),a

        ; --- левая кнопка: нажатие, двойной, повтор, отпускание (в таком порядке -
        ;     за кадр может быть всё сразу)
        ld a,MB_LEFT
        ld hl,Fld_Seen_L
        call Mouse_Btn
        ld (Fu_Flags),a
        bit ME_PRESS,a
        jr z,.dbl
        ld hl,(SV_HOVER)            ; нажали: запомнить где, фокус - если поле берёт
        ld (SV_PRESSED),hl
        call Fld_Outside            ; мимо поля в фокусе - ему EV_OUTSIDE (строка ввода закончится)
        ld hl,(SV_PRESSED)
        ld a,h
        or l
        jr z,.dbl
        push hl
        pop ix
        bit 0,(ix+FLD_FLAGS)        ; FF_FOCUS
        call nz,Fld_Set_Focus
        ld hl,(SV_PRESSED)
        ld a,EV_PRESS
        call Fld_Call
.dbl    ld a,(Fu_Flags)
        bit ME_DOUBLE,a
        jr z,.rep
        ld hl,(SV_HOVER)
        ld a,EV_DOUBLE
        call Fld_Call
.rep    ld a,(Fu_Flags)             ; держат - повтор тому, где нажали
        bit ME_REPEAT,a
        jr z,.rel
        ld hl,(SV_PRESSED)
        ld a,EV_REPEAT
        call Fld_Call
.rel    ld a,(Fu_Flags)
        bit ME_RELEASE,a
        jr z,.right
        ld hl,(SV_PRESSED)          ; отпустили: тому, где нажали
        ld a,EV_RELEASE
        call Fld_Call
        ld hl,(SV_PRESSED)          ; над ним же - клик
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        jr nz,.unpress
        ex de,hl
        ld a,EV_CLICK
        call Fld_Call
.unpress
        ld hl,0
        ld (SV_PRESSED),hl

        ; --- правая кнопка: нажатие полю под мышью
.right  ld a,MB_RIGHT
        ld hl,Fld_Seen_R
        call Mouse_Btn
        bit ME_PRESS,a
        jr z,.wheel
        ld hl,(SV_HOVER)
        ld a,EV_RCLICK
        call Fld_Call

        ; --- колесо - полю под мышью
.wheel  call Mouse_Get_Wheel
        or a
        ret z
        ld c,a
        ld hl,(SV_HOVER)
        ld a,EV_WHEEL
        jp Fld_Call

; =========================================================================
; ОСЦИЛЛЯТОРЫ (doc/todo.md п.25): 6 окон 56x32 внизу экрана поверх текста - слой тайлов T0.
; Вторая страница плеера (окно 2). Тайлы - готовые (srs/oscgen.asm, раз при старте), цвет полос -
; из темы при входе в вид паттерна (Osc_Pal); промежутки и всё над волной - прозрачно (текст виден). Каждый кадр (Osc_Tick - IM1 сразу после тика
; плеера) - только номера тайлов в карту: окно = 4 ряда по 7. Высота - громкость*2 точек,
; огибающая - вся высота (32).
; Графика - в странице спрайтов (свободные ряды тайлов OSC_TROW..), карта - PAGE_TILEMAP.
; =========================================================================

Ow_H            db 0                ; окно: высота 0..32
Ow_P            db 0                ;   рисунок
    ASSERT OSC_GBASE < 256

;-------- Вход в вид паттерна: цвета тайлов - из темы, пустая карта, слой T0 - вкл
Osc_Init
        call Osc_Pal
        ld a,PAGE_TILEMAP           ; карта - пустая (тайл 0 прозрачный: текст виден)
        SETPAGE3 a
        ld hl,#C000
        ld de,#C001
        ld bc,#3FFF
        ld (hl),0
        ldir
        RESTPAGE3
        ld bc,TMPAGE                ; слой T0: карта, графика, сдвиг, палитра
        ld a,PAGE_TILEMAP
        out (c),a
        ld bc,T0GPAGE
        ld a,PAGE_SPRITE
        out (c),a
        ld bc,T0XOFFSL
        ld a,low OSC_XOFFS
        out (c),a
        ld bc,T0XOFFSH
        ld a,high OSC_XOFFS
        out (c),a
        ld bc,T0YOFFSL
        xor a
        out (c),a
        ld bc,T0YOFFSH
        out (c),a
        ld bc,PALSEL                ; тайлам - палитра 3 (с палитрой в слове тайла - OSC_PALN)
        ld a,PALET_NUM|(3<<PAL_T0PAL_BS)|(3<<PAL_T1PAL_BS)
        out (c),a
        ld bc,TSCONFIG              ; спрайты + тайлы T0; тайл 0 прозрачный (бит T0ZEN - наоборот,
        ld a,TSU_SEN|TSU_T0EN       ;   показать тайл 0: video_ts.v tile_valid)
        out (c),a
        ret

;-------- Цвет полос (палитра OSC_PALN, цвет 1): цвет нот темы (ink CLR_NOTE) - слово из
; Pal_Data выбранной темы, в CRAM - DMA. Цвет 0 - прозрачный
Osc_Pal
        ld a,(THEME_ATTR+CLR_NOTE)
        and #0F
        call .col
        ld (Op_Buf),de
        ld hl,Op_Dma
        jp set_ports
; A - номер цвета темы -> DE - его слово (Pal_Data + тема*32 + номер*2)
.col    add a,a
        ld e,a
        ld a,(Cur_Palette)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,0
        ld de,Pal_Data
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

OSC_CRAM        equ OSC_PALN*16+OSC_COL_W   ; цвет полос в палитре тайлов
Op_Dma  db high DMASADDRL,low (Op_Buf-#8000), high DMASADDRH,high (Op_Buf-#8000), high DMASADDRX,PAGE_PLAYER2
        db high DMADADDRL,(OSC_CRAM&127)*2, high DMADADDRH,OSC_CRAM>>7, high DMADADDRX,0
        db high DMALEN,1-1, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
        ALIGN 2                     ; DMA берёт адрес словами
Op_Buf          ds 2                ; слово цвета полос

;-------- Выход из вида паттерна: тайлы - выкл
Osc_Off
        ld bc,TSCONFIG
        ld a,TSU_SEN
        out (c),a
        ret

;-------- Кадр (IM1 после тика плеера, страницы плеера - в окнах 1 и 2): окна по регистрам
Osc_Tick
        ld a,PAGE_TILEMAP
        SETPAGE3 a
        ld hl,Pl_Regs               ; чип 1 - окна 0..2
        ld de,#C000+OSC_MAPROW*256
        call .chip
        ld hl,Pl_Regs2              ; чип 2 - окна 3..5
        ld de,#C000+OSC_MAPROW*256+3*7*2
        call .chip
        RESTPAGE3
        ret
; HL - регистры чипа (L = 0), DE - карта окна канала A
.chip   ld b,0                      ; B - канал 0..2
.ch     push bc
        push de
        push hl
        call Osc_Win
        pop hl
        pop de
        pop bc
        ld a,e                      ; окно правее - 7 тайлов (6 окна + зазор)
        add a,7*2
        ld e,a
        inc b
        ld a,b
        cp 3
        jr c,.ch
        ret

; Окно канала B: HL - регистры чипа (L = 0), DE - карта (ряд 32, его колонка)
Osc_Win
        ld l,7                      ; тон выкл (бит B микшера) - сплошной
        ld a,(hl)
        ld c,b
        inc c
.r      rrca
        dec c
        jr nz,.r
        ld a,OSC_SOLID
        jr c,.pat
        ld a,b                      ; период R(2B): рисунок по старшим 8 битам из 12
        add a,a
        ld l,a
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld c,a
        inc l
        ld a,(hl)
        and #0F
        rlca
        rlca
        rlca
        rlca
        or c
        push hl
        ld l,a
        ld h,high Osc_PT
        ld a,(hl)
        pop hl
.pat    ld (Ow_P),a
        ld a,b                      ; высота: огибающая - вся, иначе громкость*2
        add a,8
        ld l,a
        ld a,(hl)
        bit 4,a
        ld a,32
        jr nz,.h
        ld a,(hl)
        and #0F
        add a,a
.h      ld (Ow_H),a
        sub 24                      ; 3 ряда сверху: заполнение - высота минус ряды ниже
        call .row
        ld a,(Ow_H)
        sub 16
        call .row
        ld a,(Ow_H)
        sub 8
        call .row
        ld a,(Ow_H)                 ; нижний ряд - с линией нуля; громкость 0 - только она
        or a
        ld l,OSC_GBASE
        jr z,.gt
        call .lev
        add a,4
        jr .grp
; A - заполнение ряда (0 и меньше - прозрачно): 7 номеров тайлов в карту (DE), DE - ниже
.row    or a
        jp m,.bg
        jr z,.bg
        call .lev
; A - вариант -> группа рисунок*OSC_VARS + вариант -> слово её первого тайла
.grp    ld l,a
        ld a,(Ow_P)
        add a,a
        add a,a
        add a,a
        add a,l
        ld l,a
.gt     ld h,0
        add hl,hl
        ld bc,Osc_GT
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,OSC_TW                 ; тайлы окна подряд
.t      ld a,l
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        inc hl
        djnz .t
        jr .next
.bg     ld hl,0                     ; тайл 0 - прозрачный (виден текст)
        ld b,OSC_TW
.tb     ld a,l
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        djnz .tb
.next   ld a,e                      ; ряд карты ниже
        sub OSC_TW*2
        ld e,a
        inc d
        ret
; A - заполнение 1.. -> уровень 0..3 (больше 8 - 8)
.lev    cp 9
        jr c,$+4
        ld a,8
        rrca
        dec a
        ret

; Группа тайлов -> слово карты её первого тайла (номер + палитра)
    MACRO OSC_GT_GEN
Ok = 0
    DUP OSC_GROUPS
        dw ((OSC_TROW + Ok/OSC_GPR)*64 + (Ok%OSC_GPR)*OSC_TW) | OSC_PAL
Ok = Ok + 1
    EDUP
    ENDM
Osc_GT  OSC_GT_GEN

; Период тона / 16 -> рисунок: полупериод полос ~ период / 64 точек (1..28), линейно - как
; GetStep индикатора FT-плеера ((4*P+32)/256)
        ALIGN 256
Osc_PT  db 0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3
        db 3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7
        db 7,8,8,8,8,9,9,9,9,10,10,10,10,11,11,11
        db 11,12,12,12,12,13,13,13,13,14,14,14,14,15,15,15
        db 15,16,16,16,16,17,17,17,17,18,18,18,18,19,19,19
        db 19,20,20,20,20,21,21,21,21,22,22,22,22,23,23,23
        db 23,24,24,24,24,25,25,25,25,26,26,26,26,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27
        db 27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27

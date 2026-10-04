; =========================================================================
; ПРОСМОТР ПАТТЕРНА - тулза (окно 1, #4000)
; Пока: заполняет тестовый паттерн и выводит его в минимальном виде
; (нота + поле инструмента), 1 чип, 3 канала.
; =========================================================================
    MODULE patview

PAT_PAGE        equ PAGE_POOL           ; временно: первая страница пула, пока нет
                                        ; распределителя и каталога трека
PAT_SLOT        equ 0               ; слот паттерна в полосе
PAT_BASE_H      equ #80             ; страница паттернов - в окне 2
SCR_BASE_H      equ #C0             ; экран - в окне 3
VIEW_LINE       equ 7               ; строка экрана с заголовком
VIEW_ROWS       equ 27              ; видимых строк паттерна (экран 8..34)
VIEW_CENTER     equ VIEW_ROWS/2     ; текущая строка паттерна и позиция ордера - по центру,
                                    ; при проигрывании всё уезжает вверх

; Экран во всю ширину: ордер-лист прижат слева, паттерн центруется в остатке.
ORD_COL         equ 0
ORD_W           equ 7               ; "r►05◄N|": повтор, стрелки у текущей, паттерн, кнопка
ARROW_R         equ #10             ; ► в шрифте 866
ARROW_L         equ #11             ; ◄
BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_UP          equ #C1             ; ┴
BOX_DOWN        equ #C2             ; ┬
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘
PAT_VIEW_W      equ 49              ; ширина вывода паттерна (L1, 1 чип, с пробелами у линий);
                                    ; потом будет считаться по карте колонок, и пробелы
                                    ; будут убираться, если не влезает
VIEW_COL        equ ORD_W+(SCR_COLS-ORD_W-PAT_VIEW_W)/2

; Тестовый ордер-лист (пока нет страницы трека)
TEST_ORD_LAST   equ 3

    PLUGIN_HEADER PLG_TOOL,"   ","Pattern view"

PluginMain
        SETPAGE2 PAT_PAGE
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        call Test_Fill
        call Clear_View
        call Draw_Order
        call Draw_Rows
        call Highlight_Edit_Row
        call Draw_Top               ; сначала замыкаем рамку,
        call Draw_Header            ; потом поверх верхней линии - подписи на плашке
        call Draw_Bottom
        RESTPAGE3
        RESTPAGE2
        xor a                       ; ERR_OK
        ret

Cur_Row         db 0                ; текущая строка паттерна (по центру экрана)
Cur_Pos         db 0                ; текущая позиция ордер-листа
Loop_Pos        db 0                ; позиция повтора
Test_Order      db 0,0,0,0          ; номера паттернов по позициям

;-------- Тестовый паттерн в слоте PAT_SLOT
Test_Fill
        ld h,PAT_BASE_H             ; очистка: 64 полосы по PAT_WIDTH байт
        ld b,PAT_ROWS_MAX
.clr    ld l,PAT_SLOT
        ld c,PAT_WIDTH
        xor a
.clr1   ld (hl),a
        inc l
        dec c
        jr nz,.clr1
        inc h
        djnz .clr

        ld hl,PAT_BASE_H*256+PAT_SLOT+CHIP_ENVPER
        ld (hl),#2D                 ; период огибающей #012D, младший байт первым
        inc l
        ld (hl),#01
        ld l,PAT_SLOT+CHIP_NOISE
        ld (hl),#0A

        ld h,PAT_BASE_H
        ld c,0                      ; номер строки
.row    ld a,c
        and 3
        jr nz,.no_a
        ld a,c                      ; канал A каждые 4 строки: C-4, C#4, ...
        rrca
        rrca
        and #0F
        cp 12
        jr c,$+4
        sub 12
        add a,NOTE_FIRST+12*4
        ld l,PAT_SLOT+CHIP_CH_A+CH_NOTE
        ld (hl),a
        inc l
        ld (hl),1                   ; сэмпл 1
        inc l
        inc l
        inc l
        ld (hl),15                  ; громкость F
.no_a   ld a,c
        and 7
        cp 2
        jr nz,.no_b
        ld l,PAT_SLOT+CHIP_CH_B+CH_NOTE
        ld (hl),NOTE_FIRST+12*3+7   ; G-3
        inc l
        ld (hl),2                   ; сэмпл 2
        inc l
        inc l
        ld (hl),3                   ; орнамент 3
.no_b   ld a,c
        and 15
        jr nz,.no_c
        ld l,PAT_SLOT+CHIP_CH_C+CH_NOTE
        ld (hl),NOTE_FIRST+12*2     ; C-2
        inc l
        ld (hl),10                  ; сэмпл A
        inc l
        ld (hl),8                   ; огибающая 8
        inc l
        inc l
        ld (hl),12                  ; громкость C
.no_c   inc h
        inc c
        ld a,c
        cp PAT_ROWS_MAX
        jr c,.row

        ld hl,(PAT_BASE_H+34)*256+PAT_SLOT+CHIP_CH_A+CH_NOTE
        ld (hl),NOTE_OFF
        ret

;-------- Очистка области вывода (во всю ширину)
Clear_View
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld d,SCR_BASE_H+VIEW_LINE
        ld b,VIEW_ROWS+1
.ln     ld e,0
.ch     ld a,' '
        call PutCh
        ld a,e
        cp SCR_COLS
        jr c,.ch
        inc d
        djnz .ln
        ret

;-------- Подписи и кнопки поверх верхней линии рамки
; Таблица: колонка, роль цвета, текст, 0; конец - #FF. Стоят между стыками ┬,
; сами стыки и углы не перекрывают.
Draw_Header
        ld d,SCR_BASE_H+VIEW_LINE
        ld hl,Header_Items
.item   ld a,(hl)
        cp #FF
        ret z
        ld e,a
        inc hl
        ld a,(hl)                   ; роль -> атрибут из темы
        inc hl
        push hl
        add a,low THEME_ATTR
        ld l,a
        adc a,high THEME_ATTR
        sub l
        ld h,a
        ld c,(hl)
        pop hl
        call PutStr
        inc hl                      ; пропустить 0
        jr .item

;-------- Строка HL (до 0) атрибутом C в DE. На выходе HL на нуле
PutStr
.l      ld a,(hl)
        or a
        ret z
        call PutCh
        inc hl
        jr .l

; Колонки - как в строке паттерна: │ 00 │ 012D 0A │ C-4 1--F │ ...
; В заголовке канала справа - кнопки +- (раскрыть / свернуть канал).
Header_Items    db ORD_COL,     CLR_HEADER, "Order ",0
                db VIEW_COL+1,  CLR_HEADER, " Rw ",0
                db VIEW_COL+6,  CLR_HEADER, " Env  Ns ",0
                db VIEW_COL+16, CLR_HEADER, " Ch:A ",0
                db VIEW_COL+24, CLR_BUTTON, "+-",0      ; вплотную к правому стыку
                db VIEW_COL+27, CLR_HEADER, " Ch:B ",0
                db VIEW_COL+35, CLR_BUTTON, "+-",0
                db VIEW_COL+38, CLR_HEADER, " Ch:C ",0
                db VIEW_COL+46, CLR_BUTTON, "+-",0
                db #FF
    ASSERT VIEW_COL+PAT_VIEW_W <= SCR_COLS

;-------- Ордер-лист слева: только номера паттернов.
; r - позиция повтора, ►NN◄ - текущая, справа от текущей и двух под ней - кнопки N + -
Draw_Order
        ld d,SCR_BASE_H+VIEW_LINE+1
        ld a,(Cur_Pos)              ; текущая позиция - на центральной строке
        sub VIEW_CENTER
        ld b,a                      ; B - позиция (выше начала списка - "отрицательная")
        ld a,VIEW_ROWS
.l      push af
        ld a,b
        cp TEST_ORD_LAST+1
        jr nc,.buttons              ; за концом списка - только кнопки
        ld e,ORD_COL

        ld a,(THEME_ATTR+CLR_LOOP)
        ld c,a
        ld a,(Loop_Pos)             ; маркер повтора
        cp b
        ld a,' '
        jr nz,$+4
        ld a,'r'
        call PutCh

        ld a,(THEME_ATTR+CLR_ORD_CUR)
        ld c,a
        ld a,(Cur_Pos)              ; левая стрелка
        cp b
        ld a,' '
        jr nz,$+4
        ld a,ARROW_R
        call PutCh

        ld a,(THEME_ATTR+CLR_PATNUM)    ; номер паттерна
        ld c,a
        ld a,b
        add a,low Test_Order
        ld l,a
        adc a,high Test_Order
        sub l
        ld h,a
        ld a,(hl)
        call PutHex2

        ld a,(THEME_ATTR+CLR_ORD_CUR)   ; правая стрелка
        ld c,a
        ld a,(Cur_Pos)
        cp b
        ld a,' '
        jr nz,$+4
        ld a,ARROW_L
        call PutCh

.buttons
        ld e,ORD_COL+5
        ld a,(Cur_Pos)              ; A = позиция - текущая
        neg
        add a,b
        cp 3
        jr nc,.bar                  ; кнопки только у текущей и двух под ней
        add a,low Order_Buttons
        ld l,a
        adc a,high Order_Buttons
        sub l
        ld h,a
        ld a,(THEME_ATTR+CLR_BUTTON)
        ld c,a
        ld a,(hl)
        call PutCh
.bar    ld e,ORD_W-1
        call PutBar
        inc d
        inc b
        pop af
        dec a
        jr nz,.l
        ret

Order_Buttons   db "N+-"            ; новый паттерн, следующий номер, предыдущий

;-------- Видимые строки паттерна, текущая - по центру
Draw_Rows
        ld a,(Cur_Row)
        sub VIEW_CENTER
        ld b,a                      ; B - строка паттерна (выше нуля - "отрицательная")
        ld d,SCR_BASE_H+VIEW_LINE+1 ; D - строка экрана
        ld a,VIEW_ROWS
.l      push af
        push bc
        push de
        ld e,VIEW_COL
        ld a,b
        cp PAT_ROWS_MAX             ; вне паттерна (и "отрицательные" тоже) - пустая строка
        jr nc,.empty
        call Draw_Row
        jr .next
.empty  call Draw_Empty_Row
.next   pop de
        pop bc
        inc b
        inc d
        pop af
        dec a
        jr nz,.l
        ret

;-------- Подсветка строки редактирования (центральной): фон из CLR_EDIT_ROW,
; цвет символов (ink) у каждого поля остаётся свой
EDIT_LINE       equ VIEW_LINE+1+VIEW_CENTER
Highlight_Edit_Row
        ld a,(THEME_ATTR+CLR_EDIT_ROW)
        and #F0
        ld c,a                      ; C - новый фон
        ld h,SCR_BASE_H+EDIT_LINE
        ld l,VIEW_COL+SCR_ATTR      ; атрибуты - на +128 в строке
        ld b,PAT_VIEW_W
.l      ld a,(hl)
        and #0F                     ; оставляем ink
        or c
        ld (hl),a
        inc l
        djnz .l
        ret

;-------- Пустая строка вне паттерна: только вертикали рамки
Draw_Empty_Row
        ld hl,Bar_Cols
.l      ld a,(hl)
        cp #FF
        ret z
        add a,VIEW_COL
        ld e,a
        call PutBar
        inc hl
        jr .l

; Где в строке паттерна стоят │ (от VIEW_COL): │ 00 │ 012D 0A │ C-4 1--F │ ...
Bar_Cols        db 0,5,15,26,37,48,#FF

;-------- Одна строка: B - строка паттерна, DE - экран
Draw_Row
        call PutBar                 ; левая рамка блока паттерна
        call PutSpace
        ld a,b                      ; номер строки, каждая 4-я выделена
        and 3
        ld a,(THEME_ATTR+CLR_ROW_NUM)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_ROW_BEAT)
        ld c,a
        ld a,b
        call PutHex2
        call PutSpace
        call PutBar

        ld a,b
        add a,PAT_BASE_H
        ld h,a                      ; H - строка паттерна

        call PutSpace
        ld l,PAT_SLOT+CHIP_ENVPER   ; заголовок чипа (C0): огибающая и шум
        call Put_EnvPer
        call PutSpace
        ld l,PAT_SLOT+CHIP_NOISE
        ld a,(hl)
        or a
        jr nz,.ns
        ld a,2
        call PutDashN
        jr .ns_done
.ns     ld a,(THEME_ATTR+CLR_NOISE)
        ld c,a
        ld a,(hl)
        call PutHex2
.ns_done
        call PutSpace
        call PutBar

        ld l,PAT_SLOT+CHIP_CH_A
        call Put_Channel
        ld l,PAT_SLOT+CHIP_CH_B
        call Put_Channel
        ld l,PAT_SLOT+CHIP_CH_C
        jp Put_Channel

;-------- Канал L1: нота + поле инструмента. HL - начало канала
Put_Channel
        call PutSpace
        ld a,(hl)
        call Put_Note
        call PutSpace
        inc l
        ld a,(THEME_ATTR+CLR_INSTR)
        ld c,a
        ld a,(hl)                   ; сэмпл
        call Put_Sym
        inc l
        ld a,(THEME_ATTR+CLR_ENVSHAPE)
        ld c,a
        ld a,(hl)                   ; огибающая
        call Put_Hex1
        inc l
        ld a,(THEME_ATTR+CLR_ORNAMENT)
        ld c,a
        ld a,(hl)                   ; орнамент 1..16
        call Put_Sym
        inc l
        ld a,(THEME_ATTR+CLR_VOLUME)
        ld c,a
        ld a,(hl)                   ; громкость
        call Put_Hex1
        call PutSpace
        jp PutBar

;-------- Период огибающей (2 байта по HL), 0 - "----"
Put_EnvPer
        ld a,(hl)
        inc l
        or (hl)
        jr nz,.val
        dec l
        ld a,4
        jp PutDashN
.val    ld a,(THEME_ATTR+CLR_ENVPER)
        ld c,a
        ld a,(hl)                   ; старший
        call PutHex2
        dec l
        ld a,(hl)                   ; младший
        jp PutHex2

;-------- Нота: A. 0 "---", 1..96 "C-4", NOTE_OFF "OFF", остальное "???"
Put_Note
        or a
        jr nz,.n
        ld a,3
        jp PutDashN
.n      cp NOTE_LAST+1
        jr nc,.cmd
        push hl
        push bc
        dec a
        ld b,0                      ; B - октава
.oct    sub 12
        jr c,.got
        inc b
        jr .oct
.got    add a,12                    ; полутон 0..11
        add a,a
        add a,low Note_Names
        ld l,a
        adc a,high Note_Names
        sub l
        ld h,a
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld a,(hl)
        call PutCh
        inc hl
        ld a,(hl)
        call PutCh
        ld a,b
        add a,'0'
        call PutCh
        pop bc
        pop hl
        ret
.cmd    push bc
        cp NOTE_OFF
        jr nz,.unk
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld a,'O'
        call PutCh
        ld a,'F'
        call PutCh
        ld a,'F'
        call PutCh
        pop bc
        ret
.unk    ld a,(THEME_ATTR+CLR_ERROR)
        ld c,a
        ld a,'?'
        call PutCh
        ld a,'?'
        call PutCh
        ld a,'?'
        call PutCh
        pop bc
        ret

Note_Names      db "C-C#D-D#E-F-F#G-G#A-A#B-"

;-------- Символ 1..32: 1..9, A..W. 0 - "-"
Put_Sym
        or a
        jr z,Put_Empty1
        cp 10
        jr c,.dig
        cp 33
        jr nc,.bad
        add a,'A'-10
        jp PutCh
.dig    add a,'0'
        jp PutCh
.bad    ld a,'?'
        jp PutCh

;-------- Hex-цифра (младшая тетрада). 0 - "-"
Put_Hex1
        or a
        jr z,Put_Empty1
        and #0F
        call HexDigit
        jp PutCh

Put_Empty1
        ld a,1
        jp PutDashN

;-------- A - число, выводит 2 hex-цифры атрибутом C
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

;-------- A штук "-" цветом пустого поля. Сохраняет BC
PutDashN
        push bc
        ld b,a
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld c,a
.l      ld a,'-'
        call PutCh
        djnz .l
        pop bc
        ret

PutBar
        push bc
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,BOX_V
        call PutCh
        pop bc
        ret

;-------- Рамка: замыкает вертикали ордер-листа и паттерна сверху и снизу
BOTTOM_LINE     equ VIEW_LINE+VIEW_ROWS+1

Draw_Top                            ; ┌──┬──┐ по строке заголовка, над первой строкой
        ld a,BOX_TL
        ld (HL_CornerL),a
        ld a,BOX_TR
        ld (HL_CornerR),a
        ld a,BOX_DOWN
        ld (HL_Junction),a
        ld d,SCR_BASE_H+VIEW_LINE
        ld h,SCR_BASE_H+VIEW_LINE+1
        jr Draw_HLine

Draw_Bottom                         ; └──┴──┘ под последней строкой
        ld a,BOX_BL
        ld (HL_CornerL),a
        ld a,BOX_BR
        ld (HL_CornerR),a
        ld a,BOX_UP
        ld (HL_Junction),a
        ld d,SCR_BASE_H+BOTTOM_LINE
        ld h,SCR_BASE_H+BOTTOM_LINE-1

;-------- Горизонтальная линия во всю ширину экрана
; D - строка, где рисуем; H - соседняя строка, где смотрим вертикали.
; Над/под │: на левом краю блока - угол L, на правом - угол R, внутри - стык.
Draw_HLine
        ld e,0
.l      ld a,e                      ; внутри ордер-листа или блока паттерна?
        cp ORD_W
        jr c,.in
        cp VIEW_COL
        jr c,.out
        cp VIEW_COL+PAT_VIEW_W
        jr nc,.out
.in     ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld l,e
        ld a,(hl)                   ; символ в соседней строке
        cp BOX_V
        ld a,BOX_H
        jr nz,.put
        ld a,e                      ; вертикаль: угол или стык
        cp VIEW_COL
        jr z,.cl
        cp ORD_W-1
        jr z,.cr
        cp VIEW_COL+PAT_VIEW_W-1
        jr z,.cr
        ld a,(HL_Junction)
        jr .put
.cl     ld a,(HL_CornerL)
        jr .put
.cr     ld a,(HL_CornerR)
        jr .put
.out    ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,' '
.put    call PutCh
        ld a,e
        cp SCR_COLS
        jr c,.l
        ret

HL_CornerL      db 0
HL_CornerR      db 0
HL_Junction     db 0

PutSpace
        push bc
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,' '
        call PutCh
        pop bc
        ret

;-------- Символ A атрибутом C в позицию DE (D - строка экрана, E - колонка)
; Атрибут лежит на +128 в той же строке. E += 1. Портит A.
PutCh
        ld (de),a
        set 7,e
        ld a,c
        ld (de),a
        res 7,e
        inc e
        ret

    ENDMODULE

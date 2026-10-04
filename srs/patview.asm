; =========================================================================
; ПРОСМОТР ПАТТЕРНА - тулза (окно 1, #4000)
; Пока: заполняет тестовый паттерн и выводит его в минимальном виде
; (нота + поле инструмента), 1 чип, 3 канала.
;
; Вывод в два этапа:
;  - Prepare_View: статика (фон, рамки, ордер-лист, заголовок) - при смене вида;
;  - Draw_Rows: только данные. Каждое поле - таблицы-плоскости на границе 256:
;    значение в L, плоскость в H, следующий символ - inc h, последняя плоскость -
;    атрибут. Без сравнений, переходов и call на символ.
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
ORD_W           equ 8               ; "│r►05◄N│": рамка, повтор, стрелки у текущей,
                                    ; паттерн, кнопка, рамка
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
                                    ; потом будет считаться по карте колонок
VIEW_COL        equ ORD_W+(SCR_COLS-ORD_W-PAT_VIEW_W)/2

; Тестовый ордер-лист (пока нет страницы трека)
TEST_ORD_LAST   equ 3

    PLUGIN_HEADER PLG_TOOL,"   ","Pattern view"

PluginMain
        SETPAGE2 PAT_PAGE
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        call Test_Fill
        call Build_Attr_Tables
        call Prepare_View
        call Draw_Rows
        call Highlight_Edit_Row
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

; =========================================================================
; СТАТИКА - рисуется при смене вида
; =========================================================================
Prepare_View
        call Clear_View
        call Draw_Frame_Rows
        call Draw_Order
        call Draw_Top               ; сначала замыкаем рамку,
        call Draw_Header            ; потом поверх верхней линии - подписи на плашке
        jp Draw_Bottom

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

;-------- Вертикали блока паттерна во всех строках
Draw_Frame_Rows
        ld d,SCR_BASE_H+VIEW_LINE+1
        ld b,VIEW_ROWS
.l      call Draw_Empty_Row
        inc d
        djnz .l
        ret

; Вертикали строки: только │ на местах из Bar_Cols. Портит A,E,HL
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
Header_Items    db ORD_COL+1,   CLR_HEADER, "Order ",0
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
        ld e,ORD_COL                ; левая рамка
        call PutBar
        ld a,b
        cp TEST_ORD_LAST+1
        jr nc,.buttons              ; за концом списка - только кнопки

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
        ld e,ORD_COL+6
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
        cp ORD_COL
        jr z,.cl
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

; =========================================================================
; ДАННЫЕ - быстрый вывод строк
; =========================================================================

;-------- Видимые строки паттерна, текущая - по центру
Draw_Rows
        ld a,(Cur_Row)
        sub VIEW_CENTER
        ld (Row_Iter),a             ; строка паттерна (выше нуля - "отрицательная")
        ld d,SCR_BASE_H+VIEW_LINE+1 ; D - строка экрана
        ld a,VIEW_ROWS
.l      push af
        ld a,(Row_Iter)
        cp PAT_ROWS_MAX             ; вне паттерна (и "отрицательные" тоже) - пусто
        jr nc,.empty
        call Draw_Row
        jr .next
.empty  call Blank_Row
.next   ld hl,Row_Iter
        inc (hl)
        inc d
        pop af
        dec a
        jr nz,.l
        ret

Row_Iter        db 0

; Символ из плоскости H по значению L в (DE), E++, H++ - следующая плоскость
    MACRO PUT_PLANE
        ld a,(hl)
        ld (de),a
        inc e
        inc h
    ENDM

; Нота: 3 символа + атрибут
    MACRO F_NOTE col,fld
        ld c,PAT_SLOT+fld
        ld a,(bc)
        ld l,a
        ld h,high Note_T
        ld e,col
        PUT_PLANE
        PUT_PLANE
        PUT_PLANE                   ; H - плоскость атрибута
        ld a,(hl)
        dec e
        set 7,e                     ; атрибуты - на +128
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
    ENDM

; Однознаковое поле: символ из tab, атрибут из плоскости tab+attr
    MACRO F_ONE col,fld,tab,attr
        ld c,PAT_SLOT+fld
        ld a,(bc)
        ld l,a
        ld h,high tab
        ld e,col
        ld a,(hl)
        ld (de),a
        ld h,(high tab)+attr
        ld a,(hl)
        set 7,e
        ld (de),a
    ENDM

; Два hex-знака, 0 = "--": символы и атрибут из HexD_T
    MACRO F_HEXD col,fld
        ld c,PAT_SLOT+fld
        ld a,(bc)
        ld l,a
        ld h,high HexD_T
        ld e,col
        PUT_PLANE
        PUT_PLANE                   ; H - плоскость атрибута
        ld a,(hl)
        dec e
        set 7,e
        ld (de),a
        dec e
        ld (de),a
    ENDM

; Канал L1: " C-4 1F0E " от base (base - пробел после │)
    MACRO CHAN_L1 base,ch
        F_NOTE base+1, ch+CH_NOTE
        F_ONE  base+5, ch+CH_SAMPLE,   Sym_T, 1
        F_ONE  base+6, ch+CH_ENVSHAPE, Hx1_T, 1
        F_ONE  base+7, ch+CH_ORNAMENT, Sym_T, 2
        F_ONE  base+8, ch+CH_VOLUME,   Hx1_T, 2
    ENDM

;-------- Одна строка: A - строка паттерна (0..63), D - строка экрана. D не портит
Draw_Row
        ld l,a
        add a,PAT_BASE_H
        ld b,a                      ; BC - указатель в паттерн, B - строка

        ld h,high Hex_T             ; номер строки, цвет - по номеру (каждая 4-я)
        ld e,VIEW_COL+2
        PUT_PLANE
        ld a,(hl)
        ld (de),a
        ld h,high Row_A
        ld a,(hl)
        set 7,e
        ld (de),a
        dec e
        ld (de),a

        ld c,PAT_SLOT+CHIP_ENVPER   ; период огибающей: 0 - "----"
        ld a,(bc)
        inc c
        ld e,a                      ; E - младший байт (на время)
        ld a,(bc)
        ld l,a                      ; L - старший
        or e
        ld a,e
        ld e,VIEW_COL+7
        jr z,.env_empty
        push af                     ; младший
        ld h,high Hex_T
        PUT_PLANE
        ld a,(hl)
        ld (de),a
        inc e
        pop af
        ld l,a
        ld h,high Hex_T
        PUT_PLANE
        ld a,(hl)
        ld (de),a
        ld a,(THEME_ATTR+CLR_ENVPER)
        jr .env_attr
.env_empty
        ld a,'-'
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        inc e
        ld (de),a
        ld a,(THEME_ATTR+CLR_EMPTY)
.env_attr
        set 7,e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a
        dec e
        ld (de),a

        F_HEXD VIEW_COL+12, CHIP_NOISE

        CHAN_L1 VIEW_COL+16, CHIP_CH_A
        CHAN_L1 VIEW_COL+27, CHIP_CH_B
        CHAN_L1 VIEW_COL+38, CHIP_CH_C
        ret

;-------- Строка вне паттерна: пробелы в клетках данных (между вертикалями)
Blank_Row
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld hl,Bar_Cols
.seg    ld a,(hl)                   ; левая вертикаль
        inc hl
        add a,VIEW_COL+1
        ld e,a
        ld a,(hl)                   ; правая
        cp #FF
        ret z
        add a,VIEW_COL
        sub e                       ; сколько клеток между ними
        jr z,.seg
        ld b,a
.f      ld a,' '
        call PutCh
        djnz .f
        jr .seg

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

;-------- Плоскости атрибутов из темы: значение 0 - "пусто", остальное - цвет поля
Build_Attr_Tables
        ld a,(THEME_ATTR+CLR_NOTE)
        ld h,(high Note_T)+3
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_NOISE)
        ld h,(high HexD_T)+2
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_INSTR)
        ld h,(high Sym_T)+1
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_ORNAMENT)
        ld h,(high Sym_T)+2
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_ENVSHAPE)
        ld h,(high Hx1_T)+1
        call Fill_Attr_Plane
        ld a,(THEME_ATTR+CLR_VOLUME)
        ld h,(high Hx1_T)+2
        call Fill_Attr_Plane

        ld h,high Row_A             ; номер строки: каждая 4-я выделена
        ld l,0
.r      ld a,l
        and 3
        ld a,(THEME_ATTR+CLR_ROW_NUM)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_ROW_BEAT)
        ld (hl),a
        inc l
        jr nz,.r
        ret

; H - плоскость, A - атрибут: все значения = A, значение 0 = CLR_EMPTY
Fill_Attr_Plane
        ld l,0
.f      ld (hl),a
        inc l
        jr nz,.f
        ld a,(THEME_ATTR+CLR_EMPTY)
        ld (hl),a
        ret

; =========================================================================
; Простой вывод (статика, ордер-лист)
; =========================================================================

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

PutBar
        push bc
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,BOX_V
        call PutCh
        pop bc
        ret

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

; =========================================================================
; ТАБЛИЦЫ-ПЛОСКОСТИ (каждая 256 байт на границе 256, индекс - само значение)
; =========================================================================
; hex-цифра d -> символ: '0'+d+((d+6)>>4)*7 (для d>=10 прибавляется 7: 'A'..'F')

        ALIGN 256
; Нота: 0 "---", 1..96 "C-0".."B-7", 97 "OFF", 98..255 "???" (команды ноты - потом)
Note_T  db '-'
        DUP 8
        db "CCDDEFFGGAAB"
        EDUP
        db 'O'
        ds 256-98,'?'
        db '-'                      ; плоскость 1
        DUP 8
        db "-#-#--#-#-#-"
        EDUP
        db 'F'
        ds 256-98,'?'
        db '-'                      ; плоскость 2: октава
        DUP 8,O
        DUP 12
        db '0'+O
        EDUP
        EDUP
        db 'F'
        ds 256-98,'?'
        ds 256                      ; плоскость 3: атрибут (Build_Attr_Tables)

; Два hex-знака всегда (номер строки, период огибающей)
Hex_T   DUP 256,N
        db '0'+(N>>4)+(((N>>4)+6)>>4)*7
        EDUP
        DUP 256,N
        db '0'+(N&15)+(((N&15)+6)>>4)*7
        EDUP

; Два hex-знака, 0 = "--" (шум)
HexD_T  db '-'
        DUP 255,N
        db '0'+((N+1)>>4)+((((N+1)>>4)+6)>>4)*7
        EDUP
        db '-'
        DUP 255,N
        db '0'+((N+1)&15)+((((N+1)&15)+6)>>4)*7
        EDUP
        ds 256                      ; плоскость 2: атрибут шума

; Атрибут номера строки по номеру
Row_A   ds 256

; Символ 1..32: 0 "-", 1..9, A..W, дальше "?" (сэмпл, орнамент)
Sym_T   db '-'
        DUP 9,I
        db '1'+I
        EDUP
        DUP 23,I
        db 'A'+I
        EDUP
        ds 256-33,'?'
        ds 256                      ; плоскость 1: атрибут сэмпла
        ds 256                      ; плоскость 2: атрибут орнамента

; Hex-цифра: 0 "-", 1..F, дальше "?" (огибающая, громкость)
Hx1_T   db '-'
        DUP 15,I
        db '0'+(I+1)+(((I+1)+6)>>4)*7
        EDUP
        ds 256-16,'?'
        ds 256                      ; плоскость 1: атрибут огибающей
        ds 256                      ; плоскость 2: атрибут громкости
Tables_End

    ASSERT (Note_T & 255) == 0
    ASSERT Hex_T == Note_T+4*256
    ASSERT HexD_T == Hex_T+2*256
    ASSERT Row_A == HexD_T+3*256
    ASSERT Sym_T == Row_A+256
    ASSERT Hx1_T == Sym_T+3*256
    ASSERT Tables_End == Hx1_T+3*256

    ENDMODULE

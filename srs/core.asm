; Core 
    ds #38
    org #0038   ; im1
    di
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ex af,af'
    push af
    push bc
    push de
    push hl
    call IM1_Handler
    pop hl
    pop de
    pop bc
    pop af
    ex af,af'
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ei
    ret

    org #0100   ;пропускаем нми и др парашу

IM1_Handler

    call Read_Mouse

    ret

    

Core_Start
        ; системные переменные для плагинов (sdk/plugin.asm)
        ld a,FT2_API_VERSION
        ld (SV_API_VERSION),a
        ld a,PAGE_TEXT
        ld (SV_DRAW_PAGE),a
        ld hl,Theme_Default
        ld de,THEME_ATTR
        ld bc,Theme_Default_end-Theme_Default
        ldir

        im 1
        ld hl,100
        ld de,100
        call Init_Mouse_Sprite

        xor a                   ; шрифт 0 и значки поверх
        call Set_Font
        call Apply_UI_Glyphs

        ld a,PAGE_TOOL_PATVIEW  ; пока просто показываем тестовый паттерн
        call Call_Tool

Pause
        ei
        halt
        jp Pause

;-------- Вызов тулзы: страница тулзы в окно 1, старт с #4000
; in: A - пейдж тулзы
; Тулза сама SETPAGE2/3 под свои данные и RESTPAGE перед ret.
; После возврата окно 1 восстановлено. Портит A, BC.
Call_Tool
        SETPAGE1 a
        call #4000
        RESTPAGE1
        ret


;-------- Шрифты. Банк PAGE_FONTS: шрифты по слотам FONT_SIZE, в слоте UI_GLYPH_SLOT -
; значки интерфейса. Выбранный шрифт копируется в PAGE_FONT (его видит текстовый
; режим), потом поверх кладутся значки - Apply_UI_Glyphs.
; Set_Font: in A - номер шрифта. Портят AF,BC,DE,HL.
Set_Font
        ld (SV_FONT),a
        ld e,a
        SETPAGE2 PAGE_FONTS
        SETPAGE3 PAGE_FONT
        ld a,e
        add a,a                 ; номер*8 = старший байт смещения слота (по 2К)
        add a,a
        add a,a
        add a,#80               ; банк - в окне 2
        ld h,a
        ld l,0
        ld de,#C000             ; шрифт - в окне 3
        ld bc,FONT_SIZE
        ldir
        RESTPAGE3
        RESTPAGE2
        ret

Apply_UI_Glyphs
        SETPAGE2 PAGE_FONTS
        SETPAGE3 PAGE_FONT
        ld hl,UI_Glyph_Codes
.l      ld a,(hl)
        cp #FF
        jr z,.done
        inc hl
        push hl
        add a,a                 ; код*8, коды меньше 32 - влезает в байт
        add a,a
        add a,a
        ld l,a
        ld e,a
        ld h,#80+UI_GLYPH_SLOT*FONT_SIZE/256
        ld d,#C0
        ld bc,8
        ldir
        pop hl
        jr .l
.done   RESTPAGE3
        RESTPAGE2
        ret

; Какие коды берутся из значков (остальное - из шрифта). Кнопка - код и код+1.
UI_Glyph_Codes
        db GLYPH_CHK_OFF, GLYPH_CHK_ON
        db GLYPH_BTN_PLUS,  GLYPH_BTN_PLUS+1
        db GLYPH_BTN_MINUS, GLYPH_BTN_MINUS+1
        db GLYPH_BTN_NEW,   GLYPH_BTN_NEW+1
        db GLYPH_BTN_PLAY,  GLYPH_BTN_PLAY+1
        db GLYPH_BTN_STOP,  GLYPH_BTN_STOP+1
        db GLYPH_BTN_REC,   GLYPH_BTN_REC+1
        db GLYPH_BTN_RES1,  GLYPH_BTN_RES1+1
        db GLYPH_BTN_RES2,  GLYPH_BTN_RES2+1
        db GLYPH_BTN_RES3,  GLYPH_BTN_RES3+1
        db GLYPH_BTN_RES4,  GLYPH_BTN_RES4+1
        db #FF

;--------пуш в порты, 1 байт старший байт порта #xxAF, нект байт данные, конец таблицы #FF
; DMA одна на всех: прерывание (мышь, плеер) тоже её дёргает. Поэтому:
;  - перед записью ждём конца текущей транзакции, чужие регистры не трогаем;
;  - из основной программы пишем порты при DI, чтобы IM1 не влез посередине.
; set_ports      - из основной программы (di ... ei)
; set_ports_int  - из прерывания (там прерывания и так запрещены)
; Окончания своей DMA не ждут. Если надо (будем менять источник) - dma_wait.
; Портят AF, BC, HL.
set_ports
		di
		call set_ports_int
		ei
		ret

set_ports_int
		call dma_wait
		ld c,#AF
.m1		ld b,(hl)
		inc hl
		inc b
		ret z
		outi
		jr .m1

dma_wait	ld bc,DMASTATUS
.w		in a,(c)
		and #80
		jr nz,.w
		ret


    include "srs/mouse.asm"
    include "srs/colors.asm"
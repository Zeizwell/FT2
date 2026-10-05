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
    exx                 ; альтернативные BC',DE',HL' - тоже сохраняем
    push af
    push bc
    push de
    push hl
    call IM1_Handler
    pop hl
    pop de
    pop bc
    pop af
    exx
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

; Порядок в кадре фиксированный: музыка -> мышь -> вывод. Прерывание ничего не
; решает само - делает по переменным, которые меняет основной цикл.
IM1_Handler

    ; 1. музыка - первой, в одной и той же точке кадра: страница плеера - в окно 1
    ld a,(SV_PLAYER)
    or a
    jr z,.nomusic
    SETPAGE1 a
    call PLAYER_TICK
    RESTPAGE1
.nomusic
    ; 2. мышь
    call Read_Mouse
    ; 3. клавиатура PS/2 и события кнопок мыши (srs/input.asm)
    call Read_Input
    ; 4. вывод активного редактора (паттерн и т.п.)
    ld hl,(SV_FRAME_HOOK)
    ld a,h
    or l
    ret z
    jp (hl)

    

Core_Start
        ld bc,CACHECONF         ; кэш окон 0,1 - без него 14 МГц ждёт DRAM на каждом чтении
        ld a,CACHE_WIN
        out (c),a

        ; системные переменные для плагинов (sdk/plugin.asm) - сначала все в 0:
        ; в ОЗУ при старте мусор, а IM1 начинает работать уже в Init_Mouse_Sprite
        ; (set_ports делает EI) и смотрит SV_PLAYER, SV_FRAME_HOOK...
        ld hl,SV_PAGES+4            ; тени страниц (SV_PAGES) уже заполнил старт - их не трогаем
        ld de,SV_PAGES+5
        ld bc,THEME_ATTR-SV_PAGES-5
        ld (hl),0
        ldir
        ld a,FT2_API_VERSION
        ld (SV_API_VERSION),a
        ld a,PAGE_TEXT
        ld (SV_DRAW_PAGE),a
        ld hl,0                 ; сборки экрана пока нет
        ld (SV_FRAME_HOOK),hl
        ld hl,Theme_Default
        ld de,THEME_ATTR
        ld bc,Theme_Default_end-Theme_Default
        ldir

        im 1
        ld hl,100
        ld de,100
        call Init_Mouse_Sprite
        call Input_Init         ; лог клавиатуры PS/2, автоповтор, счётчики мыши

        ld a,PAGE_SONG1         ; плеер: трек 1, подготовка, дальше его зовёт IM1
        ld (SV_PLAY_SONG),a
        SETPAGE1 PAGE_PLAYER
        call PLAYER_INIT
        RESTPAGE1
        ld a,PAGE_PLAYER
        ld (SV_PLAYER),a

        call Clear_Screen       ; экран - пробелы цветом фона (макета больше нет)

        xor a                   ; шрифт 0 и значки поверх
        call Set_Font
        call Apply_UI_Glyphs

        ld a,PAGE_TOOL_PATVIEW  ; первым - вид паттерна
        ld (SV_TOOL),a

;-------- Экраны (вкладки): тулза работает, пока не поставит в SV_TOOL другую и не выйдет
Tools_Loop
        ld a,(SV_TOOL)
        call Call_Tool
        jr Tools_Loop

;-------- Вызов тулзы: страница тулзы в окно 1, старт с #4000
; in: A - пейдж тулзы
; Тулза сама SETPAGE2/3 под свои данные и RESTPAGE перед ret.
; После возврата окно 1 восстановлено. Портит A, BC.
Call_Tool
        SETPAGE1 a
        call #4000
        RESTPAGE1
        ret


;-------- Экран PAGE_TEXT целиком: символы - пробелы, атрибуты - фон темы.
; Все 64 строки страницы (видно 36, остальные - шаблоны и запас)
Clear_Screen
        SETPAGE3 PAGE_TEXT
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld h,#C0                    ; строка = H (окно 3)
.l      ld l,0
.s      ld (hl),' '                 ; 0..127 - символы
        set 7,l
        ld (hl),c                   ; 128..255 - атрибуты
        res 7,l
        inc l
        bit 7,l
        jr z,.s
        inc h
        jr nz,.l
        RESTPAGE3
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

; Какие коды берутся из значков (остальное - из шрифта).
; Кнопка - код и код+1 (две половины), у [+]/[-]/Unique/Clone ещё нажатый вид (код+BTN_PRESSED).
UI_Glyph_Codes
        db GLYPH_CHK_OFF, GLYPH_CHK_ON
        db GLYPH_BTN_PLUS,  GLYPH_BTN_PLUS+1
        db GLYPH_BTN_PLUS+BTN_PRESSED,  GLYPH_BTN_PLUS+BTN_PRESSED+1
        db GLYPH_BTN_MINUS, GLYPH_BTN_MINUS+1
        db GLYPH_BTN_MINUS+BTN_PRESSED, GLYPH_BTN_MINUS+BTN_PRESSED+1
        db GLYPH_BTN_UNIQUE, GLYPH_BTN_UNIQUE+1
        db GLYPH_BTN_UNIQUE+BTN_PRESSED, GLYPH_BTN_UNIQUE+BTN_PRESSED+1
        db GLYPH_BTN_PLAY,  GLYPH_BTN_PLAY+1
        db GLYPH_BTN_STOP,  GLYPH_BTN_STOP+1
        db GLYPH_BTN_CLONE, GLYPH_BTN_CLONE+1
        db GLYPH_BTN_CLONE+BTN_PRESSED, GLYPH_BTN_CLONE+BTN_PRESSED+1
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
    include "srs/input.asm"
    include "srs/fields.asm"
    include "srs/text.asm"
    include "srs/song.asm"
    include "srs/transport.asm"
    include "srs/diskcall.asm"
    include "srs/instr.asm"
    include "srs/colors.asm"
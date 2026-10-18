; Core 
    ds #38
    org #0038   ; im1
    di
    push af
    ld a,(Im_Busy)      ; IM1 уже идёт (кто-то внутри разрешил прерывания) - не входим,
    or a                ;   только считаем такие случаи (Im_Reenter)
    jr nz,Im_Again
    inc a
    ld (Im_Busy),a
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
    xor a               ; IM1 кончился
    ld (Im_Busy),a
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
Im_Again
    ld a,(Im_Reenter)
    inc a
    jr z,$+5           ; до 255 и стоп
    ld (Im_Reenter),a
    pop af
    ei
    ret

    org #0100   ;пропускаем нми и др парашу

Im_Busy         db 0    ; 1 - IM1 работает (ставит и снимает сам обработчик)
Im_Reenter      db 0    ; сколько раз IM1 пришёл, пока шёл прошлый (должно быть 0; видно в Setup)

; Порядок в кадре фиксированный: музыка -> мышь -> вывод. Прерывание ничего не
; решает само - делает по переменным, которые меняет основной цикл.
IM1_Handler

    ; 1. музыка - первой, в одной и той же точке кадра: страницы плеера - в окна 1 и 2
    ld a,(SV_PLAYER)
    or a
    jr z,.nomusic
    ld a,(Pl_Band)              ; полоса времени: плеер - голубым
    or a
    ld hl,Pb_On
    call nz,set_ports_int
    ld a,(SV_PLAYER)
    SETPAGE1 a
    SETPAGE2 PAGE_PLAYER2
    call PLAYER_TICK
    RESTPAGE2
    RESTPAGE1
    ld a,(Pl_Band)              ;   дальше - фон темы
    or a
    call nz,Pb_Back
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
        xor a                   ; тема 0 из набора тем - в CRAM (выбранную в INI ставит
        call Set_Palette_Di     ;   Setup, OPT_LOAD). Прерывания ещё выкл - без EI
        call Spr_Pal_Set        ; палитра спрайтов интерфейса (своя, не от темы)

        im 1
        ld hl,100
        ld de,100
        call Init_Mouse_Sprite
        call Input_Init         ; лог клавиатуры PS/2, автоповтор, счётчики мыши
;       call Splash             ; заставка выкл (была грубой; вернуть - и include ниже, и блоки в spg.ini)

        ld a,1                  ; оба трека - пустые, редактируем трек 1
        call Song_Select
        call Song_New
        xor a
        call Song_Select
        call Song_New
        ld a,PAGE_SONG1         ; плеер: трек 1, подготовка, дальше его зовёт IM1
        ld (SV_PLAY_SONG),a
        SETPAGE1 PAGE_PLAYER
        SETPAGE2 PAGE_PLAYER2
        call PLAYER_INIT
        RESTPAGE2
        RESTPAGE1
        ld a,PAGE_PLAYER
        ld (SV_PLAYER),a

        call Clear_Screen       ; экран - пробелы цветом фона (макета больше нет)
        call Font2_Init         ; шрифт - и для второго экрана (двойной буфер тулз)
                                ; шрифт (со значками) уже в PAGE_FONT - его грузит spg
        ld a,OPT_LOAD           ; настройки из /FT2/FT2.INI (нет карты или файла - как есть)
        ld (SV_TOOL_ARG),a
        ld a,PAGE_TOOL_OPT
        call Call_Tool

        ld a,PAGE_TOOL_PATVIEW  ; первым - вид паттерна: рисует шапку и кнопки транспорта; INI load= -
        ld (SV_TOOL),a          ;   он сразу уходит в диск (загрузит и вернётся в паттерн)

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


    include "srs/screen.asm"       ; двойной буфер экрана тулз
    include "srs/sprites.asm"      ; спрайты интерфейса: палитра и карта
    include "srs/textin.asm"
    include "srs/spin.asm"
    include "srs/button.asm"       ; кнопка (как в Turbo Vision)         ; поле числа nn[+][-] (как в MilkyTracker)       ; строка ввода текста (Song / By, имена, файл)
    include "srs/mouse.asm"
    include "srs/input.asm"
    include "srs/fields.asm"
    include "srs/text.asm"
    include "srs/window.asm"       ; окна поверх экрана (About, меню)
;   include "srs/splash.asm"       ; заставка при старте - выкл
    include "srs/song.asm"
    include "srs/transport.asm"
    include "srs/toolscr.asm"
    include "srs/palettes.asm"
    include "srs/diskcall.asm"
    include "srs/instr.asm"
    include "srs/colors.asm"
;-------- PS/2 код -> символ (имена файлов, инструментов; 0 - не символ), раскладка US. Сразу за ней
; (Key_Chars+#80) - то же с Shift: заглавные, !@#$%^&*()_+ и т.д. (Ti_Key берёт по флагу Shift).
; Знаки - числами (ASCII). В конце коре: выравнивание на 256
        ALIGN 256
Key_Chars
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,96,0   ; #00..#0F
        db 0,0,0,0,0,113,49,0,0,0,122,115,97,119,50,0   ; #10..#1F
        db 0,99,120,100,101,52,51,0,0,32,118,102,116,114,53,0   ; #20..#2F
        db 0,110,98,104,103,121,54,0,0,0,109,106,117,55,56,0   ; #30..#3F
        db 0,44,107,105,111,48,57,0,0,46,47,108,59,112,45,0   ; #40..#4F
        db 0,0,39,0,91,61,0,0,0,0,0,93,0,92,0,0   ; #50..#5F
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0   ; #60..#6F
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0   ; #70..#7F
    ASSERT $-Key_Chars == #80
Key_Chars_Sh
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,126,0   ; #00..#0F
        db 0,0,0,0,0,81,33,0,0,0,90,83,65,87,64,0   ; #10..#1F
        db 0,67,88,68,69,36,35,0,0,32,86,70,84,82,37,0   ; #20..#2F
        db 0,78,66,72,71,89,94,0,0,0,77,74,85,38,42,0   ; #30..#3F
        db 0,60,75,73,79,41,40,0,0,62,63,76,58,80,95,0   ; #40..#4F
        db 0,0,34,0,123,43,0,0,0,0,0,125,0,124,0,0   ; #50..#5F
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0   ; #60..#6F
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0   ; #70..#7F
    ASSERT $-Key_Chars == #100

;-------- Проба ноты (редактор инструментов): строка одного чипа в формате паттерна.
; Тулза заполняет и даёт плееру PC_PREVIEW; плеер читает её из окна 0. Лежит в той же
; 256-странице, что и Key_Chars (каналы считаются по L без переноса)
Prv_Row
        ds CHIP_SIZE
    ASSERT high Prv_Row == high (Prv_Row+CHIP_SIZE-1)

; =========================================================================
; ПОЛОСА ВРЕМЕНИ ПЛЕЕРА (Ctrl+T в виде паттерна ставит Pl_Band): на время тика плеера цвет #0
; палитры - голубой, после - фон темы (Pal_Bg). Высота голубого = время плеера
; =========================================================================
Pl_Band         db 0
PB_W            equ PALET_NUM*16    ; слово CRAM
Pb_Back
        ld hl,(Pal_Bg)              ; фон темы - в выровненное слово (DMA берёт слова)
        ld (Pb_Bg),hl
        ld hl,Pb_Off
        jp set_ports_int
Pb_On   db high DMASADDRL,low Pb_Cyan, high DMASADDRH,high Pb_Cyan, high DMASADDRX,PAGE_CORE0
        db high DMADADDRL,(PB_W&127)*2, high DMADADDRH,PB_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
Pb_Off  db high DMASADDRL,low Pb_Bg, high DMASADDRH,high Pb_Bg, high DMASADDRX,PAGE_CORE0
        db high DMADADDRL,(PB_W&127)*2, high DMADADDRH,PB_W>>7, high DMADADDRX,0
        db high DMALEN,0, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF
        ALIGN 2                     ; цвет: младший gggBBbbb, старший 0RRrrrGG
Pb_Cyan         db %00011000, %00000011
Pb_Bg           dw 0

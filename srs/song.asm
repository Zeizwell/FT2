; =========================================================================
; ТРЕК: новый трек в его странице (часть коре: нужен виду паттерна и импорту)
; =========================================================================
NEW_SONG_SPEED  equ 3               ; новый трек: скорость
NEW_SONG_STEP   equ 4               ;   шаг курсора при вводе
NEW_SONG_FORMAT equ 1
NEW_SONG_DEVICE equ 0               ;   тип чипа: AY (чипов - CHIPS_MAX, 6 каналов)

;-------- Новый трек: заголовок страницы текущего трека (SV_SONG_PAGE) - нули, подпись, формат,
; чипы, скорость, шаг, страница инструментов; FX, их имена и таблицы - пустые. Ордер и каталог пишет тот, кто зовёт
; (вид паттерна - Song_Sync). Шаг в переменную вида кладёт Head_Load
Song_Clear
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,#8000+SONG_HDR        ; заголовок - нули
        ld de,#8000+SONG_HDR+1
        ld bc,255
        ld (hl),0
        ldir
        ld hl,Txt_Sign
        ld de,#8000+SH_SIGN
        ld bc,4
        ldir
        ld a,NEW_SONG_FORMAT
        ld (#8000+SH_FORMAT),a
        ld a,CHIPS_MAX
        ld (#8000+SH_CHIPS),a
        ld a,NEW_SONG_SPEED
        ld (#8000+SH_SPEED),a
        ld a,NEW_SONG_DEVICE
        ld (#8000+SH_DEVICE),a
        ld a,NEW_SONG_STEP
        ld (#8000+SH_STEP),a
        ld a,(Trk_Ins)
        ld (#8000+SH_INS_PAGE),a
        ld hl,#8000+SONG_FX_NAMES   ; имена FX - пустые
        ld de,#8000+SONG_FX_NAMES+1
        ld bc,FXS_MAX*16-1
        ld (hl),0
        ldir
        RESTPAGE2
        ld a,(Trk_Fx)               ; FX - нули (и при импорте: в PT3 / PT2 / FTC их нет,
        SETPAGE2 a                  ;   прошлые не должны остаться)
        ld hl,#8000
        ld de,#8001
        ld bc,#3FFF
        ld (hl),0
        ldir
        RESTPAGE2
        jp Fx_New_Tabs              ; таблицы FX - пресет, заголовки FX - по умолчанию
Txt_Sign        db "FT2S"

;-------- Огибающая трека: 0 FT, 1 PT (SH_ENVMODE). Одна на всех: шапка переключает (и пишет
; в трек), плеер берёт каждый тик. Из трека - Head_Load и старт сонга в плеере
Song_EnvMode    db 0

;-------- Стерео трека (SH_STEREO): 0..4 - ABC ACB BAC BCA CAB (как в VT) - какой канал на какой выход чипа.
; Одна на всех: шапка переключает (и пишет в трек), плеер переставляет каналы при выводе
Song_Stereo     db 0

;-------- Свободная память - постоянная (FREE_PAGES, srs/mem_defs.asm): "Free: NN pages"
Txt_Free        db "Free: ",FREE_PAGES/10+"0",FREE_PAGES%10+"0"," pages",0
    ASSERT FREE_PAGES < 100


;-------- Текущий трек A (0 / 1) - его страницы. Распределение жёсткое (mem_defs.asm):
; трек n - страница PAGE_SONG1+n, паттерны - с PAGE_POOL+n*PAGES_PER_SONG,
; за ними страница инструментов и орнаментов (и FX). Портит AF, B
Trk_Pat         db PAGE_POOL        ; паттерн k текущего трека - страница Trk_Pat+k
Trk_Ins         db PAGE_INS1        ; его инструменты и орнаменты
Trk_Fx          db PAGE_INS1+1      ; его FX и таблицы шагов (sdk: FX_*, TAB_*)
Trk_FxT         db PAGE_INS1+2      ; его таблицы FX и заголовки FX (новый формат: FXT_*, FXH_*)
    ASSERT PAGE_SONG2 == PAGE_SONG1+1
    ASSERT PAGE_INS1 == PAGE_POOL+PATTERNS_MAX
    ASSERT PAGES_PER_SONG == PATTERNS_MAX+3   ; паттерны, инструменты, строки FX, таблицы FX
Song_Select
        ld (SV_SONG_NUM),a
        ld b,a
        add a,PAGE_SONG1
        ld (SV_SONG_PAGE),a
        ld a,b
        or a
        ld a,PAGE_POOL
        jr z,$+4
        ld a,PAGE_POOL+PAGES_PER_SONG
        ld (Trk_Pat),a
        add a,PATTERNS_MAX
        ld (Trk_Ins),a
        inc a
        ld (Trk_Fx),a
        inc a
        ld (Trk_FxT),a
        ret

;-------- A - номер паттерна -> A - его страница (текущий трек). Портит только флаги
Pat_Page
        push hl
        ld hl,Trk_Pat
        add a,(hl)
        pop hl
        ret

;-------- Пустой текущий трек: заголовок (Song_Clear), одна позиция - паттерн 0 на 64 роу
; (данные - нули, текст строит вид паттерна), инструменты и орнаменты - по умолчанию
Song_New
        call Song_Clear
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,#8000+ORDER_LIST      ; ордер и каталоги - нули: позиция 0 - паттерн 0
        ld de,#8000+ORDER_LIST+1
        ld bc,SONG_CAT_END-ORDER_LIST-1
        ld (hl),0
        ldir
        ld a,(Trk_Pat)              ; паттерн 0: страница, 64 роу
        ld (#8000+PAT_CATALOG+PC_PAGE),a
        ld a,PAT_ROWS_MAX
        ld (#8000+PAT_CATALOG+PC_LEN),a
        RESTPAGE2
        ld a,(Trk_Pat)              ; страница паттерна 0 - нули
        SETPAGE2 a
        ld hl,#8000
        ld de,#8001
        ld bc,#3FFF
        ld (hl),0
        ldir
        RESTPAGE2
        ld a,(Trk_Ins)
        jp Ins_Clear

;-------- Таблицы и заголовки FX нового трека (страница Trk_FxT): всё - нули, таблицы 0..5 -
; пресет (Fx_Presets), у каждого FX форма свипа - треугольник (FXT_TRI)
Fx_New_Tabs
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,#8000
        ld de,#8001
        ld bc,#3FFF
        ld (hl),0
        ldir
        ld hl,Fx_Presets
        ld de,#8000
        ld bc,FXT_PRESETS*FXT_SIZE
        ldir
        ld hl,#8000+FXH_BASE+FXH_SWSHAPE
        ld de,FXH_SIZE
        ld b,FXS_MAX
.h      ld (hl),FXT_TRI
        add hl,de
        djnz .h
        RESTPAGE2
        ret

;-------- Пресет таблиц FX (doc/fx-row.md): SID - громкости 0..15, формы свипа - точки 0..255
Fx_Presets
        db 15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0                       ; 0 меандр SID (длина 2 - F 0)
        db 0,32,64,96,128,160,192,224,255,224,192,160,128,96,64,32 ; 1 треугольник
        db 128,177,218,245,255,245,218,177,128,79,38,11,1,11,38,79 ; 2 синус
        db 0,17,34,51,68,85,102,119,136,153,170,187,204,221,238,255 ; 3 пила вверх
        db 255,238,221,204,187,170,153,136,119,102,85,68,51,34,17,0 ; 4 пила вниз
        db 255,255,255,255,255,255,255,255,0,0,0,0,0,0,0,0         ; 5 меандр
    ASSERT $-Fx_Presets == FXT_PRESETS*FXT_SIZE

;-------- Буфер каталога паттернов для тулзы диска (загрузка / сохранение): в коре, страница диска полна
Disk_Cat        ds PATTERNS_MAX*PC_SIZE

;-------- Таблица FX, правленная в редакторе (#FF - нет): плеер шлёт её в карту (Fx_TabEdit) и сбрасывает
Fx_TabDirty     db #FF

;-------- FX, строки которого правили в редакторе (номер 1..32, #FF - нет): плеер шлёт каналам с этим FX
; текущую строку заново (Fx_RowEdit) - правка слышна сразу, а не с новой нотой
Fx_RowDirty     db #FF

;-------- Заглушенные каналы (клик по имени канала в виде паттерна): бит 0..5 - канал A..F.
; Плеер пишет им громкость 0 (Mu_Apply), FX у карты - выкл
Ch_Mute         db 0
;-------- Железо (плеер определяет при старте, Pl_Init; шапка показывает): 1 - есть
Hw_Fx           db 0                ; карта AY FX (Trinity) - хоть на одном чипе
Hw_Ts           db 0                ; TurboSound - второй AY

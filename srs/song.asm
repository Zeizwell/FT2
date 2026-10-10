; =========================================================================
; ТРЕК: новый трек в его странице (часть коре: нужен виду паттерна и импорту)
; =========================================================================
NEW_SONG_SPEED  equ 3               ; новый трек: скорость
NEW_SONG_STEP   equ 4               ;   шаг курсора при вводе
NEW_SONG_FORMAT equ 1
NEW_SONG_DEVICE equ 0               ;   тип чипа: AY (чипов - CHIPS_MAX, 6 каналов)

;-------- Новый трек: заголовок страницы текущего трека (SV_SONG_PAGE) - нули, подпись, формат,
; чипы, скорость, шаг, страница инструментов. Ордер и каталог пишет тот, кто зовёт
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
        RESTPAGE2
        ret
Txt_Sign        db "FT2S"

;-------- Свободная память - постоянная (FREE_PAGES, srs/mem_defs.asm): "Free: NN pages"
Txt_Free        db "Free: ",FREE_PAGES/10+"0",FREE_PAGES%10+"0"," pages",0
    ASSERT FREE_PAGES < 100


;-------- Текущий трек A (0 / 1) - его страницы. Распределение жёсткое (mem_defs.asm):
; трек n - страница PAGE_SONG1+n, паттерны - с PAGE_POOL+n*PAGES_PER_SONG,
; за ними страница инструментов и орнаментов (и FX). Портит AF, B
Trk_Pat         db PAGE_POOL        ; паттерн k текущего трека - страница Trk_Pat+k
Trk_Ins         db PAGE_INS1        ; его инструменты и орнаменты
    ASSERT PAGE_SONG2 == PAGE_SONG1+1
    ASSERT PAGE_INS1 == PAGE_POOL+PATTERNS_MAX
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

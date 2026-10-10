; =========================================================================
; ТРЕК: новый трек в его странице (часть коре: нужен виду паттерна и импорту)
; =========================================================================
NEW_SONG_SPEED  equ 3               ; новый трек: скорость
NEW_SONG_STEP   equ 4               ;   шаг курсора при вводе
NEW_SONG_FORMAT equ 1
NEW_SONG_DEVICE equ 0               ;   тип чипа: AY (чипов - CHIPS_MAX, 6 каналов)

;-------- Новый трек: заголовок страницы трека PAGE_SONG1 - нули, подпись, формат,
; чипы, скорость, шаг, страница инструментов. Ордер и каталог пишет тот, кто зовёт
; (вид паттерна - Song_Sync). Шаг в переменную вида кладёт Head_Load
Song_Clear
        ld a,PAGE_SONG1
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
        ld a,PAGE_INS1
        ld (#8000+SH_INS_PAGE),a
        RESTPAGE2
        ret
Txt_Sign        db "FT2S"

;-------- Свободная память - постоянная (FREE_PAGES, srs/mem_defs.asm): "Free: NN pages"
Txt_Free        db "Free: ",FREE_PAGES/10+"0",FREE_PAGES%10+"0"," pages",0
    ASSERT FREE_PAGES < 100


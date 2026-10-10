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

;-------- Свободная память: страниц пула, не занятых треком (паттерны из каталога трека,
; страница инструментов). Выход: A - сколько. Портит BC, HL
POOL_PAGES      equ PAGE_POOL_END-PAGE_POOL
Mem_Free_N      db 0
Mem_Free
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld hl,#8000+PAT_CATALOG
        ld b,PATTERNS_MAX
        ld c,POOL_PAGES-1           ; минус страница инструментов
.l      ld a,(hl)                   ; PC_PAGE: 0 - паттерна нет
        or a
        jr z,$+3
        dec c
        inc hl
        inc hl
        djnz .l
        ld a,c
        ld (Mem_Free_N),a           ; (RESTPAGE портит A)
        RESTPAGE2
        ld a,(Mem_Free_N)
        ret
    ASSERT PC_SIZE == 2 && PC_PAGE == 0
Txt_Free        db "Free:",0                    ; "Free: NNN/143 pages" (коре: видят все тулзы)
Txt_Free2       db "/",POOL_PAGES/100+"0",(POOL_PAGES/10)%10+"0",POOL_PAGES%10+"0"," pages",0

;-------- A (0..255) - три десятичные цифры в DE (ведущие нули - пробелы). Цвет C
Put_Dec3
        ld b,'0'-1                  ; сотни
.h      inc b
        sub 100
        jr nc,.h
        add a,100
        push af
        ld a,b
        cp '0'
        jr nz,$+4
        ld a,' '
        ld h,a                      ; H - была ли цифра (не пробел); PutCh портит A
        call PutCh
        pop af
        ld b,'0'-1                  ; десятки
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        cp '0'
        jr nz,.d
        ld a,h
        cp ' '
        ld a,'0'
        jr nz,.d
        ld a,' '
.d      call PutCh
        pop af
        jp PutCh

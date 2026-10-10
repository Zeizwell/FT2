; =========================================================================
; ЗАСТАВКА при старте (часть коре): 256 цветов, 360x288. Экран - страницы PAGE_SPLASH..+8
; (строка 512 байт: 360 точек + пусто, 32 строки на страницу - так берёт ПЛИС,
; video_mode.v). В SPG - только полоса с надписью (страницы +3..+5, строки 96..191),
; остальные страницы - фон, заливаем. Палитра - 64 цвета (64..127 в CRAM) в PAGE_SPLASH_PAL.
; Делает srs/splash/make_splash.ps1. Цвета 64..127 - не текст и не спрайты (палитра 13).
; До клавиши, клика или 5 секунд, потом - текстовый режим как был. Страницы
; заставки - из буферов редактора (#20..#26): после неё буфер обмена - пустой.
; =========================================================================
SPLASH_TIME     equ 250             ; кадров (5 сек)
SPLASH_BG       equ 64+1            ; фон - цвет (0,0,1): тёмно-синий

Splash
        ld hl,Sp_Pal                ; палитра: 64 слова -> CRAM 64..127 (DMA)
        call set_ports
        call dma_wait               ; палитру забрали - её страницу можно заливать
        ld a,PAGE_SPLASH            ; фон: страницы без надписи
        call .fill
        ld a,PAGE_SPLASH+1
        call .fill
        ld a,PAGE_SPLASH+2
        call .fill
        ld a,PAGE_SPLASH+6
        call .fill
        ld a,PAGE_SPLASH+7
        call .fill
        ld a,PAGE_SPLASH+8
        call .fill
        ld bc,VPAGE                 ; картинка
        ld a,PAGE_SPLASH
        out (c),a
        ld bc,VCONFIG
        ld a,VID_360X288|VID_256C
        out (c),a
        ld a,MB_LEFT                ; старые события мыши - мимо
        ld hl,Sp_Seen
        call Mouse_Btn
        ld b,SPLASH_TIME
.w      halt
        push bc
        call Key_Get                ; клавиша - дальше
        pop bc
        jr nz,.out
        push bc
        ld a,MB_LEFT                ; клик - дальше
        ld hl,Sp_Seen
        call Mouse_Btn
        pop bc
        and 1<<ME_PRESS
        jr nz,.out
        djnz .w
.out    ld bc,VCONFIG               ; текстовый режим - как Init_Video_90x36
        ld a,VID_360X288|VID_TEXT
        out (c),a
        ld bc,VPAGE
        ld a,PAGE_TEXT
        out (c),a
        ld a,PAGE_EDBUF             ; в буфере обмена была картинка - он пустой
        SETPAGE3 a
        xor a
        ld (patview.CLIP_HDR),a
        ld (patview.CLIP_HDR+1),a
        RESTPAGE3
        ret
; Страница A - цветом фона (окно 3)
.fill   SETPAGE3 a
        ld hl,#C000
        ld de,#C001
        ld bc,#3FFF
        ld (hl),SPLASH_BG
        ldir
        RESTPAGE3
        ret
Sp_Seen         ds 4

Sp_Pal  db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,PAGE_SPLASH_PAL
        db high DMADADDRL,(64&127)*2, high DMADADDRH,64>>7, high DMADADDRX,0
        db high DMALEN,64-1, high DMANUM,0, high DMACTR,DMA_RAM_CRAM, #FF

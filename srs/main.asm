    DEVICE ZXSPECTRUM128

    include     "includes/tsconfig.asm"
    include     "sdk/plugin.asm"    ; общий с плагинами формат, адреса, макросы страниц
    include     "mem_defs.asm"      ; макросы страниц должны быть объявлены до использования

    org #8000
    
Start:
    di
    
    ld      sp,#7FFF
    call    Init_Video_90x36

        

     ;------- Очистка SAT области спрайтов
    ld bc, FMADDR           ; Наш порт $15AF
    ld a, #10               ; Открываем SAT спрайтов на запись в окне #0000..#01FF
    out (c), a              ; ПЛИС перехватывает сигналы /WR
    push bc
    xor a
    LD HL,#0200
    ld b,2
  
.ll3
    ld (hl),a
    inc l
    jr nz, .ll3
    inc h
    djnz .ll3
    pop bc
    out (c),a
;-----------------------------------------------

    ; Переключение окна #0000..#3FFF на ОЗУ и разрешение записи в него
    ld bc, MEMCONFIG        ; Системный регистр $21AF
    ld a, MEM_W0RAM | MEM_W0WE | MEM_W0MAP_N ; Маска $08 | $02 = $0A
    out (c), a              ; Физическое отключение ПЗУ в Слоте 0
    
    ld bc, PAGE0
    ld a,PAGE_CORE0
    out (c),a               ; коре в окне 0 - теперь доступна CUR_PAGES

    ; заполняем тени страниц (окно 2 - мы тут исполняемся, страница та же)
    MAPPAGE 0,PAGE_CORE0
    MAPPAGE 1,PAGE_CORE1
    MAPPAGE 2,PAGE_CORE2
    MAPPAGE 3,PAGE_CORE3

    ld sp,STACK_TOP         ; стек в коре, до этого жили на #7FFF

    ld bc, INTMASK
    ld a, %00000001         ; Бит 0 = 1 (Разрешить Frame INT от видеоконтроллера)
    out (c), a

;-----------------------------------------------

    
    jp      Core_Start
  
    

    include     "video.asm"
    SAVEBIN     "srs/ft2.bin",Start,$-Start
    
    org #0000
              ; устанавливаем начало компиляции для коре
core_start
    include     "core.asm"
core_end
    ASSERT core_end <= SYS_API      ; коре налезло на API / системные переменные / стек
    ;ENT             ; закрываем disp
    SAVEBIN     "srs/core.bin",core_start,core_end-core_start
    display     "core size",/d,core_end-core_start," bytes"


    ; --- тулзы: каждая со своим org #4000 и своим файлом, грузится spg в свою страницу
    org #4000
tool_patview
    include     "srs/patview.asm"
tool_patview_end
    ASSERT tool_patview_end <= #8000
    SAVEBIN     "srs/patview.bin",tool_patview,tool_patview_end-tool_patview
    display     "patview size",/d,tool_patview_end-tool_patview," bytes"

    ; --- тулза диска: каталог, загрузка и сохранение (страница PAGE_TOOL_DISK)
    org #4000
tool_disk
    include     "srs/diskview.asm"
tool_disk_end
    ASSERT tool_disk_end <= #8000
    SAVEBIN     "srs/diskview.bin",tool_disk,tool_disk_end-tool_disk
    display     "diskview size",/d,tool_disk_end-tool_disk," bytes"

    ; --- плеер (страница PAGE_PLAYER, окно 1 из IM1)
    include     "srs/player.asm"
    SAVEBIN     "srs/player.bin",player_start,player_end-player_start
    display     "player size",/d,player_end-player_start," bytes"

    ; --- диск: переходник к FAT32 (страница PAGE_DISK_APP, работает в окне 2)
    include     "srs/disk.asm"
    SAVEBIN     "srs/disk.bin",disk_start,disk_end-disk_start
    display     "disk adapter size",/d,disk_end-disk_start," bytes"

    ; --- рабочая страница FAT32 (PAGE_FAT_WORK): нули + порт SD-ZC на #3900.
    ;     Сам драйвер (PAGE_FAT_CODE) собирается отдельно: build.bat, drivers/fat32
    org #C000
fatwork
    ds          FAT_PORT_TABLE,0
    incbin      "drivers/fat32/build/port_sdzc.bin"
    ds          fatwork+#4000-$,0
fatwork_end
    SAVEBIN     "srs/fatwork.bin",fatwork,fatwork_end-fatwork

    ; --- банк шрифтов (страница PAGE_FONTS): шрифты по слотам, в UI_GLYPH_SLOT - значки
    org #C000
fontbank
    incbin      "srs/fonts/866_code.fnt"        ; шрифт 0
    ds          fontbank+UI_GLYPH_SLOT*FONT_SIZE-$,0
    include     "srs/fonts/ui_glyphs.asm"
fontbank_end
    SAVEBIN     "srs/fonts.bin",fontbank,fontbank_end-fontbank

    LABELSLIST  "tools/unreal/ft.l",3
    bplist      "tools/unreal/bpx.ini" unreal

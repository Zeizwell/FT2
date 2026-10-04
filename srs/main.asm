    DEVICE ZXSPECTRUM128

    include     "includes/tsconfig.asm"
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
    ASSERT core_end <= STACK_TOP-STACK_SIZE     ; коре налезло на стек
    ;ENT             ; закрываем disp
    SAVEBIN     "srs/core.bin",core_start,core_end-core_start
    display     "core size",/d,core_end-core_start," bytes"


    org #c000
maket

    include     "srs/maket.asm"
    org #f000
maket_end
    SAVEBIN     "srs/maket.bin",maket,maket_end-maket
    display     "maket size",/d,maket_end-maket," bytes"

    LABELSLIST  "tools/unreal/ft.l",3
    bplist      "tools/unreal/bpx.ini" unreal

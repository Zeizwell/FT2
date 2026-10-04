
;-----------------------------------
;       Иницилизация мышки
;       в HL - X координата мышки в 9 бит формате
;       в DE - Y координата мышки в 9 бит формате    
Init_Mouse_Sprite
        ld (CUR_MX+1),HL        ;+1 потому что в целую часть
        ex de,hl
        ld (CUR_MY+1),HL
        ld bc,PAGE3         ; копируем в page_sprite спрайт
        ld a,PAGE_SPRITE    ; Спрайты 
        out (c),a
        ld bc,#FBDF
        in a,(c)
        ld (MOUSE_dX),a
        ld bc,#FFDF
        in a,(c)
        ld (MOUSE_dY),a

        ld hl,MOUSE_SPRITE_DATA
        ld de,#C000
        ld b,#10
.ll2    push de
        ld c,8
.ll1
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        dec c
        jr nz,.ll1
        pop de
        inc d
        djnz .ll2
        call Mouse_Scale

        ld hl, Sprite_init_table
        call set_ports
        ld hl, Cursor_dma_table
        jp set_ports




Print_D push af
        RRCA
        RRCA
        RRCA
        RRCA
        call .print_dig
        pop af
.print_dig
        and #0f
        cp 10
        jr c,.is_digit
        add a,7
.is_digit
        add a, "0"
        ld(hl),a
        inc hl
        ret






Sprite_init_table
                db high MEMCONFIG, MEM_W0RAM | MEM_W0WE | MEM_W0MAP_N ;Гарантируем, что ОЗУ Слота 0 открыто на запись (MEMCONFIG = $21AF)
                db high TSCONFIG, TSU_SEN                              ;Включаем отображение слоя спрайтов
                db high SGPAGE, PAGE_SPRITE
                db #FF                                                ;конец таблы
;------mouse sprite settings 

MOUSE_Y_MASK    equ     %00100010 ; Флаги Y: ACT=1, размер 16 пикселей (#32)
MOUSE_X_MASK    equ     %00000010 ; Флаги X: размер 16 пикселей (#02)

                align 2
MOUSE_SAT_BUFFER
MOUSE_Y_POS     db #20          ; Позиция по Y (базовый старт по центру)
                db MOUSE_Y_MASK ; Флаги Y: ACT=1, размер 16 пикселей (#32)      0 бит - 8бит координаты Y
MOUSE_X_POS     db #20          ; Позиция по X (базовый старт по центру)
                db MOUSE_X_MASK    ; Флаги X: размер 16 пикселей (#02)          0 бит - 8бит координаты X
                db 0            ; Номер тайла на карте графики 
                db #D0           ; Старшая тетрада — палитра 0, младшая — старший бит тайла D0- 13 палитра текст режима
              
              
MOUSE_SAT_END  
;-------------------------------------
Cursor_dma_table
                defb    #1a, low MOUSE_SAT_BUFFER  ; Адрес источника в ОЗУ (младший байт)
                defb    #1b, high MOUSE_SAT_BUFFER ; Адрес источника в ОЗУ (старший байт)
                defb    #1c, PAGE_CORE0            ; Источник сидит в нашей базовой RAM (обычно 0)
                defb    #1d, 0
                defb    #1e, 2                     ; НАПРАВЛЯЕМ ТРАНЗАКЦИЮ СТРОГО В SFILE (SAT память)
                defb    #1f, 0
                defb    #26, (MOUSE_SAT_END - MOUSE_SAT_BUFFER) / 2-1 ; Длина транзакции (3 слова)
                defb    #28, 0
                defb    #27, #85                   ; Запуск аппаратного DMA_RAM_SFILE!
              
                db      #ff                        ; Маркер конца таблицы для set_ports



; =========================================================================
; ЧЕСТНЫЙ ОПРОС ПОРТОВ (Вызывать из IM1_Handler)
; =========================================================================
Read_Mouse:

        call MOUSE
        
        ; РАСКИДЫВАЕМ ГОТОВЫЕ ПИКСЕЛИ В БУФЕР DMA СПРАЙТА
        
        ld a, (CUR_MY+1)
        ld (MOUSE_Y_POS), a     ; 
        ld a,(CUR_MY+2)
        and #01
        or MOUSE_Y_MASK
        ld (MOUSE_Y_POS+1), a
     
        ld a, (CUR_MX+1)          ; 
        ld (MOUSE_X_POS), a     ; Байт 2 буфера DMA (младшие 8 бит X)
        ld a,(CUR_MX+2)
        and #01
        or MOUSE_X_MASK
        ld (MOUSE_X_POS+1), a

        ; ВЫБРОС В DMA БЛИТТЕР ПЛИС
        
        ld hl,Cursor_dma_table
        jp set_ports









; =====================================================================
; FULL 16.8-BIT KEMPSTON MOUSE DRIVER (CLEAN & OPTIMIZED) 
; =====================================================================
MOUSE_MAXPIX    equ     200     ; макс пиксель спид
MOUSE_MAXSPEED  equ     63      ; макс дельта из порта, нельзя делать выше 127
MOUSE_MAX_X     equ     359
MOUSE_MAX_Y     equ     287
MOUSE_PORTX     db      0
MOUSE_PORTY     db      0

MOUSE_dX        DB 0            ;тут содержится не приведенная дельта перемещения по оси X
MOUSE_dY        DB 0            ;тут содержится не приведенная дельта перемещения по оси Y
MOUSE_SPEED     DB 4            ;значение от 0 до 1 - 5 это 100%, шаг 26
MOUSE_ACCEL     DB 14            ;кубическая акселерация мышки 0-8  
MOUSE_ACC_TABLE DUP MOUSE_MAXSPEED, X
                DW (X * X * X) / 16   ;x в кубе/128 x=1..MOUSE_MAXSPEED
                EDUP  

CUR_MX          db 0            ;дробная часть 16.8
                DW 100          ; X 
                                ; 24 битная координата
CUR_MY          db 0            ;дробная часть 16.8
                DW 100          ; Y 
                                ; 24 битная координата
MOUSE_BUT       DB 7            ; Кнопки

MOUSE_TABLE     ds      MOUSE_MAXSPEED*2     ;табличка скоростей

;----------------------------------------------------------------------------
; Расчет таблички скорости мышки
Mouse_Scale:

               
                ld de,MOUSE_TABLE
                push de
                ld a,(MOUSE_SPEED)
                add a,5         ;макс значени 9+5=14, ну оставим 1 бит запаса или нет
                ld c,a
                add a,a         ;*2
                add a,c         ;*3
                add a,a         ;*6
                ld h,0
                ld b,h
                ld l,a
                add hl,hl       ;*12
                add hl,bc       ;*13
                
                add hl,hl       ;умножили на 26, 1/10 часть от 256 примерно) т.е. тут 1xСкорость в%, добавив 5 вначале, мы на 5 скорости получим 260=1 или 100%
                ld c,l
                ld b,h          ;в бс наш дробный шаг в пикселях
                ld a,MOUSE_MAXSPEED
.mouse_scale1
                ex de,hl
                ld (hl),e
                inc hl
                ld (hl),d
                inc hl
                ex de,hl
                add hl,bc
                dec a
                jr nz, .mouse_scale1

                ld a,(MOUSE_ACCEL)
                and #1f                 ;макс ассел глушим до #0f хотя и это много, макс 8 лучше
                pop ix 
                                        
                ret z                   ;Акселерации нет
                
                ld b, MOUSE_MAXSPEED           
                ld hl,MOUSE_ACC_TABLE
.mouse_ac5
                push bc
                ld e,(hl)               ;берем из таблицы кубов в DE
                inc hl
                ld d,(hl)
                inc hl

                ex de,hl                ;DE-указатель в таблице кубов
                ld a,(MOUSE_ACCEL)
                ld c,0
.mouse_ac1                
                dec a
                jr z,.mouse_ac2
                add hl, hl              ;умножаем на
                rl c                    ;делаем 24 бита число
                jr nc,.mouse_ac1
                ld c,#ff                ;вылезли за 24 бита - насыщаем, дальше обрежется до MOUSE_MAXPIX

.mouse_ac2      ld a,c                  ;старший байт 24битного результата
                ld (.mouse_ac3+1),a
                ld a,h
                ld l,a
.mouse_ac3      ld h,0                  ;делим на 256

                ld c,(ix)               ;в IX MOUSE_TABLE со скоростью
                inc ix
                ld b,(ix)
                inc ix
                add hl,bc               ;в HL сумма скорости+акселератор
                jr c,.mouse_clamp
                ld a,h
                cp MOUSE_MAXPIX         ;целая часть >= MOUSE_MAXPIX?
                jr c,.mouse_ac4
.mouse_clamp    ld hl,MOUSE_MAXPIX*256  ;ограничиваем макс пиксель спид в кадр
.mouse_ac4
                                
                ld (ix-1),H             ;обновляем MOUSE_TABLE
                ld (ix-2),L
                ex de,hl                ;HL - MOUSE_TABLE
                pop bc
                djnz .mouse_ac5
                ret


MOUSE:
                ; --- 1. Опрос Кнопок ---
                ld bc,#FADF
                in a, (c)
                and %00000111   
                ld (MOUSE_BUT), a

                ; --- 2. Обработка оси X ---
                ld bc, #FBDF     
                in A, (C)
                ld (MOUSE_PORTX),a
                ld hl,MOUSE_dX
                ld c,(hl)
                ld (hl),a
                sub c           ;в А относительный сдвиг
                jr z,.no_X      ;мышка стоит
                bit 7,a         ;проверяем знак
                jr z,.X_pos
                neg
                ld b,0          ;негативное число иначе в б f+
.X_pos          
                
                cp MOUSE_MAXSPEED
                jr c,.mx1
                ld a,MOUSE_MAXSPEED-1   ;последний индекс MOUSE_TABLE

.mx1            add a,a
                ld  e,a
                ld d,0
                ld hl,MOUSE_TABLE
                add hl,de
                ld d,(hl)       ;D дробная часть dX
                inc hl
                ld e,(hl)       ;E целая часть dX
                
                ld hl,(CUR_MX+1);cтарший 16 бит 24бит коорд
                ld a,b
                or a            ;0 значит негативчик
                ld a,(CUR_MX)   ;A дробная часть координаты X

                jr nz,.mx2
                sub d
                ld (CUR_MX),a   ;дробную сохраняем, пох на нее в целом
                ld d,0
                sbc hl,de       ;вычитаем со знаком от дробной
                ex de,hl
                jr nc,.mx3      ;через 0 не перешли
                ld d,h          
                ld e,h
                jr .mx3

.mx2            add a,d
                ld (CUR_MX),a   ;дробную сохраняем, пох на нее в целом
                ld d,0
                adc hl,de       ;HL старшие 16бит координаты
                or a
                ld de,MOUSE_MAX_X
                ex de,hl        ;DE координата X 16h bits
                sbc hl,de
                jr nc,.mx3
                ld de,MOUSE_MAX_X
                
.mx3            ld (CUR_MX+1),de   ;итоговые координаты Х   
.no_X  

                ; --- 2. Обработка оси Y ---
                ld bc, #FFDF     
                in A, (C)
                
                ld (MOUSE_PORTY),a
                ld hl,MOUSE_dY
                ld c,(hl)
                ld (hl),a
                sub c           ;в А относительный сдвиг
                jr z,.no_Y      ;мышка стоит
                neg
                bit 7,a           ;проверяем знак
                jr z,.Y_pos
                neg
                ld b,0          ;негативное число иначе в б f+
.Y_pos          
                
                cp MOUSE_MAXSPEED
                jr c,.mx4
                ld a,MOUSE_MAXSPEED-1   ;последний индекс MOUSE_TABLE

.mx4            add a,a
                ld  e,a
                ld d,0
                ld hl,MOUSE_TABLE
                add hl,de
                ld d,(hl)       ;D дробная часть dX
                inc hl
                ld e,(hl)       ;E целая часть dX

                ld hl,(CUR_MY+1);cтарший 16 бит 24бит коорд
                ld a,b
                or a            ;0 значит негативчик
                ld a,(CUR_MY)   ;A дробная часть координаты X

                jr nz,.mx5
                sub d
                ld (CUR_MY),a   ;дробную сохраняем, пох на нее в целом
                ld d,0
                sbc hl,de       ;вычитаем со знаком от дробной
                ex de,hl
                jr nc,.mx6      ;через 0 не перешли
                ld d,h          
                ld e,h
                jr .mx6

.mx5            add a,d
                ld (CUR_MY),a   ;дробную сохраняем, пох на нее в целом
                ld d,0
                adc hl,de       ;HL старшие 16бит координаты
                or a
                ld de,MOUSE_MAX_Y
                ex de,hl        ;DE координата X 16h bits
                sbc hl,de
                jr nc,.mx6
                ld de,MOUSE_MAX_Y
                
.mx6            ld (CUR_MY+1),de   ;итоговые координаты Х   

.no_Y           ret




           






MOUSE_SPRITE_DATA:
    db #40, #00, #00, #00, #00, #00, #00, #00   ; 4             (Острая вершина)
    db #44, #00, #00, #00, #00, #00, #00, #00   ; 4B 4
    db #4B, #40, #00, #00, #00, #00, #00, #00   ; 4B B4
    db #4B, #B4, #00, #00, #00, #00, #00, #00   ; 4B BB 4
    db #4B, #BB, #40, #00, #00, #00, #00, #00   ; 4B BB B4
    db #4B, #BB, #B4, #00, #00, #00, #00, #00   ; 4B BB BB 4
    db #4B, #B4, #44, #40, #00, #00, #00, #00   ; 4B BB BB B4
    db #4B, #44, #00, #00, #00, #00, #00, #00   ; 4B BB 44 44 4  (Тонкий срез крыла)
    db #40, #00, #00, #00, #00, #00, #00, #00   ; 4B B4 4B B4    (Начало тонкой ножки)
    db #00, #00, #00, #00, #00, #00, #0f, #00   ; 4B 40 04 BB 4
    db #00, #00, #00, #00, #00, #00, #f0, #f0   ; 40 00 00 4B B4
    db #00, #00, #00, #00, #00, #00, #f0, #f0   ; 00 00 00 44 B4 (Ножка в 1 жирный пиксель)
    db #00, #00, #00, #00, #00, #00, #f0, #f0   ; 00 00 00 00 44 (Конец ножки)
    db #00, #00, #00, #00, #00, #00, #f0, #f0   ; Пусто
    db #00, #00, #00, #00, #00, #00, #0f, #00   ; Пусто
    db #00, #00, #00, #00, #00, #00, #00, #00   ; Пусто


  display     "ACC TABLE",/d,MOUSE_ACC_TABLE 
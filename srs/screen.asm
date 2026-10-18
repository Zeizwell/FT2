; =========================================================================
; ДВОЙНОЙ БУФЕР ТЕКСТОВОГО ЭКРАНА (часть коре) - для тулз: рисуем в невидимую страницу
; (SV_DRAW_PAGE), раз в кадр показываем её (VPAGE), видимую - DMA копией в невидимую, чтобы
; дорисовывать только изменения. Страницы: PAGE_TEXT / PAGE_TEXT2 (шрифт - страница XOR 1, оба
; грузит spg). Без тулзы (вид паттерна) - одна страница, как раньше.
; =========================================================================
Scr_On          db 0                ; 1 - тулза рисует через двойной буфер
Scr_Show_Pg     db PAGE_TEXT        ; видимая страница

;-------- Тулза начинает: видимая - копией в другую, рисуем в другую (SV_DRAW_PAGE).
; Звать ДО SETPAGE3 (SV_DRAW_PAGE) тулзы
Scr_Begin
        ld a,(SV_DRAW_PAGE)         ; сейчас видна та, в которую рисовали
        ld (Scr_Show_Pg),a
        call Scr_Copy               ; видимая -> другая
        ld a,(Scr_Show_Pg)
        xor PAGE_TEXT^PAGE_TEXT2
        ld (SV_DRAW_PAGE),a
        ld a,1
        ld (Scr_On),a
        ret

;-------- Кадр готов: показать нарисованную, её же - копией в другую, рисовать дальше в другую.
; Окно 3 тулзы - на новую невидимую (пара SETPAGE3..RESTPAGE3 тулзы открыта). Портит всё
Scr_Show
        ld a,(Scr_On)
        or a
        ret z
        ld a,(SV_DRAW_PAGE)         ; показать
        ld (Scr_Show_Pg),a
        ld bc,VPAGE
        out (c),a
        call Scr_Copy               ; видимая -> другая (ждём конца)
        ld a,(Scr_Show_Pg)
        xor PAGE_TEXT^PAGE_TEXT2
        ld (SV_DRAW_PAGE),a
        SWAPPAGE 3,a
        ret
    ASSERT PAGE_TEXT^PAGE_TEXT2 == 2

;-------- Тулза уходит: показать последнее, дальше (вид паттерна) - рисуем в видимую. Звать до
; RESTPAGE3 тулзы
Scr_End
        call Scr_Show
        xor a
        ld (Scr_On),a
        ld a,(Scr_Show_Pg)
        ld (SV_DRAW_PAGE),a
        ret

;-------- Страница Scr_Show_Pg целиком (64 строки по 256) -> в другую (DMA, ждём конца)
Scr_Copy
        ld a,(Scr_Show_Pg)
        ld (Scr_Dma+5),a            ; источник - видимая
        xor PAGE_TEXT^PAGE_TEXT2
        ld (Scr_Dma+11),a           ; приёмник - другая
        ld hl,Scr_Dma
        call set_ports
        jp dma_wait
Scr_Dma db high DMASADDRL,0, high DMASADDRH,0, high DMASADDRX,0
        db high DMADADDRL,0, high DMADADDRH,0, high DMADADDRX,0
        db high DMALEN,128-1, high DMANUM,64-1, high DMACTR,DMA_RAM|DMA_SALGN|DMA_DALGN, #FF

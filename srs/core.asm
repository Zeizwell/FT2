; Core 
    ds #38
    org #0038   ; im1
    di
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ex af,af'
    push af
    push bc
    push de
    push hl
    call IM1_Handler
    pop hl
    pop de
    pop bc
    pop af
    ex af,af'
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ei
    ret

    org #0100   ;пропускаем нми и др парашу

IM1_Handler

    call Read_Mouse

    ret

    

Core_Start
        ; системные переменные для плагинов (sdk/plugin.asm)
        ld a,FT2_API_VERSION
        ld (SV_API_VERSION),a
        ld a,PAGE_TEXT
        ld (SV_DRAW_PAGE),a
        ld hl,Theme_Default
        ld de,THEME_ATTR
        ld bc,Theme_Default_end-Theme_Default
        ldir

        im 1
        ld hl,100
        ld de,100
        call Init_Mouse_Sprite

        ld a,PAGE_TOOL_PATVIEW  ; пока просто показываем тестовый паттерн
        call Call_Tool

Pause
        ei
        halt
        jp Pause

;-------- Вызов тулзы: страница тулзы в окно 1, старт с #4000
; in: A - пейдж тулзы
; Тулза сама SETPAGE2/3 под свои данные и RESTPAGE перед ret.
; После возврата окно 1 восстановлено. Портит A, BC.
Call_Tool
        SETPAGE1 a
        call #4000
        RESTPAGE1
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


    include "srs/mouse.asm"
    include "srs/colors.asm"
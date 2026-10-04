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
        im 1
        ld hl,100
        ld de,100
        call Init_Mouse_Sprite
        
Pause
        ei
        halt
        jp Pause


;--------пуш в порты, 1 байт старший байт порта #xxAF, нект байт данные, конец таблицы #FF  
    IFUSED set_ports    
set_ports	ld c,#AF
.m1		ld b,(hl) 
		inc hl
		inc b
		jr z,dma_stats
		outi
		jr .m1
	ENDIF
	
	IFUSED set_ports_nowait

;------запуск DMA    
set_ports_nowait
		ld c,#AF
.m2		ld b,(hl) 
		inc hl
		inc b
		ret z
		outi
		jr .m2
	ENDIF
	IFUSED dma_stats
dma_stats	ld b,high DMASTATUS
		in a,(c)
		AND #80
		jr nz,$-4
		ret
	ENDIF


    include "srs/mouse.asm"
    include "srs/colors.asm"
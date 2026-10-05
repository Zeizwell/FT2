; =========================================================================
; КНОПКИ ТРАНСПОРТА: описатели спрайтов (SFILE) - в коре, чтобы их видели все экраны.
; Графику и состояния (Tr_State_Update) ведёт шапка в виде паттерна (srs/head.asm).
TR_BUTTONS      equ 5               ; кнопок (их поля и графика - srs/head.asm)

; =========================================================================
;-------- Все кнопки - обычные (плеер встал не по кнопке: загрузка трека)
Tr_Normal
        ld hl,Tr_SAT+4              ; тайл в описателе кнопки k: patview.TR_ROW*64 + 2k
        ld de,6
        ld a,patview.TR_ROW*64
        ld b,TR_BUTTONS
.k      ld (hl),a
        add hl,de
        add a,2
        djnz .k
        jr Tr_Send

; Описатели кнопок - в SFILE (DMA, из основного цикла)
Tr_Send
        ld hl,Tr_Dma
        jp set_ports

; Описатели (SFILE: Y, флаги Y, X, флаги X, тайл, палитра | тайл ст.)
        ALIGN 2
Tr_SAT
.k = 0
        DUP TR_BUTTONS
        db patview.HD_PLAY_Y*8, SP_ACT|SP_SIZE16, (patview.HD_PLAY_X+.k*4)*4, SP_SIZE16, patview.TR_ROW*64+.k*2, patview.TR_PAL
.k = .k+1
        EDUP
Tr_SAT_End

Tr_Dma  db high DMASADDRL, low Tr_SAT     ; коре: страница 0, окно 0
        db high DMASADDRH, high Tr_SAT
        db high DMASADDRX, PAGE_CORE0
        db high DMADADDRL, patview.TR_SFILE_SLOT*6  ; SFILE: записи 0..4 (5 - стрелка мыши)
        db high DMADADDRH, 0
        db high DMADADDRX, 0
        db high DMALEN, (Tr_SAT_End-Tr_SAT)/2-1
        db high DMANUM, 0
        db high DMACTR, DMA_RAM_SFILE
        db #FF

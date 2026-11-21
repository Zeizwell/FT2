; =========================================================================
; КНОПКИ ТРАНСПОРТА: описатели спрайтов (SFILE) - в коре, чтобы их видели все экраны.
; Графику и состояния (Tr_State_Update) ведёт шапка в виде паттерна (srs/head.asm).
; Как в Bitphase: нажатая кнопка, пока играет, на месте горит значком ■ - клик по ней - стоп.
TR_BUTTONS      equ 5               ; кнопок в графике (5-я - значок ■ для горящей)
TR_SHOWN        equ 4               ; на экране: ⇄ |◀ ▶ ▷ (отдельного ■ нет)
Tr_Btn          db #FF              ; какой кнопкой (или её клавишей) запущено (#FF - никакой)

; =========================================================================
;-------- Кнопки по состоянию плеера (тулзы): все обычные, горит (■) та, которой запустили,
; пока играет. Под мышью / нажата - только в шапке вида паттерна
TR_TILE_N       equ patview.TR_ROW*64                       ; тайл кнопки 0, обычный
TR_TILE_A       equ patview.TR_ROW*64+patview.TRV_ACTIVE*10 ;   и горящий

Tr_Active
        ld hl,Tr_SAT+4              ; тайл в описателе кнопки k: обычный + 2k
        ld de,6
        ld a,TR_TILE_N
        ld b,TR_BUTTONS
.k      ld (hl),a
        add hl,de
        add a,2
        djnz .k
        call Tr_Lit                 ; горящая: A - её номер (CF - никакой)
        jr c,Tr_Send
        ld e,a                      ; описатель: Tr_SAT + 6k, тайл - горящий + 2k
        add a,a
        ld b,a
        add a,e
        add a,a
        ld e,a
        ld d,0
        ld hl,Tr_SAT+4
        add hl,de
        ld a,TR_TILE_A
        add a,b
        ld (hl),a
        jr Tr_Send

; Каждый кадр (Fld_Update): горящая кнопка сменилась (трек кончился, запустили клавишей) -
; кнопки заново. В виде паттерна его Tr_State_Update тут же наложит подсветку поверх
Tr_LitOld       db #FF
Tr_Watch
        call Tr_Lit
        jr nc,$+4
        ld a,#FF
        ld hl,Tr_LitOld
        cp (hl)
        ret z
        ld (hl),a
        jp Tr_Active

; Горящая кнопка: играет - A = Tr_Btn, CF = 0; не играет или кнопки нет - CF = 1
Tr_Lit  ld a,(SV_PLAY_STATE)
        or a
        scf
        ret z
        ld a,(Tr_Btn)
        cp TR_SHOWN
        ccf
        ret

; Клик по кнопке A: играет с неё - Z (значит стоп); иначе запомнить её, NZ
Tr_Press
        ld b,a
        call Tr_Lit
        jr c,.new
        cp b
        ret z
.new    ld a,b
        ld (Tr_Btn),a
        or #FF                      ; NZ
        ret

; Описатели кнопок - в SFILE (DMA, из основного цикла)
Tr_Send
        ld hl,Tr_Dma
        jp set_ports

; Описатели (SFILE: Y, флаги Y, X, флаги X, тайл, палитра | тайл ст.)
        ALIGN 2
Tr_SAT
.k = 0
        DUP TR_BUTTONS
        IF .k < TR_SHOWN
        db patview.HD_PLAY_Y*8, SP_ACT|SP_SIZE16, (patview.HD_PLAY_X+.k*4)*4, SP_SIZE16, patview.TR_ROW*64+.k*2, patview.TR_PAL
        ELSE
        db 0, SP_SIZE16, 0, SP_SIZE16, 0, patview.TR_PAL      ; 5-я (■) не показывается
        ENDIF
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

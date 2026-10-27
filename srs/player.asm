; =========================================================================
; ПЛЕЕР FT2 (doc/player.md). Страницы PAGE_PLAYER (окно 1, #4000 - код) и PAGE_PLAYER2
; (окно 2, #8000 - таблицы и что не влезло).
; =========================================================================
; IM1 первым делом: коре ставит обе страницы в окна 1 и 2 и зовёт PLAYER_TICK.
; Основной цикл командует через SV_PLAY_CMD (+ CPOS / CROW), плеер сам ведёт
; позицию, роу, тики и скорость и отдаёт их в SV_PLAY_*.
; Данные - в окно 3 на время чтения (SETPAGE3 / RESTPAGE3, страница тулзы - на место):
;   страница трека (SV_PLAY_SONG): ордер, каталог паттернов, скорость, страница
;   инструментов; страница паттерна; страница инструментов и орнаментов.
; Ноты, инструменты и орнаменты (формат FTC), громкость, огибающая, шум, 2 чипа,
; команды паттерна (doc/commands.md).
;
; Как в плеере FT 1.15: у каждого канала свой код (макрос PL_CHAN, 6 копий), его
; состояние - прямо в командах (операнд - "Метка+1"); режимы - переходы, у которых
; правится смещение (GATE_ON - код за переходом работает, GATE_OFF - обход).
; Регистры чипа - адресами в коде, таблицы - на границе 256, без индексных регистров.
; Строки инструмента и орнамента - указатель и счётчик до конца (не номер строки).
; =========================================================================
    org #4000
player_start
        jp Pl_Init                  ; PLAYER_INIT
        jp Pl_Tick                  ; PLAYER_TICK
        jp Pl_Mute                  ; заглушить оба чипа

CHANNELS        equ 6

; Ворота: на месте g собрано jr t. OFF - опкод jr (#18, обход до t), ON - cp n (#FE: смещение
; становится операндом, идём дальше, 7 тактов). Правится только опкод. Портят A
    MACRO GATE_ON g
        ld a,#FE
        ld (g),a
    ENDM
    MACRO GATE_OFF g, t
        ld a,#18
        ld (g),a
    ENDM

; Регистры, посчитанные в этом тике (выводятся в начале следующего): по чипу буфер на границе
; 256 (Pl_Regs, Pl_Regs2: младший байт адреса = номер регистра, вывод - OUTI)
PR_SIZE         equ 14
PR_R13W         equ 14              ; в буфере: 1 - писать R13 (перезапуск огибающей)
PR_RTN          equ 15              ;   ретриггер (как FT 1.15): бит q - тон выхода q через 0 перед R13 (сброс фазы)
PR_STEP         equ Pl_Regs2-Pl_Regs
Pl_EnvBase      ds 2*2              ; период огибающей из паттерна, по чипу
Pl_NoiseBase    ds 2                ; шум из паттерна, по чипу
Es_Ofs          ds 2*2              ; 9 / A: смещение периода огибающей слайдом, по чипу
Pc_Mix          db 0                ; микшер чипа (собирают каналы)
Pc_ESum         db 0                ; PT: сумма смещений огибающей каналов чипа

Pl_PatPage      db 0                ; страница паттерна текущей позиции
Pl_PatLen       db 64
Pl_InsPage      db 0
Pl_NoteTab      dw NoteT            ; таблица нот трека (NoteT - копия по SH_TUNING)
Pl_OrdLast      db 0
Pl_OrdLoop      db 0
Pl_Chips        db CHIPS_MAX        ; чипов у трека (SH_CHIPS): 1 - только первый
Pl_Looped       db 0                ; 1 - сонг дошёл до конца ордера и ушёл на цикл
Pl_Quiet        db 0                ; 1 - тик без вывода в AY и в карту (экспорт PSG, коре Psg_Tick)

;-------- Старт: таблицы громкости и стерео, каналы с нуля, тишина
Pl_Init
        call Pl_VolTab
        call Fx_Detect              ; карта AY FX
        call Ts_Detect              ; TurboSound
        xor a
        ld (SV_PLAY_STATE),a
        ld (SV_PLAY_CMD),a
        call Pl_Reset_Ch
        jp Pl_Mute

;-------- Таблица громкости: Vol_T[канал*16 + амплитуда] = (канал*амплитуда + 7) / 15
; (как PT3 3.5+ и FTC)
Pl_VolTab
        ld hl,Vol_T
        ld b,0                      ; B - громкость канала
.c      ld c,0                      ; C - амплитуда
.a      push bc
        ld a,b                      ; B*C
        ld e,c
        ld d,0
        ld hl,0
        or a
        jr z,.mul0
.mul    add hl,de
        dec a
        jr nz,.mul
.mul0   ld de,7
        add hl,de
        ld a,l                      ; /15 (максимум 232 - в байте)
        ld c,0
.div    sub 15
        jr c,.dd
        inc c
        jr .div
.dd     ld a,c
        pop bc
        push af
        ld a,b                      ; адрес: Vol_T + B*16 + C
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,high Vol_T
        pop af
        ld (hl),a
        inc c
        ld a,c
        cp 16
        jr c,.a
        inc b
        ld a,b
        cp 16
        jr c,.c
        ret

        ALIGN 256
Pl_Regs         ds PR_SIZE+2        ; чип 1 (+флаг R13, маска ретриггера)

;-------- Тишина: громкости 0 у обоих чипов, шум и тон выключены
Pl_Mute
        xor a
        ld hl,Pl_Regs
        ld b,PR_SIZE+1
.z      ld (hl),a
        inc l
        djnz .z
        ld hl,Pl_Regs2
        ld b,PR_SIZE+1
.z2     ld (hl),a
        inc l
        djnz .z2
        call Fx_Mute                ; FX: у карты все каналы - выкл (уйдёт в Pl_Out)
        xor a
        ld a,#3F
        ld (Pl_Regs+7),a
        ld (Pl_Regs2+7),a
        jp Pl_Out

; =========================================================================
; ТИК (из IM1)
; =========================================================================
Pl_Tick
        call Pl_Out                 ; 1. в AY - посчитанное в прошлом тике
        ld a,(SV_PLAY_CMD)          ; 2. команда
        or a
        call nz,Pl_Cmd
        ld a,(SV_PLAY_STATE)
        or a
        ret z                       ; стоп
        cp PS_PREVIEW               ; проба - только каналы
        jp z,Pl_Channels
        ld a,(SV_PLAY_TICK)         ; 3. тик 0 - читаем роу
        or a
        jr nz,.chans
        call Pl_Row
        ld a,(SV_PLAY_SPEED)
        ld (SV_PLAY_TICK),a
.chans  call Pl_Channels            ; 4. каналы -> регистры
        ld hl,SV_PLAY_TICK          ; 5. роу кончилась - следующая
        dec (hl)
        ret nz
        jp Pl_Next_Row

;-------- Команда основного цикла
Pl_Cmd
        ld b,a
        xor a
        ld (SV_PLAY_CMD),a
        ld a,b
        cp PC_PREVIEW
        jr z,Pl_Preview
        cp PC_STOP
        jr nz,.play
        xor a
        ld (SV_PLAY_STATE),a
        jp Pl_Mute
.play   ld (SV_PLAY_STATE),a        ; PC_SONG = PS_SONG, PC_PATTERN = PS_PATTERN
        ld a,(SV_PLAY_CPOS)
        ld (SV_PLAY_POS),a
        ld a,(SV_PLAY_CROW)
        ld (SV_PLAY_ROW),a
        xor a
        ld (SV_PLAY_TICK),a         ; роу - сразу в этом тике
        call Pl_Reset
        jp Pl_Pos_Info

;-------- Тишина, каналы с нуля, сведения о треке. Играем трек, который сейчас правят
; (SV_SONG_PAGE): он же - для пробы ноты
Pl_Reset
        ld a,(SV_SONG_PAGE)
        ld (SV_PLAY_SONG),a
        xor a                       ; метка конца трека - заново
        ld (Pl_Looped),a
        call Pl_Mute                ; оба чипа (второго может не быть в треке)
        call Pl_Reset_Ch
        call Pl_Song_Info           ; скорость, страница инструментов, ордер
        jp Fx_Tables                ; таблицы FX - в карту

; Каналы и слайды огибающей - с нуля
Pl_Reset_Ch
        call c0.Rst
        call c1.Rst
        call c2.Rst
        call c3.Rst
        call c4.Rst
        call c5.Rst
        call es0.Rst
        jp es1.Rst

;-------- Проба: строка Prv_Row (коре) - в канал A первого чипа, дальше тики без роу.
; Период огибающей 0 - по ноте (1:1, период тона / 16)
Pl_Preview
        call Pl_Reset
        ld a,1                      ; только первый чип (второй молчит)
        ld (Pl_Chips),a
        ld a,PS_PREVIEW
        ld (SV_PLAY_STATE),a
        ld a,low Prv_Row            ; роу - из коре
        ld (Pr_Base),a
        ld h,high Prv_Row
        call Pl_Row_Chips
        xor a
        ld (Pr_Base),a
        ld hl,(Prv_Row+CHIP_ENVPER) ; огибающая задана - всё
        ld a,h
        or l
        ret nz
        ld a,(c0.NN+1)              ; по ноте: период тона / 16
        or a
        ret z
        call Pl_NotePer
        ld b,4
.sh     srl h
        rr l
        djnz .sh
        ld (Pl_EnvBase),hl
        ret

;-------- Из страницы трека: скорость, страница инструментов, таблица нот, последняя
; позиция, цикл
Pl_Song_Info
        ld a,(SV_PLAY_SONG)
        SETPAGE3 a
        ld a,(#C000+SH_SPEED)
        ld (SV_PLAY_SPEED),a
        ld a,(#C000+SH_INS_PAGE)
        ld (Pl_InsPage),a
        ld a,(#C000+SH_TUNING)      ; таблица нот: 0 - 1.75 МГц, иначе 1.7734
        or a
        ld hl,Note_175
        jr z,$+5
        ld hl,Note_177
        ld de,NoteT
        ld bc,NOTE_COUNT*2
        ldir
        ld a,(#C000+SH_ENVMODE)     ; огибающая FT / PT - в общую переменную (коре)
        ld (Song_EnvMode),a
        ld a,(#C000+SH_STEREO)      ; стерео - тоже
        ld (Song_Stereo),a
        ld a,(#C000+ORD_LAST)
        ld (Pl_OrdLast),a
        ld a,(#C000+SH_CHIPS)
        ld (Pl_Chips),a
        ld a,(#C000+ORD_LOOP)
        ld (Pl_OrdLoop),a
        RESTPAGE3
        ret

;-------- Позиция SV_PLAY_POS -> страница и длина её паттерна
Pl_Pos_Info
        ld a,(SV_PLAY_SONG)
        SETPAGE3 a
        ld a,(SV_PLAY_POS)
        ld l,a
        ld h,high (#C000+ORD_POS)
        ld a,low (#C000+ORD_POS)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)                   ; номер паттерна
        add a,a                     ; каталог: по PC_SIZE (2)
        ld l,a
        ld h,high (#C000+PAT_CATALOG)
        ld a,(hl)
        ld (Pl_PatPage),a
        inc l
        ld a,(hl)
        ld (Pl_PatLen),a
        RESTPAGE3
        ret
    ASSERT PC_SIZE == 2 && PC_PAGE == 0 && PC_LEN == 1
    ASSERT low (#C000+PAT_CATALOG) == 0

;-------- Следующая роу: конец паттерна - роу 0 (паттерн) или следующая позиция
Pl_Next_Row
        ld a,(SV_PLAY_ROW)
        inc a
        ld hl,Pl_PatLen
        cp (hl)
        jr nc,.end
        ld (SV_PLAY_ROW),a
        ret
.end    xor a
        ld (SV_PLAY_ROW),a
        ld a,(SV_PLAY_STATE)
        cp PS_PATTERN
        ret z
        ld a,(Pl_OrdLast)           ; сонг: следующая позиция, за последней - цикл
        ld b,a
        ld a,(SV_PLAY_POS)
        cp b
        jr c,.inc
        ld a,1                      ; трек кончился - метка (компаратор, проверка длины)
        ld (Pl_Looped),a
        ld a,(Pl_OrdLoop)
        jr .pos
.inc    inc a
.pos    ld (SV_PLAY_POS),a
        jp Pl_Pos_Info

        ALIGN 256
Pl_Regs2        ds PR_SIZE+2        ; чип 2 (+флаг R13, маска ретриггера)

; =========================================================================
; РОУ ПАТТЕРНА -> каналы
; =========================================================================
Pl_Row
        ld a,(Pl_PatPage)
        SETPAGE3 a
        ld a,(SV_PLAY_ROW)
        add a,#C0
        ld h,a
        call Pl_Row_Chips
        RESTPAGE3
        ret

;-------- H - роу (L начала - Pr_Base): заголовок чипа и его каналы
Pr_Base         db 0                ; L начала роу (паттерн - 0, проба - Prv_Row)
Pl_Row_Chips
        ld a,(Pr_Base)
        ld l,a
        ld de,Pl_EnvBase            ; чип 1
        ld bc,Pl_NoiseBase
        call Pr_ChipHdr
        push hl
        ld a,l
        add a,CHIP_CH_A
        ld l,a
        call c0.Rw
        pop hl
        push hl
        ld a,l
        add a,CHIP_CH_B
        ld l,a
        call c1.Rw
        pop hl
        push hl
        ld a,l
        add a,CHIP_CH_C
        ld l,a
        call c2.Rw
        pop hl
        push hl
        call Pr_ECmd0               ; команда огибающей чипа - после каналов (новая форма в канале её не сбросит)
        pop hl
        ld a,(Pl_Chips)             ; только чипы трека
        dec a
        ret z
        ld a,l                      ; чип 2
        add a,CHIP_SIZE
        ld l,a
        ld de,Pl_EnvBase+2
        ld bc,Pl_NoiseBase+1
        call Pr_ChipHdr
        push hl
        ld a,l
        add a,CHIP_CH_A
        ld l,a
        call c3.Rw
        pop hl
        push hl
        ld a,l
        add a,CHIP_CH_B
        ld l,a
        call c4.Rw
        pop hl
        push hl
        ld a,l
        add a,CHIP_CH_C
        ld l,a
        call c5.Rw
        pop hl
        jp Pr_ECmd1

;-------- Команда огибающей чипа (CHIP_ECMD; doc/commands.md, «Колонка огибающей»): HL - заголовок чипа в роу.
; Пока - слайды 1 / 2 (как Bitphase: 1 - период растёт = наш 9, 2 - A), через слайд огибающей чипа es0 / es1
Pr_ECmd0
        call Ec_Get
        ret z
        call es0.Set
        jp es0.Now
Pr_ECmd1
        call Ec_Get
        ret z
        call es1.Set
        jp es1.Now

; HL - заголовок -> C - байт 0 для es.Set (9 / A, задержка), E - шаг; Z - слайда нет
Ec_Get  ld a,l
        add a,CHIP_ECMD
        ld l,a
        ld c,(hl)                   ; код, задержка
        inc l
        ld e,(hl)                   ; параметр
        ld a,c
        and #F0
        cp CMD_GLIS_DOWN<<4         ; 1 - период растёт
        ld b,CMD_ENV_DOWN<<4
        jr z,.s
        cp CMD_GLIS_UP<<4           ; 2 - период падает
        jr nz,.no                   ; пусто и остальное (пока нет) - Z
        ld b,CMD_ENV_UP<<4
.s      ld a,c
        and #0F
        or b
        ld c,a
        or 1                        ; NZ - есть
        ret
.no     xor a
        ret

; HL - заголовок чипа в роу: период огибающей (не 0) -> (DE), шум (не 0) -> (BC). HL цел
Pr_ChipHdr
        push hl
        ld a,(hl)                   ; период огибающей
        inc l
        ld h,(hl)
        ld l,a
        ld a,h
        or l
        jr z,.noenv
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
.noenv  pop hl
        push hl
        ld a,l                      ; шум (0 - пусто, шум 0 - #20)
        add a,CHIP_NOISE
        ld l,a
        ld a,(hl)
        or a
        jr z,.nonz
        and #1F
        ld (bc),a
.nonz   pop hl
        ret

;-------- Строка роу (общее для каналов, Rw): команды строки, что зависит от ноты
Pr_GCmd         db 0                ; глисс / портаменто: байт 0 команды (0 - нет)
Pr_GPar         db 0                ;   параметр
Pr_SOfs         db 0                ; сэмпл с позиции: строка+1 (0 - нет)
Pr_OOfs         db 0                ; орнамент с позиции: строка+1 (0 - нет)
Pr_NDly         db 0                ; задержка ноты, тиков (0 - нет)
Pr_NewIns       db 0                ; в строке сменили сэмпл
Pr_NewOrn       db 0                ;   орнамент
Pr_Oo           db 0                ;   команда 6 (нота её иначе снимает, как PT3)
Pr_Arp          db 0                ;   команда C (нота её иначе снимает, как Bitphase)
Pr_Vib          db 0                ;   команда 8 (нота её иначе снимает, как Bitphase)
Pr_SlSet        db 0                ;   портаменто с нотой: цель задана (Slide)

; B скорость: сразу (0 - не трогаем), тик этой роу Pl_Tick возьмёт уже с новой
Pl_CSpd
        ld a,e
        or a
        ret z
        ld (SV_PLAY_SPEED),a
Pl_Ret  ret

Pl_JpHL jp (hl)

; DE = -DE
Neg_DE  ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc de
        ret

; A - нота 1..96 -> HL - её период. DE, BC целы
Pl_NotePer
        dec a
        add a,a
        ld l,a
        ld h,high NoteT
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ret

; HL += A*5 (строки инструмента). Портит DE
Mul5Add ld e,a
        ld d,0
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        ret

    ASSERT CH_NOTE == 0 && CH_SAMPLE == 1 && CH_ENVSHAPE == 2 && CH_ORNAMENT == 3 && CH_VOLUME == 4
    ASSERT CH_CMD == 6 && CH_CMDS == 2
    ASSERT OH_LOOP == 1 && OH_END == 2 && OH_ROWS == 3
    ASSERT IR_NOISE == 0 && IR_TONE == 1 && IR_VOL == 3 && IR_ENV == 4

Is_R            db 0                ; InsSet / OrnSet: строка

; =========================================================================
; КАНАЛ - макрос, копия на канал: m_name - модуль (c0..c5), m_n - номер 0..5,
; m_es / m_esr - слайд огибающей его чипа: команда и сброс (es0.Set / es0.Rst)
; =========================================================================
    MACRO PL_CHAN m_name, m_n, m_es, m_esr
    MODULE m_name
CHIP    equ m_n/3
IDX     equ m_n-CHIP*3
REGS    equ Pl_Regs+CHIP*PR_STEP

;-------- Тик: строки инструмента и орнамента -> регистры (инструменты - в окне 3)
Tk
DlG     jr DlEnd                    ; F2: отложенная нота (ON - ждём)
DlC     ld a,0
        or a
        jr z,DlGo
        dec a
        ld (DlC+1),a
        jr DlEnd
DlGo
DlN     ld a,0                      ;   пора: ворота закроет NoteGo
        call NoteGo
DlEnd
SndJ    jp Silent                   ; звучит - Snd, молчит - Silent (R--, тишина команды 6)
Silent  xor a                       ; молчит: громкость 0, канал стоит (как PT3: ни сэмпл, ни
Wv1     ld (REGS+8+IDX),a           ;   слайды; адреса записи - по стерео, St_Apply)
OoG     jr OoEnd                    ; 6 вкл / выкл - после вывода (как CH_EXIT в PT3: смена
OoC     ld a,0                      ;   фазы - со следующего тика): фаза кончилась - другая
        dec a
        jr nz,OoSt
        ld hl,Snd                   ;   звук <-> тишина (тишина - тик идёт в Silent)
        ld a,(SndJ+1)
        cp low Silent
        jr z,OoSnd
        ld hl,Silent
        ld (SndJ+1),hl
OoOff   ld a,0                      ;   тиков тишины
        jr OoCnt
OoSnd   ld (SndJ+1),hl
OoOn    ld a,0                      ;   тиков звука
OoCnt   or a                        ;   0 - больше не переключать (как PT3)
        jr nz,OoSt
        GATE_OFF OoG,OoEnd
        ret
OoSt    ld (OoC+1),a
OoEnd   ret
    ASSERT low Silent != low Snd
Snd
RiG     jr RiEnd                    ; инструмент - со строки RiR (нота, 4, смена сэмпла)
RiB     ld hl,#C000                 ;   блок сэмпла
RiR     ld a,0
        call InsSet
        ld hl,(RiB+1)               ;   и его FX (карта AY FX)
        ld a,m_n
        call Fx_Start
RiEnd
RoG     jr RoEnd                    ; орнамент - со строки RoR
RoB     ld hl,0                     ;   блок орнамента (старший 0 - нет)
RoR     ld a,0
        call OrnSet
RoEnd
OG      jr ONone                    ; орнамент (OFF - нет)
OP      ld hl,0                     ;   строка: шум и флаги, сдвиг ноты
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
OCN     ld a,0                      ;   строк до конца; конец - на цикл
        dec a
        jr nz,OSt
OLA     ld hl,0
OLC     ld a,0
OSt     ld (OCN+1),a
        ld (OP+1),hl
        ld a,c                      ;   шум + накопленный (бит 7 - сохранить)
        and #1F
ONZ     add a,0
        bit 7,c
        jr z,$+5
        ld (ONZ+1),a
        ld (ONS+1),a
        ld a,b                      ;   сдвиг ноты + накопленный (бит 6 - сохранить)
ONA     add a,0
        bit 6,c
        jr z,ONote
        ld (ONA+1),a
        jr ONote
ONone   xor a
ONote
NT      add a,0                     ; нота 0..95
ARS     add a,0                     ;   + арпеджио
        cp NOTE_COUNT               ;   за краями - край
        jr c,NOk
        rla
        ld a,NOTE_COUNT-1
        jr nc,NOk
        xor a
NOk     ld b,a                      ; B - нота
IP      ld hl,0                     ; строка инструмента (5 байт)
        ld a,(hl)                   ; шум
        ld (B0+1),a
        inc hl
        bit 6,a
        jr nz,NOff
        ex de,hl
        ld c,a
        and #1F                     ;   смещение + накопленное (бит 7 - сохранить)
NA      add a,0
        bit 7,c
        jr z,$+5
        ld (NA+1),a
ONS     add a,0                     ;   + шум орнамента
        ld hl,Pl_NoiseBase+CHIP     ;   + шум паттерна
        add a,(hl)
        and #1F
        ld (REGS+6),a
        ld hl,Pc_Mix                ;   шум канала - вкл
Mn      res 3+IDX,(hl)
        ex de,hl
NOff    ld e,(hl)                   ; тон
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; громкость
        ld (B3+1),a
        inc hl
        ld a,(hl)                   ; огибающая
        ld (B4+1),a
        inc hl
ICN     ld a,0                      ; строк до конца; конец - на цикл
        dec a
        jr nz,ISt
ILA     ld hl,0
ILC     ld a,0
ISt     ld (ICN+1),a
        ld (IP+1),hl
        ld c,d                      ; тон: C - флаги
        bit 6,c
        jr nz,TOff
        ld hl,Pc_Mix                ;   тон канала - вкл
Mt      res IDX,(hl)
TOff    bit IRB_RETRIG,c            ;   ретриггер огибающей
        jr z,TNoR
        ld a,1
        ld (REGS+PR_R13W),a
TNoR    ld a,d                      ;   12 бит со знаком -> 16
        and #0F
        xor 8
        sub 8
        ld d,a
TA      ld hl,0                     ;   + накопленный (бит 7 - сохранить)
        add hl,de
        bit 7,c
        jr z,$+5
        ld (TA+1),hl
        ex de,hl
        ld a,b                      ; период ноты
        add a,a
        ld l,a
        ld h,high NoteT
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        add hl,de                   ; + тон строки
GOF     ld de,0                     ; + глисс / портаменто
        add hl,de
DT      ld de,0                     ; + детюн
        add hl,de
VO      ld de,0                     ; + вибрато
        add hl,de
        ld a,h
        and #0F
        ld h,a
Wt      ld (REGS+IDX*2),hl
GG      jr GEnd                     ; 1, 2, 3 глисс / портаменто: шаг - после тона (как PT3: со след. тика)
GC      ld a,0
        dec a
        jr nz,GSt
        ld hl,(GOF+1)
GS      ld de,0
        add hl,de
        ld (GOF+1),hl
GM      jr GDl                      ;   глисс - дальше, портаменто (ON) - доехали до цели?
TD      ld bc,0                     ;   цель смещения: P(цель) - P(база)
        or a
        sbc hl,bc                   ;   смещение - цель
        jr z,GStop
        ld a,h                      ;   знаки разности и шага разные - ещё едем
        xor d
        jp m,GDl
GStop   call PtEnd                  ;   доехали: нота - цель
        jr GEnd
GDl
GD      ld a,0
        or a                        ;   задержка 0 - один шаг и стоп (VT2, Bitphase)
        jr nz,GSt
        GATE_OFF GG,GEnd
        jr GEnd
GSt     ld (GC+1),a
GEnd
VbG     jr VbEnd                    ; 8 вибрато (как Bitphase): раз в D тиков шаг по треугольнику
VbC     ld a,0
        dec a
        jr nz,VbSt
VbK     ld a,0                      ;   шаг в четверти периода (0..скорость-1)
        inc a
VbS     cp 0                        ;   скорость - шагов в четверти
        jr c,VbK2
        ld a,(VbQ+1)                ;   следующая четверть
        inc a
        and 3
        ld (VbQ+1),a
        xor a
VbK2    ld (VbK+1),a
        ld e,a                      ;   q = шаг * глубина / скорость - из таблицы канала
        ld d,0
        ld hl,VbTab
        add hl,de
        ld e,(hl)
VbQ     ld a,0                      ;   четверть: 0 +q, 1 глубина-q, 2 -q, 3 q-глубина
        ld c,a
        ld a,e
        bit 0,c
        jr z,VbQ0
VbDp    ld a,0
        sub e
VbQ0    ld e,a
        ld d,0
        bit 1,c
        jr z,VbP
        xor a
        sub e
        ld e,a
        sbc a,a
        ld d,a
VbP     ld (VO+1),de
VbR     ld a,0                      ;   тиков на шаг
VbSt    ld (VbC+1),a
VbEnd
ArG     jr ArEnd                    ; C арпеджио: раз в ArD тиков шаг (нота, +X, +Y)
ArC     ld a,0
        dec a
        jr nz,ArSt
ArF     ld a,0
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (ArF+1),a
        or a
        jr z,ArS
        dec a
ArX     ld a,0
        jr z,ArS
ArY     ld a,0
ArS     ld (ARS+1),a
ArD     ld a,0
ArSt    ld (ArC+1),a
ArEnd
B3      ld a,0                      ; громкость: C - флаги строки
        ld c,a
        bit IRB_SLIDE,c             ;   слайд амплитуды -15..15
        jr z,SlNo
        ld a,(SLA+1)
        bit IRB_SLIDE_DOWN,c
        jr nz,SlDn
        cp 15
        jr z,SlNo
        inc a
        jr SlSv
SlDn    cp -15
        jr z,SlNo
        dec a
SlSv    ld (SLA+1),a
SlNo    ld a,c                      ;   амплитуда + слайд, в 0..15
        and #0F
SLA     add a,0
        jp p,$+4
        xor a
        cp 16
        jr c,$+4
        ld a,15
Vol     add a,15*16                 ;   + громкость канала * 16 - по таблице
        ld l,a
        ld h,high Vol_T
        ld b,(hl)                   ; B - громкость
        ld a,(Song_EnvMode)         ; PT: смещение огибающей - в сумму чипа (строки
        or a                        ;   с выключенным шумом)
        jr z,EOn
B0      ld a,0
        bit 6,a
        jr z,EOn
        call EOffs
        ld hl,Pc_ESum
        add a,(hl)
        ld (hl),a
EOn     bit 6,c                     ; огибающая: включена в строке и в канале
        jr z,VOut
EG      jr VOut
        set 4,b
        ld a,(Song_EnvMode)         ;   FT: период - этот канал
        or a
        jr nz,VOut
        call EOffs
        ld e,a                      ;   база - смещение + слайд чипа
        rla
        sbc a,a
        ld d,a
        ld hl,(Pl_EnvBase+CHIP*2)
        or a
        sbc hl,de
        ld de,(Es_Ofs+CHIP*2)
        add hl,de
        ld (REGS+11),hl
VOut
        ld a,b
Wv2     ld (REGS+8+IDX),a
VsG     jr VsEnd                    ; 7 слайд громкости: раз в VsD тиков
VsC     ld a,0
        dec a
        jr nz,VsSt
        ld a,(Vol+1)                ;   громкость (*16) + вверх - вниз, в 0..15
        rrca
        rrca
        rrca
        rrca
        and #0F
VsU     add a,0
VsDn    sub 0
        jp p,$+4
        xor a
        cp 16
        jr c,$+4
        ld a,15
        add a,a
        add a,a
        add a,a
        add a,a
        ld (Vol+1),a
VsD     ld a,0
VsSt    ld (VsC+1),a
VsEnd
        jp OoG                      ; 6 вкл / выкл - после вывода

; Смещение огибающей строки + накопленное (бит 7 громкости, C - сохранить) -> A
EOffs
B4      ld a,0
EA      add a,0
        bit 7,c
        ret z
        ld (EA+1),a
        ret

; HL - блок сэмпла, A - строка (за концом - последняя): указатель, счётчик, цикл
InsSet  ld (Is_R),a
        GATE_OFF RiG,RiEnd
        inc hl
        ld c,(hl)                   ; C - цикл
        inc hl
        ld b,(hl)                   ; B - последняя
        inc hl                      ; HL - строка 0
        ld a,b
        ld (ILastV),a
        cp c                        ; цикл за концом - последняя
        jr nc,$+3
        ld c,b
        push hl
        ld a,c
        call Mul5Add
        ld (ILA+1),hl
        ld a,b
        sub c
        inc a
        ld (ILC+1),a
        pop hl
        ld a,(Is_R)
        cp b
        jr c,$+3
        ld a,b
        ld c,a
        call Mul5Add
        ld (IP+1),hl
        ld a,b
        sub c
        inc a
        ld (ICN+1),a
        ret

; HL - блок орнамента, A - строка: так же (строки по 2 байта); орнамент - вкл
OrnSet  ld (Is_R),a
        GATE_OFF RoG,RoEnd
        GATE_ON OG
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,b
        ld (OLastV),a
        cp c
        jr nc,$+3
        ld c,b
        push hl
        ld a,c
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld (OLA+1),hl
        ld a,b
        sub c
        inc a
        ld (OLC+1),a
        pop hl
        ld a,(Is_R)
        cp b
        jr c,$+3
        ld a,b
        ld c,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld (OP+1),hl
        ld a,b
        sub c
        inc a
        ld (OCN+1),a
        ret

;-------- Роу (паттерн - в окне 3): HL - клетка канала
Rw      ld a,(hl)                   ; пустая клетка - ничего
        inc l
        or (hl)
        inc l
        or (hl)
        inc l
        or (hl)
        inc l
        or (hl)
        inc l
        inc l
        or (hl)
        inc l
        inc l
        or (hl)
        ret z
        ld a,l
        sub CH_CMD+2
        ld l,a
        xor a                       ; что зависит от ноты - запомнить
        ld (Pr_GCmd),a
        ld (Pr_SOfs),a
        ld (Pr_OOfs),a
        ld (Pr_NDly),a
        ld (Pr_NewIns),a
        ld (Pr_NewOrn),a
        ld (Pr_Oo),a
        ld (Pr_Arp),a
        ld (Pr_Vib),a
        ld (Pr_SlSet),a
        push hl                     ; новая форма огибающей - слайд огибающей чипа стоп и с нуля:
        inc l                       ;   до команд (9 / A этой же строки - после, как PT3)
        inc l
        ld a,(hl)
        or a
        jr z,RNoEs
        cp 15
        call nz,m_esr
RNoEs   pop hl
        push hl                     ; команды
        ld a,l
        add a,CH_CMD
        ld l,a
        call Cmd
        inc l
        call Cmd
        pop hl
        inc l                       ; сэмпл
        ld a,(hl)
        or a
        call nz,RSmp
        inc l                       ; форма огибающей
        ld a,(hl)
        or a
        call nz,REnv
        inc l                       ; орнамент
        ld a,(hl)
        or a
        call nz,ROrn
        inc l                       ; громкость
        ld a,(hl)
        or a
        jr z,RNoV
        and #0F
        add a,a
        add a,a
        add a,a
        add a,a
        ld (Vol+1),a
RNoV    ld a,l
        sub CH_VOLUME
        ld l,a
        ld a,(hl)                   ; нота
        or a
        jr z,RNoNote
        cp NOTE_COUNT+1
        jp nc,ROff
        call Slide                  ; портаменто - от текущей частоты, иначе слайд с нуля
        ld b,a
        ld a,(Pr_Oo)                ; нота снимает 6, если её нет в строке (PT3: COnOff -
        or a                        ;   в группе сброса ноты)
        jr nz,RKeepOo
        GATE_OFF OoG,OoEnd
RKeepOo
        ld a,(Pr_Arp)               ; нота снимает C, если её нет в строке (Bitphase, PSG atarized)
        or a
        jr nz,RKeepAr
        ld (ARS+1),a
        GATE_OFF ArG,ArEnd
RKeepAr
        ld a,(Pr_Vib)               ; и 8, если её нет в строке (Bitphase: _resetChannelEffectsOnNewNote)
        or a
        jr nz,RKeepVb
        ld h,a
        ld l,a
        ld (VO+1),hl
        GATE_OFF VbG,VbEnd
RKeepVb
        ld a,(Pr_SOfs)              ; инструмент и орнамент - со строки (4, 5) или 0
        call Pr_Ofs
        ld (RiR+1),a
        ld a,(Pr_OOfs)
        call Pr_Ofs
        ld (RoR+1),a
        ld a,(Pr_NDly)              ; F2: нота - через столько тиков
        or a
        jr z,RNow
        ld (DlC+1),a
        ld a,b
        ld (DlN+1),a
        GATE_ON DlG
        jp Post
RNow    ld a,b
        call NoteGo
        jp Post
RNoNote ld a,(Pr_SOfs)              ; без ноты: 4 или новый сэмпл - со строки
        or a
        jr nz,RNs
        ld a,(Pr_NewIns)
        or a
        jr z,RNo2
        ld a,(ILastV)               ;   новый сэмпл - с той строки, что звучала
        inc a
        ld hl,ICN+1
        sub (hl)
        jr RNs2
RNs     dec a
RNs2    ld (RiR+1),a
        GATE_ON RiG
RNo2    ld a,(Pr_OOfs)              ;   орнамент: 5 - со строки; новый орнамент или огибающая
        or a                        ;     в строке - с начала (как PT3)
        jr nz,RNo
        ld a,(Pr_NewOrn)
        or a
        jp z,Post
        xor a
        jr RNo4
RNo     dec a
RNo4    ld (RoR+1),a
        ld a,(RoB+2)                ;   орнамент выключен - нечего
        or a
        jp z,Post
        GATE_ON RoG
        jp Post

; R-- и т.п.: канал молчит, команды - все стоп
ROff    xor a
        ld (NN+1),a
        ld (ARS+1),a
        ld h,a
        ld l,a
        ld (GOF+1),hl
        ld (VO+1),hl
        ld hl,Silent
        ld (SndJ+1),hl
        GATE_OFF GG,GEnd
        GATE_OFF OoG,OoEnd
        GATE_OFF VsG,VsEnd
        GATE_OFF VbG,VbEnd
        GATE_OFF ArG,ArEnd
        GATE_OFF DlG,DlEnd
        ret

; Нота A (1..96) стартует: инструмент и орнамент - со строк RiR / RoR, накопления - с нуля
NoteGo  ld (NN+1),a
        dec a
        ld (NT+1),a
        ld hl,Snd
        ld (SndJ+1),hl
        GATE_OFF DlG,DlEnd
        GATE_ON RiG
        ld a,(RoB+2)                ; орнамент есть - с начала
        or a
        jr z,NgNoO
        GATE_ON RoG
NgNoO   xor a
        ld h,a
        ld l,a
        ld (TA+1),hl
        ld (NA+1),a
        ld (EA+1),a
        ld (SLA+1),a
        ld (ONA+1),a
        ld (ONZ+1),a
        ld (ArF+1),a                ; арпеджио - с ноты
        ld (ARS+1),a
        ld a,(ArD+1)
        ld (ArC+1),a
        ret

;-------- Нота A (1..96): в строке портаменто - смещение = текущая частота - частота новой
; ноты (едем от того, что звучит, как VT); иначе слайд - с нуля. A сохраняет
Slide   ld b,a
        ld a,(Pr_GCmd)
        and #F0
        cp CMD_PORTA<<4
        jr nz,SlZ
NN      ld a,0                      ; звучащая нота - база (0 - тишина: ехать не от чего)
        or a
        jr z,SlZ
        call Pl_NotePer             ; цель смещения: P(новая) - P(старая)
        push hl
        ld a,b
        call Pl_NotePer
        pop de
        or a
        sbc hl,de
        ld (TD+1),hl
        ld a,b                      ; к какой ноте
        ld (SlT+1),a
        ld a,1
        ld (Pr_SlSet),a
        ld a,(NN+1)                 ; стартует база (старая), смещение - как было (PT3)
        ret
SlZ     ld hl,0
        ld (GOF+1),hl
        GATE_OFF GG,GEnd
        ld a,b
        ret

;-------- После ноты: глисс и портаменто строки. Задержка 0 у глисса - один сдвиг на первом тике (VT2, Bitphase),
; у портаменто - как 1; параметр 0 - стоп (набежавшее смещение остаётся)
Post    ld a,(Pr_GCmd)
        or a
        ret z
        ld c,a
        and #0F
        ld (GD+1),a
        ld (GC+1),a
        ld a,(Pr_GPar)
        or a
        jr nz,PoGo
        GATE_OFF GG,GEnd
        ret
PoGo    ld e,a
        ld d,0
        ld a,c
        and #F0
        cp CMD_PORTA<<4
        jr z,PoPt
        cp CMD_GLIS_DOWN<<4         ; частота вниз - период растёт: шаг плюс
        call nz,Neg_DE              ; вверх - минус
        ld (GS+1),de
        ld a,(GD+1)
        or a
        jr nz,PoGl
        inc a                       ; задержка 0: один шаг на первом тике (после вывода), потом стоп
        ld (GC+1),a
PoGl    GATE_OFF GM,GDl             ; глисс - без проверки "доехали"
        GATE_ON GG
        ret
PoPt    ld a,(Pr_SlSet)             ; портаменто без ноты в строке - к базе (цель 0), как PT3
        or a
        jr nz,PoPt1
        ld h,a
        ld l,a
        ld (TD+1),hl
        ld a,(NN+1)
        ld (SlT+1),a
        or a                        ;   молчит - ехать не от чего
        jr z,PoOff
PoPt1   ld a,(GD+1)                 ; задержка 0 - как 1
        or a
        jr nz,PoPd
        inc a
        ld (GD+1),a
        ld (GC+1),a
PoPd    ld hl,(GOF+1)               ; смещение - цель: уже там - нота цели
        ld bc,(TD+1)
        or a
        sbc hl,bc
        jp z,PtEnd
        bit 7,h                     ; шаг - к цели: смещение больше - шаг минус
        call z,Neg_DE
        ld (GS+1),de
        GATE_ON GM
        GATE_ON GG
        ret
PoOff   GATE_OFF GG,GEnd
        ret

; Портаменто доехало: нота - цель, смещение 0, стоп
PtEnd   ld hl,0
        ld (GOF+1),hl
SlT     ld a,0
        ld (NN+1),a
        dec a
        ld (NT+1),a
        GATE_OFF GG,GEnd
        ret

;-------- Команда: HL - её байт 0 (на выходе - на параметре). Обработчик - по коду из
; Pl_CmdJT: C - байт 0, E - параметр
Cmd     ld c,(hl)
        inc l
        ld e,(hl)
        ld a,c
        and #F0
        ret z
        push hl
        rrca
        rrca
        rrca
        add a,low (Pl_CmdJT+m_n*32)
        ld l,a
        ld h,high Pl_CmdJT
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        call Pl_JpHL
        pop hl
        ret

CGl     ld a,c                      ; 1, 2, 3 - после ноты (Post)
        ld (Pr_GCmd),a
        ld a,e
        ld (Pr_GPar),a
        GATE_OFF OoG,OoEnd          ;   слайды снимают 6
        ret
CSo     inc e                       ; 4 / 5 - при ноте (+1: 0 - нет)
        ld a,e
        ld (Pr_SOfs),a
        ret
COo     inc e
        ld a,e
        ld (Pr_OOfs),a
        ret
C6      GATE_OFF OoG,OoEnd          ; 6 вкл / выкл: фаза как есть, счёт - со "вкл"; 0 - стоп
        GATE_OFF GG,GEnd            ;   6 снимает слайды
        ld hl,0                     ;   и их смещение (как PT3)
        ld (GOF+1),hl
        ld a,e
        or a
        ret z
        and #0F                     ;   тиков тишины (0 - потом не включится)
        ld (OoOff+1),a
        ld a,e                      ;   тиков звука (0 - не переключать, как PT3)
        rrca
        rrca
        rrca
        rrca
        and #0F
        ret z
        ld (OoOn+1),a
        ld (OoC+1),a
        GATE_ON OoG
        ld a,1                      ;   в строке есть - нота её не снимет
        ld (Pr_Oo),a
        ret
C7      GATE_OFF VsG,VsEnd          ; 7 слайд громкости: вверх X, вниз Y; 0 - стоп
        ld a,e
        or a
        ret z
        and #0F
        ld (VsDn+1),a
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (VsU+1),a
        ld a,c                      ;   задержка (0 - как 1)
        and #0F
        jr nz,$+3
        inc a
        ld (VsD+1),a
        ld (VsC+1),a
        GATE_ON VsG
        ret
C8      GATE_OFF VbG,VbEnd          ; 8 вибрато (Bitphase): раз в D тиков шаг, скорость X - шагов в четверти
        ld hl,0                     ;   периода, глубина Y - размах в единицах периода (0 - стоп)
        ld (VO+1),hl
        ld a,e
        and #0F
        ret z
        ld (VbDp+1),a
        ld a,c                      ;   тиков на шаг (0 - как 1)
        and #0F
        jr nz,$+3
        inc a
        ld (VbR+1),a
        ld (VbC+1),a
        ld a,e                      ;   скорость (0 - как 1)
        rrca
        rrca
        rrca
        rrca
        and #0F
        jr nz,$+3
        inc a
        ld (VbS+1),a
        ld b,a                      ;   таблица канала: шаг * глубина / скорость, шаги 0..скорость-1
        ld c,a
        ld d,0
        ld hl,VbTab
C8M     ld a,d
        ld e,-1
C8D     inc e
        sub c
        jr nc,C8D
        ld (hl),e
        inc hl
        ld a,(VbDp+1)
        add a,d
        ld d,a
        djnz C8M
        xor a                       ;   с начала: позиция 0
        ld (VbK+1),a
        ld (VbQ+1),a
        inc a                       ;   в строке - нота её не снимет
        ld (Pr_Vib),a
        GATE_ON VbG
        ret
VbTab   ds 15                       ; вибрато: шаг * глубина / скорость
C9      jp m_es                     ; 9 / A - слайд огибающей чипа
CC      GATE_OFF ArG,ArEnd          ; C арпеджио: +X, +Y; 0 - стоп
        xor a
        ld (ARS+1),a
        ld a,e
        or a
        ret z
        and #0F
        ld (ArY+1),a
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (ArX+1),a
        ld a,c                      ;   тиков на шаг (0 - как 1)
        and #0F
        jr nz,$+3
        inc a
        ld (ArD+1),a
        ld (ArC+1),a
        xor a
        ld (ArF+1),a
        inc a                       ;   в строке - нота её не снимет
        ld (Pr_Arp),a
        GATE_ON ArG
        ret
CF      ld a,c                      ; F: подкод
        and #0F
        cp CMDX_DETUNE
        jr z,CFDet
        cp CMDX_DELAY
        jr z,CFDl
        cp CMDX_RETRIG
        ret nz
        ld a,1                      ;   ретриггер: R13 чипа - ещё раз
        ld (REGS+PR_R13W),a
        ld a,(Wt+1)                 ;   и тон выхода канала - через 0 (как FT 1.15: фаза тона с начала вместе
        rrca                        ;   с огибающей). Выход q = младший байт записи тона / 2 (её правит стерео)
        inc a                       ;   бит выхода: q 0, 1, 2 -> 1, 2, 4
        cp 3
        jr nz,$+4
        ld a,4
        ld hl,REGS+PR_RTN
        or (hl)
        ld (hl),a
        ret
CFDet   ld a,e                      ;   детюн: сдвиг периода, байт со знаком
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (DT+1),hl
        ret
CFDl    ld a,e                      ;   задержка ноты - при ноте
        ld (Pr_NDly),a
        ret

;-------- Поля клетки: A - значение (не 0). HL целы
RSmp    dec a                       ; сэмпл: блок #C000 + (n-1)*384
        ld e,a
        srl a                       ;   старший: #C0 + n + n/2
        add a,e
        add a,#C0
        ld (RiB+2),a
        ld a,e
        rrca                        ;   младший: нечётный - 128
        and #80
        ld (RiB+1),a
        ld a,1
        ld (Pr_NewIns),a
        ret
REnv    ld e,a                      ; огибающая: 15 - выкл, 1..14 - форма (R13); орнамент -
        ld a,1                      ;   с начала (PT3: SETENV / #B0 сбрасывают его позицию)
        ld (Pr_NewOrn),a
        ld a,e
        cp 15
        jr nz,REOn
        GATE_OFF EG,VOut
        ret
REOn    ld (REGS+13),a
        GATE_ON EG
        ld a,1
        ld (REGS+PR_R13W),a
        ret
ROrn    sub 2                       ; орнамент: 1 - нет, 2..17 - блоки 0..15 (по 256)
        jr c,RONo
        add a,#C0+high ORN_BASE
        ld (RoB+2),a
        xor a
        ld (RoB+1),a
        inc a
        ld (Pr_NewOrn),a
        ret
RONo    xor a
        ld (RoB+2),a
        ld (ONS+1),a
        GATE_OFF RoG,RoEnd
        GATE_OFF OG,ONone
        ret

;-------- Сброс: молчит, громкость 15, сэмпл 1, без орнамента и огибающей
Rst     call ROff
        ld a,15*16
        ld (Vol+1),a
        ld hl,#C000
        ld (RiB+1),hl
        xor a
        ld (RoB+2),a
        ld (ONS+1),a
        ld (ILastV),a
        ld (OLastV),a
        ld h,a
        ld l,a
        ld (DT+1),hl
        inc a
        ld (ICN+1),a
        ld (OCN+1),a
        GATE_OFF RiG,RiEnd
        GATE_OFF RoG,RoEnd
        GATE_OFF OG,ONone
        GATE_OFF EG,VOut
        ret

;-------- Для компаратора: в (DE) 5 байт - нота, строки инструмента и орнамента (следующие),
; громкость, слайд амплитуды. DE += 5
View    ld a,(NN+1)
        ld (de),a
        inc de
        ld a,(ILastV)               ; строка: последняя + 1 - строк до конца
        inc a
        ld hl,ICN+1
        sub (hl)
        ld (de),a
        inc de
        ld a,(OLastV)
        inc a
        ld hl,OCN+1
        sub (hl)
        ld (de),a
        inc de
        ld a,(Vol+1)
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (de),a
        inc de
        ld a,(SLA+1)
        ld (de),a
        inc de
        ret
ILastV          db 0                ; последняя строка сэмпла
OLastV          db 0                ;   орнамента
    ENDMODULE
    ENDM

; Слайд огибающей чипа (9 / A): m_name - модуль, m_chip - чип 0 / 1
    MACRO PL_ES m_name, m_chip
    MODULE m_name
;-------- Тик чипа: раз в EsD тиков смещение += шаг
Tk
EsG     jr EsEnd
EsC     ld a,0
        dec a
        jr nz,EsSt
        ld hl,(Es_Ofs+m_chip*2)
EsS     ld de,0
        add hl,de
        ld (Es_Ofs+m_chip*2),hl
EsD     ld a,0
        or a                        ;   задержка 0 - один шаг и стоп (VT2, Bitphase initSlide)
        jr nz,EsSt
        GATE_OFF EsG,EsEnd
        ret
EsSt    ld (EsC+1),a
EsEnd   ret
;-------- 9 / A: C - байт 0 (код, задержка), E - шаг. Вниз - период растёт (как глисс).
; Задержка 0 - один шаг (VT2, Bitphase), шаг 0 - стоп
Set     ld d,0
        ld a,c
        and #F0
        cp CMD_ENV_DOWN<<4
        call nz,Neg_DE
        ld (EsS+1),de
        ld a,c
        and #0F
        ld (EsD+1),a                ;   0 - после шага стоп
        jr nz,$+3
        inc a                       ;   первый шаг - на первом тике
        ld (EsC+1),a
        GATE_ON EsG
        ret
Rst     GATE_OFF EsG,EsEnd
        ld hl,0
        ld (Es_Ofs+m_chip*2),hl
        ret
;-------- Команда колонки Env (как Bitphase): первый тик - в кадре команды, до вывода (задержка 1 - шаг сразу,
; 3 - через два кадра), дальше - тик чипа после вывода
Now     jr Tk
    ENDMODULE
    ENDM

        PL_CHAN c0,0,es0.Set,es0.Rst
        PL_CHAN c1,1,es0.Set,es0.Rst
        PL_CHAN c2,2,es0.Set,es0.Rst
        PL_CHAN c3,3,es1.Set,es1.Rst
        PL_CHAN c4,4,es1.Set,es1.Rst
        PL_CHAN c5,5,es1.Set,es1.Rst
        PL_ES es0,0
        PL_ES es1,1

; 4 / 5 из строки (строка+1, 0 - нет) -> строка (0 - с начала)
Pr_Ofs  or a
        ret z
        dec a
        ret

; =========================================================================
; КАНАЛЫ -> регистры (страница инструментов в окне 3)
; =========================================================================
Pl_Channels
        ld a,(Pl_InsPage)
        SETPAGE3 a
        ld a,#3F                    ; чип 1: микшер - всё выкл, каналы включат
        ld (Pc_Mix),a
        xor a
        ld (Pc_ESum),a
        call c0.Tk
        call c1.Tk
        call c2.Tk
        ld a,(Pc_Mix)
        ld (Pl_Regs+7),a
        ld a,(Song_EnvMode)         ; PT: период огибающей - после всех каналов чипа
        or a
        ld de,Pl_EnvBase
        ld hl,Pl_Regs+11
        ld bc,Es_Ofs
        call nz,Pl_EPer
        call es0.Tk                 ; 9 / A: шаг слайда огибающей - после вывода (как PT3)
        ld a,(Pl_Chips)             ; только чипы трека
        dec a
        jr z,.end
        ld a,#3F                    ; чип 2
        ld (Pc_Mix),a
        xor a
        ld (Pc_ESum),a
        call c3.Tk
        call c4.Tk
        call c5.Tk
        ld a,(Pc_Mix)
        ld (Pl_Regs2+7),a
        ld a,(Song_EnvMode)
        or a
        ld de,Pl_EnvBase+2
        ld hl,Pl_Regs2+11
        ld bc,Es_Ofs+2
        call nz,Pl_EPer
        call es1.Tk
.end    RESTPAGE3
        jp Fx_Tick                  ; FX каналов - в буфер карты

; PT: (HL) R11/R12 = (DE) база - сумма Pc_ESum (со знаком) + (BC) слайд огибающей
Pl_EPer
        push hl
        ld a,(de)
        ld l,a
        inc de
        ld a,(de)
        ld h,a
        ld a,(Pc_ESum)
        ld e,a
        rla
        sbc a,a
        ld d,a
        or a
        sbc hl,de
        ld a,(bc)
        ld e,a
        inc bc
        ld a,(bc)
        ld d,a
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

;-------- Для компаратора: каналы чипа A - в (DE) по 5 байт (View)
Pl_View
        or a
        jr nz,.c2
        call c0.View
        call c1.View
        jp c2.View
.c2     call c3.View
        call c4.View
        jp c5.View

; =========================================================================
; ВЫВОД В AY: чип 1, чип 2 (TurboSound: выбор - #FF / #FE в #FFFD). Буфер чипа - на границе
; 256: OUT (C),L - номер регистра, OUTI - значение. Стерео - каналы сами пишут в переставленные
; регистры: St_Apply правит в их коде адреса записи тона и громкости и биты микшера
; =========================================================================
St_Mask         db #FF              ; 0 - стерео не трогать (компаратор: эталон играет ABC)
Pl_Out
        ld a,(Pl_Quiet)             ; экспорт PSG - только считать
        or a
        ret nz
        ld a,(St_Mask)              ; стерео сменили - переставить каналы
        ld hl,Song_Stereo
        and (hl)
St_Cur  cp 0
        call nz,St_Apply
        ld a,(Ch_Mute)              ; заглушенные каналы - громкость 0
        or a
        call nz,Mu_Apply
        ld de,#FFC0                 ; D - выбор регистра, E - запись (OUTI: B-1 = #BF)
        ld bc,#FFFD
        ld a,#FF                    ; чип 1
        out (c),a
        ld hl,Pl_Regs
        call Po_Chip
        ld a,(Fx_Card)              ; карта AY FX чипа 1: очередь пакетов
        or a
        ld a,0
        call nz,Fx_Out
        ld a,#FE                    ; чип 2
        ld b,d
        out (c),a
        ld hl,Pl_Regs2
        call Po_Chip
        ld a,(Fx_Card+1)            ;   чипа 2
        or a
        ld a,1
        call nz,Fx_Out
        ld a,#FF                    ; в конце выбран чип 1 (как после сброса)
        ld b,d
        out (c),a
        ret

; HL - буфер чипа (L = 0): R0..R12, R13 - по флагу (запись перезапускает огибающую).
; Ретриггер (маска PR_RTN): сначала тон этих выходов = 0, сразу R13, потом обычный вывод вернёт тон.
; C = #FD, D = #FF, E = #C0
Po_Chip
        ld l,PR_RTN
        ld a,(hl)
        or a
        jr nz,Po_Rt
        ld l,0
Po_Regs
    DUP 13
        ld b,d
        out (c),l
        ld b,e
        outi
    EDUP
        inc l                       ; флаг R13
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        dec l
        ld b,d
        out (c),l
        ld b,e
        outi
        ret

;-------- Ретриггер: тон выходов из маски A = 0 (R2q, R2q+1), R13 - сразу, флаг R13 снят; дальше - обычный вывод
Po_Rt   ld (hl),0                   ; маска - снята
        push hl
        ld l,a                      ; L - маска выходов, H - регистр тона 0, 2, 4
        ld h,0
.q      srl l
        jr nc,.n
        xor a
        ld b,d                      ; R2q = 0
        out (c),h
        ld b,#BF
        out (c),a
        inc h                       ; R2q+1 = 0
        ld b,d
        out (c),h
        ld b,#BF
        out (c),a
        dec h
.n      inc h
        inc h
        ld a,l
        or a
        jr nz,.q
        pop hl
        ld l,13                     ; R13 - сразу: огибающая с начала вместе с тоном
        ld b,d
        out (c),l
        ld b,e
        outi                        ; L -> 14 (флаг R13)
        ld (hl),0                   ;   уже записан - в конце вывода не повторять
        ld l,0
        jp Po_Regs

;-------- Стерео A (0..4): выход q чипа получает канал Po_Maps[режим][q] - в коде этого
; канала: запись тона - в R(2q), громкости - в R(8+q), биты микшера - q и 3+q
St_Apply
        ld (St_Cur+1),a
        ld b,a                      ; каналы режима: Po_Maps + режим*3
        add a,a
        add a,b
        ld hl,Po_Maps
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (St_Map),hl
        ld c,0                      ; C - выход 0..5 (чип 2 - 3..5)
.p      ld a,c                      ; выход в чипе, B - первый канал чипа
        ld b,0
        cp 3
        jr c,$+6
        sub 3
        ld b,3
        ld (St_Q),a
        ld hl,(St_Map)              ; канал: первый + Po_Maps[режим][выход]
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        add a,b
        ld l,a                      ; его адреса правки: St_Tab + канал*10
        add a,a
        add a,a
        add a,l
        add a,a
        ld hl,St_Tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        ld hl,Pl_Regs               ; буфер чипа
        ld a,b
        or a
        jr z,$+5
        ld hl,Pl_Regs2
        ld a,(St_Q)                 ; тон: R(2q)
        add a,a
        ld l,a
        call .put
        ld a,(St_Q)                 ; громкость: R(8+q) - два места
        add a,8
        ld l,a
        call .put
        call .put
        ld a,(St_Q)                 ; микшер: res q,(hl) / res 3+q,(hl) - второй байт #86+8*бит
        add a,a
        add a,a
        add a,a
        add a,#86
        call .pb
        add a,3*8
        call .pb
        inc c
        ld a,c
        cp 6
        jr c,.p
        ret
; HL -> по адресу из (DE); DE += 2
.put    ld a,(de)
        ld (.a+1),a
        inc de
        ld a,(de)
        ld (.a+2),a
        inc de
.a      ld (0),hl
        ret
; A -> байт по адресу из (DE); DE += 2. A, HL целы
.pb     push hl
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        ld (hl),a
        pop hl
        ret
St_Map          dw 0
St_Q            db 0
; Адреса правки каналов: операнды записи тона, громкости (2), второй байт res тона и шума
    MACRO ST_CH m_w, m_v1, m_v2, m_t, m_n
        dw m_w+1, m_v1+1, m_v2+1, m_t+1, m_n+1
    ENDM
St_Tab  ST_CH c0.Wt,c0.Wv1,c0.Wv2,c0.Mt,c0.Mn
        ST_CH c1.Wt,c1.Wv1,c1.Wv2,c1.Mt,c1.Mn
        ST_CH c2.Wt,c2.Wv1,c2.Wv2,c2.Mt,c2.Mn
        ST_CH c3.Wt,c3.Wv1,c3.Wv2,c3.Mt,c3.Mn
        ST_CH c4.Wt,c4.Wv1,c4.Wv2,c4.Mt,c4.Mn
        ST_CH c5.Wt,c5.Wv1,c5.Wv2,c5.Mt,c5.Mn
Po_Maps db 0,1,2, 0,2,1, 1,0,2, 1,2,0, 2,0,1  ; ABC ACB BAC BCA CAB - как в VT (Hd_Stereos)

; =========================================================================
; FX - таймерные эффекты карты AY FX: протокол из 2 регистров (doc/ay-ports-map.md п.5а), строка FX -
; doc/fx-row.md. Карта есть, если ответила на ключ (Fx_Detect, по чипу) - иначе ей ничего не шлём.
; Нота с инструментом - его FX с первой строки (Fx_Start из InsSet); тик - строка FX канала дальше
; (длина, цикл), строка сменилась - пакет ROW в очередь чипа; новая нота - RESET (маска каналов).
; Очередь - в карту в начале следующего тика вместе с регистрами AY (Fx_Out). Таблицы - все
; непустые при старте (Fx_Tables), правка в редакторе - одна (Fx_TabDirty, коре).
; Канал карты = выход AY: стерео переставляет каналы (Po_Maps).
; =========================================================================
FC_NUM          equ 0               ; номер FX (0 - нет)
FC_NEW          equ 1               ; 1 - начать с первой строки (новая нота)
FC_ROW          equ 2               ; текущая строка
FC_SENT         equ 3               ; строка, отправленная в карту (#FF - никакая)
FC_ON           equ 4               ; 1 - у карты на канале FX включён
FC_END          equ 5               ; заголовок FX: последняя строка
FC_LOOP         equ 6               ;   строка цикла
FC_SW           equ 7               ;   форма свипа, фаза, флаги (3 байта - хвост пакета ROW)
FC_SIZE         equ 16
Fx_Ch           ds FC_SIZE*CHANNELS
Fx_Card         db 0,0              ; карта на чипе 1 / 2
FQ_MAX          equ 96              ; очередь пакетов чипа на тик: 3 ROW + RESET + TABLE = 77
Fx_Q1           ds FQ_MAX
Fx_Q2           ds FQ_MAX
Fx_QN           db 0,0              ; байт в очереди чипа 1 / 2
Fq_Ptr          dw 0                ; куда класть (очередь текущего чипа)
Fq_Cnt          dw 0                ; её счётчик
Fx_Rst          db 0                ; маска RESET (каналы карты) текущего чипа

;-------- Есть ли карта: на каждом чипе ключ и чтение #C0 ('T'), потом закрыть
Fx_Detect
        ld a,#FF
        call .chip
        ld (Fx_Card),a
        ld a,#FE
        call .chip
        ld (Fx_Card+1),a
        ld hl,Fx_Card               ; для шапки (коре): есть хоть на одном
        or (hl)
        ld (Hw_Fx),a
        ld bc,#FFFD                 ; выбран чип 1 (как после сброса)
        ld a,#FF
        out (c),a
        ret

; A - чип -> A: 1 - карта есть
.chip   ld bc,#FFFD
        out (c),a
        jp Ayfx_Detect

;-------- TurboSound есть? R0 чипа 1 = #AA, чипа 2 = #55; прочитать оба: #AA и #55 - чипов два (без TS выбор
; #FE ничего не выбирает, обе записи - в один чип). Итог - Hw_Ts (коре)
Ts_Detect
        ld bc,#FFFD
        ld a,#FF                    ; чип 1, R0 = #AA
        out (c),a
        xor a
        out (c),a
        ld b,#BF
        ld a,#AA
        out (c),a
        ld b,#FF                    ; чип 2, R0 = #55
        ld a,#FE
        out (c),a
        xor a
        out (c),a
        ld b,#BF
        ld a,#55
        out (c),a
        ld b,#FF                    ; чип 1, R0 - прочитать
        ld a,#FF
        out (c),a
        xor a
        out (c),a
        in a,(c)
        cp #AA
        ld a,0
        jr nz,.set                  ; чип 1 потерял своё - TS нет
        ld a,#FE                    ; чип 2, R0 - прочитать
        out (c),a
        xor a
        out (c),a
        in a,(c)
        cp #55
        ld a,0
        jr nz,.set
        inc a
.set    ld (Hw_Ts),a
        ld a,#FF                    ; снова чип 1 (как после сброса), R0
        out (c),a
        xor a
        out (c),a
        xor a                       ; R0 чипа 1 - 0 (дальше всё равно пишет плеер)
        ld b,#BF
        out (c),a
        ret

;-------- Обмен с картой (ключ, закрыть, поток, опознание, отправка) и коды пакетов - общий SDK
    include "sdk/trinity_ay.asm"

;-------- Канал A (0..5) -> IX - его состояние. DE сохраняет
Fx_IX   push de
        add a,a
        add a,a
        add a,a
        add a,a                     ; *FC_SIZE
        ld e,a
        ld d,0
        ld ix,Fx_Ch
        add ix,de
        pop de
        ret
    ASSERT FC_SIZE == 16

;-------- Инструмент канала A начался (InsSet): HL - его блок (окно 3) -> номер его FX, с первой строки
Fx_Start
        push af
        ld de,INS_FX
        add hl,de
        ld e,(hl)
        pop af
        call Fx_IX
        ld (ix+FC_NUM),e
        ld (ix+FC_NEW),1
        ret

;-------- Стоп (Pl_Mute): у карты все каналы - "FX выкл" (строка нулей), каналы без FX
Fx_Mute
        ld hl,Fx_Ch
        ld b,FC_SIZE*CHANNELS
.z      ld (hl),0
        inc hl
        djnz .z
        xor a                       ; чип 1, чип 2
        call .chip
        ld a,1
.chip   ld (Fm_Chip),a
        ld e,a
        ld d,0
        ld hl,Fx_Card
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld a,(Fm_Chip)
        call Fq_Sel
        xor a
.q      ld (Fm_Q),a                 ; ROW: код, канал, 17 нулей
        ld a,AYFX_P_ROW
        call Fq_Put
        ld a,(Fm_Q)
        call Fq_Put
        ld b,19-2
.n      xor a
        call Fq_Put
        djnz .n
        ld a,(Fm_Q)
        inc a
        cp 3
        jr c,.q
        ret
Fm_Chip         db 0
Fm_Q            db 0

;-------- Очередь чипа A (0 / 1) - текущая: Fq_Ptr - на конец, Fq_Cnt - её счётчик
Fq_Sel
        ld hl,Fx_QN
        ld e,a
        ld d,0
        add hl,de
        ld (Fq_Cnt),hl
        ld a,(hl)
        ld hl,Fx_Q1
        dec e
        jr nz,$+5
        ld hl,Fx_Q2
        ld e,a
        add hl,de
        ld (Fq_Ptr),hl
        ret

;-------- A - байт в текущую очередь (полная - мимо). Портит HL; BC, DE сохраняет
Fq_Put
        push af
        ld hl,(Fq_Cnt)
        ld a,(hl)
        cp FQ_MAX
        jr nc,.full
        inc (hl)
        ld hl,(Fq_Ptr)
        pop af
        ld (hl),a
        inc hl
        ld (Fq_Ptr),hl
        ret
.full   pop af
        ret

;-------- Тик (после каналов): строки FX каналов -> пакеты в очереди чипов
Fx_Tick
        ld a,(Fx_Card)              ; карты нет - нечего делать
        ld hl,Fx_Card+1
        or (hl)
        ret z
        ld a,(Pl_InsPage)           ; страница таблиц и заголовков FX - инструменты, орнаменты, строки FX, она (PAGES_PER_SONG)
        add a,3
        SETPAGE3 a
        call Fx_Heads               ; новые ноты: заголовки FX каналов
        call Fx_TabEdit             ; таблица, правленная в редакторе - в карту
        call Fx_RowEdit             ; строка, правленная в редакторе - каналам заново
        ld a,(Pl_InsPage)           ; строки FX - за инструментами и орнаментами
        add a,2
        SWAPPAGE 3,a
        xor a                       ; чип 1: каналы 0..2
        call .chip
        ld a,1                      ; чип 2: каналы 3..5
        call .chip
        RESTPAGE3
        ret
.chip   ld (Ft_Chip),a
        ld e,a
        ld d,0
        ld hl,Fx_Card
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld a,(Ft_Chip)
        call Fq_Sel
        xor a
        ld (Fx_Rst),a
        ld (Ft_C),a
.ch     ld a,(Ft_Chip)              ; канал плеера = чип*3 + C
        ld b,a
        add a,a
        add a,b
        ld hl,Ft_C
        add a,(hl)
        call Fx_IX
        call Fx_Ch_Tick
        ld hl,Ft_C
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.ch
        ld a,(Fx_Rst)               ; новые ноты - RESET после строк
        or a
        ret z
        ld a,AYFX_P_RESET
        call Fq_Put
        ld a,(Fx_Rst)
        jp Fq_Put
Ft_Chip         db 0
Ft_C            db 0                ; канал в чипе 0..2

;-------- Канал IX (C в чипе - Ft_C): строка FX дальше; сменилась - ROW в очередь. Окно 3 - строки FX
Fx_Ch_Tick
        ld a,(ix+FC_NUM)
        or a
        jr z,.nofx
        call Mu_Is                  ; заглушён - как без FX
        jr z,.fx
.nofx
        ld a,(ix+FC_ON)             ; FX нет: был у карты - выключить (строка нулей)
        or a
        ret z
        ld (ix+FC_ON),0
        ld (ix+FC_SENT),#FF         ; снова включат (mute снят) - строку заново
        call Fx_Card_Ch
        ld a,AYFX_P_ROW
        call Fq_Put
        ld a,c
        call Fq_Put
        ld b,19-2
.z      xor a
        call Fq_Put
        djnz .z
        ret
.fx     ld a,(ix+FC_NEW)
        or a
        jr z,.next
        ld (ix+FC_NEW),0            ; новая нота: строка 0, RESET
        ld (ix+FC_ROW),0
        ld (ix+FC_SENT),#FF
        call Fx_Card_Ch
        ld a,1                      ; бит канала карты
        inc c
.b      dec c
        jr z,.bs
        add a,a
        jr .b
.bs     ld hl,Fx_Rst
        or (hl)
        ld (hl),a
        jr .send
.next   ld a,(ix+FC_ROW)            ; следующая строка: за последней - цикл
        cp (ix+FC_END)
        inc a
        jr c,$+5
        ld a,(ix+FC_LOOP)
        ld (ix+FC_ROW),a
.send   ld a,(ix+FC_ROW)            ; та же строка, что у карты - ничего
        cp (ix+FC_SENT)
        ret z
        ld (ix+FC_SENT),a
        ld (ix+FC_ON),1
        call Fx_Card_Ch             ; ROW: код, канал карты, строка 14 байт, свип 3 байта
        ld a,AYFX_P_ROW
        call Fq_Put
        ld a,c
        call Fq_Put
        ld a,(ix+FC_NUM)            ; строка: #C000 + (n-1)*512 + r*16
        dec a
        add a,a
        add a,#C0
        ld d,a
        ld a,(ix+FC_ROW)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,d
        ld d,a
        ld e,l
        ld b,FXR_SIZE-2             ; 14 байт (2 запаса не шлём)
.r      ld a,(de)
        call Fq_Put
        inc de
        djnz .r
        ld a,(ix+FC_SW)
        call Fq_Put
        ld a,(ix+FC_SW+1)
        call Fq_Put
        ld a,(ix+FC_SW+2)
        jp Fq_Put
    ASSERT FXR_BLOCK == 512 && FXR_SIZE == 16

;-------- C = канал карты (выход AY) канала Ft_C: стерео - Po_Maps[режим][q] = канал, ищем q
Fx_Card_Ch
        ld a,(St_Cur+1)             ; раскладка стерео: Po_Maps + режим*3
        ld e,a
        add a,a
        add a,e
        ld hl,Po_Maps
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(Ft_C)
        ld c,0
.f      cp (hl)
        ret z
        inc hl
        inc c
        ld e,a
        ld a,c
        cp 3
        ld a,e
        jr c,.f
        ld c,0
        ret

;-------- Новые ноты: заголовок FX канала (последняя строка, цикл, свип) - в его состояние.
; Окно 3 - страница таблиц и заголовков FX
Fx_Heads
        ld ix,Fx_Ch
        ld b,CHANNELS
.ch     ld a,(ix+FC_NEW)
        or a
        jr z,.n
        ld a,(ix+FC_NUM)
        or a
        jr z,.n
        dec a                       ; #C000 + FXH_BASE + (n-1)*8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#C000+FXH_BASE
        add hl,de
        ld a,(hl)                   ; последняя (не дальше 31)
        and FX_ROWS_MAX-1
        ld (ix+FC_END),a
        inc hl
        ld a,(hl)                   ; цикл (не дальше последней)
        cp (ix+FC_END)
        jr c,$+5
        ld a,(ix+FC_END)
        ld (ix+FC_LOOP),a
        inc hl
        ld a,(hl)                   ; форма, фаза, флаги
        ld (ix+FC_SW),a
        inc hl
        ld a,(hl)
        ld (ix+FC_SW+1),a
        inc hl
        ld a,(hl)
        ld (ix+FC_SW+2),a
.n      ld de,FC_SIZE
        add ix,de
        djnz .ch
        ret
    ASSERT FXH_END == 0 && FXH_LOOP == 1 && FXH_SWSHAPE == 2 && FXH_SWPHASE == 3 && FXH_FLAGS == 4

;-------- FX Fx_RowDirty (правка в редакторе, коре): каналам с этим FX - строку заново (как будто не отправлена)
Fx_RowEdit
        ld a,(Fx_RowDirty)
        cp #FF
        ret z
        ld c,a
        ld a,#FF
        ld (Fx_RowDirty),a
        ld hl,Fx_Ch                 ; HL - FC_NUM канала
        ld de,FC_SIZE
        ld b,CHANNELS
.c      ld a,(hl)
        cp c
        jr nz,.n
        inc hl                      ; FC_SENT = #FF: строку - заново
        inc hl
        inc hl
        ld (hl),#FF
        dec hl
        dec hl
        dec hl
.n      add hl,de
        djnz .c
        ret
    ASSERT FC_NUM == 0 && FC_SENT == 3

;-------- Таблица Fx_TabDirty (правка в редакторе, коре) - TABLE в очереди обоих чипов. Окно 3 - таблицы
Fx_TabEdit
        ld a,(Fx_TabDirty)
        cp #FF
        ret z
        ld (Ft_TN),a
        ld a,#FF
        ld (Fx_TabDirty),a
        xor a
        call .chip
        ld a,1
.chip   ld e,a
        ld d,0
        ld hl,Fx_Card
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld a,e
        call Fq_Sel
        ld a,AYFX_P_TABLE
        call Fq_Put
        ld a,(Ft_TN)
        call Fq_Put
        ld l,a                      ; #C000 + n*16
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#C000
        add hl,de
        ex de,hl
        ld b,FXT_SIZE
.v      ld a,(de)
        call Fq_Put
        inc de
        djnz .v
        ret
Ft_TN           db 0

;-------- Старт (Pl_Reset): все непустые таблицы трека - в карту каждого чипа (TABLE), очереди - пустые
Fx_Tables
        xor a
        ld (Fx_QN),a
        ld (Fx_QN+1),a
        ld a,(Fx_Card)
        ld hl,Fx_Card+1
        or (hl)
        ret z
        ld a,(Pl_InsPage)
        add a,3
        SETPAGE3 a
        ld c,#FD
        ld a,(Fx_Card)
        or a
        ld a,#FF
        call nz,.chip
        ld a,(Fx_Card+1)
        or a
        ld a,#FE
        call nz,.chip
        ld b,#FF                    ; выбран чип 1
        ld a,#FF
        out (c),a
        RESTPAGE3
        ret
.chip   ld b,#FF
        out (c),a
        call Ayfx_Key
        call Ayfx_Stream
        ld hl,#C000                ; таблица n - #C000 + n*16
.t      push hl
        ld e,FXT_SIZE               ; пустая (нули) - не шлём
        xor a
.o      or (hl)
        inc hl
        dec e
        jr nz,.o
        or a                        ; A - все байты через OR
        pop hl
        jr z,.nx
        ld b,#BF
        ld a,AYFX_P_TABLE
        out (c),a
        ld a,l                      ; номер = (HL - #C000) / 16
        rrca
        rrca
        rrca
        rrca
        and 15
        ld e,a
        ld a,h
        sub #C0
        add a,a
        add a,a
        add a,a
        add a,a
        or e
        out (c),a
        push hl
        ld e,FXT_SIZE
.v      ld a,(hl)
        out (c),a
        inc hl
        dec e
        jr nz,.v
        pop hl
.nx     ld de,FXT_SIZE
        add hl,de
        ld a,h
        cp #C0+high (FXT_MAX*FXT_SIZE)
        jr c,.t
        jp Ayfx_Close
    ASSERT FXT_MAX*FXT_SIZE == #1000

;-------- В начале тика (Pl_Out, после регистров чипа): очередь чипа A (0 / 1) - в карту: ключ, поток,
; закрыть. Выбран этот чип; C = #FD; DE сохраняет
Fx_Out
        push de
        ld e,a
        ld d,0
        ld hl,Fx_QN
        add hl,de
        ld a,(hl)
        or a
        jr z,.e
        ld (hl),0
        ld d,a                      ; D - байт
        ld hl,Fx_Q1
        dec e
        jr nz,$+5
        ld hl,Fx_Q2
        call Ayfx_Send
.e      pop de
        ret

;-------- Заглушенные каналы (Ch_Mute, коре): громкость их выхода - 0. Выход - по стерео (Po_Maps)
Mu_Apply
        ld hl,Pl_Regs+8             ; чип 1: каналы 0..2
        ld a,(Ch_Mute)
        call .chip
        ld hl,Pl_Regs2+8            ; чип 2: 3..5
        ld a,(Ch_Mute)
        rrca
        rrca
        rrca
.chip   ld (Mu_M),a
        ld b,0                      ; канал в чипе
.c      ld a,(Mu_M)
        rrca
        ld (Mu_M),a
        jr nc,.n
        ld a,b
        push hl
        call Mu_Out                 ; C - выход
        pop hl
        push hl
        ld a,l
        add a,c
        ld l,a
        ld (hl),0
        pop hl
.n      inc b
        ld a,b
        cp 3
        jr c,.c
        ret
Mu_M            db 0

;-------- A - канал в чипе 0..2 -> C - выход AY (Po_Maps[стерео][q] = канал). Портит A, E, HL
Mu_Out
        ld e,a
        ld a,(St_Cur+1)
        ld l,a
        add a,a
        add a,l
        ld hl,Po_Maps
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        ld c,0
.f      cp (hl)
        ret z
        inc hl
        inc c
        ld e,a
        ld a,c
        cp 3
        ld a,e
        jr c,.f
        ld c,0
        ret

;-------- Канал плеера (чип Ft_Chip, канал Ft_C) заглушён? NZ - да
Mu_Is
        ld a,(Ft_Chip)
        ld b,a
        add a,a
        add a,b
        ld hl,Ft_C
        add a,(hl)
        ld b,a
        inc b
        ld a,(Ch_Mute)
.s      rrca
        djnz .s
        sbc a,a                     ; CF - бит канала
        or a
        ret

player1_end
    ASSERT player1_end <= #8000

; =========================================================================
; ВТОРАЯ СТРАНИЦА (PAGE_PLAYER2, окно 2): ТАБЛИЦЫ
; =========================================================================
    org #8000
player2_start
; =========================================================================
; ТАБЛИЦЫ
; =========================================================================
; Переходы команд паттерна: на канал 16 адресов по коду (CMD_*)
    MACRO CMD_JT m_gl, m_so, m_oo, m_6, m_7, m_8, m_9, m_c, m_f
Jk = 0
    DUP 16
    IF Jk == CMD_GLIS_DOWN || Jk == CMD_GLIS_UP || Jk == CMD_PORTA
        dw m_gl
    ELSEIF Jk == CMD_SMP_OFS
        dw m_so
    ELSEIF Jk == CMD_ORN_OFS
        dw m_oo
    ELSEIF Jk == CMD_ONOFF
        dw m_6
    ELSEIF Jk == CMD_VOL_SLIDE
        dw m_7
    ELSEIF Jk == CMD_VIBRATO
        dw m_8
    ELSEIF Jk == CMD_ENV_DOWN || Jk == CMD_ENV_UP
        dw m_9
    ELSEIF Jk == CMD_SPEED
        dw Pl_CSpd
    ELSEIF Jk == CMD_ARP
        dw m_c
    ELSEIF Jk == CMD_EXT
        dw m_f
    ELSE
        dw Pl_Ret
    ENDIF
Jk = Jk + 1
    EDUP
    ENDM

        ALIGN 256
Pl_CmdJT
        CMD_JT c0.CGl,c0.CSo,c0.COo,c0.C6,c0.C7,c0.C8,c0.C9,c0.CC,c0.CF
        CMD_JT c1.CGl,c1.CSo,c1.COo,c1.C6,c1.C7,c1.C8,c1.C9,c1.CC,c1.CF
        CMD_JT c2.CGl,c2.CSo,c2.COo,c2.C6,c2.C7,c2.C8,c2.C9,c2.CC,c2.CF
        CMD_JT c3.CGl,c3.CSo,c3.COo,c3.C6,c3.C7,c3.C8,c3.C9,c3.CC,c3.CF
        CMD_JT c4.CGl,c4.CSo,c4.COo,c4.C6,c4.C7,c4.C8,c4.C9,c4.CC,c4.CF
        CMD_JT c5.CGl,c5.CSo,c5.COo,c5.C6,c5.C7,c5.C8,c5.C9,c5.CC,c5.CF
        ALIGN 256
NoteT   ds NOTE_COUNT*2             ; периоды нот трека (Pl_Song_Info: из Note_175 / Note_177)
        ALIGN 256
Vol_T   ds 256                      ; громкость канала * амплитуда (Pl_VolTab)

; Периоды нот C-1..B-8, равномерный строй A-4 = 440 Гц: период = частота чипа / (16 * f).
; Две таблицы - по частоте чипа (Tune в шапке, SH_TUNING): 0 - 1.75 МГц, 1 - 1.7734 МГц.
; Числа - колонки Ideal_* из trackers/vt/ToneTables.csv (кривые таблицы PT3 не берём)
Note_175
        dw 3344,3157,2980,2812,2655,2506,2365,2232,2107,1989,1877,1772
        dw 1672,1578,1490,1406,1327,1253,1182,1116,1053,994,939,886
        dw 836,789,745,703,664,626,591,558,527,497,469,443
        dw 418,395,372,352,332,313,296,279,263,249,235,221
        dw 209,197,186,176,166,157,148,140,132,124,117,111
        dw 105,99,93,88,83,78,74,70,66,62,59,55
        dw 52,49,47,44,41,39,37,35,33,31,29,28
        dw 26,25,23,22,21,20,18,17,16,16,15,14
Note_177
        dw 3389,3199,3019,2850,2690,2539,2397,2262,2135,2015,1902,1795
        dw 1695,1599,1510,1425,1345,1270,1198,1131,1068,1008,951,898
        dw 847,800,755,712,673,635,599,566,534,504,476,449
        dw 424,400,377,356,336,317,300,283,267,252,238,224
        dw 212,200,189,178,168,159,150,141,133,126,119,112
        dw 106,100,94,89,84,79,75,71,67,63,59,56
        dw 53,50,47,45,42,40,37,35,33,31,30,28
        dw 26,25,24,22,21,20,19,18,17,16,15,14

player_end
    ASSERT player_end <= #C000

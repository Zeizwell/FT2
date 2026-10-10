; =========================================================================
; ПЛЕЕР FT2, черновик v0 (doc/player.md). Страница PAGE_PLAYER, окно 1 (#4000).
; =========================================================================
; IM1 первым делом: коре ставит эту страницу в окно 1 и зовёт PLAYER_TICK.
; Основной цикл командует через SV_PLAY_CMD (+ CPOS / CROW), плеер сам ведёт
; позицию, роу, тики и скорость и отдаёт их в SV_PLAY_*.
; Данные - в окно 2 на время чтения (SETPAGE2 / RESTPAGE2):
;   страница трека (SV_PLAY_SONG): ордер, каталог паттернов, скорость, страница
;   инструментов; страница паттерна; страница инструментов и орнаментов.
; v0: ноты, инструменты и орнаменты (формат FTC), громкость, огибающая, шум,
; 2 чипа. Команды паттерна - только скорость (CMD_SPEED). Таблица нот - 1.75 МГц.
; =========================================================================
    org #4000
player_start
        jp Pl_Init                  ; PLAYER_INIT
        jp Pl_Tick                  ; PLAYER_TICK
        jp Pl_Mute                  ; заглушить оба чипа

CHANNELS        equ 6

; Состояние канала (CS_*), по CS_SIZE на канал
CS_NOTE         equ 0               ; нота 1..96, 0 - молчит
CS_INS          equ 1               ; 2 адрес блока инструмента (в окне 2)
CS_ORN          equ 3               ; 2 адрес блока орнамента
CS_IROW         equ 5               ; строка инструмента
CS_OROW         equ 6               ; строка орнамента
CS_VOL          equ 7               ; громкость канала 0..15
CS_ENV          equ 8               ; 1 - огибающая включена (форма из паттерна)
CS_TACC         equ 9               ; 2 накопление тона
CS_NACC         equ 11              ; накопление шума
CS_EACC         equ 12              ; накопление огибающей
CS_SLIDE        equ 13              ; накопленный слайд громкости
CS_ONACC        equ 14              ; орнамент: накопление ноты
CS_ONZ          equ 15              ; орнамент: накопление шума
CS_SIZE         equ 16

Pl_Ch           ds CHANNELS*CS_SIZE

; Регистры, посчитанные в этом тике (выводятся в начале следующего), по чипу
PR_SIZE         equ 14
Pl_Regs         ds PR_SIZE*2
Pl_R13W         ds 2                ; 1 - писать R13 (перезапуск огибающей)
Pl_EnvBase      ds 2*2              ; период огибающей из паттерна, по чипу
Pl_NoiseBase    ds 2                ; шум из паттерна, по чипу

Pl_PatPage      db 0                ; страница паттерна текущей позиции
Pl_PatLen       db 64
Pl_InsPage      db 0
Pl_NoteTab      dw Note_175         ; таблица нот трека (SH_TUNING)
Pl_OrdLast      db 0
Pl_OrdLoop      db 0
Pl_Chips        db CHIPS_MAX        ; чипов у трека (SH_CHIPS): 1 - только первый
Pl_Looped       db 0                ; 1 - сонг дошёл до конца ордера и ушёл на цикл

;-------- Старт: таблица громкости, тишина
Pl_Init
        call Pl_VolTab
        xor a
        ld (SV_PLAY_STATE),a
        ld (SV_PLAY_CMD),a
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

;-------- Тишина: громкости 0 у обоих чипов, шум и тон выключены
Pl_Mute
        ld hl,Pl_Regs
        ld b,PR_SIZE*2
        xor a
.z      ld (hl),a
        inc hl
        djnz .z
        ld a,#3F
        ld (Pl_Regs+7),a
        ld (Pl_Regs+PR_SIZE+7),a
        xor a
        ld (Pl_R13W),a
        ld (Pl_R13W+1),a
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

;-------- Тишина, каналы с нуля (громкость 15), сведения о треке. Играем трек, который
; сейчас правят (SV_SONG_PAGE): он же - для пробы ноты
Pl_Reset
        ld a,(SV_SONG_PAGE)
        ld (SV_PLAY_SONG),a
        xor a                       ; метка конца трека - заново
        ld (Pl_Looped),a
        call Pl_Mute                ; оба чипа (второго может не быть в треке)
        xor a
        ld hl,Pl_Ch
        ld b,CHANNELS*CS_SIZE
.z      ld (hl),a
        inc hl
        djnz .z
        ld ix,Pl_Ch
        ld b,CHANNELS
        ld de,CS_SIZE
.v      ld (ix+CS_VOL),15
        add ix,de
        djnz .v
        jp Pl_Song_Info             ; скорость, страница инструментов, ордер

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
        ld a,(Pl_Ch+CS_NOTE)        ; по ноте: период тона / 16
        or a
        ret z
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,(Pl_NoteTab)
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,4
.sh     srl h
        rr l
        djnz .sh
        ld (Pl_EnvBase),hl
        ret

;-------- Из страницы трека: скорость, страница инструментов, последняя позиция, цикл
Pl_Song_Info
        ld a,(SV_PLAY_SONG)
        SETPAGE2 a
        ld a,(#8000+SH_SPEED)
        ld (SV_PLAY_SPEED),a
        ld a,(#8000+SH_INS_PAGE)
        ld (Pl_InsPage),a
        ld a,(#8000+SH_TUNING)      ; таблица нот: 0 - 1.75 МГц, иначе 1.7734
        or a
        ld hl,Note_175
        jr z,$+5
        ld hl,Note_177
        ld (Pl_NoteTab),hl
        ld a,(#8000+ORD_LAST)
        ld (Pl_OrdLast),a
        ld a,(#8000+SH_CHIPS)
        ld (Pl_Chips),a
        ld a,(#8000+ORD_LOOP)
        ld (Pl_OrdLoop),a
        RESTPAGE2
        ret

;-------- Позиция SV_PLAY_POS -> страница и длина её паттерна
Pl_Pos_Info
        ld a,(SV_PLAY_SONG)
        SETPAGE2 a
        ld a,(SV_PLAY_POS)
        ld l,a
        ld h,high (#8000+ORD_POS)
        ld a,low (#8000+ORD_POS)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)                   ; номер паттерна
        add a,a                     ; каталог: по PC_SIZE (2)
        ld l,a
        ld h,high (#8000+PAT_CATALOG)
        ld a,(hl)
        ld (Pl_PatPage),a
        inc l
        ld a,(hl)
        ld (Pl_PatLen),a
        RESTPAGE2
        ret
    ASSERT PC_SIZE == 2 && PC_PAGE == 0 && PC_LEN == 1
    ASSERT low (#8000+PAT_CATALOG) == 0

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

; =========================================================================
; РОУ ПАТТЕРНА -> состояние каналов
; =========================================================================
Pr_Chip         db 0

Pl_Row
        ld a,(Pl_PatPage)
        SETPAGE2 a
        ld a,(SV_PLAY_ROW)
        add a,#80                   ; роу = H в окне 2
        ld h,a
        call Pl_Row_Chips
        RESTPAGE2
        ret

;-------- Роу (H, начало - L = Pr_Base) -> состояние каналов всех чипов трека
Pr_Base         db 0                ; L начала роу (паттерн - 0, проба - Prv_Row)
Pl_Row_Chips
        ld ix,Pl_Ch
        xor a
        ld (Pr_Chip),a
.chip   ld a,(Pr_Chip)              ; L - начало чипа
        or a
        ld a,(Pr_Base)
        jr z,$+4
        add a,CHIP_SIZE
        ld l,a
        push hl                     ; заголовок чипа: период огибающей, шум
        ld e,(hl)                   ; CHIP_ENVPER
        inc l
        ld d,(hl)
        ld a,d
        or e
        jr z,.noenv
        ld a,(Pr_Chip)
        add a,a
        push hl
        ld hl,Pl_EnvBase
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
.noenv  pop hl
        push hl
        ld a,l
        add a,CHIP_NOISE
        ld l,a
        ld a,(hl)
        or a
        jr z,.nonz
        and #1F
        ld e,a
        ld a,(Pr_Chip)
        push hl
        ld hl,Pl_NoiseBase
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        pop hl
.nonz   pop hl
        ld a,l                      ; каналы чипа
        add a,CHIP_CH_A
        ld l,a
        ld b,3
.ch     push bc
        push hl
        call Pr_Channel
        pop hl
        ld a,l
        add a,CH_SIZE
        ld l,a
        ld de,CS_SIZE
        add ix,de
        pop bc
        djnz .ch
        ld a,(Pr_Chip)
        inc a
        ld (Pr_Chip),a
        push hl                     ; H - роу паттерна, не портить
        ld hl,Pl_Chips              ; только чипы трека
        cp (hl)
        pop hl
        jr c,.chip
        ret

; HL - канал в роу паттерна, IX - его состояние
Pr_Channel
        push hl                     ; команды: пока только скорость (CMD_SPEED, sdk)
        ld a,l
        add a,CH_CMD
        ld l,a
        ld b,CH_CMDS
.cmd    ld a,(hl)                   ; байт 0: код<<4 | задержка
        and #F0
        cp CMD_SPEED<<4
        jr nz,.ncmd
        inc l                       ; байт 1: тиков на роу (0 - не трогаем)
        ld a,(hl)
        dec l
        or a
        jr z,.ncmd
        ld (SV_PLAY_SPEED),a        ; тик этой роу Pl_Tick возьмёт уже с новой
.ncmd   inc l
        inc l
        djnz .cmd
        pop hl
        push hl                     ; инструмент
        ld a,l
        add a,CH_SAMPLE
        ld l,a
        ld a,(hl)
        or a
        jr z,.noins
        dec a                       ; блок: #8000 + (n-1)*INS_BLOCK (384 = 256+128)
        ld e,a
        srl a                       ; H: #80 + n + n/2 (n*384/256 = n*1.5)
        add a,e
        add a,#80
        ld (ix+CS_INS+1),a
        ld a,e
        and 1
        ld a,0
        jr z,$+4
        ld a,128
        ld (ix+CS_INS),a
.noins  pop hl
        push hl
        ld a,l                      ; орнамент
        add a,CH_ORNAMENT
        ld l,a
        ld a,(hl)                   ; в паттерне - номер+1, 0 - не менять
        or a
        jr z,.noorn
        sub 2                       ; орнамент 1..16 - блок 0..15 (по 256)
        jr c,.orn0                  ; орнамент 0 - пустой: H = 0
        add a,#80+high ORN_BASE
        jr .orns
.orn0   xor a
.orns   ld (ix+CS_ORN+1),a
        ld (ix+CS_ORN),0
.noorn  pop hl
        push hl
        ld a,l                      ; громкость
        add a,CH_VOLUME
        ld l,a
        ld a,(hl)
        or a
        jr z,.novol
        and #0F
        ld (ix+CS_VOL),a
.novol  pop hl
        push hl
        ld a,l                      ; форма огибающей: 1..14 - вкл (R13), 15 - выкл
        add a,CH_ENVSHAPE
        ld l,a
        ld a,(hl)
        or a
        jr z,.noenv
        cp 15
        jr nz,.env
        ld (ix+CS_ENV),0
        jr .noenv
.env    ld (ix+CS_ENV),1
        ld e,a
        ld a,(Pr_Chip)              ; R13 этого чипа
        ld hl,Pl_Regs+13
        or a
        jr z,$+5
        ld hl,Pl_Regs+PR_SIZE+13
        ld (hl),e
        ld a,(Pr_Chip)
        ld hl,Pl_R13W
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),1
.noenv  pop hl
        ld a,(hl)                   ; нота
        or a
        ret z
        cp NOTE_COUNT+1
        jr c,.note
        ld (ix+CS_NOTE),0           ; команда ноты (R-- и т.п.) - канал молчит
        ret
.note   ld (ix+CS_NOTE),a           ; новая нота: инструмент и орнамент - с начала
        xor a
        ld (ix+CS_IROW),a
        ld (ix+CS_OROW),a
        ld (ix+CS_TACC),a
        ld (ix+CS_TACC+1),a
        ld (ix+CS_NACC),a
        ld (ix+CS_EACC),a
        ld (ix+CS_SLIDE),a
        ld (ix+CS_ONACC),a
        ld (ix+CS_ONZ),a
        ld a,(ix+CS_INS+1)          ; инструмента ещё не было - первый
        or a
        ret nz
        ld (ix+CS_INS+1),#80
        ret

; =========================================================================
; КАНАЛЫ: строка инструмента и орнамента -> регистры (страница инструментов в окне 2)
; =========================================================================
Pc_Idx          db 0                ; канал в чипе 0..2
Pc_Mix          db 0                ; микшер чипа (собираем)
Pc_Regs         dw 0                ; регистры чипа
Pc_Note         db 0
Pc_ONoise       db 0
Pc_Chip         db 0

Pl_Channels
        ld a,(Pl_InsPage)
        SETPAGE2 a
        ld ix,Pl_Ch
        xor a
        ld (Pc_Chip),a
.chip   ld hl,Pl_Regs               ; регистры чипа
        ld a,(Pc_Chip)
        or a
        jr z,$+5
        ld hl,Pl_Regs+PR_SIZE
        ld (Pc_Regs),hl
        ld a,#3F                    ; микшер: всё выключено, каналы включат
        ld (Pc_Mix),a
        xor a
        ld (Pc_Idx),a
.ch     call Pc_Channel
        ld de,CS_SIZE
        add ix,de
        ld hl,Pc_Idx
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.ch
        ld hl,(Pc_Regs)             ; микшер в R7
        ld de,7
        add hl,de
        ld a,(Pc_Mix)
        ld (hl),a
        ld a,(Pc_Chip)
        inc a
        ld (Pc_Chip),a
        ld hl,Pl_Chips              ; только чипы трека
        cp (hl)
        jr c,.chip
        RESTPAGE2
        ret

; IX - канал, Pc_Idx - его номер в чипе
Pc_Channel
        ld a,(ix+CS_NOTE)
        or a
        jr nz,.on
        ld a,(Pc_Idx)               ; молчит: громкость канала (R8+канал) - 0
        add a,8
        call Pc_Reg_Addr
        ld (hl),0
        ret
.on     ; --- орнамент: сдвиг ноты и шум
        ld l,(ix+CS_ORN)
        ld h,(ix+CS_ORN+1)
        ld a,h
        or a
        jr nz,.orn
        xor a                       ; орнамента нет
        ld (Pc_ONoise),a
        ld a,(ix+CS_NOTE)
        jr .note
.orn    push hl
        ld a,(ix+CS_OROW)           ; строка: блок + 3 + строка*2
        add a,a
        add a,OH_ROWS
        add a,l
        ld l,a
        ld c,(hl)                   ; C - шум и флаги
        inc l
        ld b,(hl)                   ; B - сдвиг ноты
        pop hl
        call Pc_Next_Orn            ; строка орнамента - следующая
        ld a,c                      ; шум орнамента + накопленный (бит 7 - сохранить)
        and #1F
        add a,(ix+CS_ONZ)
        bit 7,c
        jr z,.onz
        ld (ix+CS_ONZ),a
.onz    ld (Pc_ONoise),a
        ld a,b                      ; сдвиг ноты + накопленный (бит 6 - сохранить)
        add a,(ix+CS_ONACC)
        bit 6,c
        jr z,.ont
        ld (ix+CS_ONACC),a
.ont    add a,(ix+CS_NOTE)
.note   dec a                       ; нота 1..96 -> 0..95, за краями - край
        jp p,.nlo
        xor a
.nlo    cp NOTE_COUNT
        jr c,.nhi
        ld a,NOTE_COUNT-1
.nhi    ld (Pc_Note),a
        ; --- строка инструмента: блок + 3 + строка*5
        ld a,(ix+CS_IROW)
        ld e,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld l,(ix+CS_INS)
        ld h,(ix+CS_INS+1)
        push hl                     ; блок - для перехода строки
        add hl,de
        inc hl
        inc hl
        inc hl
        ld a,(hl)                   ; b0 шум
        ld (Pc_B0),a
        inc hl
        ld e,(hl)                   ; b1, b2 тон
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; b3 громкость
        ld (Pc_B3),a
        inc hl
        ld a,(hl)                   ; b4 огибающая
        ld (Pc_B4),a
        pop hl
        push de
        call Pc_Next_Ins
        pop de
        ; --- тон: 12 бит со знаком (+ накопление) + период ноты
        ld a,d
        ld (Pc_B2),a
        and #0F                     ; знак 12 бит -> 16
        bit 3,a
        jr z,$+4
        or #F0
        ld d,a
        ld l,(ix+CS_TACC)           ; + накопленный (как в PT3: строка без флага его
        ld h,(ix+CS_TACC+1)         ;   не забывает, флаг - сохранить сумму)
        add hl,de
        ld a,(Pc_B2)
        bit 7,a
        jr z,.tnacc
        ld (ix+CS_TACC),l
        ld (ix+CS_TACC+1),h
.tnacc  ex de,hl                     ; DE - смещение тона
        ld a,(Pc_Note)              ; период ноты
        add a,a
        ld l,a
        ld h,0
        ld bc,(Pl_NoteTab)
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ld a,h
        and #0F
        ld h,a
        push hl
        ld a,(Pc_Idx)               ; R0/R1, R2/R3, R4/R5
        add a,a
        call Pc_Reg_Addr
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(Pc_B2)                ; тон включён: бит канала в микшере - 0
        bit 6,a
        jr nz,.toff
        ld a,(Pc_Idx)
        call Pc_Bit
        cpl
        ld hl,Pc_Mix
        and (hl)
        ld (hl),a
.toff   ld a,(Pc_B2)                ; ретриггер огибающей
        bit IRB_RETRIG,a
        call nz,Pc_Retrig
        ; --- шум
        ld a,(Pc_B0)
        bit 6,a
        jr nz,.noff
        and #1F                     ; смещение шума + накопленное
        add a,(ix+CS_NACC)
        ld b,a
        ld a,(Pc_B0)                ; бит 7 - сохранить сумму
        bit 7,a
        ld a,b
        jr z,.nnacc
        ld (ix+CS_NACC),a
.nnacc  ld hl,Pc_ONoise
        add a,(hl)
        ld b,a
        ld a,(Pc_Chip)
        ld hl,Pl_NoiseBase
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        add a,(hl)
        and #1F
        push af
        ld a,6
        call Pc_Reg_Addr
        pop af
        ld (hl),a
        ld a,(Pc_Idx)               ; шум включён: бит 3+канал - 0
        add a,3
        call Pc_Bit
        cpl
        ld hl,Pc_Mix
        and (hl)
        ld (hl),a
.noff   ; --- громкость: амплитуда + слайд, по таблице с громкостью канала
        ld a,(Pc_B3)
        bit 5,a
        jr z,.noslide
        ld b,1
        bit 4,a
        jr z,$+4
        ld b,-1
        ld a,(ix+CS_SLIDE)
        add a,b
        cp 16                       ; -15..15
        jr c,.sok
        cp -15
        jr nc,.sok
        ld a,(ix+CS_SLIDE)
.sok    ld (ix+CS_SLIDE),a
.noslide
        ld a,(Pc_B3)
        and #0F
        add a,(ix+CS_SLIDE)
        jp p,$+4                    ; меньше 0 - 0
        xor a
        cp 16
        jr c,$+4
        ld a,15
        ld e,a
        ld a,(ix+CS_VOL)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,high Vol_T
        ld b,(hl)
        ld a,(Pc_B3)                ; огибающая: в строке включена и канал с огибающей
        bit 6,a
        jr z,.vout
        ld a,(ix+CS_ENV)
        or a
        jr z,.vout
        ld a,b
        or #10
        ld b,a
        call Pc_Env
.vout   ld a,(Pc_Idx)
        add a,8
        call Pc_Reg_Addr
        ld (hl),b
        ret

Pc_B0           db 0
Pc_B2           db 0
Pc_B3           db 0
Pc_B4           db 0

; Период огибающей: база чипа - смещение строки (+ накопление) -> R11/R12
Pc_Env
        push bc
        ld a,(Pc_B4)                ; смещение + накопленное
        add a,(ix+CS_EACC)
        ld e,a
        ld a,(Pc_B3)                ; бит 7 - сохранить сумму
        bit 7,a
        ld a,e
        jr z,.nacc
        ld (ix+CS_EACC),a
.nacc   ld e,a                      ; DE - смещение со знаком
        rla
        sbc a,a
        ld d,a
        ld a,(Pc_Chip)
        add a,a
        ld hl,Pl_EnvBase
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de
        push hl
        ld a,11
        call Pc_Reg_Addr
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        pop bc
        ret

; Ретриггер: R13 этого чипа написать ещё раз
Pc_Retrig
        ld a,(Pc_Chip)
        ld hl,Pl_R13W
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),1
        ret

; A - номер регистра -> HL - его ячейка в регистрах текущего чипа
Pc_Reg_Addr
        ld hl,(Pc_Regs)
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; A - номер бита -> A - маска
Pc_Bit
        ld b,a
        ld a,1
        inc b
.s      dec b
        ret z
        add a,a
        jr .s

; HL - блок инструмента: строка CS_IROW -> следующая (конец +2 -> цикл +1)
Pc_Next_Ins
        inc hl
        ld a,(ix+CS_IROW)
        inc hl
        cp (hl)
        dec hl
        jr nz,.inc
        ld a,(hl)                   ; цикл
        ld (ix+CS_IROW),a
        ret
.inc    inc (ix+CS_IROW)
        ret

; HL - блок орнамента: так же
Pc_Next_Orn
        inc hl
        ld a,(ix+CS_OROW)
        inc hl
        cp (hl)
        dec hl
        jr nz,.inc
        ld a,(hl)
        ld (ix+CS_OROW),a
        ret
.inc    inc (ix+CS_OROW)
        ret

; =========================================================================
; ВЫВОД В AY: чип 0, чип 1 (TurboSound: выбор - #FF / #FE в #FFFD)
; =========================================================================
Pl_Out
        ld a,#FF                    ; чип 1 - #FF, чип 2 - #FE (TurboSound)
        ld hl,Pl_Regs
        ld de,Pl_R13W
        call .chip
        ld a,#FE
        ld hl,Pl_Regs+PR_SIZE
        ld de,Pl_R13W+1
        call .chip
        ld a,#FF                    ; в конце выбран чип 1 (как после сброса)
        ld bc,#FFFD
        out (c),a
        ret
.chip   ld bc,#FFFD                 ; выбрать чип
        out (c),a
        xor a                       ; R0..R12
.r      ld b,#FF
        out (c),a
        ld b,#BF
        push af
        ld a,(hl)
        out (c),a
        pop af
        inc hl
        inc a
        cp 13
        jr c,.r
        ld a,(de)                   ; R13 - только когда надо (запись перезапускает)
        or a
        ret z
        xor a
        ld (de),a
        ld a,13
        ld b,#FF
        out (c),a
        ld b,#BF
        ld a,(hl)
        out (c),a
        ret

; =========================================================================
; ТАБЛИЦЫ
; =========================================================================
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

        ALIGN 256
Vol_T   ds 256                      ; громкость канала * амплитуда (Pl_VolTab)

player_end
    ASSERT player_end <= #8000

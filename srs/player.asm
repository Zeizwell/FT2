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
; 2 чипа. Команды паттерна (doc/commands.md): скорость, глисс, портаменто, позиции, детюн, ретриггер.
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
; команды паттерна (doc/commands.md):
CS_GOFS         equ 16              ; 2 смещение периода от глисса / портаменто, со знаком
CS_GSTEP        equ 18              ; 2 их шаг, со знаком
CS_GDLY         equ 20              ; задержка: раз в столько тиков шаг
CS_GCNT         equ 21              ;   счётчик
CS_GMODE        equ 22              ; 0 - нет, 1 - глисс, 2 - портаменто (до смещения 0)
CS_DET          equ 23              ; детюн: смещение периода со знаком
CS_OOP          equ 24              ; 6 вкл / выкл: параметр вкл<<4 | выкл (0 - нет)
CS_OOC          equ 25              ;   счётчик фазы
CS_OOS          equ 26              ;   фаза: 0 - звук, 1 - тишина
CS_VSP          equ 27              ; 7 слайд громкости: вверх<<4 | вниз (0 - нет)
CS_VSD          equ 28              ;   задержка
CS_VSC          equ 29              ;   счётчик
CS_VBP          equ 30              ; 8 вибрато: скорость<<4 | глубина (0 - нет)
CS_VBF          equ 31              ;   фаза
CS_ARP          equ 32              ; C арпеджио: +X<<4 | +Y полутонов (0 - нет)
CS_ARD          equ 33              ;   тиков на шаг
CS_ARC          equ 34              ;   счётчик
CS_ARF          equ 35              ;   шаг 0..2 (нота, +X, +Y)
CS_DLN          equ 36              ; F2 задержка ноты: нота (0 - нет)
CS_DLC          equ 37              ;   тиков до неё
CS_VBD          equ 38              ; 8 вибрато: тиков до начала
                                    ; 39 - резерв
CS_SIZE         equ 40
ES_SIZE         equ 6               ; слайд огибающей чипа: смещение 2, шаг 2, задержка, счётчик
    ASSERT CHANNELS*CS_SIZE+2*ES_SIZE < 256 ; Pl_Reset чистит одним циклом

Pl_Ch           ds CHANNELS*CS_SIZE
Es_St           ds 2*ES_SIZE        ; 9 / A: слайд огибающей, по чипу (сразу за каналами)

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
        ld b,CHANNELS*CS_SIZE+2*ES_SIZE
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
        ld a,(#8000+SH_ENVMODE)     ; огибающая FT / PT - в общую переменную (коре)
        ld (Song_EnvMode),a
        ld a,(#8000+SH_STEREO)      ; стерео - тоже
        ld (Song_Stereo),a
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
        push hl                     ; команды (doc/commands.md): что зависит от ноты -
        xor a                       ;   запомнить, сделать после неё (Pr_Post)
        ld (Pr_GCmd),a
        ld (Pr_SOfs),a
        ld (Pr_OOfs),a
        ld (Pr_NDly),a
        ld a,l
        add a,CH_CMD
        ld l,a
        ld b,CH_CMDS
.cmd    ld c,(hl)                   ; C - байт 0: код<<4 | задержка (или подкод)
        inc l
        ld e,(hl)                   ; E - параметр
        inc l
        ld a,c
        and #F0
        jp z,.ncmd
        cp CMD_SPEED<<4
        jr z,.spd
        cp CMD_GLIS_DOWN<<4
        jr z,.gl
        cp CMD_GLIS_UP<<4
        jr z,.gl
        cp CMD_PORTA<<4
        jr z,.gl
        cp CMD_SMP_OFS<<4
        jr z,.so
        cp CMD_ORN_OFS<<4
        jr z,.oo
        cp CMD_ONOFF<<4
        jp z,.c6
        cp CMD_VOL_SLIDE<<4
        jp z,.c7
        cp CMD_VIBRATO<<4
        jp z,.c8
        cp CMD_ENV_DOWN<<4
        jp z,.c9
        cp CMD_ENV_UP<<4
        jp z,.c9
        cp CMD_ARP<<4
        jp z,.cc
        cp CMD_EXT<<4
        jr nz,.ncmd
        ld a,c                      ; расширенная: подкод
        and #0F
        cp CMDX_DETUNE
        jr z,.det
        cp CMDX_DELAY
        jp z,.cf2
        cp CMDX_RETRIG
        jr nz,.ncmd
        push hl                     ; ретриггер: R13 чипа - ещё раз
        ld a,(Pr_Chip)
        ld hl,Pl_R13W
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),1
        pop hl
        jr .ncmd
.det    ld (ix+CS_DET),e            ; детюн - сразу
        jr .ncmd
.spd    ld a,e                      ; скорость (0 - не трогаем): тик этой роу Pl_Tick
        or a                        ;   возьмёт уже с новой
        jr z,.ncmd
        ld (SV_PLAY_SPEED),a
        jr .ncmd
.gl     ld a,c                      ; глисс / портаменто - после ноты
        ld (ix+CS_OOP),0            ;   слайды снимают 6
        ld (Pr_GCmd),a
        ld a,e
        ld (Pr_GPar),a
        jr .ncmd
.so     inc e                       ; сэмпл / орнамент с позиции - после ноты (+1: 0 - нет)
        ld a,e
        ld (Pr_SOfs),a
        jr .ncmd
.oo     inc e
        ld a,e
        ld (Pr_OOfs),a
.ncmd   dec b
        jp nz,.cmd
        pop hl
        jp .ins
.c6     ld (ix+CS_OOP),e            ; 6 вкл / выкл: сначала "вкл" тиков звука
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and #0F
        jr nz,$+3                   ; 0 - как 1
        inc a
        ld (ix+CS_OOC),a
        ld (ix+CS_OOS),0
        ld (ix+CS_GMODE),0          ;   6 снимает слайды
        jp .ncmd
.c7     ld (ix+CS_VSP),e            ; 7 слайд громкости: задержка (0 - как 1)
        ld a,c
        and #0F
        jr nz,$+3
        inc a
        ld (ix+CS_VSD),a
        ld (ix+CS_VSC),a
        jp .ncmd
.c8     ld a,e                      ; 8 вибрато: глубина 0 - стоп
        and #0F
        jr nz,$+3
        ld e,a
        ld (ix+CS_VBP),e
        ld (ix+CS_VBF),0            ;   с фазы 0, после задержки
        ld a,c
        and #0F
        ld (ix+CS_VBD),a
        jp .ncmd
.c9     call Es_Set                 ; 9 / A слайд огибающей чипа
        jp .ncmd
.cc     ld (ix+CS_ARP),e            ; C арпеджио: тиков на шаг (0 - как 1)
        ld a,c
        and #0F
        jr nz,$+3
        inc a
        ld (ix+CS_ARD),a
        ld (ix+CS_ARC),a
        ld (ix+CS_ARF),0
        jp .ncmd
.cf2    ld a,e                      ; F2 задержка ноты - при ноте
        ld (Pr_NDly),a
        jp .ncmd
.ins
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
        ld a,(Pr_Chip)              ; новая форма - слайд огибающей с нуля
        call Es_Ptr
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
.noenv  pop hl
        ld a,(hl)                   ; нота
        or a
        jp z,Pr_Post
        cp NOTE_COUNT+1
        jr c,.note
        ld (ix+CS_NOTE),0           ; команда ноты (R-- и т.п.) - канал молчит, команды - всё
        xor a
        ld (ix+CS_GMODE),a
        ld (ix+CS_GOFS),a
        ld (ix+CS_GOFS+1),a
        ld (ix+CS_OOP),a
        ld (ix+CS_OOS),a
        ld (ix+CS_VSP),a
        ld (ix+CS_VBP),a
        ld (ix+CS_ARP),a
        ld (ix+CS_DLN),a
        ret
.note   call Pr_Slide               ; портаменто - от текущей частоты, иначе слайд - с нуля
        ld b,a
        ld a,(Pr_NDly)              ; F2: нота - через столько тиков (Dl_Tick)
        or a
        jr z,.now
        ld (ix+CS_DLC),a
        ld (ix+CS_DLN),b
        jp Pr_Post
.now    ld a,b
        call Note_Go
        jp Pr_Post

; Нота A стартует: инструмент и орнамент - с начала, накопления - с нуля
Note_Go
        ld (ix+CS_NOTE),a
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
        ld (ix+CS_ARF),a            ; арпеджио - с ноты
        ld (ix+CS_DLN),a            ; отложенной больше нет
        ld a,(ix+CS_ARD)
        ld (ix+CS_ARC),a
        ld a,(ix+CS_INS+1)          ; инструмента ещё не было - первый
        or a
        ret nz
        ld (ix+CS_INS+1),#80
        ret

;-------- Нота A (1..96): в строке портаменто - смещение = текущая частота - частота новой
; ноты (едем от того, что звучит, как VT); иначе слайды - с нуля. A сохраняет
Pr_Slide
        ld (Ps_New),a
        ld a,(Pr_GCmd)
        and #F0
        cp CMD_PORTA<<4
        jr nz,.zero
        ld a,(ix+CS_NOTE)
        or a
        jr z,.zero                  ; до неё тишина - ехать не от чего
        call Note_Per               ; HL - старая нота со смещением
        ld e,(ix+CS_GOFS)
        ld d,(ix+CS_GOFS+1)
        add hl,de
        push hl
        ld a,(Ps_New)
        call Note_Per               ; минус новая
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (ix+CS_GOFS),l
        ld (ix+CS_GOFS+1),h
        ld a,(Ps_New)
        ret
.zero   xor a
        ld (ix+CS_GOFS),a
        ld (ix+CS_GOFS+1),a
        ld (ix+CS_GMODE),a
        ld a,(Ps_New)
        ret
Ps_New          db 0

;-------- После ноты: позиции сэмпла и орнамента, глисс и портаменто строки
Pr_GCmd         db 0                ; глисс / портаменто строки: байт 0 команды (0 - нет)
Pr_GPar         db 0                ;   параметр
Pr_SOfs         db 0                ; сэмпл с позиции: строка+1 (0 - нет)
Pr_OOfs         db 0                ; орнамент с позиции: строка+1 (0 - нет)
Pr_NDly         db 0                ; задержка ноты строки, тиков (0 - нет)
Pr_Post
        ld a,(Pr_SOfs)
        or a
        jr z,.so
        dec a
        ld (ix+CS_IROW),a
.so     ld a,(Pr_OOfs)
        or a
        jr z,.oo
        dec a
        ld (ix+CS_OROW),a
.oo     ld a,(Pr_GCmd)
        or a
        ret z
        ld c,a
        and #0F                     ; задержка
        ld (ix+CS_GDLY),a
        ld (ix+CS_GCNT),a
        ld a,(Pr_GPar)
        or a
        jr nz,.go
        ld (ix+CS_GMODE),a          ; параметр 0 - стоп (набежавшее смещение остаётся)
        ret
.go     ld e,a
        ld d,0
        ld a,c
        and #F0
        cp CMD_PORTA<<4
        jr z,.port
        cp CMD_GLIS_DOWN<<4         ; частота вниз - период растёт: шаг плюс
        call nz,Neg_DE              ; вверх - минус
        ld (ix+CS_GSTEP),e
        ld (ix+CS_GSTEP+1),d
        ld a,(ix+CS_GDLY)
        or a
        jr z,.once
        ld (ix+CS_GMODE),1
        ret
.once   ld (ix+CS_GMODE),a          ; задержка 0 (VT 3.7): один сдвиг, без слайда
        jp Gl_Add
.port   ld a,(ix+CS_GDLY)           ; портаменто: задержка 0 - как 1
        or a
        jr nz,.pd
        inc a
        ld (ix+CS_GDLY),a
        ld (ix+CS_GCNT),a
.pd     ld a,(ix+CS_GOFS)           ; уже на ноте - нечего
        or (ix+CS_GOFS+1)
        jr z,.stop
        bit 7,(ix+CS_GOFS+1)        ; шаг - к нулю: смещение плюс - шаг минус
        call z,Neg_DE
        ld (ix+CS_GSTEP),e
        ld (ix+CS_GSTEP+1),d
        ld (ix+CS_GMODE),2
        ret
.stop   ld (ix+CS_GMODE),0
        ret

;-------- Тик (звучащий канал): глисс / портаменто - раз в CS_GDLY тиков шаг; портаменто -
; доехали или проскочили 0 - стоп на ноте. Портит A, DE, HL
Gl_Tick
        ld a,(ix+CS_GMODE)
        or a
        ret z
        dec (ix+CS_GCNT)
        ret nz
        ld a,(ix+CS_GDLY)
        ld (ix+CS_GCNT),a
        call Gl_Add
        ld a,(ix+CS_GMODE)
        cp 2
        ret nz
        ld a,(ix+CS_GOFS)
        or (ix+CS_GOFS+1)
        jr z,.stop
        ld a,(ix+CS_GOFS+1)
        xor (ix+CS_GSTEP+1)
        ret m                       ; знаки разные - ещё едем
.stop   xor a
        ld (ix+CS_GOFS),a
        ld (ix+CS_GOFS+1),a
        ld (ix+CS_GMODE),a
        ret

; Смещение += шаг
Gl_Add  ld l,(ix+CS_GOFS)
        ld h,(ix+CS_GOFS+1)
        ld e,(ix+CS_GSTEP)
        ld d,(ix+CS_GSTEP+1)
        add hl,de
        ld (ix+CS_GOFS),l
        ld (ix+CS_GOFS+1),h
        ret

; DE = -DE
Neg_DE  ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc de
        ret

; A - нота 1..96 -> HL - её период (таблица трека). Портит A, DE
Note_Per
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
        ret

;-------- Отложенная нота (F2): счётчик дошёл - стартует. Портит A
Dl_Tick
        ld a,(ix+CS_DLC)
        or a
        jr z,.go
        dec (ix+CS_DLC)
        ret
.go     ld a,(ix+CS_DLN)
        jp Note_Go

;-------- Тик (звучащий канал): вкл / выкл (6), слайд громкости (7), вибрато (8) -> Fx_VOfs,
; арпеджио (C) -> Fx_Arp. Портит A, B, DE, HL
Fx_VOfs         dw 0                ; вибрато: смещение периода этого тика
Fx_Arp          db 0                ; арпеджио: сдвиг ноты этого тика
Fx_Tick
        ld a,(ix+CS_OOP)            ; 6 вкл / выкл: фаза кончилась - другая
        or a
        jr nz,.oo
        ld (ix+CS_OOS),a
        jr .vs
.oo     dec (ix+CS_OOC)
        jr nz,.vs
        ld b,a
        ld a,(ix+CS_OOS)
        xor 1
        ld (ix+CS_OOS),a
        ld a,b
        jr nz,.off                  ; тишина - тиков "выкл", звук - "вкл"
        rrca
        rrca
        rrca
        rrca
.off    and #0F                     ; 0 - как 1
        jr nz,$+3
        inc a
        ld (ix+CS_OOC),a
.vs     ld a,(ix+CS_VSP)            ; 7 слайд громкости: раз в задержку
        or a
        jr z,.vb
        dec (ix+CS_VSC)
        jr nz,.vb
        ld b,a
        ld a,(ix+CS_VSD)
        ld (ix+CS_VSC),a
        ld a,b                      ; громкость + вверх - вниз, в 0..15
        rrca
        rrca
        rrca
        rrca
        and #0F
        add a,(ix+CS_VOL)
        ld e,a
        ld a,b
        and #0F
        ld d,a
        ld a,e
        sub d
        jp p,$+4
        xor a
        cp 16
        jr c,$+4
        ld a,15
        ld (ix+CS_VOL),a
.vb     ld hl,0                     ; 8 вибрато: смещение периода по синусу
        ld a,(ix+CS_VBP)
        or a
        jr z,.vbo
        ld a,(ix+CS_VBD)            ; ещё не началось
        or a
        jr z,.vgo
        dec (ix+CS_VBD)
        jr .vbo
.vgo    ld a,(ix+CS_VBP)            ; фаза += скорость (период - 32)
        rrca
        rrca
        rrca
        rrca
        and #0F
        add a,(ix+CS_VBF)
        ld (ix+CS_VBF),a
        ld e,a
        and 15                      ; |синус| полуволны
        ld hl,Vb_Sin
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld d,(hl)
        ld a,(ix+CS_VBP)            ; * глубина / 4 (глубина не 0 - так ставит команда)
        and #0F
        ld b,a
        xor a
.vm     add a,d
        djnz .vm
        srl a
        srl a
        ld l,a
        ld h,0
        bit 4,e                     ; вторая полуволна - минус
        jr z,.vbo
        ex de,hl
        call Neg_DE
        ex de,hl
.vbo    ld (Fx_VOfs),hl
        ld a,(ix+CS_ARP)            ; C арпеджио: шаг 0 - нота, 1 - +X, 2 - +Y
        or a
        jr z,.aro
        ld b,a
        ld a,(ix+CS_ARF)
        or a
        jr z,.ar0
        dec a
        ld a,b
        jr nz,.ar2
        rrca
        rrca
        rrca
        rrca
.ar2    and #0F
        jr .ar1
.ar0    xor a
.ar1    ld (Fx_Arp),a
        dec (ix+CS_ARC)             ; раз в задержку - следующий шаг
        ret nz
        ld a,(ix+CS_ARD)
        ld (ix+CS_ARC),a
        ld a,(ix+CS_ARF)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (ix+CS_ARF),a
        ret
.aro    ld (Fx_Arp),a
        ret

; |синус| полуволны (16 шагов), до 16
Vb_Sin  db 0,3,6,9,11,13,15,16,16,16,15,13,11,9,6,3

;-------- 9 / A слайд огибающей чипа Pr_Chip: C - байт 0 (код, задержка), E - шаг.
; Вниз - период растёт (как глисс). Задержка 0 - как 1, шаг 0 - стоп. HL, B целы
Es_Set
        push hl
        push bc
        ld a,(Pr_Chip)
        call Es_Ptr
        inc hl                      ; шаг
        inc hl
        ld d,0
        ld a,c
        and #F0
        cp CMD_ENV_DOWN<<4
        call nz,Neg_DE
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,c                      ; задержка и счётчик
        and #0F
        jr nz,$+3
        inc a
        ld (hl),a
        inc hl
        ld (hl),a
        pop bc
        pop hl
        ret

;-------- Тик чипа Pc_Chip: слайд огибающей - раз в задержку смещение += шаг. Портит A, DE, HL
Es_Tick
        ld a,(Pc_Chip)
        call Es_Ptr
        push hl
        ld de,4                     ; задержка: 0 - слайда не было
        add hl,de
        ld a,(hl)
        or a
        jr z,.no
        inc hl
        dec (hl)
        jr nz,.no
        ld (hl),a
        pop hl
        push hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ret
.no     pop hl
        ret

; A - чип -> HL - его слайд огибающей (Es_St). Флаги - по A
Es_Ptr  ld hl,Es_St
        or a
        ret z
        ld hl,Es_St+ES_SIZE
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
Pc_ESum         db 0                ; PT: сумма смещений огибающей каналов чипа

Pl_Channels
        ld a,(Pl_InsPage)
        SETPAGE2 a
        ld ix,Pl_Ch
        xor a
        ld (Pc_Chip),a
.chip   call Es_Tick                ; 9 / A: слайд огибающей чипа - шаг
        ld hl,Pl_Regs               ; регистры чипа
        ld a,(Pc_Chip)
        or a
        jr z,$+5
        ld hl,Pl_Regs+PR_SIZE
        ld (Pc_Regs),hl
        ld a,#3F                    ; микшер: всё выключено, каналы включат
        ld (Pc_Mix),a
        xor a
        ld (Pc_Idx),a
        ld (Pc_ESum),a              ; PT: сумма смещений огибающей чипа
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
        ld a,(Song_EnvMode)         ; PT: период огибающей - после всех каналов чипа,
        or a                        ;   база минус сумма смещений (пишется всегда)
        ld a,(Pc_ESum)
        call nz,Pc_EPer
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
        ld a,(ix+CS_DLN)            ; F2: отложенная нота - не пора ли
        or a
        call nz,Dl_Tick
        ld a,(ix+CS_NOTE)
        or a
        jr nz,.on
        ld a,(Pc_Idx)               ; молчит: громкость канала (R8+канал) - 0
        add a,8
        call Pc_Reg_Addr
        ld (hl),0
        ret
.on     call Gl_Tick                ; команды паттерна: глисс / портаменто - шаг
        call Fx_Tick                ;   остальные
        ; --- орнамент: сдвиг ноты и шум
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
.note   ld hl,Fx_Arp                ; + арпеджио
        add a,(hl)
        dec a                       ; нота 1..96 -> 0..95, за краями - край
        jp p,.nlo
        xor a
.nlo    cp NOTE_COUNT
        jr c,.nhi
        ld a,NOTE_COUNT-1
.nhi    ld (Pc_Note),a
        ; --- строка инструмента: блок + 3 + строка*5
        ld l,(ix+CS_IROW)           ; строка*5 - в 16 битах (строки 52..63 дают больше 255)
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
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
        ld e,(ix+CS_GOFS)           ; + глисс / портаменто
        ld d,(ix+CS_GOFS+1)
        add hl,de
        ld a,(ix+CS_DET)            ; + детюн (байт со знаком)
        ld e,a
        rla
        sbc a,a
        ld d,a
        add hl,de
        ld de,(Fx_VOfs)             ; + вибрато
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
        ld a,(Song_EnvMode)         ; PT: смещение огибающей копит каждый канал
        or a
        call nz,Pc_EPtAdd
        ld a,(Pc_B3)                ; огибающая: в строке включена и канал с огибающей
        bit 6,a
        jr z,.vout
        ld a,(ix+CS_ENV)
        or a
        jr z,.vout
        ld a,b
        or #10
        ld b,a
        ld a,(Song_EnvMode)         ; FT: период - этот канал (PT - после чипа)
        or a
        call z,Pc_Env
.vout   ld a,(ix+CS_OOS)            ; 6: фаза "выкл" - тишина
        or a
        jr z,$+4
        ld b,0
        ld a,(Pc_Idx)
        add a,8
        call Pc_Reg_Addr
        ld (hl),b
        ret

Pc_B0           db 0
Pc_B2           db 0
Pc_B3           db 0
Pc_B4           db 0

; PT: смещение огибающей канала - в сумму чипа. Только строки с выключенным шумом:
; у PT3 это одно поле (шум или огибающая), импорт кладёт его в огибающую. B не портит
Pc_EPtAdd
        ld a,(Pc_B0)
        bit IRB_OFF,a
        ret z
        call Pc_EOffs
        ld hl,Pc_ESum
        add a,(hl)
        ld (hl),a
        ret

; Смещение огибающей строки: IR_ENV + накопленное (бит 7 громкости - сохранить) -> A.
; Портит E
Pc_EOffs
        ld a,(Pc_B4)                ; смещение + накопленное
        add a,(ix+CS_EACC)
        ld e,a
        ld a,(Pc_B3)                ; бит 7 - сохранить сумму
        bit 7,a
        ld a,e
        ret z
        ld (ix+CS_EACC),a
        ret

; Период огибающей: база чипа - смещение строки (+ накопление) -> R11/R12
Pc_Env
        call Pc_EOffs
; A - смещение со знаком -> R11/R12 = база чипа - A
Pc_EPer
        push bc
        ld e,a                      ; DE - смещение со знаком
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
        push hl                     ; + слайд огибающей чипа (9 / A)
        ld a,(Pc_Chip)
        call Es_Ptr
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        add hl,de
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
.chip   push af
        push de
        call Po_Stereo              ; каналы - по стерео (HL - уже Po_Buf)
        pop de
        pop af
        ld bc,#FFFD                 ; выбрать чип
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

;-------- Стерео: регистры чипа HL -> Po_Buf, каналы переставлены по Song_Stereo: выход p
; получает канал Po_Maps[режим][p] (тон, громкость, биты тона и шума в микшере).
; Выход: HL = Po_Buf. Портит AF, BC, DE
Po_Buf          ds PR_SIZE
Po_Src          dw 0
Po_Map          dw 0
Po_Maps         db 0,1,2, 0,2,1, 1,0,2, 1,2,0, 2,0,1  ; ABC ACB BAC BCA CAB - как в VT (Hd_Stereos)
Po_Stereo
        ld (Po_Src),hl
        ld de,Po_Buf                ; шум, огибающая, R13 - как есть
        ld bc,PR_SIZE
        ldir
        ld a,(Song_Stereo)
        or a
        jr z,.out                   ; ABC - каналы на своих местах
        ld b,a                      ; таблица режима: *3
        add a,a
        add a,b
        ld hl,Po_Maps
        call Po_HlA
        ld (Po_Map),hl
        ld a,(Po_Buf+7)             ; микшер: биты каналов соберём заново
        and #C0
        ld (Po_Buf+7),a
        ld c,0                      ; C - выход
.ch     ld hl,(Po_Map)              ; B - канал для него
        ld a,c
        call Po_HlA
        ld b,(hl)
        ld hl,(Po_Src)              ; тон
        ld a,b
        add a,a
        call Po_HlA
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,Po_Buf
        ld a,c
        add a,a
        call Po_HlA
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(Po_Src)              ; громкость
        ld a,b
        add a,8
        call Po_HlA
        ld e,(hl)
        ld hl,Po_Buf+8
        ld a,c
        call Po_HlA
        ld (hl),e
        ld hl,(Po_Src)              ; микшер: биты канала (тон, шум) - на место выхода
        ld de,7
        add hl,de
        ld a,(hl)
        inc b
        jr .s1
.r1     rrca
.s1     djnz .r1
        and %00001001
        ld b,c
        inc b
        jr .s2
.l2     add a,a
.s2     djnz .l2
        ld hl,Po_Buf+7
        or (hl)
        ld (hl),a
        inc c
        ld a,c
        cp 3
        jr c,.ch
.out    ld hl,Po_Buf
        ret
Po_HlA  add a,l
        ld l,a
        ret nc
        inc h
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

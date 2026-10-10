; =========================================================================
; ИМПОРТ PT3 (Pro Tracker 3.x / Vortex Tracker II) в трек 1. Часть тулзы диска
; (srs/diskview.asm): модуль уже в буфере файла (PAGE_FILEBUF..), Ld_Size - размер.
; Формат - doc/formats/pt3.md, formats/pt_format.txt.
; =========================================================================
; Что куда:
;   заголовок  - имя, автор, темп -> страница трека (новый трек: Song_Clear);
;   сэмплы 1..31 -> инструменты 1..31, сэмпл 0 ("W") -> инструмент 32;
;   орнаменты 1..15 -> 1..15 (0 - пустой, как у нас);
;   ордер      - позиции до 255; паттерн PT3 -> наш номер (по порядку появления,
;                не больше 64);
;   треки      - роу паттерна: нота, сэмпл, форма огибающей, орнамент, громкость;
;                период огибающей и шум - в заголовок чипа; спецкоманды #01..#09 -
;                в команды канала (коды CMD_* - sdk/plugin.asm);
;   TurboSound - два модуля подряд (хвост "02TS"): второй - в чип 2 (каналы D, E, F),
;                его сэмплы и орнаменты не берём (у VT они общие).
; Чего не влезло (роу больше 64, паттернов больше 64, длинные сэмплы, лишние
; команды) - обрезается, флаг Pt_Lost - в сообщение.
; =========================================================================

; --- заголовок модуля
PT_NAME         equ 30              ; 32 имя
PT_AUTHOR       equ 66              ; 32 автор
PT_TEMPO        equ 100
PT_LOOP         equ 102
PT_PATS         equ 103             ; 2 смещение таблицы паттернов (по 6 байт: A, B, C)
PT_SAMPLES      equ 105             ; 32 x 2 смещения сэмплов 0..31
PT_ORNS         equ 169             ; 16 x 2 смещения орнаментов 0..15
PT_ORDER        equ 201             ; номера паттернов x3, конец - #FF
PT_TS_TAIL      equ 16              ; хвост TurboSound: "PT3!",размер1,"PT3!",размер2,"02TS"

; --- что потеряли (биты Pt_Lost)
PL_ROWS         equ 0               ; паттерн длиннее 64 роу
PL_PATS         equ 1               ; паттернов больше 64 (позиции обрезаны)
PL_CMDS         equ 2               ; больше двух команд в клетке
PL_LEN          equ 3               ; сэмпл / орнамент длиннее 64

Pt_Lost         db 0
Pt_Base         dw 0                ; начало модуля в файле
Pt_Base2        dw 0                ; второй модуль (TurboSound)
Pt_Chips        db 1
Pt_TS37         db 0                ; PT 3.7 TS: N (паттерн чипа 2 = N-1-p), 0 - нет
PT_TS37_N       equ 98

;-------- Импорт. Выход - сообщение (Dv_Ok / Dv_Error)
Pt_Import
        xor a
        ld (Pt_Lost),a
        ld hl,0
        ld (Pt_Base),hl
        ld hl,PT_ORDER              ; ордер пустой - не PT3 (трек не трогаем)
        call Pt_Get
        cp #FF
        ld hl,Txt_BadPt3
        jp z,Dv_Error
        call Pt_TS                  ; второй модуль?
        call Song_Clear             ; новый трек
        call Pt_Header
        ld a,(Trk_Ins)              ; инструменты и орнаменты - пустые, потом PT3
        call Ins_Clear
        call Pt_Samples
        call Pt_Ornaments
        call Pt_Order               ; ордер -> наши паттерны
        call Pt_Patterns
        ld hl,Txt_Pt3Cut

;-------- Общий конец импорта (PT3, PT2...): ордер и каталог - в трек, имя файла, сообщение.
; HL - начало сообщения о потерях ("PT3 cut:")
Pt_Done
        ld (Pt_Cut_Txt),hl
        call Pt_Song_Order          ; ордер и каталог - в страницу трека
        ld hl,Dv_Spec+1             ; имя файла - в трек (шапка)
        call Dv_Song_File
        ld a,1                      ; вид паттерна перечитает трек при входе
        ld (SV_SONG_NEW),a
        ld a,(Pt_Lost)              ; без потерь - экран диска закрываем
        or a
        jp z,Dv_Loaded
        ld hl,(Pt_Cut_Txt)          ; что обрезали - словами за сообщением
        ld de,Pt_Msg
        call Str_Copy
        ld hl,Pt_Lost_Words
        ld a,(Pt_Lost)
        ld b,4
.w      rrca
        push af
        call c,Str_Copy
        pop af
        call nc,Str_Skip
        djnz .w
        ld hl,Pt_Msg
        jp Dv_Ok

Pt_Msg          ds 40
Pt_Cut_Txt      dw 0
Pt_Lost_Words   db " rows",0," pats",0," cmds",0," len",0   ; по битам PL_*

;-------- TurboSound: в конце файла "02TS" - два модуля, второй - с размер1;
; иначе - может быть PT 3.7 (Pt_TS37_Check)
Pt_TS
        ld a,1
        ld (Pt_Chips),a
        ld a,(Ld_Size+2)            ; файл больше 64К - не TS (смещения 16 бит)
        or a
        jr nz,Pt_TS37_Check
        ld hl,(Ld_Size)
        ld de,PT_TS_TAIL+256
        or a
        sbc hl,de
        jr c,Pt_TS37_Check          ; совсем короткий
        add hl,de
        ld de,-PT_TS_TAIL
        add hl,de                   ; HL - начало хвоста
        push hl
        ld de,12                    ; "02TS"
        add hl,de
        call Pt_Get16
        ld bc,"0"+"2"*256
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        jr nz,.no
        call Pt_Get16
        ld bc,"T"+"S"*256
        ex de,hl
        or a
        sbc hl,bc
        jr nz,.no
        pop hl                      ; размер первого модуля - начало второго
        xor a                       ; не 3.7
        ld (Pt_TS37),a
        ld de,4
        add hl,de
        call Pt_Get16
        ld (Pt_Base2),de
        ld a,2
        ld (Pt_Chips),a
        ret
.no     pop hl
; PT 3.7: +98 - число паттернов N (не #20): чип 2 играет паттерн N-1-p из этого же модуля
Pt_TS37_Check
        ld hl,PT_TS37_N
        call Pt_Get
        cp #20
        ld b,a
        ld a,0
        jr z,.set
        ld a,2
        ld (Pt_Chips),a
        ld a,b
.set    ld (Pt_TS37),a
        ld hl,0                     ; второй модуль - он же
        ld (Pt_Base2),hl
        ret

;-------- Заголовок трека: чипы, темп, имя, автор
Pt_Header
        ld hl,PT_TEMPO
        call Pt_Get
        or a
        jr nz,$+4
        ld a,NEW_SONG_SPEED
        ld (Ph_Tempo),a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Ph_Tempo)
        ld (#8000+SH_SPEED),a
        ld a,(Pt_Chips)
        ld (#8000+SH_CHIPS),a
        ld hl,#8000+ORDER_LIST      ; ордер и каталоги - нули
        ld de,#8000+ORDER_LIST+1
        ld bc,SONG_CAT_END-ORDER_LIST-1
        ld (hl),0
        ldir
        ld hl,PT_NAME               ; имя и автор
        ld de,#8000+SH_NAME
        call .str
        ld hl,PT_AUTHOR
        ld de,#8000+SH_AUTHOR
        call .str
        RESTPAGE2
        ret
.str    ld b,32
.c      call Pt_Get
        ld (de),a
        inc de
        djnz .c
        ret

Ph_Tempo        db 0

; =========================================================================
; ЧТЕНИЕ МОДУЛЯ: смещение от начала модуля (Pt_Base) -> байт из буфера файла
; =========================================================================
;-------- HL - смещение -> A - байт, HL+1. BC, DE целы
Pt_Get
        push bc
        push de
        push hl
        ld de,(Pt_Base)
        add hl,de                   ; адрес в файле, 17 бит
        sbc a,a                     ; перенос -> бит 2 номера страницы
        and 4
        ld b,a
        ld a,h                      ; страница буфера = адрес / 16К
        rlca
        rlca
        and 3
        or b
        add a,PAGE_FILEBUF
        ld e,a                      ; (SETPAGE портит A, BC)
        ld a,h                      ; адрес в окне 3
        or #C0
        ld h,a
        SETPAGE3 e
        ld e,(hl)
        RESTPAGE3
        ld a,e
        pop hl
        inc hl
        pop de
        pop bc
        ret

;-------- HL - смещение -> DE - слово (младший первым), HL+2
Pt_Get16
        call Pt_Get
        ld e,a
        call Pt_Get
        ld d,a
        ret

; =========================================================================
; СЭМПЛЫ И ОРНАМЕНТЫ -> страница инструментов текущего трека Trk_Ins (окно 2)
; =========================================================================
Ps_K            db 0                ; номер сэмпла / орнамента PT3
Ps_Rows         db 0                ; строк осталось
Ps_Dst          dw 0                ; куда строка (окно 2)

Pt_Samples
        xor a
        ld (Ps_K),a
.k      ld a,(Ps_K)                 ; смещение сэмпла: 0 - нет
        add a,a
        ld l,a
        ld h,0
        ld de,PT_SAMPLES
        add hl,de
        call Pt_Get16
        ld a,d
        or e
        jr z,.next
        ld a,(Ps_K)                 ; наш номер: 0 -> 32, блок (номер-1)*INS_BLOCK
        or a
        jr nz,$+4
        ld a,SAMPLES_MAX
        dec a
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl                   ; *384 = *256 + *128
        add hl,bc
        ld h,l
        ld l,0
        srl h
        rr l
        ld a,h
        or #80
        ld h,a
        push de
        ld a,(Trk_Ins)
        ld (Ps_Page),a
        pop de
        ex de,hl                    ; HL - сэмпл в модуле, DE - блок
        call Ps_Sample
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp SAMPLES_MAX
        jr c,.k
        ret

Ps_Page         db 0

;-------- Сэмпл: HL - в модуле (loop, длина, строки по 4), DE - наш блок (окно 2)
Ps_Sample
        call Ps_Head                ; заголовок блока, Ps_Rows
        ld a,(Ps_Page)
        SETPAGE2 a
.row    call Pt_Get                 ; PT3: b0 = sv +- N4..N0 Em
        ld (Ps_B0),a
        call Pt_Get                 ;      b1 = Nm ts ns Tm V3..V0
        ld (Ps_B1),a
        call Pt_Get16               ;      смещение тона
        push hl
        call Ps_Row
        pop hl
        ld hl,Ps_Rows
        dec (hl)
        jr nz,.row
        RESTPAGE2
        ret

Ps_B0           db 0
Ps_B1           db 0

; Заголовок блока по loop / длине модуля: HL - в модуле (-> строки), DE - блок.
; Длина больше 64 - обрезаем (Pt_Lost). Ps_Rows - строк, Ps_Dst - первая строка
Ph_Loop         db 0
Ph_End          db 0

Ps_Head
        call Pt_Get                 ; loop
        ld (Ph_Loop),a
        call Pt_Get                 ; длина (0 - как 1)
Ps_Head_Len                         ; вход с длиной в A (loop - уже в Ph_Loop)
        or a
        jr nz,$+3
        inc a
        cp INS_ROWS_MAX+1
        jr c,.len
        push hl
        ld hl,Pt_Lost
        set PL_LEN,(hl)
        pop hl
        ld a,INS_ROWS_MAX
.len    ld (Ps_Rows),a
        dec a                       ; конец = длина-1
        ld (Ph_End),a
        ld b,a
        ld a,(Ph_Loop)              ; цикл - не за концом
        cp b
        jr c,.lok
        ld a,b
.lok    ld (Ph_Loop),a
        push hl
        ld (Ps_Dst),de
        ld a,(Ps_Page)              ; (SETPAGE портит A, BC - всё через память)
        SETPAGE2 a
        ld hl,(Ps_Dst)
        ld a,(Ph_End)
        ld (hl),a                   ; OH_LEN
        inc hl
        ld a,(Ph_Loop)
        ld (hl),a                   ; OH_LOOP
        inc hl
        ld a,(Ph_End)
        ld (hl),a                   ; OH_END
        inc hl
        ld (Ps_Dst),hl
        RESTPAGE2
        pop hl
        ret

;-------- Строка сэмпла PT3 (Ps_B0, Ps_B1, DE - тон) -> 5 байт в Ps_Dst (окно 2)
Ps_Row
        ld hl,(Ps_Dst)
        ld a,(Ps_B1)                ; шум: Nm (бит 7 b1) = выкл
        bit 7,a
        jr nz,.noff
        ld a,(Ps_B0)                ; шум вкл: смещение N, накопление ns
        rrca
        and #1F
        ld c,a
        ld a,(Ps_B1)
        and #20                     ; ns -> бит 7
        add a,a
        add a,a
        or c
        ld (hl),a                   ; IR_NOISE
        xor a
        ld (Ps_Env),a               ; огибающая: смещения нет
        ld (Ps_EAcc),a
        jr .tone
.noff   ld (hl),1<<IRB_OFF          ; шум выкл: N - смещение огибающей (знаковое ±15)
        ld a,(Ps_B0)
        rrca
        and #1F
        cp 16
        jr c,$+4
        sub 32
        neg                         ; у нас смещение вычитается
        ld (Ps_Env),a
        ld a,(Ps_B1)                ; ns - накопление огибающей
        and #20
        add a,a
        add a,a
        ld (Ps_EAcc),a
.tone   inc hl                      ; IR_TONE: 12 бит со знаком, флаги в старшем
        ld a,d                      ; DE > 2047 -> 2047, < -2048 -> -2048
        bit 7,a
        jr nz,.neg
        cp 8
        jr c,.tok
        ld de,2047
        jr .tok
.neg    cp #F8
        jr nc,.tok
        ld de,-2048
.tok    ld (hl),e
        inc hl
        ld a,d
        and #0F
        ld c,a
        ld a,(Ps_B1)                ; ts -> бит 7, Tm -> бит 6
        and #40
        add a,a
        or c
        ld c,a
        ld a,(Ps_B1)
        and #10
        add a,a
        add a,a
        or c
        ld (hl),a
        inc hl
        ld a,(Ps_B1)                ; IR_VOL: громкость, слайд, огибающая
        and #0F
        ld c,a
        ld a,(Ps_B0)
        bit 7,a                     ; sv - слайд громкости
        jr z,.nosl
        set IRB_SLIDE,c
        bit 6,a                     ; +- = 0 - вниз
        jr nz,.nosl
        set IRB_SLIDE_DOWN,c
.nosl   bit 0,a                     ; Em = 0 - огибающая вкл
        jr nz,$+4
        set IRB_OFF,c
        ld a,(Ps_EAcc)
        or c
        ld (hl),a
        inc hl
        ld a,(Ps_Env)               ; IR_ENV
        ld (hl),a
        inc hl
        ld (Ps_Dst),hl
        ret

Ps_Env          db 0
Ps_EAcc         db 0

;-------- Орнаменты 1..15 -> наши 1..15 (блок номер-1). 0 - пустой и у нас
Pt_Ornaments
        ld a,(Trk_Ins)
        ld (Ps_Page),a
        ld a,1
        ld (Ps_K),a
.k      ld a,(Ps_K)
        add a,a
        ld l,a
        ld h,0
        ld de,PT_ORNS
        add hl,de
        call Pt_Get16
        ld a,d
        or e
        jr z,.next
        ld a,(Ps_K)                 ; блок: #8000 + ORN_BASE + (номер-1)*256
        dec a
        add a,#80+high ORN_BASE
        ld h,a
        ld l,0
        ex de,hl
        call Po_Orn
.next   ld hl,Ps_K
        inc (hl)
        ld a,(hl)
        cp ORNAMENTS_MAX
        jr c,.k
        ret

;-------- Орнамент: HL - в модуле (loop, длина, полутоны), DE - наш блок (окно 2)
Po_Orn
        call Ps_Head
Po_Orn_Rows                         ; строки: HL - в модуле, заголовок блока уже есть
        ld a,(Ps_Page)
        SETPAGE2 a
.row    call Pt_Get                 ; полутоны
        ld de,(Ps_Dst)
        ex de,hl
        ld (hl),0                   ; OR_NOISE: шума нет, сдвиг не накапливается
        inc hl
        ld (hl),a                   ; OR_NOTE
        inc hl
        ld (Ps_Dst),hl
        ex de,hl
        ld a,(Ps_Rows)
        dec a
        ld (Ps_Rows),a
        jr nz,.row
        RESTPAGE2
        ret

; =========================================================================
; ОРДЕР: позиции PT3 -> наши паттерны. Наш паттерн = пара (паттерн модуля 1,
; паттерн модуля 2 или #FF), номера - по порядку появления
; =========================================================================
Pm_Count        db 0                ; наших паттернов
Pm_P1           ds PATTERNS_MAX     ; паттерн модуля 1
Pm_P2           ds PATTERNS_MAX     ; паттерн модуля 2 (#FF - нет)
Pm_Len          ds PATTERNS_MAX     ; длина (роу)
Po_Pos          ds 255              ; ордер: наши номера
Po_Count        db 0                ; позиций
Po_Loop         db 0
Po_Ptr2         dw 0                ; ордер модуля 2 (смещение)
Po_Key1         db 0
Po_Key2         db 0

Pt_Order
        xor a
        ld (Pm_Count),a
        ld (Po_Count),a
        ld hl,PT_LOOP
        call Pt_Get
        ld (Po_Loop),a
        ld hl,PT_ORDER
        ld (Po_Ptr2),hl
.pos    ld a,(Po_Count)             ; не больше 255 позиций
        cp 255
        ret nc
        call Pt_Get                 ; модуль 1: номер x3, #FF - конец
        cp #FF
        ret z
        call Div3
        ld (Po_Key1),a
        ld a,#FF                    ; модуль 2 - его позиция с тем же номером
        ld (Po_Key2),a
        ld a,(Pt_Chips)
        cp 2
        jr c,.find
        ld a,(Pt_TS37)              ; PT 3.7: чип 2 - паттерн N-1-p этого же модуля
        or a
        jr z,.mod2
        dec a
        ld b,a
        ld a,(Po_Key1)
        neg
        add a,b
        ld (Po_Key2),a
        jr .find
.mod2   push hl
        call Pt_Mod2
        ld hl,(Po_Ptr2)
        call Pt_Get
        ld (Po_Ptr2),hl
        call Pt_Mod1
        pop hl
        cp #FF
        jr z,.find
        call Div3
        ld (Po_Key2),a
.find   push hl
        call Pm_Find                ; A - наш номер, CF - некуда
        pop hl
        jr c,.full
        ld de,Po_Pos                ; в ордер
        push hl
        ld hl,Po_Count
        ld c,(hl)
        inc (hl)
        ex de,hl
        ld b,0
        add hl,bc
        ld (hl),a
        pop hl
        jr .pos
.full   ld hl,Pt_Lost
        set PL_PATS,(hl)
        ret

; Модуль 2 / 1 - для Pt_Get
Pt_Mod2 push de
        ld de,(Pt_Base2)
        ld (Pt_Base),de
        pop de
        ret
Pt_Mod1 push de
        ld de,0
        ld (Pt_Base),de
        pop de
        ret

; A / 3 -> A (A - номер паттерна x3)
Div3    ld b,-1
.d      inc b
        sub 3
        jr nc,.d
        ld a,b
        ret

; Пара (Po_Key1, Po_Key2) -> A - наш номер паттерна (новая - в конец). CF - мест нет
Pm_Find
        ld a,(Pm_Count)
        ld b,a
        ld c,0                      ; C - номер
        ld a,b
        or a
        jr z,.new
.f      ld hl,Pm_P1
        ld a,c
        call Hl_Add_A
        ld a,(Po_Key1)
        cp (hl)
        jr nz,.n
        ld de,PATTERNS_MAX          ; Pm_P2 - сразу за Pm_P1
        add hl,de
        ld a,(Po_Key2)
        cp (hl)
        jr nz,.n
        ld a,c
        or a                        ; CF = 0
        ret
.n      inc c
        djnz .f
.new    ld a,c
        cp PATTERNS_MAX
        ccf
        ret c
        ld hl,Pm_P1
        call Hl_Add_A
        ld a,(Po_Key1)
        ld (hl),a
        ld de,PATTERNS_MAX
        add hl,de
        ld a,(Po_Key2)
        ld (hl),a
        ld hl,Pm_Count
        inc (hl)
        ld a,c
        or a
        ret

;-------- Ордер и каталог паттернов - в страницу трека
Pt_Song_Order
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(Po_Count)             ; последняя позиция, повтор
        dec a
        ld (#8000+ORD_LAST),a
        ld b,a
        ld a,(Po_Loop)
        cp b
        jr c,.lp
        jr z,.lp
        xor a
.lp     ld (#8000+ORD_LOOP),a
        ld hl,Po_Pos
        ld de,#8000+ORD_POS
        ld bc,255
        ldir
        ld hl,#8000+PAT_CATALOG     ; каталог: страница, длина
        ld de,Pm_Len
        ld c,0
.p      ld a,(Pm_Count)
        cp c
        jr z,.done
        ld a,c
        call Pat_Page
        ld (hl),a
        inc hl
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        inc c
        jr .p
.done   RESTPAGE2
        ret

; =========================================================================
; ПАТТЕРНЫ: треки PT3 -> роу наших паттернов
; =========================================================================
Pp_N            db 0                ; наш паттерн
Pp_Rows         db 0                ; длина (по каналу A модуля 1)

Pt_Patterns
        xor a
        ld (Pp_N),a
.p      ld a,(Pm_Count)
        ld hl,Pp_N
        cp (hl)
        ret z
        ld a,(hl)
        call Pat_Page
        SETPAGE2 a
        call Pat_Zero
        ld a,PAT_ROWS_MAX           ; модуль 1 - чип 1, длина - по его каналу A
        ld (Pp_Max),a
        xor a
        ld (Pp_Chip),a
        ld a,(Pp_N)
        ld hl,Pm_P1
        call Arr_Get
        call Pp_Decode
        ld (Pp_Rows),a
        ld a,(Pp_Rows)              ; модуль 2 - чип 2, столько же роу
        or a
        jr z,.len
        ld a,(Pp_N)
        ld hl,Pm_P2
        call Arr_Get
        cp #FF
        jr z,.len
        ld (Pp_P),a
        ld a,(Pp_Rows)
        ld (Pp_Max),a
        ld a,CHIP_SIZE
        ld (Pp_Chip),a
        call Pt_Mod2
        ld a,(Pp_P)
        call Pp_Decode
        call Pt_Mod1
.len    ld a,(Pp_Rows)              ; длина: пустой паттерн - 1 роу
        or a
        jr nz,$+3
        inc a
        ld hl,Pm_Len
        ld c,a
        ld a,(Pp_N)
        call Hl_Add_A
        ld (hl),c
        RESTPAGE2
        ld hl,Pp_N
        inc (hl)
        jp .p

Pp_P            db 0

; --- состояние каналов при разборе паттерна (A, B, C)
Pp_Max          db 0                ; роу не больше
Pp_Chip         db 0                ; смещение чипа в роу (0 / CHIP_SIZE)
Pp_Row          db 0
Pp_Ch           db 0                ; канал 0..2
Pc_Ptr          ds 3*2              ; трек: смещение в модуле
Pc_Skip         ds 3                ; пропуск строк (#B1)
Pc_Cnt          ds 3                ; до разбора строк
Pc_End          ds 3                ; 1 - трек кончился

;-------- Паттерн A модуля Pt_Base -> роу паттерна в окне 2 (чип Pp_Chip).
; Выход: A - роу (канал A дошёл до #00 или Pp_Max)
Pp_Decode
        ld l,a                      ; треки: таблица паттернов + номер*6
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        push hl
        ld hl,PT_PATS
        call Pt_Get16
        pop hl
        add hl,de
        ld de,Pc_Ptr
        ld b,3
.tr     push de
        call Pt_Get16
        ex (sp),hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex (sp),hl
        pop de
        djnz .tr
        ld hl,Pc_Skip               ; пропуск 1, счётчик 1, не кончились
        ld (hl),1
        inc hl
        ld (hl),1
        inc hl
        ld (hl),1
        ld hl,Pc_Cnt
        ld (hl),1
        inc hl
        ld (hl),1
        inc hl
        ld (hl),1
        xor a
        ld (Pc_End),a
        ld (Pc_End+1),a
        ld (Pc_End+2),a
        ld (Pp_Row),a
.row    xor a
        ld (Pp_Ch),a
.ch     ld hl,Pc_End                ; канал кончился - дальше пусто
        call Pc_Var
        ld a,(hl)
        or a
        jr nz,.nch
        ld hl,Pc_Cnt                ; пропуск строк
        call Pc_Var
        dec (hl)
        jr nz,.nch
        call Pr_Row                 ; разбор строки канала; CF - конец трека
        jr nc,.skip
        ld hl,Pc_End
        call Pc_Var
        ld (hl),1
        ld a,(Pp_Ch)                ; конец канала A чипа 1 - конец паттерна
        or a
        jr nz,.nch
        ld a,(Pp_Chip)
        or a
        jr nz,.nch
        ld a,(Pp_Row)
        ret
.skip   ld hl,Pc_Skip               ; счётчик - заново (Pc_Var портит A)
        call Pc_Var
        ld e,(hl)
        ld hl,Pc_Cnt
        call Pc_Var
        ld (hl),e
.nch    ld hl,Pp_Ch
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.ch
        ld hl,Pp_Row
        inc (hl)
        ld a,(Pp_Max)
        cp (hl)
        jr nz,.row
        ld a,(Pp_Chip)              ; чип 1 упёрся в 64 - роу потеряли
        or a
        jr nz,.out
        ld hl,Pc_End
        ld a,(hl)
        or a
        jr nz,.out
        call Pc_Peek_End            ; канал A на следующей строке кончается - всё влезло
        jr z,.out
        ld hl,Pt_Lost
        set PL_ROWS,(hl)
.out    ld a,(Pp_Row)
        ret

; HL - массив по каналам -> HL на элемент канала Pp_Ch
Pc_Var  ld a,(Pp_Ch)
        jp Hl_Add_A

; Канал A: следующая разбираемая строка - конец трека? Z - да
Pc_Peek_End
        ld a,(Pc_Cnt)
        cp 1
        ret nz                      ; ещё пропуск - не конец
        ld hl,(Pc_Ptr)
        call Pt_Get
        or a
        ret

;-------- Строка канала Pp_Ch: команды трека до конца строки -> клетка роу Pp_Row.
; CF - трек кончился (#00)
Pr_NCmd         db 0                ; спецкоманд в строке
Pr_Cmds         ds 8                ; их коды (#01..#09)
Pr_Out          ds 8*2              ; готовые команды (байт 0, байт 1)
PR_CMDS_MAX     equ 8

Pr_Row
        xor a
        ld (Pr_NCmd),a
        ld hl,Pc_Ptr                ; HL - позиция в треке
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.cmd    call Pt_Get
        or a
        jr nz,.go
        scf                         ; #00 - конец трека
        ret
.go     cp #10
        jr c,.spec
        jr z,.e10
        cp #20
        jr c,.e1x
        cp #40
        jr c,.noise
        cp #50
        jr c,.orn
        cp #B0
        jp c,.note
        jr z,.eoff
        cp #B1
        jr z,.skp
        cp #C0
        jr c,.ebx
        jp z,.off
        cp #D0
        jr c,.vol
        jp z,.end
        cp #F0
        jr c,.smp
        sub #F0                     ; #F0..#FF: орнамент, сэмпл, огибающая выкл
        call Pr_Orn
        call Pt_Get
        call Pr_Smp2
        call Pr_EnvOff
        jp .cmd
.spec   ld b,a                      ; #01..#0F: код - в список, параметры - после строки
        ld a,(Pr_NCmd)
        cp PR_CMDS_MAX
        jp nc,.cmd
        push hl
        ld hl,Pr_Cmds
        call Hl_Add_A
        ld (hl),b
        ld hl,Pr_NCmd
        inc (hl)
        pop hl
        jp .cmd
.e10    call Pr_EnvOff              ; #10: огибающая выкл + сэмпл
        call Pt_Get
        call Pr_Smp2
        jp .cmd
.e1x    sub #11                     ; #11..#1F: форма x-1, период, сэмпл
        call Pr_Env
        call Pt_Get
        call Pr_Smp2
        jp .cmd
.noise  sub #20                     ; #20..#3F: шум (в заголовок чипа)
        call Pr_Noise
        jp .cmd
.orn    sub #40                     ; #40..#4F: орнамент
        call Pr_Orn
        jp .cmd
.eoff   call Pr_EnvOff              ; #B0
        jp .cmd
.skp    call Pt_Get                 ; #B1: пропуск строк
        ld e,a                      ; (Pc_Var портит A)
        push hl
        ld hl,Pc_Skip
        call Pc_Var
        ld (hl),e
        pop hl
        jp .cmd
.ebx    sub #B1                     ; #B2..#BF: форма x-1, период
        call Pr_Env
        jp .cmd
.vol    sub #C0                     ; #C1..#CF: громкость
        ld c,CH_VOLUME
        call Pr_Put
        jp .cmd
.smp    sub #D0                     ; #D1..#EF: сэмпл
        ld c,CH_SAMPLE
        call Pr_Put
        jp .cmd
.note   sub #50-NOTE_FIRST          ; #50..#AF: нота, конец строки
        jr .putn
.off    ld a,NOTE_OFF               ; #C0: звук выкл, конец строки
.putn   ld c,CH_NOTE
        call Pr_Put
.end    call Pr_Specials            ; параметры спецкоманд - после конца строки
        ex de,hl                    ; позиция в треке - на место
        ld hl,Pc_Ptr
        ld a,(Pp_Ch)
        add a,a
        call Hl_Add_A
        ld (hl),e
        inc hl
        ld (hl),d
        or a                        ; CF = 0
        ret

; Клетка канала: HL' не трогаем. A - значение, C - поле CH_* -> роу Pp_Row в окне 2
Pr_Put  push hl
        push af
        call Pr_Cell
        ld a,l
        add a,c
        ld l,a
        pop af
        ld (hl),a
        pop hl
        ret

; HL <- клетка канала Pp_Ch в роу Pp_Row (окно 2). A портит
Pr_Cell ld a,(Pp_Row)
        add a,#80
        ld h,a
        ld a,(Pp_Ch)                ; CHIP_CH_A + канал*16 + чип
        add a,a
        add a,a
        add a,a
        add a,a
        add a,CHIP_CH_A
        ld l,a
        ld a,(Pp_Chip)
        add a,l
        ld l,a
        ret

; Заголовок чипа в роу: HL <- поле C. A портит
Pr_Chip_Fld
        ld a,(Pp_Row)
        add a,#80
        ld h,a
        ld a,(Pp_Chip)
        add a,c
        ld l,a
        ret

; Сэмпл из байта smp*2: 0 ("W") -> 32
Pr_Smp2 srl a
        or a
        jr nz,$+4
        ld a,SAMPLES_MAX
        ld c,CH_SAMPLE
        jp Pr_Put

; Орнамент A (0..15): в паттерне - номер+1
Pr_Orn  inc a
        ld c,CH_ORNAMENT
        jp Pr_Put

; Огибающая выключена: форма 15
Pr_EnvOff
        ld a,15
        ld c,CH_ENVSHAPE
        jp Pr_Put

; Форма A (0..14; 0 - как 9: у AY то же звучание) + период (старший первым)
Pr_Env  or a
        jr nz,$+4
        ld a,9
        ld c,CH_ENVSHAPE
        call Pr_Put
        call Pt_Get                 ; старший
        ld d,a
        call Pt_Get                 ; младший
        ld e,a
        push hl
        ld c,CHIP_ENVPER
        call Pr_Chip_Fld
        ld (hl),e
        inc l
        ld (hl),d
        pop hl
        ret

; Шум A (0..31): 0 - #20 (у нас 0 = пусто)
Pr_Noise
        or a
        jr nz,$+4
        ld a,#20
        push hl
        ld c,CHIP_NOISE
        push af
        call Pr_Chip_Fld
        pop af
        ld (hl),a
        pop hl
        ret

;-------- Параметры спецкоманд: лежат после конца строки, с последней команды.
; Разбираем все (иначе собьёмся), в клетку - первые две (Pt_Lost - если больше)
Pr_Specials
        ld a,(Pr_NCmd)
        or a
        ret z
        ld b,a                      ; с последней
.c      push bc
        ld a,b
        dec a
        push af
        push hl
        ld hl,Pr_Cmds
        call Hl_Add_A
        ld a,(hl)
        pop hl
        call Pr_Spec                ; DE - команда (D - байт 0, E - байт 1)
        pop af
        push hl
        ld hl,Pr_Out                ; на её место в Pr_Out
        add a,a
        call Hl_Add_A
        ld (hl),d
        inc hl
        ld (hl),e
        pop hl
        pop bc
        djnz .c
        ld a,(Pr_NCmd)              ; в клетку - две первые
        cp CH_CMDS+1
        jr c,.put
        push hl
        ld hl,Pt_Lost
        set PL_CMDS,(hl)
        pop hl
        ld a,CH_CMDS
.put    ld b,a
        push hl
        call Pr_Cell
        ld a,l
        add a,CH_CMD
        ld l,a
        ex de,hl
        ld hl,Pr_Out
        ld a,b
        add a,a
        ld c,a
        ld b,0
        ldir
        pop hl
        ret

; Спецкоманда A (#01..#09): параметры из трека (HL) -> DE (D - код<<4|задержка, E - параметр)
Pr_Spec cp #01
        jr z,.glis
        cp #02
        jr z,.porta
        cp #03
        jr z,.sofs
        cp #04
        jr z,.oofs
        cp #05
        jr z,.vib
        cp #08
        jr z,.env
        cp #09
        jr z,.tempo
        ld de,0                     ; неизвестная - пусто (параметров не знаем)
        ret
.glis   call Pt_Get                 ; задержка, шаг (+ - частота вниз)
        ld b,CMD_GLIS_DOWN
        ld c,CMD_GLIS_UP
        jr .slide
.porta  call Pt_Get                 ; задержка, максимум (не нужен), шаг
        push af
        call Pt_Get16
        pop af
        ld b,CMD_PORTA
        ld c,CMD_PORTA
        jr .slide
.env    call Pt_Get
        ld b,CMD_ENV_DOWN
        ld c,CMD_ENV_UP
; A - задержка, B / C - код для шага >= 0 / < 0. Шаг - из трека
.slide  call Pr_Delay
        push af
        call Pt_Get16               ; шаг со знаком
        bit 7,d
        jr z,.pos
        ld b,c                      ; отрицательный - другой код, модуль
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
.pos    ld a,d                      ; больше 255 - 255
        or a
        jr z,$+4
        ld e,255
        pop af
        ld c,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        or c
        ld d,a
        ret
.sofs   ld b,CMD_SMP_OFS
        jr .one
.oofs   ld b,CMD_ORN_OFS
        jr .one
.tempo  ld b,CMD_SPEED
.one    call Pt_Get                 ; один параметр, без задержки
        ld e,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ret
.vib    call Pt_Get                 ; вкл, выкл - по нибблу
        call Pr_Delay
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        call Pt_Get
        call Pr_Delay
        or e
        ld e,a
        ld d,CMD_VIBRATO<<4
        ret

; A > 15 -> 15
Pr_Delay
        cp 16
        ret c
        ld a,15
        ret

Txt_Pt3Cut      db "PT3 cut:",0
Txt_BadPt3      db "Bad PT3",0

; Строку HL (до 0) -> DE, DE - на её 0 (следующая допишется). HL - за 0
Str_Copy
        ld a,(hl)
        ld (de),a
        inc hl
        or a
        ret z
        inc de
        jr Str_Copy

; HL - за 0 строки
Str_Skip
        ld a,(hl)
        inc hl
        or a
        jr nz,Str_Skip
        ret

; =========================================================================
; ФАЙЛ FT2 - КОНТЕЙНЕР (doc/formats/ft2.md): заголовок "FT2C" + блоки "тег, длина, данные"
; (нечётная длина - байт 0 за данными), только непустое; в конце "END " с CRC-16 всего, что до него.
; Запись - потоком (Fs_Write) через буфер Ob_Buf, длина блока - холостым проходом сериализатора.
; Чтение - файл целиком в буфер файла (до 64К), сначала проверка блоков и CRC, потом в трек.
; Старый формат ("FT2S", дамп памяти) читает Ft2_Load как раньше.
; =========================================================================
CN_VERSION      equ 1
CN_ROW_SEGS     equ 8               ; кусков в роу: заголовок чипа 1, A, B, C, заголовок чипа 2, D, E, F

; --- состояние
Cn_Crc          dw 0                ; CRC-16 CCITT записанного / прочитанного
Cn_N            db 0                ; номер в блоке (0..)
Cn_Rows         db 0                ; паттерн: роу
Cn_Pg           db 0                ; паттерн: страница
Cn_Cnt          ds 5                ; непустых: паттернов, инструментов, орнаментов, FX, таблиц
Cn_Skip         db 0                ; паттерн: пустых роу подряд
Cn_Mask         db 0                ;   маска кусков роу
Cn_Bm           dw 0                ;   маска байт куска

; =========================================================================
; ЗАПИСЬ
; =========================================================================
Ob_Mode         db 0                ; 1 - холостой проход: только считать длину
Ob_Len          dw 0                ; длина данных блока (холостой проход)
Ob_N            db 0                ; байт в буфере (0 - пусто)
Bo_Tag          dw 0
Bo_Ser          dw 0
Ob_Buf          ds 256

;-------- Байт A - в файл (через Ob_Buf) или в счёт длины. Регистры целы
Ob_Put
        push hl
        ld hl,Ob_Mode
        bit 0,(hl)
        jr nz,.cnt
        call Crc_Byte
        push af
        ld a,(Ob_N)
        ld hl,Ob_Buf
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        pop af
        ld (hl),a
        ld hl,Ob_N
        inc (hl)
        call z,Ob_Flush             ; 256 байт - на диск
        pop hl
        ret
.cnt    ld hl,(Ob_Len)
        inc hl
        ld (Ob_Len),hl
        pop hl
        ret

;-------- Ob_Buf (Ob_N байт, 0 - полный) - в поток. Регистры целы
Ob_Flush
        push af
        push bc
        push de
        push hl
        push ix
        ld a,(Ob_N)
        ld c,a
        ld b,0
        or a
        jr nz,$+3
        inc b                       ; 0 - 256
        ld hl,Ob_Buf
        call Fs_Write
        xor a
        ld (Ob_N),a
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret

;-------- CRC-16 CCITT (#1021) по байту A. Регистры целы
Crc_Byte
        push af
        push bc
        push hl
        ld hl,(Cn_Crc)
        xor h
        ld h,a
        ld b,8
.b      add hl,hl
        jr nc,.n
        ld a,h
        xor #10
        ld h,a
        ld a,l
        xor #21
        ld l,a
.n      djnz .b
        ld (Cn_Crc),hl
        pop hl
        pop bc
        pop af
        ret

;-------- Блок: HL - тег (4 знака), IX - сериализатор (кладёт данные через Ob_Put)
Blk_Out
        ld (Bo_Tag),hl
        ld (Bo_Ser),ix
        ld a,1                      ; холостой проход - длина
        ld (Ob_Mode),a
        ld hl,0
        ld (Ob_Len),hl
        call .ser
        xor a
        ld (Ob_Mode),a
        ld hl,(Bo_Tag)              ; тег, длина
        ld b,4
.t      ld a,(hl)
        call Ob_Put
        inc hl
        djnz .t
        ld a,(Ob_Len)
        call Ob_Put
        ld a,(Ob_Len+1)
        call Ob_Put
        call .ser                   ; данные
        ld a,(Ob_Len)               ; нечётная длина - байт 0
        rra
        ret nc
        xor a
        jp Ob_Put
.ser    ld hl,(Bo_Ser)
        jp (hl)

;-------- Строка HL (до B знаков, 0 - конец) - в блок, 0 на конце
Put_Str
.c      ld a,(hl)
        or a
        jr z,.e
        call Ob_Put
        inc hl
        djnz .c
.e      xor a
        jp Ob_Put

;-------- BC байт с HL - в блок
Put_Bytes
        ld a,b
        or c
        ret z
        ld a,(hl)
        call Ob_Put
        inc hl
        dec bc
        jr Put_Bytes

;-------- Трек -> файл (создан, открыт). CF - ошибка (сообщение стоит)
Cn_Save
        ld a,1                      ; поток - запись
        ld (Fs_Mode),a
        xor a
        ld (Fs_Err),a
        ld (Ob_N),a
        ld (Ob_Mode),a
        ld a,PAGE_FILEBUF
        ld (Fs_Page),a
        ld hl,#C000
        ld (Fs_Ptr),hl
        ld hl,#FFFF
        ld (Cn_Crc),hl
        call Cat_Get_Raw            ; каталог паттернов - в Dv_Cat
        call Cn_Count               ; сколько чего (для HEAD)
        ld hl,Cn_Magic              ; заголовок файла
        ld b,6
.m      ld a,(hl)
        call Ob_Put
        inc hl
        djnz .m
        ld hl,Tag_Head
        ld ix,Ser_Head
        call Blk_Out
        ld hl,Tag_Ordr
        ld ix,Ser_Ordr
        call Blk_Out
        xor a                       ; паттерны
.pat    ld (Cn_N),a
        ld (Cat_N),a
        call Cat_Len
        jr z,.pn
        ld (Cn_Rows),a
        ld hl,Tag_Patt
        ld ix,Ser_Patt
        call Blk_Out
.pn     ld a,(Cn_N)
        inc a
        cp PATTERNS_MAX
        jr c,.pat
        xor a                       ; инструменты
.ins    ld (Cn_N),a
        call Ins_Used
        jr z,.in
        ld hl,Tag_Inst
        ld ix,Ser_Inst
        call Blk_Out
.in     ld a,(Cn_N)
        inc a
        cp SAMPLES_MAX
        jr c,.ins
        xor a                       ; орнаменты
.orn    ld (Cn_N),a
        call Orn_Used
        jr z,.on
        ld hl,Tag_Ornm
        ld ix,Ser_Orn
        call Blk_Out
.on     ld a,(Cn_N)
        inc a
        cp ORNAMENTS_MAX
        jr c,.orn
        xor a                       ; FX
.fx     ld (Cn_N),a
        call Fx_Used
        jr z,.fn
        ld hl,Tag_Fxfx
        ld ix,Ser_Fx
        call Blk_Out
.fn     ld a,(Cn_N)
        inc a
        cp FXS_MAX
        jr c,.fx
        xor a                       ; таблицы
.tb     ld (Cn_N),a
        call Tab_Used
        jr z,.tn
        ld hl,Tag_Tabl
        ld ix,Ser_Tab
        call Blk_Out
.tn     ld a,(Cn_N)
        inc a
        jr nz,.tb                   ; 0..255
        ld de,(Cn_Crc)              ; END: CRC всего, что до него
        push de
        ld hl,Tag_End
        ld b,4
.e      ld a,(hl)
        call Ob_Put
        inc hl
        djnz .e
        ld a,2
        call Ob_Put
        xor a
        call Ob_Put
        pop de
        ld a,e
        call Ob_Put
        ld a,d
        call Ob_Put
        ld a,(Ob_N)                 ; остаток буфера
        or a
        call nz,Ob_Flush
        ld a,(Fs_Err)               ; полные страницы уже на диске (Fs_Step)
        or a
        scf
        ret nz
        ld hl,(Fs_Ptr)              ; хвост - неполная страница
        ld a,h
        sub #C0
        ld h,a
        or l
        ret z
        jp Sv_Append

Cn_Magic        db "FT2C",CN_VERSION,0
Tag_Head        db "HEAD"
Tag_Ordr        db "ORDR"
Tag_Patt        db "PATT"
Tag_Inst        db "INST"
Tag_Ornm        db "ORNM"
Tag_Fxfx        db "FX16"            ; FX - новый формат (старые FXFX \/ TABL не читаем)
Tag_Tabl        db "TB16"
Tag_End         db "END "

;-------- Каталог паттернов трека - как есть в Dv_Cat (страницы - из трека)
Cat_Get_Raw
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,#8000+PAT_CATALOG
        ld de,Dv_Cat
        ld bc,PATTERNS_MAX*PC_SIZE
        ldir
        RESTPAGE2
        ret

;-------- Сколько непустых каждого вида -> Cn_Cnt
Cn_Count
        ld hl,Cn_Cnt
        ld b,5
.z      ld (hl),0
        inc hl
        djnz .z
        xor a
.p      ld (Cn_N),a
        ld (Cat_N),a
        call Cat_Len
        jr z,$+6
        ld hl,Cn_Cnt
        inc (hl)
        ld a,(Cn_N)
        inc a
        cp PATTERNS_MAX
        jr c,.p
        ld de,Cn_Cnt+1
        ld b,SAMPLES_MAX
        ld ix,Ins_Used
        call .cnt
        ld de,Cn_Cnt+2
        ld b,ORNAMENTS_MAX
        ld ix,Orn_Used
        call .cnt
        ld de,Cn_Cnt+3
        ld b,FXS_MAX
        ld ix,Fx_Used
        call .cnt
        ld de,Cn_Cnt+4
        ld b,low FXT_MAX            ; 256
        ld ix,Tab_Used
; B номеров, IX - проверка (NZ - непустой), DE - счётчик
.cnt    xor a
.c      ld (Cn_N),a
        push bc
        push de
        push ix
        call .call
        pop ix
        pop de
        pop bc
        jr z,$+4
        ex de,hl
        inc (hl)
        ex de,hl
        ld a,(Cn_N)
        inc a
        djnz .c
        ret
.call   jp (ix)

;-------- Пустой ли номер Cn_N: Z - пустой (как после очистки трека), NZ - есть что писать
; Инструмент: одна строка "тон, шум выкл, громкость 15", без FX и имени (Ins_Clear; имя - в странице трека)
Ins_Used
        call Ins_Addr
        ld a,(Trk_Ins)
        SETPAGE2 a
        ld ix,(Cn_Addr)
        ld a,(ix+OH_LOOP)
        or (ix+OH_END)
        or (ix+OH_ROWS+IR_TONE)
        or (ix+OH_ROWS+IR_TONE+1)
        or (ix+OH_ROWS+IR_ENV)
        ld b,a
        ld hl,(Cn_Addr)             ; FX
        ld de,INS_FX
        add hl,de
        ld a,(hl)
        or b
        ld b,a
        ld a,(ix+OH_ROWS+IR_NOISE)
        xor 1<<IRB_OFF
        or b
        ld b,a
        ld a,(ix+OH_ROWS+IR_VOL)
        xor 15
        or b
        ld (Cn_Res),a
        RESTPAGE2
        ld a,(SV_SONG_PAGE)         ; первая буква имени (страница трека)
        SETPAGE2 a
        call Insn_Addr
        ld hl,(Cn_Addr)
        ld a,(Cn_Res)
        or (hl)
        ld (Cn_Res),a
        RESTPAGE2
        ld a,(Cn_Res)
        or a
        ret
Cn_Res          db 0
Cn_Addr         dw 0

; Орнамент: нули (одна строка без сдвига), без имени
Orn_Used
        call Orn_Addr
        ld a,(Trk_Orn)
        jp Zero_Used
; FX (новый формат): заголовок не по умолчанию, имя или строки 0..последняя - не нули
Fx_Used
        call Fxh_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,(Cn_Addr)
        ld a,(hl)                   ; FXH_END - последняя строка
        and FX_ROWS_MAX-1
        ld (Cn_Rows),a
        ld a,(hl)
        inc hl
        or (hl)                     ; цикл
        inc hl
        ld b,a
        ld a,(hl)                   ; форма свипа: по умолчанию - треугольник
        xor FXT_TRI
        or b
        inc hl
        or (hl)                     ; фаза
        inc hl
        or (hl)                     ; флаги
        ld (Cn_Res),a
        RESTPAGE2
        ld a,(SV_SONG_PAGE)         ; имя
        SETPAGE2 a
        call Fxn_Addr
        ld hl,(Cn_Addr)
        ld a,(Cn_Res)
        or (hl)
        ld (Cn_Res),a
        RESTPAGE2
        ld a,(Trk_Fx)               ; строки 0..последняя
        SETPAGE2 a
        call Fxr_Addr
        ld a,(Cn_Rows)
        inc a
        ld b,a
        ld a,(Cn_Res)
        ld hl,(Cn_Addr)
.r      ld c,FXR_SIZE
.b      or (hl)
        inc hl
        dec c
        jr nz,.b
        djnz .r
        jp Zu_End
; Таблица FX: не как у нового трека (0..5 - пресет, остальные - нули)
Tab_Used
        call Fxt_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld b,FXT_SIZE
        ld a,(Cn_N)
        cp FXT_PRESETS
        jr nc,.zero
        ld de,(Cn_Addr)             ; пресет: Fx_Presets + n*16
        res 7,d
        ld hl,Fx_Presets
        add hl,de
        ex de,hl
        ld hl,(Cn_Addr)
        ld c,0
.p      ld a,(de)
        xor (hl)
        or c
        ld c,a
        inc hl
        inc de
        djnz .p
        ld a,c
        jp Zu_End
.zero   ld hl,(Cn_Addr)
        xor a
.z      or (hl)
        inc hl
        djnz .z
        jp Zu_End
; A - страница, Cn_Addr - блок: заголовок OH_*, строка 0 (Cn_RowSz байт), имя (Cn_NameOfs) - нули?
Zero_Used
        SETPAGE2 a
        ld hl,(Cn_Addr)
        inc hl                      ; OH_LOOP, OH_END
        ld a,(hl)
        inc hl
        or (hl)
        inc hl                      ; строка 0
        ld c,a
        ld a,(Cn_RowSz)
        ld b,a
        ld a,c
.o      or (hl)
        inc hl
        djnz .o
        ld c,a                      ; имя
        ld hl,(Cn_Addr)
        ld de,(Cn_NameOfs)
        add hl,de
        ld a,c
        or (hl)
Zu_End  ld (Cn_Res),a
        RESTPAGE2
        ld a,(Cn_Res)
        or a
        ret
Cn_RowSz        db 0
Cn_NameOfs      dw 0

;-------- Адрес блока номера Cn_N в окне 2 -> Cn_Addr; для Zero_Used - размер строки и имя
; инструмент: #8000 + n*512 (страница Trk_Ins)
Ins_Addr
        ld a,(Cn_N)
        add a,a
        add a,#80
        ld h,a
        ld l,0
        ld (Cn_Addr),hl
        ret
    ASSERT INS_BLOCK == 512
; орнамент: #8000 + n*512 (страница Trk_Orn)
Orn_Addr
        ld a,(Cn_N)
        add a,a
        add a,#80
        ld h,a
        ld l,0
        ld (Cn_Addr),hl
        ld a,ORN_ROW_SIZE
        ld (Cn_RowSz),a
        ld hl,ORN_NAME
        ld (Cn_NameOfs),hl
        ret
    ASSERT ORN_BLOCK == 512
; FX: строки - #8000 + n*512 (страница Trk_Fx)
Fxr_Addr
        ld a,(Cn_N)
        add a,a
        add a,#80
        ld h,a
        ld l,0
        ld (Cn_Addr),hl
        ret
    ASSERT FXR_BLOCK == 512
; FX: заголовок - #8000 + FXH_BASE + n*8 (страница Trk_FxT)
Fxh_Addr
        ld a,(Cn_N)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,#8000+FXH_BASE
        add hl,de
        ld (Cn_Addr),hl
        ret
    ASSERT FXH_SIZE == 8
; FX: имя - #8000 + SONG_FX_NAMES + n*16 (страница трека)
Fxn_Addr
        ld de,#8000+SONG_FX_NAMES
        jr N16_Addr
; инструмент: имя - #8000 + SONG_INS_NAMES + n*16 (страница трека: в блок не влезло)
Insn_Addr
        ld de,#8000+SONG_INS_NAMES
        jr N16_Addr
; таблица: #8000 + n*16 (страница Trk_FxT)
Fxt_Addr
        ld de,#8000
; DE + Cn_N*16 -> Cn_Addr
N16_Addr
        ld a,(Cn_N)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (Cn_Addr),hl
        ret
    ASSERT FXT_SIZE == 16

;-------- Сериализаторы блоков (данные - через Ob_Put)
; HEAD: чипы, скорость, Tune, тип чипа, стерео, огибающая, шаг, флаги, счётчики, имя, автор
Ser_Head
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,Head_Fields
        ld b,HEAD_FIELDS
.f      push hl
        ld e,(hl)
        ld d,#80
        ld a,(de)
        call Ob_Put
        pop hl
        inc hl
        djnz .f
        ld a,(Cn_Cnt+3)             ; флаги: бит 0 - есть FX
        or a
        jr z,$+4
        ld a,1
        call Ob_Put
        ld hl,Cn_Cnt
        ld b,5
.c      ld a,(hl)
        call Ob_Put
        inc hl
        djnz .c
        ld hl,#8000+SH_NAME
        ld b,32
        call Put_Str
        ld hl,#8000+SH_AUTHOR
        ld b,32
        call Put_Str
        RESTPAGE2
        ret
Head_Fields     db SH_CHIPS, SH_SPEED, SH_TUNING, SH_DEVICE, SH_STEREO, SH_ENVMODE ; настроек редактора нет
HEAD_FIELDS     equ $-Head_Fields
    ASSERT SH_ENVMODE < 256

; ORDR: последняя позиция, цикл, номера паттернов
Ser_Ordr
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,(#8000+ORD_LAST)
        call Ob_Put
        ld a,(#8000+ORD_LOOP)
        call Ob_Put
        ld a,(#8000+ORD_LAST)
        ld c,a
        ld b,0
        inc bc
        ld hl,#8000+ORD_POS
        call Put_Bytes
        RESTPAGE2
        ret

; PATT: номер, роу, записи непустых роу (пропуск, маска кусков, по куску - маска байт и байты)
Seg_Ofs         db 0, CHIP_CH_A, CHIP_CH_B, CHIP_CH_C
                db CHIP_SIZE, CHIP_SIZE+CHIP_CH_A, CHIP_SIZE+CHIP_CH_B, CHIP_SIZE+CHIP_CH_C
Ser_Patt
        ld a,(Cn_N)                 ; страница паттерна - из каталога
        add a,a
        ld hl,Dv_Cat
        call Hl_Add_A
        ld a,(hl)
        ld (Cn_Pg),a
        SETPAGE2 a
        ld a,(Cn_N)
        call Ob_Put
        ld a,(Cn_Rows)
        call Ob_Put
        xor a
        ld (Cn_Skip),a
        ld h,#80                    ; H - роу
.row    call Row_Mask               ; Cn_Mask - непустые куски
        ld a,(Cn_Mask)
        or a
        jr nz,.put
        ld a,(Cn_Skip)              ; пустая - в счёт пропуска
        inc a
        ld (Cn_Skip),a
        jr .next
.put    ld a,(Cn_Skip)
        call Ob_Put
        xor a
        ld (Cn_Skip),a
        ld a,(Cn_Mask)
        call Ob_Put
        ld de,Seg_Ofs               ; куски: маска байт, байты
        ld c,0                      ; C - кусок
.seg    ld a,(Cn_Mask)
        ld b,c
        inc b
.sh     rrca
        djnz .sh
        jr nc,.sn
        ld a,(de)
        ld l,a
        ld a,c                      ; заголовок чипа (0, 4) - 8 байт, канал - 16
        and 3
        ld b,CHIP_HDR_SIZE
        jr z,$+4
        ld b,CH_SIZE
        push de
        push bc
        call Seg_Out
        pop bc
        pop de
.sn     inc de
        inc c
        ld a,c
        cp CN_ROW_SEGS
        jr c,.seg
.next   inc h                       ; роу кончились?
        ld a,(Cn_Rows)
        add a,#80
        cp h
        jr z,.done
        jr nc,.row
.done
        RESTPAGE2
        ret
    ASSERT CHIP_CH_A == CHIP_HDR_SIZE

; Роу H (окно 2): Cn_Mask - бит n, если кусок n не пустой. H цел
Row_Mask
        xor a
        ld (Cn_Mask),a
        ld de,Seg_Ofs
        ld c,1                      ; C - бит куска
.s      ld a,(de)
        ld l,a
        ld a,c
        and %00010001               ; заголовки чипов - 8 байт
        ld b,CHIP_HDR_SIZE
        jr nz,$+4
        ld b,CH_SIZE
        xor a
.b      or (hl)
        inc l
        djnz .b
        or a
        jr z,.e
        ld a,(Cn_Mask)
        or c
        ld (Cn_Mask),a
.e      inc de
        sla c
        jr nz,.s
        ret

; Кусок: HL - начало (окно 2), B - байт (8 / 16): маска байт (1 или 2 байта), потом непустые
Seg_Out
        push hl
        push bc
        ld de,0                     ; DE - маска (бит n - байт n не ноль)
        ld c,1
.m      ld a,(hl)
        or a
        jr z,.mz
        ld a,c
        cp 9                        ; биты 8..15 - в D
        jr c,.lo
        sub 8
        call Bit_A
        or d
        ld d,a
        jr .mz
.lo     call Bit_A
        or e
        ld e,a
.mz     inc l
        inc c
        djnz .m
        pop bc
        pop hl
        ld a,e
        call Ob_Put
        ld a,b                      ; канал - второй байт маски
        cp CH_SIZE
        jr nz,.d
        ld a,d
        call Ob_Put
.d      ld a,(hl)                   ; непустые байты
        or a
        call nz,Ob_Put
        inc l
        djnz .d
        ret
; A - номер бита 1..8 -> A - его вес (1 << (A-1))
Bit_A   push bc
        ld b,a
        ld a,1
        dec b
        jr z,.e
.s      add a,a
        djnz .s
.e      pop bc
        ret

; INST: номер, цикл, последняя строка, строки, FX, имя
Ser_Inst
        call Ins_Addr
        ld a,(Trk_Ins)
        SETPAGE2 a
        ld ix,(Cn_Addr)
        ld a,(Cn_N)
        inc a
        call Ob_Put
        ld a,(ix+OH_LOOP)
        call Ob_Put
        ld a,(ix+OH_END)
        call Ob_Put
        ld a,(ix+OH_END)            ; строки: (последняя+1) * 5
        inc a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Put_Bytes
        ld hl,(Cn_Addr)
        ld de,INS_FX
        add hl,de
        ld a,(hl)
        call Ob_Put
        RESTPAGE2
        ld a,(SV_SONG_PAGE)         ; имя - из страницы трека
        SETPAGE2 a
        call Insn_Addr
        ld hl,(Cn_Addr)
        ld b,16
        call Put_Str
        RESTPAGE2
        ret
    ASSERT INS_ROW_SIZE == 5

; ORNM / FXFX: номер, цикл, последняя строка, строки (Cn_RowSz байт), имя (Cn_NameOfs)
Ser_Orn
        call Orn_Addr
        ld a,(Trk_Orn)
        jr Ser_Rows
Ser_Rows
        SETPAGE2 a
        ld ix,(Cn_Addr)
        ld a,(Cn_N)
        inc a
        call Ob_Put
        ld a,(ix+OH_LOOP)
        call Ob_Put
        ld a,(ix+OH_END)
        call Ob_Put
        ld a,(ix+OH_END)            ; строки: (последняя+1) * размер
        inc a
        ld e,a
        ld d,0
        ld hl,0
        ld a,(Cn_RowSz)
        ld b,a
.mul    add hl,de
        djnz .mul
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Put_Bytes
        ld hl,(Cn_Addr)
        ld de,(Cn_NameOfs)
        add hl,de
        ld b,16
        call Put_Str
        RESTPAGE2
        ret

; FX16: номер, заголовок (FXH_SAVED байт), строки 0..последняя (по 16), имя
Ser_Fx
        ld a,(Cn_N)
        inc a
        call Ob_Put
        call Fxh_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,(Cn_Addr)
        ld a,(hl)
        and FX_ROWS_MAX-1
        ld (Cn_Rows),a
        ld bc,FXH_SAVED
        call Put_Bytes
        RESTPAGE2
        ld a,(Trk_Fx)
        SETPAGE2 a
        call Fxr_Addr
        call Fx_Rows_Len
        ld hl,(Cn_Addr)
        call Put_Bytes
        RESTPAGE2
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        call Fxn_Addr
        ld hl,(Cn_Addr)
        ld b,16
        call Put_Str
        RESTPAGE2
        ret
; BC = (Cn_Rows + 1) * 16 - байт строк FX
Fx_Rows_Len
        ld a,(Cn_Rows)
        inc a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ret

; TB16: номер (0..255), 16 значений
Ser_Tab
        ld a,(Cn_N)
        call Ob_Put
        call Fxt_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,(Cn_Addr)
        ld bc,FXT_SIZE
        call Put_Bytes
        RESTPAGE2
        ret

; =========================================================================
; ЧТЕНИЕ (файл - в буфере файла, Pt_Base = 0)
; =========================================================================
In_Pos          dw 0                ; смещение в файле
Cn_Size         dw 0                ; размер файла
Blk_End         dw 0                ; конец данных текущего блока
Cn_Tag          ds 4
Blk_Len         dw 0

;-------- Байт файла -> A. BC, DE целы
In_Get
        push hl
        ld hl,(In_Pos)
        call Pt_Get
        ld (In_Pos),hl
        pop hl
        ret

;-------- Заголовок блока с In_Pos: Cn_Tag, Blk_Len, Blk_End. CF - за концом файла
Blk_Head
        ld hl,(In_Pos)              ; хватает места на заголовок?
        ld de,6
        add hl,de
        ex de,hl
        ld hl,(Cn_Size)
        or a
        sbc hl,de
        ret c
        ld hl,Cn_Tag
        ld b,4
.t      call In_Get
        ld (hl),a
        inc hl
        djnz .t
        call In_Get
        ld (Blk_Len),a
        call In_Get
        ld (Blk_Len+1),a
        ld hl,(In_Pos)
        ld de,(Blk_Len)
        add hl,de
        ld (Blk_End),hl
        ex de,hl                    ; данные - в файле?
        ld hl,(Cn_Size)
        or a
        sbc hl,de
        ret
;-------- На следующий блок (за данными и байтом выравнивания)
Blk_Next
        ld hl,(Blk_End)
        ld a,(Blk_Len)
        rra
        jr nc,$+3
        inc hl
        ld (In_Pos),hl
        ret

;-------- Тег HL == Cn_Tag? Z - да
Tag_Is
        ld de,Cn_Tag
        ld b,4
.c      ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .c
        ret

;-------- Файл "FT2C" (в буфере, HL - размер) -> трек. Ошибки - сообщением
Cn_Load
        ld (Cn_Size),hl
        ld hl,0                     ; Pt_Get - смещения от начала буфера
        ld (Pt_Base),hl
        ld hl,4                     ; версия
        call Pt_Get
        cp CN_VERSION+1
        jp nc,.new
        ld hl,#FFFF                 ; 1. блоки до END и CRC
        ld (Cn_Crc),hl
        ld hl,6
        ld (In_Pos),hl
.walk   call Blk_Head
        jp c,.bad
        ld hl,Tag_End
        call Tag_Is
        jr z,.end
        call Blk_Next
        jr .walk
.end    ld hl,(In_Pos)              ; CRC всего до тега END
        ld de,-6
        add hl,de
        ld b,h
        ld c,l
        ld hl,0
.crc    ld a,b
        or c
        jr z,.cmp
        call Pt_Get
        call Crc_Byte
        dec bc
        jr .crc
.cmp    call In_Get                 ; записанная CRC
        ld e,a
        call In_Get
        ld d,a
        ld hl,(Cn_Crc)
        or a
        sbc hl,de
        jp nz,.bad
        call Song_New               ; 2. трек - пустой, потом блоки по местам
        ld hl,6
        ld (In_Pos),hl
.blk    call Blk_Head
        ld hl,Tag_End
        call Tag_Is
        jr z,.done
        ld hl,Ld_Tags
.d      ld a,(hl)                   ; тег -> обработчик (незнакомый - мимо)
        or a
        jr z,.skip
        push hl
        call Tag_Is
        pop hl
        jr z,.go
        ld de,6
        add hl,de
        jr .d
.go     ld de,4
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .jp
.skip   call Blk_Next
        jr .blk
.jp     jp (hl)
.done   ld hl,Dv_Spec+1             ; имя файла - в трек (шапка)
        call Dv_Song_File
        ld a,1                      ; вид паттерна перечитает трек при входе
        ld (SV_SONG_NEW),a
        jp Dv_Loaded
.bad    ld hl,Txt_Damaged
        jp Dv_Error
.new    ld hl,Txt_NewFmt
        jp Dv_Error

Ld_Tags db "HEAD"
        dw Ld_Head
        db "ORDR"
        dw Ld_Ordr
        db "PATT"
        dw Ld_Patt
        db "INST"
        dw Ld_Inst
        db "ORNM"
        dw Ld_Orn
        db "FX16"
        dw Ld_Fx
        db "TB16"
        dw Ld_Tab
        db 0

;-------- Строка из файла (до 0) -> HL, не больше B знаков (лишнее - пропустить)
Get_Str
.c      call In_Get
        or a
        ret z
        inc b
        dec b
        jr z,.c
        ld (hl),a
        inc hl
        dec b
        jr .c

;-------- BC байт из файла -> HL
Get_Bytes
        ld a,b
        or c
        ret z
        call In_Get
        ld (hl),a
        inc hl
        dec bc
        jr Get_Bytes

; HEAD
Ld_Head
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,Head_Fields
        ld b,HEAD_FIELDS
.f      ld e,(hl)
        ld d,#80
        call In_Get
        ld (de),a
        inc hl
        djnz .f
        ld b,6                      ; флаги и счётчики - не нужны
.s      call In_Get
        djnz .s
        ld hl,#8000+SH_NAME
        ld b,32
        call Get_Str
        ld hl,#8000+SH_AUTHOR
        ld b,32
        call Get_Str
        RESTPAGE2
        ret

; ORDR
Ld_Ordr
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        call In_Get
        ld (#8000+ORD_LAST),a
        call In_Get
        ld (#8000+ORD_LOOP),a
        ld a,(#8000+ORD_LAST)
        ld c,a
        ld b,0
        inc bc
        ld hl,#8000+ORD_POS
        call Get_Bytes
        RESTPAGE2
        ret

; PATT
Ld_Patt
        call In_Get                 ; номер, роу
        cp PATTERNS_MAX
        ret nc
        ld (Cn_N),a
        call In_Get
        or a
        ret z
        cp PAT_ROWS_MAX+1
        ret nc
        ld (Cn_Rows),a
        ld a,(SV_SONG_PAGE)         ; каталог: страница, длина
        SETPAGE2 a
        ld a,(Cn_N)
        add a,a
        ld l,a
        ld de,#8000+PAT_CATALOG
        ld h,0
        add hl,de
        ld a,(Cn_N)
        call Pat_Page
        ld (hl),a
        ld (Cn_Pg),a
        inc hl
        ld a,(Cn_Rows)
        ld (hl),a
        RESTPAGE2
        ld a,(Cn_Pg)
        SETPAGE2 a
        call Pat_Zero
        ld h,#80                    ; H - роу
.rec    push hl                     ; записи, пока не кончился блок
        ld hl,(In_Pos)
        ld de,(Blk_End)
        or a
        sbc hl,de
        pop hl
        jr nc,.out
        call In_Get                 ; пропуск
        add a,h
        ld h,a
        call In_Get                 ; маска кусков
        ld (Cn_Mask),a
        ld de,Seg_Ofs
        ld c,1
.seg    ld a,(Cn_Mask)
        and c
        jr z,.sn
        ld a,(de)
        ld l,a
        push de
        push bc
        call In_Get                 ; маска байт
        ld e,a
        ld d,0
        ld b,CHIP_HDR_SIZE
        ld a,c
        and %00010001
        jr nz,.bytes
        call In_Get
        ld d,a
        ld b,CH_SIZE
.bytes  srl d                       ; следующий бит маски -> CF
        rr e
        jr nc,$+6
        call In_Get
        ld (hl),a
        inc l
        djnz .bytes
        pop bc
        pop de
.sn     inc de
        sla c
        jr nz,.seg
        inc h
        jr .rec
.out    RESTPAGE2
        ret

; INST
Ld_Inst
        call In_Get
        dec a
        cp SAMPLES_MAX
        ret nc
        ld (Cn_N),a
        call Ins_Addr
        ld a,(Trk_Ins)
        SETPAGE2 a
        ld ix,(Cn_Addr)
        call In_Get
        ld (ix+OH_LOOP),a
        call In_Get
        cp INS_ROWS_MAX
        jr c,$+4
        ld a,INS_ROWS_MAX-1
        ld (ix+OH_END),a
        ld (ix+OH_LEN),a
        inc a                       ; строки * 5
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Get_Bytes
        ld hl,(Cn_Addr)
        ld de,INS_FX
        add hl,de
        call In_Get
        ld (hl),a
        RESTPAGE2
        ld a,(SV_SONG_PAGE)         ; имя - в страницу трека
        SETPAGE2 a
        call Insn_Addr
        ld hl,(Cn_Addr)
        ld b,16
        call Get_Str
        RESTPAGE2
        ret

; ORNM, FXFX
Ld_Orn
        call In_Get
        dec a
        cp ORNAMENTS_MAX
        ret nc
        ld (Cn_N),a
        call Orn_Addr
        ld a,(Trk_Orn)
        ld b,ORN_ROWS_MAX
        jp Ld_Rows
; FX16
Ld_Fx
        call In_Get
        dec a
        cp FXS_MAX
        ret nc
        ld (Cn_N),a
        call Fxh_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,(Cn_Addr)
        ld bc,FXH_SAVED
        call Get_Bytes
        ld hl,(Cn_Addr)
        ld a,(hl)
        and FX_ROWS_MAX-1
        ld (hl),a
        ld (Cn_Rows),a
        RESTPAGE2
        ld a,(Trk_Fx)
        SETPAGE2 a
        call Fxr_Addr
        call Fx_Rows_Len
        ld hl,(Cn_Addr)
        call Get_Bytes
        RESTPAGE2
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        call Fxn_Addr
        ld hl,(Cn_Addr)
        ld b,16
        call Get_Str
        RESTPAGE2
        ret
; A - страница, B - строк максимум, Cn_Addr / Cn_RowSz / Cn_NameOfs
Ld_Rows
        ld c,b
        ld (Lr_Max),bc
        SETPAGE2 a
        ld ix,(Cn_Addr)
        call In_Get
        ld (ix+OH_LOOP),a
        call In_Get
        ld hl,Lr_Max
        cp (hl)
        jr c,$+4
        ld a,(hl)
        dec a
        ld (ix+OH_END),a
        ld (ix+OH_LEN),a
        inc a                       ; строки * размер
        ld e,a
        ld d,0
        ld hl,0
        ld a,(Cn_RowSz)
        ld b,a
.mul    add hl,de
        djnz .mul
        ld b,h
        ld c,l
        ld hl,(Cn_Addr)
        ld de,OH_ROWS
        add hl,de
        call Get_Bytes
        ld hl,(Cn_Addr)
        ld de,(Cn_NameOfs)
        add hl,de
        ld b,16
        call Get_Str
        RESTPAGE2
        ret
Lr_Max          dw 0

; TB16
Ld_Tab
        call In_Get
        ld (Cn_N),a
        call Fxt_Addr
        ld a,(Trk_FxT)
        SETPAGE2 a
        ld hl,(Cn_Addr)
        ld bc,FXT_SIZE
        call Get_Bytes
        RESTPAGE2
        ret

Txt_Damaged     db "File is damaged (CRC)",0
Txt_NewFmt      db "Newer FT2 format",0

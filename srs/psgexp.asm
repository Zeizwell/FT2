; =========================================================================
; ЭКСПОРТ PSG (тулза диска, кнопка PSG): трек с позиции 0 до конца (Pl_Looped) - регистры AY чипа 1 по кадрам
; в файл <имя>.psg. Плеер играет без вывода в AY (коре Psg_Tick), музыка IM1 на это время стоит.
; Формат - как PSG Bitphase: заголовок 16 байт ("PSG",#1A, нули), кадр - #FF, за ним пары «регистр, значение»
; только изменившихся регистров R0..R12; R13 - когда записан в этом кадре (перезапуск огибающей).
; Таймерные эффекты карты в PSG не попадают (они быстрее кадра).
; =========================================================================
PS_FRAMES_MAX   equ 65000           ; ~21 мин при 50 Гц: дальше - стоп (трек без конца)

Ps_Player       db 0                ; SV_PLAYER до экспорта
Ps_Frames       dw 0
Ps_Ptr          dw 0                ; куда следующий кадр в странице буфера файла (окно 3)
Ps_Prev         ds 13               ; R0..R12 прошлого кадра
Ps_F            ds 1+14*2           ; кадр: #FF, пары
Ps_FN           db 0                ; байт в кадре
Ps_Head         db "PSG",#1A
                ds 12
Ps_Del          db FD_FILE          ; DELETE: флаг, имя
Ps_Nm           ds NAME_W+1
Ps_Cre          db #20,0,0,0,0      ; CREATE: атрибут, размер, имя
                ds NAME_W+1
Txt_PsgBusy     db "PSG...",0
Txt_PsgOk       db "PSG OK",0
Txt_Psg         db " PSG",0

;-------- Кнопка PSG
Dv_Psg
        ld a,(Dv_Mounted)
        or a
        ret z
        ld a,(Dv_Name_Len)
        or a
        jr nz,.name
        ld hl,Txt_NoName
        jp Dv_Error
.name   ld hl,Txt_PsgBusy           ; статус - сразу: прогон долгий
        call Dv_Busy
        call Ps_Name
        ld ix,DK_FIND+256           ; такой файл есть?
        ld hl,Ps_Del
        call Disk_Call
        jp c,Dv_Disk_Err
        jr z,.new
        ld a,(Sv_Force)             ; есть: без подтверждения - спросить, как Save
        or a
        jr nz,.ovr
        ld a,ASK_PSG
        ld (Sv_Ask),a
        ld hl,Txt_Exists
        call Dv_Ok
        ld a,1                      ; строка ждёт ответа: "(Y/N) Y"
        ld (Lg_Open),a
        ret
.ovr    xor a
        ld (Sv_Force),a
        ld ix,DK_DELETE+256         ; Yes - старый удалить
        ld hl,Ps_Del
        call Disk_Call
        jp nz,Dv_Disk_Err
.new
        ld hl,Ps_Nm
        ld de,Ps_Cre+5
        ld bc,NAME_W+1
        ldir
        ld ix,DK_CREATE+256
        ld hl,Ps_Cre
        call Disk_Call
        jp nz,Dv_Disk_Err
        call Ps_Run
        ret c                       ; ошибка диска - сообщение стоит
        ld ix,DK_CLOSE
        call Disk_Call
        jp nz,Dv_Disk_Err
        call Dv_List
        ld hl,Txt_PsgOk
        jp Dv_Ok

;-------- Имя из поля Name без расширения + ".psg" -> Ps_Nm
Ps_Name
        ld hl,Dv_Name
        ld de,Ps_Nm
        ld b,NAME_W-4               ; + ".psg" должно влезть
.c      ld a,(hl)
        or a
        jr z,.ext
        cp '.'
        jr z,.ext
        ld (de),a
        inc hl
        inc de
        djnz .c
.ext    ld hl,Txt_PsgExt
        ld bc,5
        ldir
        ret
Txt_PsgExt      db ".psg",0

;-------- Прогон: заголовок, кадры до конца трека, хвост буфера на диск. CF - ошибка диска
Ps_Run
        ld a,(SV_PLAYER)            ; музыку IM1 - стоп (плеер зовём сами)
        ld (Ps_Player),a
        xor a
        ld (SV_PLAYER),a
        ld (SV_PLAY_CPOS),a         ; трек с начала
        ld (SV_PLAY_CROW),a
        ld a,PC_SONG
        ld (SV_PLAY_CMD),a
        ld hl,0
        ld (Ps_Frames),hl
        ld hl,Ps_Prev               ; первый кадр - все регистры (прошлых нет)
        ld (hl),#FF
        ld de,Ps_Prev+1
        ld bc,12
        ldir
        ld hl,#C000                 ; заголовок - в начало страницы буфера
        ld (Ps_Ptr),hl
        ld hl,Ps_Head
        ld b,16
        call Ps_Copy
.f      call Psg_Tick               ; кадр
        call Ps_Frame
        call Ps_Copy_F
        call Ps_Full                ; страница полна - на диск
        jr c,.end
        ld hl,(Ps_Frames)
        inc hl
        ld (Ps_Frames),hl
        ld de,PS_FRAMES_MAX
        or a
        sbc hl,de
        jr nc,.tail
        ld a,(Ps_End)               ; трек дошёл до конца
        or a
        jr z,.f
.tail   ld hl,(Ps_Ptr)              ; хвост страницы - на диск
        ld de,#C000
        or a
        sbc hl,de
        call Sv_Append
.end    push af                     ; CF - ошибка
        ld a,PC_STOP                ; плеер - стоп, музыка IM1 - как была
        ld (SV_PLAY_CMD),a
        ld a,(Ps_Player)
        ld (SV_PLAYER),a
        pop af
        ret

;-------- Ps_Regs (коре, Psg_Tick) -> кадр Ps_F: #FF, изменившиеся R0..R12, R13 - если записан; Ps_FN - байт
Ps_Frame
        ld ix,Ps_F+1                ; IX - куда следующая пара
        ld hl,Ps_Regs
        ld de,Ps_Prev
        ld b,0                      ; B - номер регистра
.r      ld a,(de)
        cp (hl)
        jr z,.n
        ld a,(hl)                   ; изменился - пара в кадр, прошлое - новое
        ld (de),a
        ld (ix+0),b
        ld (ix+1),a
        inc ix
        inc ix
.n      inc hl
        inc de
        inc b
        ld a,b
        cp 13
        jr c,.r
        ld a,(hl)                   ; R13: #FF - не писали
        cp #FF
        jr z,.e
        ld (ix+0),13
        ld (ix+1),a
        inc ix
        inc ix
.e      ld a,#FF
        ld (Ps_F),a
        push ix
        pop hl
        ld de,Ps_F
        or a
        sbc hl,de
        ld a,l
        ld (Ps_FN),a
        ret

;-------- Кадр Ps_F (Ps_FN байт) -> страница буфера файла (окно 3) с Ps_Ptr
Ps_Copy_F
        ld hl,Ps_F
        ld a,(Ps_FN)
        ld b,a
; B байт с HL -> страница буфера файла с Ps_Ptr
Ps_Copy
        ld a,b
        ld (Ps_FN),a
        ld (Ps_Src),hl
        ld a,PAGE_FILEBUF
        SETPAGE3 a
        ld hl,(Ps_Src)
        ld de,(Ps_Ptr)
        ld a,(Ps_FN)
        ld c,a
        ld b,0
        ldir
        ld (Ps_Ptr),de
        RESTPAGE3
        ret
Ps_Src          dw 0

;-------- Страница почти полна (кадр может быть до 29 байт) - на диск, указатель - в начало. CF - ошибка
Ps_Full
        ld hl,(Ps_Ptr)
        ld de,#10000-32
        or a
        sbc hl,de
        ccf
        ret nc                      ; ещё есть место (CF = 0)
        ld hl,(Ps_Ptr)
        ld de,#C000
        or a
        sbc hl,de
        call Sv_Append
        ret c
        ld hl,#C000
        ld (Ps_Ptr),hl
        or a
        ret

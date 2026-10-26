; =========================================================================
; ИМПОРТ - общее для тулзы диска и страницы конвертеров (обе в окне 1, коре видят обе): чтение буфера
; файла, итоги импорта, описание FTC (каталог диска и импорт), вызов страницы конвертеров
; =========================================================================
CONV_PT3        equ #4000           ; входы страницы конвертеров (srs/convview.asm)
CONV_PT2        equ #4003
CONV_FTC        equ #4006

Ld_Size         ds 4                ; размер файла
Pt_Base         dw 0                ; начало модуля в файле (Pt_Get)
Pt_Base2        dw 0                ; второй модуль (TurboSound)
Pt_Lost         db 0                ; что потеряли (биты PL_*, srs/pt3imp.asm)
Pt_Chips        db 1
Pt_TS37         db 0                ; PT 3.7 TS: N (паттерн чипа 2 = N-1-p), 0 - нет
Cv_Res          db 0

;-------- Вызов страницы конвертеров: HL - вход (CONV_*). -> A: 0 - готово, иначе - не тот файл; Z - готово.
; Страница - в окно 1 на время вызова (как Call_Tool). Портит всё
Call_Conv
        ld (.j+1),hl
        ld a,PAGE_CONV
        SETPAGE1 a
.j      call 0
        ld (Cv_Res),a
        RESTPAGE1
        ld a,(Cv_Res)
        or a
        ret

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


FC_NAME         equ #08             ; 42 имя (32) + автор
;-------- Описание FTC (42 знака) -> Fc_Txt и границы: имя - [0, Fc_Cut), автор -
; [Fc_By, Fc_Len). Есть " BY " - режем по нему; иначе длиннее 32 - по последнему
; пробелу в первых 32 знаках; иначе всё - имя
FC_TXT_LEN      equ 42
Fc_Txt          ds FC_TXT_LEN
Fc_Len          db 0
Fc_Cut          db 0
Fc_By           db 0

Fc_Split
        ld hl,FC_NAME
        ld de,Fc_Txt
        ld b,FC_TXT_LEN
.r      call Pt_Get
        ld (de),a
        inc de
        djnz .r
        ld b,FC_TXT_LEN             ; длина без хвостовых пробелов и нулей
.t      ld hl,Fc_Txt-1
        ld a,b
        call Hl_Add_A
        ld a,(hl)
        cp ' '+1
        jr nc,.len
        djnz .t
.len    ld a,b
        ld (Fc_Len),a
        ld (Fc_Cut),a               ; пока - всё имя
        ld (Fc_By),a
        ld c,0                      ; " BY " с позиции C
.f      ld a,c
        add a,4
        ld hl,Fc_Len
        cp (hl)
        jr z,$+4
        jr nc,.nby
        ld hl,Fc_Txt
        ld a,c
        call Hl_Add_A
        ld a,(hl)
        cp ' '
        jr nz,.fn
        inc hl
        ld a,(hl)
        or #20
        cp 'b'
        jr nz,.fn
        inc hl
        ld a,(hl)
        or #20
        cp 'y'
        jr nz,.fn
        inc hl
        ld a,(hl)
        cp ' '
        jr nz,.fn
        ld a,c                      ; нашли
        ld (Fc_Cut),a
        add a,4
        ld (Fc_By),a
        ret
.fn     inc c
        jr .f
.nby    ld a,(Fc_Len)               ; не длиннее 32 - всё имя
        cp 33
        ret c
        ld c,32                     ; последний пробел в первых 32
.s      ld hl,Fc_Txt
        ld a,c
        call Hl_Add_A
        ld a,(hl)
        cp ' '
        jr z,.sp
        dec c
        jr nz,.s
        ld a,32                     ; пробела нет - 32 и остальное
        ld (Fc_Cut),a
        ld (Fc_By),a
        ret
.sp     ld a,c
        ld (Fc_Cut),a
        inc a
        ld (Fc_By),a
        ret

Pat_Zero
        ld h,#80
.r      ld l,0
.z      ld (hl),0
        inc l
        ld a,l
        cp PAT_DATA_SIZE             ; данные роу (FT2_PAT_ROW тулзы диска)
        jr c,.z
        inc h
        ld a,h
        cp #80+PAT_ROWS_MAX
        jr c,.r
        ret

Hl_Add_A
        add a,l
        ld l,a
        ret nc
        inc h
        ret

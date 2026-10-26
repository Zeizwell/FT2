; =========================================================================
; ИМПОРТ - сторона тулзы диска: модуль уже в буфере файла, конвертер - в своей странице (PAGE_CONV,
; srs/convview.asm), зовём через коре (Call_Conv). Здесь - что про диск: сообщение о потерях, имя файла в
; трек, Compare и его журнал на диск.
; =========================================================================

; По типу (Ld_Kind 2 PT3, 3 PT2, 4 FTC): вход конвертера, «не тот файл», «что обрезали»
Dv_Import
        ld a,(Ld_Kind)
        sub 2
        ld l,a                      ; x6
        add a,a
        add a,l
        add a,a
        ld hl,Imp_Tab
        call Hl_Add_A
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call Call_Conv              ; -> A: 0 - готово
        pop hl
        jr z,.ok
        ld a,(hl)                   ; не тот файл - трек не тронут
        inc hl
        ld h,(hl)
        ld l,a
        jp Dv_Error
.ok     inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp Pt_Done

Imp_Tab dw CONV_PT3, Txt_BadPt3, Txt_Pt3Cut
        dw CONV_PT2, Txt_BadPt2, Txt_Pt2Cut
        dw CONV_FTC, Txt_BadFtc, Txt_FtcCut

        ld hl,Txt_Pt3Cut

;-------- Общий конец импорта (PT3, PT2...): ордер и каталог - в трек, имя файла, сообщение.
; HL - начало сообщения о потерях ("PT3 cut:")
Pt_Done
        ld (Pt_Cut_Txt),hl
        ld hl,Dv_Spec+1             ; имя файла - в трек (шапка)
        call Dv_Song_File
        ld a,1                      ; вид паттерна перечитает трек при входе
        ld (SV_SONG_NEW),a
        ld a,(Dv_Cmp)               ; Compare - сравнить плееры (PT3 / PT2 / FTC до 32К)
        or a
        call nz,Dv_Compare
        ld a,(Pt_Lost)              ; без потерь - экран диска закрываем
        or a
        jp z,Dv_Loaded
        ld hl,(Pt_Cut_Txt)          ; что обрезали - словами за сообщением
        ld de,Pt_Msg
        call Str_Copy
        ld hl,Pt_Lost_Words
        ld a,(Pt_Lost)
        ld b,5
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
Pt_Lost_Words   db " rows",0," pats",0," cmds",0," len",0," ins",0   ; по битам PL_*

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

;-------- Compare: наш плеер против эталона (srs/cmpview.asm, страница PAGE_CMP в окне 3).
; PT3, PT2 (эталон Бульбы) и FTC (плеер FT 1.15), модуль до 32К (две первые страницы буфера файла)
Dv_Compare
        ld a,(Ld_Kind)              ; 2 - PT3, 3 - PT2, 4 - FTC
        cp 2
        ret c
        cp 5
        ret nc
        ld a,(Ld_Size+2)            ; не больше 32К (окна 1 и 2 у компаратора)
        or a
        ret nz
        ld hl,(Ld_Size)
        ld de,cmpview.CM_MOD_MAX+1
        or a
        sbc hl,de
        ret nc
        ld a,PAGE_CMP
        SETPAGE3 a
        ld a,(Ld_Kind)
        sub 2
        ld (cmpview.Cmp_Kind),a
        ld hl,Dv_Spec+1             ; имя файла - для экрана сравнения
        ld de,cmpview.Cmp_Name
        ld bc,32
        ldir
        xor a
        ld (de),a
        ld a,(Pt_Chips)
        ld (cmpview.Cmp_Chips),a
        ld a,(Ld_Kind)              ; PT2, FTC - без TS
        cp 3
        ld a,0
        jr nc,.ts
        ld a,(Pt_Chips)             ; PT3: два модуля - режим 16 и адрес второго
        cp 2
        ld a,32                     ;   иначе - автопоиск PT 3.7 TS
        jr c,.ts
        ld a,(Pt_TS37)
        or a
        ld a,32
        jr nz,.ts
        ld hl,(Pt_Base2)
        ld de,cmpview.CM_MOD
        add hl,de
        ld (cmpview.Cmp_Mod2),hl
        ld a,16
.ts     ld (cmpview.Cmp_TS),a
        call cmpview.Cmp_Run
        RESTPAGE3
        call Cmp_Save               ; журнал сравнения -> FT2CMP.BIN (для разбора на PC)
        ld a,1                      ; экран диска - заново
        ld (Dv_Dirty),a
        jp Dv_Head

;-------- Журнал компаратора (буфер файла, страницы 2..3 = 32К) -> FT2CMP.BIN в текущую
; папку (старый - удаляется). Ошибка диска - молча (это только для разбора на PC)
Cs_Page         db 0
Cmp_Save
        ld ix,DK_DELETE+256
        ld hl,Spec_Cmp
        call Disk_Call
        ld ix,DK_CREATE+256
        ld hl,Spec_CmpNew
        call Disk_Call
        ret c
        ret nz
        ld a,cmpview.CM_LOG_PAGE
        ld (Cs_Page),a
.p      ld a,(Cs_Page)
        SETPAGE3 a
        ld ix,DK_APPEND
        ld hl,#C000
        ld bc,#4000
        call Disk_Call
        RESTPAGE3
        ld hl,Cs_Page
        inc (hl)
        ld a,(hl)
        cp cmpview.CM_LOG_PAGE+2
        jr c,.p
        ld ix,DK_CLOSE
        jp Disk_Call
Spec_Cmp        db FD_FILE,"FT2CMP.BIN",0
Spec_CmpNew     db #20,0,0,0,0,"FT2CMP.BIN",0
Txt_Pt2Cut      db "PT2 cut:",0
Txt_BadPt2      db "Bad PT2",0
Txt_FtcCut      db "FTC cut:",0
Txt_BadFtc      db "Bad FTC",0

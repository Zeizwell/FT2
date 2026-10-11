; =========================================================================
; КОМПАРАТОР ПЛЕЕРА: наш плеер против эталона (плеер PT2/PT3/TS С.В. Бульбы,
; srs/ptsplay.asm), для FTC - плеер Fast Tracker 1.15 (srs/ftplay.asm). Страница PAGE_CMP,
; работает в ОКНЕ 3 (#C000): окно 1 - наш плеер, на время кадра эталона окна 1 и 2 -
; модуль (буфер файла, до 32К); окно 2 ещё - экран на время вывода.
; Зовёт тулза диска после импорта PT3 / PT2 / FTC с галочкой Compare (модуль до 32К).
; =========================================================================
; Как сравниваем:
;   - эталон играет оригинал модуля, наш - то, что из него импортировали;
;   - у эталона после INIT таблицы нот и громкостей - НАШИ (иначе тон и громкость
;     расходились бы всегда): ищем логику, а не строй;
;   - старт: первый кадр с ненулевой громкостью у обоих - сдвиг выравниваем;
;   - каждый кадр без прерываний: регистры, которые реально звучат (тон канала - если
;     он включён и у канала есть громкость; шум - если включён где-то со звуком;
;     период огибающей - если она где-то включена; R13 - запись и значение);
;   - конец - оба трека дошли до конца (эталон - флаг цикла в его SETUP, наш -
;     Pl_Looped), или 65535 кадров.
; Экран: кадр, позиция, паттерн, роу, сколько кадров разошлось. В конце - первое
; расхождение (кадр, позиция, роу, чип, регистр, эталон / наш), ждём клавишу.
; =========================================================================
    MODULE cmpview

CM_SCR_H        equ #80             ; экран - в окне 2 (на время вывода)
CM_MOD          equ #4000           ; модуль - в окнах 1 и 2 на время эталона (до 32К)
CM_MOD_MAX      equ #8000
CM_FRAMES_MAX   equ #FFFF
CM_ALIGN_MAX    equ 16              ; ищем первый звук в стольких кадрах
CM_Y_TITLE      equ 2               ; строки экрана: под кнопками транспорта (строки 0..1)
CM_Y_FILE       equ 3
CM_Y_STAT       equ 5
CM_Y_BAR        equ 6               ; полоса: позиция из всех в ордере
CM_BAR_W        equ 50              ; клетка - 2%
CM_Y_RES        equ 7
CM_NOFX         equ 1               ; 1 - у эталона команды паттерна выкл (кроме темпа):
                                    ;   наш плеер их пока не умеет. Научим - 0

        jp Cmp_Run                  ; #C000 - вход (окно 3)

; --- вход: что сравниваем (ставит тулза диска)
CK_FTC          equ 2
Cmp_Kind        db 0                ; 0 - PT3, 1 - PT2 (эталон Бульбы), CK_FTC - FTC (плеер FT)
Cmp_TS          db 0                ; режим TS эталона: 0, 16 - два модуля, 32 - PT 3.7 / автопоиск
Cmp_Mod2        dw 0                ; второй модуль (два модуля TS), адрес от CM_MOD
Cmp_Chips       db 1                ; сколько чипов сравнивать
Cmp_Name        ds 33               ; имя файла модуля (для экрана)

; --- результат
Cm_Frame        dw 0                ; кадр сравнения
Cm_Diffs        dw 0                ; кадров с расхождением
Cm_First        db 0                ; 1 - первое расхождение записано
Cm_F_Frame      dw 0                ; первое: кадр, позиция, роу, чип, регистр, эталон, наш
Cm_F_Pos        db 0
Cm_F_Row        db 0
Cm_F_Chip       db 0
Cm_F_Reg        db 0
Cm_F_Ref        db 0
Cm_F_Our        db 0
Cm_Bad          db 0                ; в этом кадре было расхождение

;-------- Сравнение целиком. Прерывания выключены на всё время, в конце - включены
Cmp_Run
        di
        ld a,#FF                    ; полоса прогресса - нарисовать заново
        ld (Cm_BarPos),a
        xor a                       ; новый модуль: FT ещё не переставлял его адреса
        ld (ftp.Relocated),a
        ld a,PAGE_PLAYER            ; наш плеер - в окне 1 на всё время
        SETPAGE1 a
        call Cm_Clear_Screen
        ld hl,Txt_Title
        ld a,(Cmp_Kind)             ; FTC - эталон FT
        cp CK_FTC
        jr nz,$+5
        ld hl,Txt_TitleFt
        ld de,1+256*(CM_SCR_H+CM_Y_TITLE)
        call Cm_Text
        ld hl,Txt_File              ; имя модуля
        ld de,1+256*(CM_SCR_H+CM_Y_FILE)
        call Cm_Text
        ld hl,Cmp_Name
        ld de,7+256*(CM_SCR_H+CM_Y_FILE)
        call Cm_Text
        call Cm_Align               ; сдвиг старта
        call Cm_Init                ; заново, со сдвигом
        call Cm_Skew
        ld hl,0
        ld (Cm_EndRef),hl
        ld (Cm_EndOur),hl
        ld hl,0
        ld (Cm_Frame),hl
        ld (Cm_Diffs),hl
        xor a
        ld (Cm_First),a
.frame  call Cm_Tick_Our
        call Cm_Tick_Ref
        ld hl,(Cm_EndRef)           ; трек уже кончился у кого-то - кадры не сравниваем
        ld a,h                      ;   (наш ушёл на цикл, эталон молчит), ждём конец
        or l                        ;   у второго: видна только разница в длине
        ld hl,(Cm_EndOur)
        or h
        or l
        call z,Cm_Compare
        call Cm_Log
        call Cm_Show
        ld hl,(Cm_Frame)
        inc hl
        ld (Cm_Frame),hl
        ld a,h
        and l
        inc a
        jr z,.end                   ; 65535 кадров
        call Cm_Ends                ; трек кончился у обоих - конец (у одного - идём
        jr nz,.frame                ;   дальше: видна разница в длине)
.end    ld a,PC_STOP                ; наш плеер - стоп (возьмёт со следующим тиком IM1)
        ld (SV_PLAY_CMD),a
        call Cm_Result
        call Cm_Log_Head
        RESTPAGE1
        ei
.key    halt                        ; ждём клавишу (IM1 снова читает клавиатуру)
        call Key_Get
        jr z,.key
        ret

;-------- Оба плеера - с начала: наш - команда "сонг с позиции 0", эталон - INIT
; (модуль в окне 2) и наши таблицы нот и громкостей поверх его
Cm_Init
        ld a,(SV_SONG_PAGE)         ; наш плеер - текущий трек (как Pl_Reset)
        ld (SV_PLAY_SONG),a
        xor a
        ld (SV_PLAY_CPOS),a
        ld (SV_PLAY_CROW),a
        ld a,PC_SONG
        ld (SV_PLAY_CMD),a
        call Pl_Song_Info           ; таблица нот трека (Pl_NoteTab) - уже сейчас
        ld hl,(Pl_NoteTab)          ; наши таблицы - к себе: окно 1 (плеер) займёт модуль
        ld de,Cm_NoteT
        ld bc,96*2
        ldir
        ld hl,Vol_T+16
        ld de,Cm_VolT
        ld bc,256-16
        ldir
        xor a                       ; эталон ещё не дошёл до конца
        ld (Cm_RLoop),a
        ld a,PAGE_FILEBUF           ; модуль - в окна 1 и 2
        SETPAGE1 a
        ld a,PAGE_FILEBUF+1
        SETPAGE2 a
        ld a,(Cmp_Kind)
        cp CK_FTC
        jr z,.ft
        add a,a                     ; SETUP: без цикла (бит 0), PT2 (бит 1), TS (биты 4-5)
        or 1
        ld b,a
        ld a,(Cmp_TS)
        or b
        ld (pts.SETUP),a
        ld a,CM_NOFX                ; команды паттерна у эталона
        ld (pts.NoFx),a
        ld hl,CM_MOD
        ld de,(Cmp_Mod2)
        call pts.START+3
        ld hl,Cm_NoteT              ; наши таблицы - поверх его
        ld de,pts.NT_
        ld bc,96*2
        ldir
        ld hl,Cm_VolT
        ld de,pts.VT_+16
        jr .vol
.ft     xor a                       ; FTC: плеер FT 1.15
        ld (ftp.Looped),a
        ld a,CM_NOFX
        ld (ftp.NoFx),a
        call ftp.InitModule
        ld hl,Cm_NoteT              ; наши таблицы - поверх его
        ld de,ftp.ToneTable_Place
        ld bc,96*2
        ldir
        ld hl,Cm_VolT
        ld de,ftp.VolumeTable+16
.vol    ld bc,256-16
        ldir
        RESTPAGE2
        RESTPAGE1
        ret
Cm_NoteT        ds 96*2             ; таблица нот трека (копия: при эталоне плеера в окне 1 нет)
Cm_VolT         ds 256-16           ; таблица громкости без строки 0

;-------- Тик нашего плеера (без прерываний) / кадр эталона (модуль - в окнах 1 и 2).
; Регистры эталона после кадра - в Cm_RRegs (R13 #FF - не писали), конец трека - Cm_RLoop
Cm_RRegs        ds PR_SIZE*2        ; регистры эталона: чип 1, чип 2
Cm_RLoop        db 0                ; не 0 - эталон прошёл точку цикла
Cm_Tick_Our
        jp PLAYER_TICK
Cm_Tick_Ref
        ld a,PAGE_FILEBUF           ; модуль - в окна 1 и 2 (наш плеер вернётся в окно 1)
        SETPAGE1 a
        ld a,PAGE_FILEBUF+1
        SETPAGE2 a
        ld a,(Cmp_Kind)
        cp CK_FTC
        jr z,.ft
        call pts.START+5            ; PT3 / PT2
        ld hl,pts.VARS1+pts.VRS.AYREGS
        ld de,Cm_RRegs
        ld bc,PR_SIZE
        ldir
        ld hl,pts.VARS2+pts.VRS.AYREGS
        ld bc,PR_SIZE
        ldir
        ld a,(pts.SETUP)            ; конец трека - бит 7
        and #80
        jr .end
.ft     ld a,#FF                    ; FTC: R13 - что запишет в этот кадр
        ld (ftp.R13W),a
        call ftp.PlayModule
        ld hl,ftp.AyR0_ChannelAfinePitch
        ld de,Cm_RRegs
        ld bc,PR_SIZE
        ldir
        ld a,(ftp.R13W)
        ld (Cm_RRegs+13),a
        ld a,(ftp.Looped)
.end    ld (Cm_RLoop),a
        RESTPAGE2
        RESTPAGE1
        ret

;-------- Конец трека: эталон прошёл точку цикла (Cm_RLoop), наш - метка
; Pl_Looped. Кадр, где это случилось, - Cm_EndRef / Cm_EndOur (0 - ещё нет, считаем с 1).
; Выход: Z - кончились оба
Cm_EndRef       dw 0
Cm_EndOur       dw 0
Cm_Ends
        ld hl,(Cm_Frame)
        ld a,(Cm_RLoop)
        or a
        jr z,.our
        ld de,(Cm_EndRef)
        ld a,d
        or e
        jr nz,.our
        ld (Cm_EndRef),hl
.our    ld a,(Pl_Looped)
        or a
        jr z,.chk
        ld de,(Cm_EndOur)
        ld a,d
        or e
        jr nz,.chk
        ld (Cm_EndOur),hl
.chk    ld hl,(Cm_EndRef)           ; Z - оба не 0
        ld a,h
        or l
        jr z,.no
        ld hl,(Cm_EndOur)
        ld a,h
        or l
        jr z,.no
        xor a
        ret
.no     or 1
        ret

;-------- Сдвиг старта: первый кадр с громкостью у каждого (до CM_ALIGN_MAX), разницу -
; лишними тиками тому, кто раньше
Cm_Align
        call Cm_Init
        ld b,0
.o      push bc                     ; наш
        call Cm_Tick_Our
        pop bc
        ld hl,Pl_Regs+8
        call Cm_Sound
        jr nz,.of
        inc b
        ld a,b
        cp CM_ALIGN_MAX
        jr c,.o
.of     ld a,b
        ld (Cm_Our0),a
        call Cm_Init
        ld b,0
.r      push bc                     ; эталон
        call Cm_Tick_Ref
        pop bc
        ld hl,Cm_RRegs+8
        call Cm_Sound
        jr nz,.rf
        inc b
        ld a,b
        cp CM_ALIGN_MAX
        jr c,.r
.rf     ld a,b
        ld (Cm_Ref0),a
        ret
Cm_Our0         db 0                ; первый звучащий кадр: наш
Cm_Ref0         db 0                ;   эталон

; HL - три громкости (R8..R10): NZ - хоть одна не 0
Cm_Sound
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        and #1F
        ret

;-------- После Cm_Init: тот, кто зазвучал раньше, пропускает лишние кадры
Cm_Skew
        ld a,(Cm_Ref0)
        ld b,a
        ld a,(Cm_Our0)
        sub b
        ret z
        jr c,.ref
        ld b,a                      ; наш позже: эталон вперёд
.r      push bc
        call Cm_Tick_Ref
        pop bc
        djnz .r
        ret
.ref    neg                         ; эталон позже: наш вперёд
        ld b,a
.o      push bc
        call Cm_Tick_Our
        pop bc
        djnz .o
        ret

; =========================================================================
; СРАВНЕНИЕ КАДРА
; =========================================================================
Cm_Chip         db 0
Cm_Ref          dw 0                ; регистры эталона (чип)
Cm_Our          dw 0                ;   наши
Cm_Mix          db 0                ; микшер эталона
Cm_Any          db 0                ; хоть один канал со звуком
Cm_AnyN         db 0                ;   с шумом
Cm_AnyE         db 0                ;   с огибающей
Cm_MixM         db 0                ; маска микшера: биты каналов со звуком

; A - номер бита -> A - маска
Cm_Bit  ld b,a
        ld a,1
        inc b
.s      dec b
        ret z
        add a,a
        jr .s

Cm_Compare
        xor a
        ld (Cm_Bad),a
        ld (Cm_Chip),a
        ld hl,Cm_RRegs
        ld de,Pl_Regs
        call Cm_Chip_Cmp
        ld a,(Cmp_Chips)
        cp 2
        jr c,.cnt
        ld a,1
        ld (Cm_Chip),a
        ld hl,Cm_RRegs+PR_SIZE
        ld de,Pl_Regs+PR_SIZE
        call Cm_Chip_Cmp
.cnt    ld a,(Cm_Bad)               ; кадров с расхождением
        or a
        ret z
        ld hl,(Cm_Diffs)
        inc hl
        ld (Cm_Diffs),hl
        ret

;-------- Чип: HL - регистры эталона, DE - наши
Cm_Chip_Cmp
        ld (Cm_Ref),hl
        ld (Cm_Our),de
        xor a
        ld (Cm_Any),a
        ld (Cm_AnyN),a
        ld (Cm_AnyE),a
        ld (Cm_MixM),a
        ld a,7
        call Cm_RefR
        ld (Cm_Mix),a
        ld c,0                      ; C - канал
.ch     ld a,8                      ; громкости: огибающая - только бит 4
        add a,c
        push bc
        call Cm_Amp
        pop bc
        jr z,.next                  ; у эталона тихо - тон и микшер не важны
        ld a,1
        ld (Cm_Any),a
        push bc                     ; маска микшера: биты этого канала (C и C+3)
        ld a,c
        call Cm_Bit
        ld b,a
        add a,a
        add a,a
        add a,a
        or b
        ld hl,Cm_MixM
        or (hl)
        ld (hl),a
        pop bc
        ld a,(Cm_Mix)               ; тон включён (бит канала = 0) - тон сравниваем
        ld b,c
        inc b
.sh     rrca
        djnz .sh
        jr c,.ntone
        push bc
        ld a,c
        add a,a
        call Cm_Reg                 ; младший тона
        pop bc
        push bc
        ld a,c
        add a,a
        inc a
        ld b,#0F
        call Cm_RegM                ; старший тона - 4 бита
        pop bc
.ntone  ld a,(Cm_Mix)               ; шум включён у канала со звуком
        ld b,c
        inc b
        inc b
        inc b
        inc b
.shn    rrca
        djnz .shn
        jr c,.next
        ld a,1
        ld (Cm_AnyN),a
.next   inc c
        ld a,c
        cp 3
        jr c,.ch
        ld a,(Cm_MixM)              ; микшер - только биты каналов со звуком
        or a
        jr z,.nmix
        ld b,a
        ld a,7
        call Cm_RegM
.nmix   ld a,(Cm_AnyN)              ; шум
        or a
        jr z,.nnz
        ld a,6
        ld b,#1F
        call Cm_RegM
.nnz    ld a,(Cm_AnyE)              ; период огибающей
        or a
        jr z,.nenv
        ld a,11
        call Cm_Reg
        ld a,12
        call Cm_Reg
.nenv   ld a,13                     ; R13: у эталона #FF - не писать; у нас - флаг Pl_R13W
        call Cm_RefR
        ld b,a
        ld a,(Cm_Chip)
        ld hl,Pl_R13W
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        or a
        ld a,#FF
        jr z,.r13
        ld hl,(Cm_Our)
        ld de,13
        add hl,de
        ld a,(hl)
.r13    cp b
        ret z
        ld c,a                      ; наш
        ld a,13
        jp Cm_Diff

; Громкость канала A (8..10): нормализуем (огибающая - #10, иначе 0..15), сравниваем.
; Выход: Z - у эталона тихо (без огибающей и громкость 0)
Cm_A            db 0
Cm_Amp  ld (Cm_A),a
        call Cm_RefR
        call Cm_Norm
        ld b,a                      ; B - эталон
        ld a,(Cm_A)
        call Cm_OurR
        call Cm_Norm
        ld c,a                      ; C - наш
        cp b
        jr z,.same
        ld a,(Cm_A)
        call Cm_Diff
.same   ld a,b                      ; огибающая у эталона
        cp #10
        jr nz,.ne
        ld a,1
        ld (Cm_AnyE),a
.ne     ld a,b
        or a
        ret
Cm_Norm bit 4,a
        jr z,.v
        ld a,#10
        ret
.v      and #0F
        ret

; Регистр A: сравнить целиком / по маске B
Cm_Reg  ld b,#FF
Cm_RegM push af
        call Cm_RefR
        and b
        ld e,a
        pop af
        push af
        call Cm_OurR
        and b
        ld c,a
        pop af
        ld b,e
        ld d,a
        ld a,c
        cp b
        ret z
        ld a,d
        jp Cm_Diff

; A - регистр -> A - значение эталона / наше. HL портит
Cm_RefR ld hl,(Cm_Ref)
        jr Cm_R
Cm_OurR ld hl,(Cm_Our)
Cm_R    add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret

;-------- Расхождение: A - регистр, B - эталон, C - наш. Первое - запомнить
Cm_Diff ld e,a
        ld a,1
        ld (Cm_Bad),a
        ld a,(Cm_First)
        or a
        ret nz
        inc a
        ld (Cm_First),a
        ld a,e
        ld (Cm_F_Reg),a
        ld a,b
        ld (Cm_F_Ref),a
        ld a,c
        ld (Cm_F_Our),a
        ld a,(Cm_Chip)
        ld (Cm_F_Chip),a
        ld hl,(Cm_Frame)
        ld (Cm_F_Frame),hl
        ld a,(SV_PLAY_POS)
        ld (Cm_F_Pos),a
        ld a,(SV_PLAY_ROW)
        ld (Cm_F_Row),a
        push hl                     ; снимок; регистры - как были (B, C ещё нужны)
        push de
        push bc
        call Cm_Snap
        pop bc
        pop de
        pop hl
        ret

; =========================================================================
; ЖУРНАЛ для разбора на PC: буфер файла, страницы 1..3 (48К; в странице 0 - модуль).
; +0 заголовок 64 байта, дальше запись на кадр по 64 байта (первые CM_LOG_N кадров):
;   +0 кадр (2), +2 позиция, +3 роу, +4 чипов, +5 1 - кадр разошёлся, +6 резерв (2),
;   +8 эталон чип 1 R0..R13, +22 эталон чип 2, +36 наш чип 1, +50 наш чип 2
;   (R13: #FF - в этом кадре не пишется, иначе значение). Тулза диска сохраняет его
;   файлом FT2CMP.BIN в текущую папку
; =========================================================================
CM_LOG_PAGE     equ PAGE_FILEBUF+2         ; страницы 0, 1 - модуль
CM_LOG_REC      equ 64
CM_LOG_N        equ 2*16384/CM_LOG_REC-1    ; 511 кадров

;-------- Запись кадра Cm_Frame (пока влезает)
Cm_Log  ld hl,(Cm_Frame)
        ld de,CM_LOG_N
        or a
        sbc hl,de
        ret nc
        ld hl,(Cm_Frame)            ; адрес: (кадр+1)*64 от начала журнала
        inc hl
        call Cm_Log_Addr            ; E - страница, HL - запись (окно 2)
        ld (Cm_LP),hl
        SETPAGE2 e
        ld hl,(Cm_LP)
        ld de,(Cm_Frame)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(SV_PLAY_POS)
        ld (hl),a
        inc hl
        ld a,(SV_PLAY_ROW)
        ld (hl),a
        inc hl
        ld a,(Cmp_Chips)
        ld (hl),a
        inc hl
        ld a,(Cm_Bad)
        ld (hl),a
        inc hl
        inc hl
        inc hl
        ex de,hl                    ; регистры эталона: оба чипа
        ld hl,Cm_RRegs
        ld bc,PR_SIZE
        ldir
        ld hl,Cm_RRegs+PR_SIZE
        ld bc,PR_SIZE
        ldir
        ld hl,Pl_Regs               ; наши; R13 - как у эталона (#FF - не пишется)
        ld bc,PR_SIZE
        ldir
        ld a,(Pl_R13W)
        call .r13
        ld hl,Pl_Regs+PR_SIZE
        ld bc,PR_SIZE
        ldir
        ld a,(Pl_R13W+1)
        call .r13
        RESTPAGE2
        ret
.r13    or a                        ; DE - за R13 записанного чипа
        ret nz
        dec de
        ld a,#FF
        ld (de),a
        inc de
        ret

; HL - номер записи (0 - заголовок) -> E - страница журнала, HL - адрес в окне 2.
; SETPAGE - у вызывающего (он кладёт страницу на стек)
Cm_LP           dw 0
Cm_Log_Addr
        add hl,hl                   ; *64
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h                      ; страница = адрес / 16К
        rlca
        rlca
        and 3
        add a,CM_LOG_PAGE
        ld e,a
        ld a,h
        and #3F
        or #80
        ld h,a
        ret

;-------- Заголовок журнала (+0): "FT2CMP1",0; +8 кадров (2), +10 разошлось (2), +12 есть
; первое; +13 его кадр (2), +15 позиция, +16 роу, +17 чип, +18 регистр, +19 эталон, +20 наш;
; +21 первый звук наш, +22 эталон; +23 конец эталона (2), +25 конец наш (2); +27 чипов,
; +28 PT3 0 / PT2 1, +29 режим TS
Cm_Log_Head
        ld hl,0
        call Cm_Log_Addr
        ld (Cm_LP),hl
        SETPAGE2 e
        ld de,(Cm_LP)
        ld hl,Txt_Sig
        ld bc,8
        ldir
        ld hl,Cm_Frame
        ld bc,2+2+1
        ldir                        ; кадров, разошлось, есть первое
        ld hl,Cm_F_Frame
        ld bc,2+6
        ldir                        ; первое: кадр, позиция, роу, чип, регистр, эталон, наш
        ld a,(Cm_Our0)
        ld (de),a
        inc de
        ld a,(Cm_Ref0)
        ld (de),a
        inc de
        ld hl,Cm_EndRef
        ld bc,4
        ldir
        ld a,(Cmp_Chips)
        ld (de),a
        inc de
        ld a,(Cmp_Kind)
        ld (de),a
        inc de
        ld a,(Cmp_TS)
        ld (de),a
        RESTPAGE2
        ret
Txt_Sig         db "FT2CMP1",0
    ASSERT Cm_Diffs == Cm_Frame+2 && Cm_First == Cm_Diffs+2
    ASSERT Cm_F_Pos == Cm_F_Frame+2 && Cm_F_Our == Cm_F_Frame+7
    ASSERT Cm_EndOur == Cm_EndRef+2


; =========================================================================
; СНИМОК ПЕРВОГО РАСХОЖДЕНИЯ: регистры обоих плееров и каналы чипа, где разошлось
; =========================================================================
Cm_SRef         ds PR_SIZE*2        ; регистры эталона (чип 1, чип 2)
Cm_SOur         ds PR_SIZE*2        ;   наши
Cm_SOurCh       ds 3*CS_SIZE        ; наши каналы чипа Cm_F_Chip (CS_*)
    ASSERT CS_SIZE == 32
Cm_SRefCh       ds 3*5              ; каналы эталона: нота, строка сэмпла, строка орнамента,
                                    ;   громкость, слайд (младший)

Cm_Snap
        ld hl,Cm_RRegs
        ld de,Cm_SRef
        ld bc,PR_SIZE
        ldir
        ld hl,Cm_RRegs+PR_SIZE
        ld bc,PR_SIZE
        ldir
        ld hl,Pl_Regs               ; наши: оба чипа подряд
        ld de,Cm_SOur
        ld bc,PR_SIZE*2
        ldir
        ld a,(Cm_Chip)              ; каналы чипа, где разошлось
        or a
        ld hl,Pl_Ch
        ld de,pts.VARS1+pts.VRS.ChanA
        jr z,.c
        ld hl,Pl_Ch+3*CS_SIZE
        ld de,pts.VARS2+pts.VRS.ChanA
.c      ld (Cs_Ref),de
        ld de,Cm_SOurCh
        ld bc,3*CS_SIZE
        ldir
        ld de,Cm_SRefCh             ; каналы эталона - по его типу
        ld a,(Cmp_Kind)
        cp CK_FTC
        jr z,.ft
        ld ix,(Cs_Ref)              ; PT3 / PT2: поля CHP
        ld b,3
.pc     ld a,(ix+pts.CHP.Note)
        ld (de),a
        inc de
        ld a,(ix+pts.CHP.PsInSm)
        ld (de),a
        inc de
        ld a,(ix+pts.CHP.PsInOr)
        ld (de),a
        inc de
        ld a,(ix+pts.CHP.Volume)    ; громкость - в старшем полубайте
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (de),a
        inc de
        ld a,(ix+pts.CHP.CrAmSl)
        ld (de),a
        inc de
        push bc
        ld bc,pts.CHP
        add ix,bc
        pop bc
        djnz .pc
        ret
.ft     ld hl,Ft_Snap               ; FTC: поля - в коде плеера FT (адреса - таблицей)
        ld b,3
.fc     push bc
        call .fb                    ; нота
        call .fb                    ; строка сэмпла
        call .fb                    ; строка орнамента
        ld c,(hl)                   ; громкость: (адрес строки его таблицы - VolumeTable) / 16
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld a,(bc)
        ld l,a
        inc bc
        ld a,(bc)
        ld h,a
        ld bc,ftp.VolumeTable
        or a
        sbc hl,bc
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (de),a
        inc de
        pop hl
        call .fb                    ; слайд
        pop bc
        djnz .fc
        ret
; байт по адресу из таблицы HL (HL += 2) -> в DE (DE += 1)
.fb     ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(bc)
        ld (de),a
        inc de
        ret
Cs_Ref          dw 0
Ft_Snap         dw ftp.HgthA+1, ftp.FSTPA11+1, ftp.ImShHlA+1, ftp.SetVolumeFromTableA+1, ftp.FSTPA39+1
                dw ftp.HgthB+1, ftp.FSTPB11+1, ftp.ImShHlB+1, ftp.SetVolumeFromTableB+1, ftp.FSTPB39+1
                dw ftp.HgthC+1, ftp.FSTPC11+1, ftp.ImShHlC+1, ftp.SetVolumeFromTableC+1, ftp.FSTPC39+1

;-------- Вывод снимка (экран - уже в окне 2, C - цвет):
;   Ref / Our: R0..R13 чипа; каналы: нота, строка сэмпла, строка орнамента, громкость, слайд
Cm_Snap_Show
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+CM_Y_RES+5)
        ld hl,Txt_SRef
        call PutStr
        ld hl,Cm_SRef
        call .regs
        ld de,1+256*(CM_SCR_H+CM_Y_RES+6)
        ld hl,Txt_SOur
        call PutStr
        ld hl,Cm_SOur
        call .regs
        ld de,1+256*(CM_SCR_H+CM_Y_RES+7)  ; подписи колонок каналов
        ld hl,Txt_SCap
        call PutStr
        ld b,0                      ; B - канал
.ch     push bc
        ld a,b                      ; строка экрана
        add a,CM_SCR_H+CM_Y_RES+8
        ld d,a
        ld e,1
        ld a,b
        add a,'A'
        call PutCh
        ld a,' '
        call PutCh
        ld a,b                      ; наш канал: IX = Cm_SOurCh + канал*CS_SIZE (32)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,Cm_SOurCh
        call Cm_HlA
        push hl
        pop ix
        ld a,(ix+CS_NOTE)
        call .h
        ld a,(ix+CS_IROW)
        call .h
        ld a,(ix+CS_OROW)
        call .h
        ld a,(ix+CS_VOL)
        call .h
        ld a,(ix+CS_SLIDE)
        call .h
        ld a,'|'
        call PutCh
        ld a,' '
        call PutCh
        pop bc
        push bc
        ld a,b                      ; канал эталона: Cm_SRefCh + канал*5
        add a,a
        add a,a
        add a,b
        ld hl,Cm_SRefCh
        call Cm_HlA
        ld a,b                      ; строка экрана - снова (DE портили)
        add a,CM_SCR_H+CM_Y_RES+8
        ld d,a
        ld e,1+2+5*3+2
        ld b,5
        call .r
        pop bc
        inc b
        ld a,b
        cp 3
        jp c,.ch
        ret
.h      call PutHex2                ; байт и пробел
        ld a,' '
        jp PutCh
; 14 регистров чипа Cm_F_Chip с HL
.regs   ld a,(Cm_F_Chip)
        or a
        jr z,.rg
        ld a,PR_SIZE
        call Cm_HlA
.rg     ld b,PR_SIZE
.r      ld a,(hl)
        inc hl
        call .h
        djnz .r
        ret

; HL += A
Cm_HlA  add a,l
        ld l,a
        ret nc
        inc h
        ret

Txt_SRef        db "Ref regs: ",0
Txt_SOur        db "Our regs: ",0
Txt_SCap        db "  our: note smp orn vol sld | ref: note smp orn vol sld",0
; =========================================================================
; ЭКРАН (текстовая страница - в окне 2 на время вывода)
; =========================================================================
;-------- Строка состояния: кадр, позиция, паттерн, роу, расхождений
Cm_Show
        ld a,(SV_PLAY_POS)          ; паттерн позиции - из ордера трека
        ld e,a
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld a,e
        ld hl,#8000+ORD_POS
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (Cm_Pat),a
        RESTPAGE2
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+CM_Y_STAT)
        ld hl,Txt_Frame
        call PutStr
        ld a,(Cm_Frame+1)
        call PutHex2
        ld a,(Cm_Frame)
        call PutHex2
        ld hl,Txt_Pos
        call PutStr
        ld a,(SV_PLAY_POS)
        call PutHex2
        ld hl,Txt_Pat
        call PutStr
        ld a,(Cm_Pat)
        call PutHex2
        ld hl,Txt_Row
        call PutStr
        ld a,(SV_PLAY_ROW)
        call PutHex2
        ld hl,Txt_Diffs
        call PutStr
        ld a,(Cm_Diffs+1)
        call PutHex2
        ld a,(Cm_Diffs)
        call PutHex2
        call Cm_Bar
        RESTPAGE2
        ret
Cm_Pat          db 0

;-------- Полоса прогресса, как в Windows: CM_BAR_W клеток и проценты. Процент = позиция * 100 /
; позиций в ордере (длина в кадрах заранее не известна - скорость меняется). Только когда
; позиция сменилась. Экран - в окне 2
Cm_BarPos       db #FF              ; позиция, для которой нарисована (#FF - ещё нет)
Cm_Bar
        ld a,(SV_PLAY_POS)
        ld hl,Cm_BarPos
        cp (hl)
        ret z
        ld (hl),a
        ld l,a                      ; HL = позиция * 100 (4 + 32 + 64)
        ld h,0
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,bc
        ld a,(Pl_OrdLast)           ; DE - позиций (последняя + 1, до 256)
        ld e,a
        ld d,0
        inc de
        xor a                       ; A - процент: HL / DE
.div    or a
        sbc hl,de
        jr c,Cm_Bar_Draw
        inc a
        jr .div

; A - процент 0..100: клетки (по 2%) и "NN%"
Cm_Bar_Draw
        ld (Cb_Pct),a
        srl a                       ; клеток пройдено
        ld b,a
        ld a,CM_BAR_W
        sub b
        ld (Cb_Rest),a
        ld de,1+256*(CM_SCR_H+CM_Y_BAR)
        ld a,(THEME_ATTR+CLR_VOLUME) ; пройдено - клетки
        ld c,a
        inc b
        jr .fn
.f      ld a,GLYPH_VOL
        call PutCh
.fn     djnz .f
        ld a,(THEME_ATTR+CLR_EMPTY) ; осталось - точки
        ld c,a
        ld a,(Cb_Rest)
        ld b,a
        inc b
        jr .rn
.r      ld a,'.'
        call PutCh
.rn     djnz .r
        ld a,(THEME_ATTR+CLR_TEXT)  ; проценты: 3 знака, без ведущих нулей
        ld c,a
        ld a,' '
        call PutCh
        ld a,(Cb_Pct)
        ld b,'0'-1                  ; сотни
.h      inc b
        sub 100
        jr nc,.h
        add a,100
        ld (Cb_Rest),a              ; остаток - в памяти (PutCh может портить)
        ld a,b
        cp '0'
        jr nz,$+4
        ld a,' '
        call PutCh
        ld a,(Cb_Rest)
        ld b,'0'-1                  ; десятки (у 100 - "0")
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld (Cb_Rest),a              ; остаток - в памяти (PutCh может портить)
        ld a,b
        cp '0'
        jr nz,.tp
        ld a,(Cb_Pct)               ; 0..9 - пробел, у 100 - ноль
        cp 100
        ld a,' '
        jr c,.tp
        ld a,'0'
.tp     call PutCh
        ld a,(Cb_Rest)
        call PutCh
        ld a,'%'
        jp PutCh
Cb_Rest         db 0
Cb_Pct          db 0

;-------- Итог: сдвиг старта, первое расхождение или "совпало"
Cm_Result
        call Cm_Show
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,100                    ; сравнение кончилось - полоса полная
        call Cm_Bar_Draw
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+CM_Y_RES)    ; сдвиг: первый звук - эталон / наш
        ld hl,Txt_Start
        call PutStr
        ld a,(Cm_Ref0)
        call PutHex2
        ld a,'/'
        call PutCh
        ld a,(Cm_Our0)
        call PutHex2
        ld de,1+256*(CM_SCR_H+CM_Y_RES+1)  ; конец трека: кадр у эталона / у нас (0 - не дошёл)
        ld hl,Txt_End
        call PutStr
        ld a,(Cm_EndRef+1)
        call PutHex2
        ld a,(Cm_EndRef)
        call PutHex2
        ld a,'/'
        call PutCh
        ld a,(Cm_EndOur+1)
        call PutHex2
        ld a,(Cm_EndOur)
        call PutHex2
        ld de,1+256*(CM_SCR_H+CM_Y_RES+2)
        ld a,(Cm_First)
        or a
        jr nz,.diff
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld hl,Txt_Same
        call PutStr
        jr .key
.diff   ld a,(THEME_ATTR+CLR_ERROR)
        ld c,a
        ld hl,Txt_First
        call PutStr
        ld a,(Cm_F_Frame+1)
        call PutHex2
        ld a,(Cm_F_Frame)
        call PutHex2
        ld hl,Txt_Pos
        call PutStr
        ld a,(Cm_F_Pos)
        call PutHex2
        ld hl,Txt_Row
        call PutStr
        ld a,(Cm_F_Row)
        call PutHex2
        ld de,1+256*(CM_SCR_H+CM_Y_RES+3)
        ld hl,Txt_Chip
        call PutStr
        ld a,(Cm_F_Chip)
        inc a
        call PutHex2
        ld hl,Txt_Reg
        call PutStr
        ld a,(Cm_F_Reg)
        call PutHex2
        ld hl,Txt_RefV
        call PutStr
        ld a,(Cm_F_Ref)
        call PutHex2
        ld hl,Txt_OurV
        call PutStr
        ld a,(Cm_F_Our)
        call PutHex2
        call Cm_Snap_Show           ; регистры и каналы в этот кадр
.key    ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+CM_Y_RES+13)
        ld hl,Txt_Key
        call PutStr
        RESTPAGE2
        ret

;-------- Чистый экран: строки 0..35 - пробелы цветом фона
Cm_Clear_Screen
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld d,CM_SCR_H
.r      ld e,0
.s      ld a,' '
        call PutCh
        bit 7,e
        jr z,.s
        inc d
        ld a,d
        cp CM_SCR_H+36
        jr c,.r
        RESTPAGE2
        ret

; HL - текст, DE - куда: экран в окно 2, цвет заголовка. HL, DE - через память:
; SETPAGE кладёт страницу на стек, push/pop через него нельзя
Ct_HL           dw 0
Ct_DE           dw 0
Cm_Text ld (Ct_HL),hl
        ld (Ct_DE),de
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,(Ct_DE)
        ld hl,(Ct_HL)
        call PutStr
        RESTPAGE2
        ret

Txt_Title       db "Player compare: FT2 player vs reference (S.V.Bulba PT2/PT3/TS)",0
Txt_TitleFt     db "Player compare: FT2 player vs reference (Fast Tracker 1.15)",0
Txt_File        db "File:",0
Txt_Frame       db "Frame ",0
Txt_Pos         db "  Pos ",0
Txt_Pat         db "  Pat ",0
Txt_Row         db "  Row ",0
Txt_Diffs       db "  Diff frames ",0
Txt_Start       db "First sound frame (ref/our): ",0
Txt_Same        db "All frames match",0
Txt_End         db "End of song frame (ref/our): ",0
Txt_First       db "First diff: frame ",0
Txt_Chip        db "Chip ",0
Txt_Reg         db "  R",0
Txt_RefV        db "  ref ",0
Txt_OurV        db "  our ",0
Txt_Key         db "Press any key",0

; =========================================================================
; ЭТАЛОН
; =========================================================================
    MODULE pts
    include "srs/ptsplay.asm"
    ENDMODULE
    MODULE ftp
    include "srs/ftplay.asm"
    ENDMODULE

    ENDMODULE

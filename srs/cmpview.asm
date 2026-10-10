; =========================================================================
; КОМПАРАТОР ПЛЕЕРА: наш плеер против эталона (плеер PT2/PT3/TS С.В. Бульбы,
; srs/ptsplay.asm). Страница PAGE_CMP, работает в ОКНЕ 3 (#C000): окно 1 занимает
; наш плеер, окно 2 - модуль (буфер файла) или экран на время вывода.
; Зовёт тулза диска после импорта PT3 / PT2 с галочкой Compare (модуль до 16К).
; =========================================================================
; Как сравниваем:
;   - эталон играет оригинал модуля, наш - то, что из него импортировали;
;   - у эталона после INIT таблицы нот и громкостей - НАШИ (иначе тон и громкость
;     расходились бы всегда): ищем логику, а не строй;
;   - старт: первый кадр с ненулевой громкостью у обоих - сдвиг выравниваем;
;   - каждый кадр без прерываний: регистры, которые реально звучат (тон канала - если
;     он включён и у канала есть громкость; шум - если включён где-то со звуком;
;     период огибающей - если она где-то включена; R13 - запись и значение);
;   - конец - эталон прошёл точку цикла (флаг в его SETUP), или 65535 кадров.
; Экран: кадр, позиция, паттерн, роу, сколько кадров разошлось. В конце - первое
; расхождение (кадр, позиция, роу, чип, регистр, эталон / наш), ждём клавишу.
; =========================================================================
    MODULE cmpview

CM_SCR_H        equ #80             ; экран - в окне 2 (на время вывода)
CM_MOD          equ #8000           ; модуль - в окне 2
CM_FRAMES_MAX   equ #FFFF
CM_ALIGN_MAX    equ 16              ; ищем первый звук в стольких кадрах
CM_NOFX         equ 1               ; 1 - у эталона команды паттерна выкл (кроме темпа):
                                    ;   наш плеер их пока не умеет. Научим - 0

        jp Cmp_Run                  ; #C000 - вход (окно 3)

; --- вход: что сравниваем (ставит тулза диска)
Cmp_Kind        db 0                ; 0 - PT3, 1 - PT2
Cmp_TS          db 0                ; режим TS эталона: 0, 16 - два модуля, 32 - PT 3.7 / автопоиск
Cmp_Mod2        dw 0                ; второй модуль (два модуля TS), адрес в окне 2
Cmp_Chips       db 1                ; сколько чипов сравнивать

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
        ld a,PAGE_PLAYER            ; наш плеер - в окне 1 на всё время
        SETPAGE1 a
        call Cm_Clear_Screen
        ld hl,Txt_Title
        ld de,1+256*(CM_SCR_H+1)
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
        call Cm_Compare
        call Cm_Log
        call Cm_Show
        ld hl,(Cm_Frame)
        inc hl
        ld (Cm_Frame),hl
        ld a,h
        and l
        inc a
        jr z,.end                   ; 65535 кадров
        call Cm_Ends                ; трек кончился (у кого-то) - конец
        jr z,.frame
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
        ld a,PAGE_FILEBUF
        SETPAGE2 a
        ld a,(Cmp_Kind)             ; SETUP: без цикла (бит 0), PT2 (бит 1), TS (биты 4-5)
        add a,a
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
        ld hl,(Pl_NoteTab)          ; наши таблицы - поверх его
        ld de,pts.NT_
        ld bc,96*2
        ldir
        ld hl,Vol_T+16
        ld de,pts.VT_+16
        ld bc,256-16
        ldir
        RESTPAGE2
        ret

;-------- Тик нашего плеера (без прерываний) / кадр эталона (модуль - в окне 2)
Cm_Tick_Our
        jp PLAYER_TICK
Cm_Tick_Ref
        ld a,PAGE_FILEBUF
        SETPAGE2 a
        call pts.START+5
        RESTPAGE2
        ret

;-------- Конец трека: эталон прошёл точку цикла (бит 7 его SETUP), наш - метка
; Pl_Looped. Кадр, где это случилось, - Cm_EndRef / Cm_EndOur (0 - ещё нет, считаем с 1).
; Выход: NZ - кончился хотя бы один
Cm_EndRef       dw 0
Cm_EndOur       dw 0
Cm_Ends
        ld hl,(Cm_Frame)
        ld a,(pts.SETUP)
        rla
        jr nc,.our
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
.chk    ld hl,(Cm_EndRef)
        ld a,h
        or l
        ld hl,(Cm_EndOur)
        or h
        or l
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
        ld hl,pts.VARS1+pts.VRS.AYREGS+8
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

Cm_Compare
        xor a
        ld (Cm_Bad),a
        ld (Cm_Chip),a
        ld hl,pts.VARS1+pts.VRS.AYREGS
        ld de,Pl_Regs
        call Cm_Chip_Cmp
        ld a,(Cmp_Chips)
        cp 2
        jr c,.cnt
        ld a,1
        ld (Cm_Chip),a
        ld hl,pts.VARS2+pts.VRS.AYREGS
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
        ld a,(Cm_Any)               ; микшер - если где-то звук (биты тона и шума)
        or a
        jr z,.nmix
        ld a,7
        ld b,#3F
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
        ret

; =========================================================================
; ЖУРНАЛ для разбора на PC: буфер файла, страницы 1..3 (48К; в странице 0 - модуль).
; +0 заголовок 64 байта, дальше запись на кадр по 64 байта (первые CM_LOG_N кадров):
;   +0 кадр (2), +2 позиция, +3 роу, +4 чипов, +5 1 - кадр разошёлся, +6 резерв (2),
;   +8 эталон чип 1 R0..R13, +22 эталон чип 2, +36 наш чип 1, +50 наш чип 2
;   (R13: #FF - в этом кадре не пишется, иначе значение). Тулза диска сохраняет его
;   файлом FT2CMP.BIN в текущую папку
; =========================================================================
CM_LOG_PAGE     equ PAGE_FILEBUF+1
CM_LOG_REC      equ 64
CM_LOG_N        equ 3*16384/CM_LOG_REC-1    ; 767 кадров

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
        ld hl,pts.VARS1+pts.VRS.AYREGS
        ld bc,PR_SIZE
        ldir
        ld hl,pts.VARS2+pts.VRS.AYREGS
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
        ld de,1+256*(CM_SCR_H+3)
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
        RESTPAGE2
        ret
Cm_Pat          db 0

;-------- Итог: сдвиг старта, первое расхождение или "совпало"
Cm_Result
        call Cm_Show
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+5)    ; сдвиг: первый звук - эталон / наш
        ld hl,Txt_Start
        call PutStr
        ld a,(Cm_Ref0)
        call PutHex2
        ld a,'/'
        call PutCh
        ld a,(Cm_Our0)
        call PutHex2
        ld de,1+256*(CM_SCR_H+6)    ; конец трека: кадр у эталона / у нас (0 - не дошёл)
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
        ld de,1+256*(CM_SCR_H+7)
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
        ld de,1+256*(CM_SCR_H+8)
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
.key    ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,1+256*(CM_SCR_H+10)
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

; HL - текст, DE - куда: экран в окно 2, цвет заголовка
Cm_Text push hl
        push de
        ld a,(SV_DRAW_PAGE)
        SETPAGE2 a
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        pop de
        pop hl
        call PutStr
        RESTPAGE2
        ret

Txt_Title       db "Player compare: FT2 player vs reference (S.V.Bulba PT2/PT3/TS)",0
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

    ENDMODULE

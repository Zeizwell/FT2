; =========================================================================
; ВВОД: клавиатура PC (PS/2) и кнопки мыши. Часть коре.
; =========================================================================
; IM1 каждый кадр (после мыши) - Read_Input:
;   - вычитывает лог сканкодов PS/2 из AVR и ведёт карту нажатых (SV_KEY_DOWN)
;     и очередь событий (SV_KEY_Q): нажатие и автоповтор последней клавиши;
;   - по кнопкам мыши считает события: нажатие, отпускание, повтор, двойной.
; Основной цикл читает: Key_Get (очередь), Key_Down (держат ли), Mouse_Btn.
; Обмен без DI: очередь и счётчики пишет только IM1, читатель только сравнивает.
;
; Сканкоды - PS/2 набор 2. Код клавиши для FT2 = сканкод, у E0-кодов +128
; (стрелки, правые Ctrl/Alt, Ins/Del/Home/End/PgUp/PgDn). F7 (#83) -> #7F.
; Лог: расширение Gluk-часов #02 (pentevo/docs/GluExt/version_ext.md).
; =========================================================================

PORT_EFF7       equ #EFF7           ; остальные биты у нас 0 (как после сброса)
EFF7_CMOS       equ #80
GLUK_ADDR       equ #DFF7           ; номер регистра Gluk
GLUK_DATA       equ #BFF7           ; данные
GLUK_EXTSW      equ #F0             ; регистр выбора расширения / данные лога
GLUK_EXT_KBLOG  equ #02             ; расширение: лог клавиатуры PS/2
GLUK_REG_C      equ #0C             ; бит 0 - сбросить лог (после переполнения он
                                    ; отдаёт #FF, пока не сбросишь)
KB_MAX_BYTES    equ 16              ; байт лога за кадр, не больше (защита от зависания)

; Коды клавиш (PS/2 набор 2, E0-коды +128)
KEY_LSHIFT      equ #12
KEY_RSHIFT      equ #59
KEY_LCTRL       equ #14
KEY_RCTRL       equ #14+#80
KEY_LALT        equ #11
KEY_RALT        equ #11+#80

;-------- Старт: включить лог клавиатуры, настройки по умолчанию
Input_Init
        ld bc,PORT_EFF7             ; бит 7 - доступ к портам часов Gluk (без него
        ld a,EFF7_CMOS              ; DFF7/BFF7 не работают, читается #FF)
        out (c),a
        ld bc,GLUK_ADDR             ; EXTSW = лог клавиатуры
        ld a,GLUK_EXTSW
        out (c),a
        ld b,high GLUK_DATA
        ld a,GLUK_EXT_KBLOG
        out (c),a
        ld a,20                     ; клавиши: повтор через 20 кадров, дальше раз в 3
        ld (SV_KB_DELAY),a
        ld a,3
        ld (SV_KB_RATE),a
        ld a,20                     ; кнопки мыши: так же, но раз в 4
        ld (SV_MS_DELAY),a
        ld a,4
        ld (SV_MS_RATE),a
        ld a,15                     ; двойной клик - не дольше 15 кадров
        ld (SV_MS_DBL),a
        xor a
        ld (SV_KEY_HEAD),a
        ld (SV_KEY_TAIL),a
        ld (SV_KEY_MODS),a
        ld (Kb_RepKey),a
        ld hl,SV_KEY_DOWN           ; ничего не нажато, счётчики мыши - 0
        ld b,32
.c      ld (hl),a
        inc hl
        djnz .c
        ld hl,SV_MS_COUNT
        ld b,12
.m      ld (hl),a
        inc hl
        djnz .m
        ret

;-------- IM1: клавиатура и кнопки мыши
Read_Input
        ld hl,(SV_FRAMES)           ; счётчик кадров
        inc hl
        ld (SV_FRAMES),hl
        call Read_Kbd
        jp Mouse_Buttons

; =========================================================================
; КЛАВИАТУРА
; =========================================================================
Kb_Ext          db 0                ; был префикс E0: #80
Kb_Rel          db 0                ; был префикс F0: 1 - отпускание
Kb_RepKey       db 0                ; клавиша автоповтора, 0 - нет
Kb_RepCnt       db 0                ; кадров до следующего повтора
Kb_Left         db 0                ; сколько байт лога ещё можно прочитать в кадре

Read_Kbd
        ld a,KB_MAX_BYTES
        ld (Kb_Left),a
.l      ld hl,Kb_Left               ; лимит за кадр - остальное в следующем
        dec (hl)
        jp z,.repeat
        ld bc,GLUK_ADDR             ; очередной байт лога
        ld a,GLUK_EXTSW
        out (c),a
        ld b,high GLUK_DATA
        in a,(c)
        or a
        jp z,.repeat                ; лог пуст
        cp #FF
        jr z,.overflow
        cp #E0                      ; префикс расширенной клавиши
        jr nz,.n1
        ld a,#80
        ld (Kb_Ext),a
        jr .l
.n1     cp #F0                      ; префикс отпускания
        jr nz,.n2
        ld a,1
        ld (Kb_Rel),a
        jr .l
.n2     cp #83                      ; F7 - единственный код > #7F
        jr nz,$+4
        ld a,#7F
        and #7F
        ld hl,Kb_Ext                ; + #80 у E0-клавиш
        or (hl)
        ld (hl),0
        ld e,a                      ; E - код клавиши
        call Key_Bit                ; HL - байт карты, A - маска
        ld d,a
        ld a,(Kb_Rel)
        or a
        jr z,.press
        xor a                       ; --- отпускание
        ld (Kb_Rel),a
        ld a,d
        cpl
        and (hl)
        ld (hl),a
        ld a,(Kb_RepKey)            ; отпустили повторяемую - повтор стоп
        cp e
        jr nz,.mods
        xor a
        ld (Kb_RepKey),a
        jr .mods
.press  ld a,(hl)                   ; --- нажатие
        and d
        jr nz,.l                    ; уже держат: это повтор самой клавиатуры - свой есть
        ld a,(hl)
        or d
        ld (hl),a
        call Kb_Mods
        call Is_Mod                 ; модификаторы событий не дают
        jr z,.l
        ld c,0                      ; событие "нажатие"
        call Key_Push
        ld a,e                      ; эта клавиша теперь повторяется
        ld (Kb_RepKey),a
        ld a,(SV_KB_DELAY)
        ld (Kb_RepCnt),a
        jr .l
.mods   call Kb_Mods
        jp .l

.overflow                           ; лог переполнился: сбросить, считаем, что всё отпущено
        ld bc,GLUK_ADDR
        ld a,GLUK_REG_C
        out (c),a
        ld b,high GLUK_DATA
        ld a,1
        out (c),a
        ld hl,SV_KEY_DOWN
        ld b,32
        xor a
.o      ld (hl),a
        inc hl
        djnz .o
        ld (Kb_RepKey),a
        ld (Kb_Ext),a
        ld (Kb_Rel),a
        jp Kb_Mods                  ; лог пуст - в этом кадре больше не читаем

.repeat ld a,(Kb_RepKey)            ; автоповтор последней нажатой
        or a
        ret z
        ld hl,Kb_RepCnt
        dec (hl)
        ret nz
        ld e,a
        ld a,(SV_KB_RATE)
        ld (hl),a
        ld c,KF_REPEAT
        jp Key_Push

; E - код -> HL - байт карты нажатых, A - маска бита. Портит B
Key_Bit
        ld a,e
        rrca
        rrca
        rrca
        and #1F
        add a,low SV_KEY_DOWN
        ld l,a
        ld h,high SV_KEY_DOWN
        ld a,e
        and 7
        ld b,a
        ld a,1
        jr z,.r
.s      add a,a
        djnz .s
.r      ret

; E - код. Z - это модификатор (Shift / Ctrl / Alt)
Is_Mod
        ld a,e
        cp KEY_LSHIFT
        ret z
        cp KEY_RSHIFT
        ret z
        cp KEY_LCTRL
        ret z
        cp KEY_RCTRL
        ret z
        cp KEY_LALT
        ret z
        cp KEY_RALT
        ret

; Модификаторы по карте нажатых -> SV_KEY_MODS (левый или правый - всё равно).
; Портит A, B, HL; сохраняет DE
Kb_Mods
        push de
        ld d,0
        ld e,KEY_LSHIFT
        call .t
        jr nz,.s1
        ld e,KEY_RSHIFT
        call .t
        jr z,.c1
.s1     set 0,d                     ; KM_SHIFT
.c1     ld e,KEY_LCTRL
        call .t
        jr nz,.s2
        ld e,KEY_RCTRL
        call .t
        jr z,.c2
.s2     set 1,d                     ; KM_CTRL
.c2     ld e,KEY_LALT
        call .t
        jr nz,.s3
        ld e,KEY_RALT
        call .t
        jr z,.c3
.s3     set 2,d                     ; KM_ALT
.c3     ld a,d
        ld (SV_KEY_MODS),a
        pop de
        ret
.t      call Key_Bit                ; NZ - клавиша E нажата
        and (hl)
        ret

; Событие в очередь: E - код, C - флаги (KF_REPEAT). Модификаторы - текущие.
; Очередь полна - событие теряется
Key_Push
        ld a,(SV_KEY_HEAD)
        ld b,a
        inc a
        and 15
        ld hl,SV_KEY_TAIL
        cp (hl)
        ret z                       ; полна
        ld l,b                      ; запись: SV_KEY_Q + голова*2
        sla l
        ld h,0
        push de
        ld de,SV_KEY_Q
        add hl,de
        pop de
        ld (hl),e
        inc hl
        ld b,a
        ld a,(SV_KEY_MODS)
        or c
        ld (hl),a
        ld a,b                      ; голову двигаем ПОСЛЕ записи
        ld (SV_KEY_HEAD),a
        ret

;-------- Основной цикл: следующее событие клавиатуры.
; Выход: Z - событий нет; иначе A - код, C - флаги (KM_* | KF_REPEAT). Портит HL
Key_Get
        ld a,(SV_KEY_TAIL)
        ld hl,SV_KEY_HEAD
        cp (hl)
        ret z
        ld l,a
        ld h,0
        add hl,hl
        push de
        ld de,SV_KEY_Q
        add hl,de
        pop de
        inc a
        and 15
        ld (SV_KEY_TAIL),a
        ld a,(hl)
        inc hl
        ld c,(hl)
        or a                        ; код не 0 - NZ
        ret

;-------- Держат ли клавишу. A - код. NZ - держат. Портит B, E, HL
Key_Down
        ld e,a
        call Key_Bit
        and (hl)
        ret

; =========================================================================
; КНОПКИ МЫШИ: из SV_MOUSE_BUT (0 - нажата) -> счётчики событий SV_MS_COUNT
; =========================================================================
Ms_Prev         db 0                ; кнопки в прошлом кадре (1 - нажата)
Ms_RepCnt       ds 3                ; +0: до повтора, по кнопке
Ms_Since        ds 3                ; +3: кадров с прошлого нажатия, до 255 (двойной)
Ms_Col          ds 3                ; +6: колонка прошлого нажатия
Ms_Row          ds 3                ; +9: строка прошлого нажатия

Mouse_Buttons
        ld a,(SV_MOUSE_BUT)
        cpl
        and 7
        ld hl,Ms_Prev
        ld b,(hl)                   ; B - были нажаты (1)
        ld (hl),a
        ld c,a                      ; C - нажаты сейчас (1)
        ld ix,SV_MS_COUNT           ; IX - счётчики кнопки
        ld iy,Ms_RepCnt             ; IY - состояние кнопки
        ld e,3                      ; E - кнопок
.b      ld a,(iy+3)                 ; кадры с прошлого нажатия, насыщение 255
        inc a
        jr z,$+5
        ld (iy+3),a
        srl c                       ; CF - нажата сейчас
        jr c,.down
        srl b                       ; CF - была нажата
        jr nc,.next
        inc (ix+ME_RELEASE)         ; отпустили
        jr .next
.down   srl b
        jr c,.held
        inc (ix+ME_PRESS)           ; нажали
        ld a,(SV_MS_DELAY)
        ld (iy+0),a
        call Ms_Double
        jr .next
.held   dec (iy+0)                  ; держат: автоповтор
        jr nz,.next
        ld a,(SV_MS_RATE)
        ld (iy+0),a
        inc (ix+ME_REPEAT)
.next   ld a,ixl                    ; следующая кнопка (счётчики - по 4 байта)
        add a,4
        ld ixl,a
        inc iy
        dec e
        jr nz,.b
        ret

; Нажатие кнопки IY/IX: двойное, если прошлое было недавно и в той же клетке.
; Портит A, HL
Ms_Double
        ld a,(iy+3)
        ld (iy+3),0
        ld hl,SV_MS_DBL
        cp (hl)
        jr nc,.save
        ld a,(SV_MOUSE_COL)
        cp (iy+6)
        jr nz,.save
        ld a,(SV_MOUSE_ROW)
        cp (iy+9)
        jr nz,.save
        inc (ix+ME_DOUBLE)
.save   ld a,(SV_MOUSE_COL)
        ld (iy+6),a
        ld a,(SV_MOUSE_ROW)
        ld (iy+9),a
        ret

;-------- Основной цикл: события кнопки мыши с прошлого вызова.
; In: A - кнопка (MB_*), HL - 4 байта "уже видели" у вызывающего (обновляются).
; Out: A - флаги: бит ME_PRESS..ME_DOUBLE - было такое событие, бит 7 - держат.
; Портит BC, DE, HL
Mouse_Btn
        push af                     ; номер кнопки
        add a,a
        add a,a
        add a,low SV_MS_COUNT
        ld e,a
        ld d,high SV_MS_COUNT
        ld c,0                      ; C - флаги
        ld b,1                      ; B - бит текущего события
.e      ld a,(de)                   ; счётчик сдвинулся - событие было
        cp (hl)
        jr z,.s
        ld (hl),a
        ld a,c
        or b
        ld c,a
.s      inc de
        inc hl
        sla b
        ld a,b
        cp 16
        jr c,.e
        pop af                      ; держат? бит кнопки в Ms_Prev -> CF
        ld b,a
        ld a,(Ms_Prev)
        inc b
.h      dec b
        jr z,.t
        rrca
        jr .h
.t      rrca
        ld a,c
        ret nc
        or #80
        ret

; =========================================================================
; ТЕКСТ И ТАБЛИЦЫ: общее для всех экранов (часть коре)
; =========================================================================
; Символ A цветом C в DE (D - строка, E - колонка), цвет на +128. E++
PutCh
        ld (de),a
        set 7,e
        ld a,c
        ld (de),a
        res 7,e
        inc e
        ret

; HL - строка, конец 0. C - цвет. На выходе HL - на 0
PutStr
.l      ld a,(hl)
        or a
        ret z
        call PutCh
        inc hl
        jr .l

PutHex2
        push af
        rrca
        rrca
        rrca
        rrca
        and #0F
        call HexDigit
        call PutCh
        pop af
        and #0F
        call HexDigit
        jp PutCh

HexDigit
        cp 10
        jr c,.d
        add a,7
.d      add a,'0'
        ret

; A - индекс, HL - массив байт -> A = массив[индекс]
Arr_Get
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret

;-------- Таблица действий тулзы: HL - таблица (действие ACT_*, обработчик; конец 0),
; B - код, C - флаги события. Действие наше, если нажатое - его бинд (Bind_Tab): так одна
; клавиша в разных тулзах может значить разное. Выход: CF - наше (обработчик вызван)
Keys_Table
        ld a,b
        ld (Kt_Key),a
        ld a,c
        and KM_SHIFT|KM_CTRL|KM_ALT ; повтор и нажатие для таблицы одинаковы
        ld (Kt_Mods),a
.f      ld a,(hl)                   ; действие, 0 - конец таблицы
        or a
        ret z                       ; не наша (CF = 0)
        call Act_Has
        jr z,.hit
        inc hl
        inc hl
        inc hl
        jr .f
.hit    ld a,(hl)                   ; какое действие - обработчику (группа на один)
        ld (Kt_Act),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call .jp
        scf
        ret
.jp     jp (hl)
Kt_Key          db 0                ; нажатое: код
Kt_Mods         db 0                ;   модификаторы (KM_*)
Kt_Act          db 0                ; сработавшее действие (ACT_*)

; A - действие: Z - нажатое (Kt_Key, Kt_Mods) - его бинд. HL, BC целы
Act_Has
        push hl
        push bc
        ld c,a
        ld hl,Bind_Tab
.b      ld a,(hl)                   ; код, 0 - конец
        or a
        jr z,.no
        ld b,a
        ld a,(Kt_Key)
        cp b
        jr nz,.n
        inc hl                      ; модификаторы - точно
        ld a,(Kt_Mods)
        cp (hl)
        dec hl
        jr nz,.n
        inc hl                      ; действие
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        dec hl
        cp c
        jr z,.yes
.n      inc hl
        inc hl
        inc hl
        inc hl
        jr .b
.no     or 1                        ; NZ
.yes    pop bc
        pop hl
        ret

;-------- Бинды (doc/architecture.md): код, модификаторы (KM_*, точно), условие (0 - всегда; пока
; не проверяется), действие ACT_*. Конец - 0. На действие - сколько угодно записей (как в VT:
; Insert или Ctrl+I). Умолчания - как VT (doc/trackers.md); свои - потом из INI поверх
Bind_Tab
        db KEY_UP,    0,        0, ACT_UP
        db KEY_DOWN,  0,        0, ACT_DOWN
        db KEY_LEFT,  0,        0, ACT_LEFT
        db KEY_RIGHT, 0,        0, ACT_RIGHT
        db KEY_PGUP,  0,        0, ACT_PGUP
        db KEY_PGDN,  0,        0, ACT_PGDN
        db KEY_HOME,  0,        0, ACT_HOME
        db KEY_END,   0,        0, ACT_END
        db KEY_TAB,   0,        0, ACT_NEXT
        db KEY_TAB,   KM_SHIFT, 0, ACT_PREV
        db KEY_ENTER, 0,        0, ACT_ENTER
        db KEY_BACK,  0,        0, ACT_DIR_UP
        db KEY_F5,    0,        0, ACT_PLAY_SONG
        db KEY_F6,    0,        0, ACT_PLAY_START
        db KEY_F7,    0,        0, ACT_PLAY_ROW
        db KEY_F8,    0,        0, ACT_PLAY_PAT
        db KEY_ESC,   0,        0, ACT_STOP
        db KEY_E,     KM_CTRL,  0, ACT_ENV_OPEN
        db KEY_E,     KM_ALT,   0, ACT_ENV_NOTE
        db KEY_T,     KM_CTRL,  0, ACT_TIMING
        db KEY_DEL,   0,        0, ACT_CLEAR
        db KEY_SPACE, 0,        0, ACT_AUTOSTEP
        db KEY_INS,   0,        0, ACT_INS_TRK
        db KEY_I,     KM_CTRL,  0, ACT_INS_PAT
        db KEY_BACK,  0,        0, ACT_DEL_TRK
        db KEY_BACK,  KM_CTRL,  0, ACT_DEL_PAT
        db KEY_Y,     KM_CTRL,  0, ACT_DEL_PAT
        db #69,       0,        0, ACT_OCT_1    ; Numpad 1..8 - октава
        db #72,       0,        0, ACT_OCT_1+1
        db #7A,       0,        0, ACT_OCT_1+2
        db #6B,       0,        0, ACT_OCT_1+3
        db #73,       0,        0, ACT_OCT_1+4
        db #74,       0,        0, ACT_OCT_1+5
        db #6C,       0,        0, ACT_OCT_1+6
        db #75,       0,        0, ACT_OCT_1+7
        db #45,       KM_CTRL,  0, ACT_STEP_0   ; Ctrl+0..9 - шаг
        db #16,       KM_CTRL,  0, ACT_STEP_0+1
        db #1E,       KM_CTRL,  0, ACT_STEP_0+2
        db #26,       KM_CTRL,  0, ACT_STEP_0+3
        db #25,       KM_CTRL,  0, ACT_STEP_0+4
        db #2E,       KM_CTRL,  0, ACT_STEP_0+5
        db #36,       KM_CTRL,  0, ACT_STEP_0+6
        db #3D,       KM_CTRL,  0, ACT_STEP_0+7
        db #3E,       KM_CTRL,  0, ACT_STEP_0+8
        db #46,       KM_CTRL,  0, ACT_STEP_0+9
        db 0


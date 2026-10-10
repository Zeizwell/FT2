; =========================================================================
; SETUP - тулза настроек (окно 1, #4000, страница PAGE_TOOL_OPT).
; =========================================================================
; ЭКРАН (строки 0..3 - копия шапки; клик по ней - вкладки / назад в вид паттерна):
;   Palette - темы (Set_Palette, коре), клик - сразу;
;   Font    - шрифты банка (Set_Font), клик - сразу;   Save - в \FT2\FT2.INI;
; Вход с SV_TOOL_ARG = OPT_HELP - экран Help: горячие клавиши (справка), рамка во всю ширину.
; Вход с SV_TOOL_ARG = OPT_LOAD (коре при старте): прочитать \FT2\FT2.INI, поставить
; тему и шрифт и сразу вернуться, без экрана.
;
; FT2.INI - текст, строки "ключ=число" (пробелов нет, ';' - комментарий):
;   palette=0..5   font=0..3   mouse_speed=0..9   mouse_accel=0..8
; Диск - через Disk_Call (коре). Буферы драйвера - в окне 3 (PAGE_FILEBUF). Текущий
; каталог драйвера потом возвращаем (им живёт тулза диска).
; =========================================================================
    MODULE optview

OV_SCR_H        equ TL_SCR_H
OV_TOP          equ TL_TOP

; --- рамки: темы, шрифты (Setup); клавиши - экран Help
PL_X            equ 0
PL_W            equ 22
FN_X            equ 22
FN_W            equ 22
KY_X            equ 0
KY_W            equ 90
LIST_Y          equ OV_TOP+2        ; первая строка списков
SAVE_Y          equ OV_TOP+10       ; кнопка Save (рамка Palette)
SAVE_X          equ 2
MSG_Y           equ OV_TOP+12       ; сообщение
MEM_Y           equ OV_TOP+14       ; свободная память
IMR_Y           equ OV_TOP+15       ; IM1: повторных входов (должно быть 00)
MS_Y            equ LIST_Y+FONTS_COUNT+2 ; мышь: заголовок, скорость, ускорение (рамка Font)
MS_X            equ FN_X+2
MS_BAR_X        equ MS_X+6          ; полоса - за подписью
MS_SPEED_MAX    equ 9               ; MOUSE_SPEED 0..9 (5 - 100%)
MS_ACCEL_MAX    equ 8               ; MOUSE_ACCEL 0..8 (0 - выкл)
CB_Y            equ MS_Y+4          ; курсор паттерна: Solid / Blink (клик - другой)

; --- файл
INI_BUF         equ #C000           ; окно 3: страница PAGE_FILEBUF
INI_MAX         equ 1000            ; читаем не больше
CLUS_BUF        equ #FFF0           ; окно 3: текущий каталог драйвера (4 байта)
FD_DIR          equ #10             ; флаг поиска: папка / файл
FD_FILE         equ #00
DK_SET_CLUS     equ 10
DK_GET_CLUS     equ 11
DK_ENTER        equ 31
DK_DELETE       equ 75
DK_MKDIR        equ 73

    MACRO OV_FIELD x,y,w,h,flags,handler,param
        db x,y,w,h,flags,PAGE_TOOL_OPT
        dw handler,0,param
    ENDM

; =========================================================================
; ВХОД
; =========================================================================
Ov_Start
        ld a,(SV_TOOL_ARG)          ; при старте коре: только прочитать настройки
        cp OPT_LOAD
        jp z,Ini_Load
        cp OPT_HELP                 ; режим: Help, иначе - Setup
        ld a,0
        jr nz,$+4
        ld a,OPT_HELP
        ld (Ov_Mode),a
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
        ld a,(Ov_Mode)
        or a
        jr nz,.help
        ld hl,OV_TAB_SETUP          ; шапка, вкладка Setup - выбрана
        ld b,5
        call Tool_Head
        call Tool_Clear
        call Tr_Active
        call Ov_Frames
        ld hl,Ov_Fields
        call Fld_Init
        ld a,1
        ld (Ov_Dirty),a
        jr Ov_Loop
.help   ld hl,OV_TAB_HELP           ; Help: шапка, вкладка Help - выбрана, клавиши
        ld b,4
        call Tool_Head
        call Tool_Clear
        call Tr_Active
        call Hp_Frame
        ld hl,Hp_Fields
        call Fld_Init

Ov_Loop
        halt
        call Ov_Keys
        call Fld_Update
        ld a,(Ov_Exit)
        or a
        jr nz,Ov_Leave
        ld a,(Ov_Mode)              ; Help - рисовать больше нечего
        or a
        jr nz,Ov_Loop
        ld a,(Ov_Dirty)
        or a
        call nz,Ov_Draw
        call Ov_Button
        jr Ov_Loop

Ov_Leave
        xor a
        ld (Ov_Exit),a
        call Tool_Clear
        RESTPAGE3
        ret

Ov_Exit         db 0
Ov_Mode         db 0                ; 0 - Setup, OPT_HELP - Help
Ov_Dirty        db 0
Ov_Msg          dw 0                ; сообщение (0 - нет)
OV_TAB_SETUP    equ OV_SCR_H*256+128+patview.HD_TAB_SETUP
OV_TAB_HELP     equ OV_SCR_H*256+128+patview.HD_HELP_X
    ASSERT OPT_HELP == 1            ; Ov_TabEv: параметр 4 - Setup, 5 - Help (минус 4)

; =========================================================================
; ЭКРАН
; =========================================================================
Ov_Frames
        ld hl,Ov_Boxes
        ld b,2
.box    push bc
        ld a,(hl)
        ld (Bx_X),a
        inc hl
        ld a,(hl)
        ld (Bx_W),a
        inc hl
        push hl
        call Tool_Box
        pop hl
        ld a,(THEME_ATTR+CLR_HEADER) ; заголовок рамки
        ld c,a
        ld a,(Bx_X)
        add a,2
        ld e,a
        ld d,OV_SCR_H+OV_TOP
        call PutStr
        inc hl
        pop bc
        djnz .box
        ret

;-------- Help: рамка во всю ширину, справка - из таблицы Hlp_Tab; клавиши действий - из
; биндов (Bind_Tab, коре), поэтому после переназначения справка верна сама
Hp_Frame
        ld hl,Hp_Box
        ld b,1
        call Ov_Frames.box
        ld a,(Hp_Page)              ; закладки: выбранная - цветом выделения
        or a
        ld a,(THEME_ATTR+CLR_SELECT)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld de,HP_TAB1+256*(OV_SCR_H+HP_TAB_Y)
        ld hl,Txt_TKeys
        call PutStr
        ld a,(Hp_Page)
        or a
        ld a,(THEME_ATTR+CLR_TEXT)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld e,HP_TAB2
        ld hl,Txt_TCmds
        call PutStr
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld a,KY_X+2                 ; первый столбец
        ld (Hl_Col),a
        ld d,OV_SCR_H+LIST_Y
        ld a,(Hp_Page)              ; страница: клавиши или команды
        or a
        ld hl,Hlp_Tab
        jr z,$+5
        ld hl,Cmd_Tab
.l      ld a,(hl)                   ; вид строки, 0 - конец
        inc hl
        or a
        ret z
        cp HL_COL
        jr nz,.t
        ld a,KY_X+46                ; второй столбец
        ld (Hl_Col),a
        ld d,OV_SCR_H+LIST_Y
        jr .l
.t      ld b,a
        ld a,(Hl_Col)
        ld e,a
        ld a,b
        cp HL_TEXT
        jr z,.txt
        cp HL_CMD
        jr z,.cmd
        cp HL_CMDX
        jr z,.cmdx
        cp HL_ACT
        ld a,(hl)                   ; действие (у диапазона - первое)
        inc hl
        ld (Hl_Act),a
        jr z,.act
        ld a,(hl)                   ; диапазон: последнее
        inc hl
        ld (Hl_Last),a
        push hl
        ld a,(Hl_Act)
        call Key_Of                 ; первая клавиша первого ".." первая последнего
        ld a,'.'
        call PutCh
        ld a,'.'
        call PutCh
        ld a,(Hl_Last)
        call Key_Of
        pop hl
        jr .desc
.act    push hl
        ld a,(Hl_Act)
        call Keys_Of
        pop hl
.desc   ld a,(Hl_Col)               ; описание - за колонкой клавиш
        add a,HL_KEYW
        ld e,a
.txt    call PutStr
        inc hl
        inc d
        jr .l
.cmdx   ld a,CMD_EXT                ; расширенная: "F" и подкод
        call .hex
.cmd    ld a,(hl)                   ; код команды - из CMD_* (sdk), дальше текст
        inc hl
        call .hex
        jr .txt
.hex    cp 10                       ; A - hex-цифра
        jr c,$+4
        add a,7
        add a,'0'
        jp PutCh
Hl_Col          db 0
Hl_Act          db 0
Hl_Last         db 0
HL_KEYW         equ 18              ; ширина колонки клавиш

; A - действие: все его клавиши через ", " (с DE). Портит всё, кроме C, D
Keys_Of
        ld (Ko_Act),a
        xor a
        ld (Ko_N),a
        ld hl,Bind_Tab
.f      ld a,(hl)                   ; код, 0 - конец
        or a
        ret z
        ld (Ko_Ptr),hl
        inc hl
        inc hl
        inc hl
        ld a,(Ko_Act)
        cp (hl)
        ld hl,(Ko_Ptr)
        jr nz,.n
        ld a,(Ko_N)                 ; не первая - через запятую
        or a
        jr z,.p
        ld a,','
        call PutCh
        ld a,' '
        call PutCh
.p      ld hl,Ko_N
        inc (hl)
        ld hl,(Ko_Ptr)
        call .one
        ld hl,(Ko_Ptr)
.n      inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.one    push hl                     ; HL - запись бинда: модификаторы, клавиша
        inc hl
        ld a,(hl)
        call Mods_Put
        pop hl
        push hl
        ld a,(hl)
        call Key_Put
        pop hl
        ret
Ko_Act          db 0
Ko_N            db 0
Ko_Ptr          dw 0

; A - действие: его первая клавиша (с модификаторами). Нет бинда - "-"
Key_Of
        ld b,a
        ld hl,Bind_Tab
.f      ld a,(hl)
        or a
        jr z,.none
        push hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        pop hl
        cp b
        jp z,Keys_Of.one
        inc hl
        inc hl
        inc hl
        inc hl
        jr .f
.none   ld a,'-'
        jp PutCh

; A - модификаторы KM_* -> "Ctrl+", "Shift+", "Alt+"
Mods_Put
        ld b,a
        bit 1,b                     ; KM_CTRL
        ld hl,Txt_Ctrl
        call nz,PutStr
        bit 0,b                     ; KM_SHIFT
        ld hl,Txt_Shift
        call nz,PutStr
        bit 2,b                     ; KM_ALT
        ld hl,Txt_Alt
        call nz,PutStr
        ret
    ASSERT KM_SHIFT == 1 && KM_CTRL == 2 && KM_ALT == 4
Txt_Ctrl        db "Ctrl+",0
Txt_Shift       db "Shift+",0
Txt_Alt         db "Alt+",0

; A - код клавиши -> её имя: особые - по таблице, буквы и цифры - из Key_Chars (заглавные)
Key_Put
        ld b,a
        ld hl,Key_Names
.f      ld a,(hl)                   ; код, имя, 0; конец - 0
        or a
        jr z,.ch
        inc hl
        cp b
        jp z,PutStr
.s      ld a,(hl)                   ; мимо имени
        inc hl
        or a
        jr nz,.s
        jr .f
.ch     ld a,b                      ; E0-коды без имени - "?"
        or a
        jp m,.q
        ld h,high Key_Chars
        ld l,a
        ld a,(hl)
        or a
        jr z,.q
        cp 'a'
        jr c,.put
        cp 'z'+1
        jr nc,.put
        sub 'a'-'A'
.put    jp PutCh
.q      ld a,'?'
        jp PutCh

Key_Names
        db KEY_UP,"Up",0,       KEY_DOWN,"Down",0,   KEY_LEFT,"Left",0
        db KEY_RIGHT,"Right",0, KEY_PGUP,"PgUp",0,   KEY_PGDN,"PgDn",0
        db KEY_HOME,"Home",0,   KEY_END,"End",0,     KEY_TAB,"Tab",0
        db KEY_ENTER,"Enter",0, KEY_BACK,"Bksp",0,   KEY_ESC,"Esc",0
        db KEY_SPACE,"Space",0, KEY_DEL,"Del",0,     KEY_INS,"Ins",0
        db KEY_F5,"F5",0,       KEY_F6,"F6",0,       KEY_F7,"F7",0
        db KEY_F8,"F8",0,       KEY_KP_PLUS,"Num+",0, KEY_KP_MINUS,"Num-",0
        db #69,"Num1",0, #72,"Num2",0, #7A,"Num3",0, #6B,"Num4",0
        db #73,"Num5",0, #74,"Num6",0, #6C,"Num7",0, #75,"Num8",0
        db 0

;-------- Закладки Help: клик - страница (клавиши / команды), рамка заново
Hp_TabEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        ld (Hp_Page),a
        jp Hp_Frame

; Команды паттерна (doc/commands.md): коды - из CMD_* / CMDX_* (sdk), поменяли код - справка тоже
Cmd_Tab
        db HL_TEXT,"Command NDPp: N code, D delay, Pp param",0
        db HL_TEXT," ",0
        db HL_CMD,CMD_GLIS_DOWN,"DPp  glide down: delay, step",0
        db HL_CMD,CMD_GLIS_UP,"DPp  glide up: delay, step",0
        db HL_CMD,CMD_PORTA,"DPp  portamento (from current pitch)",0
        db HL_CMD,CMD_SMP_OFS,".Pp  sample from row Pp",0
        db HL_CMD,CMD_ORN_OFS,".Pp  ornament from row Pp",0
        db HL_CMD,CMD_ONOFF,".XY  sound on X / off Y ticks",0
        db HL_CMD,CMD_VOL_SLIDE,"DXY  volume slide: up X, down Y",0
        db HL_CMD,CMD_VIBRATO,"DXY  vibrato: speed X, depth Y",0
        db HL_CMD,CMD_ENV_DOWN,"DPp  envelope slide down",0
        db HL_CMD,CMD_ENV_UP,"DPp  envelope slide up",0
        db HL_CMD,CMD_SPEED,".Pp  speed: ticks per row",0
        db HL_CMD,CMD_ARP,"NXY  arpeggio: N steps, +X, +Y",0
        db HL_CMDX,CMDX_RETRIG,"..  envelope + tone retrigger",0
        db HL_CMDX,CMDX_DETUNE,"Pp  detune (signed)",0
        db HL_CMDX,CMDX_DELAY,"Pp  note delay: ticks",0
        db HL_TEXT," ",0
        db HL_TEXT,"Player plays now: speed only",0
        db HL_COL
        db HL_TEXT,"Channel cell:  C-4 A1FE 1234 5678",0
        db HL_TEXT,"  C-4   note (R-- off)",0
        db HL_TEXT,"  A     sample 1..W",0
        db HL_TEXT,"  1     envelope shape 1..E, F - off",0
        db HL_TEXT,"  F     ornament 0..G (0 - none)",0
        db HL_TEXT,"  E     volume 1..F",0
        db HL_TEXT,"  1234 5678  two commands",0
        db HL_TEXT," ",0
        db HL_TEXT,"Chip Env:  0134 1F 0000",0
        db HL_TEXT,"  0134  envelope period",0
        db HL_TEXT,"  1F    noise",0
        db HL_TEXT,"  0000  envelope 2",0
        db HL_TEXT," ",0
        db HL_TEXT,"Empty field (.) - keep previous",0
        db 0

; Справка: HL_TEXT текст / HL_ACT действие, описание / HL_RANGE первое, последнее, описание /
; HL_COL - второй столбец. Конец - 0
HL_TEXT         equ 1
HL_ACT          equ 2
HL_RANGE        equ 3
HL_COL          equ 4
HL_CMD          equ 5               ; код CMD_*, текст - на экране код hex и текст
HL_CMDX         equ 6               ; подкод CMDX_*, текст - "F", подкод и текст
Hlp_Tab
        db HL_TEXT,"Pattern:",0
        db HL_TEXT,"Z..M Q..P         notes (Shift - octave up)",0
        db HL_TEXT,"A  K              note off / clear note",0
        db HL_TEXT,"0-9 A-F           digits in fields",0
        db HL_ACT,ACT_CLEAR,"clear field / selection",0
        db HL_ACT,ACT_INS_TRK,"insert track line",0
        db HL_ACT,ACT_DEL_TRK,"delete track line",0
        db HL_ACT,ACT_INS_PAT,"insert row",0
        db HL_ACT,ACT_DEL_PAT,"delete row",0
        db HL_ACT,ACT_UNDO,"undo (in channel)",0
        db HL_ACT,ACT_REDO,"redo",0
        db HL_TEXT,"Shift+arrows, drag - select",0
        db HL_ACT,ACT_SEL_ALL,"select all",0
        db HL_ACT,ACT_COPY,"copy",0
        db HL_ACT,ACT_CUT,"cut",0
        db HL_ACT,ACT_PASTE,"paste",0
        db HL_ACT,ACT_TR_UP,"transpose up",0
        db HL_ACT,ACT_TR_DN,"transpose down",0
        db HL_ACT,ACT_TR_OCT_UP,"octave up",0
        db HL_ACT,ACT_TR_OCT_DN,"octave down",0
        db HL_ACT,ACT_AUTOSTEP,"autostep on / off",0
        db HL_RANGE,ACT_STEP_0,ACT_STEP_0+9,"step",0
        db HL_RANGE,ACT_OCT_1,ACT_OCT_1+7,"input octave",0
        db HL_ACT,ACT_ENTER,"play pattern (hold)",0
        db HL_TEXT,"Left Right        fields",0
        db HL_TEXT,"Click             cursor (Shift - select)",0
        db HL_COL
        db HL_ACT,ACT_PLAY_SONG,"play song from position",0
        db HL_ACT,ACT_PLAY_START,"play song from start",0
        db HL_ACT,ACT_PLAY_ROW,"play pattern from row",0
        db HL_ACT,ACT_PLAY_PAT,"play pattern (loop)",0
        db HL_ACT,ACT_STOP,"stop",0
        db HL_ACT,ACT_ENV_OPEN,"open chip Env",0
        db HL_ACT,ACT_ENV_NOTE,"envelope as note",0
        db HL_ACT,ACT_TIMING,"time band",0
        db HL_ACT,ACT_NEXT,"next channel",0
        db HL_ACT,ACT_PREV,"previous channel",0
        db HL_TEXT," ",0
        db HL_TEXT,"Instr / Orn:",0
        db HL_TEXT,"Arrows PgUp PgDn  cursor",0
        db HL_TEXT,"0-9 A-F  - =      digits, sign",0
        db HL_TEXT,"Space             flag on / off",0
        db HL_TEXT,"Z..M Q..P         piano (preview row)",0
        db HL_ACT,ACT_ENTER,"play preview (hold)",0
        db HL_ACT,ACT_INS_TRK,"insert row",0
        db HL_ACT,ACT_INS_PAT,"insert row",0
        db HL_ACT,ACT_DEL_TRK,"delete row",0
        db HL_ACT,ACT_DEL_PAT,"delete row",0
        db HL_TEXT,"+  x              insert / delete (mouse)",0
        db HL_TEXT,"Click L, number   loop to this row",0
        db 0

Ov_Boxes
        db PL_X,PL_W,"Palette",0
        db FN_X,FN_W,"Font",0
Hp_Box  db KY_X,KY_W,"Help",0
HP_TAB_Y        equ OV_TOP+1        ; закладки Help
HP_TAB1         equ KY_X+2
HP_TAB2         equ KY_X+9
Hp_Page         db 0                ; 0 - клавиши, 1 - команды
Txt_TKeys       db " Keys ",0
Txt_TCmds       db " Commands ",0

;-------- Списки (выбранное - выделением), свободная память, сообщение
Ov_Draw
        xor a
        ld (Ov_Dirty),a
        ld a,(THEME_ATTR+CLR_TEXT)  ; "Free: NN pages"
        ld c,a
        ld de,SAVE_X+256*(OV_SCR_H+MEM_Y)
        ld hl,Txt_Free
        call PutStr
        ld de,SAVE_X+256*(OV_SCR_H+IMR_Y)
        ld hl,Txt_ImRe
        call PutStr
        ld a,(Im_Reenter)
        call PutHex2
        ld hl,Pal_Names             ; темы: имена по 8
        ld a,(Cur_Palette)
        ld c,a
        ld b,PALETTES
        ld e,PL_X+2
        call Ov_List
        ld hl,Font_Names            ; шрифты: имена по 8... по 14
        ld a,(SV_FONT)
        ld c,a
        ld b,FONTS_COUNT
        ld e,FN_X+2
        call Ov_List14
        call Ov_Mouse
        ld a,(THEME_ATTR+CLR_BG)    ; сообщение
        ld c,a
        ld de,1+256*(OV_SCR_H+MSG_Y)
        ld b,PL_W-2
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld hl,(Ov_Msg)
        ld a,h
        or l
        ret z
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld e,SAVE_X
        jp PutStr

; Список имён по 8 знаков: HL - имена, B - сколько, C - выбранный, E - колонка
Ov_List
        ld a,8
        jr Ov_Names
Ov_List14
        ld a,14
Ov_Names
        ld (Ol_W),a
        ld d,OV_SCR_H+LIST_Y
        ld a,c
        ld (Ol_Sel),a
        xor a
        ld (Ol_I),a
.n      push bc
        push de
        ld a,(Ol_I)                 ; цвет: выбранный - выделением
        ld b,a
        ld a,(Ol_Sel)
        cp b
        ld a,(THEME_ATTR+CLR_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
        ld a,(Ol_W)
        ld b,a
.c      ld a,(hl)
        call PutCh
        inc hl
        djnz .c
        pop de
        inc d
        ld a,(Ol_I)
        inc a
        ld (Ol_I),a
        pop bc
        djnz .n
        ret
Ol_W            db 0
Ol_Sel          db 0
Ol_I            db 0

;-------- Мышь: заголовок и две полосы
Ov_Mouse
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,MS_X+256*(OV_SCR_H+MS_Y)
        ld hl,Txt_Mouse
        call PutStr
        ld de,MS_X+256*(OV_SCR_H+MS_Y+1)
        ld hl,Txt_Speed
        ld a,(MOUSE_SPEED)
        ld b,MS_SPEED_MAX
        call Ov_Bar
        ld de,MS_X+256*(OV_SCR_H+MS_Y+2)
        ld hl,Txt_Accel
        ld a,(MOUSE_ACCEL)
        ld b,MS_ACCEL_MAX
        call Ov_Bar
        ld a,(THEME_ATTR+CLR_TEXT)  ; курсор паттерна
        ld c,a
        ld de,MS_X+256*(OV_SCR_H+CB_Y)
        ld hl,Txt_Cursor
        call PutStr
        ld a,(THEME_ATTR+CLR_VOLUME)
        ld c,a
        ld a,(Cur_Blink)
        or a
        ld hl,Txt_Solid
        jr z,$+5
        ld hl,Txt_Blink
        jp PutStr

; Полоса: HL - подпись (6 знаков), A - значение (столько клеток горит), B - клеток всего,
; DE - место. За полосой - значение цифрой
Ov_Bar
        ld (Ob_V),a
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        call PutStr
        ld a,(Ob_V)
        ld l,a                      ; L - сколько клеток ещё горит
.c      ld a,(THEME_ATTR+CLR_VOLUME) ; горит - клетка цветом громкости
        ld c,a
        ld a,GLYPH_VOL
        dec l
        jp p,.put
        ld a,(THEME_ATTR+CLR_EMPTY) ; нет - точка, как пустое поле
        ld c,a
        ld a,'.'
.put    call PutCh
        djnz .c
        ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld a,' '
        call PutCh
        ld a,(Ob_V)
        add a,'0'
        jp PutCh
Ob_V            db 0

;-------- Кнопка Save: под мышью / нажата - другим цветом
Ov_Button
        ld hl,F_Save
        ld de,(SV_HOVER)
        or a
        sbc hl,de
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr nz,.put
        ld hl,F_Save
        ld de,(SV_PRESSED)
        or a
        sbc hl,de
        ld a,(THEME_ATTR+CLR_HOVER)
        jr nz,.put
        ld a,(THEME_ATTR+CLR_CURSOR)
.put    ld c,a
        ld de,SAVE_X+256*(OV_SCR_H+SAVE_Y)
        ld hl,Txt_Save
        jp PutStr

; =========================================================================
; ПОЛЯ
; =========================================================================
Ov_Fields
        OV_FIELD patview.HD_PLAY_X,   patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 0
        OV_FIELD patview.HD_PLAY_X+4, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 1
        OV_FIELD patview.HD_PLAY_X+8, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 2
        OV_FIELD patview.HD_PLAY_X+12,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 3
        OV_FIELD patview.HD_PLAY_X+16,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 4
        OV_FIELD patview.HD_TAB_INSTR,patview.HD_TABS_Y,5,1, FF_HAND, Ov_TabEv, 1  ; Instr
        OV_FIELD patview.HD_TAB_ORN,  patview.HD_TABS_Y,3,1, FF_HAND, Ov_TabEv, 2  ; Orn
        OV_FIELD patview.HD_TAB_DISK, patview.HD_TABS_Y,4,1, FF_HAND, Ov_TabEv, 3  ; Disk
        OV_FIELD patview.HD_HELP_X,   patview.HD_TABS_Y,4,1, FF_HAND, Ov_TabEv, 5  ; Help
        OV_FIELD 0,0,90,OV_TOP, 0, Ov_TabEv, 0                          ; остальное - назад
        OV_FIELD PL_X+2,LIST_Y,8,PALETTES, FF_HAND, Ov_PalEv, 0          ; темы
        OV_FIELD FN_X+2,LIST_Y,14,FONTS_COUNT, FF_HAND, Ov_FontEv, 0     ; шрифты
;-------- Help: те же транспорт и вкладки, Setup - назад в настройки
Hp_Fields
        OV_FIELD HP_TAB1,HP_TAB_Y,6,1, FF_HAND, Hp_TabEv, 0             ; закладки
        OV_FIELD HP_TAB2,HP_TAB_Y,10,1, FF_HAND, Hp_TabEv, 1
        OV_FIELD patview.HD_PLAY_X,   patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 0
        OV_FIELD patview.HD_PLAY_X+4, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 1
        OV_FIELD patview.HD_PLAY_X+8, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 2
        OV_FIELD patview.HD_PLAY_X+12,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 3
        OV_FIELD patview.HD_PLAY_X+16,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 4
        OV_FIELD patview.HD_TAB_INSTR,patview.HD_TABS_Y,5,1, FF_HAND, Ov_TabEv, 1  ; Instr
        OV_FIELD patview.HD_TAB_ORN,  patview.HD_TABS_Y,3,1, FF_HAND, Ov_TabEv, 2  ; Orn
        OV_FIELD patview.HD_TAB_DISK, patview.HD_TABS_Y,4,1, FF_HAND, Ov_TabEv, 3  ; Disk
        OV_FIELD patview.HD_TAB_SETUP,patview.HD_TABS_Y,5,1, FF_HAND, Ov_TabEv, 4  ; Setup
        OV_FIELD 0,0,90,OV_TOP, 0, Ov_TabEv, 0                          ; остальное - назад
        db FLD_END

F_Save  OV_FIELD SAVE_X,SAVE_Y,6,1, FF_HAND, Ov_SaveEv, 0                ; Save
        OV_FIELD MS_X,MS_Y+1,6+MS_SPEED_MAX,1, FF_HAND, Ov_MouseEv, 0    ; мышь: скорость
        OV_FIELD MS_X,MS_Y+2,6+MS_ACCEL_MAX,1, FF_HAND, Ov_MouseEv, 1    ;   ускорение
        OV_FIELD MS_X,CB_Y,12,1, FF_HAND, Ov_CurEv, 0                    ; курсор: Solid / Blink
        db FLD_END

;-------- Шапка: 0 - вид паттерна, 1/2 - Instr/Orn, 3 - Disk, 4 - Setup, 5 - Help
Ov_TabEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        ld b,PAGE_TOOL_PATVIEW
        or a
        jr z,.go
        ld b,PAGE_TOOL_DISK
        cp 3
        jr z,.go
        jr c,.ins
        sub 4                       ; Setup - 0, Help - OPT_HELP: эта же тулза заново
        ld (SV_TOOL_ARG),a
        ld b,PAGE_TOOL_OPT
        jr .go
.ins    dec a                       ; режим инструментов: 0 / 1
        ld (SV_TOOL_ARG),a
        ld b,PAGE_TOOL_INSTR
.go     ld a,b
        ld (SV_TOOL),a
        ld a,1
        ld (Ov_Exit),a
        ret

;-------- Тема: клик - сразу
Ov_PalEv
        cp EV_PRESS
        ret nz
        ld a,(SV_MOUSE_ROW)
        sub LIST_Y
        call Set_Palette
        jr Ov_Changed

;-------- Шрифт: клик - сразу (значки - поверх)
Ov_FontEv
        cp EV_PRESS
        ret nz
        ld a,(SV_MOUSE_ROW)
        sub LIST_Y
        call Set_Font
        call Apply_UI_Glyphs
Ov_Changed
        ld hl,0
        ld (Ov_Msg),hl
        ld a,1
        ld (Ov_Dirty),a
        ret

;-------- Курсор паттерна: клик - сплошной / мигающий
Ov_CurEv
        cp EV_CLICK
        ret nz
        ld a,(Cur_Blink)
        xor 1
        ld (Cur_Blink),a
        jp Ov_Changed

;-------- Мышь: клик по клетке k - значение k+1, по подписи - 0. Таблицу скорости - сразу
Ov_MouseEv
        cp EV_PRESS
        ret nz
        ld a,(SV_MOUSE_COL)         ; клетка: колонка - начало полосы
        sub MS_BAR_X
        jr nc,$+4
        ld a,-1                     ; подпись - 0
        inc a
        ld b,a
        ld a,(ix+FLD_PARAM)
        or a
        ld a,b
        jr nz,.acc
        ld (MOUSE_SPEED),a
        jr .set
.acc    ld (MOUSE_ACCEL),a
.set    push ix                     ; Mouse_Scale портит IX
        call Mouse_Scale
        pop ix
        jp Ov_Changed

;-------- Save: настройки - в \FT2\FT2.INI
Ov_SaveEv
        cp EV_CLICK
        ret nz
        call Ini_Save
        ld hl,Txt_Saved
        jr nc,$+5
        ld hl,Txt_DiskErr
        ld (Ov_Msg),hl
        ld a,1
        ld (Ov_Dirty),a
        ret

;-------- Клавиши: полям (здесь своих нет) - просто выбрать очередь
Ov_Keys
.k      call Key_Get
        ret z
        ld b,a
        call Fld_Key
        jr .k

; =========================================================================
; FT2.INI
; =========================================================================
;-------- Прочитать и применить (тема, шрифт). Нет карты / файла - всё как есть
Ini_Load
        ld a,PAGE_FILEBUF
        SETPAGE3 a
        call Ini_Dir                ; \FT2 - текущий
        jr c,.out
        ld ix,DK_FIND+256
        ld hl,Spec_Ini
        call Disk_Call
        jr c,.back
        jr z,.back                  ; файла нет
        ld a,d                      ; размер (больше INI_MAX - читаем INI_MAX)
        or e
        jr nz,.max
        ld bc,INI_MAX
        or a
        sbc hl,bc
        add hl,bc
        jr c,.len
.max    ld hl,INI_MAX
.len    ld (Ini_Len),hl
        ld ix,DK_READ
        ld hl,INI_BUF
        ld b,2                      ; 2 сектора = 1К
        call Disk_Call
        jr c,.back
        call Ini_Parse
.back   call Ini_Dir_Back
.out    RESTPAGE3
        ret

Ini_Len         dw 0

;-------- Разбор INI_BUF (Ini_Len байт): строки "ключ=число" -> применить
Ini_Parse
        ld hl,INI_BUF
        ld bc,(Ini_Len)
        add hl,bc
        ld (hl),0                   ; конец текста
        ld hl,INI_BUF
.line   ld de,Key_Palette           ; palette=
        call Ini_Key
        jr nz,.font
        call Ini_Num
        cp PALETTES
        jr nc,.next
        ld b,a                      ; та же, что стоит - CRAM не трогаем
        ld a,(Cur_Palette)
        cp b
        jr z,.next
        ld a,b
        push hl
        call Set_Palette
        pop hl
        jr .next
.font   ld de,Key_Font              ; font=
        call Ini_Key
        jr nz,.mspd
        call Ini_Num
        cp FONTS_COUNT
        jr nc,.next
        push hl
        call Set_Font
        call Apply_UI_Glyphs
        pop hl
        jr .next
.mspd   ld de,Key_MSpeed            ; mouse_speed=
        call Ini_Key
        jr nz,.macc
        call Ini_Num
        cp MS_SPEED_MAX+1
        jr nc,.next
        ld (MOUSE_SPEED),a
        jr .mset
.macc   ld de,Key_MAccel            ; mouse_accel=
        call Ini_Key
        jr nz,.cblk
        call Ini_Num
        cp MS_ACCEL_MAX+1
        jr nc,.next
        ld (MOUSE_ACCEL),a
.mset   push hl                     ; таблица скорости - заново
        call Mouse_Scale
        pop hl
        jr .next
.cblk   ld de,Key_CBlink            ; cursor_blink=
        call Ini_Key
        jr nz,.next
        call Ini_Num
        and 1
        ld (Cur_Blink),a
.next   ld a,(hl)                   ; до конца строки
        or a
        ret z
        inc hl
        cp 10
        jr nz,.next
        jr .line

; Ключ DE (с '=' на конце, 0) с позиции HL? Z - да, HL - за '='; NZ - HL как был
Ini_Key
        push hl
.c      ld a,(de)
        or a
        jr z,.yes
        cp (hl)
        jr nz,.no
        inc hl
        inc de
        jr .c
.yes    pop bc                      ; старый HL не нужен
        xor a                       ; Z
        ret
.no     pop hl
        ret                         ; NZ

; Десятичное число с HL -> A (до 255), HL - за ним. Портит B
Ini_Num
        xor a
.d      ld b,a
        ld a,(hl)
        sub '0'
        jr c,.e
        cp 10
        jr nc,.e
        inc hl
        ld c,a
        ld a,b                      ; A = B*10 + цифра
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,c
        jr .d
.e      ld a,b
        ret

;-------- Записать: \FT2 (нет - создать), старый FT2.INI - удалить, новый - создать.
; CF - ошибка
Ini_Save
        ld a,PAGE_FILEBUF
        SETPAGE3 a
        call Ini_Dir
        jr c,.out
        ld ix,DK_DELETE+256         ; старый - удалить (нет - не важно)
        ld hl,Spec_Ini
        call Disk_Call
        call Ini_Text               ; текст - в INI_BUF, BC - длина
        ld (Ini_Len),bc
        ld ix,DK_CREATE+256
        ld hl,Spec_New
        call Disk_Call
        jr c,.err
        jr nz,.err
        ld ix,DK_APPEND
        ld hl,INI_BUF
        ld bc,(Ini_Len)
        call Disk_Call
        jr c,.err
        or a
        jr nz,.err
        ld ix,DK_CLOSE
        call Disk_Call
        jr c,.err
        jr nz,.err
        call Ini_Dir_Back
        RESTPAGE3
        or a
        ret
.err    call Ini_Dir_Back
.out    RESTPAGE3
        scf
        ret

; Текст настроек -> INI_BUF, BC - длина
Ini_Text
        ld de,INI_BUF
        ld hl,Txt_IniHead
        call Str_Put
        ld hl,Key_Palette
        call Str_Put
        ld a,(Cur_Palette)
        call Dec_Put
        ld hl,Key_Font
        call Str_Put
        ld a,(SV_FONT)
        call Dec_Put
        ld hl,Key_MSpeed
        call Str_Put
        ld a,(MOUSE_SPEED)
        call Dec_Put
        ld hl,Key_MAccel
        call Str_Put
        ld a,(MOUSE_ACCEL)
        call Dec_Put
        ld hl,Key_CBlink
        call Str_Put
        ld a,(Cur_Blink)
        call Dec_Put
        ex de,hl                    ; длина = конец - начало
        ld bc,INI_BUF
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        ret

; Строку HL (до 0) - в DE
Str_Put
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr Str_Put

; A (0..99) десятичным в DE и перевод строки
Dec_Put
        ld b,'0'-1
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        cp '0'
        jr z,.one
        ld (de),a
        inc de
.one    ld a,c
        ld (de),a
        inc de
        ld a,13
        ld (de),a
        inc de
        ld a,10
        ld (de),a
        inc de
        ret

;-------- Каталог \FT2 - текущий (карта подключается; нет папки - создаётся).
; Прежний текущий каталог - в CLUS_BUF (вернуть - Ini_Dir_Back). CF - ошибка
Ini_Dir
        call Disk_Mount
        scf
        ret nz
        ld ix,DK_GET_CLUS
        ld de,CLUS_BUF
        call Disk_Call
        ret c
        ld ix,DK_SET_ROOT
        call Disk_Call
        jr c,.fail
        ld ix,DK_FIND+256
        ld hl,Spec_Dir
        call Disk_Call
        jr c,.fail
        jr nz,.enter
        ld ix,DK_MKDIR+256          ; нет - создать
        ld hl,Spec_MkDir
        call Disk_Call
        jr c,.fail
        ld ix,DK_FIND+256
        ld hl,Spec_Dir
        call Disk_Call
        jr c,.fail
        jr z,.fail
.enter  ld ix,DK_ENTER
        call Disk_Call
        ret nc
.fail   call Ini_Dir_Back           ; каталог - как был
        scf
        ret

;-------- Вернуть текущий каталог драйвера
Ini_Dir_Back
        ld ix,DK_SET_CLUS
        ld hl,CLUS_BUF
        jp Disk_Call

; =========================================================================
; ТЕКСТЫ
; =========================================================================
Spec_Dir        db FD_DIR,"FT2",0
Spec_Ini        db FD_FILE,"FT2.INI",0
Spec_New        db #20,0,0,0,0,"FT2.INI",0      ; CREATE: атрибут, размер 0, имя
Spec_MkDir      db "FT2",0                      ; MKDIR: [имя, 0] (README драйвера)
Key_Palette     db "palette=",0
Key_Font        db "font=",0
Key_MSpeed      db "mouse_speed=",0
Key_MAccel      db "mouse_accel=",0
Key_CBlink      db "cursor_blink=",0
Txt_IniHead     db "; Fast Tracker 2.01b settings",13,10,0
Txt_Save        db " Save ",0
Txt_Saved       db "Saved \\FT2\\FT2.INI",0
Txt_DiskErr     db "Disk error",0
Txt_ImRe        db "IM1 re-entry: ",0
Txt_Mouse       db "Mouse",0
Txt_Speed       db "Speed ",0
Txt_Accel       db "Accel ",0
Txt_Cursor      db "Cursor ",0
Txt_Solid       db "Solid",0
Txt_Blink       db "Blink",0

; Имена шрифтов банка (как в srs/main.asm), по 14 знаков
Font_Names      db "cp866         Toshiba TxL1  Toshiba TxL2  Compaq Thin   "
    ASSERT $-Font_Names == FONTS_COUNT*14

    ENDMODULE

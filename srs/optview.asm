; =========================================================================
; SETUP - тулза настроек (окно 1, #4000, страница PAGE_TOOL_OPT).
; =========================================================================
; ЭКРАН (строки 0..3 - копия шапки; клик по ней - вкладки / назад в вид паттерна):
;   Palette - темы (Set_Palette, коре), клик - сразу;
;   Font    - шрифты банка (Set_Font), клик - сразу;   Save - в \FT2\FT2.INI;
;   Keys    - горячие клавиши (справка).
; Вход с SV_TOOL_ARG = OPT_LOAD (коре при старте): прочитать \FT2\FT2.INI, поставить
; тему и шрифт и сразу вернуться, без экрана.
;
; FT2.INI - текст, строки "ключ=число" (пробелов нет, ';' - комментарий):
;   palette=0..5   font=0..3
; Диск - через Disk_Call (коре). Буферы драйвера - в окне 3 (PAGE_FILEBUF). Текущий
; каталог драйвера потом возвращаем (им живёт тулза диска).
; =========================================================================
    MODULE optview

OV_SCR_H        equ TL_SCR_H
OV_TOP          equ TL_TOP

; --- рамки: темы, шрифты, клавиши
PL_X            equ 0
PL_W            equ 22
FN_X            equ 22
FN_W            equ 22
KY_X            equ 44
KY_W            equ 46
LIST_Y          equ OV_TOP+2        ; первая строка списков
SAVE_Y          equ OV_TOP+10       ; кнопка Save (рамка Palette)
SAVE_X          equ 2
MSG_Y           equ OV_TOP+12       ; сообщение

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
        ld a,(SV_DRAW_PAGE)
        SETPAGE3 a
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

Ov_Loop
        halt
        call Ov_Keys
        call Fld_Update
        ld a,(Ov_Exit)
        or a
        jr nz,Ov_Leave
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
Ov_Dirty        db 0
Ov_Msg          dw 0                ; сообщение (0 - нет)
OV_TAB_SETUP    equ OV_SCR_H*256+128+patview.HD_TAB_SETUP

; =========================================================================
; ЭКРАН
; =========================================================================
Ov_Frames
        ld hl,Ov_Boxes
        ld b,3
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
        ld a,(THEME_ATTR+CLR_TEXT)  ; клавиши - справка, один раз
        ld c,a
        ld hl,Txt_Keys
        ld d,OV_SCR_H+LIST_Y
.ky     ld e,KY_X+2
        call PutStr
        inc hl
        inc d
        ld a,(hl)
        or a
        jr nz,.ky
        ret

Ov_Boxes
        db PL_X,PL_W,"Palette",0
        db FN_X,FN_W,"Font",0
        db KY_X,KY_W,"Keys",0

;-------- Списки (выбранное - выделением) и сообщение
Ov_Draw
        xor a
        ld (Ov_Dirty),a
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
        OV_FIELD 0,0,90,OV_TOP, 0, Ov_TabEv, 0                          ; остальное - назад
        OV_FIELD PL_X+2,LIST_Y,8,PALETTES, FF_HAND, Ov_PalEv, 0          ; темы
        OV_FIELD FN_X+2,LIST_Y,14,FONTS_COUNT, FF_HAND, Ov_FontEv, 0     ; шрифты
F_Save  OV_FIELD SAVE_X,SAVE_Y,6,1, FF_HAND, Ov_SaveEv, 0                ; Save
        db FLD_END

;-------- Шапка: 0 - вид паттерна, 1/2 - Instr/Orn, 3 - Disk
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
        dec a                       ; режим инструментов: 0 / 1
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
        push hl
        call Set_Palette
        pop hl
        jr .next
.font   ld de,Key_Font              ; font=
        call Ini_Key
        jr nz,.next
        call Ini_Num
        cp FONTS_COUNT
        jr nc,.next
        push hl
        call Set_Font
        call Apply_UI_Glyphs
        pop hl
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
Spec_MkDir      db #10,0,0,0,0,"FT2",0          ; MKDIR: папка
Key_Palette     db "palette=",0
Key_Font        db "font=",0
Txt_IniHead     db "; Fast Tracker 2.01b settings",13,10,0
Txt_Save        db " Save ",0
Txt_Saved       db "Saved \\FT2\\FT2.INI",0
Txt_DiskErr     db "Disk error",0

; Имена шрифтов банка (как в srs/main.asm), по 14 знаков
Font_Names      db "cp866         Toshiba TxL1  Toshiba TxL2  Compaq Thin   "
    ASSERT $-Font_Names == FONTS_COUNT*14

; Справка: строки, пустая строка - " ", конец - 0
Txt_Keys
        db "F5        Play song from position",0
        db "F6        Play song from start",0
        db "F7        Play pattern from row",0
        db "F8        Play pattern (loop)",0
        db "Esc       Stop",0
        db "Ctrl+E    Open chip Env column",0
        db "Alt+E     Envelope as note",0
        db "Ctrl+T    Time band",0
        db "Tab       Next field",0
        db " ",0
        db "Instr / Orn:",0
        db "Arrows, PgUp/PgDn, Home/End - cursor",0
        db "0-9 A-F   digits",0
        db "- =       sign (slide: down / up)",0
        db "Space     flag on/off",0
        db "Z..M Q..P piano (preview row, Tab)",0
        db "Click L   loop to this row",0
        db 0

    ENDMODULE

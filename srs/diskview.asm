; =========================================================================
; ДИСК - тулза (окно 1, #4000, страница PAGE_TOOL_DISK): каталог, загрузка и
; сохранение трека FT2.
; =========================================================================
; ЭКРАН (строки 0..3 - копия шапки из её буфера, кликается только вкладка Pattern):
;   слева  - рамка с путём, каталог: сначала папки, потом файлы; имя, размер, дата;
;   справа - выбранный файл: Name (поле ввода - под это имя сохраняем), тип,
;            размер, Song / By (FT2 и PT3 - из файла), кнопки Load, Save, сообщение.
; Мышь: клик - выбрать, двойной клик / Enter - открыть (папка - войти, файл -
; загрузить), колесо - листать. Backspace в каталоге - в папку выше.
;
; ПАМЯТЬ:
;   PAGE_DIRLIST - каталог: записи по DR_SIZE (флаг, размер, дата, имя), хвост
;                  страницы - буфер записи драйвера (NXTETY) и кластер каталога;
;   PAGE_FILEBUF.. - файл трека целиком (32 страницы = 512К).
;
; ФАЙЛ FT2 (как в памяти, без разбора):
;   16К страница трека | 16К страница инструментов и орнаментов |
;   паттерны по номерам 0..63, что есть в каталоге: роу 0..длина-1 по 112 байт
;   (только данные; текст роу вид строит заново - Song_Reload в patview.asm).
;
; Драйвер - через Disk_Call (коре, srs/diskcall.asm): окна 0/1 у драйвера, имена
; он берёт из памяти тулзы, буферы - в окне 3. Всё под DI - музыка стоит.
; =========================================================================
    MODULE diskview

DV_SCR_H        equ #C0             ; текстовая страница - в окне 3
DV_HEAD_H       equ DV_SCR_H+patview.HD_BUF_LINE    ; буфер шапки (её рисует вид паттерна)
DV_TOP          equ patview.VIEW_LINE               ; первая строка экрана тулзы
DV_LAST         equ 35                              ; последняя видимая строка

; --- рамки
BOX_V           equ #B3             ; │
BOX_H           equ #C4             ; ─
BOX_TL          equ #DA             ; ┌
BOX_TR          equ #BF             ; ┐
BOX_BL          equ #C0             ; └
BOX_BR          equ #D9             ; ┘

; --- каталог (слева)
LS_X            equ 0               ; рамка: колонки 0..49, строки 4..34
LS_W            equ 50
LS_ROW0         equ DV_TOP+1        ; первая строка списка
LS_ROWS         equ 29              ; строк списка
LS_NAME_X       equ 2               ; имя (30 знаков)
LS_NAME_W       equ 30
LS_SIZE_X       equ 33              ; размер (7 знаков) или <DIR>
LS_DATE_X       equ 41              ; дата dd.mm.yy

; --- файл (справа)
FP_X            equ 50              ; рамка: колонки 50..89
FP_W            equ 40
FP_L            equ FP_X+1          ; подписи
FP_V            equ FP_X+6          ; значения (32 знака: 56..87)
NAME_Y          equ DV_TOP+2        ; Name: - поле ввода
NAME_W          equ 30
TYPE_Y          equ DV_TOP+4        ; Type: ... Size: ...
SONG_Y          equ DV_TOP+5        ; Song:
BY_Y            equ DV_TOP+6        ; By:
BTN_Y           equ DV_TOP+8        ; [ Load ]  [ Save ]
LOAD_X          equ FP_L
SAVE_X          equ FP_L+10
BTN_W           equ 8
MSG_Y           equ DV_TOP+10       ; сообщение

; --- запись каталога в PAGE_DIRLIST
DR_FLAG         equ 0               ; 0 - папка, #10 - файл (как отдаёт драйвер)
DR_LEN          equ 1               ; 4 размер
DR_DATE         equ 5               ; 2 дата FAT
DR_NAME         equ 8               ; имя, 0 на конце
DR_NAME_MAX     equ 55
DR_SIZE         equ 64
DR_MAX          equ 248             ; записей: #C000..#FDFF
DL_TMP          equ #FE00           ; окно 3: запись от драйвера (до 13+255 байт):
NX_LEN          equ 4               ;   +0 кластер (4), +4 размер (4), +8 дата, +10 время,
NX_DATE         equ 8
NX_FLAG         equ 12              ;   +12 флаг (0 - папка, #10 - файл), +13 имя, 0
NX_NAME         equ 13
DL_CLUS         equ #FFF0           ; окно 3: кластер текущего каталога (4 байта)
DR_IS_DIR       equ #00             ; DR_FLAG (и проход каталога): папка / файл
DR_IS_FILE      equ #10
FD_DIR          equ #10             ; флаг поиска (FIND, DELETE): папка / файл -
FD_FILE         equ #00             ;   у драйвера он обратный флагу записи
    ASSERT DR_MAX*DR_SIZE <= DL_TMP-#C000

; --- файл трека
FT2_PAT_ROW     equ PAT_DATA_SIZE   ; байт роу паттерна в файле (только данные)
FB_PAGES        equ PAGES_FILEBUF

; --- входы драйвера (drivers/fat32/include/fat32.inc)
DK_SET_CLUS     equ 10              ; HL -> кластер каталога (4): сделать текущим
DK_GET_CLUS     equ 11              ; DE <- кластер текущего каталога
DK_NEXT         equ 29              ; NXTETY: DE <- следующая запись каталога
DK_ENTER        equ 31              ; войти в найденную (FIND) папку
DK_DELETE       equ 75              ; HL -> [флаг, имя, 0]
DK_RENAME       equ 74              ; HL -> [флаг, имя, 0], DE -> [новое имя, 0]

; --- клавиши (PS/2, E0-коды +#80)
KEY_UP          equ #75+#80
KEY_DOWN        equ #72+#80
KEY_PGUP        equ #7D+#80
KEY_PGDN        equ #7A+#80
KEY_HOME        equ #6C+#80
KEY_END         equ #69+#80
KEY_ENTER       equ #5A
KEY_BACK        equ #66
KEY_TAB         equ #0D

    MACRO DV_FIELD x,y,w,h,flags,handler,param
        db x,y,w,h,flags,PAGE_TOOL_DISK
        dw handler,0,param
    ENDM

; =========================================================================
; ВХОД (коре: Tools_Loop -> Call_Tool)
; =========================================================================
Dv_Start
        ld a,(SV_DRAW_PAGE)         ; экран - в окно 3 на всё время работы
        SETPAGE3 a
        call Dv_Head
        call Dv_Clear
        ld a,(Dv_Mounted)           ; карта: первый раз - подключить
        or a
        jr nz,.list
        call Disk_Mount
        jr nz,.nocard
        ld a,1
        ld (Dv_Mounted),a
        ld hl,Dv_Path               ; путь - корень
        ld (hl),'/'
        inc hl
        ld (hl),0
.list   call Dv_List
        jr .fields
.nocard ld hl,Txt_NoCard
        call Dv_Error
.fields ld hl,Dv_Fields
        call Fld_Init
        ld hl,F_List
        call Fld_Set_Focus
        ld a,1
        ld (Dv_Dirty),a

Dv_Loop
        halt
        call Dv_Keys
        call Fld_Update
        ld a,(Dv_Exit)              ; другая вкладка - выходим в коре
        or a
        jr nz,Dv_Leave
        ld a,(Dv_Dirty)
        or a
        call nz,Dv_Draw
        call Dv_Buttons             ; кнопки - каждый кадр (под мышью - подсветка)
        jr Dv_Loop

;-------- Выход в коре (страница следующей тулзы - уже в SV_TOOL)
Dv_Leave
        xor a
        ld (Dv_Exit),a
        call Dv_Clear               ; экран - под вид паттерна
        RESTPAGE3
        ret

; --- состояние
Dv_Mounted      db 0                ; 1 - карта подключена
Dv_Exit         db 0                ; 1 - выйти в коре
Dv_Dirty        db 0                ; 1 - перерисовать экран
Dv_Count        db 0                ; записей в каталоге
Dv_Top          db 0                ; первая видимая запись
Dv_Sel          db 0                ; выбранная запись
Dv_Msg          dw 0                ; сообщение (0 - нет)
Dv_Msg_Clr      db 0                ; его цвет: роль CLR_*
Dv_Msg_Code     db 0                ; код ошибки драйвера (печатается за сообщением)
Dv_Msg_F        db 0                ; флаги драйвера (отладка)
Dv_Msg_Show     db 0                ; отладка: 1 - строка "list .. find .."
Dv_Path         ds 120              ; путь от корня, "/" в конце
DV_PATH_MAX     equ 118
Dv_Name         ds NAME_W+1         ; поле Name: имя файла (под него и сохраняем)
Dv_Name_Len     db 0
Dv_Type         dw 0                ; тип выбранного файла: строка
Dv_Song         ds 33               ; Song / By из файла
Dv_By           ds 33
Dv_Len          ds 4                ; размер выбранного файла

; =========================================================================
; ЭКРАН
; =========================================================================
;-------- Шапка: её буфер (рисует вид паттерна) - в строки 0..3, один раз
Dv_Head
        ld hl,DV_HEAD_H*256
        ld de,DV_SCR_H*256
        ld bc,DV_TOP*256
        ldir
        ld a,(THEME_ATTR+CLR_TOP_TEXT)  ; вкладки: Pattern - обычная, Disk - выбрана
        ld hl,DV_TAB_PAT
        ld b,7
        call .attr
        ld a,(THEME_ATTR+CLR_TOP_HI)
        ld hl,DV_TAB_DISK
        ld b,4
; B атрибутов A с адреса HL
.attr   ld (hl),a
        inc l
        djnz .attr
        ret
DV_TAB_PAT      equ DV_SCR_H*256+128+patview.HD_TABS_X      ; атрибут вкладки Pattern
DV_TAB_DISK     equ DV_TAB_PAT+21                           ;   и Disk

;-------- Строки DV_TOP..DV_LAST: пробелы цветом фона
Dv_Clear
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld d,DV_SCR_H+DV_TOP
.r      ld e,0
.s      ld a,' '
        call PutCh
        bit 7,e
        jr z,.s
        inc d
        ld a,d
        cp DV_SCR_H+DV_LAST+1
        jr c,.r
        ret

;-------- Весь экран тулзы: рамки, каталог, файл
Dv_Draw
        xor a
        ld (Dv_Dirty),a
        call Dv_Frames
        call Dv_Draw_List
        jp Dv_Draw_File

;-------- Рамки: каталог (в заголовке - путь), файл
Dv_Frames
        ld a,LS_X
        ld (Bx_X),a
        ld a,LS_W
        ld (Bx_W),a
        call Dv_Box
        ld hl,(SV_FOCUS)            ; путь - ярче, когда список в фокусе
        ld de,F_List
        or a
        sbc hl,de
        ld a,(THEME_ATTR+CLR_HEADER)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld de,LS_X+2+256*(DV_SCR_H+DV_TOP)
        call Dv_Path_Tail
        call PutStr
        ld a,FP_X
        ld (Bx_X),a
        ld a,FP_W
        ld (Bx_W),a
        call Dv_Box
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FP_X+2+256*(DV_SCR_H+DV_TOP)
        ld hl,Txt_File
        jp PutStr

; Рамка: колонка Bx_X, ширина Bx_W, строки DV_TOP..DV_LAST-1. Внутри - пробелы
Bx_X            db 0
Bx_W            db 0
Dv_Box
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld d,DV_SCR_H+DV_TOP        ; верх ┌──┐
        ld a,BOX_TL
        ld b,BOX_TR
        call .line
        ld d,DV_SCR_H+DV_LAST-1     ; низ └──┘
        ld a,BOX_BL
        ld b,BOX_BR
        call .line
        ld d,DV_SCR_H+DV_TOP+1      ; бока, внутри - пробелы
.side   ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,(Bx_X)
        ld e,a
        ld a,BOX_V
        call PutCh
        ld a,(THEME_ATTR+CLR_BG)
        ld c,a
        ld a,(Bx_W)
        sub 2
        ld b,a
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld a,(THEME_ATTR+CLR_TITLE)
        ld c,a
        ld a,BOX_V
        call PutCh
        inc d
        ld a,d
        cp DV_SCR_H+DV_LAST-1
        jr c,.side
        ret
; Линия рамки: A - левый угол, B - правый, D - строка
.line   push bc
        push af
        ld a,(Bx_X)
        ld e,a
        pop af
        call PutCh
        ld a,(Bx_W)
        sub 2
        ld b,a
.h      ld a,BOX_H
        call PutCh
        djnz .h
        pop bc
        ld a,b
        jp PutCh

; HL - конец пути, который влезает в заголовок рамки (последние 44 знака)
DV_PATH_SHOW    equ LS_W-6
Dv_Path_Tail
        ld hl,Dv_Path
        call Str_Len                ; A - длина
        sub DV_PATH_SHOW
        ret c
        ret z
        jp Hl_Add_A

;-------- Каталог: LS_ROWS строк с записи Dv_Top, выбранная - курсором
Dv_Draw_List
        ld a,PAGE_DIRLIST           ; записи - в окно 2
        SETPAGE2 a
        ld a,(Dv_Top)
        ld (Dl_Idx),a
        ld d,DV_SCR_H+LS_ROW0
.row    push de
        call Dv_List_Row
        pop de
        ld hl,Dl_Idx
        inc (hl)
        inc d
        ld a,d
        cp DV_SCR_H+LS_ROW0+LS_ROWS
        jr c,.row
        RESTPAGE2
        ret

Dl_Idx          db 0

; Строка D: запись Dl_Idx (за концом - пустая). Каталог - в окне 2
Dv_List_Row
        ld e,LS_X+1
        ld a,(Dl_Idx)
        ld hl,Dv_Count
        cp (hl)
        jp nc,.empty
        call Dl_Ofs                 ; запись
        ld a,h
        or #80
        ld h,a
        ld (Dl_Rec),hl
        ld a,(hl)                   ; цвет строки: папка - ярче
        cp DR_IS_DIR
        ld a,(THEME_ATTR+CLR_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        ld a,(Dl_Idx)               ; выбранная - курсором (список в фокусе - ярким)
        ld hl,Dv_Sel
        cp (hl)
        jr nz,.fill
        ld hl,(SV_FOCUS)
        push de
        ld de,F_List
        or a
        sbc hl,de
        pop de
        ld a,(THEME_ATTR+CLR_CURSOR)
        jr z,$+5
        ld a,(THEME_ATTR+CLR_SELECT)
        ld c,a
.fill   ld b,LS_W-2                 ; фон строки
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld e,LS_NAME_X              ; имя, не длиннее LS_NAME_W
        ld hl,(Dl_Rec)
        ld bc,DR_NAME
        add hl,bc
        ld b,LS_NAME_W
.nm     ld a,(hl)
        or a
        jr z,.size
        ld (de),a
        inc e
        inc hl
        djnz .nm
.size   ld hl,(Dl_Rec)              ; папка - <DIR>, файл - размер
        ld a,(hl)
        or a
        jr nz,.file
        ld e,LS_SIZE_X
        ld hl,Txt_Dir
        call Dv_StrKeep
        jr .date
.file   inc hl                      ; DR_LEN
        push de                     ; D - строка экрана (Nm_* портят DE)
        call Nm_Load32
        call Nm_Dec7
        pop de
        ld e,LS_SIZE_X
        ld hl,Nm_Buf
        call Dv_StrKeep
.date   ld hl,(Dl_Rec)              ; дата
        ld bc,DR_DATE
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h                        ; даты нет - пусто
        ret z
        call Nm_Date
        ld e,LS_DATE_X
        ld hl,Nm_Buf
        jp Dv_StrKeep
.empty  ld a,(THEME_ATTR+CLR_TEXT)
        ld c,a
        ld b,LS_W-2
.esp    ld a,' '
        call PutCh
        djnz .esp
        ret

Dl_Rec          dw 0

; Строка HL (0 на конце) в DE, атрибуты не трогаем
Dv_StrKeep
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc e
        inc hl
        jr Dv_StrKeep

;-------- Файл: Name (поле ввода), тип, размер, Song, By, сообщение
Dv_Draw_File
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FP_L+256*(DV_SCR_H+NAME_Y)
        ld hl,Txt_Name
        call PutStr
        ld de,FP_L+256*(DV_SCR_H+TYPE_Y)
        ld hl,Txt_Type
        call PutStr
        ld de,FP_L+256*(DV_SCR_H+SONG_Y)
        ld hl,Txt_Song
        call PutStr
        ld de,FP_L+256*(DV_SCR_H+BY_Y)
        ld hl,Txt_By
        call PutStr
        call Dv_Draw_Name
        ld a,(THEME_ATTR+CLR_TEXT)  ; тип, размер
        ld c,a
        ld de,FP_V+256*(DV_SCR_H+TYPE_Y)
        ld hl,(Dv_Type)
        ld a,h
        or l
        jr z,.song
        call PutStr
        ld de,FP_V+6+256*(DV_SCR_H+TYPE_Y)
        ld hl,Txt_Size
        call PutStr
        push de                     ; DE - экран (Nm_* портят DE)
        ld hl,Dv_Len
        call Nm_Load32
        call Nm_Dec7
        pop de
        ld hl,Nm_Buf
        call PutStr
.song   ld de,FP_V+256*(DV_SCR_H+SONG_Y)
        ld hl,Dv_Song
        call PutStr
        ld de,FP_V+256*(DV_SCR_H+BY_Y)
        ld hl,Dv_By
        call PutStr
        ld hl,(Dv_Msg)              ; сообщение
        ld a,h
        or l
        ret z
        ld a,(Dv_Msg_Clr)
        add a,low THEME_ATTR
        ld e,a
        ld d,high THEME_ATTR
        ld a,(de)
        ld c,a
        ld de,FP_L+256*(DV_SCR_H+MSG_Y)
        call PutStr
        ld a,(Dv_Msg_Show)          ; отладка: A и флаги листинга, A и флаги поиска
        or a
        jr z,.code
        ld de,FP_L+256*(DV_SCR_H+MSG_Y+1)
        ld hl,Txt_DbgList
        call PutStr
        ld hl,(Dl_Dbg)
        call .af
        ld hl,Txt_DbgFind
        call PutStr
        ld hl,(Dl_Dbg2)
        call .af
        ld de,FP_L+256*(DV_SCR_H+MSG_Y+2)  ; дамп
        ld hl,Dl_Dump
        ld b,16
.dmp    ld a,(hl)
        push hl
        push bc
        call PutHex2
        pop bc
        pop hl
        inc hl
        ld a,b
        cp 5                        ; CGPZ, CGFL - через пробел
        jr nz,.nsp
        ld a,' '
        call PutCh
.nsp    djnz .dmp
        ret
.af     ld a,h
        push hl
        call PutHex2
        ld a,' '
        call PutCh
        pop hl
        ld a,l
        jp PutHex2
.code   ld a,(Dv_Msg_Code)          ; код ошибки драйвера
        or a
        ret z
        jp PutHex2

;-------- Поле Name: текст на фоне поля ввода, в фокусе - курсор "_"
Dv_Draw_Name
        ld a,(THEME_ATTR+CLR_EDIT_ROW)
        ld c,a
        ld de,FP_V+256*(DV_SCR_H+NAME_Y)
        ld b,NAME_W
.sp     ld a,' '
        call PutCh
        djnz .sp
        ld de,FP_V+256*(DV_SCR_H+NAME_Y)
        ld hl,Dv_Name
        call PutStr
        ld hl,(SV_FOCUS)
        push de
        ld de,F_Name
        or a
        sbc hl,de
        pop de
        ret nz
        ld a,(Dv_Name_Len)
        cp NAME_W
        ret nc
        ld a,'_'
        jp PutCh

;-------- Кнопки Load / Save: под мышью - подсветка, держат - "нажата" (цвет курсора)
Dv_Buttons
        ld ix,F_Load
        ld de,LOAD_X+256*(DV_SCR_H+BTN_Y)
        ld hl,Txt_Load
        call .one
        ld ix,F_Save
        ld de,SAVE_X+256*(DV_SCR_H+BTN_Y)
        ld hl,Txt_Save
.one    push hl
        push ix                     ; цвет: нажата / под мышью / обычная
        pop hl
        ld bc,(SV_HOVER)
        or a
        sbc hl,bc
        ld a,(THEME_ATTR+CLR_HEAD_TEXT)
        jr nz,.put
        push ix
        pop hl
        ld bc,(SV_PRESSED)
        or a
        sbc hl,bc
        ld a,(THEME_ATTR+CLR_HOVER)
        jr nz,.put
        ld a,(THEME_ATTR+CLR_CURSOR)
.put    ld c,a
        pop hl
        jp PutStr

; =========================================================================
; ПОЛЯ
; =========================================================================
Dv_Fields
        DV_FIELD 0,0,90,DV_TOP, FF_HAND, Dv_TabPat, 0                   ; шапка: клик - назад к паттерну
F_List  DV_FIELD LS_X+1,LS_ROW0,LS_W-2,LS_ROWS, FF_FOCUS, Dv_ListEv, 0  ; каталог
F_Name  DV_FIELD FP_V,NAME_Y,NAME_W,1, FF_FOCUS|FF_HAND, Dv_NameEv, 0   ; имя файла
F_Load  DV_FIELD LOAD_X,BTN_Y,BTN_W,1, FF_HAND, Dv_BtnEv, 0              ; Load
F_Save  DV_FIELD SAVE_X,BTN_Y,BTN_W,1, FF_HAND, Dv_BtnEv, 1              ; Save
        db FLD_END

;-------- Клик в шапку (вкладки, мимо экрана диска): назад в вид паттерна
Dv_TabPat
        cp EV_CLICK
        ret nz
        ld a,PAGE_TOOL_PATVIEW
        ld (SV_TOOL),a
        ld a,1
        ld (Dv_Exit),a
        ret

;-------- Кнопки: Load - открыть выбранную запись, Save - сохранить под Name
Dv_BtnEv
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)
        or a
        jp z,Dv_Open
        jp Dv_Save

;-------- Каталог: клик - выбрать, двойной - открыть, колесо, клавиши
Dv_ListEv
        cp EV_PRESS
        jr z,.press
        cp EV_DOUBLE
        jp z,Dv_Open
        cp EV_WHEEL
        jr z,.wheel
        cp EV_KEY
        jr z,.key
        cp EV_FOCUS_IN
        jr z,.focus
        cp EV_FOCUS_OUT
        ret nz
.focus  ld a,1                      ; курсор и путь - другим цветом
        ld (Dv_Dirty),a
        ret
.press  ld a,(SV_MOUSE_ROW)         ; строка -> запись
        sub LS_ROW0
        ld hl,Dv_Top
        add a,(hl)
        ld hl,Dv_Count
        cp (hl)
        ret nc
        jp Dv_Select
.wheel  ld a,c                      ; вниз (C < 0) - следующая
        or a
        jp m,Dv_Next
        jp Dv_Prev
.key    ld hl,List_Keys
        jp Keys_Table

List_Keys
        db KEY_UP,   0
        dw Dv_Prev
        db KEY_DOWN, 0
        dw Dv_Next
        db KEY_PGUP, 0
        dw Dv_PgUp
        db KEY_PGDN, 0
        dw Dv_PgDn
        db KEY_HOME, 0
        dw Dv_Home
        db KEY_END,  0
        dw Dv_End
        db KEY_ENTER,0
        dw Dv_Open
        db KEY_BACK, 0
        dw Dv_Parent
        db 0

Dv_Prev ld a,(Dv_Sel)
        or a
        ret z
        dec a
        jp Dv_Select
Dv_Next ld a,(Dv_Sel)
        inc a
        ld hl,Dv_Count
        cp (hl)
        ret nc
        jp Dv_Select
Dv_PgUp ld a,(Dv_Sel)
        sub LS_ROWS
        jr nc,$+3
        xor a
        jp Dv_Select
Dv_PgDn ld a,(Dv_Sel)
        add a,LS_ROWS
        jr c,Dv_End
        ld hl,Dv_Count
        cp (hl)
        jp c,Dv_Select
Dv_End  ld a,(Dv_Count)
        or a
        ret z
        dec a
        jp Dv_Select
Dv_Home xor a
        jp Dv_Select

;-------- Выбрать запись A: курсор виден, имя - в поле Name, сведения о файле
Dv_Select
        ld (Dv_Sel),a
        ld hl,Dv_Top                ; выше видимых - список вверх
        cp (hl)
        jr nc,.below
        ld (hl),a
        jr .info
.below  sub LS_ROWS-1               ; ниже - вниз
        jr c,.info
        cp (hl)
        jr c,.info
        ld (hl),a
.info   ld a,1
        ld (Dv_Dirty),a
        call Dv_Clear_Info
        ld a,(Dv_Count)
        or a
        ret z
        ld a,(Dv_Sel)               ; запись - в Dv_Spec (флаг, имя)
        call Dv_Spec_Rec
        ld a,(Dv_Spec)              ; папка - сведений нет
        cp FD_DIR
        ret z
        ld hl,Dv_Spec+1             ; файл: имя - в поле Name
        ld de,Dv_Name
        ld b,NAME_W
        ld c,0
.cp     ld a,(hl)
        or a
        jr z,.cpe
        ld (de),a
        inc hl
        inc de
        inc c
        djnz .cp
.cpe    xor a
        ld (de),a
        ld a,c
        ld (Dv_Name_Len),a
        jp Dv_File_Info

; Сведения о выбранном - пустые
Dv_Clear_Info
        ld hl,0
        ld (Dv_Type),hl
        xor a
        ld (Dv_Song),a
        ld (Dv_By),a
        ret

;-------- Поле Name: буквы, цифры, точка, минус / подчёркивание; Backspace; Enter - Save
Dv_NameEv
        cp EV_FOCUS_IN
        jr z,.focus
        cp EV_FOCUS_OUT
        jr z,.focus
        cp EV_KEY
        ret nz
        ld a,b
        cp KEY_ENTER
        jr z,.save
        cp KEY_BACK
        jr z,.back
        cp KEY_TAB                  ; Tab - не наш (фокус - в Dv_Keys)
        ret z
        or a                        ; E0-коды - не буквы (CF = 0: не наша)
        ret m
        ld h,high Dv_Chars          ; код -> символ (0 - не символ)
        ld l,a
        ld a,(hl)
        or a
        ret z
        bit 0,c                     ; Shift: буквы - заглавные, минус - подчёркивание
        jr z,.put
        cp '-'
        jr nz,.up
        ld a,'_'
        jr .put
.up     cp 'a'
        jr c,.put
        cp 'z'+1
        jr nc,.put
        sub 'a'-'A'
.put    ld b,a
        ld a,(Dv_Name_Len)
        cp NAME_W
        jr nc,.eat
        ld hl,Dv_Name
        call Hl_Add_A
        ld (hl),b
        inc hl
        ld (hl),0
        ld hl,Dv_Name_Len
        inc (hl)
        jr .focus
.back   ld a,(Dv_Name_Len)
        or a
        jr z,.eat
        dec a
        ld (Dv_Name_Len),a
        ld hl,Dv_Name
        call Hl_Add_A
        ld (hl),0
        jr .focus
.save   call Dv_Save
.focus  ld a,1
        ld (Dv_Dirty),a
.eat    scf                         ; клавиша - наша
        ret

;-------- Клавиши: полю в фокусе; Tab - фокус каталог <-> Name
Dv_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld b,a
        push bc
        call Fld_Key
        pop bc
        jr c,.k
        ld a,b
        cp KEY_TAB
        jr nz,.k
        ld hl,(SV_FOCUS)
        ld de,F_List
        or a
        sbc hl,de
        ld hl,F_Name
        jr z,$+5
        ld hl,F_List
        call Fld_Set_Focus
        jr .k

; =========================================================================
; КАТАЛОГ
; =========================================================================
;-------- Прочитать текущий каталог: сначала папки, потом файлы. "." - не берём
Dl_Want         db 0                ; какой флаг берём в этом проходе

Dv_List
        xor a
        ld (Dv_Count),a
        ld (Dv_Top),a
        ld (Dv_Sel),a
        ld a,PAGE_DIRLIST           ; записи - в окне 3 (там же ждёт буфер драйвер)
        SETPAGE3 a
        ld ix,DK_GET_CLUS           ; кластер каталога - чтобы читать его дважды
        ld de,DL_CLUS
        call Disk_Call
        ld a,DR_IS_DIR
        call Dl_Pass
        ld a,DR_IS_FILE
        call Dl_Pass
        RESTPAGE3
        ld a,1                      ; курсор - на первой, поле Name не трогаем
        ld (Dv_Dirty),a
        call Dv_Clear_Info
        ld a,(Dv_Count)             ; отладка: пусто - что вернул драйвер (A, флаги)
        or a
        ret nz
        ld ix,DK_FIND+256           ; и поиск TMPFT по имени: A, флаги
        ld hl,Spec_TmpFT
        call Disk_Call
        push af
        pop hl
        ld (Dl_Dbg2),hl
        ld hl,Txt_Empty
        call Dv_Error
        ld hl,(Dl_Dbg)
        ld a,h
        ld (Dv_Msg_Code),a
        ld a,l
        ld (Dv_Msg_F),a
        ld a,1                      ; код печатаем всегда
        ld (Dv_Msg_Show),a
        ld a,PAGE_FAT_WORK          ; буфер каталога драйвера (#0000) и CGFL / CGPZ (#37FC)
        SETPAGE3 a
        ld hl,#C000
        ld de,Dl_Dump
        ld bc,12
        ldir
        ld hl,#C000+#37FC
        ld bc,4
        ldir
        RESTPAGE3
        ret

Dl_Dump         ds 16               ; отладка: 12 байт буфера + CGPZ, CGFL

Spec_TmpFT      db FD_DIR,"TMPFT",0
Dl_Dbg2         dw 0                ; отладка: AF поиска TMPFT

Dl_Dbg          dw 0                ; отладка: AF последнего NXTETY

; Проход по каталогу с начала: записи с флагом A - в список
Dl_Pass
        ld (Dl_Want),a
        ld ix,DK_SET_CLUS           ; с начала каталога
        ld hl,DL_CLUS
        call Disk_Call
.next   ld a,(Dv_Count)
        cp DR_MAX
        ret nc
        ld ix,DK_NEXT               ; следующая запись
        ld de,DL_TMP
        call Disk_Call
        push af                     ; отладка: что вернул драйвер
        pop hl
        ld (Dl_Dbg),hl
        ret z                       ; конец каталога
        cp 1                        ; не 1 - конец цепочки или ошибка
        ret nz
        ld a,(Dl_Want)
        ld hl,DL_TMP+NX_FLAG
        cp (hl)
        jr nz,.next
        ld hl,DL_TMP+NX_NAME        ; "." - не берём
        ld a,(hl)
        cp '.'
        jr nz,.keep
        inc hl
        ld a,(hl)
        or a
        jr z,.next
.keep   ld a,(Dv_Count)             ; запись: флаг, размер, дата, имя
        call Dl_Ofs
        ld a,h
        or #C0
        ld h,a
        ex de,hl
        ld a,(DL_TMP+NX_FLAG)
        ld (de),a                   ; DR_FLAG
        inc de
        ld hl,DL_TMP+NX_LEN         ; DR_LEN, потом DR_DATE
        ld bc,4
        ldir
        ld bc,2                     ; DR_DATE
        ldir
        inc de                      ; +7 - резерв
        ld hl,DL_TMP+NX_NAME        ; DR_NAME, не длиннее DR_NAME_MAX
        ld b,DR_NAME_MAX
.nm     ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .nm
.end    xor a
        ld (de),a
        ld hl,Dv_Count
        inc (hl)
        jr .next

; A - номер записи -> HL - её смещение в странице каталога (A*64)
Dl_Ofs
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ret

;-------- Запись A -> Dv_Spec: флаг поиска (FD_*), имя, 0 - так её ищет драйвер
Dv_Spec         ds 1+DR_NAME_MAX+1

Dv_Spec_Rec
        ld (Dl_Idx),a
        ld a,PAGE_DIRLIST
        SETPAGE2 a
        ld a,(Dl_Idx)
        call Dl_Ofs
        ld a,h
        or #80
        ld h,a
        ld a,(hl)                   ; флаг записи -> флаг поиска
        xor DR_IS_FILE^FD_FILE
        ld (Dv_Spec),a
        ld bc,DR_LEN                ; размер - в сведения
        add hl,bc
        ld de,Dv_Len
        ld bc,4
        ldir
        ld bc,DR_NAME-DR_LEN-4
        add hl,bc
        ld de,Dv_Spec+1
        ld bc,DR_NAME_MAX+1
        ldir
        RESTPAGE2
        ret

;-------- Открыть выбранное: папка - войти, файл - загрузить
Dv_Open
        ld a,(Dv_Count)
        or a
        ret z
        ld a,(Dv_Sel)
        call Dv_Spec_Rec
        ld a,(Dv_Spec)
        cp FD_DIR
        jp nz,Dv_Load
        ld hl,Dv_Spec               ; найти папку и войти
        call Dv_Find
        ret c
        ld ix,DK_ENTER
        call Disk_Call
        jp c,Dv_Disk_Err
        ld hl,Dv_Spec+1             ; ".." - путь короче, иначе - имя в путь
        ld a,(hl)
        cp '.'
        jr nz,.add
        inc hl
        ld a,(hl)
        cp '.'
        jr nz,.add
        call Path_Up
        jp Dv_List
.add    call Path_Add
        jp Dv_List

;-------- Backspace в каталоге: в папку выше (в корне - ничего)
Dv_Parent
        ld a,(Dv_Path+1)            ; "/" - корень
        or a
        ret z
        ld hl,Spec_Up
        call Dv_Find
        ret c
        ld ix,DK_ENTER
        call Disk_Call
        jp c,Dv_Disk_Err
        call Path_Up
        jp Dv_List

Spec_Up         db FD_DIR,"..",0

;-------- Найти запись HL -> [флаг, имя, 0]. CF - нет или ошибка (сообщение уже
; стоит), иначе DE:HL - размер
Dv_Find
        ld ix,DK_FIND+256           ; одно имя
        call Disk_Call
        jp c,Dv_Disk_Err
        ret nz                      ; найдено (CF = 0)
        ld hl,Txt_NotFound
        call Dv_Error
        scf
        ret

; Путь: + имя из Dv_Spec и "/" (не влезает - путь не меняем, только видно хуже)
Path_Add
        ld hl,Dv_Path
        call Str_Len
        ld c,a
        ld hl,Dv_Spec+1
        call Str_Len
        add a,c
        cp DV_PATH_MAX
        ret nc
        ld hl,Dv_Path
        ld a,c
        call Hl_Add_A
        ex de,hl
        ld hl,Dv_Spec+1
.c      ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .c
.e      ld a,'/'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; Путь: без последней папки ("/a/b/" -> "/a/")
Path_Up
        ld hl,Dv_Path
        call Str_Len
        cp 2
        ret c
        sub 2                       ; с предпоследнего знака назад - до "/"
        ld hl,Dv_Path
        call Hl_Add_A
.b      ld a,(hl)
        cp '/'
        jr z,.cut
        dec hl
        jr .b
.cut    inc hl
        ld (hl),0
        ret

;-------- Сведения о файле Dv_Spec: тип по расширению; FT2, PT3 - Song / By из файла
Dv_File_Info
        call Dv_Ext                 ; A - тип: 1 FT2, 2 PT3, 3 PT2, 0 - другой
        or a
        jr nz,.known
        ld hl,Txt_Other
        ld (Dv_Type),hl
        ret
.known  ld (Fi_Type),a
        dec a
        add a,a
        ld hl,Fi_Names
        call Hl_Add_A
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (Dv_Type),hl
        ld a,(Fi_Type)
        cp 3                        ; PT2 - имени не читаем
        ret nc
        ld hl,Dv_Spec               ; первый сектор файла - в буфер файла
        call Dv_Find
        ret c
        ld a,PAGE_FILEBUF
        SETPAGE3 a
        ld ix,DK_READ
        ld hl,#C000
        ld b,1
        call Disk_Call
        jr c,.out
        ld a,(Fi_Type)              ; где имя и автор
        cp 1
        ld hl,#C000+SH_NAME
        ld de,#C000+SH_AUTHOR
        jr z,.copy
        ld hl,#C000+30              ; PT3: +30 имя, +66 автор
        ld de,#C000+66
.copy   push de
        ld de,Dv_Song
        call .str
        pop hl
        ld de,Dv_By
        call .str
.out    RESTPAGE3
        ret
; 32 знака HL -> DE, хвостовые пробелы и нули - конец
.str    ld bc,32
        ldir
        xor a
        ld (de),a
        ld b,32
.trim   dec de
        ld a,(de)
        cp ' '+1
        ret nc
        xor a
        ld (de),a
        djnz .trim
        ret

Fi_Type         db 0
Fi_Names        dw Txt_FT2,Txt_PT3,Txt_PT2

; Расширение имени Dv_Spec -> A: 1 FT2, 2 PT3, 3 PT2, 0 - другое
Dv_Ext
        ld hl,Dv_Spec+1             ; последняя точка
        ld de,0
.f      ld a,(hl)
        or a
        jr z,.got
        cp '.'
        jr nz,$+4
        ld d,h
        ld e,l
        inc hl
        jr .f
.got    ld a,d
        or e
        ret z                       ; точки нет
        ex de,hl
        inc hl
        ld de,Ext_FT2
        call Ext_Cmp
        ld a,1
        ret z
        ld de,Ext_PT3
        call Ext_Cmp
        ld a,2
        ret z
        ld de,Ext_PT2
        call Ext_Cmp
        ld a,3
        ret z
        xor a
        ret

; Расширение HL (без учёта регистра) = DE (3 знака, строчные)? Z - да. HL цел
Ext_Cmp
        push hl
        ld b,3
.c      ld a,(hl)
        or #20                      ; в строчные (у цифр бит 5 и так есть)
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.no
        inc hl
        inc de
        djnz .c
        ld a,(hl)                   ; дальше - конец имени
        or a
.no     pop hl
        ret

Ext_FT2         db "ft2"
Ext_PT3         db "pt3"
Ext_PT2         db "pt2"

; =========================================================================
; ЗАГРУЗКА И СОХРАНЕНИЕ FT2
; =========================================================================
;-------- Загрузить файл Dv_Spec в трек 1: FT2 - как есть, PT3 - импорт (srs/pt3imp.asm)
Dv_Load
        call Dv_Ext
        ld (Ld_Kind),a
        cp 1
        jr z,.kind
        cp 2
        jr z,.kind
        ld hl,Txt_CantLoad
        jp Dv_Error
.kind   ld hl,Dv_Spec
        call Dv_Find
        ret c
        ld (Ld_Size),hl
        ld (Ld_Size+2),de
        ld a,d                      ; размер: не меньше двух страниц, не больше буфера
        or a
        jr nz,.big
        ld a,e
        cp FB_PAGES/4
        jr c,.fits
        jr nz,.big
        ld a,h
        or l
        jr z,.fits
.big    ld hl,Txt_TooBig
        jp Dv_Error
.fits   ld a,(Ld_Kind)              ; PT3 - хотя бы заголовок и ордер
        cp 2
        jr nz,.ft2min
        ld a,e
        or h
        jr nz,.pages
        ld a,l
        cp PT_ORDER+1
        jr nc,.pages
        ld hl,Txt_BadPt3
        jp Dv_Error
.ft2min ld a,e                      ; FT2 - хотя бы две страницы
        or a
        jr nz,.pages
        ld a,h
        cp #80
        jr nc,.pages
        ld hl,Txt_NotFT2
        jp Dv_Error
.pages  ld a,e                      ; страниц = размер / 16К с округлением вверх
        add a,a
        add a,a
        ld b,a
        ld a,h
        rlca
        rlca
        and 3
        add a,b
        ld b,a
        ld a,h
        and #3F
        or l
        jr z,$+3
        inc b
        ld a,b
        ld (Ld_Pages),a
        ld a,PC_STOP                ; плеер - стоп: страницы трека сейчас перепишем
        ld (SV_PLAY_CMD),a
        halt
        halt
        call Tr_Normal              ; кнопки транспорта - не горят
        xor a                       ; файл - в буфер, по странице
        ld (Ld_Page),a
.read   ld a,(Ld_Page)
        add a,PAGE_FILEBUF
        SETPAGE3 a
        ld ix,DK_READ
        ld hl,#C000
        ld b,32
        call Disk_Call
        ld (Ld_Res),a
        sbc a,a                     ; CF -> память: RESTPAGE портит флаги
        ld (Ld_Err),a
        RESTPAGE3
        ld a,(Ld_Err)
        or a
        jr nz,.err
        ld hl,Ld_Page
        inc (hl)
        ld a,(Ld_Res)               ; A <> 0 (без CF) - цепочка кончилась
        or a
        jr nz,.check
        ld a,(Ld_Pages)
        cp (hl)
        jr nz,.read
.check  ld a,(Ld_Kind)              ; PT3 - импорт
        cp 2
        jp z,Pt_Import
        ld a,PAGE_FILEBUF           ; подпись трека
        SETPAGE3 a
        ld hl,(#C000+SH_SIGN)
        ld de,(#C000+SH_SIGN+2)
        RESTPAGE3
        ld bc,"F"+"T"*256
        or a
        sbc hl,bc
        jr nz,.bad
        ex de,hl
        ld bc,"2"+"S"*256
        sbc hl,bc
        jr z,Ld_Unpack
.bad    ld hl,Txt_NotFT2
        jp Dv_Error
.err    ld a,(Ld_Res)
        jp Dv_Disk_Code

Ld_Kind         db 0                ; 1 FT2, 2 PT3 (Dv_Ext)
Ld_Size         ds 4                ; размер файла
Ld_Pages        db 0                ; страниц в файле
Ld_Page         db 0                ; прочитано страниц
Ld_Res          db 0
Ld_Err          db 0

;-------- Буфер файла -> трек: страница трека, инструменты, паттерны
Ld_Unpack
        ld a,PAGE_FILEBUF           ; страница трека
        ld (Pg_File),a
        ld a,PAGE_SONG1
        ld (Pg_Mem),a
        call Pg_Get
        ld a,PAGE_FILEBUF+1         ; инструменты и орнаменты
        ld (Pg_File),a
        ld a,PAGE_INS1
        ld (Pg_Mem),a
        call Pg_Get
        call Cat_Get                ; каталог паттернов: страницы - на наши места
        ld a,PAGE_FILEBUF+2         ; паттерны - потоком
        ld (Fs_Page),a
        ld hl,#C000
        ld (Fs_Ptr),hl
        xor a
        ld (Cat_N),a
.pat    call Cat_Len                ; A - длина, Z - паттерна нет
        jr z,.next
        ld (Cat_Rows),a
        ld a,(Cat_N)
        add a,patview.PAT_PAGE
        SETPAGE2 a
        call Pat_Zero               ; данные всех роу - 0 (за длиной тоже)
        ld de,#8000                 ; роу 0..длина-1
.row    push de
        ld bc,FT2_PAT_ROW
        call Fs_Read
        pop de
        inc d
        ld hl,Cat_Rows
        dec (hl)
        jr nz,.row
        RESTPAGE2
.next   ld hl,Cat_N
        inc (hl)
        ld a,(hl)
        cp PATTERNS_MAX
        jr c,.pat
        ld a,1                      ; вид паттерна перечитает трек при входе
        ld (SV_SONG_NEW),a
        ld hl,Txt_Loaded
        jp Dv_Ok

; Данные роу 0..63 паттерна в окне 2 - нули
Pat_Zero
        ld h,#80
.r      ld l,0
.z      ld (hl),0
        inc l
        ld a,l
        cp FT2_PAT_ROW
        jr c,.z
        inc h
        ld a,h
        cp #80+PAT_ROWS_MAX
        jr c,.r
        ret

;-------- Каталог паттернов трека -> Dv_Cat; страницы в треке - PAT_PAGE+n (так их
; ждёт вид паттерна), страница инструментов - PAGE_INS1
Dv_Cat          ds PATTERNS_MAX*PC_SIZE
Cat_N           db 0                ; номер паттерна
Cat_Rows        db 0

Cat_Get
        ld a,PAGE_SONG1
        SETPAGE2 a
        ld hl,#8000+PAT_CATALOG
        ld de,Dv_Cat
        ld bc,PATTERNS_MAX*PC_SIZE
        ldir
        ld hl,#8000+PAT_CATALOG
        ld b,0                      ; B - номер паттерна
.p      ld a,(hl)
        or a
        jr z,.n
        ld a,b
        add a,patview.PAT_PAGE
        ld (hl),a
.n      inc hl
        inc hl
        inc b
        ld a,b
        cp PATTERNS_MAX
        jr c,.p
        ld a,PAGE_INS1
        ld (#8000+SH_INS_PAGE),a
        RESTPAGE2
        ret

; Паттерн Cat_N: Z - его нет, иначе A - длина (0 - 64)
Cat_Len
        ld a,(Cat_N)
        add a,a
        ld hl,Dv_Cat
        call Hl_Add_A
        ld a,(hl)                   ; PC_PAGE
        or a
        ret z
        inc hl
        ld a,(hl)                   ; PC_LEN
        or a
        jr nz,.ok
        ld a,PAT_ROWS_MAX
.ok     or a
        ret

;-------- Сохранить трек 1 под именем из поля Name (нет точки - добавим .ft2)
Dv_Save
        ld a,(Dv_Mounted)
        or a
        ret z
        ld a,(Dv_Name_Len)
        or a
        jr nz,.name
        ld hl,Txt_NoName
        jp Dv_Error
.name   call Name_Ext
        call Sv_Pack                ; трек -> буфер файла
        ld hl,Dv_Spec               ; такой файл есть? - пишем во временный
        ld (hl),FD_FILE
        ld hl,Dv_Name
        ld de,Dv_Spec+1
        ld bc,NAME_W+1
        ldir
        ld ix,DK_FIND+256
        ld hl,Dv_Spec
        call Disk_Call
        jp c,Dv_Disk_Err
        ld a,0
        jr z,$+4
        ld a,1
        ld (Sv_Repl),a
        ld hl,Dv_Name               ; имя, под которым создаём
        jr z,$+5
        ld hl,Txt_TmpName
        ld de,Sv_Spec+5
        ld bc,NAME_W+1
        ldir
        ld ix,DK_CREATE+256
        ld hl,Sv_Spec
        call Disk_Call
        jp nz,Dv_Disk_Err
        xor a                       ; страницы буфера - на диск
        ld (Ld_Page),a
.page   ld a,(Ld_Page)
        ld hl,Sv_Full
        cp (hl)
        jr nc,.last
        ld hl,#4000
        call Sv_Append
        ret c
        ld hl,Ld_Page
        inc (hl)
        jr .page
.last   ld hl,(Sv_Tail)             ; хвост - неполная страница
        ld a,h
        or l
        call nz,Sv_Append
        ret c
        ld ix,DK_CLOSE
        call Disk_Call
        jp nz,Dv_Disk_Err
        ld a,(Sv_Repl)              ; замена: старый - удалить, временный - переименовать
        or a
        jr z,.done
        ld ix,DK_DELETE+256
        ld hl,Dv_Spec
        call Disk_Call
        jp nz,Dv_Disk_Err
        ld ix,DK_RENAME+512
        ld hl,Spec_Tmp
        ld de,Dv_Name
        call Disk_Call
        jp nz,Dv_Disk_Err
.done   call Dv_List
        ld hl,Txt_Saved
        jp Dv_Ok

; Страница буфера Ld_Page - на диск, HL байт с её начала. CF - ошибка (сообщение стоит)
Sv_Append
        ld (Sv_N),hl
        ld a,(Ld_Page)
        add a,PAGE_FILEBUF
        SETPAGE3 a
        ld ix,DK_APPEND
        ld hl,#C000
        ld bc,(Sv_N)
        call Disk_Call
        ld (Ld_Res),a
        RESTPAGE3
        ld a,(Ld_Res)
        or a
        ret z
        call Dv_Disk_Code
        scf
        ret

Sv_Repl         db 0                ; 1 - файл был, пишем через временный
Sv_N            dw 0
Sv_Full         db 0                ; полных страниц в буфере
Sv_Tail         dw 0                ; байт в последней, неполной
Sv_Spec         db #20,0,0,0,0      ; CREATE: атрибут (архивный), размер 0, имя
                ds NAME_W+1
Spec_Tmp        db FD_FILE
Txt_TmpName     db "FT2TMP.$$",0

; Нет точки в имени - добавить ".ft2" (если влезает)
Name_Ext
        ld hl,Dv_Name
.f      ld a,(hl)
        or a
        jr z,.add
        cp '.'
        ret z
        inc hl
        jr .f
.add    ld a,(Dv_Name_Len)
        cp NAME_W-3
        ret nc
        add a,4
        ld (Dv_Name_Len),a
        ex de,hl
        ld hl,Txt_Ft2Ext
        ld bc,5
        ldir
        ret
Txt_Ft2Ext      db ".ft2",0

;-------- Трек -> буфер файла: страница трека, инструменты, паттерны потоком.
; Sv_Full / Sv_Tail - сколько получилось
Sv_Pack
        ld a,PAGE_FILEBUF
        ld (Pg_File),a
        ld a,PAGE_SONG1
        ld (Pg_Mem),a
        call Pg_Put
        ld a,PAGE_FILEBUF+1
        ld (Pg_File),a
        ld a,PAGE_INS1
        ld (Pg_Mem),a
        call Pg_Put
        ld a,PAGE_SONG1             ; каталог паттернов - как есть
        SETPAGE2 a
        ld hl,#8000+PAT_CATALOG
        ld de,Dv_Cat
        ld bc,PATTERNS_MAX*PC_SIZE
        ldir
        RESTPAGE2
        ld a,PAGE_FILEBUF+2
        ld (Fs_Page),a
        ld hl,#C000
        ld (Fs_Ptr),hl
        xor a
        ld (Cat_N),a
.pat    call Cat_Len
        jr z,.next
        ld (Cat_Rows),a
        ld hl,Dv_Cat                ; страница паттерна - из каталога
        ld a,(Cat_N)
        add a,a
        call Hl_Add_A
        ld a,(hl)
        SETPAGE2 a
        ld hl,#8000
.row    push hl
        ld bc,FT2_PAT_ROW
        call Fs_Write
        pop hl
        inc h
        ld a,(Cat_Rows)
        dec a
        ld (Cat_Rows),a
        jr nz,.row
        RESTPAGE2
.next   ld hl,Cat_N
        inc (hl)
        ld a,(hl)
        cp PATTERNS_MAX
        jr c,.pat
        ld a,(Fs_Page)              ; размер: полные страницы + хвост
        sub PAGE_FILEBUF
        ld (Sv_Full),a
        ld hl,(Fs_Ptr)
        ld a,h
        sub #C0
        ld h,a
        ld (Sv_Tail),hl
        ret

;-------- Страница целиком: Pg_Get - из буфера файла в память, Pg_Put - обратно
Pg_File         db 0                ; страница буфера файла
Pg_Mem          db 0                ; страница трека / инструментов

Pg_Get
        ld a,(Pg_File)
        SETPAGE3 a
        ld a,(Pg_Mem)
        SETPAGE2 a
        ld hl,#C000
        ld de,#8000
        ld bc,#4000
        ldir
        RESTPAGE2
        RESTPAGE3
        ret

Pg_Put
        ld a,(Pg_File)
        SETPAGE3 a
        ld a,(Pg_Mem)
        SETPAGE2 a
        ld hl,#8000
        ld de,#C000
        ld bc,#4000
        ldir
        RESTPAGE2
        RESTPAGE3
        ret

;-------- Поток в буфере файла: страница Fs_Page, адрес Fs_Ptr в окне 3.
; Fs_Read: BC байт из потока в DE (окно 2), DE - за последним.
; Fs_Write: BC байт из HL (окно 2) в поток.
Fs_Page         db 0
Fs_Ptr          dw 0
Fs_Cnt          dw 0                ; осталось перенести
Fs_N            dw 0                ; кусок до конца страницы потока
Fs_Src          dw 0

Fs_Read
        ld (Fs_Cnt),bc
.l      call Fs_Chunk
        ret z
        ld a,(Fs_Page)
        SETPAGE3 a
        ld hl,(Fs_Ptr)
        ld bc,(Fs_N)
        ldir
        RESTPAGE3
        call Fs_Step
        jr .l

Fs_Write
        ld (Fs_Src),hl
        ld (Fs_Cnt),bc
.l      call Fs_Chunk
        ret z
        ld a,(Fs_Page)
        SETPAGE3 a
        push de
        ld hl,(Fs_Src)
        ld de,(Fs_Ptr)
        ld bc,(Fs_N)
        ldir
        ld (Fs_Src),hl
        ex de,hl                    ; HL - новый адрес в потоке
        pop de
        RESTPAGE3
        call Fs_Step
        jr .l

; Кусок: Fs_N = меньшее из Fs_Cnt и остатка страницы потока. Z - переносить нечего
Fs_Chunk
        ld hl,(Fs_Cnt)
        ld a,h
        or l
        ret z
        ld hl,(Fs_Ptr)              ; до конца страницы: #10000 - Fs_Ptr
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ld bc,(Fs_Cnt)
        or a
        sbc hl,bc
        jr nc,.all                  ; влезает целиком
        add hl,bc
        ld b,h
        ld c,l
.all    ld (Fs_N),bc
        ld hl,(Fs_Cnt)
        or a
        sbc hl,bc
        ld (Fs_Cnt),hl
        or 1                        ; NZ
        ret

; После куска: HL - адрес в потоке за ним; конец страницы - следующая
Fs_Step
        ld a,h
        or l
        jr nz,.st
        ld hl,Fs_Page
        inc (hl)
        ld hl,#C000
.st     ld (Fs_Ptr),hl
        ret

    include "srs/pt3imp.asm"

; =========================================================================
; СООБЩЕНИЯ
; =========================================================================
; HL - текст ошибки
Dv_Error
        ld a,CLR_ERROR
        jr Dv_Msg_Set
; HL - текст "готово"
Dv_Ok
        ld a,CLR_CMD
Dv_Msg_Set
        ld (Dv_Msg),hl
        ld (Dv_Msg_Clr),a
        xor a
        ld (Dv_Msg_Code),a
        ld (Dv_Msg_F),a
        ld (Dv_Msg_Show),a
        inc a
        ld (Dv_Dirty),a
        ret

; Ошибка драйвера: код - в A (после Disk_Call). CF на выходе
Dv_Disk_Err
Dv_Disk_Code
        push af
        ld hl,Txt_DiskErr
        call Dv_Error
        pop af
        ld (Dv_Msg_Code),a
        scf
        ret

; =========================================================================
; ЧИСЛА, СТРОКИ
; =========================================================================
; HL -> 4 байта -> DE:HL
Nm_Load32
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        ret

; DE:HL -> Nm_Buf: 7 знаков, справа, впереди пробелы
Nm_Buf          ds 9
Nm_K            db 0                ; знаков осталось
Nm_Seen         db 0                ; 1 - уже была ненулевая цифра

Nm_Dec7
        ld ix,Nm_Pow
        ld iy,Nm_Buf
        ld a,7
        ld (Nm_K),a
        xor a
        ld (Nm_Seen),a
.d      ld a,'0'
.s      ld c,(ix+0)                 ; DE:HL -= степень, пока можно
        ld b,(ix+1)
        or a
        sbc hl,bc
        ex de,hl
        ld c,(ix+2)
        ld b,(ix+3)
        sbc hl,bc
        ex de,hl
        jr c,.back
        inc a
        jr .s
.back   ld c,(ix+0)                 ; лишнее вычитание - назад
        ld b,(ix+1)
        add hl,bc
        ex de,hl
        ld c,(ix+2)
        ld b,(ix+3)
        adc hl,bc
        ex de,hl
        ld b,a                      ; ведущий ноль - пробел (кроме последней цифры)
        ld a,(Nm_K)
        dec a
        ld (Nm_K),a
        jr z,.put
        ld a,(Nm_Seen)
        or a
        jr nz,.put
        ld a,b
        cp '0'
        jr nz,.seen
        ld b,' '
        jr .put
.seen   ld a,1
        ld (Nm_Seen),a
.put    ld (iy+0),b
        inc iy
        ld bc,4
        add ix,bc
        ld a,(Nm_K)
        or a
        jr nz,.d
        ld (iy+0),a
        ret

Nm_Pow  dd 1000000,100000,10000,1000,100,10,1

; HL - дата FAT (биты 15..9 год-1980, 8..5 месяц, 4..0 день) -> Nm_Buf "dd.mm.yy"
Nm_Date
        ld iy,Nm_Buf
        ld a,l                      ; день
        and #1F
        call .dec2
        ld (iy+0),'.'
        inc iy
        ld a,l                      ; месяц: H бит 0 и L биты 7..5
        rlca
        rlca
        rlca
        and 7
        ld b,a
        ld a,h
        and 1
        add a,a
        add a,a
        add a,a
        or b
        call .dec2
        ld (iy+0),'.'
        inc iy
        ld a,h                      ; год: 1980 + H/2, две цифры
        srl a
        add a,80
.y      cp 100
        jr c,.y2
        sub 100
        jr .y
.y2     call .dec2
        ld (iy+0),0
        ret
.dec2   ld b,'0'-1                  ; A (0..99) -> 2 цифры в (IY)
.t      inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld (iy+0),b
        ld (iy+1),a
        inc iy
        inc iy
        ret

; HL - строка -> A - длина (до 255). HL цел
Str_Len
        push hl
        ld b,0
.l      ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .l
.e      ld a,b
        pop hl
        ret

; HL += A
Hl_Add_A
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; =========================================================================
; ТЕКСТЫ
; =========================================================================
Txt_File        db " File ",0
Txt_Name        db "Name:",0
Txt_Type        db "Type:",0
Txt_Song        db "Song:",0
Txt_By          db "By:",0
Txt_Size        db "Size:",0
Txt_Load        db "[ Load ]",0
Txt_Save        db "[ Save ]",0
Txt_Dir         db "  <DIR>",0
Txt_FT2         db "FT2",0
Txt_PT3         db "PT3",0
Txt_PT2         db "PT2",0
Txt_Other       db "-",0
Txt_NoCard      db "No SD card / no FAT32",0
Txt_NotFound    db "Not found",0
Txt_NotFT2      db "Not an FT2 file",0
Txt_TooBig      db "File too big",0
Txt_CantLoad    db "Load: FT2 or PT3 only",0
Txt_NoName      db "Type a name",0
Txt_Loaded      db "Loaded",0
Txt_Saved       db "Saved",0
Txt_DiskErr     db "Disk error #",0
Txt_Empty       db "Empty dir",0
Txt_DbgList     db "list ",0
Txt_DbgFind     db "  find ",0

; --- PS/2 код -> символ имени файла (0 - не символ). Shift - в Dv_NameEv
        ALIGN 256
Dv_Chars
        ds #15,0
        db 'q','1',0,0,0,'z','s','a','w','2',0           ; #15..#1F
        db 0,'c','x','d','e','4','3',0,0,' ','v','f','t','r','5',0   ; #20..#2F
        db 0,'n','b','h','g','y','6',0,0,0,'m','j','u','7','8',0      ; #30..#3F
        db 0,0,'k','i','o','0','9',0,0,'.',0,'l',0,'p','-',0          ; #40..#4F
        ds #80-#50,0
    ASSERT $-Dv_Chars == #80

    ENDMODULE

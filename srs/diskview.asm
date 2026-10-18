; =========================================================================
; ДИСК - тулза (окно 1, #4000, страница PAGE_TOOL_DISK): каталог, загрузка и
; сохранение трека FT2.
; =========================================================================
; ЭКРАН (строки 0..3 - копия шапки из её буфера; клик по ней - назад в вид паттерна):
;   слева  - рамка с путём, каталог: сначала папки, потом файлы; имя, размер, дата;
;   справа - выбранный файл: Name (поле ввода - под это имя сохраняем), тип,
;            размер, Song / By (FT2 и PT3 - из файла), кнопки Load, Save, сообщение.
; Мышь: клик - выбрать, двойной клик / Enter - открыть (папка - войти, файл -
; загрузить), колесо - листать. Backspace в каталоге - в папку выше.
;
; ПАМЯТЬ:
;   PAGE_DIRLIST - каталог: таблица адресов записей (DR_MAX слов), за ней записи
;                  переменной длины (флаг, размер, дата, имя, 0); хвост страницы -
;                  буфер записи драйвера (NXTETY) и кластер каталога;
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

DV_SCR_H        equ TL_SCR_H        ; текстовая страница - в окне 3 (srs/toolscr.asm)
DV_HEAD_H       equ TL_HEAD_H       ; буфер шапки (её рисует вид паттерна)
DV_TOP          equ TL_TOP          ; первая строка экрана тулзы
DV_LAST         equ TL_LAST         ; последняя видимая строка

; --- каталог (слева)
LS_X            equ 0               ; рамка: колонки 0..49, строки 4..34
LS_W            equ 50
LS_ROW0         equ DV_TOP+1        ; первая строка списка
LS_ROWS         equ 30              ; строк списка
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
CMP_X           equ FP_L+20         ; [ Compare ]: после загрузки PT3 / PT2 - сравнить плееры
CMP_W           equ 11
CHK_Y           equ BTN_Y+1         ; [ Check ]: выбранный FT2 - во второй слот и сравнить (проверка контейнера)
CHK_W           equ 9
NEW_X           equ FP_L+10         ; [ New ] - очистить трек; [ Exit WC ] - в Wild Commander (строка Check)
NEW_W           equ 7
WC_X            equ FP_L+18
WC_W            equ 11
ASK_SAVE        equ 1               ; Sv_Ask: что спрашиваем (ответ Y / N / Esc)
ASK_NEW         equ 2
ASK_WC          equ 3
MSG_Y           equ DV_TOP+11       ; лог сообщений (3 строки), под кнопками через строку

; --- запись каталога в PAGE_DIRLIST (переменной длины, адрес - из таблицы, Dl_Ofs)
DR_FLAG         equ 0               ; 0 - папка, #10 - файл (как отдаёт драйвер)
DR_LEN          equ 1               ; 4 размер
DR_DATE         equ 5               ; 2 дата FAT
DR_NAME         equ 8               ; имя, 0 на конце
DR_NAME_MAX     equ 119             ; длиннее - обрезаем (LFN до 255)
DR_MAX          equ 640             ; записей не больше (номера - 16 бит)
DR_DATA         equ DR_MAX*2        ; записи - за таблицей адресов (смещения от начала страницы)
DR_END          equ DL_TMP-#C000    ;   и до буфера драйвера
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
    ASSERT DR_DATA < DR_END

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

; клавиши (KEY_*) и действия (ACT_*) - в sdk/plugin.asm

    MACRO DV_FIELD x,y,w,h,flags,handler,param
        db x,y,w,h,flags,PAGE_TOOL_DISK
        dw handler,0,param
    ENDM

; =========================================================================
; ВХОД (коре: Tools_Loop -> Call_Tool)
; =========================================================================
Dv_Start
        ld hl,Lg_Txt                ; лог - с чистого листа (строки пустые, без незакрытой)
        ld de,Lg_Txt+1
        ld bc,Lg_Open-Lg_Txt        ; + Lg_Clr, Lg_Len, Lg_Open
        ld (hl),0
        ldir
        ld a,CLR_CMD                ; цвет пустых строк - как при старте
        ld (Lg_Clr),a
        ld (Lg_Clr+1),a
        ld (Lg_Clr+2),a
        call Scr_Begin              ; двойной буфер: рисуем в невидимую страницу
        ld a,(SV_DRAW_PAGE)         ; экран - в окно 3 на всё время работы
        SETPAGE3 a
        call Dv_Head
        call Tool_Clear
        call Tr_Active              ; кнопки транспорта - по плееру (без подсветки шапки)
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
        ld a,(Auto_Go)              ; старт с INI load= - загрузить трек
        or a
        call nz,Dv_Auto
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
        call Scr_Show               ; кадр - показать
        jr Dv_Loop

;-------- Выход в коре (страница следующей тулзы - уже в SV_TOOL)
Dv_Leave
        xor a
        ld (Dv_Exit),a
        call Tool_Clear               ; экран - под вид паттерна
        call Scr_End
        RESTPAGE3
        ret

; --- состояние
Dv_Mounted      db 0                ; 1 - карта подключена
Dv_Cmp          db 0                ; 1 - Compare: после загрузки сравнить наш плеер с эталоном
Dv_Exit         db 0                ; 1 - выйти в коре
Dv_Dirty        db 0                ; 1 - перерисовать экран
Dv_Count        dw 0                ; записей в каталоге (номера - 16 бит)
Dv_Top          dw 0                ; первая видимая запись
Dv_Sel          dw 0                ; выбранная запись
Dv_Full         db 0                ; 1 - каталог не влез (показаны не все)
Dl_Free         dw 0                ; куда писать следующую запись (смещение в странице)
LG_LINES        equ 3               ; лог сообщений (как в консоли): строк, знаков в строке
LG_W            equ 38
LG_LAST         equ Lg_Txt+(LG_LINES-1)*(LG_W+1)
Lg_Txt          ds LG_LINES*(LG_W+1) ; строки, старая - первая (Dv_Start чистит с Lg_Txt по Lg_Open)
Lg_Clr          db CLR_CMD,CLR_CMD,CLR_CMD ; цвет строки: роль CLR_* (пустые - фоном сообщений)
Lg_Len          db 0                ; знаков в последней строке
Lg_Open         db 0                ; 1 - последняя строка ждёт итога (её начал Dv_Busy)
    ASSERT Lg_Open == Lg_Txt+LG_LINES*(LG_W+1)+LG_LINES+1
Lg_C            db 0
Lg_HexT         ds 3
Dv_Msg_Code     db 0                ; код ошибки драйвера (отладка)
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
        ld hl,DV_TAB_DISK           ; вкладка Disk - выбрана
        ld b,4
        jp Tool_Head
DV_TAB_DISK     equ DV_SCR_H*256+128+patview.HD_TAB_DISK     ; атрибут вкладки Disk


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
        call Tool_Box
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
        call Tool_Box
        ld a,(THEME_ATTR+CLR_HEADER)
        ld c,a
        ld de,FP_X+2+256*(DV_SCR_H+DV_TOP)
        ld hl,Txt_File
        jp PutStr

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
        ld hl,(Dv_Top)
        ld (Dl_Idx),hl
        ld d,DV_SCR_H+LS_ROW0
.row    push de
        call Dv_List_Row
        pop de
        ld hl,(Dl_Idx)
        inc hl
        ld (Dl_Idx),hl
        inc d
        ld a,d
        cp DV_SCR_H+LS_ROW0+LS_ROWS
        jr c,.row
        RESTPAGE2
        ret

Dl_Idx          dw 0
Dl_Tail         db 0                ; длинное имя: где последние 4 знака

; Строка D: запись Dl_Idx (за концом - пустая). Каталог - в окне 2
Dv_List_Row
        ld e,LS_X+1
        ld hl,(Dl_Idx)              ; за концом - пустая
        ld bc,(Dv_Count)
        or a
        sbc hl,bc
        jp nc,.empty
        ld hl,(Dl_Idx)
        ld a,#80                    ; запись (каталог - в окне 2)
        call Dl_Ofs
        ld (Dl_Rec),hl
        ld a,(hl)                   ; цвет строки: папка - ярче
        cp DR_IS_DIR
        ld a,(THEME_ATTR+CLR_TEXT)
        jr nz,$+5
        ld a,(THEME_ATTR+CLR_NOTE)
        ld c,a
        push de                     ; выбранная - курсором (список в фокусе - ярким)
        ld hl,(Dl_Idx)
        ld de,(Dv_Sel)
        or a
        sbc hl,de
        pop de
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
        ld e,LS_NAME_X              ; имя: влезает в LS_NAME_W - целиком,
        ld hl,(Dl_Rec)              ;   длиннее - начало, "~" и последние 4 знака
        ld bc,DR_NAME               ;   (расширение видно)
        add hl,bc
        call Str_Len
        cp LS_NAME_W+1
        ld b,LS_NAME_W
        jr c,.nm
        sub 4                       ; хвост: имя + длина - 4
        ld (Dl_Tail),a
        ld b,LS_NAME_W-5
        call .put
        ld a,'~'
        ld (de),a
        inc e
        ld hl,(Dl_Rec)
        ld bc,DR_NAME
        add hl,bc
        ld a,(Dl_Tail)
        call Hl_Add_A
        ld b,4
.nm     call .put
        jr .size
; B знаков с HL (до 0) - на экран с DE
.put    ld a,(hl)
        or a
        ret z
        ld (de),a
        inc e
        inc hl
        djnz .put
        ret
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
        jp Lg_Draw                  ; лог сообщений

;-------- Поле Name: текст на фоне поля ввода, в фокусе - курсор строки ввода (Ti_Cursor)
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
        ld hl,(SV_FOCUS)            ; в фокусе - курсор строки ввода
        ld de,F_Name
        or a
        sbc hl,de
        ret nz
        ld de,FP_V+256*(DV_SCR_H+NAME_Y)
        jp Ti_Cursor

;-------- Кнопки Load / Save: под мышью - подсветка, держат - "нажата" (цвет курсора)
Dv_Buttons
        ld ix,F_Load
        ld de,LOAD_X+256*(DV_SCR_H+BTN_Y)
        ld hl,Txt_Load
        call .one
        ld ix,F_Save
        ld de,SAVE_X+256*(DV_SCR_H+BTN_Y)
        ld hl,Txt_Save
        call .one
        ld ix,F_Chk
        ld de,LOAD_X+256*(DV_SCR_H+CHK_Y)
        ld hl,Txt_Check
        call .one
        ld ix,F_New
        ld de,NEW_X+256*(DV_SCR_H+CHK_Y)
        ld hl,Txt_New
        call .one
        ld ix,F_WC
        ld de,WC_X+256*(DV_SCR_H+CHK_Y)
        ld hl,Txt_ExitWC
        call .one
        ld ix,F_Cmp                 ; Compare: вкл / выкл
        ld de,CMP_X+256*(DV_SCR_H+BTN_Y)
        ld hl,Txt_CmpOff
        ld a,(Dv_Cmp)
        or a
        jr z,.one
        ld hl,Txt_CmpOn
        call .one                   ; включено - поверх цветом выделения
        ld a,(THEME_ATTR+CLR_SELECT)
        ld hl,CMP_X+128+256*(DV_SCR_H+BTN_Y)
        ld b,CMP_W
.sel    ld (hl),a
        inc l
        djnz .sel
        ret
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
        DV_FIELD patview.HD_PLAY_X,   patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 0  ; ⇄ паттерн по кругу
        DV_FIELD patview.HD_PLAY_X+4, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 1  ; |◀ сонг с начала
        DV_FIELD patview.HD_PLAY_X+8, patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 2  ; ▶ сонг
        DV_FIELD patview.HD_PLAY_X+12,patview.HD_PLAY_Y,4,2, FF_HAND, Tool_TrEv, 3  ; ▷ паттерн с роу
        DV_FIELD patview.HD_TAB_INSTR,patview.HD_TABS_Y,5,1, FF_HAND, Dv_TabPat, 1 ; Instr
        DV_FIELD patview.HD_TAB_ORN,  patview.HD_TABS_Y,3,1, FF_HAND, Dv_TabPat, 2 ; Orn
        DV_FIELD patview.HD_TAB_SETUP,patview.HD_TABS_Y,5,1, FF_HAND, Dv_TabPat, 3 ; Setup
        DV_FIELD patview.HD_HELP_X,   patview.HD_TABS_Y,4,1, FF_HAND, Dv_TabPat, 4 ; Help
        DV_FIELD patview.HD_ABOUT_X,  patview.HD_TABS_Y,5,1, FF_HAND, Win_AboutEv, 0 ; About
        DV_FIELD 0,0,90,DV_TOP, 0, Dv_TabPat, 0                         ; остальная шапка: клик - назад
F_List  DV_FIELD LS_X+1,LS_ROW0,LS_W-2,LS_ROWS, FF_FOCUS, Dv_ListEv, 0  ; каталог
F_Name  DV_FIELD FP_V,NAME_Y,NAME_W,1, FF_FOCUS|FF_HAND, Dv_NameEv, 0   ; имя файла
F_Load  DV_FIELD LOAD_X,BTN_Y,BTN_W,1, FF_HAND, Dv_BtnEv, 0              ; Load
F_Save  DV_FIELD SAVE_X,BTN_Y,BTN_W,1, FF_HAND, Dv_BtnEv, 1              ; Save
F_Cmp   DV_FIELD CMP_X,BTN_Y,CMP_W,1, FF_HAND, Dv_BtnEv, 2              ; Compare
F_Chk   DV_FIELD LOAD_X,CHK_Y,CHK_W,1, FF_HAND, Dv_BtnEv, 3             ; Check
F_New   DV_FIELD NEW_X,CHK_Y,NEW_W,1, FF_HAND, Dv_BtnEv, 4              ; New
F_WC    DV_FIELD WC_X,CHK_Y,WC_W,1, FF_HAND, Dv_BtnEv, 5                ; Exit WC
        db FLD_END

;-------- Клик в шапку: Instr / Orn - тулза инструментов, остальное - назад в вид паттерна
Dv_TabPat
        cp EV_CLICK
        ret nz
        ld a,(ix+FLD_PARAM)         ; 0 - вид паттерна, 1 - Instr, 2 - Orn, 3 - Setup, 4 - Help
        ld b,PAGE_TOOL_PATVIEW
        or a
        jr z,.go
        cp 3
        jr c,.ins
        sub 3                       ; Setup - 0, Help - OPT_HELP
        ld (SV_TOOL_ARG),a
        ld b,PAGE_TOOL_OPT
        jr .go
.ins
        dec a                       ; режим тулзы инструментов: 0 / 1
        ld (SV_TOOL_ARG),a
        ld b,PAGE_TOOL_INSTR
.go     ld a,b
        ld (SV_TOOL),a
        ld a,1
        ld (Dv_Exit),a
        ret


;-------- Кнопки: Load - открыть выбранную запись, Save - сохранить под Name, Check - сравнить файл с треком
Dv_BtnEv
        cp EV_CLICK
        ret nz
        ld a,(Sv_Ask)               ; спрашивали перезапись - кнопка = "нет"
        or a
        jr z,.go
        xor a
        ld (Sv_Ask),a
        ld hl,Txt_SvNo
        call Dv_Ok
.go     ld a,(ix+FLD_PARAM)
        or a
        jp z,Dv_Open
        dec a
        jp z,Dv_Save
        dec a
        jr z,.cmp
        dec a
        jp z,Dv_Check
        dec a
        ld a,ASK_NEW                ; New / Exit WC - сначала вопрос
        ld hl,Txt_AskNew
        jr z,.ask
        ld a,ASK_WC
        ld hl,Txt_AskWC
.ask    ld (Sv_Ask),a
        jp Dv_Busy                  ; строка вопроса - открытая, ответ допишется
.cmp    ld a,(Dv_Cmp)               ; Compare - переключить
        xor 1
        ld (Dv_Cmp),a
        ret

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
        ld hl,(Dv_Top)
        call Hl_Add_A
        jp Dv_Sel_Chk
.wheel  ld a,c                      ; вниз (C < 0) - следующая
        or a
        jp m,Dv_Next
        jp Dv_Prev
.key    ld hl,List_Keys
        jp Keys_Table

List_Keys
        db ACT_UP
        dw Dv_Prev
        db ACT_DOWN
        dw Dv_Next
        db ACT_PGUP
        dw Dv_PgUp
        db ACT_PGDN
        dw Dv_PgDn
        db ACT_HOME
        dw Dv_Home
        db ACT_END
        dw Dv_End
        db ACT_ENTER
        dw Dv_Open
        db ACT_DIR_UP
        dw Dv_Parent
        db 0

Dv_Prev ld hl,(Dv_Sel)
        ld a,h
        or l
        ret z
        dec hl
        jr Dv_Select
Dv_Next ld hl,(Dv_Sel)
        inc hl
        jr Dv_Sel_Chk
Dv_PgUp ld hl,(Dv_Sel)
        ld de,LS_ROWS
        or a
        sbc hl,de
        jr nc,Dv_Select
Dv_Home ld hl,0
        jr Dv_Select
Dv_PgDn ld hl,(Dv_Sel)
        ld de,LS_ROWS
        add hl,de
        call Dv_In_List
        jr c,Dv_Select
Dv_End  ld hl,(Dv_Count)
        ld a,h
        or l
        ret z
        dec hl
        jr Dv_Select

; HL - номер: в списке - выбрать, нет - ничего
Dv_Sel_Chk
        call Dv_In_List
        ret nc
        jr Dv_Select
; HL < Dv_Count? CF - да. HL цел, портит DE
Dv_In_List
        ld de,(Dv_Count)
        or a
        sbc hl,de
        add hl,de
        ret

;-------- Выбрать запись HL: курсор виден, имя - в поле Name, сведения о файле
Dv_Select
        ld (Dv_Sel),hl
        ld de,(Dv_Top)              ; выше видимых - список вверх
        or a
        sbc hl,de
        add hl,de
        jr nc,.below
        ld (Dv_Top),hl
        jr .info
.below  ld de,LS_ROWS-1             ; ниже - вниз: верх = номер - (LS_ROWS-1)
        or a
        sbc hl,de
        jr c,.info
        ld de,(Dv_Top)
        or a
        sbc hl,de
        add hl,de
        jr c,.info
        ld (Dv_Top),hl
.info   ld a,1
        ld (Dv_Dirty),a
        call Dv_Clear_Info
        ld hl,(Dv_Count)
        ld a,h
        or l
        ret z
        ld hl,(Dv_Sel)              ; запись - в Dv_Spec (флаг, имя)
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

;-------- Поле Name: стандартная строка ввода (Ti_*, коре); Enter - Save, Esc - не наш (выход из Disk)
Dv_NameEv
        ld (Dv_NEv),a
        ld hl,Dv_Name
        ld a,NAME_W
        call Ti_Set
        ld a,(Dv_NEv)
        cp EV_FOCUS_IN
        jr z,.in
        cp EV_FOCUS_OUT
        jr z,.focus
        cp EV_PRESS
        jr z,.click
        cp EV_KEY
        ret nz
        ld a,b
        cp KEY_ESC                  ; CF = 0: не наша
        ret z
        call Ti_Key
        ret nc
        ld (Dv_NEv),a               ; итог
        call Ti_Len                 ; длина имени - до Save (он берёт её)
        ld (Dv_Name_Len),a
        ld a,(Dv_NEv)
        cp TI_DONE
        call z,Dv_Save              ; Enter
        jr .focus
.in     ld hl,Dv_Name
        ld a,NAME_W
        call Ti_Begin
        jr .focus
.click  ld a,(SV_MOUSE_COL)         ; курсор - на знак под мышью
        sub (ix+FLD_X)
        call Ti_Click
.focus  ld a,1
        ld (Dv_Dirty),a
        scf                         ; событие - наше
        ret
Dv_NEv          db 0

;-------- Клавиши: полю в фокусе; Tab - фокус каталог <-> Name
Dv_Keys
.k      call Key_Get                ; A - код, C - флаги; Z - пусто
        ret z
        ld b,a
        ld a,(Sv_Ask)               ; Save спрашивает перезапись - ответ клавишей
        or a
        jr nz,Sv_Answer
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

;-------- New: трек - пустой (как при старте), назад в вид паттерна
Dv_NewSong
        ld a,PC_STOP                ; плеер - стоп: трек сейчас перепишем
        ld (SV_PLAY_CMD),a
.w      halt
        ld a,(SV_PLAY_STATE)
        or a
        jr nz,.w
        call Tr_Active
        call Song_New
        ld a,1                      ; вид паттерна перечитает трек
        ld (SV_SONG_NEW),a
        ld a,PAGE_TOOL_PATVIEW
        ld (SV_TOOL),a
        ld a,1
        ld (Dv_Exit),a
        ret

;-------- Exit WC: ПЗУ (ts-bios) в окно 0 и на #0000 - перезапуск, BIOS грузит WC с карты.
; Вернуться в WC без перезапуска нельзя: FT2 занимает его страницы
Dv_ExitWC
        di
        ld bc,MEMCONFIG
        ld a,MEM_W0MAP_N            ; окно 0 - ПЗУ (W0RAM = 0), обычный режим
        out (c),a
        ld bc,PAGE0
        xor a                       ; страница 0 ПЗУ
        out (c),a
        jp 0

;-------- Ответ на "overwrite? (Y/N)": B - клавиша. Y - писать поверх, N / Esc - нет, прочие - мимо
Sv_Answer
        ld a,b
        cp KEY_Y
        jr z,.yes
        cp KEY_N
        jr z,.no
        cp KEY_ESC
        jp nz,Dv_Keys
.no     xor a
        ld (Sv_Ask),a
        ld hl,Txt_SvNo
        call Dv_Ok
        jp Dv_Keys
.yes    ld a,(Sv_Ask)
        push af
        xor a
        ld (Sv_Ask),a
        ld hl,Txt_SvYes
        call Dv_Ok
        pop af
        cp ASK_WC
        jp z,Dv_ExitWC
        cp ASK_NEW
        jr nz,.save
        call Dv_NewSong
        jp Dv_Keys
.save
        ld a,1                      ; Save ещё раз - поверх
        ld (Sv_Force),a
        call Dv_Save
        xor a                       ; не дошёл до вопроса (ошибка) - не оставлять
        ld (Sv_Force),a
        jp Dv_Keys

; =========================================================================
; КАТАЛОГ
; =========================================================================
;-------- Прочитать текущий каталог: сначала папки, потом файлы. "." - не берём
Dl_Want         db 0                ; какой флаг берём в этом проходе

Dv_List
        ld hl,0
        ld (Dv_Count),hl
        ld (Dv_Top),hl
        ld (Dv_Sel),hl
        ld hl,DR_DATA               ; записи - за таблицей адресов
        ld (Dl_Free),hl
        xor a
        ld (Dv_Full),a
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
        ld a,(Dv_Full)              ; не влез - сказать
        or a
        ld hl,Txt_Full
        call nz,Dv_Error
        ld hl,(Dv_Count)            ; пусто - сказать
        ld a,h
        or l
        ret nz
        ld hl,Txt_Empty
        jp Dv_Error




; Проход по каталогу с начала: записи с флагом A - в список
Dl_Pass
        ld (Dl_Want),a
        ld ix,DK_SET_CLUS           ; с начала каталога
        ld hl,DL_CLUS
        call Disk_Call
.next   ld hl,(Dv_Count)            ; таблица полна - дальше не читаем
        ld de,DR_MAX
        or a
        sbc hl,de
        jp nc,.full
        ld ix,DK_NEXT               ; следующая запись
        ld de,DL_TMP
        call Disk_Call
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
.keep   ld hl,DL_TMP+NX_NAME        ; место: запись = заголовок + имя (до DR_NAME_MAX) + 0
        call Str_Len
        cp DR_NAME_MAX+1
        jr c,$+4
        ld a,DR_NAME_MAX
        add a,DR_NAME+1
        ld e,a
        ld d,0
        ld hl,(Dl_Free)
        add hl,de
        ld de,DR_END+1              ; за DR_END - не влезла
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(Dv_Count)            ; адрес записи - в таблицу
        add hl,hl
        ld a,h
        or #C0
        ld h,a
        ld de,(Dl_Free)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,d                      ; DE - запись (окно 3): флаг, размер, дата, имя
        or #C0
        ld d,a
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
        inc de
        ld a,d                      ; следующая - сразу за ней
        and #3F
        ld d,a
        ld (Dl_Free),de
        ld hl,(Dv_Count)
        inc hl
        ld (Dv_Count),hl
        jp .next
.full   ld a,1                      ; не влез - показываем, что есть
        ld (Dv_Full),a
        ret

; HL - номер записи, A - старший байт окна со страницей каталога (#80 / #C0) ->
; HL - адрес записи (из таблицы). Портит C
Dl_Ofs
        ld c,a
        add hl,hl                   ; таблица: слово на запись
        or h
        ld h,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        or h
        ld h,a
        ret

;-------- Запись HL -> Dv_Spec: флаг поиска (FD_*), имя, 0 - так её ищет драйвер
Dv_Spec         ds 1+DR_NAME_MAX+1

Dv_Spec_Rec
        ld (Dl_Idx),hl
        ld a,PAGE_DIRLIST
        SETPAGE2 a
        ld hl,(Dl_Idx)
        ld a,#80                    ; каталог - в окне 2
        call Dl_Ofs
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
        ld hl,(Dv_Count)
        ld a,h
        or l
        ret z
        ld hl,(Dv_Sel)
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

;-------- Автозагрузка (INI load=): путь от корня - папки по очереди, потом файл. Не нашли - остаёмся
; в диске (сообщение в логе, видна папка, где остановились)
Au_Name         dw 0
Dv_Auto
        xor a                       ; один раз
        ld (Auto_Go),a
        ld a,(Dv_Mounted)
        or a
        ret z
        ld ix,DK_SET_ROOT           ; от корня
        call Disk_Call
        ret c
        ld hl,Dv_Path
        ld (hl),'/'
        inc hl
        ld (hl),0
        ld hl,Auto_Path
        ld a,(hl)
        cp '/'
        jr nz,.part
        inc hl
.part   ld (Au_Name),hl             ; имя - до "/" или конца
        ld de,Dv_Spec+1
.c      ld a,(hl)
        or a
        jr z,.file
        cp '/'
        jr z,.dir
        ld (de),a
        inc hl
        inc de
        jr .c
.dir    xor a                       ; папка - войти
        ld (de),a
        inc hl
        push hl
        ld a,FD_DIR
        ld (Dv_Spec),a
        ld hl,Dv_Spec
        call Dv_Find
        jr c,.err
        ld ix,DK_ENTER
        call Disk_Call
        jr nc,.in
        call Dv_Disk_Err
        jr .err
.in     call Path_Add
        pop hl
        jr .part
.err    pop hl
        jp Dv_List
.file   call Dv_List                ; каталог - тот, где файл (Dv_Spec портит)
        ld hl,(Au_Name)             ; имя файла - заново
        ld de,Dv_Spec+1
.f      ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.f
        ld a,FD_FILE
        ld (Dv_Spec),a
        jp Dv_Load

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

;-------- Сведения о файле Dv_Spec: тип по расширению; FT2, PT3, FTC - Song / By из файла
Dv_File_Info
        call Dv_Ext                 ; A - тип: 1 FT2, 2 PT3, 3 PT2, 4 FTC, 0 - другой
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
        ret z
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
        cp 4                        ; FTC - описание режем на имя и автора, как импорт
        jr z,.ftc
        cp 1
        jr nz,.pt3
        ld a,(#C000+3)              ; контейнер "FT2C": HEAD - первый блок, имя - +12 его данных
        cp 'C'
        jr nz,.dump
        ld hl,#C000+6+6+12
        ld d,h
        ld e,l
.nz     ld a,(de)                   ; автор - за нулём имени
        inc de
        or a
        jr nz,.nz
        jr .copy
.dump   ld hl,#C000+SH_NAME
        ld de,#C000+SH_AUTHOR
        jr .copy
.pt3
        ld hl,#C000+30              ; PT3: +30 имя, +66 автор
        ld de,#C000+66
.copy   push de
        ld de,Dv_Song
        call .str
        pop hl
        ld de,Dv_By
        call .str
        jr .out
.ftc    ld hl,0                     ; описание - из буфера файла с начала (Pt_Get)
        ld (Pt_Base),hl
        call Fc_Split
        ld hl,Fc_Txt                ; имя: [0, Fc_Cut)
        ld de,Dv_Song
        ld a,(Fc_Cut)
        call .part
        ld hl,Fc_Txt                ; автор: [Fc_By, Fc_Len)
        ld a,(Fc_By)
        call Hl_Add_A
        ld de,Dv_By
        ld a,(Fc_By)
        ld b,a
        ld a,(Fc_Len)
        sub b
        call .part
.out    RESTPAGE3
        ret
; 32 знака HL -> DE, хвостовые пробелы и нули - конец
; A знаков (не больше 32) HL -> DE, 0 на конце
.part   cp 33
        jr c,$+4
        ld a,32
        or a
        jr z,.pz
        ld c,a
        ld b,0
        ldir
.pz     xor a
        ld (de),a
        ret
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
Fi_Names        dw Txt_FT2,Txt_PT3,Txt_PT2,Txt_FTCn

; Расширение имени Dv_Spec -> A: 1 FT2, 2 PT3, 3 PT2, 4 FTC, 0 - другое
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
        ld de,Ext_FTC
        call Ext_Cmp
        ld a,4
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
Ext_FTC         db "ftc"

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
        cp 3
        jr z,.kind
        cp 4
        jr z,.kind
        ld hl,Txt_CantLoad
        jp Dv_Error
.kind   ld hl,Txt_Loading           ; статус - сразу: чтение долгое
        call Dv_Busy
        ld hl,Dv_Spec
        call Dv_Find
        ret c
        ld (Ld_Size),hl
        ld (Ld_Size+2),de
        ld a,(Ld_Kind)              ; FT2 - потоком: размер любой (не меньше двух страниц)
        cp 1
        jr z,.ft2min
        ld a,d                      ; модуль - целиком в буфер: не больше 64К
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
.fits   ld a,e                      ; модуль - хотя бы заголовок и ордер
        or h
        jr nz,.pages
        ld a,l
        cp PT_ORDER+1
        jr nc,.pages
        ld hl,Txt_BadPt3
        jp Dv_Error
.ft2min ld a,e                      ; FT2 - хотя бы заголовок контейнера (старый дамп - проверит Ft2_Load)
        or h
        jr nz,.pages
        ld a,l
        cp 12
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
        ld a,PC_STOP                ; плеер - стоп (регистры AY в 0): страницы трека
        ld (SV_PLAY_CMD),a          ; сейчас перепишем
.wst    halt                        ; ждём, пока плеер встанет (SV_PLAY_STATE = 0)
        ld a,(SV_PLAY_STATE)
        or a
        jr nz,.wst
        call Tr_Active              ; кнопки транспорта - не горят
        ld a,(Ld_Kind)              ; FT2 - потоком
        cp 1
        jp z,Ft2_Load
        xor a                       ; модуль - в буфер, по странице
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
.check  ld a,(Ld_Kind)              ; импорт по типу
        cp 2
        jp z,Pt_Import
        cp 3
        jp z,Pt2_Import
        jp Ftc_Import
.err    ld a,(Ld_Res)
        jp Dv_Disk_Code

Ld_Kind         db 0                ; 1 FT2, 2 PT3 (Dv_Ext)
Ld_Size         ds 4                ; размер файла
Ld_Pages        db 0                ; страниц в файле
Ld_Page         db 0                ; прочитано страниц
Ld_Res          db 0
Ld_Err          db 0

;-------- FT2 - потоком через одну страницу буфера (файл открыт Dv_Find):
; 16К - страница трека, 16К - инструменты и орнаменты, дальше паттерны по роу
Ft2_Load
        xor a                       ; поток - чтение
        ld (Fs_Mode),a
        ld (Fs_Err),a
        call Fs_Fill                ; страница трека
        jp c,.err
        ld a,PAGE_FILEBUF           ; подпись трека
        SETPAGE3 a
        ld hl,(#C000+SH_SIGN)
        ld de,(#C000+SH_SIGN+2)
        RESTPAGE3
        ld bc,"F"+"T"*256           ; "FT2C" - контейнер
        or a
        sbc hl,bc
        add hl,bc
        jr nz,.old
        push hl
        ex de,hl
        ld bc,"2"+"C"*256
        or a
        sbc hl,bc
        ex de,hl
        pop hl
        jp z,Cn_Read
.old    ld a,(Ld_Size+2)            ; старый дамп - хотя бы две страницы (32К)
        ld c,a
        ld a,(Ld_Size+3)
        or c
        jr nz,.sz
        ld a,(Ld_Size+1)
        cp #80
        jr c,.bad
.sz
        ld bc,"F"+"T"*256
        or a
        sbc hl,bc
        jr nz,.bad
        ex de,hl
        ld bc,"2"+"S"*256
        sbc hl,bc
        jr nz,.bad
        ld a,PAGE_FILEBUF
        ld (Pg_File),a
        ld (Fs_Page),a
        ld a,(SV_SONG_PAGE)
        ld (Pg_Mem),a
        call Pg_Get
        call Fs_Fill                ; инструменты и орнаменты
        jr c,.err
        ld a,(Trk_Ins)
        ld (Pg_Mem),a
        call Pg_Get
        call Fs_Fill                ; дальше - паттерны
        jr c,.err
        ld hl,#C000
        ld (Fs_Ptr),hl
        jr Ld_Unpack
.bad    ld hl,Txt_NotFT2
        jp Dv_Error
.err    ld a,(Ld_Res)
        jp Dv_Disk_Code

;-------- Контейнер: первые 16К уже в буфере - остальное (до 64К) туда же, потом разбор
Cn_Read
        ld a,(Ld_Size+2)            ; больше 64К - не берём
        or a
        jr nz,.big
        ld a,(Ld_Size+3)
        or a
        jr nz,.big
        ld a,1
        ld (Ld_Page),a
.r      ld a,(Ld_Page)
        ld hl,Ld_Pages
        cp (hl)
        jr nc,.go
        add a,PAGE_FILEBUF
        SETPAGE3 a
        ld ix,DK_READ
        ld hl,#C000
        ld b,32
        call Disk_Call
        ld (Ld_Res),a
        sbc a,a
        ld (Ld_Err),a
        RESTPAGE3
        ld a,(Ld_Err)
        or a
        jr nz,.err
        ld hl,Ld_Page
        inc (hl)
        jr .r
.go     ld hl,(Ld_Size)
        jp Cn_Load
.big    ld hl,Txt_TooBig
        jp Dv_Error
.err    ld a,(Ld_Res)
        jp Dv_Disk_Code

;-------- Паттерны из потока - в трек
Ld_Unpack
        call Cat_Get                ; каталог паттернов: страницы - на наши места
        xor a
        ld (Cat_N),a
.pat    call Cat_Len                ; A - длина, Z - паттерна нет
        jr z,.next
        ld (Cat_Rows),a
        ld a,(Cat_N)
        call Pat_Page
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
        ld a,(Fs_Err)               ; диск подвёл посреди паттернов
        or a
        jr z,.ok
        ld a,(Ld_Res)
        jp Dv_Disk_Code
.ok     ld hl,Dv_Spec+1             ; имя файла - в трек (шапка)
        call Dv_Song_File
        ld a,1                      ; вид паттерна перечитает трек при входе
        ld (SV_SONG_NEW),a
        jp Dv_Loaded

;-------- Имя файла HL (0 на конце, до 31 знака) - в заголовок трека (SH_FILE)
Sf_Src          dw 0

Dv_Song_File
        ld (Sf_Src),hl
        ld a,(SV_SONG_PAGE)
        SETPAGE2 a
        ld hl,(Sf_Src)
        ld de,#8000+SH_FILE
        ld b,31
.c      ld a,(hl)
        ld (de),a
        or a
        jr z,.e
        inc hl
        inc de
        djnz .c
        xor a                       ; длиннее - обрезали
        ld (de),a
.e      RESTPAGE2
        ret

;-------- Загрузили без потерь - экран диска закрываем, назад в вид паттерна
Dv_Loaded
        ld a,(Ck_On)                ; Check: остаёмся в диске, дальше - сравнение
        or a
        jr z,.exit
        ld (Ck_Ok),a
        ret
.exit
        ld hl,Txt_LgOk              ; "Loading... OK"
        call Dv_Ok
        ld a,PAGE_TOOL_PATVIEW
        ld (SV_TOOL),a
        ld a,1
        ld (Dv_Exit),a
        ret

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

;-------- Каталог паттернов трека -> Dv_Cat; страницы в треке - Trk_Pat+n (так их
; ждёт вид паттерна), страница инструментов - Trk_Ins
Dv_Cat          equ Disk_Cat        ; буфер - в коре (страница диска полна)
Cat_N           db 0                ; номер паттерна
Cat_Rows        db 0

Cat_Get
        ld a,(SV_SONG_PAGE)
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
        call Pat_Page
        ld (hl),a
.n      inc hl
        inc hl
        inc b
        ld a,b
        cp PATTERNS_MAX
        jr c,.p
        ld a,(Trk_Ins)
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
.name   ld hl,Txt_Saving            ; статус - сразу: запись долгая
        call Dv_Busy
        call Name_Ext
        ld hl,Dv_Name               ; имя файла - в трек (и в файл)
        call Dv_Song_File
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
        or a
        jr z,.nm
        ld a,(Sv_Force)             ; файл есть: без подтверждения - спросить (кнопки Yes / No)
        or a
        jr nz,.ovr
        ld a,ASK_SAVE
        ld (Sv_Ask),a
        ld hl,Txt_Exists
        call Dv_Ok
        ld a,1                      ; строка ждёт ответа: "(Y/N) Y"
        ld (Lg_Open),a
        ret
.ovr    xor a
        ld (Sv_Force),a
        ld hl,Txt_TmpName           ; есть - пишем во временный
        jr .cr
.nm     ld hl,Dv_Name               ; имя, под которым создаём
.cr     ld de,Sv_Spec+5
        ld bc,NAME_W+1
        ldir
        ld ix,DK_CREATE+256
        ld hl,Sv_Spec
        call Disk_Call
        jp nz,Dv_Disk_Err
        call Cn_Save                ; трек - в файл (контейнер)
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

; Страница буфера файла - на диск, HL байт с её начала. CF - ошибка (сообщение стоит)
Sv_Append
        ld (Sv_N),hl
        ld a,PAGE_FILEBUF
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
Sv_Ask          db 0                ; 1 - файл есть, спрашиваем: кнопки Yes / No
Sv_Force        db 0                ; 1 - Yes: писать поверх
Sv_N            dw 0
Sv_Spec         db #20,0,0,0,0      ; CREATE: атрибут (архивный), размер 0, имя
                ds NAME_W+1
Spec_Tmp        db FD_FILE
Txt_TmpName     db "FT2TMP.$$",0

; Нет точки в имени - добавить ".ft2" (если влезает)
;-------- Имя для записи: расширение всегда .ft2 - своё (после последней точки) долой;
; длинное имя укорачиваем, чтобы .ft2 влезло
Name_Ext
        ld hl,Dv_Name
        ld b,0                      ; B - сколько знаков прошли
        ld c,#FF                    ; C - длина до последней точки (#FF - точки нет)
.f      ld a,(hl)
        or a
        jr z,.end
        cp '.'
        jr nz,.n
        ld c,b
.n      inc hl
        inc b
        jr .f
.end    ld a,c                      ; есть точка - имя до неё
        inc a
        jr z,$+3
        ld b,c
        ld a,b                      ; A - длина имени без расширения
        cp NAME_W-3                 ; + ".ft2" должно влезть в поле
        jr c,$+4
        ld a,NAME_W-4
        ld e,a
        add a,4
        ld (Dv_Name_Len),a
        ld d,0
        ld hl,Dv_Name
        add hl,de
        ex de,hl
        ld hl,Txt_Ft2Ext
        ld bc,5
        ldir
        ret
Txt_Ft2Ext      db ".ft2",0

;-------- Трек -> файл (создан, открыт) потоком через одну страницу буфера: страница
; трека, инструменты, паттерны по роу. CF - ошибка (сообщение стоит)
Sv_Stream
        ld a,1                      ; поток - запись
        ld (Fs_Mode),a
        xor a
        ld (Fs_Err),a
        ld a,PAGE_FILEBUF
        ld (Pg_File),a
        ld (Fs_Page),a
        ld a,(SV_SONG_PAGE)
        ld (Pg_Mem),a
        call Pg_Put
        ld hl,#4000
        call Sv_Append
        ret c
        ld a,(Trk_Ins)
        ld (Pg_Mem),a
        call Pg_Put
        ld hl,#4000
        call Sv_Append
        ret c
        ld a,(SV_SONG_PAGE)             ; каталог паттернов - как есть
        SETPAGE2 a
        ld hl,#8000+PAT_CATALOG
        ld de,Dv_Cat
        ld bc,PATTERNS_MAX*PC_SIZE
        ldir
        RESTPAGE2
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
        ld a,(Fs_Err)               ; полные страницы уже на диске (Fs_Step)
        or a
        scf
        ret nz
        ld hl,(Fs_Ptr)              ; хвост - неполная страница
        ld a,h
        sub #C0
        ld h,a
        or l
        ret z
        jp Sv_Append

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

; После куска: HL - адрес в потоке за ним. Страница кончилась: чтение - следующие 16К
; файла в неё же, запись - она на диск. Ошибка диска - Fs_Err (дальше не читаем и не пишем)
Fs_Step
        ld a,h
        or l
        jr nz,.st
        ld a,(Fs_Err)
        or a
        jr nz,.re
        ld a,(Fs_Mode)
        or a
        jr nz,.w
        call Fs_Fill
        jr .chk
.w      ld hl,#4000
        call Sv_Append
.chk    jr nc,.re
        ld a,1
        ld (Fs_Err),a
.re     ld hl,#C000
.st     ld (Fs_Ptr),hl
        ret

Fs_Mode         db 0                ; 0 - чтение, 1 - запись
Fs_Err          db 0                ; 1 - диск подвёл

;-------- Следующие 16К файла - в страницу буфера. CF - ошибка (Ld_Res - код)
Fs_Fill
        ld a,PAGE_FILEBUF
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
        rra                         ; CF - ошибка
        ret

    include "srs/pt3imp.asm"
    include "srs/pt2imp.asm"
    include "srs/ftcimp.asm"
    include "srs/ft2c.asm"         ; контейнер FT2 (doc/formats/ft2.md)
    include "srs/cncheck.asm"      ; Check: файл FT2 против трека в памяти

; =========================================================================
; СООБЩЕНИЯ
; =========================================================================
; Лог сообщений (как в консоли): Dv_Busy начинает строку "Saving...", Dv_Ok / Dv_Error дописывают
; к ней итог ("Saving... OK"); без начатой строки - новая строка. Старые уезжают вверх

; HL - текст ошибки
Dv_Error
        ld a,CLR_ERROR
        jr Lg_End
; HL - текст "готово"
Dv_Ok
        ld a,CLR_OK
; HL - текст, A - цвет (роль CLR_*): начатая строка - дописать, иначе - новая
Lg_End
        ld (Lg_C),a
        ld a,(Lg_Open)
        or a
        jr nz,.app
        call Lg_Push
        jr .put
.app    xor a                       ; строка закрыта
        ld (Lg_Open),a
        push hl
        ld hl,Txt_LgSp
        call Lg_Add
        pop hl
.put    call Lg_Add
        ld a,(Lg_C)                 ; цвет строки - по последнему
        ld (Lg_Clr+LG_LINES-1),a
        ld a,1
        ld (Dv_Dirty),a
        ret

; HL - текст "идёт работа": новая строка и сразу на экран (дальше долгая операция, кадры не крутятся)
Dv_Busy
        push hl
        ld a,(Lg_Open)              ; прошлая не закрыта - значит, прошла: "OK"
        or a
        ld hl,Txt_LgOk
        call nz,Dv_Ok
        pop hl
        call Dv_Ok
        ld a,1
        ld (Lg_Open),a
        call Dv_Draw
        jp Scr_Show                 ; сразу на экран (двойной буфер)

; Строки вверх, последняя - пустая. HL цел
Lg_Push
        push hl
        ld hl,Lg_Txt+LG_W+1
        ld de,Lg_Txt
        ld bc,(LG_LINES-1)*(LG_W+1)
        ldir
        ld hl,Lg_Clr+1
        ld de,Lg_Clr
        ld bc,LG_LINES-1
        ldir
        xor a
        ld (LG_LAST),a
        ld (Lg_Len),a
        pop hl
        ret

; Текст HL - в конец последней строки (не длиннее LG_W)
Lg_Add
        ld a,(Lg_Len)
        ld e,a
        ld d,0
        push hl
        ld hl,LG_LAST
        add hl,de
        ex de,hl
        pop hl
.c      ld a,(Lg_Len)
        cp LG_W
        jr nc,.end
        ld a,(hl)
        or a
        jr z,.end
        ld (de),a
        inc hl
        inc de
        ld a,(Lg_Len)
        inc a
        ld (Lg_Len),a
        jr .c
.end    xor a
        ld (de),a
        ret

; A - 2 hex в конец последней строки
Lg_Hex
        ld de,Lg_HexT
        call Ck_Hex
        xor a
        ld (de),a
        ld hl,Lg_HexT
        jp Lg_Add

; Лог на экран: строки с MSG_Y, хвост строки - пробелами (старое не остаётся)
Lg_Draw
        ld hl,Lg_Txt
        ld de,FP_L+256*(DV_SCR_H+MSG_Y)
        ld a,(Lg_Clr)
        call .one
        ld hl,Lg_Txt+LG_W+1
        ld de,FP_L+256*(DV_SCR_H+MSG_Y+1)
        ld a,(Lg_Clr+1)
        call .one
        ld hl,Lg_Txt+2*(LG_W+1)
        ld de,FP_L+256*(DV_SCR_H+MSG_Y+2)
        ld a,(Lg_Clr+2)
.one    push de
        add a,low THEME_ATTR
        ld e,a
        ld d,high THEME_ATTR
        ld a,(de)
        ld c,a
        pop de
        call PutStr
.sp     ld a,e
        cp FP_L+LG_W
        ret nc
        ld a,' '
        call PutCh
        jr .sp
    ASSERT LG_LINES == 3
    ASSERT FP_L+LG_W < FP_X+FP_W

; Ошибка драйвера: код - в A (после Disk_Call). CF на выходе
Dv_Disk_Err
Dv_Disk_Code
        push af
        ld hl,Txt_DiskErr
        call Dv_Error
        pop af
        push af
        ld (Dv_Msg_Code),a
        call Lg_Hex                 ; код - в строку
        pop af
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
Txt_Check       db "[ Check ]",0
Txt_New         db "[ New ]",0
Txt_ExitWC      db "[ Exit WC ]",0
Txt_AskNew      db "New song? (Y/N)",0
Txt_AskWC       db "Exit to WC? (Y/N)",0
Txt_Exists      db "overwrite? (Y/N)",0
Txt_SvYes       db "Y",0
Txt_SvNo        db "N",0
Txt_CmpOff      db "[ ] Compare",0  ; одной длины: старое не остаётся; #FB - галочка CP866
Txt_CmpOn       db "[",#FB,"] Compare",0
Txt_Dir         db "  <DIR>",0
Txt_FT2         db "FT2",0
Txt_PT3         db "PT3",0
Txt_PT2         db "PT2",0
Txt_FTCn        db "FTC",0
Txt_Other       db "-",0
Txt_NoCard      db "No SD card / no FAT32",0
Txt_NotFound    db "Not found",0
Txt_NotFT2      db "Not an FT2 file",0
Txt_TooBig      db "File too big",0
Txt_CantLoad    db "Load: FT2 PT3 PT2 FTC only",0
Txt_NoName      db "Type a name",0
Txt_Saved       db "OK",0
Txt_LgOk        db "OK",0
Txt_LgSp        db " ",0
Txt_Saving      db "Saving...",0
Txt_Loading     db "Loading...",0
Txt_DiskErr     db "Disk error #",0
Txt_Empty       db "Empty dir",0
Txt_Full        db "Too many files: not all shown",0


    ENDMODULE

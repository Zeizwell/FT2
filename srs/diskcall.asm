; =========================================================================
; ДИСК: вызов FAT32-драйвера из коре (переходник - srs/disk.asm, окно 2)
; =========================================================================
; Disk_Call: IXL - номер входа драйвера (FAT32_xxx = #4000 + номер*3,
;            drivers/fat32/include/fat32.inc), IXH - сколько имён скопировать
;            в окно 2 (0; 1 - имя по HL; 2 - и по DE: переименование),
;            A/BC/DE/HL - параметры драйвера. Буфер данных - в окне 3, его ставит
;            вызывающий.
; Выход: AF/BC/DE/HL - что вернул драйвер; IX, IY целы. Окна 0..3 - как были.
; На время вызова DI (музыка стоит), в конце EI.
; =========================================================================
Dk_Win2         db 0

Disk_Call
        di
        push af
        push bc
        ld a,(SV_PAGES+2)           ; окно 2 - переходнику (тень не трогаем: вернём)
        ld (Dk_Win2),a
        ld bc,PAGE0+#200
        ld a,PAGE_DISK_APP
        out (c),a
        pop bc
        pop af
        jp Ad_Entry

; Возврат из переходника: на стеке результат AF, BC, DE, HL
Disk_Ret
        ld a,(Dk_Win2)              ; окно 2 - как было
        ld bc,PAGE0+#200
        out (c),a
        pop af
        pop bc
        pop de
        pop hl
        ei
        ret

;-------- Подготовить карту: подключить порт SD-ZC, инициализировать, найти FAT32.
; Выход: Z - готово, NZ - ошибка (A - код драйвера)
DK_BIND         equ 0               ; номера входов (drivers/fat32/include/fat32.inc)
DK_DEVICE_INIT  equ 1
DK_MOUNT        equ 3
DK_SET_ROOT     equ 32
DK_FIND         equ 59
DK_READ         equ 48
DK_CREATE       equ 72
DK_APPEND       equ 76
DK_CLOSE        equ 35
FAT_PORT_TABLE  equ #3900           ; таблица порта SD-ZC в рабочей странице драйвера

Disk_Mount
        ld ix,DK_BIND               ; IXH = 0 - без имён
        ld hl,FAT_PORT_TABLE
        xor a                       ; устройство 0
        call Disk_Call
        ld ix,DK_DEVICE_INIT
        ld a,(Dk_Dev)               ; устройство порта: 0 - SD, 1 - SD2 (Z-Controller)
        call Disk_Call
        ret nz
        ld ix,DK_MOUNT
        jp Disk_Call

;-------- Устройство (выбор - кнопка Device в Disk, окно-список как "Select Device" в WC).
; Порт драйвера пока один - SD-ZC (drivers/fat32/ports/sdzc.asm): его init берёт номер карты
; (0 - SD, 1 - SD2). IDE Nemo / SMUC, SD NeoGS - переносить из WC (DIDENEMO, DIDESMUC, DSDNGS)
DK_DEVS_OK      equ 2               ; устройств с драйвером: 0..1
Dk_Dev          db 0                ; выбранное (номер пункта Dk_Menu)

; Окно-список устройств у мыши. Выход: A - устройство (#FF - ничего)
Dk_Choose
        ld hl,Dk_Menu
        call Win_Menu
        cp #FF
        ret z
        ld hl,Dk_Menu
        jp Wm_Item_Act              ; A - номер устройства (первый байт пункта)

Dk_Menu db 24, 7, WF_CONTEXT        ; ширина, пунктов, флаги; пункт: номер, имя
        db 1,"SD: Z-Controller",0
        db 2,"SD2: Z-Controller",0
        db 3,"IDE NEMO: Master",0
        db 4,"IDE NEMO: Slave",0
        db 5,"IDE SMUC: Master",0
        db 6,"IDE SMUC: Slave",0
        db 7,"SD: NeoGS",0
        db WIN_END

; =========================================================================
; ДИСК: переходник к FAT32-драйверу (drivers/fat32). Страница PAGE_DISK_APP, окно 2.
; =========================================================================
; Драйвер требует (drivers/fat32/README.md):
;   окно 0 - его рабочая память (PAGE_FAT_WORK, порт SD-ZC на #3900),
;   окно 1 - его код (PAGE_FAT_CODE, входы #4000 + номер*3),
;   окно 2 - код вызывающего, стек, имена и блок параметров FILEX (эта страница),
;   окно 3 - данные (буфер чтения / записи - его ставит вызывающий).
; Окна 0 и 1 у нас - коре и тулза, поэтому сам вызов идёт отсюда, из окна 2:
; коре (Disk_Call, srs/diskcall.asm) ставит эту страницу в окно 2 и прыгает сюда;
; здесь - свой стек, окна 0/1 драйверу, вызов, окна 0/1 обратно, назад в коре
; (Disk_Ret). Всё при DI: в окне 0 у драйвера буферы, IM1 там нет. Музыка стоит.
; Тени SV_PAGES лежат в окне 0 - пока оно у драйвера, порты пишем без теней.
; =========================================================================
    org #8000
disk_start

; Вход из коре: IXL - номер входа драйвера, IXH - сколько имён скопировать сюда
; (0; 1 - HL; 2 - HL и DE), A/BC/DE/HL - параметры драйвера. Окно 0 ещё коре.
Ad_Entry
        ld (Ad_SP),sp               ; свой стек - в этой странице
        ld sp,Ad_Stack
        ld (Ad_A),a
        push hl                     ; адрес JP драйвера: FAT_API + номер*3
        push de
        ld a,ixl
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,FAT_API
        add hl,de
        ld (Ad_Jp+1),hl
        pop de
        pop hl
        ld a,ixh                    ; имена из памяти вызывающего - сюда, пока
        or a                        ; окна 0/1 ещё его
        call nz,Ad_Copy_Names
        ld a,(SV_PAGES+0)           ; запомнить окна 0 и 1 (тени - в окне 0, пока оно наше)
        ld (Ad_Win0),a
        ld a,(SV_PAGES+1)
        ld (Ad_Win1),a
        push ix
        push iy
        push bc
        ld bc,PAGE0                 ; окна 0/1 - драйверу
        ld a,PAGE_FAT_WORK
        out (c),a
        inc b
        ld a,PAGE_FAT_CODE
        out (c),a
        pop bc
        ld a,(Ad_A)
Ad_Jp   call 0                      ; вход драйвера
        push af                     ; результат
        push bc
        ld bc,PAGE0                 ; окна 0/1 - обратно
        ld a,(Ad_Win0)
        out (c),a
        inc b
        ld a,(Ad_Win1)
        out (c),a
        pop bc
        pop af
        pop iy
        pop ix
        ld sp,(Ad_SP)               ; стек коре (окно 0 уже коре); флаги ld sp не портит
        push hl                     ; результат - на стек коре, Disk_Ret снимет
        push de
        push bc
        push af
        jp Disk_Ret

;-------- Имена в эту страницу: HL -> Ad_Name1, при IXH=2 ещё DE -> Ad_Name2.
; На выходе HL/DE - на копии. Портит A
Ad_Copy_Names
        push bc
        push de
        ld de,Ad_Name1
        ld bc,AD_NAME_SIZE
        ldir
        pop hl                      ; второе имя (был DE)
        ld a,ixh
        cp 2
        jr c,.one
        ld de,Ad_Name2
        ld bc,AD_NAME_SIZE
        ldir
.one    pop bc
        ld hl,Ad_Name1
        ld de,Ad_Name2
        ret

AD_NAME_SIZE    equ 64
FAT_API         equ #4000           ; таблица входов драйвера (drivers/fat32/include/fat32.inc)

Ad_SP           dw 0
Ad_A            db 0
Ad_Win0         db 0
Ad_Win1         db 0
Ad_Name1        ds AD_NAME_SIZE
Ad_Name2        ds AD_NAME_SIZE
                ds 256              ; стек переходника и драйвера
Ad_Stack

disk_end
    ASSERT disk_end <= #C000

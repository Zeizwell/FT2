PAGE_CORE0  equ #00
PAGE_CORE1  equ #01
PAGE_CORE2  equ #02
PAGE_CORE3  equ #03

PAGE_SPRITE equ #08         ; Спрайты
; Внимательно смотрим сборщик и тд, куда кто грузится через spg!
PAGE_TEXT   EQU #10         ; Текст режим, 128 символов+128 атр на строку
PAGE_FONT   EQU #11         ; Шрифты текст режима

;------------------------------------------------------------------
; Стек живёт в коре (пейдж 0, окно #0000), чтобы не пропадал при
; переключении тулз в окне 1. Растёт вниз от #3FFF.
STACK_TOP   equ #4000
STACK_SIZE  equ #200        ; #3E00..#3FFF, коре не должно сюда залезать

;------------------------------------------------------------------
; Менеджер страниц
; Номера включённых страниц хранятся в CUR_PAGES (в коре), т.к. Page0/1
; только на запись. Менять страницы ТОЛЬКО этими макросами, иначе
; CUR_PAGES разъедется с железом.
;
; MAPPAGE win,page  - включить страницу в окно win (0..3) без сохранения
; SETPAGEn page     - сохранить текущую страницу окна n на стек и включить page
; RESTPAGEn         - вернуть страницу окна n со стека
;
; SETPAGE/RESTPAGE парные, как push/pop - в одной процедуре, вложенность любая.
; page - число, регистр (a,b,c,d,e,h,l) или (hl). Портят A, BC.
; Обработчик прерывания если меняет страницы - тоже только SETPAGE/RESTPAGE.

    MACRO MAPPAGE win,page
        ld b,page
        ld a,b
        ld (CUR_PAGES+win),a    ; сначала тень, потом порт
        ld bc,PAGE0+win*#100
        out (c),a
    ENDM

    MACRO SETPAGE win,page
        ld b,page
        ld a,(CUR_PAGES+win)
        push af
        ld a,b
        ld (CUR_PAGES+win),a
        ld bc,PAGE0+win*#100
        out (c),a
    ENDM

    MACRO RESTPAGE win
        pop af
        ld (CUR_PAGES+win),a
        ld bc,PAGE0+win*#100
        out (c),a
    ENDM

    MACRO SETPAGE0 page
        SETPAGE 0,page
    ENDM
    MACRO SETPAGE1 page
        SETPAGE 1,page
    ENDM
    MACRO SETPAGE2 page
        SETPAGE 2,page
    ENDM
    MACRO SETPAGE3 page
        SETPAGE 3,page
    ENDM

    MACRO RESTPAGE0
        RESTPAGE 0
    ENDM
    MACRO RESTPAGE1
        RESTPAGE 1
    ENDM
    MACRO RESTPAGE2
        RESTPAGE 2
    ENDM
    MACRO RESTPAGE3
        RESTPAGE 3
    ENDM

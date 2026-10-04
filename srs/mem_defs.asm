PAGE_CORE0  equ #00
PAGE_CORE1  equ #01
PAGE_CORE2  equ #02
PAGE_CORE3  equ #03

PAGE_TOOL_PATVIEW equ #04   ; тулза просмотра паттерна (окно 1)
PAGE_SPRITE equ #08         ; Спрайты
; Внимательно смотрим сборщик и тд, куда кто грузится через spg!
PAGE_TEXT   EQU #10         ; Текст режим, 128 символов+128 атр на строку
PAGE_FONT   EQU #11         ; Шрифты текст режима
PAGE_PATTERNS EQU #40       ; первая страница паттернов

;------------------------------------------------------------------
; Стек живёт в коре (пейдж 0, окно #0000), чтобы не пропадал при
; переключении тулз в окне 1. Растёт вниз от #3FFF.
; Над коре: #3C00 API, #3D00 системные переменные (см. sdk/plugin.asm).
STACK_TOP   equ #4000
STACK_SIZE  equ #200        ; #3E00..#3FFF

;------------------------------------------------------------------
; Менеджер страниц
; Номера включённых страниц хранятся в SV_PAGES (sdk/plugin.asm), т.к.
; Page0/1 только на запись. Менять страницы ТОЛЬКО макросами, иначе
; SV_PAGES разъедется с железом.
;
; SETPAGE/RESTPAGE и SETPAGE2/3, RESTPAGE2/3 - в sdk/plugin.asm.
; Здесь - то, что нужно только коре:
; MAPPAGE win,page  - включить страницу в окно win (0..3) без сохранения
; SETPAGE0/1 page, RESTPAGE0/1
;
; page - число, регистр (a,b,c,d,e,h,l) или (hl). Портят A, BC.
; Переменную - только через регистр: ld a,(var) / SETPAGE3 a
; (SETPAGE3 (var) соберётся молча, но подставит младший байт адреса!)

    MACRO MAPPAGE win,page
        ld b,page
        ld a,b
        ld (SV_PAGES+win),a     ; сначала тень, потом порт
        ld bc,PAGE0+win*#100
        out (c),a
    ENDM

    MACRO SETPAGE0 page
        SETPAGE 0,page
    ENDM
    MACRO SETPAGE1 page
        SETPAGE 1,page
    ENDM
    MACRO RESTPAGE0
        RESTPAGE 0
    ENDM
    MACRO RESTPAGE1
        RESTPAGE 1
    ENDM

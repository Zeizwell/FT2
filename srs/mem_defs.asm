PAGE_CORE0  equ #00
PAGE_CORE1  equ #01
PAGE_CORE2  equ #02
PAGE_CORE3  equ #03

PAGE_SPRITE equ #08         ; Спрайты
; Внимательно смотрим сборщик и тд, куда кто грузится через spg!
PAGE_TEXT   EQU #10         ; Текст режим, 128 символов+128 атр на строку
PAGE_FONT   EQU #11         ; Шрифты текст режима


; =========================================================================
; ПРОБНЫЙ МАКЕТ ЭКРАНА FX (реворк FX): текст как есть, рисуется вместо редактора FX
; (вкладка FX, Fxm_Draw в srs/instrview.asm). Править прямо здесь: строка - с первой строки
; тулзы, до 90 знаков, 0 на конце; "!" в начале - строка цветом заголовков. Конец - #FF.
; Рамки - коды CP866: #DA ┌ #BF ┐ #C0 └ #D9 ┘ #C4 ─ #B3 │; скролл #1E ▲ #1F ▼ #DB █
; Ничего не делает - только посмотреть раскладку.
; =========================================================================
Fxm_Lines
        db #DA,"FX",#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#BF,"  Name: Bass SID          Len -08+  Loop -00+",0
        db #B3,"01 Bass SID      ",#1E,#B3,"  Sweep: Tri   Start -128+   Kp",0
        db #B3,"02 Lead FM       ",#DB,#B3,"  [Clone] [Copy] [Paste] [Clear] [Unloop]      [Save] [Load]",0
        db #B3,"03 Buzz           ",#B3,0
        db #B3,"04               ",#1F,#B3,"  [ Mix ]  [ FM ]  [ Env FM ]",0
        db #C0,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#C4,#D9,0
        db 0
        db "!Rw  Mix  Max  Min  Swp  Semi  Det  Ln  Steps",0
        db "00  SID  50%   0%   24   +12   +1   2  15 00",0
        db "01  SID  50%   0%    0    +0   +1   4  15 00 15 12",0
        db "02  Buz   --   --   --    +0   +0   1  08",0
        db "03  SID  50%   0%   --    +0   +1  16  15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00",0
        db "04  ---",0
        db "05  ---",0
        db "06  ---",0
        db "07  ---",0
        db 0
        db "!FM:      Rw  FM   Semi  Det  Unit  Ln  Steps",0
        db "          00  on    +0   +1   semi   4  +0 +12  +7  +0",0
        db 0
        db "!Env FM:  Rw  EFM  Semi  Det  Unit  Ln  Steps",0
        db "          00  on    +0   +1   per    2  +0 -16",0
        db 0
        db "Max / Min / Swp - only when Ln = 2 (as Bitphase), otherwise dimmed",0
        db #FF

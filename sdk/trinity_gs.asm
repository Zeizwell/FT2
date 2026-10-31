; =========================================================================
; ZX Trinity RP-GS driver channel - SDK for Z80 programs / Канал драйвера RP-GS - SDK для программ Z80
; -------------------------------------------------------------------------
; EN: Settings, load and versions of the card through the GS ports #BB / #B3, behind the key "TRINITY".
;     No key - the card is a plain GS. For the driver program only: players do not need this file.
;     Protocol: FT2 doc/trinity-api.md 7.
; RU: Настройки, нагрузка и версии карты через порты GS #BB / #B3, за ключом "TRINITY".
;     Без ключа карта - обычный GS. Только для программы-драйвера: плеерам этот файл не нужен.
;     Протокол: FT2 doc/trinity-api.md, раздел 7.
; =========================================================================

; --- Ports / Порты
GSC_PORT_CMD    equ #BB             ; EN: write command, read status (bit 7 data, bit 0 command)
                                    ; RU: запись - команда, чтение - статус (бит 7 данные, бит 0 команда)
GSC_PORT_DAT    equ #B3             ; EN: data     RU: данные

; --- Commands / Команды - EN: numbers only here and in engine/gs/gs_ctl.h  RU: номера только здесь и в engine/gs/gs_ctl.h
GSC_KEY         equ #FB             ; EN: one key byte in #B3    RU: один байт ключа в #B3
GSC_BYTE        equ #FC             ; EN: one packet byte in #B3 RU: один байт пакета в #B3
GSC_CLOSE       equ #FD             ; EN: close the channel      RU: закрыть канал

; --- Packets / Пакеты: [code][length 2 bytes][data]
GSC_P_CFG_GET   equ #D0             ; EN: tag 4 chars -> value 4 bytes      RU: тег 4 знака -> значение 4 байта
GSC_P_CFG_SET   equ #D1             ; EN: tag, value 4 bytes -> 0 / #FF     RU: тег, значение 4 байта -> 0 / #FF
GSC_P_CFG_SAVE  equ #D2             ; EN: write to flash -> 0 / #FF         RU: записать во флеш -> 0 / #FF
GSC_P_PRESET    equ #D3             ; EN: 0 GS 1 A500 2 A1200 3 HiFi -> 0 / #FF
GSC_P_STAT      equ #D4             ; EN: -> load, peak, late, blocks...    RU: -> нагрузка, пик, опоздания, блоки...
GSC_P_STAT_RES  equ #D5             ; EN: peak and late from zero -> 0      RU: пик и опоздания с нуля -> 0
GSC_P_CURVE     equ #D6             ; EN: stage or #FF total -> 32 points   RU: ступень или #FF итог -> 32 точки
GSC_P_VERSION   equ #D7             ; EN: -> protocol, firmware 2 bytes     RU: -> протокол, прошивка 2 байта

; --- STAT answer, offsets / Ответ STAT, смещения
GSC_ST_LOAD     equ 0               ; EN: load, 2 bytes, 0.1 %              RU: нагрузка, 2 байта, 0.1 %
GSC_ST_TOP      equ 2               ; EN: peak, 2 bytes, 0.1 %              RU: пик, 2 байта, 0.1 %
GSC_ST_LATE     equ 4               ; EN: late blocks, 4 bytes              RU: опоздания, 4 байта
GSC_ST_BLOCKS   equ 8               ; EN: blocks, 4 bytes                   RU: блоки, 4 байта
GSC_ST_RATE     equ 12              ; EN: output rate, Hz, 4 bytes          RU: частота вывода, Гц, 4 байта
GSC_ST_SYSK     equ 16              ; EN: clock, kHz, 4 bytes               RU: такт, кГц, 4 байта
GSC_ST_MODE     equ 20              ; EN: mode, 1 byte                      RU: режим, 1 байт
GSC_ST_DEV      equ 21              ; EN: device, 4 chars                   RU: устройство, 4 знака

;-------- EN: A = byte: put into #B3, send command E, wait until the card takes it. C - taken, NC - no answer. Spoils A, BC
;         RU: A = байт: в #B3, команда E, ждём, пока карта возьмёт. C - взяла, NC - ответа нет. Портит A, BC
Gsc_Send
        out (GSC_PORT_DAT),a
        ld a,e
        out (GSC_PORT_CMD),a
        ld bc,0
.wait
        in a,(GSC_PORT_CMD)
        rrca
        jr nc,.taken
        dec bc
        ld a,b
        or c
        jr nz,.wait
        ret                         ; EN: or c leaves NC    RU: or c оставил NC
.taken
        scf
        ret

;-------- EN: Wait for data and read it -> A. NC - no answer. Spoils BC
;         RU: Дождаться данных и прочитать -> A. NC - ответа нет. Портит BC
Gsc_Get
        ld bc,0
.wait
        in a,(GSC_PORT_CMD)
        rlca
        jr c,.ready
        dec bc
        ld a,b
        or c
        jr nz,.wait
        ret
.ready
        in a,(GSC_PORT_DAT)
        scf
        ret

;-------- EN: Open the channel. -> A = protocol, NZ - our card; A = 0, Z - a plain GS or nothing. Spoils BC, DE, HL
;         RU: Открыть канал. -> A = протокол, NZ - наша карта; A = 0, Z - обычный GS или ничего. Портит BC, DE, HL
Gsc_Open
        ld hl,Gsc_Sign
        ld d,Gsc_Sign_N
        ld e,GSC_KEY
.key
        ld a,(hl)
        inc hl
        call Gsc_Send
        jr nc,.none
        dec d
        jr nz,.key
        call Gsc_Get
        jr nc,.none
        or a
        ret
.none
        xor a
        ret
Gsc_Sign        db "TRINITY"
Gsc_Sign_N      equ $-Gsc_Sign

;-------- EN: Close the channel: the card is a plain GS again. Spoils A
;         RU: Закрыть канал: карта снова обычный GS. Портит A
Gsc_Close
        ld a,GSC_CLOSE
        out (GSC_PORT_CMD),a
        ret

;-------- EN: HL - packet [code][length 2 bytes][data], DE - answer buffer. -> C - ok, HL - answer length;
;             NC - no answer. Save to flash answers late, the waits cover it. Spoils A, BC, DE
;         RU: HL - пакет [код][длина 2 байта][данные], DE - буфер ответа. -> C - есть, HL - длина ответа;
;             NC - ответа нет. Запись во флеш отвечает с задержкой, ожидания это покрывают. Портит A, BC, DE
Gsc_Packet
        push de
        inc hl                      ; EN: data length + 3 bytes of header   RU: длина данных + 3 байта шапки
        ld a,(hl)
        dec hl
        add a,3
        ld d,a
        ld e,GSC_BYTE
.send
        ld a,(hl)
        inc hl
        call Gsc_Send
        jr nc,.nosend
        dec d
        jr nz,.send
        pop de
        call Gsc_Get                ; EN: answer length  RU: длина ответа
        ret nc
        ld l,a
        call Gsc_Get
        ret nc
        ld h,a
        push hl
.read
        ld a,h
        or l
        jr z,.end
        call Gsc_Get
        jr nc,.fail
        ld (de),a
        inc de
        dec hl
        jr .read
.end
        pop hl
        scf
        ret
.fail
        pop hl
        or a
        ret
.nosend
        pop de
        or a
        ret

; =========================================================================
; ЭТАЛОН FTC для компаратора: плеер Fast Tracker 1.15 (Orion/DR; разбор и
; правки 1.15 - sandrowski/mayHem). Оригинал - players/FT1-15player_src.asm.
; Для сборки: без ORG и тестовой обвязки, комментарии с битой кодировкой убраны.
; Правки FT2 помечены "FT2:":
;   - Module_Addr = модуль в окне 2 (буфер файла);
;   - NoFx: глиссандо, портаменто, ретриггер выкл (наш плеер их пока не умеет);
;   - Looped - прошли точку цикла; R13W - что записано в R13 в этот кадр (#FF - ничего);
;   - баг: на роу без событий C оставался с входа, при C=0 портаменто считалось заново;
;   - в конце вывода нет EI (сравниваем без прерываний).
; Плеер сам переставляет указатели модуля на адрес (один раз) и правит свой код.
; =========================================================================
Module_Addr	equ @cmpview.CM_MOD
NoFx		db 0			; 1 - команды паттерна выкл (кроме темпа и шума)
Looped		db 0			; 1 - трек дошёл до конца (ставит плеер)
R13W		db #FF			; R13 в этот кадр (#FF - не писали)

InitModule 
		LD HL, Module_Addr
		JP Player_Init

PlayModule
		DI 
		LD HL,TiksCounter


		DEC (HL)
		JP NZ,PlayTiksToZero

		
GlobalDelay 
		LD (HL),0
		LD A,2
		EX AF,AF'
		CALL FSTXA
		LD A,C
		OR A
		JR NZ,FTRA5			; check me

FTPORTA LD A,0
		PUSH AF
FTRA2   LD A,0
		CALL PortamentoTonesTableCalc
		LD E,(HL)
		INC HL
		LD D,(HL)
		LD A,(HgthA+1)
		CALL PortamentoTonesTableCalc
		LD C,(HL)
		INC HL
		LD B,(HL)
		EX DE,HL
		POP AF
		LD E,A
		OR A
		SBC HL,BC
		LD (FSTPA39+1),HL
		LD A,#C2			;jp nz,
		JR C,FTRA3
		LD A,#CA			;jp z,
FTRA3   LD (FSTPA41),A
		LD H,0
		LD L,E
		JR C,FTRA4
		LD L,H
		LD D,L
		OR A
		SBC HL,DE

FTRA4   LD (FSTPA40+1),HL

FTRA5   LD A,2
		EX AF,AF'
		CALL FSTXB
		LD A,C
		OR A
		JR NZ,FTRB5		;check me

FTPORTB LD A,0
		PUSH AF
FTRB2   LD A,0
		CALL PortamentoTonesTableCalc
		LD E,(HL)
		INC HL
		LD D,(HL)
		LD A,(HgthB+1)
		CALL PortamentoTonesTableCalc
		LD C,(HL)
		INC HL
		LD B,(HL)
		EX DE,HL
		POP AF
		LD E,A
		OR A
		SBC HL,BC
		LD (FSTPB39+1),HL
		LD A,#C2				;jp nz,
		JR C,FTRB3
		LD A,#CA				;jp z,
FTRB3   LD (FSTPB41),A
		LD H,0
		LD L,E
		JR C,FTRB4
		LD L,H
		LD D,L
		OR A
		SBC HL,DE
FTRB4   LD (FSTPB40+1),HL

FTRB5   LD A,2
		EX AF,AF'
		CALL FSTXC
		LD A,C
		OR A
		JR NZ,PlayTiksToZero			;check me!

		
FTPORTC LD A,0
		PUSH AF
FTRC2   LD A,0
		CALL PortamentoTonesTableCalc
		LD E,(HL)
		INC HL
		LD D,(HL)
		LD A,(HgthC+1)
		CALL PortamentoTonesTableCalc
		LD C,(HL)
		INC HL
		LD B,(HL)
		EX DE,HL
		POP AF
		LD E,A
		OR A
		SBC HL,BC
		LD (FSTPC39+1),HL
		LD A,#C2			;jp nz,
		JR C,FTRC3
		LD A,#CA			;jp z,
FTRC3   LD (FSTPC41),A
		LD H,0
		LD L,E
		JR C,FTRC4
		LD L,H
		LD D,L
		OR A
		SBC HL,DE
FTRC4   LD (FSTPC40+1),HL

;-------------------------------------------------------------
PlayTiksToZero
		CALL ImagAddrA
		CALL ImagAddrB
		CALL ImagAddrC
		LD A,LX
		LD (AyR7_Mixer),A
		XOR A
		JP PlayerOuter
;-------------------------------------------------------------

PattsHeightsAddr
		LD HL,0
		LD A,(HL)
		INC HL
		LD C,(HL)
		ADD A,A
		JR NC,MoPatH
		LD A,1				; FT2: конец трека - метка для компаратора
		LD (Looped),A
ModuleLoopTo
		LD HL,0
		LD A,(HL)
		INC HL
		LD C,(HL)
		ADD A,A
MoPatH  INC HL
		LD (PattsHeightsAddr+1),HL
		LD L,A
		LD H,0
		ADD A,A
		ADD A,L
		LD L,A
		JR NC,PaPoThg
		INC H
PaPoThg	LD DE,0
		ADD HL,DE
		LD A,C
		LD (NoteAddHeightA+1),A
		LD (NoteAddHeightB+1),A
		LD (NoteAddHeightC+1),A
		LD (ModLpSp+1),SP
		LD SP,HL
		POP HL
		LD (ChkHgtA+1),HL
		EX DE,HL
		POP HL
		LD (CntDistB+1),HL
		POP HL
		LD (CntDistC+1),HL
ModLpSp	LD SP,0
		RET 



;-------------------------------------------------------------
FSTXA
		LD C,1				; FT2: роу без событий - C не 0, иначе GlobalDelay
						;   считает портаменто по старым данным (баг: C с входа)
		LD HL,CntDistNextNoteA
		DEC (HL)
		RET P
		INC (HL)
ChkHgtA  LD DE,0
		LD A,(DE)
		INC A
		CALL Z,PattsHeightsAddr
		CALL ContChekParamsA
		LD (ChkHgtA+1),DE
		RET

DistToNextNoteA  
		LD (CntDistNextNoteA),A
		LD C,1
		RET 

ImagShiftsAddrTblA
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (ImShA+1),A
		XOR A
		LD B,(HL)
		INC B
		INC HL
		LD C,A
		LD (ImShHlA+1),BC
		LD (ImagAddrA+1),HL
		LD (ImSh7A+1),A
		LD (ImSh6A+1),A
		JR ContChekParamsA

SampShiftsAddrTblA
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (FSTPA12+1),A
		LD A,(HL)
		INC A
		INC HL
		LD (FSTPA11+2),A
		LD (SamplAddrA+1),HL
		JR ContChekParamsA

SetEnvelopeA
		JR Z,FSTXA7
		CP #F
		JR Z,SetEnvelopeFA
FTPXA5A LD (AyR13_EnvelopeShape),A
		LD A,#37			;SCF
		LD (EnvFormPresetA),A
		LD A,(DE)
		INC DE
		LD L,A
		LD A,(DE)
		LD H,A
		LD (FSTPA30+1),HL
		OR #FF
		LD (SetShapeOrNo+1),A
		LD L,A
		LD H,A
		LD (PlayCont+1),HL
		JR ChekNuParamsA

SetEnvelopeFA  
		LD A,#B7			; OR A
		LD (EnvFormPresetA),A
		JR ContChekParamsA

FSTXA7  LD A,#B7			; OR A
		LD (StEnvA),A
		JP FSTXA17

NoFxGlA	INC DE				; FT2: пропуск параметра глиссандо
ChekNuParamsA
		INC DE
ContChekParamsA
		LD A,(DE)
		INC DE
		ADD A,#13
		ADD A,#21
		JR C,ImagShiftsAddrTblA
		ADD A,#6C
		JR C,NoteParamsA
		ADD A,#20
		JR C,DistToNextNoteA
		ADD A,#10
		JR C,SetEnvelopeA
		ADD A,#10
		JR C,SetVolumeNoteA
		ADD A,#20
		JR C,SampShiftsAddrTblA
		ADD A,#13
		JR Z,ComGlideUpDownA
		DEC A
		JR Z,ComPortamentoA
		DEC A
		JR Z,ComNoiseA
		LD A,(DE)
		LD (TiksCounter),A
		LD (GlobalDelay+1),A
		JR ChekNuParamsA

ComPortamentoA
		LD A,(NoFx)			; FT2: команды выкл - параметр пропустить
		OR A
		JR NZ,ChekNuParamsA
		LD A,(DE)
		LD (FTPORTA+1),A
		XOR A
		EX AF,AF'
		JR ChekNuParamsA

ComGlideUpDownA
		LD A,(NoFx)			; FT2: команды выкл - два байта пропустить
		OR A
		JR NZ,NoFxGlA
		LD A,(DE)
		LD L,A
		INC DE
		LD A,(DE)
		LD H,A
		LD (FSTPA40+1),HL
		LD A,1
		EX AF,AF'
		JR ChekNuParamsA

ComNoiseA 
		LD A,(DE)
		CP #FE
		JR Z,SetRetrigMarkerA
		LD (AddNoisePitchA+1),A
		JR ChekNuParamsA

SetRetrigMarkerA
		LD A,(NoFx)			; FT2: команды выкл - ретриггер не ставить
		OR A
		JR NZ,ChekNuParamsA
		LD A,1
		LD (AyRetriggerMarker),A
		JR ChekNuParamsA

SetVolumeNoteA
		CALL CountVolume
		LD (SetVolumeFromTableA+1),HL
		JP ContChekParamsA

NoteParamsA
		PUSH AF
		LD A,(HgthA+1)
		LD (FTRA2+1),A
		POP AF

NoteAddHeightA 
		ADD A,0
		LD (HgthA+1),A
		LD A,#37				;SCF
		LD (StEnvA),A

FSTXA17
		XOR A
		LD (FSTPA11+1),A
		LD (FSTPA14+1),A
		LD (FSTPA21+1),A
		LD (ImSh7A+1),A
		LD (ImSh6A+1),A
		LD (ImShHlA+1),A
		LD H,A
		LD L,A
		LD (FSTPA18+1),HL
		LD (FSTPA28+1),HL
		EX AF,AF'
		LD C,A
		OR A
		RET Z
		LD (FSTPA39+1),HL
		DEC A
		LD A,#C3				;jp
		LD (FSTPA41),A
		RET Z
		LD (FSTPA40+1),HL
		RET 

ImagAddrA
		LD DE,0
ImShHlA  LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPA3
ImShA	LD L,0
		LD A,L
FSTPA3  INC L
		LD (ImShHlA+1),HL
		ADD A,A
		ADD A,E
		LD E,A
		JR NC,FSTPA4
		INC D
FSTPA4  EX DE,HL
		LD (FSTPA35+1),SP
		LD SP,HL
		POP BC
ImSh6A  LD A,0
		ADD A,B
		BIT 6,C
		JR Z,FSTPA6
		LD (ImSh6A+1),A
FSTPA6  LD (FSTPA37+1),A

ImSh7A
		LD A,0
		ADD A,C
		BIT 7,C
		JR Z,FSTPA8
		LD (ImSh7A+1),A
FSTPA8  LD (FSTPA17+1),A
StEnvA  NOP 
		JP NC,FSTPA43


SamplAddrA
		LD DE,0
FSTPA11 LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPA13
FSTPA12 LD L,0
		LD A,L
FSTPA13 INC L
		LD (FSTPA11+1),HL
		LD L,A
		LD C,A
		LD H,0
		LD B,H
		ADD HL,HL
		ADD HL,HL
		ADD HL,BC
		ADD HL,DE
		LD SP,HL
FSTPA14 LD A,0
		POP BC
		DEC SP
		ADD A,C
		BIT 7,C
		JR Z,FSTPA15
		LD (FSTPA14+1),A
FSTPA15 BIT 6,C
		LD E,#FF
		JR NZ,FSTPA18
AddNoisePitchA
		ADD A,0
FSTPA17 ADD A,0
		LD (AyR6_NoisePitch),A
		RES 3,E
FSTPA18 LD HL,0
		POP BC
		ADD HL,BC
		BIT 7,B
		JR Z,FSTPA19
		LD (FSTPA18+1),HL
FSTPA19 BIT 6,B
		JR NZ,FSTPA20
		RES 0,E
FSTPA20 LD LX,E
		LD (FSTPA38+1),HL
		POP BC
		XOR A
FSTPA21 LD D,0
		BIT 5,C
		JR Z,FSTPA25
		DEC A
		BIT 4,C
		JR NZ,FSTPA22
		AND 1
FSTPA22 ADD A,D
		JP P,FSTPA23
		CP #F1
		ADC A,0
		JR FSTPA24
FSTPA23 CP #10
		ADC A,#FF
FSTPA24 LD (FSTPA21+1),A
		LD D,A
FSTPA25 LD A,C
		AND #F
		ADD A,D
		JP P,FSTPA26
		XOR A
FSTPA26 CP #10
		JR C,FSTPA27
		LD A,#F
FSTPA27 LD E,A
FSTPA28 LD HL,0
		LD D,C
		LD C,B
		RLC B
		SBC A,A
		LD B,A
		ADD HL,BC
		BIT 7,D
		JR Z,FSTPA29
		LD (FSTPA28+1),HL
FSTPA29 OR A
		LD C,L
		LD B,H
FSTPA30 LD HL,0
		SBC HL,BC
		XOR A
		BIT 6,D
		JR Z,FSTPA32
EnvFormPresetA 
		NOP 
		JR NC,FSTPA32
		LD (AyR11_EnvelopeFine),HL
		OR #10
FSTPA32 LD D,0

SetVolumeFromTableA
		LD HL,0
		ADD HL,DE
		OR (HL)

FSTPA34	LD (AyR8_ChannelAvolume),A
FSTPA35	LD SP,0
HgthA	LD A,0
FSTPA37	ADD A,0
FSTPA38	LD DE,0
		CALL CountToneX
FSTPA39	LD HL,0
FSTPA40	LD BC,0
		ADD HL,BC
		LD (FSTPA39+1),HL
		BIT 7,H
FSTPA41	JP FSTPA42			;jp z ; jp nz;
		ADD HL,DE
		LD (AyR0_ChannelAfinePitch),DE
		LD HL,0
		LD (FSTPA39+1),HL
		LD (FSTPA40+1),HL
		RET

FSTPA42 ADD HL,DE
		LD (AyR0_ChannelAfinePitch),HL
		RET 

FSTPA43 XOR A
		LD LX,#FF
		JR FSTPA34

;-------------------------------------------------------------
FSTXB
		LD C,1				; FT2: роу без событий - C не 0, иначе GlobalDelay
						;   считает портаменто по старым данным (баг: C с входа)
		LD HL,CntDistNextNoteB
		DEC (HL)
		RET P
		INC (HL)
CntDistB  LD DE,0
		CALL ContChekParamsB
		LD (CntDistB+1),DE
		RET 

DistToNextNoteB
		LD (CntDistNextNoteB),A
		LD C,1
		RET 

ImagShiftsAddrTblB
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (ImShB+1),A
		XOR A
		LD B,(HL)
		INC B
		INC HL
		LD C,A
		LD (ImShHlB+1),BC
		LD (ImagAddrB+1),HL
		LD (ImSh7B+1),A
		LD (ImSh6B+1),A
		JR ContChekParamsB

SampShiftsAddrTblB
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (FSTPB12+1),A
		LD A,(HL)
		INC A
		INC HL
		LD (FSTPB11+2),A
		LD (SamplAddrB+1),HL
		JR ContChekParamsB
		
SetEnvelopeB
		JR Z,FSTXB7
		CP #F
		JR Z,FSTXB6
		LD (AyR13_EnvelopeShape),A
		LD A,#37			;SCF
		LD (EnvFormPresetB),A
		LD A,(DE)
		INC DE
		LD L,A
		LD A,(DE)
		LD H,A
		LD (FSTPB30+1),HL
		OR #FF
		LD (SetShapeOrNo+1),A
		LD L,A
		LD H,A
		LD (PlayCont+1),HL
		JR ChekNuParamsB

FSTXB6  LD A,#B7			; OR A
		LD (EnvFormPresetB),A
		JR ContChekParamsB

FSTXB7  LD A,#B7			; OR A
		LD (StEnvB),A
		JP FSTXB17

NoFxGlB	INC DE				; FT2: пропуск параметра глиссандо
ChekNuParamsB
		INC DE
ContChekParamsB
		LD A,(DE)
		INC DE
		ADD A,#13
		ADD A,#21
		JR C,ImagShiftsAddrTblB
		ADD A,#6C
		JR C,FSTXB15
		ADD A,#20
		JR C,DistToNextNoteB
		ADD A,#10
		JR C,SetEnvelopeB
		ADD A,#10
		JR C,SetVolumeNoteB
		ADD A,#20
		JR C,SampShiftsAddrTblB
		ADD A,#13
		JR Z,ComGlideUpDownB
		DEC A
		JR Z,ComPortamentoB
		DEC A
		JR Z,ComNoiseB
		LD A,(DE)
		LD (TiksCounter),A
		LD (GlobalDelay+1),A
		JR ChekNuParamsB

ComPortamentoB
		LD A,(NoFx)			; FT2: команды выкл - параметр пропустить
		OR A
		JR NZ,ChekNuParamsB
		LD A,(DE)
		LD (FTPORTB+1),A
		XOR A
		EX AF,AF'
		JR ChekNuParamsB

ComGlideUpDownB
		LD A,(NoFx)			; FT2: команды выкл - два байта пропустить
		OR A
		JR NZ,NoFxGlB
		LD A,(DE)
		LD L,A
		INC DE
		LD A,(DE)
		LD H,A
		LD (FSTPB40+1),HL
		LD A,1
		EX AF,AF'
		JR ChekNuParamsB

ComNoiseB LD A,(DE)
		CP #FE
		JR Z,SetRetrigMarkerB
		LD (AddNoisePitchB+1),A
		JR ChekNuParamsB

SetRetrigMarkerB
		LD A,(NoFx)			; FT2: команды выкл - ретриггер не ставить
		OR A
		JR NZ,ChekNuParamsB
		LD A,2
		LD (AyRetriggerMarker),A
		JR ChekNuParamsB

SetVolumeNoteB
		CALL CountVolume
		LD (SetVolumeFromTableB+1),HL
		JP ContChekParamsB






FSTXB15 PUSH AF
		LD A,(HgthB+1)
		LD (FTRB2+1),A
		POP AF

NoteAddHeightB
		ADD A,0
		LD (HgthB+1),A

		LD A,#37		;SCF
		LD (StEnvB),A

FSTXB17 XOR A
		LD (FSTPB11+1),A
		LD (FSTPB14+1),A
		LD (FSTPB21+1),A
		LD (ImSh7B+1),A
		LD (ImSh6B+1),A
		LD (ImShHlB+1),A
		LD H,A
		LD L,A
		LD (FSTPB18+1),HL
		LD (FSTPB28+1),HL
		EX AF,AF'
		LD C,A
		OR A
		RET Z
		LD (FSTPB39+1),HL
		DEC A
		LD A,#C3				;jp
		LD (FSTPB41),A
		RET Z
		LD (FSTPB40+1),HL
		RET 

ImagAddrB
		LD DE,0
ImShHlB  LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPB3
ImShB  LD L,0
		LD A,L
FSTPB3  INC L
		LD (ImShHlB+1),HL
		ADD A,A
		ADD A,E
		LD E,A
		JR NC,FSTPB4
		INC D
FSTPB4  EX DE,HL
		LD (FSTPB35+1),SP
		LD SP,HL
		POP BC
ImSh6B  LD A,0
		ADD A,B
		BIT 6,C
		JR Z,FSTPB6
		LD (ImSh6B+1),A
FSTPB6  LD (FSTPB37+1),A
ImSh7B  LD A,0
		ADD A,C
		BIT 7,C
		JR Z,FSTPB8
		LD (ImSh7B+1),A
FSTPB8  LD (FSTPB17+1),A
StEnvB  NOP 
		JP NC,FSTPB43
		
		
SamplAddrB
		LD DE,0
FSTPB11 LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPB13
FSTPB12 LD L,0
		LD A,L
FSTPB13 INC L
		LD (FSTPB11+1),HL
		LD L,A
		LD C,A
		LD H,0
		LD B,H
		ADD HL,HL
		ADD HL,HL
		ADD HL,BC
		ADD HL,DE
		LD SP,HL
FSTPB14 LD A,0
		POP BC
		DEC SP
		ADD A,C
		BIT 7,C
		JR Z,FSTPB15
		LD (FSTPB14+1),A
FSTPB15 BIT 6,C
		LD E,LX
		JR NZ,FSTPB18

AddNoisePitchB
		ADD A,0
FSTPB17 ADD A,0
		LD (AyR6_NoisePitch),A
		RES 4,E
FSTPB18 LD HL,0
		POP BC
		ADD HL,BC
		BIT 7,B
		JR Z,FSTPB19
		LD (FSTPB18+1),HL
FSTPB19 BIT 6,B
		JR NZ,FSTPB20
		RES 1,E
FSTPB20 LD LX,E
		LD (FSTPB38+1),HL
		POP BC
		XOR A
FSTPB21 LD D,0
		BIT 5,C
		JR Z,FSTPB25
		DEC A
		BIT 4,C
		JR NZ,FSTPB22
		AND 1
FSTPB22 ADD A,D
		JP P,FSTPB23
		CP #F1
		ADC A,0
		JR FSTPB24
FSTPB23 CP #10
		ADC A,#FF
FSTPB24 LD (FSTPB21+1),A
		LD D,A
FSTPB25 LD A,C
		AND #F
		ADD A,D
		JP P,FSTPB26
		XOR A
FSTPB26 CP #10
		JR C,FSTPB27
		LD A,#F
FSTPB27 LD E,A
FSTPB28 LD HL,0
		LD D,C
		LD C,B
		RLC B
		SBC A,A
		LD B,A
		ADD HL,BC
		BIT 7,D
		JR Z,FSTPB29
		LD (FSTPB28+1),HL
FSTPB29 OR A
		LD C,L
		LD B,H
FSTPB30 LD HL,0
		SBC HL,BC
		XOR A
		BIT 6,D
		JR Z,FSTPB32

EnvFormPresetB
		NOP 
		JR NC,FSTPB32
		LD (AyR11_EnvelopeFine),HL
		OR #10
FSTPB32 LD D,0

SetVolumeFromTableB
		LD HL,0
		ADD HL,DE
		OR (HL)
FSTPB34	LD (AyR9_ChannelBvolume),A
FSTPB35	LD SP,0
HgthB	LD A,0
FSTPB37	ADD A,0
FSTPB38	LD DE,0
		CALL CountToneX
FSTPB39	LD HL,0
FSTPB40	LD BC,0
		ADD HL,BC
		LD (FSTPB39+1),HL
		BIT 7,H
FSTPB41	JP FSTPB42				;jp z; jp nz; jp

		ADD HL,DE
		LD (AyR2_ChannelBfinePitch),DE
		LD HL,0
		LD (FSTPB39+1),HL
		LD (FSTPB40+1),HL
		RET

FSTPB42	ADD HL,DE
		LD (AyR2_ChannelBfinePitch),HL
		RET

FSTPB43	LD A,LX
		OR #12
		LD LX,A

		XOR A
		JR FSTPB34



;-------------------------------------------------------------
FSTXC
		LD C,1				; FT2: роу без событий - C не 0, иначе GlobalDelay
						;   считает портаменто по старым данным (баг: C с входа)
		LD HL,CntDistNextNoteC
		DEC (HL)
		RET P
		INC (HL)
CntDistC  LD DE,0
		CALL ContChekParamsC
		LD (CntDistC+1),DE
		RET
		
DistToNextNoteC
		LD (CntDistNextNoteC),A
		LD C,1
		RET

ImagShiftsAddrTblC
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (ImShC+1),A
		XOR A
		LD B,(HL)
		INC B
		INC HL
		LD C,A
		LD (ImShHlC+1),BC
		LD (ImagAddrC+1),HL
		LD (ImSh7C+1),A
		LD (ImSh6C+1),A
		JR ContChekParamsC

SampShiftsAddrTblC
		LD HL,0
		CALL ImSmCntShft
		INC HL
		LD A,(HL)
		INC HL
		LD (FSTPC12+1),A
		LD A,(HL)
		INC A
		INC HL
		LD (FSTPC11+2),A
		LD (SamplAddrC+1),HL
		JR ContChekParamsC

SetEnvelopeC
		JR Z,FSTXC7
		CP #F
		JR Z,FSTXC6
		LD (AyR13_EnvelopeShape),A
		LD A,#37		;SCF
		LD (EnvFormPresetC),A
		LD A,(DE)
		INC DE
		LD L,A
		LD A,(DE)
		LD H,A
		LD (FSTPC30+1),HL
		OR #FF
		LD (SetShapeOrNo+1),A
		LD L,A
		LD H,A
		LD (PlayCont+1),HL
		JR ChekNuParamsC
		
FSTXC6  LD A,#B7			; OR A
		LD (EnvFormPresetC),A
		JR ContChekParamsC

FSTXC7  LD A,#B7			; OR A
		LD (StEnvC),A
		JP FSTXC17

NoFxGlC	INC DE				; FT2: пропуск параметра глиссандо
ChekNuParamsC
		INC DE
ContChekParamsC
		LD A,(DE)
		INC DE
		ADD A, #13
		ADD A, #21
		JR C,ImagShiftsAddrTblC
		ADD A, #6C
		JR C,FSTXC15
		ADD A, #20
		JR C,DistToNextNoteC
		ADD A, #10
		JR C,SetEnvelopeC
		ADD A, #10
		JR C,SetVolumeNoteC
		ADD A, #20
		JR C,SampShiftsAddrTblC
		ADD A, #13
		JR Z,ComGlideUpDownC
		DEC A
		JR Z,ComPortamentoC
		DEC A
		JR Z,ComNoiseC
		LD A,(DE)
		LD (TiksCounter),A
		LD (GlobalDelay+1),A
		JR ChekNuParamsC

ComPortamentoC
		LD A,(NoFx)			; FT2: команды выкл - параметр пропустить
		OR A
		JR NZ,ChekNuParamsC
		LD A,(DE)
		LD (FTPORTC+1),A
		XOR A
		EX AF,AF'
		JR ChekNuParamsC

ComGlideUpDownC
		LD A,(NoFx)			; FT2: команды выкл - два байта пропустить
		OR A
		JR NZ,NoFxGlC
		LD A,(DE)
		LD L,A
		INC DE
		LD A,(DE)
		LD H,A
		LD (FSTPC40+1),HL
		LD A,1
		EX AF,AF'
		JR ChekNuParamsC

ComNoiseC
		LD A,(DE)
		CP #FE
		JR Z,SetRetrigMarkerC
		LD (AddNoisePitchC+1),A
		JR ChekNuParamsC

SetRetrigMarkerC
		LD A,(NoFx)			; FT2: команды выкл - ретриггер не ставить
		OR A
		JR NZ,ChekNuParamsC
		LD A,3
		LD (AyRetriggerMarker),A
		JR ChekNuParamsC

SetVolumeNoteC
		CALL CountVolume
		LD (SetVolumeFromTableC+1),HL
		JP ContChekParamsC

FSTXC15 PUSH AF
		LD A,(HgthC+1)
		LD (FTRC2+1),A
		POP AF

NoteAddHeightC
		ADD A,0
		LD (HgthC+1),A
		LD A,#37		;SCF
		LD (StEnvC),A

FSTXC17 XOR A
		LD (FSTPC11+1),A
		LD (FSTPC14+1),A
		LD (FSTPC21+1),A
		LD (ImSh7C+1),A
		LD (ImSh6C+1),A
		LD (ImShHlC+1),A
		LD H,A
		LD L,A
		LD (FSTPC18+1),HL
		LD (FSTPC28+1),HL
		EX AF,AF'
		LD C,A
		OR A
		RET Z
		LD (FSTPC39+1),HL
		DEC A
		LD A,#C3				;jp
		LD (FSTPC41),A
		RET Z
		LD (FSTPC40+1),HL
		RET
		
ImagAddrC   
		LD DE,0
ImShHlC
		LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPC3
ImShC  LD L,0
		LD A,L
FSTPC3  INC L
		LD (ImShHlC+1),HL
		ADD A,A
		ADD A,E
		LD E,A
		JR NC,FSTPC4
		INC D
FSTPC4  EX DE,HL
		LD (FSTPC35+1),SP
		LD SP,HL
		POP BC
ImSh6C  LD A,0
		ADD A,B
		BIT 6,C
		JR Z,FSTPC6
		LD (ImSh6C+1),A
FSTPC6  LD (FSTPC37+1),A
ImSh7C  LD A,0
		ADD A,C
		BIT 7,C
		JR Z,FSTPC8
		LD (ImSh7C+1),A
FSTPC8  LD (FSTPC17+1),A
StEnvC  NOP 
		JP NC,FSTPC43


SamplAddrC
		LD DE,0
FSTPC11 LD HL,0
		LD A,L
		CP H
		JR NZ,FSTPC13
FSTPC12 LD L,0
		LD A,L
FSTPC13 INC L
		LD (FSTPC11+1),HL
		LD L,A
		LD C,A
		LD H,0
		LD B,H
		ADD HL,HL
		ADD HL,HL
		ADD HL,BC
		ADD HL,DE
		LD SP,HL
FSTPC14 LD A,0
		POP BC
		DEC SP
		ADD A,C
		BIT 7,C
		JR Z,FSTPC15
		LD (FSTPC14+1),A
FSTPC15 BIT 6,C
		LD E,LX
		JR NZ,FSTPC18

AddNoisePitchC
		ADD A,0
FSTPC17 ADD A,0
		LD (AyR6_NoisePitch),A
		RES 5,E
FSTPC18 LD HL,0
		POP BC
		ADD HL,BC
		BIT 7,B
		JR Z,FSTPC19
		LD (FSTPC18+1),HL
FSTPC19 BIT 6,B
		JR NZ,FSTPC20
		RES 2,E
FSTPC20 LD LX,E
		LD (FSTPC38+1),HL
		POP BC
		XOR A
FSTPC21 LD D,0
		BIT 5,C
		JR Z,FSTPC25
		DEC A
		BIT 4,C
		JR NZ,FSTPC22
		AND 1
FSTPC22 ADD A,D
		JP P,FSTPC23
		CP #F1
		ADC A,0
		JR FSTPC24
FSTPC23 CP #10
		ADC A,#FF
FSTPC24 LD (FSTPC21+1),A
		LD D,A
FSTPC25 LD A,C
		AND #F
		ADD A,D
		JP P,FSTPC26
		XOR A
FSTPC26 CP #10
		JR C,FSTPC27
		LD A,#F
FSTPC27 LD E,A
FSTPC28 LD HL,0
		LD D,C
		LD C,B
		RLC B
		SBC A,A
		LD B,A
		ADD HL,BC
		BIT 7,D
		JR Z,FSTPC29
		LD (FSTPC28+1),HL
FSTPC29 OR A
		LD C,L
		LD B,H
FSTPC30 LD HL,0
		SBC HL,BC
		XOR A
		BIT 6,D
		JR Z,FSTPC32

EnvFormPresetC
		NOP 
		JR NC,FSTPC32
		LD (AyR11_EnvelopeFine),HL
		OR #10
FSTPC32 LD D,0

SetVolumeFromTableC
		LD HL,0
		ADD HL,DE
		OR (HL)
FSTPC34 LD (AyR10_ChannelCvolume),A
FSTPC35 LD SP,0
HgthC LD A,0
FSTPC37 ADD A,0
FSTPC38 LD DE,0
		CALL CountToneX

FSTPC39 LD HL,0
FSTPC40 LD BC,0
		ADD HL,BC
		LD (FSTPC39+1),HL
		BIT 7,H
FSTPC41 JP FSTPC42			;jp z; jp nz; jp
		ADD HL,DE
		LD (AyR4_ChannelCfinePitch),DE
		LD HL,0
		LD (FSTPC39+1),HL
		LD (FSTPC40+1),HL
		RET 

FSTPC42 ADD HL,DE
		LD (AyR4_ChannelCfinePitch),HL
		RET 

FSTPC43 LD A,LX
		OR #24
		LD LX,A
		XOR A
		JR FSTPC34

;-------------------------------------------------------------
Player_Init 
		DI 
		PUSH HL

		LD HL,ToneTable_175snd
		LD A,(Module_Addr+#32)

		CP 2
		JR Z,$+5

		LD HL,ToneTable_Classic
		LD DE,ToneTable_Place
make_ft LD B,12
mftr1   PUSH BC
		LD C,(HL)
		INC HL
		PUSH HL
		LD B,(HL)
		PUSH DE
		EX DE,HL
		LD DE,23
		LD A,8
mftr2   SRL B
		RR C
		LD (HL),C
		INC HL
		LD (HL),B
		ADD HL,DE
		DEC A
		JR NZ,mftr2
		POP DE			;tonetable place in DE
		INC DE
		INC DE
		POP HL
		INC HL			;next byte of packed table in HL
		POP BC
		DJNZ mftr1

		POP HL			;Now Module_Addr in HL
		PUSH HL
		LD BC,#45		;skip signature
		ADD HL,BC		;Default Delay Addr in HL
		LD A,(HL)		;Default Delay now in A
		INC HL
		LD (GlobalDelay+1),A

		LD A,1
		LD (TiksCounter),A
		LD A,(HL)
		ADD A,A			;

		POP BC

		LD HL,#D4

		LD E,A
		LD D,H
		ADD HL,BC
		
		LD (PattsHeightsAddr+1),HL
		ADD HL,DE
		LD (ModuleLoopTo+1),HL

		LD HL,#52
		ADD HL,BC

		LD (StackIni+1),SP
		PUSH HL
		LD (SampShiftsAddrTblA+1),HL	
		LD (SampShiftsAddrTblB+1),HL
		LD (SampShiftsAddrTblC+1),HL
		LD HL,#92
		ADD HL,BC
		LD (ImagShiftsAddrTblA+1),HL
		LD (ImagShiftsAddrTblB+1),HL
		LD (ImagShiftsAddrTblC+1),HL

		POP HL
		LD SP,HL
		INC HL
		LD A,(HL)						
		CP #40
		JR NC,FSTPI2

		LD A,#41
FSTPI1  POP HL
		ADD HL,BC
		PUSH HL
		POP HL
		DEC A
		JR NZ,FSTPI1

FSTPI2  LD HL,#4B
		ADD HL,BC
		LD SP,HL
		POP HL
		ADD HL,BC
		LD (PaPoThg+1),HL
		LD SP,HL
		INC HL
		LD A,(HL)
		CP #40
		JR NC,FSTPI5

FSTPI3  POP HL
		LD A,H
		INC A
		JR NZ,FSTPI4
		LD A,L
		INC A
		JR Z,FSTPI5
FSTPI4  ADD HL,BC
		PUSH HL
		POP HL
		JR FSTPI3


FSTPI5  
		LD HL,#52
		ADD HL,BC
		LD (SamplAddrA+1),HL	;chan A, de
		LD (SamplAddrB+1),HL	;chan B, de
		LD (SamplAddrC+1),HL	;chan C, de
		LD HL,#92
		ADD HL,BC
		LD SP,HL
		POP HL
		LD (ImagAddrA+1),HL
		LD (ImagAddrB+1),HL
		LD (ImagAddrC+1),HL
		XOR A
		LD (AddNoisePitchA+1),A
		LD (AddNoisePitchB+1),A
		LD (AddNoisePitchC+1),A
		LD (ImSh7A+1),A
		LD (ImSh7B+1),A
		LD (ImSh7C+1),A
		LD (ImSh6A+1),A
		LD (ImSh6B+1),A
		LD (ImSh6C+1),A
		LD (ImShA+1),A
		LD (ImShB+1),A
		LD (ImShC+1),A
		LD (FTPORTA+1),A
		LD (FTPORTB+1),A
		LD (FTPORTC+1),A
		LD HL,#0100
		LD (ImShHlA+1),HL
		LD (ImShHlB+1),HL
		LD (ImShHlC+1),HL
		LD A,#B7			; OR A
		LD (StEnvA),A
		LD (StEnvB),A
		LD (StEnvC),A
		LD (EnvFormPresetA),A
		LD (EnvFormPresetB),A
		LD (EnvFormPresetC),A
		LD HL,VolumeM
		LD (SetVolumeFromTableA+1),HL
		LD (SetVolumeFromTableB+1),HL
		LD (SetVolumeFromTableC+1),HL
		LD HL,ShutEnOnOf+1
		LD (ChkHgtA+1),HL
StackIni	LD SP,0
			JP PlayerShutUper

;-------------------------------------------------------------
		
CountToneX
		ADD A,A
		ADD A, low ToneTable_Place	;.ToneTable_Place
		LD L,A
		ADC A, high ToneTable_Place	;'ToneTable_Place
		SUB L
		LD H,A
		LD A,(HL)
		INC HL
		LD H,(HL)
		LD L,A
		ADD HL,DE
		EX DE,HL
		RET
		
ImSmCntShft  
		ADD A,A
		LD C,A
		LD B,0
		ADD HL,BC
;_HL_toHL
		LD A,(HL)
		INC HL
		LD H,(HL)
		LD L,A
		RET
		
CountVolume
		ADD A,A
		ADD A,A
		ADD A,A
		ADD A,A
		ADD A, low VolumeTable	;.VolumeTable
		LD L,A
		ADC A, high VolumeTable	;'VolumeTable
		SUB L
		LD H,A
		RET
		
PortamentoTonesTableCalc
		ADD A,A
		ADD A, low ToneTable_Place	;.ToneTable_Place
		LD L,A
		ADC A, high ToneTable_Place	;'ToneTable_Place
		SUB L
		LD H,A
		RET 

;-------------------------------------------------------------


ToneTable_Classic  		DW #0EF8*2,#0E10*2,#0D60*2,#0C80*2
						DW #0BD8*2,#0B28*2,#0A88*2,#09F0*2
						DW #0960*2,#08E0*2,#0858*2,#07E0*2

ToneTable_175snd		DW #0D10*2,#0C58*2,#0BA0*2,#0B00*2
						DW #0A60*2,#09C8*2,#0940*2,#08B8*2
						DW #0840*2,#07C0*2,#0750*2,#06F0*2

ToneTable_Place 		DS 192




VolumeTable DB #0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0,#0
			DB #0,#0,#0,#0,#0,#0,#0,#0,#1,#1,#1,#1,#1,#1,#1,#1
			DB #0,#0,#0,#0,#1,#1,#1,#1,#1,#1,#1,#1,#2,#2,#2,#2
			DB #0,#0,#0,#1,#1,#1,#1,#1,#2,#2,#2,#2,#2,#3,#3,#3
			DB #0,#0,#1,#1,#1,#1,#2,#2,#2,#2,#3,#3,#3,#3,#4,#4
			DB #0,#0,#1,#1,#1,#2,#2,#2,#3,#3,#3,#4,#4,#4,#5,#5
			DB #0,#0,#1,#1,#2,#2,#2,#3,#3,#4,#4,#4,#5,#5,#6,#6
			DB #0,#0,#1,#1,#2,#2,#3,#3,#4,#4,#5,#5,#6,#6,#7,#7
			DB #0,#1,#1,#2,#2,#3,#3,#4,#4,#5,#5,#6,#6,#7,#7,#8
			DB #0,#1,#1,#2,#2,#3,#4,#4,#5,#5,#6,#7,#7,#8,#8,#9
			DB #0,#1,#1,#2,#3,#3,#4,#5,#5,#6,#7,#7,#8,#9,#9,#A
			DB #0,#1,#1,#2,#3,#4,#4,#5,#6,#7,#7,#8,#9,#A,#A,#B
			DB #0,#1,#2,#2,#3,#4,#5,#6,#6,#7,#8,#9,#A,#A,#B,#C
			DB #0,#1,#2,#3,#3,#4,#5,#6,#7,#8,#9,#A,#A,#B,#C,#D
			DB #0,#1,#2,#3,#4,#5,#6,#7,#7,#8,#9,#A,#B,#C,#D,#E
VolumeM 	DB #0,#1,#2,#3,#4,#5,#6,#7,#8,#9,#A,#B,#C,#D,#E,#F

;-------------------------------------------------------------
RetriggerBackout
		XOR A
		LD (AyRetriggerMarker),A
		LD L,#0D
		LD A,(AyR13_EnvelopeShape)
		LD (R13W),A			; FT2: R13 записан (ретриггер)
		LD H,A
RetriggerOut
		LD BC,#FFFD
		OUT (C),L
		LD B,#BF
		OUT (C),H
		RET 

RetriggNow
		CALL RetriggerOut
		INC L
		CALL RetriggerOut
		CALL RetriggerBackout
		JR PlayCont

PlayerShutUper  
			LD BC,#1200

			LD HL,AyRetriggerMarker	;AyR0_ChannelAfinePitch
regszeros	LD (HL),C
			INC HL
			DJNZ regszeros

ShutEnOnOf  	OR #FF
			LD (SetShapeOrNo+1),A
			LD L,A
			LD H,A
			LD (PlayCont+1),HL

PlayerOuter 
			LD HL,AyR13_EnvelopeShape
			LD C,#FD
			LD DE,#FFBF
			LD A,(HL)
SetShapeOrNo  	
			CP 0
			JR Z,PLAI2TR
			LD (R13W),A			; FT2: R13 записан в этот кадр (#FF - нет)
			LD (SetShapeOrNo+1),A
			PUSH AF
			LD A,#D
			LD B,D
			OUT (C),A
			LD B,E
			POP AF
			OUT (C),A

PLAI2TR
		LD A,(AyRetriggerMarker)
		LD HL,0
		DEC A
		JR Z,RetriggNow
		INC L
		INC L
		DEC A
		JR Z,RetriggNow
		INC L
		INC L
		DEC A
		JR Z,RetriggNow
PlayCont
		LD DE,0
		LD HL,(AyR11_EnvelopeFine)
		OR A
		SBC HL,DE
		LD DE,#FFBF
		JR Z,RegsWr
		LD HL,(AyR11_EnvelopeFine)
		LD (PlayCont+1),HL
		LD A,#C
		LD B,D
		OUT (C),A
		LD B,E
		OUT (C),H
		DEC A
		LD B,D
		OUT (C),A
		LD B,E
		OUT (C),L


RegsWr	LD HL,AyR10_ChannelCvolume
		LD A,#A
rwrcont	LD B,D
		OUT (C),A
		LD B,E
		OUTD
		DEC A
		jp p,rwrcont

		RET				; EI убран: компаратор работает без прерываний

AyRetriggerMarker 			DB 0
AyR0_ChannelAfinePitch		DB 0
AyR1_ChannelAcoursePitch	DB 0
AyR2_ChannelBfinePitch		DB 0
AyR3_ChannelBcoursePitch	DB 0
AyR4_ChannelCfinePitch		DB 0
AyR5_ChannelCcoursePitch	DB 0
AyR6_NoisePitch				DB 0
AyR7_Mixer					DB 0
AyR8_ChannelAvolume			DB 0
AyR9_ChannelBvolume			DB 0
AyR10_ChannelCvolume		DB 0
AyR11_EnvelopeFine			DB 0
AyR12_EnvelopeCourse		DB 0
AyR13_EnvelopeShape			DB 0

CntDistNextNoteA			DB 0
CntDistNextNoteB			DB 0
CntDistNextNoteC			DB 0
TiksCounter					DB 0


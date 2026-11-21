#pragma once
// ZX Trinity card = its RP firmware on the hardware model (Trinity firmware/rp-ay/test/emu.bat -> trinity_card.dll
// next to Unreal.exe). [AY] AYFX=1 and the DLL is there - the card sits on chip #FF (in CHRV - ay[1]): every #FFFD /
// #BFFD write goes to the card, reads of #FFFD with chip #FF selected come from it, and ay[1] plays the card's chip
// registers. No DLL - the old built-in AY FX model (sndchip.cpp trin_*). Card console - trinity_card.log
extern bool tc_on;
void tc_init();                      // after the ini is read
void tc_write(int a0, unsigned char v);
unsigned char tc_read();
void tc_frame();                     // end of frame: run the card up to now, its chip registers -> ay[1]

// RP-GS of the card from trinity_gs.dll (Trinity firmware/rp-gs/test/emu.bat): GSType=TRIN in [SOUND] - ports #BB / #B3
// go to it instead of the built-in GS. Sector gate disk - trinity_sd.img next to Unreal.exe. No sound yet
void tgs_init();                     // after the ini is read; no DLL - GSType falls back to NONE
u8 tgs_in(u8 port);
void tgs_out(u8 port, u8 v);
void tgs_reset();

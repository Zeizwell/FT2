#include "std.h"
#include "sysdefs.h"
#include "emul.h"
#include "vars.h"
#include "emul_2203.h"
#include "sndchip.h"
#include <math.h>

/*
   YM-2149F emulator for Unreal Speccy project
   created under public domain license by SMT, jan.2006
*/

unsigned SNDCHIP::render(AYOUT *src, unsigned srclen, unsigned clk_ticks, bufptr_t dst)
{
   start_frame(dst);
   for (unsigned index = 0; index < srclen; index++) {
      // if (src[index].timestamp > clk_ticks) continue; // wrong input data leads to crash
      select(src[index].reg_num);
      write(src[index].timestamp, src[index].reg_value);
   }
   return end_frame(clk_ticks);
}


const unsigned MULT_C_1 = 14; // fixed point precision for 'system tick -> ay tick'
// b = 1+ln2(max_ay_tick/8) = 1+ln2(max_ay_fq/8 / min_intfq) = 1+ln2(10000000/(10*8)) = 17.9
// assert(b+MULT_C_1 <= 32)

void SNDCHIP::start_frame(bufptr_t dst)
{
   r13_reloaded = 0;
   SNDRENDER::start_frame(dst);
}

unsigned SNDCHIP::end_frame(unsigned clk_ticks)
{
   // adjusting 't' with whole history will fix accumulation of rounding errors

   u64 end_chip_tick = ((passed_clk_ticks + clk_ticks) * chip_clock_rate) / system_clock_rate;

   flush( (unsigned) (end_chip_tick - passed_chip_ticks) );
   if (conf.sound.trinity) trin_frame();   // ZX Trinity: PWM sweep, once per frame
   unsigned res = SNDRENDER::end_frame(t);

   passed_clk_ticks += clk_ticks;
   passed_chip_ticks += t; t = 0;
   nextfmtickfloat = 0.; //Alone Coder
   nextfmtick = 0; //Alone Coder

   return res;
}

void SNDCHIP::flush(unsigned chiptick) // todo: noaction at (temp.sndblock || !conf.sound.ay)
{
   while (t < chiptick) {
      t++;
      if (++ta >= fa) ta = 0, bitA ^= -1;
      if (++tb >= fb) tb = 0, bitB ^= -1;
      if (++tc >= fc) tc = 0, bitC ^= -1;
      if (++tn >= fn)
         tn = 0,
         ns = (ns*2+1) ^ (((ns>>16)^(ns>>13)) & 1),
         bitN = 0 - ((ns >> 16) & 1);
      if (++te >= fe) {
         te = 0, env += denv;
         if (env & ~31) {
            unsigned mask = (1<<r.env);
            if (mask & ((1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9)|(1<<15)))
               env = denv = 0;
            else if (mask & ((1<<8)|(1<<12)))
               env &= 31;
            else if (mask & ((1<<10)|(1<<14)))
               denv = -denv, env = env + denv;
            else env = 31, denv = 0; //11,13
         }
      }

      if (conf.sound.trinity) trin_tick();   // ZX Trinity timers

      unsigned en, mix_l, mix_r;

      en = ((ea & env) | va) & ((bitA | bit0) & (bitN | bit3));
      if (conf.sound.trinity && (trin[0].reg[0] & 3) == 1) en = en * trin[0].lvl / 15;   // SID
      mix_l  = vols[0][en]; mix_r  = vols[1][en];

      en = ((eb & env) | vb) & ((bitB | bit1) & (bitN | bit4));
      if (conf.sound.trinity && (trin[1].reg[0] & 3) == 1) en = en * trin[1].lvl / 15;
      mix_l += vols[2][en]; mix_r += vols[3][en];

      en = ((ec & env) | vc) & ((bitC | bit2) & (bitN | bit5));
      if (conf.sound.trinity && (trin[2].reg[0] & 3) == 1) en = en * trin[2].lvl / 15;
      mix_l += vols[4][en]; mix_r += vols[5][en];
//YM2203 here
      if (/*temp.sndblock ||*/ conf.sound.ay_chip == CHIP_YM2203) {
        if (t >= nextfmtick) {
          nextfmtickfloat += ayticks_per_fmtick;
          nextfmtick = (int)nextfmtickfloat;
          if (++FMbufN == FMBUFSIZE) {
            YM2203UpdateOne(Chip2203, FMbufs/*&FMbuf*/, FMBUFSIZE/*1*/);
            FMbufN = 0;
          };
          if (fmsoundon0 == 0) {
            //FMbufOUT=(int)(FMbuf*conf.sound.ay/8192*0.7f);
            FMbufOUT=((((i16)FMbufs[FMbufN])*FMbufMUL)>>16);
          }
          else FMbufOUT=0;
        }
        mix_l += FMbufOUT; mix_r += FMbufOUT;
      }; //Alone Coder
//
      if ((mix_l ^ SNDRENDER::mix_l) | (mix_r ^ SNDRENDER::mix_r)) // similar check inside update()
         update(t, mix_l, mix_r);
   }
}

void SNDCHIP::select(u8 nreg)
{
   if (chiptype == CHIP_AY) nreg &= 0x0F;
   if (nreg != 0xC0) trin_key = 0;   // ZX Trinity: key "TRIN" - only in a row into #C0
   activereg = nreg;
}

void SNDCHIP::write(unsigned timestamp, u8 val)
{
   if (activereg >= 0x20 && conf.sound.ay_chip == CHIP_YM2203)
   {
      if (timestamp) flush((timestamp * mult_const) >> MULT_C_1); // cputick * ( (chip_clock_rate/8) / system_clock_rate );
      if (activereg >= 0x2d && activereg <= 0x2f) {
         int oldayfq=Chip2203->OPN.ST.SSGclock /*ayfq*/;
         YM2203Write(Chip2203,0,activereg);
         YM2203Write(Chip2203,1,val);
         if (oldayfq!=Chip2203->OPN.ST.SSGclock) {
            //if (!conf.sound.ay_samples) flush(cpu.t);
            //ayfq=Chip2203->OPN.ST.SSGclock;
            //t=(unsigned)((__int64)t*ayfq/oldayfq);
            //mult_const2 = ((ayfq/conf.intfq) << (MULT_C_1-3))/conf.frame;
            //mult_const3 = TICK_F/2+(unsigned)((__int64)temp.snd_frame_ticks*conf.intfq*(1<<(MULT_C+3))/ayfq);
            //ay_div = ((unsigned)((double)ayfq*0x10*(double)SAMPLE_T/(double)conf.sound.fq));
            //ay_div2 = (ayfq*0x100)/(conf.sound.fq/32);
            set_timings(system_clock_rate,Chip2203->OPN.ST.SSGclock,SNDRENDER::sample_rate);
         }
      }
      else
      {
         YM2203Write(Chip2203,0,activereg);
         YM2203Write(Chip2203,1,val);
      }
      return;
   } //Dexus

   if (activereg >= 0x10) {
      if (conf.sound.trinity) trin_write(timestamp, val);   // ZX Trinity
      return;
   }

   if ((1 << activereg) & ((1<<1)|(1<<3)|(1<<5)|(1<<13))) val &= 0x0F;
   if ((1 << activereg) & ((1<<6)|(1<<8)|(1<<9)|(1<<10))) val &= 0x1F;

   if (activereg != 13 && reg[activereg] == val) return;

   reg[activereg] = val;


   if (timestamp) flush((timestamp * mult_const) >> MULT_C_1); // cputick * ( (chip_clock_rate/8) / system_clock_rate );

   switch (activereg) {
      case 0:
      case 1:
         fa = r.fA;
         break;
      case 2:
      case 3:
         fb = r.fB;
         break;
      case 4:
      case 5:
         fc = r.fC;
         break;
      case 6:
         fn = val*2;
         break;
      case 7:
         bit0 = 0 - ((val>>0) & 1);
         bit1 = 0 - ((val>>1) & 1);
         bit2 = 0 - ((val>>2) & 1);
         bit3 = 0 - ((val>>3) & 1);
         bit4 = 0 - ((val>>4) & 1);
         bit5 = 0 - ((val>>5) & 1);
         break;
      case 8:
         ea = (val & 0x10)? -1 : 0;
         va = ((val & 0x0F)*2+1) & ~ea;
         break;
      case 9:
         eb = (val & 0x10)? -1 : 0;
         vb = ((val & 0x0F)*2+1) & ~eb;
         break;
      case 10:
         ec = (val & 0x10)? -1 : 0;
         vc = ((val & 0x0F)*2+1) & ~ec;
         break;
      case 11:
      case 12:
         fe = r.envT;
         break;
      case 13:
         r13_reloaded = 1;
         te = 0;
         if (r.env & 4) env = 0, denv = 1; // attack
         else env = 31, denv = -1; // decay
         break;
   }
}

u8 SNDCHIP::read()
{
   u8 v;
   if (conf.sound.trinity && trin_read(v)) return v;   // ZX Trinity
   if (activereg >= 0x10) return 0xFF;
   return reg[activereg & 0x0F];
}

void SNDCHIP::set_timings(unsigned system_clock_rate, unsigned chip_clock_rate, unsigned sample_rate)
{
   if (conf.sound.ay_chip == CHIP_YM2203) { //install YM2203 frequencies
         Chip2203->OPN.ST.clock = conf.sound.ayfq*2;
         Chip2203->OPN.ST.rate = conf.sound.fq /*44100*/;
         OPNPrescaler_w(&Chip2203->OPN, 1 , 1 );
         //ayfq=Chip2203->OPN.ST.SSGclock;
         //????????? ????????? ????????? ????????? ayfq ???????????? ????????? "??????????????????????????????" ?????????????????????, ????????????????????? ??? ??????????????? ??????????????? ?????? ??????????????????.
         chip_clock_rate=Chip2203->OPN.ST.SSGclock;
   } //Dexus
   
   chip_clock_rate /= 8;

   SNDCHIP::system_clock_rate = system_clock_rate;
   SNDCHIP::chip_clock_rate = chip_clock_rate;

   mult_const = (unsigned) (((u64)chip_clock_rate << MULT_C_1) / system_clock_rate);
   SNDRENDER::set_timings(chip_clock_rate, sample_rate);
   passed_chip_ticks = passed_clk_ticks = 0;
   t = 0; ns = 0xFFFF;

   nextfmtickfloat = 0.; //Alone Coder
   nextfmtick = 0; //Alone Coder
   ayticks_per_fmtick = (float)chip_clock_rate/conf.sound.fq /*44100*/; //Alone Coder
   FMbufMUL=(u16)(((float)conf.sound.ay_vol/8192 /* =0..1 */)*0.1f*65536); //Alone Coder 0.36.4

   //apply_regs();
}

void SNDCHIP::set_volumes(unsigned global_vol, const SNDCHIP_VOLTAB *voltab, const SNDCHIP_PANTAB *stereo)
{
   for (int j = 0; j < 6; j++)
      for (int i = 0; i < 32; i++)
         vols[j][i] = (unsigned) (((u64)global_vol * voltab->v[i] * stereo->raw[j])/(65535*15*3));
}

void SNDCHIP::reset(unsigned timestamp)
{
   for (int i = 0; i < 14; i++) reg[i] = 0;
   trin_reset();

   if (Chip2203) YM2203ResetChip((void*)Chip2203); //Dexus
/*
   ayfq=Chip2203->OPN.ST.SSGclock; //Dexus
   mult_const2 = ((ayfq/conf.intfq) << (MULT_C_1-3))/conf.frame; //Dexus
   mult_const3 = TICK_F/2+(unsigned)((__int64)temp.snd_frame_ticks*conf.intfq*(1<<(MULT_C+3))/ayfq); //Dexus
   ay_div = ((unsigned)((double)ayfq*0x10*(double)SAMPLE_T/(double)conf.sound.fq)); //Dexus
   ay_div2 = (ayfq*0x100)/(conf.sound.fq/32); //Dexus
*/
   apply_regs(timestamp);
}

void SNDCHIP::apply_regs(unsigned timestamp)
{
   for (u8 r = 0; r < 16; r++) {
      select(r); u8 p = reg[r];
      /* clr cached values */
      write(timestamp, p ^ 1); write(timestamp, p);
   }
}

SNDCHIP::SNDCHIP()
{
   bitA = bitB = bitC = 0;
   nextfmtick = 0; //Alone Coder
   set_timings(SNDR_DEFAULT_SYSTICK_RATE, SNDR_DEFAULT_AY_RATE, SNDR_DEFAULT_SAMPLE_RATE);
   Chip2203 = (YM2203 *) YM2203Init(0, 0, conf.sound.ayfq*2, conf.sound.fq /*44100*/); //Dexus
   set_chip(CHIP_YM);
   set_volumes(0x7FFF, SNDR_VOL_YM, SNDR_PAN_ABC);
   reset();
}

// corresponds enum CHIP_TYPE
const char * const ay_chips[] = { "AY-3-8910", "YM2149F", "YM2203" }; //Dexus


const SNDCHIP_VOLTAB SNDR_VOL_AY_S =
{ { 0x0000,0x0000,0x0340,0x0340,0x04C0,0x04C0,0x06F2,0x06F2,0x0A44,0x0A44,0x0F13,0x0F13,0x1510,0x1510,0x227E,0x227E,
    0x289F,0x289F,0x414E,0x414E,0x5B21,0x5B21,0x7258,0x7258,0x905E,0x905E,0xB550,0xB550,0xD7A0,0xD7A0,0xFFFF,0xFFFF } };

const SNDCHIP_VOLTAB SNDR_VOL_YM_S =
{ { 0x0000,0x0000,0x00EF,0x01D0,0x0290,0x032A,0x03EE,0x04D2,0x0611,0x0782,0x0912,0x0A36,0x0C31,0x0EB6,0x1130,0x13A0,
    0x1751,0x1BF5,0x20E2,0x2594,0x2CA1,0x357F,0x3E45,0x475E,0x5502,0x6620,0x7730,0x8844,0xA1D2,0xC102,0xE0A2,0xFFFF } };

const SNDCHIP_PANTAB SNDR_PAN_MONO_S =
{ 100,100, 100,100, 100,100 };

const SNDCHIP_PANTAB SNDR_PAN_ABC_S =
{ 100,10,  66,66,   10,100 };

const SNDCHIP_PANTAB SNDR_PAN_ACB_S =
{ 100,10,  10,100,  66,66 };

const SNDCHIP_PANTAB SNDR_PAN_BAC_S =
{ 66,66,   100,10,  10,100 };

const SNDCHIP_PANTAB SNDR_PAN_BCA_S =
{ 10,100,  100,10,  66,66 };

const SNDCHIP_PANTAB SNDR_PAN_CAB_S =
{ 66,66,   10,100,  100,10 };

const SNDCHIP_PANTAB SNDR_PAN_CBA_S =
{ 10,100,  66,66,   100,10 };

// =========================================================================
// ZX Trinity: timer effects card (FT2 doc/ay-ports-map.md, 5a)
// Per chip: #C0 key "TRIN" / read 'T', #C1 GO (shadow -> work; 0 - also lock, bit 0 - keep open),
// #C2 channel, #C3-#CE channel regs = FX row (FLAGS, PWM, SWEEP, 3 x (SEMI, RAW, TAB)),
// #CF CMD (TAKE A..C bits 0-2, RESET A..C bits 3-5), #B8 table number, #B9 table data.
// Timer of an effect ticks every P chip ticks (8*P AY clocks), P = base * 2^(-semi/12) + raw,
// base - channel tone period (FOLLOW) or taken by TAKE. Each step lasts P (SID with 2 steps
// and PWM - 2P split by the duty).
// =========================================================================
enum { TF_MIX = 3, TF_SID = 1, TF_SYNC = 2, TF_FM = 4, TF_EFM = 8, TF_FOLLOW = 16, TF_FMPER = 32, TF_EFMPER = 64 };

static double trin_mul[256];        // 2^(-s/12) for semitones s = -128..127 (index - s as u8)
static bool trin_mul_ok = false;

static double trin_semi(u8 s)
{
   if (!trin_mul_ok) {
      for (int i = 0; i < 256; i++) trin_mul[i] = pow(2.0, -(double)(signed char)i / 12.0);
      trin_mul_ok = true;
   }
   return trin_mul[s];
}

static unsigned trin_clamp(double p, unsigned max)
{
   if (p < 1.0) return 1;
   if (p > max) return max;
   return (unsigned)(p + 0.5);
}

void SNDCHIP::trin_reset()
{
   trin_on = trin_key = trin_ch = trin_cmd = trin_tn = trin_tp = 0;
   memset(trin_sh, 0, sizeof trin_sh);
   memset(trin, 0, sizeof trin);
   memset(trin_tab, 0, sizeof trin_tab);
   for (int c = 0; c < 3; c++) trin[c].lvl = 15;
}

// tone period of channel c from AY registers
unsigned SNDCHIP::trin_tone(int c)
{
   unsigned p = (c == 0 ? r.fA : c == 1 ? r.fB : r.fC) & 0x0FFF;
   return p ? p : 1;
}

// timer period of effect k of channel c (chip ticks)
unsigned SNDCHIP::trin_period(int c, int k)
{
   TRIN_CH &ch = trin[c];
   unsigned base = (ch.reg[0] & TF_FOLLOW) || !ch.base ? trin_tone(c) : ch.base;
   double p = base * trin_semi(ch.reg[3 + 3 * k]) + (signed char)ch.reg[4 + 3 * k];
   return trin_clamp(p, 0xFFFF);
}

// steps of effect k: table by number, 0 - default (SID 15 0, Sync - current shape, FM - no shift)
const u8 *SNDCHIP::trin_table(int c, int k, u8 &len, u8 &loop)
{
   static const u8 def_sid[2] = { 15, 0 }, def_zero[1] = { 0 };
   u8 n = trin[c].reg[5 + 3 * k];
   if (n == 0 || n > TRIN_TABS) {
      loop = 0;
      if (k == 0 && (trin[c].reg[0] & TF_MIX) == TF_SID) { len = 2; return def_sid; }
      len = 1; return def_zero;
   }
   len = (trin_tab[n][0] & 15) + 1;
   loop = trin_tab[n][0] >> 4;
   if (loop >= len) loop = 0;
   return trin_tab[n] + 1;
}

// apply current step of effect k and set its length
void SNDCHIP::trin_apply(int c, int k)
{
   TRIN_CH &ch = trin[c];
   TRIN_FX &fx = ch.fx[k];
   u8 len, loop;
   const u8 *st = trin_table(c, k, len, loop);
   if (fx.step >= len) fx.step = loop;
   u8 v = st[fx.step];
   unsigned p = trin_period(c, k);
   fx.dur = p;

   if (k == 0) {
      if ((ch.reg[0] & TF_MIX) == TF_SID) {
         ch.lvl = v & 15;
         if (len == 2 && ch.reg[1]) {               // PWM: 2 steps share 2P by the duty
            double lo = (ch.reg[1] & 15) / 30.0, hi = (ch.reg[1] >> 4) / 30.0, d = hi;   // 0..50%; no sweep - max
            if (ch.reg[2]) d = lo + (hi - lo) * (ch.sweep < 32768 ? ch.sweep : 65536 - ch.sweep) / 32768.0;
            unsigned h = trin_clamp(2.0 * p * d, 2 * p - 1);
            fx.dur = fx.step == 0 ? h : 2 * p - h;
         }
      } else if ((ch.reg[0] & TF_MIX) == TF_SYNC) {  // envelope restart, step - shape (0 - current)
         if (v & 15) r.env = v & 15;
         r13_reloaded = 1;
         te = 0;
         if (r.env & 4) env = 0, denv = 1;
         else env = 31, denv = -1;
      }
   } else if (k == 1) {                              // FM: tone period of the channel
      unsigned t0 = trin_tone(c);
      unsigned np = ch.reg[0] & TF_FMPER ? trin_clamp((double)t0 + (signed char)v, 0x0FFF)
                                         : trin_clamp(t0 * trin_semi(v), 0x0FFF);
      if (c == 0) fa = np; else if (c == 1) fb = np; else fc = np;
   } else {                                          // Env FM: envelope period
      unsigned e0 = r.envT ? r.envT : 1;
      fe = ch.reg[0] & TF_EFMPER ? trin_clamp((double)e0 + (signed char)v, 0xFFFF)
                                 : trin_clamp(e0 * trin_semi(v), 0xFFFF);
   }
}

// next step of effect k
void SNDCHIP::trin_next(int c, int k)
{
   trin[c].fx[k].step++;
   trin_apply(c, k);
}

// every chip tick: timers of active effects
void SNDCHIP::trin_tick()
{
   for (int c = 0; c < 3; c++) {
      u8 f = trin[c].reg[0];
      if (!(f & (TF_MIX | TF_FM | TF_EFM))) continue;
      if ((f & TF_MIX) && ++trin[c].fx[0].cnt >= trin[c].fx[0].dur) trin[c].fx[0].cnt = 0, trin_next(c, 0);
      if ((f & TF_FM) && ++trin[c].fx[1].cnt >= trin[c].fx[1].dur) trin[c].fx[1].cnt = 0, trin_next(c, 1);
      if ((f & TF_EFM) && ++trin[c].fx[2].cnt >= trin[c].fx[2].dur) trin[c].fx[2].cnt = 0, trin_next(c, 2);
   }
}

// once per frame: PWM sweep, triangle min -> max -> min
void SNDCHIP::trin_frame()
{
   for (int c = 0; c < 3; c++)
      if (trin[c].reg[2]) trin[c].sweep = (trin[c].sweep + trin[c].reg[2] * 64) & 0xFFFF;
}

// GO: shadow -> work, CMD; effects switched off give the channel back to AY registers
void SNDCHIP::trin_go(u8 val)
{
   for (int c = 0; c < 3; c++) {
      TRIN_CH &ch = trin[c];
      u8 was = ch.reg[0];
      memcpy(ch.reg, trin_sh[c], TRIN_REGS);
      u8 now = ch.reg[0];
      if ((was & TF_FM) && !(now & TF_FM)) {
         if (c == 0) fa = r.fA; else if (c == 1) fb = r.fB; else fc = r.fC;
      }
      if ((was & TF_EFM) && !(now & TF_EFM)) fe = r.envT;
      if (!(now & TF_MIX)) ch.lvl = 15;
      if (trin_cmd & (1 << c)) ch.base = trin_tone(c);              // TAKE
      for (int k = 0; k < 3; k++) {
         static const u8 bit[3] = { TF_MIX, TF_FM, TF_EFM };
         bool on = (now & bit[k]) != 0, start = on && !(was & bit[k]);
         if (trin_cmd & (8 << c)) {                                   // RESET
            ch.fx[k].step = 0, ch.fx[k].cnt = 0;
            if (on) trin_apply(c, k);
         } else if (start) {                                          // just switched on
            ch.fx[k].step = 0, ch.fx[k].cnt = 0;
            trin_apply(c, k);
         }
      }
      if (trin_cmd & (8 << c)) ch.sweep = 0;
   }
   trin_cmd = 0;
   if (!(val & 1)) trin_on = 0;
}

bool SNDCHIP::trin_write(unsigned timestamp, u8 val)
{
   static const char key[] = "TRIN";
   u8 n = activereg;
   if (n == 0xC0) {
      if ((char)val == key[trin_key]) trin_key++;
      else trin_key = (char)val == key[0];
      if (trin_key == 4) trin_on = 1, trin_key = 0;
      return true;
   }
   if (!trin_on) return false;
   if (n == 0xC1) {
      if (timestamp) flush((timestamp * mult_const) >> MULT_C_1);
      trin_go(val);
   }
   else if (n == 0xC2) { if (val < 3) trin_ch = val; }
   else if (n >= 0xC3 && n <= 0xCE) trin_sh[trin_ch][n - 0xC3] = val;
   else if (n == 0xCF) trin_cmd = val;
   else if (n == 0xB8) trin_tn = val, trin_tp = 0;
   else if (n == 0xB9) {
      if (trin_tn >= 1 && trin_tn <= TRIN_TABS && trin_tp < 1 + TRIN_STEPS) trin_tab[trin_tn][trin_tp++] = val;
   }
   else return false;
   return true;
}

// read: #C0 - 'T' (card is there, open), #C1 - version
bool SNDCHIP::trin_read(u8 &val)
{
   if (!trin_on) return false;
   if (activereg == 0xC0) { val = 'T'; return true; }
   if (activereg == 0xC1) { val = 1; return true; }
   return false;
}

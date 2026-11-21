#include "std.h"
#include "emul.h"
#include "vars.h"
#include "sndchip.h"
#include "trincard.h"

// ZX Trinity card from trinity_card.dll (see trincard.h). Here only glue: time and the chip registers
extern SNDCHIP ay[2];

bool tc_on = false;

typedef int (*tc_init_t)(const char *log);
typedef void (*tc_write_t)(int a0, unsigned char v);
typedef unsigned char (*tc_read_t)(void);
typedef void (*tc_run_t)(unsigned us);
struct tc_wr_t { unsigned ns; unsigned char reg, val; };
typedef const tc_wr_t *(*tc_writes_t)(int *n);
static tc_write_t f_write;
static tc_read_t f_read;
static tc_run_t f_run;
static tc_writes_t f_writes;
typedef unsigned (*tc_phim_t)(void);
static tc_phim_t f_phim;
static __int64 t_last;               // CPU tacts the card has already run up to

void tc_init()
{
   if (!conf.sound.trinity) return;
   char path[MAX_PATH];
   GetModuleFileName(0, path, sizeof path);
   char *p = strrchr(path, '\\');
   if (!p) return;
   strcpy(p + 1, "trinity_card.dll");
   HMODULE h = LoadLibrary(path);
   if (!h) return;
   tc_init_t f_init = (tc_init_t)GetProcAddress(h, "trin_init");
   f_write = (tc_write_t)GetProcAddress(h, "trin_write");
   f_read = (tc_read_t)GetProcAddress(h, "trin_read");
   f_run = (tc_run_t)GetProcAddress(h, "trin_run");
   f_writes = (tc_writes_t)GetProcAddress(h, "trin_writes");
   f_phim = (tc_phim_t)GetProcAddress(h, "trin_phim");
   if (!f_init || !f_write || !f_read || !f_run || !f_writes) return;
   strcpy(p + 1, "trinity_card.log");
   if (!f_init(path)) return;        // firmware start failed (chip test) - see the log
   tc_on = true;
   conf.sound.trinity = 0;           // the built-in AY FX model is off: the card is the real thing
   t_last = comp.t_states + cpu.t;
}

// The card runs up to the current CPU tact (before every access: its answer depends on time). Its chip writes go
// to ay[1] at their own moments (timer effects and SNDH digis change registers many times per frame)
static void tc_catch_up()
{
   __int64 now = comp.t_states + cpu.t;
   unsigned cpufq = conf.intfq * conf.frame;
   if (now <= t_last || !cpufq) { t_last = now; return; }
   unsigned us = (unsigned)((now - t_last) * 1000000 / cpufq);
   if (!us) return;
   f_run(us);
   int n;
   const tc_wr_t *w = f_writes(&n);
   for (int i = 0; i < n; i++) {
      __int64 t = t_last + (__int64)w[i].ns * cpufq / 1000000000 - comp.t_states;   // tact in this frame (as cpu.t)
      if (t < 1) t = 1;
      if (t > cpu.t) t = cpu.t;
      ay[1].select(w[i].reg);
      ay[1].write(temp.sndblock ? 0 : (unsigned)t, w[i].val);
   }
   t_last += (__int64)us * cpufq / 1000000;
}

void tc_write(int a0, unsigned char v)
{
   tc_catch_up();
   f_write(a0, v);
}

unsigned char tc_read()
{
   tc_catch_up();
   return f_read();
}

// ---- RP-GS (trinity_gs.dll)
typedef int (*tgs_init_t)(const char *dir);
typedef void (*tgs_out_t)(int port, int v);
typedef int (*tgs_in_t)(int port);
typedef void (*tgs_reset_t)(void);
static tgs_out_t g_out;
static tgs_in_t g_in;
static tgs_reset_t g_reset;

void tgs_init()
{
   if (conf.gs_type != 3) return;
   conf.gs_type = 0;                 // no DLL - no GS at all
   char path[MAX_PATH];
   GetModuleFileName(0, path, sizeof path);
   char *p = strrchr(path, '\\');
   if (!p) return;
   strcpy(p + 1, "trinity_gs.dll");
   HMODULE h = LoadLibrary(path);
   if (!h) return;
   tgs_init_t f_init = (tgs_init_t)GetProcAddress(h, "tgs_init");
   g_out = (tgs_out_t)GetProcAddress(h, "tgs_out");
   g_in = (tgs_in_t)GetProcAddress(h, "tgs_in");
   g_reset = (tgs_reset_t)GetProcAddress(h, "tgs_reset");
   if (!f_init || !g_out || !g_in || !g_reset) return;
   p[1] = 0;
   if (!f_init(path)) return;
   conf.gs_type = 3;
}

// Unreal resets the GS before tgs_init (init_gs): no DLL yet - nothing to do
u8 tgs_in(u8 port) { return g_in ? (u8)g_in(port) : 0xFF; }
void tgs_out(u8 port, u8 v) { if (g_out) g_out(port, v); }
void tgs_reset() { if (g_reset) g_reset(); }

// End of frame: the card up to now; its φM changed (ATARI - 4 MHz) - ay[1] on that clock.
// The card chip is YM2203: its SSG runs at φM / 2 (ATARI: 2 MHz, as the Atari YM)
void tc_frame()
{
   tc_catch_up();
   static unsigned fq_last;
   unsigned fq = f_phim ? f_phim() / 2 : 0;
   if (!fq) fq = conf.sound.ayfq;
   if (fq == fq_last) return;
   fq_last = fq;
   ay[1].set_timings(conf.intfq * conf.frame, fq, conf.sound.fq);
}

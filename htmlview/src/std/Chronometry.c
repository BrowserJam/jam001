#include "std/Chronometry.h"
#include <stdlib.h>
#include <string.h>

#define WIN32 1

#if WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#if _POSIX_C_SOURCE >= 199309L
#include <time.h>
#endif

#if WIN32
TimePoint chrono_getCurrentTime() {
  TimePoint ret = 0;

  LARGE_INTEGER li;
  if (!QueryPerformanceCounter(&li)) {
    abort();
  }

  memcpy(&ret, &li.QuadPart, sizeof(li.QuadPart));
  return ret;
}

f64 chrono_secondsBetween(TimePoint t0, TimePoint t1) {
  LARGE_INTEGER li0, li1, freq;
  memcpy(&li0.QuadPart, &t0, sizeof(t0));
  memcpy(&li1.QuadPart, &t1, sizeof(t1));
  i64 delta = li1.QuadPart - li0.QuadPart;

  if (!QueryPerformanceFrequency(&freq)) {
    abort();
  }

  return delta / ((f64)freq.QuadPart);
}

#else
TimePoint chrono_getCurrentTime() {
  TimePoint ret = 0;
  u64 ticks;

  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  ticks = now.tv_sec;
  ticks *= 1000000000;
  ticks += now.tv_nsec;

  memcpy(&ret, &ticks, sizeof(ticks));
  return ret;
}

f64 chrono_secondsBetween(TimePoint t0, TimePoint t1) {
  u64 ticks0, ticks1;
  memcpy(&ticks0, &t0, sizeof(t0));
  memcpy(&ticks1, &t1, sizeof(t1));
  auto delta = ticks1 - ticks0;

  return delta / (f64)1000000000;
}
#endif

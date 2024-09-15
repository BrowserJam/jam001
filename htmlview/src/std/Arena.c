#include "std/Arena.h"
#include "std/Types.h"

#include <assert.h>
#include <string.h>

u8 *alloc(Arena *a, u32 objsize, u32 align, u32 count) {
  assert(count >= 0);
  u32 pad = (u64)a->end & (align - 1);
  while (!(count < (a->end - a->beg - pad) / objsize)) {
    handleOOM(a);
  }
  return (u8 *)memset(a->end -= objsize * count + pad, 0, objsize * count);
}

u8 *allocNZ(Arena *a, u32 objsize, u32 align, u32 count) {
  assert(count >= 0);
  u32 pad = (u64)a->end & (align - 1);
  while (!(count < (a->end - a->beg - pad) / objsize)) {
    handleOOM(a);
  }
  return (u8 *)(a->end -= objsize * count + pad);
}
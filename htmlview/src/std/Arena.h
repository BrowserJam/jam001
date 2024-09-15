#pragma once

#include "std/Types.h"

typedef struct Arena {
  u8 *beg;
  u8 *end;
} Arena;

typedef struct ArenaTemp {
  Arena *arena;
  Arena saved;
} ArenaTemp;

#if __cplusplus
extern "C" {
#endif

u8 *alloc(Arena *a, u32 objsize, u32 align, u32 count);
u8 *allocNZ(Arena *a, u32 objsize, u32 align, u32 count);
/**
 * Finds a scratch arena that doesn't conflict with the provided arenas, saves
 * its state and returns it to the caller.
 *
 * Functions that need to temporarily allocate memory on the heap can use this
 * function to acquire an arena. It's guaranteed that the returned arena is not
 * within the provided conflict list.
 *
 * When a function returns a heap allocated result and but it also needs to
 * allocate memory for some temporary results, then it would call this function
 * like this:
 *
 * ArenaTemp temp = getScratch(&arena, 1);
 *
 * where `arena` was supplied by the caller of the function as the place where
 * the result has to be allocated.
 *
 * If a function doesn't use an arena but it still has to allocate temporary
 * memory, it can call this function with an empty conflict list:
 *
 * `ArenaTemp temp = getScratch(nullptr, 0);`
 *
 * The `temp` value contains a pointer to an arena which can be used like this:
 *
 * `u8* ptr = alloc(temp.arena, 32, 1, 1);`
 *
 * Callers **must** release the ArenaTemp at the end of its scope:
 *
 * `releaseScratch(temp);`
 *
 * Callers can also reset the scratch arena to the initial state, for example at
 * the start of iterations:
 *
 * `for(...) { resetScratch(temp);  work(temp.arena); }`
 *
 */
ArenaTemp getScratch(Arena **pConflicts, u32 numConflicts);
void handleOOM(Arena *arena);
#define releaseScratch(arenaTemp) ((*arenaTemp.arena) = arenaTemp.saved)
#define resetScratch(arenaTemp) releaseScratch(arenaTemp)

#if __cplusplus
}
#endif

#if __cplusplus

template <typename T>
T *alloc(Arena *a, u32 count = 1) {
  return (T *)alloc(a, sizeof(T), alignof(T), count);
}

#endif

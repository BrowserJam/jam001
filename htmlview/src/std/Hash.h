#pragma once

#include "std/Types.h"

#if __cplusplus
extern "C" {
#endif

// Fowler-Noll-Vo hash, FNV-1a variant
u64 fnv64(const void *in, u32 len);

#if __cplusplus
}
#endif
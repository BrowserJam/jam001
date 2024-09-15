#pragma once

#include "std/Types.h"

#if __cplusplus
extern "C" {
#endif

typedef struct TimePoint_t *TimePoint;

TimePoint chrono_getCurrentTime();
/**
 * Computes the amount of time that has passed between t0 and t1, i.e. `t1 -
 * t0`.
 * @returns Number of seconds
 */
f64 chrono_secondsBetween(TimePoint t0, TimePoint t1);

#if __cplusplus
}
#endif
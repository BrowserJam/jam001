#pragma once

#include "std/Arena.h"
#include "std/Slice.hpp"
#include "std/Types.h"

void *os_reserve_vm(u64 size);
b32 os_commit_vm(void *ptr, u64 size);

void os_sleep(u32 milliseconds);
void os_abort();

#pragma once

#include "std/Arena.h"

#include <assert.h>
#include <string.h>

/**
 * A growable array.
 */
template <typename T>
struct Vector {
  T *data = nullptr;
  u32 length = 0;
  u32 capacity = 0;

  T &operator[](u32 i) {
    CHECK(i < length);
    return data[i];
  }
};

/**
 * Allocates spaces for `count` items in the vector and return the base address
 * to the caller. When the vector is full, a new backing array is allocated into
 * the provided arena and old elements are copied into it.
 */
template <typename T>
T *append(Arena *arena, Vector<T> *dst, u32 count) {
  if (dst->length + count > dst->capacity) {
    CHECK(dst->capacity <= 268435456);
    u32 capRequired = dst->length + count;
    u32 newCap = dst->capacity;
    do {
      newCap = (newCap * 24) / 16;
      if (newCap == 0) {
        newCap = 4;
      }
    } while (newCap < capRequired);

    T *newData = alloc<T>(arena, newCap);
    if (dst->data != nullptr) {
      memcpy(newData, dst->data, dst->capacity * sizeof(T));
    }
    dst->data = newData;
    dst->capacity = newCap;
  }

  CHECK(dst->length + count <= dst->capacity);
  T *ret = &dst->data[dst->length];
  dst->length += count;
  return ret;
}

/**
 * Allocates a new slot in the vector and returns it to the caller. When the
 * vector is full, a new backing array is allocated into the provided arena and
 * old elements are copied into it.
 */
template <typename T>
T *append(Arena *arena, Vector<T> *dst) {
  if (dst->length + 1 > dst->capacity) {
    CHECK(dst->capacity <= 268435456);
    u32 newCap = (dst->capacity * 24) / 16;
    if (newCap == 0) {
      newCap = 4;
    }

    T *newData = alloc<T>(arena, newCap);
    if (dst->data != nullptr) {
      memcpy(newData, dst->data, dst->capacity * sizeof(T));
    }
    dst->data = newData;
    dst->capacity = newCap;
  }

  CHECK(dst->length + 1 <= dst->capacity);
  T *ret = &dst->data[dst->length];
  dst->length++;
  return ret;
}

template <typename T>
T *append(Arena *arena, Vector<T> *dst, const T &value) {
  T *p = append(arena, dst);
  *p = value;
  return p;
}

/**
 * Creates a vector with a predefined initial capacity.
 */
template <typename T>
Vector<T> vectorWithInitialCapacity(Arena *arena, u32 capacity) {
  Vector<T> ret;
  ret.data = alloc<T>(arena, capacity);
  ret.length = 0;
  ret.capacity = capacity;
  return ret;
}

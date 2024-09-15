#pragma once

#include "std/Slice.hpp"
#include "std/Types.h"
#include "std/Vector.hpp"

#include <string.h>

#define SLICE_FROM_STRLIT(s) \
  { (u8 *)s, (u32)strlen(s) }

b32 compareAsString(Slice<u8> left, Slice<u8> right);
b32 startsWith(Slice<u8> left, Slice<u8> prefix);
b32 endsWith(Slice<u8> left, Slice<u8> suffix);
b32 compareAsString(Slice<u8> left, const char *right);
/** Takes two slices and returns their concatenation. */
Slice<u8> concat(Arena *arena, Slice<u8> left, Slice<u8> right);
/**
 * Takes two slices and returns their concatenation with a null-terminator
 * appended to the end.
 */
Slice<u8> concatAsciiZ(Arena *arena, Slice<u8> left, Slice<u8> right);

/**
 * Copies the contents of the vector into a slice. The storage for the slice
 * will be allocated into the provided arena.
 */
template <typename T>
Slice<T> copyToSlice(Arena *arena, Vector<T> src) {
  if (src.data == nullptr || src.length == 0) {
    return {nullptr, 0};
  }
  T *newData = alloc<T>(arena, src.length);
  memcpy(newData, src.data, src.length * sizeof(T));
  Slice<T> ret = {newData, src.length};
  return ret;
}

template <typename T>
Slice<T> duplicate(Arena *arena, Slice<T> in) {
  Slice<T> ret = {alloc<T>(arena, in.length), in.length};
  memcpy(ret.data, in.data, ret.length * sizeof(T));
  return ret;
}

/**
 * Creates a new zero-initialized slice with the specified length.
 */
template <typename T>
void alloc(Arena *arena, u32 length, Slice<T> &dst) {
  dst.length = length;
  dst.data = alloc<T>(arena, length);
}

template <typename T>
void zeroMemory(Slice<T> s) {
  memset(s.data, 0, s.length * sizeof(T));
}

template <typename T>
void copy(Slice<T> dst, Slice<T> src) {
  CHECK(src.length <= dst.length);
  memcpy(dst.data, src.data, src.length * sizeof(T));
}

template <typename T>
Slice<u8> makeSlice(Arena *arena, const T *src, u32 len) {
  T *newBuf = alloc<T>(arena, len);
  memcpy(newBuf, src, len * sizeof(T));
  return {newBuf, len};
}

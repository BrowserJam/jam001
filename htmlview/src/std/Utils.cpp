#include "std/Utils.hpp"

b32 compareAsString(Slice<u8> left, Slice<u8> right) {
  if (left.data == nullptr || right.data == nullptr) {
    return left.data == right.data;
  }

  if (left.length != right.length) {
    return false;
  }

  return memcmp(left.data, right.data, left.length) == 0;
}

b32 startsWith(Slice<u8> left, Slice<u8> prefix) {
  if (left.data == nullptr || prefix.data == nullptr) {
    return false;
  }

  if (left.length < prefix.length) {
    return false;
  }

  return memcmp(left.data, prefix.data, prefix.length) == 0;
}

b32 endsWith(Slice<u8> left, Slice<u8> suffix) {
  if (left.data == nullptr || suffix.data == nullptr) {
    return false;
  }

  if (left.length < suffix.length) {
    return false;
  }

  return memcmp(left.data + left.length - suffix.length, suffix.data,
                suffix.length) == 0;
}

b32 compareAsString(Slice<u8> left, const char *right) {
  u32 lenRight = strlen(right);
  Slice<u8> tmp = {(u8 *)right, lenRight};
  return compareAsString(left, tmp);
}

Slice<u8> concat(Arena *arena, Slice<u8> left, Slice<u8> right) {
  assert(left.data);
  assert(right.data);
  Slice<u8> ret;
  ret.length = left.length + right.length;
  ret.data = alloc<u8>(arena, ret.length);
  memcpy(ret.data, left.data, left.length);
  memcpy(ret.data + left.length, right.data, right.length);
  return ret;
}

Slice<u8> concatAsciiZ(Arena *arena, Slice<u8> left, Slice<u8> right) {
  assert(left.data);
  assert(right.data);
  Slice<u8> ret;
  ret.length = left.length + right.length + 1;
  ret.data = alloc<u8>(arena, ret.length);
  memcpy(ret.data, left.data, left.length);
  memcpy(ret.data + left.length, right.data, right.length);
  ret.data[ret.length - 1] = '\0';
  return ret;
}
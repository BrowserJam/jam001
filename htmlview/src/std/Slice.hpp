#pragma once

#include "std/Check.h"
#include "std/Types.h"

template <typename T>
struct SliceIterator {
  struct Element {
    T &value;
    u32 index;
  };

  T *data;
  u32 index;

  bool operator!=(const SliceIterator &other) const {
    return index != other.index;
  }

  void operator++() { index++; }

  Element operator*() { return {data[index], index}; }
};

/**
 * A view on a section of a homogeneous array. The data being viewed is not
 * owned by the slice.
 *
 * This can be iterated with a for-each expression; the iterator yields
 * `[value, index]` pairs.
 */
template <typename T>
struct Slice {
  T *data;
  u32 length;

  T &operator[](u32 i) const {
    DCHECK(data != nullptr);
    DCHECK(i < length);
    return data[i];
  }

  SliceIterator<T> begin() { return {data, 0}; }
  SliceIterator<T> end() { return {data, length}; }
};

/**
 * Steps the slice forward by N elements and decreases its length accordingly.
 * The slice must not have atleast N elements.
 */
template <typename T>
inline void shrinkFromLeftByCount(Slice<T> *target, u32 numElements) {
  CHECK(target->data != NULL);
  CHECK(target->length >= numElements);
  target->data += numElements;
  target->length -= numElements;
}

template <typename T>
inline b32 indexOf(Slice<T> s, const T &needle, u32 *out) {
  if (empty(s)) {
    return false;
  }

  for (u32 i = 0; i < s.length; i++) {
    if (s[i] == needle) {
      *out = i;
      return true;
    }
  }

  return false;
}

template <typename T>
inline Slice<T> subarray(Slice<T> s, u32 idxStart, u32 idxEnd) {
  if (idxEnd <= idxStart || s.length <= idxStart) {
    return {nullptr, 0};
  }

  if (s.length < idxEnd) {
    idxEnd = s.length;
  }

  u32 len = idxEnd - idxStart;
  T *data = s.data + idxStart;

  return {data, len};
}

template <typename T>
inline Slice<T> subarray(Slice<T> s, u32 idxStart) {
  return subarray(s, idxStart, s.length);
}

/**
 * Steps the slice forward by one element and decreases its length.
 * The slice must not be empty.
 */
template <typename T>
inline void shrinkFromLeft(Slice<T> *target) {
  CHECK(target->data != NULL);
  CHECK(target->length != 0);
  target->data++;
  target->length -= 1;
}

template <typename T>
inline b32 empty(Slice<T> s) {
  return s.length == 0;
}

/**
 * A macro that can be used to supply a slice (usually a Slice<char>) as an
 * argument to a printf-style function when using a directive like "%.*s".
 */
#define FMT_SLICE(s) (s).length, (s).data

/**
 * Casts a slice from one type to another.
 */
template <typename D, typename S>
Slice<D> cast(Slice<S> in) {
  static_assert(sizeof(D) < sizeof(S) || (sizeof(D) % sizeof(S)) == 0);
  static_assert(sizeof(S) < sizeof(D) || (sizeof(S) % sizeof(D)) == 0);
  Slice<D> ret;
  ret.data = (D *)in.data;
  ret.length = in.length * sizeof(S) / sizeof(D);
  return ret;
}
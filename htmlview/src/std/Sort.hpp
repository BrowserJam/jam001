#pragma once

#include "std/Slice.hpp"
#include "std/Utils.hpp"

template <typename T>
void merge(Slice<T> dst, Slice<T> left, Slice<T> right) {
  u32 idxLeft = 0;
  u32 idxRight = 0;

  for (u32 idxDst = 0; idxDst < dst.length; idxDst++) {
    if (idxLeft < left.length &&
        (idxRight == right.length || left[idxLeft] < right[idxRight])) {
      dst[idxDst] = left[idxLeft++];
    } else {
      dst[idxDst] = right[idxRight++];
    }
  }
}

template <typename T>
void mergeSort_impl(Slice<T> dst, Slice<T> s) {
  if (s.length == 1) {
    return;
  }

  Slice<T> left, right;
  Slice<T> dstLeft, dstRight;

  left.data = s.data;
  left.length = s.length / 2;

  right.data = s.data + left.length;
  right.length = s.length - left.length;

  dstLeft.data = dst.data;
  dstLeft.length = left.length;

  dstRight.data = dst.data + left.length;
  dstRight.length = right.length;

  mergeSort_impl(left, dstLeft);
  mergeSort_impl(right, dstRight);

  merge(dst, left, right);
}

template <typename T>
void mergeSort(Slice<T> dst, Slice<T> s) {
  copy(dst, s);
  mergeSort_impl(dst, s);
}
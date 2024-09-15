#pragma once

#include "std/Arena.h"

template <typename T>
struct ListNode {
  ListNode<T> *next;
  T value;
};

template <typename T>
struct ListIterator {
  ListNode<T> *node;

  ListIterator operator++() {
    node = node->next;
    return *this;
  }

  T *operator->() { return &node->value; }
  T &operator*() { return node->value; }

  bool operator!=(const ListIterator<T> &other) const {
    return node != other.node;
  }
};

template <typename T>
struct List {
  ListNode<T> *first = nullptr;
  ListNode<T> *last = nullptr;

  ListIterator<T> begin() { return {first}; }
  ListIterator<T> end() { return {nullptr}; }
};

template <typename T>
inline T *append(Arena *arena, List<T> &list) {
  ListNode<T> *node = alloc<ListNode<T>>(arena);
  if (list.first == nullptr) {
    list.first = list.last = node;
  } else {
    list.last->next = node;
    node->next = nullptr;
    list.last = node;
  }

  return &node->value;
}

template <typename T>
inline u32 length(const List<T> &list) {
  if (list.first == nullptr) {
    return 0;
  }

  ListNode<T> *cur = list.first;
  u32 numNodes = 1;
  while (cur != list.last) {
    numNodes++;
    cur = cur->next;
  }

  return numNodes;
}

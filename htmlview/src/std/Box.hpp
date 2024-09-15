#pragma once

#include <cstddef>
#include <utility>

template <typename T>
struct Box {
  ~Box() noexcept {
    if (_ptr == nullptr) {
      return;
    }
    delete _ptr;
  }

  Box() noexcept : _ptr(nullptr) {}
  explicit Box(T *p) noexcept : _ptr(p) {}
  Box(std::nullptr_t) noexcept : _ptr(nullptr) {}
  Box(Box<T> &&other) noexcept : _ptr(other._ptr) { other._ptr = nullptr; }
  Box(const Box<T> &) = delete;
  template <typename U>
  Box(Box<U> &&other) noexcept : _ptr(other._ptr) {
    other._ptr = nullptr;
  }

  Box<T> &operator=(Box<T> &&other) noexcept {
    std::swap(_ptr, other._ptr);
    return *this;
  }

  template <typename U>
  Box<T> &operator=(Box<U> &&other) noexcept {
    if (_ptr != nullptr) {
      delete _ptr;
    }

    auto t = other._ptr;
    other._ptr = nullptr;
    _ptr = t;
    return *this;
  }

  Box<T> &operator=(std::nullptr_t) noexcept {
    if (_ptr != nullptr) {
      delete _ptr;
      _ptr = nullptr;
    }

    return *this;
  }

  void operator=(const Box<T> &) = delete;

  T *get() const noexcept { return _ptr; }
  T &operator*() const noexcept { return *_ptr; }
  T *operator->() const noexcept { return _ptr; }
  operator bool() const noexcept { return _ptr; }

  template <typename U>
  bool operator==(const Box<U> &o) const noexcept {
    return _ptr == o._ptr;
  }

  template <typename U>
  bool operator!=(const Box<U> &o) const noexcept {
    return _ptr != o._ptr;
  }

  bool operator==(std::nullptr_t) const noexcept { return !_ptr; }

  bool operator!=(std::nullptr_t) const noexcept { return _ptr; }

  template <class... Args>
  static Box<T> make(Args &&...args) {
    return Box<T>(new T(std::forward<Args>(args)...));
  }

 private:
  template <typename U>
  friend struct Box;
  T *_ptr;
};

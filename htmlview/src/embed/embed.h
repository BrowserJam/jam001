#pragma once

#define EMBED_DECL(name)        \
  extern "C" const char name[]; \
  extern "C" const size_t name##_len;
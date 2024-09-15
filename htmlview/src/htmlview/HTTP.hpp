#pragma once

#include "std/Arena.h"
#include "std/Slice.hpp"

struct Url {
  Slice<u8> protocol;
  Slice<u8> host;
  Slice<u8> port;
  Slice<u8> path;
};

b32 Url_initFromString(Url *self, Arena *arena, Slice<u8> url);
Slice<u8> Url_format(Arena *arena, Url *self);

struct HTTP_Response {
  Slice<u8> body;
  i32 code;
};

b32 HTTP_fetch(Arena *arena, Slice<u8> urlIn, HTTP_Response &res);

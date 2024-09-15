#pragma once

#include "std/Arena.h"
#include "std/Slice.hpp"

struct HTMLAttribute {
  Slice<u8> name;
  Slice<u8> value;
};

struct HTMLOpenTag {
  Slice<u8> name;
  Slice<HTMLAttribute> attributes;
  b32 isSelfClosing;
};

struct HTMLText {
  Slice<u8> contents;
};

struct HTMLCloseTag {
  Slice<u8> name;
};

enum class HTMLTokenKind {
  OpenTag,
  Text,
  CloseTag,
};

struct HTMLToken {
  HTMLTokenKind kind;

  union {
    HTMLOpenTag openTag;
    HTMLText text;
    HTMLCloseTag closeTag;
  };
};

b32 HTML_tokenize(Arena *arena, Slice<u8> source, Slice<HTMLToken> &out);
b32 HTML_print(Slice<HTMLToken> tokens);
b32 HTML_isWhitespace(u8 ch);

#pragma once

#include "htmlview/HTML.hpp"
#include "std/Arena.h"
#include "std/Slice.hpp"

#define DOM_INVALID_INDEX (0xFFFFFFFF)

enum class DOM_NodeKind {
  Element,
  Text,
};

struct DOM_Node {
  DOM_NodeKind kind;

  union {
    u32 idxElement;
    u32 idxText;
  };

  u32 idxPrev;
  u32 idxNext;
  u32 idxParent;

  Slice<u32> children;
};

struct DOM_ElementData {
  u32 idxNode;
  Slice<u8> name;
  Slice<HTMLAttribute> attributes;
  b32 isSelfClosing;
};

struct DOM_TextData {
  u32 idxNode;
  Slice<u8> contents;
};

struct DOM_Tree {
  Slice<DOM_ElementData> elementData;
  Slice<DOM_TextData> textData;
  Slice<DOM_Node> nodes;

  u32 idxHtmlNode;
  u32 idxHeadNode;
};

extern const Slice<u8> TAG_HTML;
extern const Slice<u8> TAG_HEAD;
extern const Slice<u8> TAG_TITLE;
extern const Slice<u8> TAG_BODY;
extern const Slice<u8> TAG_DD;
extern const Slice<u8> TAG_DT;
extern const Slice<u8> TAG_P;
extern const Slice<u8> TAG_A;
extern const Slice<u8> TAG_DIV;
extern const Slice<u8> TAG_DL;
extern const Slice<u8> TAG_UL;
extern const Slice<u8> TAG_TABLE;
extern const Slice<u8> TAG_TD;
extern const Slice<u8> TAG_TH;
extern const Slice<u8> TAG_H1;
extern const Slice<u8> TAG_H2;
extern const Slice<u8> TAG_H3;
extern const Slice<u8> TAG_H4;
extern const Slice<u8> TAG_H5;
extern const Slice<u8> TAG_H6;
extern const Slice<u8> TAG_HEADER;

b32 DOM_Tree_init(DOM_Tree *self, Arena *arena, Slice<HTMLToken> tokens);
b32 DOM_Tree_print(DOM_Tree *self);

b32 equalCaseInsensitive(Slice<u8> l, Slice<u8> r);
#define equalCaseInsensitiveLit(l, s) \
  equalCaseInsensitive(l, SLICE_FROM_STRLIT(s))

b32 DOM_isBlock(DOM_ElementData &elem);
b32 DOM_isInline(DOM_ElementData &elem);

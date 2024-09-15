#include "htmlview/DOM.hpp"
#include <cstdio>
#include "htmlview/HTML.hpp"
#include "std/Arena.h"
#include "std/Slice.hpp"
#include "std/Utils.hpp"
#include "std/Vector.hpp"

/** Insertion mode */
enum class InsMode {
  Initial,
  BeforeHtml,
  BeforeHead,
  InHead,
  AfterHead,
  InBody,
  Text,
  AfterBody,
  AfterAfterBody,
};

struct OpenElement {
  u32 idxNode;

  Vector<u32> children;
};

struct DOM_Parser {
  // The return arena; only permanent data can be allocated here
  Arena *arena;

  Vector<OpenElement> openElementStack;
  InsMode insertionMode = InsMode::Initial;
  b32 cannotChangeMode = false;

  Vector<DOM_Node> nodes;
  Vector<DOM_ElementData> elementData;
  Vector<DOM_TextData> textData;

  u32 idxHtmlNode;
  u32 idxHeadNode;

  Slice<HTMLToken> tokens;
  b32 reparse = false;
};

const Slice<u8> TAG_HTML = SLICE_FROM_STRLIT("html");
const Slice<u8> TAG_HEAD = SLICE_FROM_STRLIT("head");
const Slice<u8> TAG_TITLE = SLICE_FROM_STRLIT("title");
const Slice<u8> TAG_BODY = SLICE_FROM_STRLIT("body");
const Slice<u8> TAG_DD = SLICE_FROM_STRLIT("dd");
const Slice<u8> TAG_DT = SLICE_FROM_STRLIT("dt");
const Slice<u8> TAG_P = SLICE_FROM_STRLIT("p");
const Slice<u8> TAG_A = SLICE_FROM_STRLIT("a");
const Slice<u8> TAG_DIV = SLICE_FROM_STRLIT("div");
const Slice<u8> TAG_DL = SLICE_FROM_STRLIT("dl");
const Slice<u8> TAG_UL = SLICE_FROM_STRLIT("ul");
const Slice<u8> TAG_TABLE = SLICE_FROM_STRLIT("table");
const Slice<u8> TAG_TD = SLICE_FROM_STRLIT("td");
const Slice<u8> TAG_TH = SLICE_FROM_STRLIT("th");
const Slice<u8> TAG_H1 = SLICE_FROM_STRLIT("h1");
const Slice<u8> TAG_H2 = SLICE_FROM_STRLIT("h2");
const Slice<u8> TAG_H3 = SLICE_FROM_STRLIT("h3");
const Slice<u8> TAG_H4 = SLICE_FROM_STRLIT("h4");
const Slice<u8> TAG_H5 = SLICE_FROM_STRLIT("h5");
const Slice<u8> TAG_H6 = SLICE_FROM_STRLIT("h6");
const Slice<u8> TAG_HEADER = SLICE_FROM_STRLIT("header");
const Slice<u8> TAG_ADDRESS = SLICE_FROM_STRLIT("address");

static OpenElement &currentOpenElement(DOM_Parser &P) {
  DCHECK(P.openElementStack.length != 0);

  return P.openElementStack[P.openElementStack.length - 1];
}

b32 equalCaseInsensitive(Slice<u8> l, Slice<u8> r) {
  if (l.length != r.length) {
    return false;
  }
  if (l.data == nullptr && r.data == nullptr) {
    return true;
  }

  for (u32 i = 0; i < l.length; i++) {
    if (l[i] == r[i]) {
      continue;
    }

    u8 ch0 = l[i];
    u8 ch1 = r[i];
    if ('A' <= ch0 && ch0 <= 'Z') {
      ch0 |= 0x20;
    }

    if ('A' <= ch1 && ch1 <= 'Z') {
      ch1 |= 0x20;
    }

    if (ch0 != ch1) {
      return false;
    }
  }

  return true;
}

static b32 equalCaseInsensitiveAny(Slice<u8> self) {
  return false;
}

template <typename... Args>
static b32 equalCaseInsensitiveAny(Slice<u8> self, Slice<u8> r, Args... rest) {
  if (equalCaseInsensitive(self, r)) {
    return true;
  }

  return equalCaseInsensitiveAny(self, rest...);
}

static DOM_Node *createElement(Arena *arena,
                               DOM_Parser &P,
                               HTMLOpenTag &token,
                               u32 &idxNode) {
  u32 idxElement = P.elementData.length;
  idxNode = P.nodes.length;

  DOM_ElementData *data = append(arena, &P.elementData);
  DCHECK(idxElement < P.elementData.length);
  data->idxNode = idxNode;
  data->name = token.name;
  data->attributes = token.attributes;
  data->isSelfClosing = token.isSelfClosing;

  DOM_Node *node = append(arena, &P.nodes);
  node->idxPrev = DOM_INVALID_INDEX;
  node->idxNext = DOM_INVALID_INDEX;
  node->idxParent = DOM_INVALID_INDEX;

  node->kind = DOM_NodeKind::Element;
  node->idxElement = idxElement;
  return node;
}

static DOM_Node *createElement(Arena *arena,
                               DOM_Parser &P,
                               Slice<u8> name,
                               u32 &idxNode) {
  u32 idxElement = P.elementData.length;
  idxNode = P.nodes.length;

  DOM_ElementData *data = append(arena, &P.elementData);
  DCHECK(idxElement < P.elementData.length);
  data->idxNode = idxNode;
  data->name = name;
  data->attributes = {};

  DOM_Node *node = append(arena, &P.nodes);
  node->idxPrev = DOM_INVALID_INDEX;
  node->idxNext = DOM_INVALID_INDEX;
  node->idxParent = DOM_INVALID_INDEX;

  node->kind = DOM_NodeKind::Element;
  node->idxElement = idxElement;
  return node;
}

static DOM_Node *createText(Arena *arena,
                            DOM_Parser &P,
                            Slice<u8> contents,
                            u32 &idxNode) {
  u32 idxText = P.textData.length;
  idxNode = P.nodes.length;

  DOM_TextData *data = append(arena, &P.textData);
  data->idxNode = idxNode;
  data->contents = contents;

  DOM_Node *node = append(arena, &P.nodes);
  node->idxPrev = DOM_INVALID_INDEX;
  node->idxNext = DOM_INVALID_INDEX;
  node->idxParent = DOM_INVALID_INDEX;

  node->kind = DOM_NodeKind::Text;
  node->idxText = idxText;
  return node;
}

static void insertNode(Arena *arena, DOM_Parser &P, u32 &idxNode) {
  OpenElement &openElem = currentOpenElement(P);

  u32 idxPrev = DOM_INVALID_INDEX;

  if (openElem.children.length != 0) {
    // Determine the index of the previous node
    idxPrev = openElem.children[openElem.children.length - 1];

    // Set the prev node's next node to this node
    DOM_Node &prev = P.nodes[idxPrev];
    DCHECK(prev.idxNext == DOM_INVALID_INDEX);
    prev.idxNext = idxNode;
  }

  P.nodes[idxNode].idxPrev = idxPrev;
  P.nodes[idxNode].idxParent = openElem.idxNode;

  // Append this node to the open element
  *append(arena, &openElem.children) = idxNode;
  DCHECK(openElem.children.length > 0);

  DOM_Node &node = P.nodes[openElem.idxNode];
  DOM_ElementData &elem = P.elementData[node.idxElement];
}

static DOM_Node *insertElement(Arena *arena,
                               DOM_Parser &P,
                               HTMLOpenTag &tag,
                               u32 &idxNode) {
  DOM_Node *node = createElement(arena, P, tag, idxNode);
  insertNode(arena, P, idxNode);
  return node;
}

static DOM_Node *insertElement(Arena *arena,
                               DOM_Parser &P,
                               Slice<u8> name,
                               u32 &idxNode) {
  DOM_Node *node = createElement(arena, P, name, idxNode);
  insertNode(arena, P, idxNode);
  return node;
}

static DOM_Node *insertText(Arena *arena,
                            DOM_Parser &P,
                            HTMLText &text,
                            u32 &idxNode) {
  DOM_Node *node = createText(arena, P, text.contents, idxNode);
  insertNode(arena, P, idxNode);
  return node;
}

static void popOpenElement(DOM_Parser &P) {
  CHECK(P.openElementStack.length != 0);
  OpenElement &openElem = currentOpenElement(P);
  DCHECK(openElem.idxNode != DOM_INVALID_INDEX);

  // Seal the children array
  DOM_Node &node = P.nodes[openElem.idxNode];
  node.children = copyToSlice(P.arena, openElem.children);

  P.openElementStack.length--;
}

static void pushOpenElement(Arena *arena, DOM_Parser &P, u32 idxNode) {
  *append(arena, &P.openElementStack) = {idxNode, {}};
}

static void generateImpliedEndTags(Arena *arena,
                                   DOM_Parser &P,
                                   Slice<u8> except) {
  while (P.openElementStack.length != 0) {
    OpenElement &openElem = currentOpenElement(P);

    DCHECK(openElem.idxNode != DOM_INVALID_INDEX);
    DOM_Node &node = P.nodes[openElem.idxNode];
    DCHECK(node.kind == DOM_NodeKind::Element);
    DOM_ElementData &data = P.elementData[node.idxElement];
    Slice<u8> name = data.name;

    if (!empty(except) && equalCaseInsensitive(name, except)) {
      return;
    }

    if (equalCaseInsensitive(name, TAG_DD) ||
        equalCaseInsensitive(name, TAG_DT) ||
        equalCaseInsensitiveLit(name, "li") ||
        equalCaseInsensitiveLit(name, "optgroup") ||
        equalCaseInsensitiveLit(name, "nextid") ||
        equalCaseInsensitiveLit(name, "option") ||
        equalCaseInsensitive(name, TAG_P) ||
        equalCaseInsensitiveLit(name, "rb") ||
        equalCaseInsensitiveLit(name, "rp") ||
        equalCaseInsensitiveLit(name, "rt") ||
        equalCaseInsensitiveLit(name, "rtc")) {
      popOpenElement(P);
    } else {
      return;
    }
  }
}

static void DOM_parse_beforeHtml(Arena *arena, DOM_Parser &P) {
  HTMLToken &token = P.tokens[0];

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      CHECK(P.idxHtmlNode == DOM_INVALID_INDEX);

      if (equalCaseInsensitiveLit(token.openTag.name, "html")) {
        createElement(arena, P, token.openTag, P.idxHtmlNode);
      } else {
        createElement(arena, P, TAG_HTML, P.idxHtmlNode);
        P.reparse = true;
      }
      pushOpenElement(arena, P, P.idxHtmlNode);
      P.insertionMode = InsMode::BeforeHead;
      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitive(token.closeTag.name, TAG_HEAD) ||
          equalCaseInsensitive(token.closeTag.name, TAG_BODY) ||
          equalCaseInsensitive(token.closeTag.name, TAG_HTML) ||
          equalCaseInsensitiveLit(token.closeTag.name, "br")) {
        DOM_Node *node = createElement(arena, P, TAG_HTML, P.idxHtmlNode);
        pushOpenElement(arena, P, P.idxHtmlNode);
        P.reparse = true;
        P.insertionMode = InsMode::BeforeHead;
      } else {
        // Parse error; ignore token
        return;
      }
      break;
    }
    case HTMLTokenKind::Text: {
      CHECK(P.idxHtmlNode == DOM_INVALID_INDEX);
      DOM_Node *node = createElement(arena, P, TAG_HTML, P.idxHtmlNode);
      pushOpenElement(arena, P, P.idxHtmlNode);

      P.insertionMode = InsMode::BeforeHead;
      P.reparse = true;
      break;
    }
  }

  return;
}

static void DOM_parse_beforeHead(Arena *arena, DOM_Parser &P) {
  CHECK(P.idxHtmlNode != DOM_INVALID_INDEX);
  HTMLToken &token = P.tokens[0];

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      CHECK(P.idxHeadNode == DOM_INVALID_INDEX);
      if (equalCaseInsensitive(token.openTag.name, TAG_HEAD)) {
        insertElement(arena, P, token.openTag, P.idxHeadNode);
        DCHECK(P.idxHeadNode != DOM_INVALID_INDEX);
        pushOpenElement(arena, P, P.idxHeadNode);
        P.insertionMode = InsMode::InHead;
        return;
      }

      if (!equalCaseInsensitive(token.openTag.name, TAG_HTML)) {
        insertElement(arena, P, TAG_HEAD, P.idxHeadNode);
        DCHECK(P.idxHeadNode != DOM_INVALID_INDEX);
        pushOpenElement(arena, P, P.idxHeadNode);
        P.insertionMode = InsMode::InHead;
        P.reparse = true;
      }

      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitiveLit(token.closeTag.name, "head") ||
          equalCaseInsensitiveLit(token.closeTag.name, "body") ||
          equalCaseInsensitiveLit(token.closeTag.name, "html") ||
          equalCaseInsensitiveLit(token.closeTag.name, "br")) {
        insertElement(arena, P, TAG_HEAD, P.idxHeadNode);
        DCHECK(P.idxHeadNode != DOM_INVALID_INDEX);
        pushOpenElement(arena, P, P.idxHeadNode);
        P.reparse = true;
        P.insertionMode = InsMode::InHead;
      } else {
        // Parse error; ignore token
        return;
      }
      break;
    }
    case HTMLTokenKind::Text: {
      insertElement(arena, P, TAG_HEAD, P.idxHeadNode);
      DCHECK(P.idxHeadNode != DOM_INVALID_INDEX);
      pushOpenElement(arena, P, P.idxHeadNode);
      P.insertionMode = InsMode::InHead;
      P.reparse = true;
      break;
    }
  }
}

static void popHeadElement(DOM_Parser &P) {
  CHECK(P.openElementStack.length != 0);
  DCHECK(currentOpenElement(P).idxNode == P.idxHeadNode);
  popOpenElement(P);
  P.insertionMode = InsMode::AfterHead;
}

static void DOM_parse_inHead(Arena *arena, DOM_Parser &P) {
  HTMLToken &token = P.tokens[0];
  CHECK(P.idxHtmlNode != DOM_INVALID_INDEX);
  CHECK(P.idxHeadNode != DOM_INVALID_INDEX);

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      if (equalCaseInsensitive(token.openTag.name, TAG_HEAD)) {
        // Ignore
        return;
      }

      // FIXME(danielm): elements that actually belong to head will also be
      // moved to body

      popHeadElement(P);
      P.insertionMode = InsMode::AfterHead;
      P.reparse = true;

      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitiveLit(token.closeTag.name, "head")) {
        popHeadElement(P);
        return;
      }
      if (equalCaseInsensitiveLit(token.closeTag.name, "html")) {
        return;
      }

      // Parse error; ignore
      break;
    }
    case HTMLTokenKind::Text: {
      popHeadElement(P);
      P.reparse = true;
      break;
    }
  }
}

static void DOM_parse_afterHead(Arena *arena, DOM_Parser &P) {
  HTMLToken &token = P.tokens[0];

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      u32 idxNode;
      if (equalCaseInsensitive(token.openTag.name, TAG_BODY)) {
        insertElement(arena, P, token.openTag, idxNode);
        pushOpenElement(arena, P, idxNode);
        P.insertionMode = InsMode::InBody;
        return;
      }

      // Insert a <body>
      insertElement(arena, P, TAG_BODY, idxNode);
      pushOpenElement(arena, P, idxNode);

      P.insertionMode = InsMode::InBody;
      P.reparse = true;
      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitiveLit(token.closeTag.name, "body") ||
          equalCaseInsensitiveLit(token.closeTag.name, "html") ||
          equalCaseInsensitiveLit(token.closeTag.name, "br")) {
        u32 idxNode;
        insertElement(arena, P, SLICE_FROM_STRLIT("body"), idxNode);
        pushOpenElement(arena, P, idxNode);
        P.insertionMode = InsMode::InBody;
        P.reparse = true;
        return;
      }
      if (equalCaseInsensitive(token.closeTag.name, TAG_HTML)) {
        return;
      }

      // Parse error; ignore
      break;
    }
    case HTMLTokenKind::Text: {
      u32 idxNode;
      insertElement(arena, P, TAG_BODY, idxNode);
      pushOpenElement(arena, P, idxNode);
      P.insertionMode = InsMode::InBody;
      P.reparse = true;
      break;
    }
  }
}

static void DOM_parse_afterBody(Arena *arena, DOM_Parser &P) {
  HTMLToken &token = P.tokens[0];

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitive(token.closeTag.name, TAG_HTML)) {
        P.insertionMode = InsMode::AfterAfterBody;
        return;
      }

      // Parse error; ignore
      break;
    }
    default: {
      // Parse error; ignore
      break;
    }
  }
}

static Slice<u8> getOpenElementName(DOM_Parser &P, OpenElement &openElem) {
  DOM_Node &node = P.nodes[openElem.idxNode];
  CHECK(node.idxElement != DOM_INVALID_INDEX);
  DOM_ElementData &data = P.elementData[node.idxElement];
  return data.name;
}

static b32 openElementIsNamed(DOM_Parser &P,
                              OpenElement &openElem,
                              Slice<u8> name) {
  DOM_Node &node = P.nodes[openElem.idxNode];
  if (node.idxElement == DOM_INVALID_INDEX) {
    return false;
  }

  return equalCaseInsensitive(getOpenElementName(P, openElem), name);
}

static b32 currentOpenElementIsNamed(DOM_Parser &P, Slice<u8> name) {
  if (P.openElementStack.length == 0) {
    return false;
  }

  OpenElement &openElem = currentOpenElement(P);
  return openElementIsNamed(P, openElem, name);
}

static b32 hasElementInScope(DOM_Parser &P, Slice<u8> name) {
  u32 lenStack = P.openElementStack.length;
  for (u32 i = lenStack - 1; i < lenStack; i--) {
    Slice<u8> elemName = getOpenElementName(P, P.openElementStack[i]);
    if (equalCaseInsensitive(elemName, name)) {
      return true;
    }

    if (equalCaseInsensitiveAny(elemName, TAG_HTML, TAG_TABLE, TAG_TH,
                                TAG_TD)) {
      return false;
    }
  }

  DCHECK(!"there should be a html element in the stack");
}

static void DOM_parse_inBody(Arena *arena, DOM_Parser &P) {
  HTMLToken &token = P.tokens[0];

  switch (token.kind) {
    case HTMLTokenKind::OpenTag: {
      if (equalCaseInsensitive(token.openTag.name, TAG_BODY)) {
        return;
      }

      // A start tag whose tag name is one of: "address", "article", "aside",
      // "blockquote", "center", "details", "dialog", "dir", "div", "dl",
      // "fieldset", "figcaption", "figure", "footer", "header", "hgroup",
      // "main", "menu", "nav", "ol", "p", "search", "section", "summary", "ul"
      if (equalCaseInsensitiveAny(token.openTag.name, TAG_ADDRESS, TAG_DIV,
                                  TAG_DL, TAG_P, TAG_UL)) {
        if (currentOpenElementIsNamed(P, TAG_P)) {
          popOpenElement(P);
        }
      }

      // A start tag whose tag name is one of: "h1", "h2", "h3", "h4", "h5",
      // "h6"
      if (equalCaseInsensitiveAny(token.openTag.name, TAG_H1, TAG_H2, TAG_H3,
                                  TAG_H4, TAG_H5, TAG_H6)) {
        if (hasElementInScope(P, TAG_P)) {
          popOpenElement(P);
        }
      }

      // A start tag whose tag name is one of: "dd", "dt"
      if (equalCaseInsensitive(token.openTag.name, TAG_DD) ||
          equalCaseInsensitive(token.openTag.name, TAG_DT)) {
        while (true) {
          if (currentOpenElementIsNamed(P, TAG_DD)) {
            generateImpliedEndTags(arena, P, TAG_DD);

            while (!currentOpenElementIsNamed(P, TAG_DD)) {
              popOpenElement(P);
            }
            popOpenElement(P);
            break;
          }

          if (currentOpenElementIsNamed(P, TAG_DT)) {
            generateImpliedEndTags(arena, P, TAG_DT);

            while (!currentOpenElementIsNamed(P, TAG_DT)) {
              popOpenElement(P);
            }
            popOpenElement(P);
            break;
          }

          if (!currentOpenElementIsNamed(P, TAG_P)) {
            break;
          }
        }

        if (currentOpenElementIsNamed(P, TAG_P)) {
          popOpenElement(P);
        }

        u32 idxNode;
        insertElement(arena, P, token.openTag, idxNode);
        pushOpenElement(arena, P, idxNode);

        return;
      }

      u32 idxNode;
      insertElement(arena, P, token.openTag, idxNode);
      if (!token.openTag.isSelfClosing) {
        pushOpenElement(arena, P, idxNode);
      }
      break;
    }
    case HTMLTokenKind::CloseTag: {
      if (equalCaseInsensitive(token.closeTag.name, TAG_BODY)) {
        if (!hasElementInScope(P, TAG_BODY)) {
          // Parse error; ignore
          return;
        }

        popOpenElement(P);
        P.insertionMode = InsMode::AfterBody;
        return;
      }

      if (equalCaseInsensitive(token.closeTag.name, TAG_HTML)) {
        if (!currentOpenElementIsNamed(P, token.closeTag.name)) {
          // Parse error; ignore
          return;
        }

        popOpenElement(P);
        P.insertionMode = InsMode::AfterBody;
        P.reparse = true;
        return;
      }

      // Generate implied end tags
      generateImpliedEndTags(arena, P, token.closeTag.name);

      if (!currentOpenElementIsNamed(P, token.closeTag.name)) {
        // FIXME(danielm): check that the "the stack of open elements does not
        // have an element in scope that is an HTML element with the same tag
        // name as that of the token"
        // Parse error; ignore
        return;
      }

      while (!currentOpenElementIsNamed(P, token.closeTag.name)) {
        popOpenElement(P);
      }

      popOpenElement(P);

      break;
    }
    case HTMLTokenKind::Text: {
      u32 idxNode;
      insertText(arena, P, token.text, idxNode);
      break;
    }
  }
}

b32 DOM_Tree_init(DOM_Tree *self, Arena *arena, Slice<HTMLToken> tokens) {
  DOM_Parser parser = {};
  parser.tokens = tokens;
  parser.idxHtmlNode = DOM_INVALID_INDEX;
  parser.idxHeadNode = DOM_INVALID_INDEX;

  // TODO(danielm): doctype

  parser.insertionMode = InsMode::BeforeHtml;
  parser.arena = arena;

  ArenaTemp temp = getScratch(&arena, 1);

  while (parser.tokens.length > 0) {
    parser.reparse = false;

    switch (parser.insertionMode) {
      case InsMode::BeforeHtml:
        DOM_parse_beforeHtml(temp.arena, parser);
        break;
      case InsMode::BeforeHead:
        DOM_parse_beforeHead(temp.arena, parser);
        break;
      case InsMode::InHead:
        DOM_parse_inHead(temp.arena, parser);
        break;
      case InsMode::AfterHead:
        DOM_parse_afterHead(temp.arena, parser);
        break;
      case InsMode::InBody:
        DOM_parse_inBody(temp.arena, parser);
        break;
      case InsMode::AfterBody:
        DOM_parse_afterBody(temp.arena, parser);
        break;
      case InsMode::AfterAfterBody:
        break;
      default:
        TODO();
        break;
    }

    if (!parser.reparse) {
      shrinkFromLeft(&parser.tokens);
    }
  }

  while (parser.openElementStack.length != 0) {
    popOpenElement(parser);
  }

  self->elementData = copyToSlice(arena, parser.elementData);

  DCHECK(self->elementData.length == parser.elementData.length);
  self->textData = copyToSlice(arena, parser.textData);
  self->nodes = copyToSlice(arena, parser.nodes);
  self->idxHtmlNode = parser.idxHtmlNode;
  self->idxHeadNode = parser.idxHeadNode;

  releaseScratch(temp);
  return true;
}

#include <stdio.h>

b32 DOM_Tree_print(DOM_Tree *self, u32 idxNode) {
  DOM_Node &node = self->nodes[idxNode];
  if (node.kind == DOM_NodeKind::Text) {
    DOM_TextData &data = self->textData[node.idxText];
    printf("%.*s", FMT_SLICE(data.contents));
  } else {
    DOM_ElementData &data = self->elementData[node.idxElement];
    printf("<%.*s (%u/%u) ", FMT_SLICE(data.name), idxNode, node.idxElement);

    for (u32 i = 0; i < data.attributes.length; i++) {
      printf("%.*s='%.*s' ", FMT_SLICE(data.attributes[i].name),
             FMT_SLICE(data.attributes[i].value));
    }
    if (data.isSelfClosing) {
      printf("/>");
      CHECK(empty(node.children));
    } else {
      printf(">");
    }
    for (auto [idxChildNode, _] : node.children) {
      DOM_Tree_print(self, idxChildNode);
    }

    printf("</%.*s>", FMT_SLICE(data.name));
  }

  return true;
}

b32 DOM_Tree_print(DOM_Tree *self) {
  return DOM_Tree_print(self, self->idxHtmlNode);
}

b32 DOM_isBlock(DOM_ElementData &elem) {
  return equalCaseInsensitiveAny(elem.name, TAG_BODY, TAG_DIV, TAG_P, TAG_H1,
                                 TAG_H2, TAG_H3, TAG_H4, TAG_H5, TAG_H6, TAG_DL,
                                 TAG_DT, TAG_DD, TAG_HEADER, TAG_ADDRESS);
}

b32 DOM_isInline(DOM_ElementData &elem) {
  return equalCaseInsensitiveAny(elem.name, TAG_A);
}

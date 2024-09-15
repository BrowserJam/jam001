#include "embed/embed.h"
#include "gpu/Renderer.hpp"
#include "htmlview/DOM.hpp"
#include "htmlview/HTML.hpp"
#include "htmlview/HTTP.hpp"
#include "htmlview/OS.hpp"
#include "log/log.h"
#include "std/Arena.h"
#include "std/Utils.hpp"

#include "stb/stb_rect_pack.h"
#include "stb/stb_truetype.h"
#include "std/Vector.hpp"

EMBED_DECL(font_regular);
EMBED_DECL(font_bold);

static Arena arenaPerm;
static Arena arenaTemp;

static const i32 EM_SIZE = 16;

extern "C" {
static void Arena_init(Arena *dst) {
  const u64 SIZ_TOTAL = u64(1) * 1024 * 1024 * 1024;
  const u64 SIZ_INITIAL_COMMITED = u64(16) * 1024 * 1024;

  u8 *pBaseAddr = (u8 *)os_reserve_vm(SIZ_TOTAL);
  CHECK(pBaseAddr);

  u8 *beg = pBaseAddr + SIZ_TOTAL - SIZ_INITIAL_COMMITED;
  if (!os_commit_vm(beg, SIZ_INITIAL_COMMITED)) {
    log_error("os_commit_vm failed");
    os_abort();
  }

  dst->beg = beg;
  dst->end = beg + SIZ_INITIAL_COMMITED;

  log_info("Arena %p initial size %lluMiB max size %lluGiB", dst,
           SIZ_INITIAL_COMMITED / 1024 / 1024, SIZ_TOTAL / 1024 / 1024 / 1024);
}

static void setupArenas() {
  Arena_init(&arenaPerm);
  Arena_init(&arenaTemp);
}

void handleOOM(Arena *arena) {
  if (arena != &arenaPerm && arena != &arenaTemp) {
    CHECK(!"CANNOT GROW NON-ROOT ARENA: OUT OF MEMORY");
  }
  const u64 SIZ_GROW = 64 * 1024 * 1024;
  u8 *newBeg = arena->beg - SIZ_GROW;
  if (!os_commit_vm(newBeg, SIZ_GROW)) {
    CHECK(!"CANNOT GROW ARENA: OUT OF MEMORY");
  }

  arena->beg = newBeg;
}

ArenaTemp getScratch(Arena **pConflicts, u32 numConflicts) {
  ArenaTemp ret;
  if (!pConflicts || numConflicts == 0) {
    ret.arena = &arenaTemp;
    ret.saved = arenaTemp;
    return ret;
  }
  if (numConflicts > 1) {
    os_abort();
  }

  if (pConflicts[0] == &arenaTemp) {
    ret.arena = &arenaPerm;
    ret.saved = arenaPerm;
  } else {
    ret.arena = &arenaTemp;
    ret.saved = arenaTemp;
  }
  return ret;
}
}

enum class FontStyle {
  Normal,
  Italic,
};

enum class FontWeight {
  Normal,
  Bold,
};

struct Font {
  FontStyle style;
  FontWeight weight;
  i32 pointSize;

  stbtt_pack_context packCtx;
  Slice<stbtt_packedchar> packedChars;
  GPU_Image image;
  u32 width, height;
  f32 size;
  f32 ascent;
};

static b32 Font_init(Font *self,
                     Arena *arena,
                     GPU_Device gpu,
                     const char *data,
                     u32 len,
                     i32 pointSize,
                     FontStyle style,
                     FontWeight weight) {
  ArenaTemp temp = getScratch(&arena, 1);
  Slice<u8> pixels;
  u32 w = 1024;
  u32 h = 1024;
  f32 size = STBTT_POINT_SIZE(pointSize);
  alloc(temp.arena, w * h, pixels);
  Slice<stbtt_packedchar> packedChars;
  alloc(arena, 256, packedChars);
  stbtt_pack_context packCtx;
  stbtt_PackBegin(&packCtx, pixels.data, w, h, 0, 1, nullptr);
  stbtt_PackFontRange(&packCtx, (const u8 *)data, 0, size, 0, 256,
                      packedChars.data);
  stbtt_PackEnd(&packCtx);

  f32 ascent, descent, linegap;
  stbtt_GetScaledFontVMetrics((const u8 *)data, 0, size, &ascent, &descent,
                              &linegap);

  GPU_ImageDesc fontImageDesc = {};
  fontImageDesc.format = GPU_PixelFormat::R8;
  fontImageDesc.width = w;
  fontImageDesc.height = h;
  fontImageDesc.pixels = pixels;
  GPU_Image image;
  GPU_createImage(gpu, arena, &fontImageDesc, &image);

  releaseScratch(temp);

  self->width = w;
  self->height = h;
  self->packCtx = packCtx;
  self->packedChars = packedChars;
  self->image = image;
  self->size = size;
  self->ascent = ascent;
  self->pointSize = pointSize;
  self->style = style;
  self->weight = weight;
  return true;
}

static u32 findBestFont(Slice<Font> list,
                        i32 pointSize,
                        FontStyle style,
                        FontWeight weight) {
  u32 idxClosest = 0;
  i32 sizeDist = 0x7FFFFFFF;

  for (u32 idxFont = 0; idxFont < list.length; idxFont++) {
    Font &cur = list[idxFont];
    if (cur.style != style || cur.weight != weight) {
      continue;
    }

    if (cur.pointSize == pointSize) {
      return idxFont;
    }

    i32 curSizeDist = pointSize - cur.pointSize;
    if (curSizeDist < sizeDist) {
      sizeDist = curSizeDist;
      idxClosest = idxFont;
    }
  }

  // Return the closest one if there was no match
  return idxClosest;
}

static void Font_getPackedQuad(Font *self,
                               int codepoint,
                               f32 *xpos,
                               f32 *ypos,
                               stbtt_aligned_quad *aq) {
  stbtt_GetPackedQuad(self->packedChars.data, self->width, self->height,
                      codepoint, xpos, ypos, aq, 0);
}

static void Font_measureText(Font *self,
                             Slice<u8> text,
                             f32 x0,
                             f32 x1,
                             v2 start,
                             v2 *out,
                             f32 *xCursor) {
  f32 x = start.x;
  // f32 y = start.y + -self->size;
  f32 y = start.y + self->ascent;
  const f32 width = x1 - x0;

  f32 y0 = y;

  *out = {0, 0};

  // FIXME(danielm): utf-8
  // FIXME(danielm): overflow wrap
  u32 idxChar = 0;
  while (idxChar < text.length) {
    if (text[idxChar] == '\r' || text[idxChar] == '\n') {
      idxChar++;
      continue;
    }
    f32 nextX = x;
    stbtt_aligned_quad aq;
    // NOTE(danielm): y is never written by stbtt
    Font_getPackedQuad(self, text[idxChar], &nextX, &y, &aq);

    if (nextX > x1) {
      // If this is not the very first glyph on the line
      if (false && nextX - x < width) {
        // Try again on the next line
        y = y + -self->size;
        x = x0;
        continue;
      }
    }

    x = nextX;
    idxChar++;
  }

  f32 dy = y - y0;
  out->y = dy;
  *xCursor = x;
}

static void Font_drawText(Font *self,
                          Arena *arena,
                          Vector<GPU_Vertex> &vertices,
                          Vector<u32> &indices,
                          Slice<u8> text,
                          f32 x0,
                          f32 x1,
                          v2 start,
                          v4 color) {
  f32 x = start.x;
  // f32 y = start.y + -self->size;
  f32 y = start.y + self->ascent;
  const f32 width = x1 - x0;

  // FIXME(danielm): utf-8
  // FIXME(danielm): overflow wrap
  u32 idxChar = 0;
  while (idxChar < text.length) {
    if (text[idxChar] == '\r' || text[idxChar] == '\n') {
      idxChar++;
      continue;
    }
    f32 nextX = x;
    stbtt_aligned_quad aq;
    // NOTE(danielm): y is never written by stbtt
    Font_getPackedQuad(self, text[idxChar], &nextX, &y, &aq);

    if (nextX > x1) {
      // If this is not the very first glyph on the line
      if (false && nextX - x < width) {
        // Try again on the next line
        y = y + -self->size;
        x = x0;
        continue;
      }
    }

    u32 idxTL = vertices.length;
    u32 idxTR = idxTL + 1;
    u32 idxBR = idxTL + 2;
    u32 idxBL = idxTL + 3;

    u32 *ind = append(arena, &indices, 6);
    ind[0] = idxTL;
    ind[1] = idxTR;
    ind[2] = idxBL;
    ind[3] = idxBL;
    ind[4] = idxTR;
    ind[5] = idxBR;

    GPU_Vertex *corners = append(arena, &vertices, 4);

    corners[0].position = {aq.x0, aq.y0};
    corners[0].texcoord0 = {aq.s0, aq.t0};
    corners[0].color0 = color;

    corners[1].position = {aq.x1, aq.y0};
    corners[1].texcoord0 = {aq.s1, aq.t0};
    corners[1].color0 = color;

    corners[2].position = {aq.x1, aq.y1};
    corners[2].texcoord0 = {aq.s1, aq.t1};
    corners[2].color0 = color;

    corners[3].position = {aq.x0, aq.y1};
    corners[3].texcoord0 = {aq.s0, aq.t1};
    corners[3].color0 = color;

    x = nextX;
    idxChar++;
  }
}

struct PageRenderer {
  GPU_Device gpu;
  GPU_Surface surface;

  Slice<Font> fonts;
};

struct NodeLayoutInfo {
  v2 position;
  v2 size;

  f32 parentX0, parentX1;

  f32 lineBoxY;
};

static f32 bottomOf(const NodeLayoutInfo &i) {
  return i.position.y + i.size.y;
}

static void initPositionSize(DOM_Tree &tree,
                             Slice<NodeLayoutInfo> &nodeLayoutInfo,
                             DOM_Node *self,
                             u32 idxSelf) {
  u32 idxParentNode = self->idxParent;
  NodeLayoutInfo &parentLayoutInfo = nodeLayoutInfo[idxParentNode];
  nodeLayoutInfo[idxSelf].size.x = parentLayoutInfo.size.x;
  nodeLayoutInfo[idxSelf].size.y = 0;
  nodeLayoutInfo[idxSelf].position.x = parentLayoutInfo.position.x;
  nodeLayoutInfo[idxSelf].position.y = bottomOf(parentLayoutInfo);
  // nodeLayoutInfo[idxSelf].position.y = parentLayoutInfo.lineBoxY;
}

struct TextStyleInfo {
  v4 color;

  FontWeight fontWeight;
  i32 fontSize;

  u32 idxFont;
};

static Slice<TextStyleInfo> computeTextStyles(Arena *arena,
                                              DOM_Tree &domTree,
                                              Slice<Font> availableFonts) {
  Slice<TextStyleInfo> ret;
  alloc(arena, domTree.textData.length, ret);

  struct StackEntry {
    u32 idxNode;

    TextStyleInfo textStyle;
  };

  ArenaTemp temp = getScratch(&arena, 1);
  Vector<StackEntry> stack =
      vectorWithInitialCapacity<StackEntry>(temp.arena, 256);

  TextStyleInfo defaultTextStyle = {{0, 0, 0, 1}, FontWeight::Normal, 16};
  *append(temp.arena, &stack) = {domTree.idxHtmlNode, defaultTextStyle};

  while (stack.length != 0) {
    StackEntry cur = stack[stack.length - 1];

    stack.length--;

    DOM_Node &node = domTree.nodes[cur.idxNode];
    if (node.kind == DOM_NodeKind::Text) {
      ret[node.idxText] = cur.textStyle;
    } else {
      DOM_ElementData &elemData = domTree.elementData[node.idxElement];

      TextStyleInfo ownStyle = cur.textStyle;

      if (equalCaseInsensitive(elemData.name, TAG_H1)) {
        ownStyle.fontSize = 2.0f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_H2)) {
        ownStyle.fontSize = 1.5f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_H3)) {
        ownStyle.fontSize = 1.17f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_H4)) {
        ownStyle.fontSize = 1.0f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_H5)) {
        ownStyle.fontSize = 0.83f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_H6)) {
        ownStyle.fontSize = 0.67f * EM_SIZE;
        ownStyle.fontWeight = FontWeight::Bold;
      } else if (equalCaseInsensitive(elemData.name, TAG_A)) {
        ownStyle.color = {22 / 255.0f, 0, 233 / 255.0f, 1};
        // TODO(danielm): text-underline
      }

      for (auto [idxChild, _] : node.children) {
        *append(temp.arena, &stack) = {idxChild, ownStyle};
      }
    }
  }

  releaseScratch(temp);

  // Select fonts based on style
  for (u32 i = 0; i < ret.length; i++) {
    ret[i].idxFont = findBestFont(availableFonts, ret[i].fontSize,
                                  FontStyle::Normal, ret[i].fontWeight);
  }

  return ret;
}

static void expandSizeOfAncestorBlocks(Slice<NodeLayoutInfo> nodeLayoutInfo,
                                       DOM_Node *node,
                                       u32 idxNode,
                                       DOM_Tree &domTree) {
  if (true) {
    f32 selfBottomY = bottomOf(nodeLayoutInfo[idxNode]);
    u32 idxAncestor = node->idxParent;
    while (idxAncestor != DOM_INVALID_INDEX) {
      NodeLayoutInfo &ancestorLayout = nodeLayoutInfo[idxAncestor];
      DOM_Node &ancestorNode = domTree.nodes[idxAncestor];
      DOM_ElementData &ancestorElemData =
          domTree.elementData[ancestorNode.idxElement];

      if (!DOM_isBlock(ancestorElemData)) {
        // break;
      }

      f32 prev = ancestorLayout.size.y;
      f32 selfBottomYInAncestorSpace = selfBottomY - ancestorLayout.position.y;
      ancestorLayout.size.y =
          max(ancestorLayout.size.y, selfBottomYInAncestorSpace);

      idxAncestor = ancestorNode.idxParent;
    }
  }
}

static Slice<NodeLayoutInfo> doLayout(Arena *arena,
                                      PageRenderer &renderer,
                                      DOM_Tree &domTree,
                                      v2 viewportSize,
                                      Slice<TextStyleInfo> textStyleInfo) {
  Slice<NodeLayoutInfo> nodeLayoutInfo;
  alloc(arena, domTree.nodes.length, nodeLayoutInfo);

  struct LayoutStackEntry {
    u32 idxNode;
    u32 idxParentNode;
    b32 finalizeSize;
  };

  ArenaTemp temp = getScratch(&arena, 1);
  Vector<LayoutStackEntry> queue =
      vectorWithInitialCapacity<LayoutStackEntry>(temp.arena, 256);
  *append(temp.arena, &queue) = {domTree.idxHtmlNode, DOM_INVALID_INDEX};

  f32 xCursor = 0;
  f32 lineBoxHeight = 0;
  b32 lastTextEndedWithWhitespace = false;

  while (queue.length > 0) {
    LayoutStackEntry &top = queue[queue.length - 1];

    auto [idxNode, idxParentNode, finalizeSize] = top;
    DOM_Node *node = &domTree.nodes[idxNode];

    queue.length--;
    DOM_Node *parentNode = nullptr;

    if (idxParentNode != DOM_INVALID_INDEX) {
      parentNode = &domTree.nodes[idxParentNode];
    }

    if (finalizeSize) {
      NodeLayoutInfo &selfLayout = nodeLayoutInfo[idxNode];
      for (u32 i = 0; i < node->children.length; i++) {
        u32 idxChild = node->children[i];
        f32 childHeight =
            bottomOf(nodeLayoutInfo[idxChild]) - selfLayout.position.y;
        selfLayout.size.y = max(selfLayout.size.y, childHeight);
      }
      expandSizeOfAncestorBlocks(nodeLayoutInfo, node, idxNode, domTree);
      if (idxParentNode != DOM_INVALID_INDEX) {
        NodeLayoutInfo &parentLayout = nodeLayoutInfo[idxParentNode];
        DOM_ElementData &parentElemData =
            domTree.elementData[parentNode->idxElement];
        if (node->kind == DOM_NodeKind::Element &&
            DOM_isBlock(domTree.elementData[node->idxElement])) {
          parentLayout.lineBoxY = bottomOf(nodeLayoutInfo[idxNode]);
        }
      }
      continue;
    }

    b32 isPrevElemBlock = false;
    b32 isPrevElemInline = false;
    if (node->idxPrev != DOM_INVALID_INDEX) {
      DOM_Node *prev = &domTree.nodes[node->idxPrev];
      if (prev->kind == DOM_NodeKind::Element) {
        isPrevElemBlock = DOM_isBlock(domTree.elementData[prev->idxElement]);
        isPrevElemInline = DOM_isInline(domTree.elementData[prev->idxElement]);
      } else {
        isPrevElemInline = true;
      }
    }

    b32 isBlock = false;

    if (node->kind == DOM_NodeKind::Text) {
      DCHECK(node->children.length == 0);
      DCHECK(idxNode != idxParentNode);

      b32 addWhitespace = !lastTextEndedWithWhitespace;
      lastTextEndedWithWhitespace = true;

      NodeLayoutInfo &parentLayoutInfo = nodeLayoutInfo[idxParentNode];
      if (parentLayoutInfo.size.x <= 0) {
        continue;
      }

      if (isPrevElemBlock) {
        xCursor = parentLayoutInfo.position.x;
        // parentLayoutInfo.size.y += nodeLayoutInfo[node->idxPrev].size.y;
      }

      f32 lineBoxY = parentLayoutInfo.lineBoxY;

      DOM_TextData &textData = domTree.textData[node->idxText];
      TextStyleInfo textStyle = textStyleInfo[node->idxText];
      Font *font = &renderer.fonts[textStyle.idxFont];

      if (textData.contents.length == 0) {
        continue;
      }

      b32 whitespaceOnly = true;
      for (u32 i = 0; i < textData.contents.length; i++) {
        if (!HTML_isWhitespace(textData.contents[i])) {
          whitespaceOnly = false;
          break;
        }
      }

      if (whitespaceOnly) {
        nodeLayoutInfo[idxNode].size = {0, 0};
        continue;
      }

      lastTextEndedWithWhitespace =
          HTML_isWhitespace(textData.contents[textData.contents.length - 1]);

      v2 size;
      v2 start = {xCursor, parentLayoutInfo.size.y};
      // Measure text size

      if (addWhitespace) {
        Font_measureText(font, SLICE_FROM_STRLIT(" "),
                         parentLayoutInfo.position.x,
                         parentLayoutInfo.position.x + parentLayoutInfo.size.x,
                         start, &size, &xCursor);
      }

      Font_measureText(font, textData.contents, parentLayoutInfo.position.x,
                       parentLayoutInfo.position.x + parentLayoutInfo.size.x,
                       start, &size, &xCursor);
      lineBoxHeight = max(lineBoxHeight, size.y + -font->size);

      nodeLayoutInfo[idxNode].size.x = 0;
      nodeLayoutInfo[idxNode].size.y = size.y + -font->size;
      DCHECK(nodeLayoutInfo[idxNode].size.y >= 0);
      nodeLayoutInfo[idxNode].position.x = start.x;
      nodeLayoutInfo[idxNode].position.y = lineBoxY;

      parentLayoutInfo.lineBoxY += size.y;

      nodeLayoutInfo[idxNode].parentX0 = parentLayoutInfo.position.x;
      nodeLayoutInfo[idxNode].parentX1 =
          parentLayoutInfo.position.x + parentLayoutInfo.size.x;
    } else {
      DCHECK(idxNode != idxParentNode);

      DOM_ElementData &elemData = domTree.elementData[node->idxElement];
      if (DOM_isInline(elemData)) {
        NodeLayoutInfo &parentLayoutInfo = nodeLayoutInfo[idxParentNode];
        nodeLayoutInfo[idxNode].position.x = 0;
        nodeLayoutInfo[idxNode].position.y = parentLayoutInfo.lineBoxY;
        nodeLayoutInfo[idxNode].size = {parentLayoutInfo.size.x, 0};
        nodeLayoutInfo[idxNode].lineBoxY = nodeLayoutInfo[idxNode].position.y;

        if (isPrevElemBlock) {
          xCursor = parentLayoutInfo.position.x;
        }
      } else if (equalCaseInsensitiveLit(elemData.name, "html")) {
        nodeLayoutInfo[domTree.idxHtmlNode].position = {0, 0};
        nodeLayoutInfo[domTree.idxHtmlNode].size = {viewportSize.x, 0};
      } else if (equalCaseInsensitiveLit(elemData.name, "title")) {
        nodeLayoutInfo[idxNode].position = {0, 0};
        nodeLayoutInfo[idxNode].size = {0, 0};
      } else {
        // Blocks; assume unknown elements are blocks as well
        nodeLayoutInfo[idxParentNode].size.y += lineBoxHeight;
        lineBoxHeight = 0;
        initPositionSize(domTree, nodeLayoutInfo, node, idxNode);
        // nodeLayoutInfo[idxParentNode].lineBoxY += lineBoxHeight;
        xCursor = nodeLayoutInfo[idxNode].position.x;
        nodeLayoutInfo[idxNode].lineBoxY = nodeLayoutInfo[idxNode].position.y;
        isBlock = true;
      }

      expandSizeOfAncestorBlocks(nodeLayoutInfo, node, idxNode, domTree);

      // Push children into the queue in reverse order so that they'll be
      // processed in order
      for (u32 i = node->children.length - 1; i < node->children.length; i--) {
        u32 idxChild = node->children[i];
        DCHECK(idxChild != DOM_INVALID_INDEX);
        DCHECK(idxChild < domTree.nodes.length);
        // b32 lastChild = i == 0;
        b32 finalizeSize = i == node->children.length - 1;
        if (finalizeSize) {
          *append(temp.arena, &queue) = {idxNode, idxParentNode, finalizeSize};
        }
        *append(temp.arena, &queue) = {idxChild, idxNode, false};
      }
    }

    DCHECK(nodeLayoutInfo[idxNode].size.x >= 0);
    DCHECK(nodeLayoutInfo[idxNode].size.y >= 0);
  }

  releaseScratch(temp);
  return nodeLayoutInfo;
}

struct InteractiveElement {
  v2 position;
  v2 size;
  Slice<u8> href;
};

static Slice<u8> joinPaths(Arena *arena, Slice<u8> left, Slice<u8> right) {
  ArenaTemp temp = getScratch(&arena, 1);
  // Copy the path part into a vector
  Vector<u8> cur = vectorWithInitialCapacity<u8>(temp.arena, left.length);
  memcpy(append(temp.arena, &cur, left.length), left.data, left.length);
  // There is a null-terminator
  cur.length -= 1;

  // Shrink the current path until the last slash
  while (cur.length > 0 && cur[cur.length - 1] != '/') {
    cur.length--;
  }

  Slice<u8> curRight = right;

  while (!empty(curRight)) {
    if (curRight.length >= 3 && curRight[0] == '.' && curRight[1] == '.' &&
        curRight[2] == '/') {
      if (cur.length > 0) {
        cur.length--;
        while (cur.length > 0 && cur[cur.length - 1] != '/') {
          cur.length--;
        }
      }

      shrinkFromLeftByCount(&curRight, 3);
    } else {
      *append(temp.arena, &cur) = curRight[0];
      shrinkFromLeft(&curRight);
    }
  }

  *append(temp.arena, &cur) = '\0';

  Slice<u8> ret = copyToSlice(arena, cur);
  releaseScratch(temp);
  return ret;
}

static Slice<u8> joinUrls(Arena *arena, Slice<u8> base, Slice<u8> rel) {
  ArenaTemp temp = getScratch(&arena, 1);

  Url right;
  if (Url_initFromString(&right, temp.arena, rel)) {
    // The right-hand side is a complete url
    releaseScratch(temp);
    return duplicate(arena, rel);
  }
  resetScratch(temp);

  Url left;
  Url_initFromString(&left, temp.arena, base);

  Slice<u8> combinedPath = joinPaths(temp.arena, left.path, rel);

  left.path = combinedPath;
  Slice<u8> ret = Url_format(arena, &left);

  releaseScratch(temp);
  return ret;
}

static Slice<InteractiveElement> getInteractiveElements(
    Arena *arena,
    Slice<u8> &location,
    Slice<NodeLayoutInfo> layoutInfo,
    DOM_Tree &domTree) {
  ArenaTemp temp = getScratch(&arena, 1);
  Vector<InteractiveElement> elems;

  for (u32 i = 0; i < domTree.elementData.length; i++) {
    DOM_ElementData &elemData = domTree.elementData[i];
    if (equalCaseInsensitive(elemData.name, TAG_A)) {
      InteractiveElement *ie = append(temp.arena, &elems);

      ie->position = layoutInfo[elemData.idxNode].position;
      ie->size = layoutInfo[elemData.idxNode].size;

      b32 foundHref = false;

      for (auto [attr, _] : elemData.attributes) {
        if (equalCaseInsensitiveLit(attr.name, "href")) {
          ie->href = joinUrls(arena, location, attr.value);
          foundHref = true;
          break;
        }
      }

      if (!foundHref) {
        ie->href = {nullptr, 0};
      }
    }
  }

  Slice<InteractiveElement> ret = copyToSlice(arena, elems);
  releaseScratch(temp);
  return ret;
}

static b32 intersects(Slice<InteractiveElement> elems, v2 pos, u32 &outIndex) {
  for (auto [elem, idxElem] : elems) {
    if (pos.x < elem.position.x || pos.y < elem.position.y) {
      continue;
    }

    if (pos.x > elem.position.x + elem.size.x ||
        pos.y > elem.position.y + elem.size.y) {
      continue;
    }

    outIndex = idxElem;
    return true;
  }
  return false;
}

enum class PageStatus {
  Invalid,
  Exit,
  NavigateToUrl,
  NavigateBack,
};

static PageStatus showPage(Arena *arena,
                           PageRenderer &renderer,
                           Slice<u8> urlIn,
                           Slice<u8> &nextUrl) {
  char bufError[1024];

  HTTP_Response response = {};
  if (!HTTP_fetch(arena, urlIn, response)) {
    return PageStatus::Exit;
  }

  Slice<u8> responseBody = response.body;
  if (response.code != 200) {
    const char *msg = "Error";
    switch (response.code) {
      case 301:
      case 307:
      case 308:
        msg =
            "The site has redirected us, but redirects are not implemented yet";
        break;
      case 400:
        msg = "400 Bad request (sorry :c)";
        break;
      case 404:
        msg = "404 Not found";
        break;
    }
    snprintf(bufError, 1024,
             "<html><head></head><body><h2>%s</h2><p>Failed to load "
             "'%.*s'</p></body></html>",
             msg, FMT_SLICE(urlIn));
    responseBody = {(u8 *)bufError, (u32)strlen(bufError)};
  }

  // log_info("Response body:\n%.*s", FMT_SLICE(responseBody));

  Slice<HTMLToken> tokens;
  log_info("Tokenizing");
  if (!HTML_tokenize(arena, responseBody, tokens)) {
    log_error("Tokenizer failed");
  }
  // log_info("Printing");
  // HTML_print(tokens);

  log_info("Building DOM tree");
  DOM_Tree domTree = {};
  DOM_Tree_init(&domTree, arena, tokens);
  // log_info("Printing DOM tree:");
  // DOM_Tree_print(&domTree);

  i32 viewportWidth, viewportHeight;
  Surface_getSize(renderer.surface, &viewportWidth, &viewportHeight);
  if (viewportWidth == 0) {
    viewportWidth = 1280;
  }
  if (viewportHeight == 0) {
    viewportHeight = 720;
  }

  Slice<u8> siteTitle;

  // Look for the first title element, check if it only has text inside and set
  // the siteTitle to that text
  for (auto [elem, _] : domTree.elementData) {
    if (equalCaseInsensitive(elem.name, TAG_TITLE)) {
      DOM_Node &node = domTree.nodes[elem.idxNode];
      if (node.children.length == 1) {
        DOM_Node &child = domTree.nodes[node.children[0]];
        if (child.kind == DOM_NodeKind::Text) {
          siteTitle = domTree.textData[node.idxText].contents;
        }
      }
      break;
    }
  }

  f32 documentYOffset = 0;

  PageStatus pageStatus = PageStatus::Invalid;
  while (pageStatus == PageStatus::Invalid) {
    ArenaTemp layout = {arena, *arena};
    Slice<TextStyleInfo> textStyleInfo =
        computeTextStyles(layout.arena, domTree, renderer.fonts);
    Slice<NodeLayoutInfo> nodeLayoutInfo =
        doLayout(layout.arena, renderer, domTree,
                 v2(viewportWidth, viewportHeight), textStyleInfo);
    Slice<InteractiveElement> interactiveElements =
        getInteractiveElements(layout.arena, urlIn, nodeLayoutInfo, domTree);

    struct TextBatch {
      GPU_Image fontAtlas;
      GPU_Mesh mesh;
    };

    const u32 numFonts = renderer.fonts.length;
    Slice<TextBatch> textBatches;
    alloc(layout.arena, numFonts, textBatches);

    // Generate and create GPU meshes; bin quads based on the font that
    // they use
    {
      ArenaTemp temp = getScratch(&layout.arena, 1);
      Slice<Vector<GPU_Vertex>> verticesPerFont;
      Slice<Vector<u32>> indicesPerFont;

      alloc(temp.arena, renderer.fonts.length, verticesPerFont);
      alloc(temp.arena, renderer.fonts.length, indicesPerFont);

      for (auto [text, idxText] : domTree.textData) {
        NodeLayoutInfo &layoutInfo = nodeLayoutInfo[text.idxNode];
        v2 start = layoutInfo.position;
        f32 x0 = layoutInfo.parentX0;
        f32 x1 = layoutInfo.parentX1;
        if (x1 - x0 <= 0) {
          continue;
        }
        TextStyleInfo &style = textStyleInfo[idxText];
        Font *font = &renderer.fonts[style.idxFont];
        Vector<GPU_Vertex> &vertices = verticesPerFont[style.idxFont];
        Vector<u32> &indices = indicesPerFont[style.idxFont];
        Font_drawText(font, temp.arena, vertices, indices, text.contents, x0,
                      x1, start, style.color);
      }

      Slice<GPU_MeshDesc> meshDesc;
      alloc(temp.arena, numFonts, meshDesc);
      for (u32 i = 0; i < numFonts; i++) {
        if (verticesPerFont[i].length == 0 || indicesPerFont[i].length == 0) {
          continue;
        }
        meshDesc[i].vertexData = copyToSlice(arena, verticesPerFont[i]);
        meshDesc[i].indices = copyToSlice(arena, indicesPerFont[i]);
        GPU_Mesh mesh;
        GPU_createMesh(renderer.gpu, layout.arena, &meshDesc[i],
                       &textBatches[i].mesh);
        textBatches[i].fontAtlas = renderer.fonts[i].image;
      }

      releaseScratch(temp);
    }

    while (!Surface_wasClosed(renderer.surface)) {
      ArenaTemp frame = getScratch(&layout.arena, 1);

      f32 deltaTime;
      GPU_beginFrame(renderer.gpu, renderer.surface, &deltaTime);
      Slice<GPU_Event> events =
          Surface_getEvents(renderer.gpu, frame.arena, renderer.surface);

      for (auto [ev, _] : events) {
        switch (ev.kind) {
          case GET_MouseWheel: {
            documentYOffset =
                max(0.0f, documentYOffset - ev.mouseWheel.y * 16.0f);
            f32 maxY = viewportHeight;
            f32 htmlElemHeight = nodeLayoutInfo[domTree.idxHtmlNode].size.y;
            if (htmlElemHeight < viewportHeight) {
              maxY = 0;
            } else {
              maxY = htmlElemHeight - viewportHeight;
            }
            documentYOffset = min(documentYOffset, maxY);
            break;
          }
          case GET_MouseUp: {
            v2 cursorPosPageSpace;
            cursorPosPageSpace.x = ev.mouseUp.x;
            cursorPosPageSpace.y = ev.mouseUp.y + documentYOffset;
            u32 idxClickedElem;
            if (intersects(interactiveElements, cursorPosPageSpace,
                           idxClickedElem)) {
              nextUrl = interactiveElements[idxClickedElem].href;
              pageStatus = PageStatus::NavigateToUrl;
            }
            break;
          }
          case GET_KeyDown: {
            break;
          }
          case GET_KeyUp: {
            if (ev.key.vk == K_Left && ev.key.altIsHeld) {
              pageStatus = PageStatus::NavigateBack;
            }
            break;
          }
          default:
            (void)ev;
            break;
        }
      }

      Vector<GPU_RenderCmd> renderCmds = {};

      GPU_RenderCmd *setView = append(frame.arena, &renderCmds);
      setView->kind = GPU_CmdKind::SetView;
      setView->setView.projection = mat4x4_id();

      f32 l = 0;
      f32 r = viewportWidth;
      f32 t = documentYOffset;
      f32 b = viewportHeight + documentYOffset;
      setView->setView.projection.c0.x = 2.0f / (r - l);
      setView->setView.projection.c1.y = 2.0f / (t - b);
      setView->setView.projection.c2.z = 1.0f;
      setView->setView.projection.c3.x = -(r + l) / (r - l);
      setView->setView.projection.c3.y = -(t + b) / (t - b);
      setView->setView.projection.c3.z = 0;

      for (auto [textBatch, _] : textBatches) {
        if (!textBatch.mesh) {
          continue;
        }
        GPU_RenderCmd *bindMesh = append(frame.arena, &renderCmds);
        bindMesh->kind = GPU_CmdKind::BindMesh;
        bindMesh->bindMesh.mesh = textBatch.mesh;

        GPU_RenderCmd *bindImage = append(frame.arena, &renderCmds);
        bindImage->kind = GPU_CmdKind::BindImage;
        bindImage->bindImage.image = textBatch.fontAtlas;
        bindImage->bindImage.colorSpace = GCS_Linear;

        GPU_RenderCmd *draw = append(frame.arena, &renderCmds);
        draw->kind = GPU_CmdKind::RenderInstance;
        draw->renderInstance = {};
      }

      GPU_submit(renderer.gpu, renderer.surface,
                 copyToSlice(frame.arena, renderCmds));
      GPU_present(renderer.gpu, renderer.surface);
      releaseScratch(frame);

      i32 w, h;
      Surface_getSize(renderer.surface, &w, &h);
      if (viewportWidth != w || viewportHeight != h) {
        viewportWidth = w;
        viewportHeight = h;

        break;
      }

      if (pageStatus != PageStatus::Invalid) {
        break;
      }
    }

    // Cleanup meshes
    for (auto [textBatch, _] : textBatches) {
      if (!textBatch.mesh) {
        continue;
      }

      GPU_destroyMesh(renderer.gpu, textBatch.mesh);
    }

    resetScratch(layout);

    if (Surface_wasClosed(renderer.surface)) {
      return PageStatus::Exit;
    }
  }

  return pageStatus;
}

static Slice<u8> DEFAULT_URL =
    SLICE_FROM_STRLIT("http://info.cern.ch/hypertext/WWW/TheProject.html");

int AppEntry(Slice<Slice<u8>> argv) {
  Slice<u8> initialUrl = DEFAULT_URL;

  log_info("argv len: %u\n", argv.length);
  if (argv.length >= 2) {
    initialUrl = argv[1];
  }

  log_info("Initial URL: %.*s", FMT_SLICE(initialUrl));

  setupArenas();

  GPU_Device gpu;
  if (!GPU_create(&arenaPerm, &gpu)) {
    log_error("GPU_create failed");
    return false;
  }

  GPU_SurfaceDesc surfDesc = {};
  surfDesc.kind = GSK_NativeWindow;
  GPU_Surface surf;
  if (!GPU_createSurface(gpu, &arenaPerm, &surfDesc, &surf)) {
    log_error("GPU_createSurface failed");
    GPU_destroy(gpu);
    return false;
  }

  Font fonts[7];

  Font_init(&fonts[0], &arenaPerm, gpu, font_regular, font_regular_len, EM_SIZE,
            FontStyle::Normal, FontWeight::Normal);
  Font_init(&fonts[1], &arenaPerm, gpu, font_bold, font_bold_len,
            2.0f * EM_SIZE, FontStyle::Normal, FontWeight::Bold);
  Font_init(&fonts[2], &arenaPerm, gpu, font_bold, font_bold_len,
            1.5f * EM_SIZE, FontStyle::Normal, FontWeight::Bold);
  Font_init(&fonts[3], &arenaPerm, gpu, font_bold, font_bold_len,
            1.17f * EM_SIZE, FontStyle::Normal, FontWeight::Bold);
  Font_init(&fonts[4], &arenaPerm, gpu, font_bold, font_bold_len, EM_SIZE,
            FontStyle::Normal, FontWeight::Bold);
  Font_init(&fonts[5], &arenaPerm, gpu, font_bold, font_bold_len,
            0.83f * EM_SIZE, FontStyle::Normal, FontWeight::Bold);
  Font_init(&fonts[6], &arenaPerm, gpu, font_bold, font_bold_len,
            0.67f * EM_SIZE, FontStyle::Normal, FontWeight::Bold);

  Arena historyArena;
  historyArena.beg = alloc<u8>(&arenaPerm, 64 * 1024);
  historyArena.end = historyArena.beg + 64 * 1024;
  Slice<u8> historyArr[32];
  // This vector is backed by the stack
  Vector<Slice<u8>> history = {historyArr, 0, 32};

  PageRenderer pageRenderer = {gpu, surf, {fonts, 7}};

  ArenaTemp temp = {&arenaTemp, arenaTemp};
  Slice<u8> nextLocation = duplicate(temp.arena, initialUrl);
  while (true) {
    printf("======================================\n");
    ArenaTemp pageArena = {&arenaPerm, arenaPerm};
    Slice<u8> urlToLoad = duplicate(pageArena.arena, nextLocation);
    resetScratch(temp);
    log_info("Loading %.*s", FMT_SLICE(urlToLoad));
    PageStatus status =
        showPage(pageArena.arena, pageRenderer, urlToLoad, nextLocation);
    if (status == PageStatus::NavigateToUrl) {
      nextLocation = duplicate(temp.arena, nextLocation);
      log_info("Navigating to %.*s", FMT_SLICE(nextLocation));

      if (history.length < 32) {
        history.data[history.length] = duplicate(&historyArena, urlToLoad);
        history.length++;
      } else {
        log_warn("History is full!");
      }
    } else if (status == PageStatus::NavigateBack) {
      if (history.length != 0) {
        Slice<u8> prevUrl = history[history.length - 1];
        nextLocation = duplicate(temp.arena, prevUrl);
        history.length--;
        log_info("Going back to %.*s", FMT_SLICE(nextLocation));
        // historyArena acts like a stack, so the end of it must be allocated
        // for this entry
        historyArena.end += prevUrl.length;
      } else {
        log_warn("History is empty! Reloading current page...");
        // Reload the current page
        nextLocation = duplicate(temp.arena, urlToLoad);
      }
    } else {
      break;
    }

    releaseScratch(pageArena);
  }

  Surface_destroy(surf);
  GPU_destroy(gpu);

  return 0;
}

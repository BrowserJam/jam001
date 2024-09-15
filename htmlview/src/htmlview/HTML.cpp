#include "htmlview/HTML.hpp"
#include "log/log.h"
#include "std/Arena.h"
#include "std/Slice.hpp"
#include "std/Utils.hpp"
#include "std/Vector.hpp"

static b32 isAlphanumeric(u8 ch) {
  if ('a' <= ch && ch <= 'z') {
    return true;
  }
  if ('A' <= ch && ch <= 'Z') {
    return true;
  }
  if ('0' <= ch && ch <= '9') {
    return true;
  }

  return false;
}

b32 HTML_isWhitespace(u8 ch) {
  return ch == 0x09 || ch == 0x0A || ch == 0x0C || ch == 0x0D || ch == 0x20;
}

static b32 eatWhitespace(Slice<u8> &cur) {
  while (!empty(cur) && HTML_isWhitespace(cur[0])) {
    shrinkFromLeft(&cur);
  }

  return !empty(cur);
}

static b32 eatUntilEscapableDelimiter(u8 ch, Slice<u8> &cur, Slice<u8> &value) {
  // Single quoted
  shrinkFromLeft(&cur);
  if (empty(cur)) {
    return false;
  }

  value = cur;
  value.length = 0;

  b32 escaped = false;
  while (!empty(cur) && (cur[0] != ch || escaped)) {
    escaped = false;

    if (cur[0] == '\\') {
      escaped = true;
    }

    value.length++;
    shrinkFromLeft(&cur);
  }

  if (empty(cur) || cur[0] != ch) {
    return false;
  }

  shrinkFromLeft(&cur);  // eat ch

  return true;
}

static b32 HTML_eatAttribute(Arena *arena,
                             Slice<u8> &cur,
                             Vector<HTMLAttribute> &attributes) {
  DCHECK(!empty(cur));

  Slice<u8> name = cur;
  name.length = 0;

  while (!empty(cur) && isAlphanumeric(cur[0])) {
    name.length++;
    shrinkFromLeft(&cur);
  }

  if (!eatWhitespace(cur)) {
    return false;
  }

  if (cur[0] == '=') {
    shrinkFromLeft(&cur);
  } else if (isAlphanumeric(cur[0])) {
    // Empty attribute
    HTMLAttribute *attr = append(arena, &attributes);
    attr->name = name;
    attr->value = {};
    return true;
  }

  if (!eatWhitespace(cur)) {
    return false;
  }

  // FIXME(danielm): not all attribute value restriction violations are detected
  // here
  if (cur[0] == '\'') {
    // Single quoted
    Slice<u8> value;
    if (!eatUntilEscapableDelimiter('\'', cur, value)) {
      return false;
    }

    HTMLAttribute *attr = append(arena, &attributes);
    attr->name = name;
    attr->value = value;
  } else if (cur[0] == '"') {
    // Double quoted
    Slice<u8> value;
    if (!eatUntilEscapableDelimiter('\"', cur, value)) {
      return false;
    }

    HTMLAttribute *attr = append(arena, &attributes);
    attr->name = name;
    attr->value = value;
  } else {
    // Unquoted
    Slice<u8> value = cur;
    value.length = 0;
    while (
        !empty(cur) && !HTML_isWhitespace(cur[0]) && cur[0] != '>' &&
        // If there is a slash in the value, it must not be followed by a `>`
        (cur.length > 1 && cur[0] == '/' && cur[1] != '>' || cur[0] != '/')) {
      value.length++;
      shrinkFromLeft(&cur);
    }

    if (empty(cur)) {
      return false;
    }

    HTMLAttribute *attr = append(arena, &attributes);
    attr->name = name;
    attr->value = value;
  }

  return true;
}

static b32 HTML_tokenizeTag(Arena *arena,
                            Slice<u8> &cur,
                            Vector<HTMLToken> &tokens) {
  DCHECK(!empty(cur) && cur[0] == '<');

  if (cur.length == 1) {
    // End of the document
    HTMLToken *token = append(arena, &tokens);
    token->kind = HTMLTokenKind::Text;
    token->text.contents = cur;
    return true;
  }

  shrinkFromLeft(&cur);

  DCHECK(!empty(cur));

  if (cur[0] == '/') {
    shrinkFromLeft(&cur);
    Slice<u8> name = cur;
    name.length = 0;

    while (!empty(cur) && isAlphanumeric(cur[0])) {
      name.length++;
      shrinkFromLeft(&cur);
    }

    if (!eatWhitespace(cur)) {
      return false;
    }
    DCHECK(!empty(cur));

    if (cur[0] != '>') {
      return false;
    }

    shrinkFromLeft(&cur);  // eat '>'

    HTMLToken *token = append(arena, &tokens);
    token->kind = HTMLTokenKind::CloseTag;
    token->closeTag.name = name;
  } else if (cur[0] == '!') {
    if (cur.length > 8 && memcmp(cur.data, "!DOCTYPE", 8) == 0) {
      while (!empty(cur) && cur[0] != '>') {
        shrinkFromLeft(&cur);
      }
      shrinkFromLeft(&cur);
    } else {
      return false;
    }
  } else if (isAlphanumeric(cur[0])) {
    Slice<u8> name = cur;
    name.length = 1;
    shrinkFromLeft(&cur);
    while (!empty(cur) && isAlphanumeric(cur[0])) {
      name.length++;
      shrinkFromLeft(&cur);
    }

    if (empty(cur)) {
      return false;
    }

    ArenaTemp temp = getScratch(&arena, 1);
    Vector<HTMLAttribute> attributes;
    b32 isSelfClosing = false;
    while (!empty(cur)) {
      if (!eatWhitespace(cur)) {
        return false;
      }
      DCHECK(!empty(cur));

      if (cur[0] == '>') {
        shrinkFromLeft(&cur);
        break;
      } else if (cur[0] == '/') {
        isSelfClosing = true;
        shrinkFromLeft(&cur);
        if (empty(cur) || cur[0] != '>') {
          return false;
        }
        shrinkFromLeft(&cur);
        break;
      } else {
        if (!HTML_eatAttribute(arena, cur, attributes)) {
          return false;
        }
      }
    }

    HTMLToken *token = append(arena, &tokens);
    token->kind = HTMLTokenKind::OpenTag;
    token->openTag.name = name;
    token->openTag.isSelfClosing = isSelfClosing;
    token->openTag.attributes = copyToSlice(arena, attributes);

    return true;
  } else {
    return false;
  }

  return true;
}

static b32 HTML_tokenizeText(Arena *arena,
                             Slice<u8> &cur,
                             Vector<HTMLToken> &tokens) {
  Slice<u8> contents = cur;
  contents.length = 0;
  const u32 origLength = cur.length;
  b32 stop = false;
  while (!empty(cur) && !stop) {
    switch (cur[0]) {
      case '<': {
        if (cur.length > 1) {
          if (cur[1] == '/' || isAlphanumeric(cur[1])) {
            // This is the beginning of a tag
            stop = true;
            break;
          }
        }
        contents.length++;
        shrinkFromLeft(&cur);
        break;
      }
      default: {
        contents.length++;
        shrinkFromLeft(&cur);
        break;
      }
    }
  }

  DCHECK(contents.length <= origLength);

  HTMLToken *token = append(arena, &tokens);
  token->kind = HTMLTokenKind::Text;
  token->text.contents = contents;

  return true;
}

b32 HTML_tokenize(Arena *arena, Slice<u8> source, Slice<HTMLToken> &out) {
  Vector<HTMLToken> tokens;

  ArenaTemp temp = getScratch(&arena, 1);

  Slice<u8> cur = source;
  while (!empty(cur)) {
    switch (cur[0]) {
      case '<':
        // Element
        if (!HTML_tokenizeTag(arena, cur, tokens)) {
          releaseScratch(temp);
          return false;
        }
        break;
      case ' ':
      case '\t':
        // Whitespace
        shrinkFromLeft(&cur);
        break;
      default:
        // Text
        if (!HTML_tokenizeText(temp.arena, cur, tokens)) {
          releaseScratch(temp);
          return false;
        }
        break;
    }
  }

  out = copyToSlice(arena, tokens);
  releaseScratch(temp);
  return true;
}

b32 HTML_print(Slice<HTMLToken> tokens) {
  for (u32 i = 0; i < tokens.length; i++) {
    HTMLToken &token = tokens[i];
    switch (token.kind) {
      case HTMLTokenKind::OpenTag:
        printf("<%.*s ", FMT_SLICE(token.openTag.name));
        for (u32 j = 0; j < token.openTag.attributes.length; j++) {
          HTMLAttribute &attr = token.openTag.attributes[j];
          printf("%.*s=%.*s ", FMT_SLICE(attr.name), FMT_SLICE(attr.value));
        }

        if (token.openTag.isSelfClosing) {
          printf("/>");
        } else {
          printf(">");
        }
        break;
      case HTMLTokenKind::CloseTag:
        printf("</ %.*s>", FMT_SLICE(token.closeTag.name));
        break;
      case HTMLTokenKind::Text:
        printf("%.*s", FMT_SLICE(token.text.contents));
        break;
    }
  }
  return false;
}

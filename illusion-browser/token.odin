package main

import "core:fmt"
import "core:unicode"
import "core:strings"
import "core:unicode/utf8"

TokenKind :: enum {
    StartTag,
    EndTag,
    SelfClosingTag,
    Text,
    Comment,
    Doctype,
    Unknown,
    EOF,
}

Token :: struct {
    kind: TokenKind,
    text: string,
    attr: []ElementAttribute,
}

Tokenizer :: struct {
    src: string,

    ch: rune,
    read_offset: int,
    offset: int,
}

@(private = "file")
skip_whitespace :: proc(t: ^Tokenizer) -> bool {
    skipped := false

    for {
        switch t.ch {
        case ' ', '\t', '\r', '\n':
            advance_rune(t)
            skipped = true
        case:
            return skipped
        }
    }

    return skipped
}

@(private = "file")
read_comment :: proc(t: ^Tokenizer) -> string {
    start := t.offset

    for {
        advance_rune(t)

        if t.ch == utf8.RUNE_EOF {
            return ""
        }

        //fmt.println(t.offset)
        //fmt.println(t.ch)
        if t.src[t.offset - 1:][:2] == "--" {
            if peek(t) == '>' { 
                break
            } else {
                // TODO: "--" sequence was found but it's not a comment end
                // Return an error.
                return ""
            }
        }
    }

    return string(t.src[start: t.offset - 1])
}

@(private = "file")
read_doctype :: proc(t: ^Tokenizer) -> string {
    start := t.offset

    for {
        advance_rune(t)

        if t.ch == utf8.RUNE_EOF {
            return ""
        } else if t.ch == '>' {
            break
        }
    }

    return string(t.src[start: t.read_offset - 1])
}

@(private = "file")
read_tag :: proc(t: ^Tokenizer, save_attribute: bool) -> (TokenKind, string, []ElementAttribute) {
    read_tag_name :: proc(t: ^Tokenizer) -> (TokenKind, string) {
        start := t.offset

        loop: for {
            advance_rune(t)

            switch t.ch {
            case ' ', '\n', '\r', '\t', '\f', '/':
                break loop
            case '>':
                str := string(t.src[start:t.read_offset - 1])
                t.read_offset -= 1
                return .StartTag, str
            }
        }

        return .StartTag, string(t.src[start:t.read_offset - 1])
    }

    read_attr_key :: proc(t: ^Tokenizer) -> string {
        start := t.offset

        // BUG: forward slashes are considered part of the attribute key

        for {
            advance_rune(t)

            switch t.ch {
            case '=':
                if start+1 == t.read_offset {
                    // WHATWG 13.2.5.32, if we see an equals sign before the attribute name
                    // begins, we treat it as a character in the attribute name and continue.
                    continue
                }
                fallthrough
            case ' ', '\n', '\r', '\t', '\f', '/', '>':
                t.read_offset -= 1
                t.offset -= 1
                return string(t.src[start:t.read_offset])
            }
        }
    }

    read_attr_value :: proc(t: ^Tokenizer) -> string {
        skip_whitespace(t)

        //if t.ch == '>' {
        //    t.read_offset -= 1
        //    t.offset -= 1
        //    return ""
        //}

        advance_rune(t)

        // Attribute with only a key
        if t.ch == '/' {
            return ""
        }
        if t.ch != '=' {
            t.read_offset -= 1
            t.offset -= 1
            return ""
        }

        skip_whitespace(t)
        advance_rune(t)

        quote := t.ch

        switch quote {
        case '>':
            t.read_offset -= 1
            return ""
        case '"', '\'': // Quoted attribute value
            start := t.offset + 1

            for {
                advance_rune(t)

                if t.ch == quote {
                    break
                }
            }

            defer {
                if peek(t) == ' ' || peek(t) == '/' {
                    advance_rune(t)
                    skip_whitespace(t)
                }
            }

            return string(t.src[start:t.read_offset-1])
        case: // Unquoted attribute value
            start := t.offset

            loop: for {
                advance_rune(t)

                switch t.ch {
                case ' ', '\n', '\r', '\t', '\f':
                    break loop
                case '>':
                    t.read_offset -= 1
                    t.offset -= 1 
                    return string(t.src[start:t.read_offset])
                }
            }

            return string(t.src[start:t.read_offset - 1])
        }
    }

    kind, tag_name := read_tag_name(t)
    before_skipping := t.offset
    // HACK: quick hack to make sure we only skip go back one byte when there's more than one whitespace at the end of the tag
    if skip_whitespace(t) && t.offset > before_skipping + 1 {
        t.read_offset -= 1
    }

    attrs := make([dynamic]ElementAttribute)

    for {
        advance_rune(t)

        // End of attributes or no attributes
        if t.ch == '>' {
            break
        }
        t.read_offset -= 1
        t.offset -= 1

        start := t.offset
        key := read_attr_key(t)
        end := t.read_offset
        val := read_attr_value(t)

        if save_attribute && start != end {
            append(&attrs, ElementAttribute{key, val})
        }

        // HACK: on top of hack on top of hack on top of hack
        if skip_whitespace(t) && peek(t, -1) == '>' {
            t.read_offset -= 1
        }
    }

    // Look at the char before the > to see if we have a self closing tag
    if t.src[t.read_offset - 2] == '/' {
        kind = .SelfClosingTag
    }

    return kind, tag_name, attrs[:]
}

@(private = "file")
advance_rune :: proc(t: ^Tokenizer) {
    if t.read_offset < len(t.src) {
        t.offset = t.read_offset
        t.ch = rune(t.src[t.read_offset])
        t.read_offset += 1
    } else {
        t.offset = len(t.src)
        t.ch = utf8.RUNE_EOF
    }
}

@(private = "file")
peek :: proc(t: ^Tokenizer, offset: int = 0) -> rune {
    if t.read_offset + offset < len(t.src) {
        #no_bounds_check return rune(t.src[t.read_offset+offset])
    }

    return 0
}

tokenizer_init :: proc(t: ^Tokenizer, src: string) {
    t.ch = ' '
    t.src = src
    t.read_offset = 0
    t.offset = 0
}

tokenizer_next :: proc(t: ^Tokenizer) -> Token {
    skip_whitespace(t)

    kind: TokenKind
    text: string
    attr: []ElementAttribute

    switch t.ch {
    case:
        kind = .Text
        start := t.offset

        for {
            advance_rune(t)

            if t.ch == '<' {
                break
            }
        }

        // HACK: just replace_all the newlines :)))
        text, _ = strings.replace_all(string(t.src[start:t.read_offset - 1]), "\n", " ")
    case utf8.RUNE_EOF:
        kind = .EOF
    case '<':
        advance_rune(t)
        switch t.ch {
        case '!':
            if peek(t) == '-' && peek(t, 1) == '-' {
                kind = .Comment
            } else {
                kind = .Doctype
            }
        case '/':
            kind = .EndTag
        case 'a'..='z', 'A'..='Z':
            kind = .StartTag
        case:
            kind = .Unknown
            // NOTE: bad
            text = strings.clone_from_bytes({byte(t.ch)})
        }

        #partial switch kind {
            case .StartTag:
                kind, text, attr = read_tag(t, true)
                advance_rune(t)
            case .EndTag:
                // Skip the /
                advance_rune(t)
                _, text, _ = read_tag(t, false)
                advance_rune(t)
            case .Comment:
                // consume the dashes
                t.read_offset += 3
                t.offset += 3
                text = read_comment(t)
                advance_rune(t)
                advance_rune(t)
            case .Doctype:
                // consume the exclamation point
                t.read_offset += 1
                t.offset += 1
                text = read_doctype(t)
                advance_rune(t)
        }
    }

    return Token{kind, text, attr}
}

#include "SDL_error.h"
#include "SDL_log.h"
#include "SDL_rect.h"
#include "SDL_render.h"
#include "SDL_surface.h"
#include "sys/types.h"
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOG__INT(fmt, ...) printf("\x1b[90m[INFO] \x1b[0m" fmt "%s", __VA_ARGS__);
#define LOG(...) LOG__INT(__VA_ARGS__, "\x1b[0m\n")
#define ERROR__INT(fmt, ...) fprintf(stderr, "\x1b[90m[ERROR] \x1b[31m" fmt "%s", __VA_ARGS__);
#define ERROR(...) ERROR__INT(__VA_ARGS__, "\x1b[0m\n")
#define DEBUG__INT(fmt, ...) fprintf(stderr, "\x1b[90m[DEBUG] \x1b[90m" fmt "%s", __VA_ARGS__);
#define DEBUG(...) DEBUG__INT(__VA_ARGS__, "\x1b[0m\n")

size_t get_file_size(FILE *file) {
    size_t size;

    fseek(file, 0, SEEK_END);
    size = ftell(file);
    fseek(file, 0, SEEK_SET);

    return size;
}

int is_ascii(uint8_t byte) { return byte >= 0 && byte < 128; }

int is_text(uint8_t byte) { return byte >= 32 && byte < 127; }

int is_text_not_empty(uint8_t byte) { return byte > 32 && byte < 127; }

typedef enum { STATE_TEXT, STATE_TAG, STATE_COMMENT } TokenizerState;

typedef enum { TOK_TYPE_TEXT, TOK_TYPE_OPENING_TAG, TOK_TYPE_CLOSING_TAG } TokenType;

const char *token_type_char_map[3] = {
    [TOK_TYPE_TEXT] = "TextNode", [TOK_TYPE_OPENING_TAG] = "OpenTagNode", [TOK_TYPE_CLOSING_TAG] = "CloseTagNode"};

typedef struct Span {
    uint8_t *data;
    size_t len;
} Span;

typedef struct Attribute {
    Span key;
    Span value;
} Attribute;

typedef struct LinkedListNode {
    void *element;
    struct LinkedListNode *next;
} LinkedListNode;

typedef struct LinkedList {
    LinkedListNode *head;
    size_t len;
} LinkedList;

struct Token;
typedef struct Token {
    TokenType type;
    Span data;
} Token;

typedef enum { NODE_TYPE_TEXT, NODE_TYPE_ELEMENT } NodeType;
const char *node_type_char_map[3] = {
    [NODE_TYPE_TEXT] = "Text",
    [NODE_TYPE_ELEMENT] = "Element",
};

typedef enum {
    ELEMENT_ROOT,
    ELEMENT_CUSTOM,
    ELEMENT_HEADER,
    ELEMENT_BODY,
    ELEMENT_TITLE,
    ELEMENT_H1,
    ELEMENT_H2,
    ELEMENT_H3,
    ELEMENT_H4,
    ELEMENT_H5,
    ELEMENT_H6,
    ELEMENT_P,
    ELEMENT_DL,
    ELEMENT_DT,
    ELEMENT_DD,
    ELEMENT_LI,
    ELEMENT_UL,
    ELEMENT_ADDRESS,
    ELEMENT_XMP,
    ELEMENT_PLAINTEXT
} ElementType;

// Some tags allow omitting the end tags. According to mdn <p> is one of them. There are also others such as <dd> and
// <dt> Technically h1-h6 don't allow omissing tags, but on this test page
// (https://info.cern.ch/hypertext/WWW/Status.html) there are multiple examples of <h2>s closed by </h3>s. Testing on
// modern browsers it seems that nesting <h1>s doesn't work (example: <h1>test<h1>hello</h1><h1> is parsed as
// <h1>test</h1><h1>hello</h1>), so this solution should be fine.

int tag_omission_table[32][32] = {
    [ELEMENT_ROOT] = {0},
    [ELEMENT_CUSTOM] = {0},
    [ELEMENT_HEADER] = {0},
    [ELEMENT_BODY] = {0},
    [ELEMENT_TITLE] = {0},
    [ELEMENT_H1] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_H2] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_H3] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_H4] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_H5] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_H6] = {ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6},
    [ELEMENT_P] = {ELEMENT_ADDRESS, ELEMENT_H1, ELEMENT_H2, ELEMENT_H3, ELEMENT_H4, ELEMENT_H5, ELEMENT_H6,
                   ELEMENT_HEADER, ELEMENT_UL, ELEMENT_DL},
    [ELEMENT_DL] = {0},
    [ELEMENT_DT] = {ELEMENT_DT, ELEMENT_DD, ELEMENT_DL},
    [ELEMENT_DD] = {ELEMENT_DT, ELEMENT_DD, ELEMENT_DL},
    [ELEMENT_LI] = {ELEMENT_UL, ELEMENT_LI},
    [ELEMENT_UL] = {0},
    [ELEMENT_ADDRESS] = {ELEMENT_UL, ELEMENT_LI},
    [ELEMENT_XMP] = {0},
    [ELEMENT_PLAINTEXT] = {0},
};

typedef struct {
    int ptsize;
    int renderstyle;
} TextStyle;

TextStyle element_font_map[] = {
    [ELEMENT_ROOT] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_CUSTOM] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_HEADER] = {.ptsize = 0, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_BODY] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_TITLE] = {.ptsize = 0, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_H1] = {.ptsize = 18, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_H2] = {.ptsize = 16, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_H3] = {.ptsize = 14, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_H4] = {.ptsize = 12, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_H5] = {.ptsize = 12, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_H6] = {.ptsize = 12, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_P] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_DL] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_DT] = {.ptsize = 12, .renderstyle = TTF_STYLE_BOLD},
    [ELEMENT_DD] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_LI] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_UL] = {.ptsize = 12, .renderstyle = TTF_STYLE_NORMAL},
    [ELEMENT_ADDRESS] = {.ptsize = 12, .renderstyle = TTF_STYLE_ITALIC},
};

typedef struct Element {
    Span name;
    LinkedList attributes;
    ElementType type;
} Element;

struct Node;
typedef struct Node {
    NodeType type;
    Span text;
    Element element;
    struct Node *parent;
    LinkedList children;
} Node;

int n_void_elements = 4;
char *void_elements[] = {"nextid", "isindex", "br", "meta"};

Span empty_string = {.data = NULL, .len = 0};

int list_empty(LinkedList *list) { return list->len == 0 || list->head == NULL; }

void str_tolower(uint8_t *str, int len) {
    for (int i = 0; i < len; i++) {
        str[i] = tolower(str[i]);
    }
}

void span_dup(Span *dest, Span *src) {
    dest->data = calloc(src->len, sizeof(uint8_t));
    memcpy(dest->data, src->data, src->len * sizeof(uint8_t));
    dest->len = src->len;
}

void span_free(Span *span) {
    if (span->data) {
        free(span->data);
    }
}

int span_cmp(Span *s1, Span *s2) {
    size_t min_len = s1->len < s2->len ? s1->len : s2->len;
    for (size_t i = 0; i < min_len; i++) {
        uint8_t diff = s1->data[i] - s2->data[i];
        if (diff != 0) {
            return diff;
        }
    }

    return 0;
}

// make function which checks equality
int span_str_cmp(Span *s1, char *str, int len) {
    size_t min_len = s1->len < len ? s1->len : len;
    for (size_t i = 0; i < min_len; i++) {
        uint8_t diff = s1->data[i] - str[i];
        if (diff != 0) {
            return diff;
        }
    }

    return 0;
}

#define SPAN_STR_CMP(s1, str) span_str_cmp(s1, str, sizeof(str))

int is_end_tag_omissable(ElementType type) {
    int *tags = tag_omission_table[type];
    return tags[0] != 0;
}

int should_break_tag(Node *parent, Node *current) {
    int parent_type = parent->element.type;
    if (!is_end_tag_omissable(parent_type)) {
        return 0;
    }

    int *tags = tag_omission_table[parent_type];
    for (; *tags; tags++) {
        if (*tags == current->element.type) {
            return 1;
        }
    }

    return 0;
}

ElementType get_type_from_name(Span name) {
    Span lower;
    span_dup(&lower, &name);
    str_tolower(lower.data, lower.len);
    ElementType final = ELEMENT_CUSTOM;

    if (!SPAN_STR_CMP(&lower, "header")) {
        final = ELEMENT_HEADER;
    } else if (!SPAN_STR_CMP(&lower, "h1")) {
        final = ELEMENT_H1;
    } else if (!SPAN_STR_CMP(&lower, "h2")) {
        final = ELEMENT_H2;
    } else if (!SPAN_STR_CMP(&lower, "h3")) {
        final = ELEMENT_H3;
    } else if (!SPAN_STR_CMP(&lower, "h4")) {
        final = ELEMENT_H4;
    } else if (!SPAN_STR_CMP(&lower, "h5")) {
        final = ELEMENT_H5;
    } else if (!SPAN_STR_CMP(&lower, "h6")) {
        final = ELEMENT_H6;
    } else if (!SPAN_STR_CMP(&lower, "p")) {
        final = ELEMENT_P;
    } else if (!SPAN_STR_CMP(&lower, "body")) {
        final = ELEMENT_BODY;
    } else if (!SPAN_STR_CMP(&lower, "dl")) {
        final = ELEMENT_DL;
    } else if (!SPAN_STR_CMP(&lower, "dt")) {
        final = ELEMENT_DT;
    } else if (!SPAN_STR_CMP(&lower, "dd")) {
        final = ELEMENT_DD;
    } else if (!SPAN_STR_CMP(&lower, "li")) {
        final = ELEMENT_LI;
    } else if (!SPAN_STR_CMP(&lower, "ul")) {
        final = ELEMENT_UL;
    } else if (!SPAN_STR_CMP(&lower, "address")) {
        final = ELEMENT_ADDRESS;
    }

    span_free(&lower);

    return final;
}

int is_void_element(Node *node) {
    for (int i = 0; i < n_void_elements; i++) {
        char *void_element = void_elements[i];
        char *name = strdup(node->element.name.data);
        str_tolower(name, node->element.name.len);
        if (strcmp(name, void_element) == 0) {
            return 1;
        }
    }
    return 0;
}

Node *node_new() {

    Node *current_node = malloc(sizeof(Node));

    current_node->type = NODE_TYPE_TEXT;
    current_node->text = empty_string;

    current_node->children.head = NULL;
    current_node->children.len = 0;

    current_node->element.type = ELEMENT_CUSTOM;
    current_node->element.name.data = NULL;
    current_node->element.name.len = 0;

    current_node->element.attributes.head = NULL;
    current_node->element.attributes.len = 0;

    return current_node;
}

void attribute_reset(Attribute *attribute) {
    attribute->key = empty_string;
    attribute->value = empty_string;
}

Attribute *attribute_new() {
    Attribute *attribute = malloc(sizeof(Attribute));
    attribute_reset(attribute);
    return attribute;
}

void list_append_node(LinkedList *list, Node *node) {
    LinkedListNode *nd = malloc(sizeof(LinkedListNode));
    nd->element = node;
    nd->next = NULL;

    if (list_empty(list)) {
        list->head = nd;
        list->len++;
        return;
    }

    LinkedListNode *el = list->head;
    while (el) {
        if (el->next == NULL) {
            el->next = nd;
            break;
        }

        el = el->next;
    }

    list->len++;
}

void list_push(LinkedList *list, LinkedListNode *node) {
    node->next = list->head;
    list->head = node;
    list->len++;
}

void list_push_node(LinkedList *list, Node *node) {
    LinkedListNode *nd = malloc(sizeof(LinkedListNode));

    nd->element = node;
    nd->next = list->head;

    list->head = nd;
    list->len++;
}

void list_push_attribute(LinkedList *list, Attribute *attr) {
    LinkedListNode *nd = malloc(sizeof(LinkedListNode));

    nd->element = attr;
    nd->next = list->head;

    list->head = nd;
    list->len++;
}

LinkedListNode *list_pop(LinkedList *list) {
    if (list_empty(list)) {
        return NULL;
    }

    LinkedListNode *popped = list->head;
    list->head = list->head->next;
    list->len--;
    return popped;
}

void node_reset(Token *node) {
    node->data.data = NULL;
    node->data.len = 0;
    node->type = TOK_TYPE_TEXT;
}

int is_empty_str_span(Span span) {
    int charfound = 0;
    for (int i = 0; i < span.len; i++) {
        if (is_text_not_empty(span.data[i])) {
            charfound = 1;
            break;
        }
    }

    return !charfound;
}

int is_empty_token(Token *node) {
    if (node->data.data == NULL) {
        return 1;
    }

    if (node->data.len == 0) {
        return 1;
    }

    if (is_empty_str_span(node->data)) {
        return 1;
    }

    return 0;
}

void print_tree(Token *nodes, size_t len) {
    for (size_t i = 0; i < len; i++) {
        Token current = nodes[i];
        fprintf(stdout, "[%s] data: %s\n", token_type_char_map[current.type],
                is_empty_token(&current) ? "(empty)" : (char *)current.data.data);
    }
}

void clear_span(Span *span) {
    if (span->data == NULL) {
        span->len = 0;
        return;
    }

    memset(span->data, 0, span->len * sizeof(uint8_t));
    span->len = 0;
}

void span_append(Span *span, uint8_t byte) {
    span->data[span->len] = byte;
    span->len++;
}

#define BUFFER_SIZE 4096

int tokenize(Span data, Token *tokens, size_t max_len) {
    size_t tokens_len = 0;
    TokenizerState tokstate = STATE_TEXT;
    Token current_node = {.data = {.data = NULL, .len = 0}, .type = TOK_TYPE_TEXT};

    uint8_t bufdata[BUFFER_SIZE] = {0};

    Span buffer = {.len = 0, .data = bufdata};
    int might_close = 0;

    for (size_t i = 0; i < data.len; i++) {
        uint8_t byte = data.data[i];
        if (!is_ascii(byte)) {
            ERROR("Non ascii char at pos: %zu", i);
            continue;
        }

        switch (tokstate) {

        case STATE_TEXT: {
            if (byte == '<') {
                if (buffer.len > 0) {
                    span_dup(&current_node.data, &buffer);

                    tokens[tokens_len] = current_node;
                    tokens_len++;

                    node_reset(&current_node);
                    clear_span(&buffer);
                }

                tokstate = STATE_TAG;
                might_close = 1;

                current_node.type = TOK_TYPE_OPENING_TAG;
                continue;
                // TODO: handle < inside a tag
            } else if (is_text(byte)) {
                tokstate = STATE_TEXT;
            }
            break;
        }
        case STATE_TAG: {
            if (byte == '>') {
                tokstate = STATE_TEXT;
                might_close = 0;

                // span_append(&buffer, byte);

                span_dup(&current_node.data, &buffer);

                tokens[tokens_len] = current_node;
                tokens_len++;

                node_reset(&current_node);
                clear_span(&buffer);

                continue;
            } else if (byte == '!') {
                tokstate = STATE_COMMENT;
                might_close = 0;
                // TODO: tokens should be in a list and not an array so when a comment is found
                // it should be removed instead of appending an empty text node (current approach)
                current_node.type = TOK_TYPE_TEXT;
                continue;
            } else if (byte == '/' && might_close) {
                // is  < /tag> valid???
                current_node.type = TOK_TYPE_CLOSING_TAG;
                continue;
            } else if (is_text(byte)) {
                tokstate = STATE_TAG;
                might_close = 0;
            } else {
                byte = ' ';
            }
            break;
        }
        case STATE_COMMENT: {
            // this sucks but I don't have time
            if (byte == '>' && data.data[i - 1] == '-' && data.data[i - 2] == '-') {
                tokstate = STATE_TEXT;
            }
            continue;
        }
        }

        span_append(&buffer, byte);
    }
    return tokens_len;
}

typedef enum { PARSER_STATE_DEFAULT, PARSER_STATE_EL_OPENED, PARSER_STATE_EL_CLOSED } ParserState;

void print_attribute(Attribute *attribute) { printf("%s = %s; ", attribute->key.data, attribute->value.data); }

void print_node_tree(Node *root, int indent) {
    char spacebuf[128] = {0};
    memset(spacebuf, ' ', indent * 4 * sizeof(char));

    if (root->type == NODE_TYPE_ELEMENT) {
        printf("%s[%s] %s | \x1b[2mdata: %s\x1b[0m | ", spacebuf, node_type_char_map[root->type],
               root->element.name.data, root->text.data);
        if (root->element.attributes.len != 0) {
        }
        if (!list_empty(&root->element.attributes)) {
            LinkedListNode *attr = root->element.attributes.head;
            while (attr) {
                Attribute *attribute = attr->element;
                print_attribute(attribute);
                attr = attr->next;
            }
        }
        putc('\n', stdout);
    } else if (!is_empty_str_span(root->text)) {
        printf("%s[%s] data: %s\n", spacebuf, node_type_char_map[root->type], root->text.data);
    }

    if (list_empty(&root->children)) {
        return;
    }
    LinkedListNode *el = root->children.head;
    while (el) {
        print_node_tree(el->element, indent + 1);
        el = el->next;
    }
}

typedef enum {
    PARSER_ATTR_STATE_DEFAULT,
    PARSER_ATTR_STATE_NAME,
    PARSER_ATTR_STATE_KEY,
    PARSER_ATTR_STATE_VALUE
} ParserAttributesState;

int parse_name_and_attributes(Token *token, Node *node) {
    uint8_t buf[512] = {0};
    Span buffer = {.data = buf, .len = 0};

    Attribute *current_attribute = attribute_new();

    ParserAttributesState previous_state = PARSER_ATTR_STATE_DEFAULT;
    ParserAttributesState state = PARSER_ATTR_STATE_DEFAULT;
    node->element.name.len = 0;
    node->type = NODE_TYPE_ELEMENT;

    for (size_t i = 0; i < token->data.len; i++) {
        uint8_t byte = token->data.data[i];

        switch (state) {
        // Does not handle attributes without ="" (example <hello attr></hello>), or spaces in between keys and values
        // (<hello key = "val"></hello>) Eventually this test case should pass when these issues are fixed: <hello
        // ciao="val" vuoto="" ="" "" att >aaa</hello><vuoto ciao>aaa</vuoto><spazio ddd = "ddd">aaa</spazio>
        case PARSER_ATTR_STATE_DEFAULT: {
            if (node->element.name.len == 0 && token->type != TOK_TYPE_TEXT) {
                state = PARSER_ATTR_STATE_NAME;
            } else if (is_text_not_empty(byte)) {
                if (previous_state == PARSER_ATTR_STATE_KEY) {
                    list_push_attribute(&node->element.attributes, current_attribute);
                    current_attribute = attribute_new();
                }
                previous_state = PARSER_ATTR_STATE_DEFAULT;
                state = PARSER_ATTR_STATE_KEY;
            } else if (byte == '=') {
                state = PARSER_ATTR_STATE_VALUE;
            }
            i--;
            break;
        }
        case PARSER_ATTR_STATE_NAME: {
            if (is_text_not_empty(byte)) {
                buffer.data[buffer.len] = byte;
                buffer.len++;
                if (i + 1 < token->data.len) {
                    break;
                }
            }

            span_dup(&node->element.name, &buffer);
            clear_span(&buffer);

            state = PARSER_ATTR_STATE_DEFAULT;

            break;
        }
        case PARSER_ATTR_STATE_KEY: {
            if (byte == '=') {
                previous_state = PARSER_ATTR_STATE_KEY;
                state = PARSER_ATTR_STATE_VALUE;
                span_dup(&current_attribute->key, &buffer);
                clear_span(&buffer);
                break;
            }

            if (is_text_not_empty(byte)) {
                buffer.data[buffer.len] = byte;
                buffer.len++;
                if (i + 1 < token->data.len) {
                    break;
                }
            }

            span_dup(&current_attribute->key, &buffer);
            clear_span(&buffer);

            previous_state = PARSER_ATTR_STATE_KEY;
            state = PARSER_ATTR_STATE_DEFAULT;

            break;
        }
        case PARSER_ATTR_STATE_VALUE:
            if (is_text_not_empty(byte)) {
                buffer.data[buffer.len] = byte;
                buffer.len++;
                if (i + 1 < token->data.len) {
                    break;
                }
            }

            span_dup(&current_attribute->value, &buffer);
            clear_span(&buffer);

            list_push_attribute(&node->element.attributes, current_attribute);
            current_attribute = attribute_new();

            previous_state = PARSER_ATTR_STATE_VALUE;
            state = PARSER_ATTR_STATE_DEFAULT;

            break;
        }
    }

    node->element.type = get_type_from_name(node->element.name);

    return 0;
}

int parse(Node *initial_root, Token *tokens, size_t len) {
    initial_root->children.len = 0;

    Node *root = initial_root;

    Node *current_node = node_new();
    current_node->parent = initial_root;

    for (size_t i = 0; i < len; i++) {
        Token current_token = tokens[i];
        if (current_token.type != TOK_TYPE_TEXT) {
            parse_name_and_attributes(&current_token, current_node);
        }

        switch (current_token.type) {
        case TOK_TYPE_TEXT: {
            Node *text_node = node_new();
            text_node->type = NODE_TYPE_TEXT;
            text_node->text = current_token.data;
            list_append_node(&root->children, text_node);
            // current_node = node_new();
            break;
        }
        case TOK_TYPE_OPENING_TAG: {
            if (should_break_tag(root, current_node)) {
                if (root->parent) {
                    root = root->parent;
                }
            }

            current_node->type = NODE_TYPE_ELEMENT;
            current_node->text = current_token.data;
            list_append_node(&root->children, current_node);

            if (!is_void_element(current_node)) {
                current_node->parent = root;
                root = current_node;
            }

            current_node = node_new();
            break;
        }
        case TOK_TYPE_CLOSING_TAG: {
            if (root->parent == NULL) {
                break;
            }

            if (should_break_tag(root, current_node)) {
                root = root->parent;
                // If closing node is the same as parent node, go up the tree again

                // I don't know why I'm considering the custom element case, there is no tag that
                // can be broken by a ELEMENT_CUSTOM... (modern browsers agree, tag with omissable ends
                // can't be broken by any element, but only by a few)
                if ((current_node->element.type != ELEMENT_CUSTOM &&
                     current_node->element.type == root->element.type) ||
                    (current_node->element.type == ELEMENT_CUSTOM &&
                     span_cmp(&root->element.name, &current_node->element.name) == 0)) {
                    if (root->parent != NULL) {
                        root = root->parent;
                    }
                }
                break;
            }

            if (span_cmp(&root->element.name, &current_node->element.name)) {
                break;
            }

            root = root->parent;
            break;
        }
        }
    }

    return 0;
}

TTF_Font *font;
SDL_Color white = {0xFF, 0xFF, 0xFF, 0};
SDL_Color black = {0x00, 0x00, 0x00, 0};
SDL_Window *window;
SDL_Renderer *renderer;
SDL_Surface *surface;

int y = 0;

void render(Node *node, int y_par) {
    if (node->type == NODE_TYPE_ELEMENT) {
    } else if (!is_empty_str_span(node->text)) {
        // if(node->parent != NULL) {
        // TextStyle current_style = element_font_map[node->parent->element.type];
        // TTF_SetFontStyle(font, current_style.renderstyle);
        // TTF_SetFontSize(font, current_style.ptsize);
        if (node->type == NODE_TYPE_TEXT) {
            char *str = node->text.data;
            DEBUG("%s", str);
            SDL_Surface *text_surface = TTF_RenderText(font, str, black, white);
            SDL_Texture *text_texture = SDL_CreateTextureFromSurface(renderer, text_surface);
            int width = text_surface->w;
            int height = text_surface->h;

            SDL_FreeSurface(text_surface);
            SDL_Rect pos = {.h = height, .w = width, .x = 0, .y = y};
            SDL_RenderCopy(renderer, text_texture, NULL, &pos);
            y += height;
        }
        LOG("[%s] data: %s\n", node_type_char_map[node->type], node->text.data);
        DEBUG("%d", y);
        //}
    }

    if (list_empty(&node->children)) {
        return;
    }
    LinkedListNode *el = node->children.head;
    while (el) {
        render(el->element, y);
        el = el->next;
    }
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        ERROR("Provide filename as first argument");
        return 1;
    }

    const char *filename = argv[1];

    FILE *file = fopen(filename, "r");
    size_t filesize = get_file_size(file);

    if (filesize > 10000) {
        ERROR("File is too big");
        return 1;
    }

    uint8_t *data = malloc(filesize * sizeof(uint8_t));
    fread(data, sizeof(uint8_t), filesize, file);

    Token tokens[1024];
    size_t tokens_len = tokenize((Span){.data = data, .len = filesize}, tokens, 1024);

    Node root_node = {.children = {.head = NULL, .len = 0},
                      .element = {.type = ELEMENT_ROOT},
                      .type = NODE_TYPE_ELEMENT,
                      .text = {.data = "ROOT", .len = 5}};

    /*     // Test printing
        Node *node = new_node();
        node->text.data = "root";
        Node *child = new_node();
        child->text.data = "child";

        Node *child2 = new_node();
        child2->text.data = "child2";

        Node *child3 = new_node();
        child3->text.data = "child3";

        list_push_node(&node->children, child);
        list_push_node(&node->children, child2);
        list_push_node(&child->children, child3);

        print_node_tree(node, 0);
        // End test printing */

    LOG("TOKENS")
    print_tree(tokens, tokens_len);

    LOG("PARSED ELEMENTS")
    parse(&root_node, tokens, tokens_len);

    print_node_tree(&root_node, 0);

    // TIME TO RENDER!!! Will I make it in time?

    SDL_Event event;

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL:%s", SDL_GetError());
        return 3;
    }

    if (SDL_CreateWindowAndRenderer(800, 600, SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create window and renderer: %s", SDL_GetError());
        return 3;
    }

    if (TTF_Init()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't init SDL_TTF: %s", TTF_GetError());
        return 3;
    }

    TextStyle default_style = {
        .renderstyle = TTF_STYLE_NORMAL,
        .ptsize = 12,
    };

    font = TTF_OpenFont("Roboto-Regular.ttf", default_style.ptsize);
    if (font == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Could not open font: %s", SDL_GetError());
        return 3;
    }
    TTF_SetFontStyle(font, default_style.renderstyle);

    int rendered = 0;

    while (1) {
        SDL_PollEvent(&event);
        if (event.type == SDL_QUIT) {
            break;
        }

        if (!rendered) {
            SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
            SDL_RenderClear(renderer);
            int y = 0;

            render(&root_node, 0);

            SDL_RenderPresent(renderer);

            rendered = 1;
        }
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    SDL_Quit();
    return 0;
}

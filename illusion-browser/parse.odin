package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:time"
import "core:log"
import "core:strings"

ElementStack :: struct {
    top: ^ElementNode,
    free: ^ElementNode,
}

ElementAttribute :: struct {
    name: string,
    value: string,
}

Element :: struct {
    tag: string,
    text: string,
    attributes: []ElementAttribute,
    first: ^Element,
    last: ^Element,
    parent: ^Element,
    next: ^Element,
    prev: ^Element,
}

ElementNode :: struct {
    next: ^ElementNode,
    v: ^Element,
}

Error :: union {
    os.Error,
}

Document :: struct {
    root: ^Element,
    title: string,
}

@(rodata)
inline_tags := [?]string{
    "a", "span", "img",
}

self_closing_tags := [?]string{
    "meta", "link", "col",
    "br", "hr", "img", "input",
    "nextid",
}

contains :: proc(arr: []string, tag: string) -> bool {
    for e in arr {
        if e == tag {
            return true
        }
    }

    return false
}

parse_from_file :: proc(path: string, allocator := context.allocator) -> (doc: Document, err: Error) {
    context.allocator = allocator
    data := os.read_entire_file_or_err(path) or_return

    return parse_from_memory(data), nil
}

parse_from_memory :: proc(data: []byte, allocator := context.allocator) -> Document {
    context.allocator = allocator

    t: Tokenizer
    stack: ElementStack

    tokenizer_init(&t, string(data))
    root := push_node(&stack, "<root>")
    doc: Document
    doc.root = root

    start := time.now()

    loop: for {
        token := tokenizer_next(&t)

        switch token.kind {
        case .EOF:
            break loop
        case .Unknown:
            fmt.eprintln("Encountered unknown token:", token.text)
        case .Comment:
            // Ignore comments
        case .Doctype:
            // Ignore doctype
        case .StartTag:
            //fmt.println("Start:", token)
            tag_name := strings.to_lower(token.text, context.temp_allocator)

            // HACK: lovely hardcoded stuff
            if tag_name == "p" && stack.top.v.tag == "p" {
                // TODO: This will cause any text that's after the nested <p> tag to not be attached to the proper tag.
                // I think instead of popping the parent we can instead push the nested tag as a child of the parent's parent.
                //fmt.println("Closing off parent <p> before starting another <p>")
                pop_node(&stack)
            }

            if tag_name == "dl" && stack.top.v.tag == "p" {
                pop_node(&stack)
            }

            if tag_name == "dd" && stack.top.v.tag == "dt" {
                pop_node(&stack)
            }

            if tag_name == "dt" && stack.top.v.tag == "dd" {
                pop_node(&stack)
            }

            if tag_name == "dd" && stack.top.v.tag == "dd" {
                pop_node(&stack)
            }

            elem := push_node(&stack, token.text)
            elem.attributes = token.attr

            if contains(self_closing_tags[:], tag_name) {
                //fmt.println("Found self-closing tag that wasn't closed")
                pop_node(&stack)
            }
        case .EndTag:
            //fmt.println("End:", token)
            pop_node(&stack)
        case .Text:
            //fmt.println("Text:", token)
            if stack.top.v.tag == "title" {
                doc.title = token.text
            }
            push_node(&stack, "", token.text)
            pop_node(&stack)
        case .SelfClosingTag:
            //fmt.println("Self closing:", token)
            elem := push_node(&stack, token.text)
            elem.attributes = token.attr
            pop_node(&stack)
        }
    }
    log.debug("Tokenizing and parsing took:", time.diff(start, time.now()))

    return doc
}

parse :: proc {parse_from_memory, parse_from_file}

// Double pointer because we can't change the address if we shadow the pointer
@(private = "file")
linked_list_stack_push :: proc "contextless" (f: ^^ElementNode, n: ^ElementNode) {
    n.next = f^
    f^ = n
}

// Double pointer because we can't change the address if we shadow the pointer
@(private = "file")
linked_list_stack_pop :: proc "contextless" (f: ^^ElementNode) {
    f^ = f^.next
}

@(private = "file")
double_linked_list_insert :: proc "contextless" (f, l, p, n: ^^$T) {
    if f^ == nil {
        f^ = n^
        l^ = n^
        n^.next = nil
        n^.prev = nil
    } else if p^ == nil {
        n^.next = f^
        f^.prev = n^
        f^ = n^
        n^.prev = nil
    } else if p^ == l^ {
        l^.next = n^
        n^.prev = l^
        l^ = n^
        n^.next = nil
    } else {
        if p^ != nil && p^.next == nil {
            // do nothing
        } else {
            p^.next.prev = n^
        }
        n^.next = p^.next
        p^.next = n^
        n^.prev = p^
    }
}

@(private = "file")
double_linked_list_push_back :: proc "contextless" (f, l, n: ^^$T) {
    double_linked_list_insert(f, l, l, n)
}

@(private = "file")
double_linked_list_push_front :: proc "contextless" (f, l, n: ^^$T) {
    double_linked_list_insert(l, f, f, n)
}

@(private = "file")
push_node :: proc(stack: ^ElementStack, tag: string, text: string = "", allocator: mem.Allocator = context.allocator) -> ^Element {
    context.allocator = allocator
    node := stack.free
    if node == nil {
        node = new(ElementNode)
    } else {
        linked_list_stack_pop(&stack.free)
    }
    elem := new(Element)
    elem.tag = strings.to_lower(tag)
    elem.text = text
    node.v = elem
    if stack.top != nil {
        node.v.parent = stack.top.v
        double_linked_list_push_back(&stack.top.v.first, &stack.top.v.last, &node.v)
    }

    linked_list_stack_push(&stack.top, node)

    return node.v
}

@(private = "file")
pop_node :: proc "contextless" (stack: ^ElementStack) {
    popped := stack.top

    linked_list_stack_pop(&stack.top)
    linked_list_stack_push(&stack.free, popped)
}

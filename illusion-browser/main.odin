package main

import "core:strings"
import "core:fmt"
import "core:log"
import "core:mem"
import m "core:math/linalg/glsl"
import "core:os"
import "core:mem/virtual"

import gl "vendor:OpenGL"

import "engine"

print_tree :: proc(root: ^Element) {
    nest := 0

    iter_children :: proc(node: ^Element, nest: int) {
        for child := node.first; child != nil; child = child.next {
            space := strings.repeat(" ", nest * 4)
            if child.tag != "" {
                fmt.printfln("%s<%s>", space, child.tag)
            } else if child.text != "" {
                fmt.printfln("%s%s", space, child.text)
            }
            iter_children(child, nest + 1)
            if child.tag != "" {
                fmt.printfln("%s</%s>", space, child.tag)
            }
        }
    }

    iter_children(root, nest)
}

block_elements := [?]string{
    "h1", "p", "dl", "dt", "dd",
}

StyleState :: struct {
    font_size: u32,
    margin: m.vec4,
    text_color: engine.Color,
}

draw_pos: m.vec2
style := StyleState{16, 0, engine.COLOR_BLACK}

main :: proc() {
    context.logger = log.create_console_logger()

    args := os.args
    defer delete(os.args)

    if len(os.args) < 2 {
        fmt.eprintln("Please provide an html file as the first argument to the program")
        return
    }

    arena: virtual.Arena
    err := virtual.arena_init_static(&arena, commit_size = mem.Megabyte * 8)
    if err != nil {
        fmt.eprintln("Failed to allocate memory")
        return
    }
    allocator := virtual.arena_allocator(&arena)

    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, allocator)
    defer mem.tracking_allocator_destroy(&track)

    doc, parse_err := parse(args[1], mem.tracking_allocator(&track))
    if parse_err != nil {
        fmt.eprintln("Failed to parse html file: ", parse_err)
        return
    }

    engine.init("", strings.clone_to_cstring(doc.title), {640, 480}, false)
    engine.set_clear_color({1, 1, 1, 1})
    defer engine.deinit()

    screenshot := false

    for !engine.should_quit() {
        engine.frame_start()

        e := engine.iter_events()
        for e != nil {
            #partial switch e.type {
                case .WINDOW_CLOSED:
                    engine.quit()
                case .VIRT_KEY_PRESSED:
                    if e.key.scancode == .P {
                        screenshot = true
                    }
                    if e.key.scancode == .F11 {
                        engine.toggle_fullscreen()
                    }
            }
            e = engine.iter_events()
        }

        draw_pos = {8, 8}

        gl.Disable(gl.DEPTH_TEST)

        draw_children :: proc(node: ^Element) {
            for child := node.first; child != nil; child = child.next {
                if child.tag == "title" || child.tag == "style" || child.tag == "script" {
                    continue
                }

                if child != node.first && contains(block_elements[:], child.tag) && child.prev != nil && child.prev.text != "" {
                    draw_pos.x = 8
                    draw_pos.y += f32(style.font_size) + f32(style.font_size / 16 * 8)
                }

                if child.tag == "h1" {
                    style.font_size = 32
                    style.margin[0] = 21
                    style.margin[2] = 21
                }

                if child.tag == "p" {
                    style.margin[0] = 16
                    style.margin[2] = 16
                }

                if child.tag == "dd" {
                    draw_pos.x += 40
                }

                // We only draw text nodes.
                if child.text != "" {
                    draw_pos.y += style.margin[0]

                    if child.parent.tag == "a" {
                        style.text_color = engine.COLOR_BLUE
                        style.margin = 0
                        // If the <a> tag's prev sibling is a text node
                        if child.parent.prev != nil && child.parent.prev.tag == "" {
                            draw_pos.x += 6
                        }
                    } else {
                        style.text_color = engine.COLOR_BLACK
                    }

                    cons := engine.DEFAULT_UI_CONSTRAINTS

                    engine.set_x_constraint(&cons, draw_pos.x, .FIXED)
                    engine.set_y_constraint(&cons, draw_pos.y, .FIXED)
                    engine.set_width_constraint(&cons, 1, .FIXED)

                    engine.draw_text(child.text, style.font_size, cons, style.text_color, .TOP_LEFT)

                    text_size := engine.calculate_text_size(child.text, 16)

                    draw_pos += {text_size.x, 0}


                    // If the <a> tag's next sibling is a text node
                    if child.parent.next != nil && child.parent.next.tag == "" && child.parent.tag == "a" {
                        draw_pos.x += 6
                    }
                }

                draw_children(child)

                draw_pos.y += style.margin[2]

                if contains(block_elements[:], child.tag) {
                    draw_pos.x = 8
                    draw_pos.y += f32(style.font_size) + f32(style.font_size / 16 * 8)
                }

                style.font_size = 16
                style.margin = 0
            }
        }

        draw_children(doc.root)

        engine.frame_end()

        if screenshot {
            engine.save_default_framebuffer_to_image()
            screenshot = false
        }
    }

    print_tree(doc.root)

    free_all(mem.tracking_allocator(&track))

    for _, leak in track.allocation_map {
        log.debugf("%v leaked %m", leak.location, leak.size)
    }
    for bad_free in track.bad_free_array {
        log.debugf("%v allocation %p was freed badly", bad_free.location, bad_free.memory)
    }
    log.debugf("Total Mem: %m", track.total_memory_allocated)
    log.debugf("Current Mem: %m", track.current_memory_allocated)
    log.debugf("Peak Mem: %m", track.peak_memory_allocated)
    log.debugf("Total Allocs: %v, Total Frees: %v:", track.total_allocation_count, track.total_free_count)
    log.debugf("Total Mem Free'd: %m", track.total_memory_freed)
}


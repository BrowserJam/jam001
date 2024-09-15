package zephr

import "core:log"
import m "core:math/linalg/glsl"
import "core:mem"
import "core:os"

import gl "vendor:OpenGL"

UiIdHash :: u32

Alignment :: enum {
    TOP_LEFT,
    TOP_CENTER,
    TOP_RIGHT,
    LEFT_CENTER,
    CENTER,
    RIGHT_CENTER,
    BOTTOM_LEFT,
    BOTTOM_CENTER,
    BOTTOM_RIGHT,
}

UiConstraint :: enum {
    FIXED,
    RELATIVE,
    RELATIVE_PIXELS,
    ASPECT_RATIO,
}

ButtonState :: enum {
    ACTIVE,
    INACTIVE,
    DISABLED,
}

UiConstraints :: struct {
    x:        f32,
    y:        f32,
    width:    f32,
    height:   f32,
    rotation: f32,
    scale:    m.vec2,
    parent:   ^UiConstraints,
}

Rect :: struct {
    pos:  m.vec2,
    size: m.vec2,
}

UiStyle :: struct {
    bg_color:      Color,
    fg_color:      Color,
    border_radius: f32,
    align:         Alignment,
}

UiElement :: struct {
    id:   UiIdHash,
    rect: Rect,
}

Ui :: struct {
    hovered_element:          UiIdHash,
    active_element:           UiIdHash,
    elements:                 [dynamic]UiElement,
    popup_open:               bool,
    popup_parent_hash:        UiIdHash,
    popup_rect:               Rect,
    popup_parent_constraints: UiConstraints,
    popup_revert_color:       ^Color,
}

@(private)
ui_shader: ^Shader
@(private)
color_chooser_shader: ^Shader
@(private)
ui_vao: u32
@(private)
ui_vbo: u32

DEFAULT_UI_CONSTRAINTS :: UiConstraints {
    x        = 0,
    y        = 0,
    width    = 0,
    height   = 0,
    rotation = 0,
    scale    = m.vec2{1, 1},
    parent   = nil,
}

@(private)
ui_init :: proc(font_path: string) {
    context.logger = logger

    res := init_fonts(font_path)
    if (res == -1) {
        log.fatal("Failed to initialize the freetype library")
        os.exit(1)
    } else if (res == -2) {
        log.fatalf("Failed to load font file: \"%s\"", font_path)
        os.exit(1)
    } else if (res != 0) {
        os.exit(1)
    }

    l_ui_shader, success1 := create_shader(create_resource_path("shaders/ui.vert"), create_resource_path("shaders/ui.frag"))
    l_color_chooser_shader, success2 := create_shader(
        create_resource_path("shaders/ui.vert"),
        create_resource_path("shaders/color_chooser.frag"),
    )

    ui_shader = l_ui_shader
    color_chooser_shader = l_color_chooser_shader

    if !success1 || !success2 {
        log.fatal("Failed to load ui shaders")
        os.exit(1)
    }

    gl.GenVertexArrays(1, &ui_vao)
    gl.GenBuffers(1, &ui_vbo)

    gl.BindVertexArray(ui_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 6 * 4, nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}

set_parent_constraint :: proc(constraints: ^UiConstraints, parent_constraints: ^UiConstraints) {
    constraints.parent = parent_constraints
}

set_x_constraint :: proc(constraints: ^UiConstraints, value: f32, type: UiConstraint) {
    switch (type) {
        case .ASPECT_RATIO:
            // no-op. fall back to FIXED
            fallthrough
        case .FIXED:
            constraints.x = value
        case .RELATIVE:
            if (constraints.parent != nil) {
                constraints.x = (value * constraints.parent.width)
            } else {
                constraints.x = (value * zephr_ctx.window.size.x)
            }
        case .RELATIVE_PIXELS:
            constraints.x = zephr_ctx.window.size.x / zephr_ctx.screen_size.x * value
    }

    if (constraints.parent != nil) {
        constraints.x += constraints.parent.x
    }
}

set_y_constraint :: proc(constraints: ^UiConstraints, value: f32, type: UiConstraint) {
    switch (type) {
        case .ASPECT_RATIO:
            // no-op. fall back to FIXED
            fallthrough
        case .FIXED:
            constraints.y = value
        case .RELATIVE:
            if (constraints.parent != nil) {
                constraints.y = (value * constraints.parent.height)
            } else {
                constraints.y = (value * zephr_ctx.window.size.y)
            }
        case .RELATIVE_PIXELS:
            constraints.y = zephr_ctx.window.size.y / zephr_ctx.screen_size.y * value
    }

    if (constraints.parent != nil) {
        constraints.y += constraints.parent.y
    }
}

set_width_constraint :: proc(constraints: ^UiConstraints, value: f32, type: UiConstraint) {
    switch (type) {
        case .FIXED:
            constraints.width = value
        case .RELATIVE:
            if (constraints.parent != nil) {
                constraints.width = (value * constraints.parent.width)
            } else {
                constraints.width = (value * zephr_ctx.window.size.x)
            }
        case .RELATIVE_PIXELS:
            constraints.width = zephr_ctx.window.size.x / zephr_ctx.screen_size.x * value
        case .ASPECT_RATIO:
            constraints.width = constraints.height * value
    }
}

set_height_constraint :: proc(constraints: ^UiConstraints, value: f32, type: UiConstraint) {
    switch (type) {
        case .FIXED:
            constraints.height = value
        case .RELATIVE:
            if (constraints.parent != nil) {
                constraints.height = (value * constraints.parent.height)
            } else {
                constraints.height = (value * zephr_ctx.window.size.y)
            }
        case .RELATIVE_PIXELS:
            constraints.height = zephr_ctx.window.size.y / zephr_ctx.screen_size.y * value
        case .ASPECT_RATIO:
            constraints.height = constraints.width * value
    }
}

set_rotation_constraint :: proc(constraints: ^UiConstraints, angle_d: f32) {
    constraints.rotation = angle_d
}

@(private)
apply_constraints :: proc(constraints: ^UiConstraints, pos: ^m.vec2, size: ^m.vec2) {
    pos^ = m.vec2{constraints.x, constraints.y}
    size^ = m.vec2{constraints.width, constraints.height}
}

@(private)
apply_alignment :: proc(align: Alignment, constraints: ^UiConstraints, size: m.vec2, pos: ^m.vec2) {
    // if we don't have a parent then we're a top level element and we should align against the window
    parent_size := m.vec2{zephr_ctx.window.size.x, zephr_ctx.window.size.y}
    if (constraints.parent != nil) {
        parent_size = m.vec2{constraints.parent.width, constraints.parent.height}
    }

    switch (align) {
        case .TOP_LEFT:
            pos.x = pos.x
            pos.y = pos.y
        case .TOP_CENTER:
            pos.x += parent_size.x / 2 - size.x / 2
            pos.y = pos.y
        case .TOP_RIGHT:
            pos.x += parent_size.x - size.x
            pos.y = pos.y
        case .BOTTOM_LEFT:
            pos.x = pos.x
            pos.y += parent_size.y - size.y
        case .BOTTOM_CENTER:
            pos.x += parent_size.x / 2 - size.x / 2
            pos.y += parent_size.y - size.y
        case .BOTTOM_RIGHT:
            pos.x += parent_size.x - size.x
            pos.y += parent_size.y - size.y
        case .LEFT_CENTER:
            pos.x = pos.x
            pos.y += parent_size.y / 2 - size.y / 2
        case .RIGHT_CENTER:
            pos.x += parent_size.x - size.x
            pos.y += parent_size.y / 2 - size.y / 2
        case .CENTER:
            pos.x += parent_size.x / 2 - size.x / 2
            pos.y += parent_size.y / 2 - size.y / 2
    }
}

@(private)
// TODO: make this handle rotated and scaled rects too
inside_rect :: proc(rect: Rect, point: m.vec2) -> bool {
    return(
        point.x >= rect.pos.x &&
        point.x <= rect.pos.x + rect.size.x &&
        point.y >= rect.pos.y &&
        point.y <= rect.pos.y + rect.size.y \
    )
}

draw_quad :: proc(constraints: ^UiConstraints, style: UiStyle) {
    use_shader(ui_shader)

    set_vec4f(
        ui_shader,
        "aColor",
        cast(f32)style.bg_color.r / 255,
        cast(f32)style.bg_color.g / 255,
        cast(f32)style.bg_color.b / 255,
        cast(f32)style.bg_color.a / 255,
    )
    set_float(ui_shader, "uiWidth", constraints.width)
    set_float(ui_shader, "uiHeight", constraints.height)
    set_float(ui_shader, "borderRadius", style.border_radius)
    set_mat4f(ui_shader, "projection", zephr_ctx.projection)

    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(style.align, constraints, rect.size, &rect.pos)

    // set the positions after applying alignment so children can use them
    constraints.x = rect.pos.x
    constraints.y = rect.pos.y

    model := m.identity(m.mat4)
    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Scale(m.vec3{constraints.scale.x, constraints.scale.y, 1}) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Rotate(m.vec3{0, 0, 1}, m.radians(constraints.rotation)) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    set_mat4f(ui_shader, "model", model)

    gl.BindVertexArray(ui_vao)

    vertices: [6][4]f32 = {
        // bottom left tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0, 0, 0.0, 0.0},
        {0 + rect.size.x, 0, 1.0, 0.0},

        // top right tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0 + rect.size.x, 0, 1.0, 0.0},
        {0 + rect.size.x, 0 + rect.size.y, 1.0, 1.0},
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(&vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    gl.BindVertexArray(0)
}

draw_circle :: proc(constraints: ^UiConstraints, style: UiStyle) {
    radius: f32 = 0

    if (constraints.width > constraints.height) {
        radius = constraints.height / 2
    } else {
        radius = constraints.width / 2
    }

    new_style := style
    new_style.border_radius = radius

    draw_quad(constraints, new_style)
}

draw_triangle :: proc(constraints: ^UiConstraints, style: UiStyle) {
    use_shader(ui_shader)

    set_vec4f(
        ui_shader,
        "aColor",
        cast(f32)style.bg_color.r / 255,
        cast(f32)style.bg_color.g / 255,
        cast(f32)style.bg_color.b / 255,
        cast(f32)style.bg_color.a / 255,
    )
    set_float(ui_shader, "borderRadius", 0)
    set_mat4f(ui_shader, "projection", zephr_ctx.projection)

    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(style.align, constraints, rect.size, &rect.pos)

    // set the positions after applying alignment so children can use them
    constraints.x = rect.pos.x
    constraints.y = rect.pos.y

    model := m.identity(m.mat4)
    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Scale(m.vec3{constraints.scale.x, constraints.scale.y, 1}) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Rotate(m.vec3{0, 0, 1}, m.radians(constraints.rotation)) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    set_mat4f(ui_shader, "model", model)

    gl.BindVertexArray(ui_vao)

    vertices := [3][4]f32 {
        {0 + rect.size.x, 0, 0.0, 0.0},
        {0, 0, 0.0, 0.0},
        {0 + rect.size.x / 2, 0 + rect.size.y, 0.0, 0.0},
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(&vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.DrawArrays(gl.TRIANGLES, 0, 3)

    gl.BindVertexArray(0)
}

draw_texture :: proc(constraints: ^UiConstraints, texture_id: TextureId, style: UiStyle, flip_y: bool = false) {
    use_shader(ui_shader)

    set_vec4f(
        ui_shader,
        "aColor",
        cast(f32)style.bg_color.r / 255,
        cast(f32)style.bg_color.g / 255,
        cast(f32)style.bg_color.b / 255,
        cast(f32)style.bg_color.a / 255,
    )
    set_float(ui_shader, "uiWidth", constraints.width)
    set_float(ui_shader, "uiHeight", constraints.height)
    set_float(ui_shader, "borderRadius", style.border_radius)
    set_bool(ui_shader, "hasTexture", true)

    set_mat4f(ui_shader, "projection", zephr_ctx.projection)

    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(style.align, constraints, rect.size, &rect.pos)

    // set the positions after applying alignment so children can use them
    constraints.x = rect.pos.x
    constraints.y = rect.pos.y

    model := m.identity(m.mat4)
    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Scale(m.vec3{constraints.scale.x, constraints.scale.y, 1}) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{-rect.size.x / 2, -rect.size.y / 2, 0}) * model
    model = m.mat4Rotate(m.vec3{0, 0, 1}, m.radians(constraints.rotation)) * model
    model = m.mat4Translate(m.vec3{rect.size.x / 2, rect.size.y / 2, 0}) * model

    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    set_mat4f(ui_shader, "model", model)

    gl.BindVertexArray(ui_vao)

    v1_uv := m.vec2{0.0, 1.0}
    v2_uv := m.vec2{0.0, 0.0}
    v3_uv := m.vec2{1.0, 0.0}
    v4_uv := m.vec2{0.0, 1.0}
    v5_uv := m.vec2{1.0, 0.0}
    v6_uv := m.vec2{1.0, 1.0}

    if flip_y {
        v1_uv.y = 0.0
        v2_uv.y = 1.0
        v3_uv.y = 1.0
        v4_uv.y = 0.0
        v5_uv.y = 1.0
        v6_uv.y = 0.0
    }

    vertices := [6][4]f32 {
        // bottom left tri
        {0, 0 + rect.size.y, v1_uv.x, v1_uv.y},
        {0, 0, v2_uv.x, v2_uv.y},
        {0 + rect.size.x, 0, v3_uv.x, v3_uv.y},

        // top right tri
        {0, 0 + rect.size.y, v4_uv.x, v4_uv.y},
        {0 + rect.size.x, 0, v5_uv.x, v5_uv.y},
        {0 + rect.size.x, 0 + rect.size.y, v6_uv.x, v6_uv.y},
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(&vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, texture_id)

    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    gl.BindVertexArray(0)
    set_bool(ui_shader, "hasTexture", false)
}

draw_button :: proc(
    constraints: ^UiConstraints,
    text: string,
    style: UiStyle,
    state: ButtonState,
    id: u32 = 0,
    caller := #caller_location,
) -> bool {
    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    id := id
    id_bytes := mem.byte_slice(&id, size_of(id))
    hash := fnv_hash(id_bytes, size_of(id), FNV_HASH32_INIT)
    hash = fnv_hash(transmute([]byte)caller.file_path, cast(u64)len(caller.file_path), hash)
    hash = fnv_hash(line_bytes, size_of(caller.line), hash)

    style := style
    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(style.align, constraints, rect.size, &rect.pos)

    is_hovered := zephr_ctx.ui.hovered_element == hash
    is_held := zephr_ctx.ui.active_element == hash
    left_mouse_pressed := .LEFT in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
    left_mouse_released := .LEFT in zephr_ctx.virt_mouse.button_has_been_released_bitset
    clicked := false

    if (zephr_ctx.ui.active_element == 0) {
        if (is_hovered && left_mouse_pressed) {
            zephr_ctx.ui.active_element = hash
        }
    } else if (zephr_ctx.ui.active_element == hash) {
        if (left_mouse_released) {
            zephr_ctx.ui.active_element = 0

            if (is_hovered) {
                clicked = true
            }
        }
    }

    if (is_hovered && state == .ACTIVE) {
        set_cursor(.HAND)

        if (is_held) {
            style.bg_color = mult_color(style.bg_color, 0.8)
            style.fg_color = mult_color(style.fg_color, 0.8)
        } else {
            style.bg_color = mult_color(style.bg_color, 0.9)
            style.fg_color = mult_color(style.fg_color, 0.9)
        }
    } else if (state == .DISABLED) {
        if (is_hovered) {
            set_cursor(.DISABLED)
        }

        style.bg_color.a = 100
        style.fg_color.a = 100
    }

    draw_quad(constraints, style)

    if (text != "") {
        text_constraints := DEFAULT_UI_CONSTRAINTS

        set_parent_constraint(&text_constraints, constraints)
        set_x_constraint(&text_constraints, 0, .RELATIVE_PIXELS)
        set_y_constraint(&text_constraints, 0, .RELATIVE_PIXELS)
        set_width_constraint(&text_constraints, 1.0, .RELATIVE_PIXELS)

        font_size := ((constraints.width) / (text_constraints.width * 0.1 * 65))

        // TODO: need to adjust the font size based on the text height

        draw_text(text, cast(u32)font_size, text_constraints, style.fg_color, .CENTER)
    }

    element := UiElement {
        id   = hash,
        rect = rect,
    }

    append(&zephr_ctx.ui.elements, element)

    if (clicked && state == .ACTIVE) {
        return true
    }

    return false
}

draw_icon_button :: proc(
    constraints: ^UiConstraints,
    icon_tex_id: TextureId,
    style: UiStyle,
    state: ButtonState,
    id: u32 = 0,
    caller := #caller_location,
) -> bool {
    log.assert(icon_tex_id != 0, "draw_icon_button() requires that you provide an icon texture")

    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    id := id
    id_bytes := mem.byte_slice(&id, size_of(id))
    hash := fnv_hash(id_bytes, size_of(id), FNV_HASH32_INIT)
    hash = fnv_hash(transmute([]byte)caller.file_path, cast(u64)len(caller.file_path), hash)
    hash = fnv_hash(line_bytes, size_of(caller.line), hash)

    style := style
    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(style.align, constraints, rect.size, &rect.pos)

    is_hovered := zephr_ctx.ui.hovered_element == hash
    is_held := zephr_ctx.ui.active_element == hash
    left_mouse_pressed := .LEFT in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
    left_mouse_released := .LEFT in zephr_ctx.virt_mouse.button_has_been_released_bitset
    clicked := false

    if (zephr_ctx.ui.active_element == 0) {
        if (is_hovered && left_mouse_pressed) {
            zephr_ctx.ui.active_element = hash
        }
    } else if (zephr_ctx.ui.active_element == hash) {
        if (left_mouse_released) {
            zephr_ctx.ui.active_element = 0

            if (is_hovered) {
                clicked = true
            }
        }
    }

    if (is_hovered && state == .ACTIVE) {
        set_cursor(.HAND)

        if (is_held) {
            style.bg_color = mult_color(style.bg_color, 0.8)
            style.fg_color = mult_color(style.fg_color, 0.8)
        } else {
            style.bg_color = mult_color(style.bg_color, 0.9)
            style.fg_color = mult_color(style.fg_color, 0.9)
        }
    } else if (state == .DISABLED) {
        if (is_hovered) {
            set_cursor(.DISABLED)
        }

        style.fg_color.a = 100
        style.bg_color.a = 100
    }

    draw_quad(constraints, style)

    icon_constraints := DEFAULT_UI_CONSTRAINTS

    set_parent_constraint(&icon_constraints, constraints)
    set_x_constraint(&icon_constraints, 0, .RELATIVE_PIXELS)
    set_y_constraint(&icon_constraints, 0, .RELATIVE_PIXELS)
    set_width_constraint(&icon_constraints, constraints.width * 0.8, .FIXED)
    set_height_constraint(&icon_constraints, constraints.height * 0.8, .FIXED)
    tex_style := UiStyle {
        bg_color = style.fg_color,
        align    = .CENTER,
    }
    draw_texture(&icon_constraints, icon_tex_id, tex_style)

    element := UiElement {
        id   = hash,
        rect = rect,
    }

    append(&zephr_ctx.ui.elements, element)

    if (clicked && state == .ACTIVE) {
        return true
    }

    return false
}

@(private)
draw_color_picker_slider :: proc(constraints: ^UiConstraints, align: Alignment, caller := #caller_location) -> f32 {
    @(static)
    slider_selection: f32 = 0
    @(static)
    dragging := false

    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    hash := fnv_hash(transmute([]byte)caller.file_path, cast(u64)len(caller.file_path), FNV_HASH32_INIT)
    hash = fnv_hash(line_bytes, size_of(caller.line), hash)

    use_shader(color_chooser_shader)

    set_bool(color_chooser_shader, "isSlider", true)
    set_mat4f(color_chooser_shader, "projection", zephr_ctx.projection)

    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(align, constraints, rect.size, &rect.pos)

    // set the positions after applying alignment so children can use them
    constraints.x = rect.pos.x
    constraints.y = rect.pos.y

    is_hovered := zephr_ctx.ui.hovered_element == hash
    left_mouse_pressed := .LEFT in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
    left_mouse_released := .LEFT in zephr_ctx.virt_mouse.button_has_been_released_bitset

    if (zephr_ctx.ui.active_element == 0) {
        if (is_hovered && left_mouse_pressed) {
            zephr_ctx.ui.active_element = hash
            dragging = true
        }
    } else if (zephr_ctx.ui.active_element == hash) {
        if (left_mouse_released) {
            zephr_ctx.ui.active_element = 0
            dragging = false
        }
    }

    if (dragging) {
        slider_selection = clamp((zephr_ctx.virt_mouse.pos.y - constraints.y) / constraints.height, 0, 1)
    }

    model := m.identity(m.mat4)
    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    set_mat4f(color_chooser_shader, "model", model)

    gl.BindVertexArray(ui_vao)

    vertices := [6][4]f32 {
        // bottom left tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0, 0, 0.0, 0.0},
        {0 + rect.size.x, 0, 1.0, 0.0},

        // top right tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0 + rect.size.x, 0, 1.0, 0.0},
        {0 + rect.size.x, 0 + rect.size.y, 1.0, 1.0},
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(&vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    gl.BindVertexArray(0)
    set_bool(color_chooser_shader, "isSlider", false)

    // draw the selection
    triangle_con := DEFAULT_UI_CONSTRAINTS
    set_parent_constraint(&triangle_con, constraints)
    set_x_constraint(&triangle_con, -11, .RELATIVE_PIXELS)
    set_y_constraint(&triangle_con, slider_selection, .RELATIVE)
    set_rotation_constraint(&triangle_con, -90)
    set_width_constraint(&triangle_con, 14, .RELATIVE_PIXELS)
    set_height_constraint(&triangle_con, 0.5, .ASPECT_RATIO)
    triangle_con.y += -(triangle_con.height / 2)
    tri_style := UiStyle {
        bg_color      = COLOR_BLACK,
        border_radius = 0,
        align         = .TOP_LEFT,
    }
    draw_triangle(&triangle_con, tri_style)

    set_x_constraint(&triangle_con, 1, .RELATIVE)
    triangle_con.x -= triangle_con.height / 2
    set_rotation_constraint(&triangle_con, 90)
    draw_triangle(&triangle_con, tri_style)

    element := UiElement {
        id   = hash,
        rect = rect,
    }

    append(&zephr_ctx.ui.elements, element)

    return slider_selection
}

@(private)
draw_color_picker_canvas :: proc(
    constraints: ^UiConstraints,
    slider_percentage: f32,
    align: Alignment,
    caller := #caller_location,
) -> Color {
    @(static)
    dragging := false
    @(static)
    canvas_pos := m.vec2{0, 0}

    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    hash := fnv_hash(transmute([]byte)caller.file_path, cast(u64)len(caller.file_path), FNV_HASH32_INIT)
    hash = fnv_hash(line_bytes, size_of(caller.line), hash)

    use_shader(color_chooser_shader)

    set_bool(color_chooser_shader, "isSlider", false)
    set_float(color_chooser_shader, "sliderPercentage", slider_percentage)
    set_mat4f(color_chooser_shader, "projection", zephr_ctx.projection)

    rect: Rect = ---

    apply_constraints(constraints, &rect.pos, &rect.size)
    apply_alignment(align, constraints, rect.size, &rect.pos)

    // set the positions after applying alignment so children can use them
    constraints.x = rect.pos.x
    constraints.y = rect.pos.y

    is_hovered := zephr_ctx.ui.hovered_element == hash
    left_mouse_pressed := .LEFT in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
    left_mouse_released := .LEFT in zephr_ctx.virt_mouse.button_has_been_released_bitset

    if (zephr_ctx.ui.active_element == 0) {
        if (is_hovered && left_mouse_pressed) {
            zephr_ctx.ui.active_element = hash
            dragging = true
        }
    } else if (zephr_ctx.ui.active_element == hash) {
        if (left_mouse_released) {
            zephr_ctx.ui.active_element = 0
            dragging = false
        }
    }

    if (dragging) {
        x := (zephr_ctx.virt_mouse.pos.x - constraints.x) / constraints.width
        y := (zephr_ctx.virt_mouse.pos.y - constraints.y) / constraints.height

        canvas_pos.x = clamp(x, 0, 1)
        canvas_pos.y = clamp(y, 0, 1)
    }

    model := m.identity(m.mat4)
    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    set_mat4f(color_chooser_shader, "model", model)

    gl.BindVertexArray(ui_vao)

    vertices := [6][4]f32 {
        // bottom left tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0, 0, 0.0, 0.0},
        {0 + rect.size.x, 0, 1.0, 0.0},

        // top right tri
        {0, 0 + rect.size.y, 0.0, 1.0},
        {0 + rect.size.x, 0, 1.0, 0.0},
        {0 + rect.size.x, 0 + rect.size.y, 1.0, 1.0},
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), raw_data(&vertices))
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    gl.DrawArrays(gl.TRIANGLES, 0, 6)

    gl.BindVertexArray(0)

    selected_color := hsv2rgb(slider_percentage * 360, canvas_pos.x, 1.0 - canvas_pos.y)

    // draw the selection
    triangle_con := DEFAULT_UI_CONSTRAINTS
    set_parent_constraint(&triangle_con, constraints)
    set_x_constraint(&triangle_con, canvas_pos.x, .RELATIVE)
    set_y_constraint(&triangle_con, canvas_pos.y, .RELATIVE)
    set_width_constraint(&triangle_con, 14, .RELATIVE_PIXELS)
    set_height_constraint(&triangle_con, 0.5, .ASPECT_RATIO)
    triangle_con.x -= triangle_con.height
    triangle_con.y -= triangle_con.height + triangle_con.height / 2 + triangle_con.width / 2
    set_rotation_constraint(&triangle_con, 0)
    tri_style := UiStyle {
        bg_color      = determine_color_contrast(selected_color),
        border_radius = 0,
        align         = .TOP_LEFT,
    }
    draw_triangle(&triangle_con, tri_style)

    triangle_con.x += triangle_con.height * 2
    triangle_con.y += triangle_con.height * 2
    set_rotation_constraint(&triangle_con, 90)
    draw_triangle(&triangle_con, tri_style)

    triangle_con.x -= triangle_con.height * 2
    triangle_con.y += triangle_con.height * 2
    set_rotation_constraint(&triangle_con, 180)
    draw_triangle(&triangle_con, tri_style)

    triangle_con.x -= triangle_con.height * 2
    triangle_con.y -= triangle_con.height * 2
    set_rotation_constraint(&triangle_con, 270)
    draw_triangle(&triangle_con, tri_style)

    element := UiElement {
        id   = hash,
        rect = rect,
    }

    append(&zephr_ctx.ui.elements, element)

    return selected_color
}

@(private)
draw_color_picker_popup :: proc(picker_button_con: ^UiConstraints) {
    id := 023467
    id_bytes := mem.byte_slice(&id, size_of(id))
    hash := fnv_hash(id_bytes, size_of(id), zephr_ctx.ui.popup_parent_hash)
    popup_con := DEFAULT_UI_CONSTRAINTS
    set_parent_constraint(&popup_con, picker_button_con)
    set_x_constraint(&popup_con, 0, .FIXED)
    set_y_constraint(&popup_con, 1.4, .RELATIVE)
    set_width_constraint(&popup_con, 450, .RELATIVE_PIXELS)
    set_height_constraint(&popup_con, 480, .RELATIVE_PIXELS)
    popup_style := UiStyle {
        bg_color      = mult_color(COLOR_WHITE, 0.94),
        border_radius = popup_con.width * 0.02,
        align         = .TOP_LEFT,
    }
    draw_quad(&popup_con, popup_style)

    rect := Rect{{popup_con.x, popup_con.y}, {popup_con.width, popup_con.height}}

    element := UiElement {
        id   = hash,
        rect = rect,
    }

    append(&zephr_ctx.ui.elements, element)

    color_slider_con := DEFAULT_UI_CONSTRAINTS
    set_parent_constraint(&color_slider_con, &popup_con)
    set_x_constraint(&color_slider_con, -0.04, .RELATIVE)
    set_y_constraint(&color_slider_con, 0.05, .RELATIVE)
    set_height_constraint(&color_slider_con, 400 * 0.9, .RELATIVE_PIXELS)
    set_width_constraint(&color_slider_con, 0.1, .ASPECT_RATIO)
    slider_selection := draw_color_picker_slider(&color_slider_con, .TOP_RIGHT)

    set_x_constraint(&color_slider_con, 0.04, .RELATIVE)
    set_y_constraint(&color_slider_con, 0.05, .RELATIVE)
    set_width_constraint(&color_slider_con, popup_con.width * 0.8, .FIXED)
    selected_color := draw_color_picker_canvas(&color_slider_con, slider_selection, .TOP_LEFT)

    button_con := DEFAULT_UI_CONSTRAINTS
    set_parent_constraint(&button_con, &popup_con)
    set_x_constraint(&button_con, 0.04, .RELATIVE)
    set_y_constraint(&button_con, -0.05, .RELATIVE)
    set_width_constraint(&button_con, 0.43, .RELATIVE)
    set_height_constraint(&button_con, 0.3, .ASPECT_RATIO)
    button_style := UiStyle {
        bg_color      = zephr_ctx.ui.popup_revert_color^,
        fg_color      = determine_color_contrast(zephr_ctx.ui.popup_revert_color^),
        border_radius = 4,
        align         = .BOTTOM_LEFT,
    }
    if (draw_button(&button_con, "Revert", button_style, .ACTIVE)) {
        zephr_ctx.ui.popup_open = false
        zephr_ctx.ui.popup_parent_hash = 0
    }

    button_style.align = .BOTTOM_RIGHT
    button_style.fg_color = determine_color_contrast(selected_color)
    set_x_constraint(&button_con, -0.04, .RELATIVE)
    set_y_constraint(&button_con, -0.05, .RELATIVE)
    button_style.bg_color = selected_color
    if (draw_button(&button_con, "Apply", button_style, .ACTIVE)) {
        zephr_ctx.ui.popup_revert_color^ = selected_color
        zephr_ctx.ui.popup_open = false
        zephr_ctx.ui.popup_parent_hash = 0
    }

    zephr_ctx.ui.popup_rect = rect
}

draw_color_picker :: proc(
    constraints: ^UiConstraints,
    color: ^Color,
    align: Alignment,
    state: ButtonState,
    id: u32 = 0,
    caller := #caller_location,
) {
    line := caller.line
    line_bytes := mem.byte_slice(&line, size_of(line))
    id := id
    id_bytes := mem.byte_slice(&id, size_of(id))
    hash := fnv_hash(id_bytes, size_of(id), FNV_HASH32_INIT)
    hash = fnv_hash(transmute([]byte)caller.file_path, cast(u64)len(caller.file_path), hash)
    hash = fnv_hash(line_bytes, size_of(line), hash)

    rect: Rect = ---
    display_color := color^

    con := constraints^

    apply_constraints(&con, &rect.pos, &rect.size)
    apply_alignment(align, &con, rect.size, &rect.pos)

    is_held := zephr_ctx.ui.active_element == hash
    is_hovered := zephr_ctx.ui.hovered_element == hash
    left_mouse_pressed := .LEFT in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
    left_mouse_released := .LEFT in zephr_ctx.virt_mouse.button_has_been_released_bitset
    clicked := false

    if (zephr_ctx.ui.active_element == 0) {
        if (is_hovered && left_mouse_pressed) {
            zephr_ctx.ui.active_element = hash
        }
    } else if (zephr_ctx.ui.active_element == hash) {
        if (left_mouse_released) {
            zephr_ctx.ui.active_element = 0

            if (is_hovered) {
                clicked = true
            }
        }
    }

    if (is_hovered && state == .ACTIVE) {
        set_cursor(.HAND)
        con.scale.y *= 1.08
        con.scale.x *= 1.08

        if (is_held) {
            display_color = mult_color(display_color, 0.8)
        } else {
            display_color = mult_color(display_color, 0.9)
        }
    } else if (state == .DISABLED) {
        if (is_hovered) {
            set_cursor(.DISABLED)
        }

        display_color.a = 100
    }

    style := UiStyle {
        bg_color      = display_color,
        border_radius = con.width * 0.08,
        align         = align,
    }
    draw_quad(&con, style)

    if (clicked && state == .ACTIVE) {
        zephr_ctx.ui.popup_open = true
        zephr_ctx.ui.popup_parent_constraints = con
        zephr_ctx.ui.popup_revert_color = color
        zephr_ctx.ui.popup_parent_hash = hash
    }

    if (zephr_ctx.ui.popup_parent_hash == hash) {
        zephr_ctx.ui.popup_open = true
        zephr_ctx.ui.popup_parent_constraints = con
    }

    element := UiElement {
        rect = rect,
        id   = hash,
    }

    append(&zephr_ctx.ui.elements, element)
}

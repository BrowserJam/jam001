package zephr

import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:math/bits"
import "core:math"
import "core:strings"

import gl "vendor:OpenGL"

import FT "3rdparty/freetype"

Glyph :: [6]Character

#assert(size_of(Character) == 52)
Character :: struct {
    size:       m.vec2,
    bearing:    m.vec2,
    advance:    u32,
    tex_coords: [4]m.vec2,
}

Font :: struct {
    atlas_tex_id: TextureId,
    glyphs:   [128]Glyph,
}

// GlyphInstance needs to be 128 bytes (meaning no padding) otherwise the data we send to the shader
// is misaligned and we get rendering errors
#assert(size_of(GlyphInstance) == 128)

GlyphInstance :: struct #packed {
    pos:            m.vec4,
    tex_coords: [4]m.vec2,
    color:          m.vec4,
    model:          m.mat4,
}

GlyphInstanceList :: [dynamic]GlyphInstance

@(private)
FONT_PIXEL_SIZES := [?]u8 {
    100,
    64,
    32,
    20,
    16,
    11,
}

@(private)
LINE_HEIGHT :: 2.0
@(private)
LINE_HEIGHT_PERCENT :: 0.36

@(private)
font_shader: ^Shader
@(private)
font_vao: u32
@(private)
font_instance_vbo: u32

// sets the variable font to be bold
/* if ((face->face_flags & FT_FACE_FLAG_MULTIPLE_MASTERS)) { */
/*   printf("[INFO] Got a variable font\n"); */
/*   FT_MM_Var *mm; */
/*   FT_Get_MM_Var(face, &mm); */

/*   FT_Set_Var_Design_Coordinates(face, mm->num_namedstyles, mm->namedstyle[mm->num_namedstyles - 4].coords); */

/*   FT_Done_MM_Var(ft, mm); */
/* } */

init_freetype :: proc(font_path: cstring) -> i32 {
    context.logger = logger

    ft: FT.Library
    if (FT.Init_FreeType(&ft) != 0) {
        return -1
    }

    face: FT.Face
    err := FT.New_Face(ft, font_path, 0, &face)
    if (err != 0) {
        log.errorf("FT.New_Face returned: %d", err)
        return -2
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    pen_x, pen_y: u32

    /* FT_UInt glyph_idx; */
    /* FT_ULong c = FT_Get_First_Char(face, &glyph_idx); */

    tex_width, tex_height: u32
    for i in 32 ..< 128 {
        height_of_different_glyph_sizes: u32 = 0

        for pixel_size, s in FONT_PIXEL_SIZES {
            FT.Set_Pixel_Sizes(face, 0, cast(u32)pixel_size)

            if (FT.Load_Char(face, cast(FT.ULong)i, .RENDER | .FORCE_AUTOHINT) != 0) {
                log.errorf("Failed to load glyph for char '0x%x'", i)
            }

            //FT.Render_Glyph(face.glyph, .SDF)

            // Only set the width for the biggest pixel size which is the first one in the array
            if s == 0 {
                tex_width += face.glyph.bitmap.width + 1
            }
            height_of_different_glyph_sizes += face.glyph.bitmap.rows
        }

        tex_height = max(tex_height, height_of_different_glyph_sizes)
    }

    pixels := make([dynamic]u8, tex_width * tex_height * 2)
    defer delete(pixels)

    for i in 32 ..< 128 {
        max_pen_x_for_glyph: u32 = 0
        glyph: Glyph

        for pixel_size, s in FONT_PIXEL_SIZES {
            FT.Set_Pixel_Sizes(face, 0, cast(u32)pixel_size)

            /* while (glyph_idx) { */
            if (FT.Load_Char(face, cast(FT.ULong)i, .RENDER | .FORCE_AUTOHINT) != 0) {
                log.errorf("Failed to load glyph for char '0x%x'", i)
            }

            //FT.Render_Glyph(face.glyph, .SDF)

            bmp := &face.glyph.bitmap

            //if (pen_x + bmp.width >= tex_width) {
            //    pen_x = 0
            //    pen_y += cast(u32)(1 + (face.size.metrics.height >> 6))
            //}

            for row in 0 ..< bmp.rows {
                for col in 0 ..< bmp.width {
                    x := pen_x + col
                    y := pen_y + row
                    pixels[y * tex_width + x] = bmp.buffer[row * cast(u32)bmp.pitch + col]
                }
            }

            atlas_x0 := cast(f32)pen_x / cast(f32)tex_width
            atlas_y0 := cast(f32)pen_y / cast(f32)tex_height
            atlas_x1 := cast(f32)(pen_x + bmp.width) / cast(f32)tex_width
            atlas_y1 := cast(f32)(pen_y + bmp.rows) / cast(f32)tex_height

            top_left := m.vec2{atlas_x0, atlas_y1}
            top_right := m.vec2{atlas_x1, atlas_y1}
            bottom_right := m.vec2{atlas_x1, atlas_y0}
            bottom_left := m.vec2{atlas_x0, atlas_y0}


            glyph[s].tex_coords[0] = top_left
            glyph[s].tex_coords[1] = top_right
            glyph[s].tex_coords[2] = bottom_right
            glyph[s].tex_coords[3] = bottom_left
            glyph[s].advance = cast(u32)face.glyph.advance.x
            glyph[s].size = m.vec2{cast(f32)face.glyph.bitmap.width, cast(f32)face.glyph.bitmap.rows}
            glyph[s].bearing = m.vec2{cast(f32)face.glyph.bitmap_left, cast(f32)face.glyph.bitmap_top}

            //character.tex_coords[0] = top_left
            //character.tex_coords[1] = top_right
            //character.tex_coords[2] = bottom_right
            //character.tex_coords[3] = bottom_left
            //character.advance = cast(u32)face.glyph.advance.x
            //character.size = m.vec2{cast(f32)face.glyph.bitmap.width, cast(f32)face.glyph.bitmap.rows}
            //character.bearing = m.vec2{cast(f32)face.glyph.bitmap_left, cast(f32)face.glyph.bitmap_top}


            max_pen_x_for_glyph = max(max_pen_x_for_glyph, bmp.width + 1)
            pen_y += bmp.rows + 1

            // When adding support for unicode, don't actually loop over every single glyph in the font,
            // instead have a range of glyphs that we want to support and only add those.
            /* c = FT_Get_Next_Char(face, c, &glyph_idx); */
        }

        zephr_ctx.font.glyphs[i] = glyph

        pen_x += max_pen_x_for_glyph
        pen_y = 0
    }

    texture: TextureId
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.R8,
        cast(i32)tex_width,
        cast(i32)tex_height,
        0,
        gl.RED,
        gl.UNSIGNED_BYTE,
        raw_data(pixels),
    )

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    zephr_ctx.font.atlas_tex_id = texture

    gl.BindTexture(gl.TEXTURE_2D, 0)

    FT.Done_Face(face)
    FT.Done_FreeType(ft)

    return 0
}

init_fonts :: proc(font_path: string) -> i32 {
    context.logger = logger
    font_vbo, font_ebo: u32

    font_path_c_str := strings.clone_to_cstring(font_path, context.temp_allocator)
    res := init_freetype(font_path_c_str)
    if (res != 0) {
        return res
    }

    l_font_shader, success := create_shader(create_resource_path("shaders/font.vert"), create_resource_path("shaders/font.frag"))

    if (!success) {
        log.fatal("Failed to create font shader")
        return -2
    }

    font_shader = l_font_shader

    gl.GenVertexArrays(1, &font_vao)
    gl.GenBuffers(1, &font_vbo)
    gl.GenBuffers(1, &font_instance_vbo)
    gl.GenBuffers(1, &font_ebo)

    quad_vertices := [4][2]f32 {
        {0.0, 1.0}, // top left
        {1.0, 1.0}, // top right
        {1.0, 0.0}, // bottom right
        {0.0, 0.0}, // bottom left
    }

    quad_indices := [6]u32{0, 1, 2, 2, 3, 0}

    gl.BindVertexArray(font_vao)

    // font quad vbo
    gl.BindBuffer(gl.ARRAY_BUFFER, font_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(quad_vertices), &quad_vertices, gl.STATIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), 0)

    // font instance vbo
    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), 0)
    gl.VertexAttribDivisor(1, 1)

    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4))
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 2)
    gl.VertexAttribDivisor(2, 1)
    gl.VertexAttribDivisor(3, 1)

    gl.EnableVertexAttribArray(4)
    gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 3)
    gl.VertexAttribDivisor(4, 1)

    gl.EnableVertexAttribArray(5)
    gl.EnableVertexAttribArray(6)
    gl.EnableVertexAttribArray(7)
    gl.EnableVertexAttribArray(8)
    gl.VertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 4)
    gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 5)
    gl.VertexAttribPointer(7, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 6)
    gl.VertexAttribPointer(8, 4, gl.FLOAT, gl.FALSE, size_of(GlyphInstance), size_of(m.vec4) * 7)
    gl.VertexAttribDivisor(5, 1)
    gl.VertexAttribDivisor(6, 1)
    gl.VertexAttribDivisor(7, 1)
    gl.VertexAttribDivisor(8, 1)

    // font ebo
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, font_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(quad_indices), &quad_indices, gl.STATIC_DRAW)

    use_shader(font_shader)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    return 0
}

calculate_text_size :: proc(text: string, font_size: u32) -> m.vec2 {
    closest := get_closest_font_size(font_size)
    scale := cast(f32)font_size / cast(f32)FONT_PIXEL_SIZES[closest]
    size: m.vec2 = ---
    w: f32 = 0
    h: f32 = 0
    max_bearing_h: f32 = 0
    w_of_last_line: f32 = 0
    max_w: f32 = 0


    // NOTE: I don't like looping through the characters twice, but it's fine for now
    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.glyphs[text[i]][closest]
        max_bearing_h = max(max_bearing_h, ch.bearing.y)
    }

    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.glyphs[text[i]][closest]
        w += cast(f32)ch.advance / 64

        // remove bearing of first character
        if (i == 0 && len(text) > 1) {
            w -= ch.bearing.x
        }

        // remove the trailing width of the last character
        if (i == len(text) - 1) {
            w -= ((cast(f32)ch.advance / 64) - (ch.bearing.x + ch.size.x))
        }

        // if we only have one character in the text, then remove the bearing width
        if (len(text) == 1) {
            w -= (ch.bearing.x)
        }

        h = max(h, max_bearing_h - ch.bearing.y + ch.size.y)

        if (text[i] == '\n') {
            w_of_last_line = w
            w = 0
            h += max_bearing_h + ((LINE_HEIGHT_PERCENT * cast(f32)FONT_PIXEL_SIZES[closest]) * LINE_HEIGHT)
        }
    }

    max_w = max(w, w_of_last_line)

    size.x = max_w * scale
    size.y = h * scale

    return size
}

draw_text :: proc(text: string, font_size: u32, constraints: UiConstraints, color: Color, alignment: Alignment) {
    glyph_instance_list := get_glyph_instance_list_from_text(text, font_size, constraints, color, alignment)
    defer delete(glyph_instance_list)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, zephr_ctx.font.atlas_tex_id)
    gl.BindVertexArray(font_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(GlyphInstance) * len(glyph_instance_list),
        raw_data(glyph_instance_list),
        gl.DYNAMIC_DRAW,
    )

    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(glyph_instance_list))

    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
}

draw_text_batch :: proc(batch: ^GlyphInstanceList) {
    defer delete(batch^)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, zephr_ctx.font.atlas_tex_id)
    gl.BindVertexArray(font_vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, font_instance_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(GlyphInstance) * len(batch), raw_data(batch^), gl.DYNAMIC_DRAW)

    gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, cast(i32)len(batch))

    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
}

@(private = "file")
get_closest_font_size :: proc(font_size: u32) -> u8 {
    diff: i32 = bits.I32_MAX
    closest_idx: u8 = 0

    #reverse for pixel_size, i in FONT_PIXEL_SIZES {
        cur_diff := math.abs(cast(i32)pixel_size - cast(i32)font_size)
        if cur_diff < diff {
            diff = cur_diff
            closest_idx = cast(u8)i
        }
    }

    return closest_idx
}

get_glyph_instance_list_from_text :: proc(
    text: string,
    font_size: u32,
    constraints: UiConstraints,
    color: Color,
    alignment: Alignment,
) -> GlyphInstanceList {
    constraints := constraints
    use_shader(font_shader)
    text_color := m.vec4 {
        cast(f32)color.r / 255,
        cast(f32)color.g / 255,
        cast(f32)color.b / 255,
        cast(f32)color.a / 255,
    }

    set_mat4f(font_shader, "projection", zephr_ctx.projection)

    rect: Rect

    apply_constraints(&constraints, &rect.pos, &rect.size)

    closest_font_size := get_closest_font_size(font_size)

    text_size := calculate_text_size(text, cast(u32)FONT_PIXEL_SIZES[closest_font_size])
    font_scale := cast(f32)font_size / cast(f32)FONT_PIXEL_SIZES[closest_font_size] * rect.size.x

    apply_alignment(alignment, &constraints, m.vec2{text_size.x * font_scale, text_size.y * font_scale}, &rect.pos)

    model := m.identity(m.mat4)
    model = m.mat4Scale(m.vec3{font_scale, font_scale, 1}) * model

    model = m.mat4Translate(m.vec3{-text_size.x * font_scale / 2, -text_size.y * font_scale / 2, 0}) * model
    model = m.mat4Scale(m.vec3{constraints.scale.x, constraints.scale.y, 1}) * model
    model = m.mat4Translate(m.vec3{text_size.x * font_scale / 2, text_size.y * font_scale / 2, 0}) * model

    // rotate around the center point of the text
    model = m.mat4Translate(m.vec3{-text_size.x * font_scale / 2, -text_size.y * font_scale / 2, 0}) * model
    model = m.mat4Rotate(m.vec3{0, 0, 1}, m.radians(constraints.rotation)) * model
    model = m.mat4Translate(m.vec3{text_size.x * font_scale / 2, text_size.y * font_scale / 2, 0}) * model

    model = m.mat4Translate(m.vec3{rect.pos.x, rect.pos.y, 0}) * model

    max_bearing_h: f32 = 0
    for i in 0 ..< len(text) {
        ch := zephr_ctx.font.glyphs[text[i]][closest_font_size]
        max_bearing_h = max(max_bearing_h, ch.bearing.y)
    }

    first_char_bearing_w := zephr_ctx.font.glyphs[text[0]][closest_font_size].bearing.x

    glyph_instance_list: GlyphInstanceList
    reserve(&glyph_instance_list, 16)

    // we use the original text and character sizes in the loop and then we just
    // scale up or down the model matrix to get the desired font size.
    // this way everything works out fine and we get to transform the text using the
    // model matrix
    c := 0
    x: u32 = 0
    y: f32 = 0
    for c != len(text) {
        ch := zephr_ctx.font.glyphs[text[c]][closest_font_size]
        // subtract the bearing width of the first character to remove the extra space
        // at the start of the text and move every char to the left by that width
        xpos := (cast(f32)x + (ch.bearing.x - first_char_bearing_w))
        ypos := y + (text_size.y - ch.bearing.y - (text_size.y - max_bearing_h))

        if (text[c] == '\n') {
            x = 0
            y += max_bearing_h + ((LINE_HEIGHT_PERCENT * cast(f32)FONT_PIXEL_SIZES[closest_font_size]) * LINE_HEIGHT)
            c += 1
            continue
        }

        instance := GlyphInstance {
            pos            = m.vec4{xpos, ypos, ch.size.x, ch.size.y},
            tex_coords     = ch.tex_coords,
            color          = text_color,
            model          = model,
        }

        append(&glyph_instance_list, instance)

        x += (ch.advance >> 6)
        c += 1
    }

    return glyph_instance_list
}

add_text_instance :: proc(
    batch: ^GlyphInstanceList,
    text: string,
    font_size: u32,
    constraints: UiConstraints,
    color: Color,
    alignment: Alignment,
) {
    glyph_instance_list := get_glyph_instance_list_from_text(text, font_size, constraints, color, alignment)
    defer delete(glyph_instance_list)

    append(batch, ..glyph_instance_list[:])
}

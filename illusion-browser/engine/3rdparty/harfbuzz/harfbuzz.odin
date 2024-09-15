package harfbuzz

import "core:c"

import FT "../freetype"

// Harfbuzz version 8.4.0
when ODIN_OS == .Linux {foreign import harfbuzz "libs/libharfbuzz.a"}
when ODIN_OS == .Windows {foreign import harfbuzz "libs/harfbuzz.lib"}

@(link_prefix = "hb_")
foreign harfbuzz {
    buffer_create :: proc() -> hb_buffer_t ---
    buffer_reset :: proc(buffer: hb_buffer_t) ---
    buffer_add_utf8 :: proc(buffer: hb_buffer_t, text: cstring, text_length: c.int, item_offset: c.uint, item_length: c.int) ---
    buffer_set_direction :: proc(buffer: hb_buffer_t, direction: direction_t) ---
    buffer_set_script :: proc(buffer: hb_buffer_t, script: hb_script_t) ---
    buffer_set_language :: proc(buffer: hb_buffer_t, language: hb_language_t) ---
    buffer_guess_segment_properties :: proc(buffer: hb_buffer_t) ---
    buffer_get_glyph_infos :: proc(buffer: hb_buffer_t, length: ^c.uint) -> [^]hb_glyph_info_t ---
    buffer_get_glyph_positions :: proc(buffer: hb_buffer_t, length: ^c.uint) -> [^]glyph_position_t ---
    buffer_get_length :: proc(buffer: hb_buffer_t) -> c.uint ---
    buffer_destroy :: proc(buffer: hb_buffer_t) ---

    blob_create_from_file :: proc(file_name: cstring) -> hb_blob_t ---
    blob_create_from_file_or_fail :: proc(file_name: cstring) -> hb_blob_t ---
    blob_destroy :: proc(blob: hb_blob_t) ---

    face_create :: proc(blob: hb_blob_t, index: c.uint) -> hb_face_t ---
    face_destroy :: proc(face: hb_face_t) ---

    font_create :: proc(face: hb_face_t) -> font_t ---
    font_destroy :: proc(font: font_t) ---

    shape :: proc(font: font_t, buffer: hb_buffer_t, features: [^]hb_feature_t, num_features: c.uint) ---

    ft_font_create :: proc(ft_face: FT.Face, destroy: hb_destroy_func_t) -> font_t ---
    ft_font_create_referenced :: proc(ft_face: FT.Face) -> font_t ---
}

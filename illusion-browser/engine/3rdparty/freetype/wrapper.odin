// based on system packaged freetype 2.11.1 on Ubuntu 22.04
// @INCOMPLETE
package freetype

when ODIN_OS == .Linux {foreign import freetype "system:freetype"}
when ODIN_OS == .Windows {foreign import freetype "libs/freetype.lib"}

@(link_prefix = "FT_")
foreign freetype {
    Init_FreeType :: proc(lib: ^Library) -> FT_Error ---
    New_Face :: proc(lib: Library, file_pathname: cstring, face_index: FT_Long, face: ^Face) -> FT_Error ---
    New_Memory_Face :: proc(lib: Library, file_base: [^]FT_Byte, file_size: FT_Long, face_index: FT_Long, face: ^Face) -> FT_Error ---
    Set_Pixel_Sizes :: proc(face: Face, pixel_width: UInt, pixel_height: UInt) -> FT_Error ---
    Set_Charmap :: proc(face: Face, charmap: FT_CharMap) -> FT_Error ---
    Select_Charmap :: proc(face: Face, encoding: FT_Encoding) -> FT_Error ---
    Get_First_Char :: proc(face: Face, agindex: ^UInt) -> ULong ---
    Get_Next_Char :: proc(face: Face, char_code: ULong, agindex: ^UInt) -> ULong ---
    Get_Char_Index :: proc(face: Face, char_code: ULong) -> UInt ---
    Set_Char_Size :: proc(face: Face,
                      char_width: FT_F26Dot6,
                      char_height: FT_F26Dot6,
                      horz_resolution: UInt,
                      vert_resolution: UInt) -> FT_Error ---
    Load_Char :: proc(face: Face, char_code: ULong, load_flags: LoadFlags) -> FT_Error ---
    Render_Glyph :: proc(slot: FT_GlyphSlot, render_mode: FT_Render_Mode_) -> FT_Error ---
    Done_Face :: proc(face: Face) -> FT_Error ---
    Done_FreeType :: proc(lib: Library) -> FT_Error ---
}

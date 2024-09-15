// based on system packaged freetype 2.11.1 on Ubuntu 22.04
// @INCOMPLETE

package freetype

import "core:c"

// TODO: make an error enum
// https://freetype.org/freetype2/docs/reference/ft2-error_code_values.html

FT_Error :: c.int
@(private)
FT_Byte :: c.uchar
@(private)
FT_Short :: c.short
@(private)
FT_UShort :: c.ushort
@(private)
FT_Int :: c.int
UInt :: c.uint
@(private)
FT_Long :: c.long
ULong :: c.ulong
@(private)
FT_String :: c.char
@(private)
FT_UInt32 :: c.uint
@(private)
FT_F26Dot6 :: c.long

@(private)
FT_Pos :: c.long
@(private)
FT_Fixed :: c.long
@(private)
FT_SubGlyph :: rawptr // internal object
@(private)
FT_Slot_Internal :: rawptr // opaque handle to internal slot structure
@(private)
FT_Size_Internal :: rawptr // opaque handle to internal size structure
@(private)
FT_Driver :: rawptr // a handle to a given FreeType font driver object
@(private)
FT_Memory :: rawptr // a handle to a given memory manager object
@(private)
FT_Face_Internal :: rawptr

Library :: rawptr // handle to a library object

@(private)
FT_Render_Mode_ :: enum {
    NORMAL = 0,
    LIGHT,
    MONO,
    LCD,
    LCD_V,
    SDF,
    MAX,
}

LoadFlags :: enum {
    DEFAULT                     = 0x0,
    NO_SCALE                    = 1 << 0,
    NO_HINTING                  = 1 << 1,
    RENDER                      = 1 << 2,
    NO_BITMAP                   = 1 << 3,
    VERTICAL_LAYOUT             = 1 << 4,
    FORCE_AUTOHINT              = 1 << 5,
    CROP_BITMAP                 = 1 << 6,
    PEDANTIC                    = 1 << 7,
    IGNORE_GLOBAL_ADVANCE_WIDTH = 1 << 9,
    NO_RECURSE                  = 1 << 10,
    IGNORE_TRANSFORM            = 1 << 11,
    MONOCHROME                  = 1 << 12,
    LINEAR_DESIGN               = 1 << 13,
    NO_AUTOHINT                 = 1 << 15,
    // Bits 16-19 are used by `FT_LOAD_TARGET_`
    COLOR                       = 1 << 20,
    COMPUTE_METRICS             = 1 << 21,
    BITMAP_METRICS_ONLY         = 1 << 22,

    /* used internally only by certain font drivers */
    ADVANCE_ONLY                = 1 << 8,
    SBITS_ONLY                  = 1 << 14,
    FT_LOAD_TARGET_NORMAL       = (int(FT_Render_Mode_.NORMAL) & 15) << 16,
    FT_LOAD_TARGET_LIGHT        = (int(FT_Render_Mode_.LIGHT) & 15) << 16,
    FT_LOAD_TARGET_MONO         = (int(FT_Render_Mode_.MONO) & 15) << 16,
    FT_LOAD_TARGET_LCD          = (int(FT_Render_Mode_.LCD) & 15) << 16,
    FT_LOAD_TARGET_LCD_V        = (int(FT_Render_Mode_.LCD_V) & 15) << 16,
}

FaceFlags :: bit_set[FaceFlagsBits;FT_Long]

@(private)
FaceFlagsBits :: enum FT_Long {
    SCALABLE          =  0,
    FIXED_SIZES       =  1,
    FIXED_WIDTH       =  2,
    SFNT              =  3,
    HORIZONTAL        =  4,
    VERTICAL          =  5,
    KERNING           =  6,
    FAST_GLYPHS       =  7,
    MULTIPLE_MASTERS  =  8,
    GLYPH_NAMES       =  9,
    EXTERNAL_STREAM   = 10,
    HINTER            = 11,
    CID_KEYED         = 12,
    TRICKY            = 13,
    COLOR             = 14,
    VARIATION         = 15,
}

#assert(size_of(OutlineFlags) == 8)

@(private)
OutlineFlags :: enum {
    NONE            = 0x0,
    OWNER           = 0x1,
    EVEN_ODD_FILL   = 0x2,
    REVERSE_FILL    = 0x4,
    IGNORE_DROPOUTS = 0x8,
    SMART_DROPOUTS  = 0x10,
    INCLUDE_STUBS   = 0x20,
    OVERLAP         = 0x40,
    HIGH_PRECISION  = 0x100,
    SINGLE_PASS     = 0x200,
}

@(private)
FT_Encoding :: enum u32 {
    NONE           = 0,
    MS_SYMBOL      = ('s' << 24) | ('y' << 16) | ('m' << 8) | 'b',
    UNICODE        = ('u' << 24) | ('n' << 16) | ('i' << 8) | 'c',
    SJIS           = ('s' << 24) | ('j' << 16) | ('i' << 8) | 's',
    PRC            = ('g' << 24) | ('b' << 16) | (' ' << 8) | ' ',
    BIG5           = ('b' << 24) | ('i' << 16) | ('g' << 8) | '5',
    WANSUNG        = ('w' << 24) | ('a' << 16) | ('n' << 8) | 's',
    JOHAB          = ('j' << 24) | ('o' << 16) | ('h' << 8) | 'a',

    /* for backward compatibility */
    GB2312         = PRC,
    MS_SJIS        = SJIS,
    MS_GB2312      = PRC,
    MS_BIG5        = BIG5,
    MS_WANSUNG     = WANSUNG,
    MS_JOHAB       = JOHAB,
    ADOBE_STANDARD = ('A' << 24) | ('D' << 16) | ('O' << 8) | 'B',
    ADOBE_EXPERT   = ('A' << 24) | ('D' << 16) | ('B' << 8) | 'E',
    ADOBE_CUSTOM   = ('A' << 24) | ('D' << 16) | ('B' << 8) | 'C',
    ADOBE_LATIN_1  = ('l' << 24) | ('a' << 16) | ('t' << 8) | '1',
    OLD_LATIN_2    = ('l' << 24) | ('a' << 16) | ('t' << 8) | '2',
    APPLE_ROMAN    = ('a' << 24) | ('r' << 16) | ('m' << 8) | 'n',
}

@(private)
Platform :: enum FT_UShort {
    APPLE_UNICODE = 0,
    MACINTOSH = 1,
    ISO = 2, // Deprecated
    MICROSOFT = 3,
    CUSTOM = 4,
    ADOBE = 7, // Artificial
}

#assert(size_of(FT_CharMapRec_) == 16)

@(private)
FT_CharMapRec_ :: struct {
    face:        Face,
    encoding:    FT_Encoding,
    platform_id: Platform,
    encoding_id: FT_UShort,
}

@(private)
FT_CharMap :: ^FT_CharMapRec_

#assert(size_of(FT_Bitmap_Size) == (16 when (ODIN_OS == .Windows) else 32))

@(private)
FT_Bitmap_Size :: struct {
    height: FT_Short,
    width:  FT_Short,
    size:   FT_Pos,
    x_ppem: FT_Pos,
    y_ppem: FT_Pos,
}

#assert(size_of(FT_Generic) == 16)

@(private)
FT_Generic :: struct {
    data:      rawptr,
    finalizer: ^proc(object: rawptr),
}

#assert(size_of(FT_BBox) == (16 when (ODIN_OS == .Windows) else 32))

@(private)
FT_BBox :: struct {
    xMin, yMin: FT_Pos,
    xMax, yMax: FT_Pos,
}

#assert(size_of(FT_Vector) == (8 when (ODIN_OS == .Windows) else 16))

@(private)
FT_Vector :: struct {
    x, y: FT_Pos,
}

#assert(size_of(FT_Glyph_Metrics) == (32 when (ODIN_OS == .Windows) else 64))

@(private)
FT_Glyph_Metrics :: struct {
    width:        FT_Pos,
    height:       FT_Pos,
    horiBearingX: FT_Pos,
    horiBearingY: FT_Pos,
    horiAdvance:  FT_Pos,
    vertBearingX: FT_Pos,
    vertBearingY: FT_Pos,
    vertAdvance:  FT_Pos,
}

#assert(size_of(FT_Outline) == 40)

@(private)
FT_Outline :: struct {
    n_contours: i16,
    n_points:   i16,
    points:     ^FT_Vector,
    tags:       ^i8,
    contours:   ^i16,
    flags:      OutlineFlags,
}

#assert(size_of(FT_Glyph_Format) == 8)

@(private)
FT_Glyph_Format :: enum {
    NONE      = (0 << 24) | (0 << 16) | (0 << 8) | 0,
    COMPOSITE = ('c' << 24) | ('o' << 16) | ('m' << 8) | 'p',
    BITMAP    = ('b' << 24) | ('i' << 16) | ('t' << 8) | 's',
    OUTLINE   = ('o' << 24) | ('u' << 16) | ('t' << 8) | 'l',
    PLOTTER   = ('p' << 24) | ('l' << 16) | ('o' << 8) | 't',
}

// linux: 304
// windows: 248
// windows: 236 packed
#assert(size_of(FT_GlyphSlotRec_) == (248 when (ODIN_OS == .Windows) else 304))

FT_GlyphSlotRec_ :: struct {
    library:           Library,
    face:              Face,
    next:              FT_GlyphSlot,
    glyph_index:       UInt, /* new in 2.10; was reserved previously */
    generic:           FT_Generic,
    metrics:           FT_Glyph_Metrics,
    linearHoriAdvance: FT_Fixed,
    linearVertAdvance: FT_Fixed,
    advance:           FT_Vector,
    format:            FT_Glyph_Format,
    bitmap:            Bitmap,
    bitmap_left:       FT_Int,
    bitmap_top:        FT_Int,
    outline:           FT_Outline,
    num_subglyphs:     UInt,
    subglyphs:         FT_SubGlyph,
    control_data:      rawptr,
    control_len:       c.long,
    lsb_delta:         FT_Pos,
    rsb_delta:         FT_Pos,
    other:             rawptr,
    internal:          FT_Slot_Internal,
}

@(private)
FT_GlyphSlot :: ^FT_GlyphSlotRec_

#assert(size_of(FT_Size_Metrics) == (28 when (ODIN_OS == .Windows) else 56))

@(private)
FT_Size_Metrics :: struct {
    x_ppem:      FT_UShort, /* horizontal pixels per EM               */
    y_ppem:      FT_UShort, /* vertical pixels per EM                 */
    x_scale:     FT_Fixed, /* scaling values used to convert font    */
    y_scale:     FT_Fixed, /* units to 26.6 fractional pixels        */
    ascender:    FT_Pos, /* ascender in 26.6 frac. pixels          */
    descender:   FT_Pos, /* descender in 26.6 frac. pixels         */
    height:      FT_Pos, /* text height in 26.6 frac. pixels       */
    max_advance: FT_Pos, /* max horizontal advance, in 26.6 pixels */
}

// linux: 88
// windows: 64 (has 4 bytes padding)
// windows: 60 packed
#assert(size_of(FT_SizeRec) == (64 when (ODIN_OS == .Windows) else 88))

@(private)
FT_SizeRec :: struct {
    face:     Face,
    generic:  FT_Generic,
    metrics:  FT_Size_Metrics,
    internal: FT_Size_Internal,
}

@(private)
FT_Size :: ^FT_SizeRec

#assert(size_of(FT_StreamDesc) == 8)

@(private)
FT_StreamDesc :: struct #raw_union {
    value:   i64,
    pointer: rawptr,
}

@(private)
FT_Stream_IoFunc :: #type ^proc(stream: FT_Stream, offset: u64, buffer: [^]u8, count: u64) -> u64
@(private)
FT_Stream_CloseFunc :: #type ^proc(stream: FT_Stream)

#assert(size_of(FT_StreamRec_) == 80)

@(private)
FT_StreamRec_ :: struct {
    base:       [^]u8,
    size:       u64,
    pos:        u64,
    descriptor: FT_StreamDesc,
    pathname:   FT_StreamDesc,
    read:       FT_Stream_IoFunc,
    close:      FT_Stream_CloseFunc,
    memory:     FT_Memory,
    cursor:     [^]u8,
    limit:      [^]u8,
}

@(private)
FT_Stream :: ^FT_StreamRec_

#assert(size_of(FT_ListNodeRec_) == 24)

@(private)
FT_ListNodeRec_ :: struct {
    prev: FT_ListNode,
    next: FT_ListNode,
    data: rawptr,
}

@(private)
FT_ListNode :: ^FT_ListNodeRec_

#assert(size_of(FT_ListRec) == 16)

@(private)
FT_ListRec :: struct {
    head: FT_ListNode,
    tail: FT_ListNode,
}

// linux: 248
// windows: 216
// windows packed: 204
#assert(size_of(FT_FaceRec_) == (216 when (ODIN_OS == .Windows) else 248))

@(private)
FT_FaceRec_ :: struct {
    num_faces:           FT_Long,
    face_index:          FT_Long,
    face_flags:          FaceFlags,
    style_flags:         FT_Long,
    num_glyphs:          FT_Long,
    family_name:         ^FT_String,
    style_name:          ^FT_String,
    num_fixed_sizes:     FT_Int,
    available_sizes:     ^FT_Bitmap_Size,
    num_charmaps:        FT_Int,
    charmaps:            [^]FT_CharMap,
    generic:             FT_Generic,

    /*# The following member variables (down to `underline_thickness`) */
    /*# are only relevant to scalable outlines; cf. @FT_Bitmap_Size    */
    /*# for bitmap fonts.                                              */
    bbox:                FT_BBox,
    units_per_EM:        FT_UShort,
    ascender:            FT_Short,
    descender:           FT_Short,
    height:              FT_Short,
    max_advance_width:   FT_Short,
    max_advance_height:  FT_Short,
    underline_position:  FT_Short,
    underline_thickness: FT_Short,
    glyph:               FT_GlyphSlot,
    size:                FT_Size,
    charmap:             FT_CharMap,

    /*@private begin */
    driver:              FT_Driver,
    memory:              FT_Memory,
    stream:              FT_Stream,
    sizes_list:          FT_ListRec,
    autohint:            FT_Generic, // face-specific auto-hinter data
    extensions:          rawptr, // unused
    internal:            FT_Face_Internal,

    /*@private end */
}

Face :: ^FT_FaceRec_

#assert(size_of(Bitmap) == 40)

Bitmap :: struct {
    rows:         u32,
    width:        u32,
    pitch:        i32,
    buffer:       [^]u8,
    num_grays:    u16,
    pixel_mode:   u8,
    palette_mode: u8,
    palette:      rawptr,
}

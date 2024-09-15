package harfbuzz

import "core:c"

/**
 * HB_TAG_NONE:
 *
 * Unset #hb_tag_t.
 */
@(private)
HB_TAG_NONE :: 0
/**
 * HB_TAG_MAX:
 *
 * Maximum possible unsigned #hb_tag_t.
 *
 * Since: 0.9.26
 */
@(private)
HB_TAG_MAX :: (0xFF << 24) | (0xFF << 16) | (0xFF << 8) | 0xFF
/**
 * HB_TAG_MAX_SIGNED:
 *
 * Maximum possible signed #hb_tag_t.
 *
 * Since: 0.9.33
 */
@(private)
HB_TAG_MAX_SIGNED :: (0x7F << 24) | (0xFF << 16) | (0xFF << 8) | 0xFF

@(private)
hb_destroy_func_t :: #type proc(user_data: rawptr)

@(private)
hb_tag_t :: distinct c.uint
@(private)
hb_codepoint_t :: distinct c.uint
@(private)
hb_mask_t :: distinct c.uint
@(private)
hb_position_t :: distinct c.int

font_t :: distinct rawptr
@(private)
hb_face_t :: distinct rawptr
@(private)
hb_buffer_t :: distinct rawptr
@(private)
hb_blob_t :: distinct rawptr
@(private)
hb_language_t :: distinct rawptr

@(private)
hb_var_int_t :: struct #raw_union {
    u32: c.uint,
    i32: c.int,
    u16: [2]c.ushort,
    i16: [2]c.short,
    u8: [4]c.uchar,
    i8: [4]c.char,
}

@(private)
hb_feature_t :: struct {
    tag: hb_tag_t,
    value: c.uint,
    start: c.uint,
    end: c.uint,
}

@(private)
hb_glyph_info_t :: struct  {
    codepoint: hb_codepoint_t,
    /*< private >*/
    mask: hb_mask_t,
    /*< public >*/
    cluster: c.uint,

    /*< private >*/
    var1: hb_var_int_t,
    var2: hb_var_int_t,
}

glyph_position_t :: struct {
    x_advance: hb_position_t,
    y_advance: hb_position_t,
    x_offset: hb_position_t,
    y_offset: hb_position_t,

    /*< private >*/
    var: hb_var_int_t,
}

direction_t :: enum {
  INVALID = 0,
  LTR = 4,
  RTL,
  TTB,
  BTT
}

hb_script_t :: enum hb_tag_t {
  COMMON     = ('Z' << 24) | ('y' << 16) | ('y' << 8) | 'y', /*1.1*/
  INHERITED  = ('Z' << 24) | ('i' << 16) | ('n' << 8) | 'h', /*1.1*/
  UNKNOWN    = ('Z' << 24) | ('z' << 16) | ('z' << 8) | 'z', /*5.0*/

  ARABIC     = ('A' << 24) | ('r' << 16) | ('a' << 8) | 'b', /*1.1*/
  ARMENIAN   = ('A' << 24) | ('r' << 16) | ('m' << 8) | 'n', /*1.1*/
  BENGALI    = ('B' << 24) | ('e' << 16) | ('n' << 8) | 'g', /*1.1*/
  CYRILLIC   = ('C' << 24) | ('y' << 16) | ('r' << 8) | 'l', /*1.1*/
  DEVANAGARI = ('D' << 24) | ('e' << 16) | ('v' << 8) | 'a', /*1.1*/
  GEORGIAN   = ('G' << 24) | ('e' << 16) | ('o' << 8) | 'r', /*1.1*/
  GREEK      = ('G' << 24) | ('r' << 16) | ('e' << 8) | 'k', /*1.1*/
  GUJARATI   = ('G' << 24) | ('u' << 16) | ('j' << 8) | 'r', /*1.1*/
  GURMUKHI   = ('G' << 24) | ('u' << 16) | ('r' << 8) | 'u', /*1.1*/
  HANGUL     = ('H' << 24) | ('a' << 16) | ('n' << 8) | 'g', /*1.1*/
  HAN        = ('H' << 24) | ('a' << 16) | ('n' << 8) | 'i', /*1.1*/
  HEBREW     = ('H' << 24) | ('e' << 16) | ('b' << 8) | 'r', /*1.1*/
  HIRAGANA   = ('H' << 24) | ('i' << 16) | ('r' << 8) | 'a', /*1.1*/
  KANNADA    = ('K' << 24) | ('n' << 16) | ('d' << 8) | 'a', /*1.1*/
  KATAKANA   = ('K' << 24) | ('a' << 16) | ('n' << 8) | 'a', /*1.1*/
  LAO        = ('L' << 24) | ('a' << 16) | ('o' << 8) | 'o', /*1.1*/
  LATIN      = ('L' << 24) | ('a' << 16) | ('t' << 8) | 'n', /*1.1*/
  MALAYALAM  = ('M' << 24) | ('l' << 16) | ('y' << 8) | 'm', /*1.1*/
  ORIYA      = ('O' << 24) | ('r' << 16) | ('y' << 8) | 'a', /*1.1*/
  TAMIL      = ('T' << 24) | ('a' << 16) | ('m' << 8) | 'l', /*1.1*/
  TELUGU     = ('T' << 24) | ('e' << 16) | ('l' << 8) | 'u', /*1.1*/
  THAI       = ('T' << 24) | ('h' << 16) | ('a' << 8) | 'i', /*1.1*/

  TIBETAN    = ('T' << 24) | ('i' << 16) | ('b' << 8) | 't', /*2.0*/

  BOPOMOFO           = ('B' << 24) | ('o' << 16) | ('p' << 8) | 'o', /*3.0*/
  BRAILLE            = ('B' << 24) | ('r' << 16) | ('a' << 8) | 'i', /*3.0*/
  CANADIAN_SYLLABICS = ('C' << 24) | ('a' << 16) | ('n' << 8) | 's', /*3.0*/
  CHEROKEE           = ('C' << 24) | ('h' << 16) | ('e' << 8) | 'r', /*3.0*/
  ETHIOPIC           = ('E' << 24) | ('t' << 16) | ('h' << 8) | 'i', /*3.0*/
  KHMER              = ('K' << 24) | ('h' << 16) | ('m' << 8) | 'r', /*3.0*/
  MONGOLIAN          = ('M' << 24) | ('o' << 16) | ('n' << 8) | 'g', /*3.0*/
  MYANMAR            = ('M' << 24) | ('y' << 16) | ('m' << 8) | 'r', /*3.0*/
  OGHAM              = ('O' << 24) | ('g' << 16) | ('a' << 8) | 'm', /*3.0*/
  RUNIC              = ('R' << 24) | ('u' << 16) | ('n' << 8) | 'r', /*3.0*/
  SINHALA            = ('S' << 24) | ('i' << 16) | ('n' << 8) | 'h', /*3.0*/
  SYRIAC             = ('S' << 24) | ('y' << 16) | ('r' << 8) | 'c', /*3.0*/
  THAANA             = ('T' << 24) | ('h' << 16) | ('a' << 8) | 'a', /*3.0*/
  YI                 = ('Y' << 24) | ('i' << 16) | ('i' << 8) | 'i', /*3.0*/

  DESERET    = ('D' << 24) | ('s' << 16) | ('r' << 8) | 't', /*3.1*/
  GOTHIC     = ('G' << 24) | ('o' << 16) | ('t' << 8) | 'h', /*3.1*/
  OLD_ITALIC = ('I' << 24) | ('t' << 16) | ('a' << 8) | 'l', /*3.1*/

  BUHID    = ('B' << 24) | ('u' << 16) | ('h' << 8) | 'd', /*3.2*/
  HANUNOO  = ('H' << 24) | ('a' << 16) | ('n' << 8) | 'o', /*3.2*/
  TAGALOG  = ('T' << 24) | ('g' << 16) | ('l' << 8) | 'g', /*3.2*/
  TAGBANWA = ('T' << 24) | ('a' << 16) | ('g' << 8) | 'b', /*3.2*/

  CYPRIOT  = ('C' << 24) | ('p' << 16) | ('r' << 8) | 't', /*4.0*/
  LIMBU    = ('L' << 24) | ('i' << 16) | ('m' << 8) | 'b', /*4.0*/
  LINEAR_B = ('L' << 24) | ('i' << 16) | ('n' << 8) | 'b', /*4.0*/
  OSMANYA  = ('O' << 24) | ('s' << 16) | ('m' << 8) | 'a', /*4.0*/
  SHAVIAN  = ('S' << 24) | ('h' << 16) | ('a' << 8) | 'w', /*4.0*/
  TAI_LE   = ('T' << 24) | ('a' << 16) | ('l' << 8) | 'e', /*4.0*/
  UGARITIC = ('U' << 24) | ('g' << 16) | ('a' << 8) | 'r', /*4.0*/

  BUGINESE     = ('B' << 24) | ('u' << 16) | ('g' << 8) | 'i', /*4.1*/
  COPTIC       = ('C' << 24) | ('o' << 16) | ('p' << 8) | 't', /*4.1*/
  GLAGOLITIC   = ('G' << 24) | ('l' << 16) | ('a' << 8) | 'g', /*4.1*/
  KHAROSHTHI   = ('K' << 24) | ('h' << 16) | ('a' << 8) | 'r', /*4.1*/
  NEW_TAI_LUE  = ('T' << 24) | ('a' << 16) | ('l' << 8) | 'u', /*4.1*/
  OLD_PERSIAN  = ('X' << 24) | ('p' << 16) | ('e' << 8) | 'o', /*4.1*/
  SYLOTI_NAGRI = ('S' << 24) | ('y' << 16) | ('l' << 8) | 'o', /*4.1*/
  TIFINAGH     = ('T' << 24) | ('f' << 16) | ('n' << 8) | 'g', /*4.1*/

  BALINESE   = ('B' << 24) | ('a' << 16) | ('l' << 8) | 'i', /*5.0*/
  CUNEIFORM  = ('X' << 24) | ('s' << 16) | ('u' << 8) | 'x', /*5.0*/
  NKO        = ('N' << 24) | ('k' << 16) | ('o' << 8) | 'o', /*5.0*/
  PHAGS_PA   = ('P' << 24) | ('h' << 16) | ('a' << 8) | 'g', /*5.0*/
  PHOENICIAN = ('P' << 24) | ('h' << 16) | ('n' << 8) | 'x', /*5.0*/

  CARIAN     = ('C' << 24) | ('a' << 16) | ('r' << 8) | 'i', /*5.1*/
  CHAM       = ('C' << 24) | ('h' << 16) | ('a' << 8) | 'm', /*5.1*/
  KAYAH_LI   = ('K' << 24) | ('a' << 16) | ('l' << 8) | 'i', /*5.1*/
  LEPCHA     = ('L' << 24) | ('e' << 16) | ('p' << 8) | 'c', /*5.1*/
  LYCIAN     = ('L' << 24) | ('y' << 16) | ('c' << 8) | 'i', /*5.1*/
  LYDIAN     = ('L' << 24) | ('y' << 16) | ('d' << 8) | 'i', /*5.1*/
  OL_CHIKI   = ('O' << 24) | ('l' << 16) | ('c' << 8) | 'k', /*5.1*/
  REJANG     = ('R' << 24) | ('j' << 16) | ('n' << 8) | 'g', /*5.1*/
  SAURASHTRA = ('S' << 24) | ('a' << 16) | ('u' << 8) | 'r', /*5.1*/
  SUNDANESE  = ('S' << 24) | ('u' << 16) | ('n' << 8) | 'd', /*5.1*/
  VAI        = ('V' << 24) | ('a' << 16) | ('i' << 8) | 'i', /*5.1*/

  AVESTAN                = ('A' << 24) | ('v' << 16) | ('s' << 8) | 't', /*5.2*/
  BAMUM                  = ('B' << 24) | ('a' << 16) | ('m' << 8) | 'u', /*5.2*/
  EGYPTIAN_HIEROGLYPHS   = ('E' << 24) | ('g' << 16) | ('y' << 8) | 'p', /*5.2*/
  IMPERIAL_ARAMAIC       = ('A' << 24) | ('r' << 16) | ('m' << 8) | 'i', /*5.2*/
  INSCRIPTIONAL_PAHLAVI  = ('P' << 24) | ('h' << 16) | ('l' << 8) | 'i', /*5.2*/
  INSCRIPTIONAL_PARTHIAN = ('P' << 24) | ('r' << 16) | ('t' << 8) | 'i', /*5.2*/
  JAVANESE               = ('J' << 24) | ('a' << 16) | ('v' << 8) | 'a', /*5.2*/
  KAITHI                 = ('K' << 24) | ('t' << 16) | ('h' << 8) | 'i', /*5.2*/
  LISU                   = ('L' << 24) | ('i' << 16) | ('s' << 8) | 'u', /*5.2*/
  MEETEI_MAYEK           = ('M' << 24) | ('t' << 16) | ('e' << 8) | 'i', /*5.2*/
  OLD_SOUTH_ARABIAN      = ('S' << 24) | ('a' << 16) | ('r' << 8) | 'b', /*5.2*/
  OLD_TURKIC             = ('O' << 24) | ('r' << 16) | ('k' << 8) | 'h', /*5.2*/
  SAMARITAN              = ('S' << 24) | ('a' << 16) | ('m' << 8) | 'r', /*5.2*/
  TAI_THAM               = ('L' << 24) | ('a' << 16) | ('n' << 8) | 'a', /*5.2*/
  TAI_VIET               = ('T' << 24) | ('a' << 16) | ('v' << 8) | 't', /*5.2*/

  BATAK   = ('B' << 24) | ('a' << 16) | ('t' << 8) | 'k', /*6.0*/
  BRAHMI  = ('B' << 24) | ('r' << 16) | ('a' << 8) | 'h', /*6.0*/
  MANDAIC = ('M' << 24) | ('a' << 16) | ('n' << 8) | 'd', /*6.0*/

  CHAKMA               = ('C' << 24) | ('a' << 16) | ('k' << 8) | 'm', /*6.1*/
  MEROITIC_CURSIVE     = ('M' << 24) | ('e' << 16) | ('r' << 8) | 'c', /*6.1*/
  MEROITIC_HIEROGLYPHS = ('M' << 24) | ('e' << 16) | ('r' << 8) | 'o', /*6.1*/
  MIAO                 = ('P' << 24) | ('l' << 16) | ('r' << 8) | 'd', /*6.1*/
  SHARADA              = ('S' << 24) | ('h' << 16) | ('r' << 8) | 'd', /*6.1*/
  SORA_SOMPENG         = ('S' << 24) | ('o' << 16) | ('r' << 8) | 'a', /*6.1*/
  TAKRI                = ('T' << 24) | ('a' << 16) | ('k' << 8) | 'r', /*6.1*/

  /*
   * Since: 0.9.30
   */
  BASSA_VAH          = ('B' << 24) | ('a' << 16) | ('s' << 8) | 's', /*7.0*/
  CAUCASIAN_ALBANIAN = ('A' << 24) | ('g' << 16) | ('h' << 8) | 'b', /*7.0*/
  DUPLOYAN           = ('D' << 24) | ('u' << 16) | ('p' << 8) | 'l', /*7.0*/
  ELBASAN            = ('E' << 24) | ('l' << 16) | ('b' << 8) | 'a', /*7.0*/
  GRANTHA            = ('G' << 24) | ('r' << 16) | ('a' << 8) | 'n', /*7.0*/
  KHOJKI             = ('K' << 24) | ('h' << 16) | ('o' << 8) | 'j', /*7.0*/
  KHUDAWADI          = ('S' << 24) | ('i' << 16) | ('n' << 8) | 'd', /*7.0*/
  LINEAR_A           = ('L' << 24) | ('i' << 16) | ('n' << 8) | 'a', /*7.0*/
  MAHAJANI           = ('M' << 24) | ('a' << 16) | ('h' << 8) | 'j', /*7.0*/
  MANICHAEAN         = ('M' << 24) | ('a' << 16) | ('n' << 8) | 'i', /*7.0*/
  MENDE_KIKAKUI      = ('M' << 24) | ('e' << 16) | ('n' << 8) | 'd', /*7.0*/
  MODI               = ('M' << 24) | ('o' << 16) | ('d' << 8) | 'i', /*7.0*/
  MRO                = ('M' << 24) | ('r' << 16) | ('o' << 8) | 'o', /*7.0*/
  NABATAEAN          = ('N' << 24) | ('b' << 16) | ('a' << 8) | 't', /*7.0*/
  OLD_NORTH_ARABIAN  = ('N' << 24) | ('a' << 16) | ('r' << 8) | 'b', /*7.0*/
  OLD_PERMIC         = ('P' << 24) | ('e' << 16) | ('r' << 8) | 'm', /*7.0*/
  PAHAWH_HMONG       = ('H' << 24) | ('m' << 16) | ('n' << 8) | 'g', /*7.0*/
  PALMYRENE          = ('P' << 24) | ('a' << 16) | ('l' << 8) | 'm', /*7.0*/
  PAU_CIN_HAU        = ('P' << 24) | ('a' << 16) | ('u' << 8) | 'c', /*7.0*/
  PSALTER_PAHLAVI    = ('P' << 24) | ('h' << 16) | ('l' << 8) | 'p', /*7.0*/
  SIDDHAM            = ('S' << 24) | ('i' << 16) | ('d' << 8) | 'd', /*7.0*/
  TIRHUTA            = ('T' << 24) | ('i' << 16) | ('r' << 8) | 'h', /*7.0*/
  WARANG_CITI        = ('W' << 24) | ('a' << 16) | ('r' << 8) | 'a', /*7.0*/

  AHOM                  = ('A' << 24) | ('h' << 16) | ('o' << 8) | 'm', /*8.0*/
  ANATOLIAN_HIEROGLYPHS = ('H' << 24) | ('l' << 16) | ('u' << 8) | 'w', /*8.0*/
  HATRAN                = ('H' << 24) | ('a' << 16) | ('t' << 8) | 'r', /*8.0*/
  MULTANI               = ('M' << 24) | ('u' << 16) | ('l' << 8) | 't', /*8.0*/
  OLD_HUNGARIAN         = ('H' << 24) | ('u' << 16) | ('n' << 8) | 'g', /*8.0*/
  SIGNWRITING           = ('S' << 24) | ('g' << 16) | ('n' << 8) | 'w', /*8.0*/

  /*
   * Since 1.3.0
   */
  ADLAM     = ('A' << 24) | ('d' << 16) | ('l' << 8) | 'm', /*9.0*/
  BHAIKSUKI = ('B' << 24) | ('h' << 16) | ('k' << 8) | 's', /*9.0*/
  MARCHEN   = ('M' << 24) | ('a' << 16) | ('r' << 8) | 'c', /*9.0*/
  OSAGE     = ('O' << 24) | ('s' << 16) | ('g' << 8) | 'e', /*9.0*/
  TANGUT    = ('T' << 24) | ('a' << 16) | ('n' << 8) | 'g', /*9.0*/
  NEWA      = ('N' << 24) | ('e' << 16) | ('w' << 8) | 'a', /*9.0*/

  /*
   * Since 1.6.0
   */
  MASARAM_GONDI    = ('G' << 24) | ('o' << 16) | ('n' << 8) | 'm', /*10.0*/
  NUSHU            = ('N' << 24) | ('s' << 16) | ('h' << 8) | 'u', /*10.0*/
  SOYOMBO          = ('S' << 24) | ('o' << 16) | ('y' << 8) | 'o', /*10.0*/
  ZANABAZAR_SQUARE = ('Z' << 24) | ('a' << 16) | ('n' << 8) | 'b', /*10.0*/

  /*
   * Since 1.8.0
   */
  DOGRA           = ('D' << 24) | ('o' << 16) | ('g' << 8) | 'r', /*11.0*/
  GUNJALA_GONDI   = ('G' << 24) | ('o' << 16) | ('n' << 8) | 'g', /*11.0*/
  HANIFI_ROHINGYA = ('R' << 24) | ('o' << 16) | ('h' << 8) | 'g', /*11.0*/
  MAKASAR         = ('M' << 24) | ('a' << 16) | ('k' << 8) | 'a', /*11.0*/
  MEDEFAIDRIN     = ('M' << 24) | ('e' << 16) | ('d' << 8) | 'f', /*11.0*/
  OLD_SOGDIAN     = ('S' << 24) | ('o' << 16) | ('g' << 8) | 'o', /*11.0*/
  SOGDIAN         = ('S' << 24) | ('o' << 16) | ('g' << 8) | 'd', /*11.0*/

  /*
   * Since 2.4.0
   */
  ELYMAIC                = ('E' << 24) | ('l' << 16) | ('y' << 8) | 'm', /*12.0*/
  NANDINAGARI            = ('N' << 24) | ('a' << 16) | ('n' << 8) | 'd', /*12.0*/
  NYIAKENG_PUACHUE_HMONG = ('H' << 24) | ('m' << 16) | ('n' << 8) | 'p', /*12.0*/
  WANCHO                 = ('W' << 24) | ('c' << 16) | ('h' << 8) | 'o', /*12.0*/

  /*
   * Since 2.6.7
   */
  CHORASMIAN          = ('C' << 24) | ('h' << 16) | ('r' << 8) | 's', /*13.0*/
  DIVES_AKURU         = ('D' << 24) | ('i' << 16) | ('a' << 8) | 'k', /*13.0*/
  KHITAN_SMALL_SCRIPT = ('K' << 24) | ('i' << 16) | ('t' << 8) | 's', /*13.0*/
  YEZIDI              = ('Y' << 24) | ('e' << 16) | ('z' << 8) | 'i', /*13.0*/

  /*
   * Since 3.0.0
   */
  CYPRO_MINOAN = ('C' << 24) | ('p' << 16) | ('m' << 8) | 'n', /*14.0*/
  OLD_UYGHUR   = ('O' << 24) | ('u' << 16) | ('g' << 8) | 'r', /*14.0*/
  TANGSA       = ('T' << 24) | ('n' << 16) | ('s' << 8) | 'a', /*14.0*/
  TOTO         = ('T' << 24) | ('o' << 16) | ('t' << 8) | 'o', /*14.0*/
  VITHKUQI     = ('V' << 24) | ('i' << 16) | ('t' << 8) | 'h', /*14.0*/

  /*
   * Since 3.4.0
   */
  MATH = ('Z' << 24) | ('m' << 16) | ('t' << 8) | 'h',

  /*
   * Since 5.2.0
   */
  KAWI        = ('K' << 24) | ('a' << 16) | ('w' << 8) | 'i', /*15.0*/
  NAG_MUNDARI = ('N' << 24) | ('a' << 16) | ('g' << 8) | 'm', /*15.0*/

  /* No script set. */
  INVALID			= HB_TAG_NONE,

  /*< private >*/

  /* Dummy values to ensure any hb_tag_t value can be passed/stored as hb_script_t
   * without risking undefined behavior.  We have two, for historical reasons.
   * HB_TAG_MAX used to be unsigned, but that was invalid Ansi C, so was changed
   * to _HB_SCRIPT_MAX_VALUE to be equal to HB_TAG_MAX_SIGNED as well.
   *
   * See this thread for technicalities:
   *
   *   https://lists.freedesktop.org/archives/harfbuzz/2014-March/004150.html
   */
  MAX_VALUE				= HB_TAG_MAX_SIGNED, /*< skip >*/
  MAX_VALUE_SIGNED			= HB_TAG_MAX_SIGNED /*< skip >*/
}


package sheenbidi

import "core:c"

// Based on version 2.7
when ODIN_OS == .Linux {foreign import sheenbidi "libs/libsheenbidi.a"}
when ODIN_OS == .Windows {
    // disable linking with libc since Odin already does that (or maybe we disable Odin's libc linking?)
    // fixes linker warnings with harfbuzz too
    // https://discord.com/channels/568138951836172421/1194846822573822023/1194906017654374463
    @(extra_linker_flags = "/NODEFAULTLIB:libcmt")
    foreign import sheenbidi "libs/sheenbidi.lib"
}

SBUInteger :: c.uintptr_t
SBUInt8 :: c.uint8_t
SBUInt32 :: c.uint32_t

SBCodepoint :: SBUInt32

SBStringEncoding :: enum SBUInt32 {
    UTF8 = 0,  /**< An 8-bit representation of Unicode code points. */
    UTF16 = 1, /**< 16-bit UTF encoding in native endianness. */
    UTF32 = 2  /**< 32-bit UTF encoding in native endianness. */
}

SBBoolean :: enum SBUInt8 {
    False = 0, /**< A value representing the false state. */
    True  = 1  /**< A value representing the true state. */
}

SBBidiType :: enum SBUInt8 {
    Nil = 0x00,

    L   = 0x01,   /**< Strong: Left-to-Right */
    R   = 0x02,   /**< Strong: Right-to-Left */
    AL  = 0x03,   /**< Strong: Right-to-Left Arabic */

    BN  = 0x04,   /**< Weak: Boundary Neutral */
    NSM = 0x05,   /**< Weak: Non-Spacing Mark */
    AN  = 0x06,   /**< Weak: Arabic Number */
    EN  = 0x07,   /**< Weak: European Number */
    ET  = 0x08,   /**< Weak: European Number Terminator */
    ES  = 0x09,   /**< Weak: European Number Separator */
    CS  = 0x0A,   /**< Weak: Common Number Separator */

    WS  = 0x0B,   /**< Neutral: White Space */
    S   = 0x0C,   /**< Neutral: Segment Separator */
    B   = 0x0D,   /**< Neutral: Paragraph Separator */
    ON  = 0x0E,   /**< Neutral: Other Neutral */

    LRI = 0x0F,   /**< Format: Left-to-Right Isolate */
    RLI = 0x10,   /**< Format: Right-to-Left Isolate */
    FSI = 0x11,   /**< Format: First Strong Isolate */
    PDI = 0x12,   /**< Format: Pop Directional Isolate */
    LRE = 0x13,   /**< Format: Left-to-Right Embedding */
    RLE = 0x14,   /**< Format: Right-to-Left Embedding */
    LRO = 0x15,   /**< Format: Left-to-Right Override */
    RLO = 0x16,   /**< Format: Right-to-Left Override */
    PDF = 0x17    /**< Format: Pop Directional Formatting */
}

/**
 * A type to represent a bidi level.
 */
SBLevel :: enum SBUInt8 {
    /**
    * A value representing an invalid bidi level.
    */
    Invalid = 0xFF,

    /**
    * A value representing maximum explicit embedding level.
    */
    Max = 125,

    /**
    * A value specifying to set base level to zero (left-to-right) if there is no strong character.
    */
    DefaultLTR = 0xFE,

    /**
    * A value specifying to set base level to one (right-to-left) if there is no strong character.
    */
    DefaultRTL = 0xFD,
}

CodepointSequence :: struct {
    stringEncoding: SBStringEncoding, /**< The encoding of the string. */
    stringBuffer: rawptr,              /**< The source string containing the code units. */
    stringLength: SBUInteger,         /**< The length of the string in terms of code units. */
}

#assert(size_of(Run) == 24)
Run :: struct {
    offset: SBUInteger, /**< The index to the first code unit of the run in source string. */
    length: SBUInteger, /**< The number of code units covering the length of the run. */
    level: SBLevel,     /**< The embedding level of the run. */
}

#assert(size_of(SBLine) == 64)
SBLine :: struct {
    codepointSequence: CodepointSequence,
    fixedRuns: ^Run,
    runCount: SBUInteger,
    offset: SBUInteger,
    length: SBUInteger,
    retainCount: SBUInteger,
}
SBLineRef :: ^SBLine

#assert(size_of(SBAlgorithm) == 40)
SBAlgorithm :: struct {
    codepointSequence: CodepointSequence,
    fixedTypes: ^SBBidiType,
    retainCount: SBUInteger,
}
SBAlgorithmRef :: ^SBAlgorithm

#assert(size_of(SBParagraph) == 56)
SBParagraph :: struct {
    algorithm: SBAlgorithmRef,
    refTypes: ^SBBidiType,
    fixedLevels: ^SBLevel,
    offset: SBUInteger,
    length: SBUInteger,
    baseLevel: SBLevel,
    retainCount: SBUInteger,
}
SBParagraphRef :: ^SBParagraph

SBMirrorAgent :: struct {
    index: SBUInteger,      /**< The absolute index of the code point. */
    mirror: SBCodepoint,    /**< The mirrored code point. */
    codepoint: SBCodepoint, /**< The actual code point. */
}

#assert(size_of(SBMirrorLocator) == 48)
SBMirrorLocator :: struct {
    _line: SBLineRef,
    _runIndex: SBUInteger,
    _stringIndex: SBUInteger,
    agent: SBMirrorAgent,
    retainCount: SBUInteger,
}
SBMirrorLocatorRef :: ^SBMirrorLocator

@(link_prefix = "SB")
foreign sheenbidi {
    AlgorithmCreate :: proc(codepointSequence: ^CodepointSequence) -> SBAlgorithmRef ---
    AlgorithmCreateParagraph :: proc(
        algorithm: SBAlgorithmRef,
        paragraphOffset: SBUInteger,
        suggestedLength: SBUInteger,
        baseLevel: SBLevel) -> SBParagraphRef ---
    ParagraphGetLength :: proc(paragraph: SBParagraphRef) -> SBUInteger ---
    ParagraphCreateLine :: proc(paragraph: SBParagraphRef, lineOffset: SBUInteger, lineLength: SBUInteger) -> SBLineRef ---
    LineGetRunCount :: proc(line: SBLineRef) -> SBUInteger ---
    LineGetRunsPtr :: proc(line: SBLineRef) -> [^]Run ---
    MirrorLocatorCreate :: proc() -> SBMirrorLocatorRef ---
    MirrorLocatorLoadLine :: proc(locator: SBMirrorLocatorRef, line: SBLineRef, stringBuffer: rawptr) ---
    MirrorLocatorGetAgent :: proc(locator: SBMirrorLocatorRef) -> ^SBMirrorAgent ---
    MirrorLocatorMoveNext :: proc(locator: SBMirrorLocatorRef) -> SBBoolean ---
    MirrorLocatorRelease :: proc(locator: SBMirrorLocatorRef) ---
    LineRelease :: proc(line: SBLineRef) ---
    ParagraphRelease :: proc(paragraph: SBParagraphRef) ---
    AlgorithmRelease :: proc(algorithm: SBAlgorithmRef) ---
}

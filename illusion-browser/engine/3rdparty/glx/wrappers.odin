// +build linux
package glx

import x11 "vendor:x11/xlib"
foreign import glx "system:GL"

#assert(size_of(__FBConfigRec) == 232)

@(private)
__FBConfigRec :: struct {
    visualType:                                                          i32,
    transparentType:                                                     i32,
    transparentRed, transparentGreen, transparentBlue, transparentAlpha: i32,
    transparentIndex:                                                    i32,
    visualCaveat:                                                        i32,
    associatedVisualId:                                                  i32,
    screen:                                                              i32,
    drawableType:                                                        i32,
    renderType:                                                          i32,
    maxPbufferWidth, maxPbufferHeight, maxPbufferPixels:                 i32,
    optimalPbufferWidth, optimalPbufferHeight:                           i32, /* for SGIX_pbuffer */
    visualSelectGroup:                                                   i32, /* visuals grouped by select priority */
    id:                                                                  u32,
    rgbMode:                                                             b8,
    colorIndexMode:                                                      b8,
    doubleBufferMode:                                                    b8,
    stereoMode:                                                          b8,
    haveAccumBuffer:                                                     b8,
    haveDepthBuffer:                                                     b8,
    haveStencilBuffer:                                                   b8,

    /* The number of bits present in various buffers */
    accumRedBits, accumGreenBits, accumBlueBits, accumAlphaBits:         i32,
    depthBits:                                                           i32,
    stencilBits:                                                         i32,
    indexBits:                                                           i32,
    redBits, greenBits, blueBits, alphaBits:                             i32,
    redMask, greenMask, blueMask, alphaMask:                             u32,
    multiSampleSize:                                                     u32, /* Number of samples per pixel (0 if no ms) */
    nMultiSampleBuffers:                                                 u32, /* Number of available ms buffers */
    maxAuxBuffers:                                                       i32,

    /* frame buffer level */
    level:                                                               i32,

    /* color ranges (for SGI_color_range) */
    extendedRange:                                                       b8,
    minRed, maxRed:                                                      f64,
    minGreen, maxGreen:                                                  f64,
    minBlue, maxBlue:                                                    f64,
    minAlpha, maxAlpha:                                                  f64,
}

FBConfig :: ^__FBConfigRec
Context :: rawptr

@(link_prefix = "glX")
foreign glx {
    GetProcAddressARB :: proc(name: ^u8) -> rawptr ---
    SwapBuffers :: proc(display: ^x11.Display, drawable: Drawable) ---
    QueryVersion :: proc(display: ^x11.Display, major: ^i32, minor: ^i32) -> b32 ---
    QueryExtensionsString :: proc(display: ^x11.Display, screen: i32) -> cstring ---
    GetFBConfigAttrib :: proc(display: ^x11.Display, config: FBConfig, attribute: i32, value: ^i32) -> i32 ---
    ChooseFBConfig :: proc(display: ^x11.Display, screen: i32, attrib_list: ^i32, nelements: ^i32) -> [^]FBConfig ---
    CreateContextAttribsARB :: proc(display: ^x11.Display, config: FBConfig, share_context: Context, direct: b32, attrib_list: ^i32) -> Context ---
    GetVisualFromFBConfig :: proc(display: ^x11.Display, config: FBConfig) -> ^x11.XVisualInfo ---
    DestroyContext :: proc(display: ^x11.Display, ctx: Context) ---
    SwapIntervalEXT :: proc(display: ^x11.Display, drawable: Drawable, interval: i32) ---
    MakeCurrent :: proc(display: ^x11.Display, drawable: Drawable, ctx: Context) -> b32 ---
}

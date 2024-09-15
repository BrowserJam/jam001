package zephr

import "core:container/bit_array"
import "core:container/queue"
import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:time"

import gl "vendor:OpenGL"

// TODO: In the future stop drawing and processing things in the engine when the window is not focused
//       This assumes the window is just completely hidden and not just out of focus (the user can still see it)

RELEASE_BUILD :: #config(RELEASE_BUILD, false)

Cursor :: enum {
    INVISIBLE,
    ARROW,
    IBEAM,
    CROSSHAIR,
    HAND,
    HRESIZE,
    VRESIZE,
    DISABLED,
}

EventType :: enum {
    UNKNOWN,
    INPUT_DEVICE_CONNECTED,
    INPUT_DEVICE_DISCONNECTED,
    INPUT_DEVICE_UPDATED,
    RAW_GAMEPAD_ACTION_PRESSED,
    RAW_GAMEPAD_ACTION_RELEASED,
    RAW_TOUCHPAD_ACTION_PRESSED,
    RAW_TOUCHPAD_ACTION_RELEASED,
    RAW_TOUCHPAD_MOVED,
    RAW_ACCELEROMETER_CHANGED,
    RAW_GYROSCOPE_CHANGED,
    RAW_KEY_PRESSED,
    RAW_KEY_RELEASED,
    RAW_MOUSE_BUTTON_PRESSED,
    RAW_MOUSE_BUTTON_RELEASED,
    RAW_MOUSE_SCROLL,
    RAW_MOUSE_MOVED,
    VIRT_MOUSE_BUTTON_PRESSED,
    VIRT_MOUSE_BUTTON_RELEASED,
    VIRT_MOUSE_SCROLL,
    VIRT_MOUSE_MOVED,
    VIRT_KEY_PRESSED,
    VIRT_KEY_RELEASED,
    FILE_DROP,
    WINDOW_RESIZED,
    WINDOW_CLOSED,
}

MouseButton :: enum {
    NONE    = 0x00,
    LEFT    = 0x01,
    RIGHT   = 0x02,
    MIDDLE  = 0x04,
    BACK    = 0x08,
    FORWARD = 0x10,
}

KeyMod :: bit_set[KeyModBits;u16]
KeyModBits :: enum {
    NONE        = 0,
    LEFT_SHIFT  = 1,
    RIGHT_SHIFT = 2,
    LEFT_CTRL   = 3,
    RIGHT_CTRL  = 4,
    LEFT_ALT    = 5,
    RIGHT_ALT   = 6,
    LEFT_META   = 7,
    RIGHT_META  = 8,
    CAPS_LOCK   = 9,
    NUM_LOCK    = 10,
}

Keycode :: distinct Scancode

Scancode :: enum {
    NULL               = 0,
    A                  = 4,
    B                  = 5,
    C                  = 6,
    D                  = 7,
    E                  = 8,
    F                  = 9,
    G                  = 10,
    H                  = 11,
    I                  = 12,
    J                  = 13,
    K                  = 14,
    L                  = 15,
    M                  = 16,
    N                  = 17,
    O                  = 18,
    P                  = 19,
    Q                  = 20,
    R                  = 21,
    S                  = 22,
    T                  = 23,
    U                  = 24,
    V                  = 25,
    W                  = 26,
    X                  = 27,
    Y                  = 28,
    Z                  = 29,
    KEY_1              = 30,
    KEY_2              = 31,
    KEY_3              = 32,
    KEY_4              = 33,
    KEY_5              = 34,
    KEY_6              = 35,
    KEY_7              = 36,
    KEY_8              = 37,
    KEY_9              = 38,
    KEY_0              = 39,
    ENTER              = 40,
    ESCAPE             = 41,
    BACKSPACE          = 42,
    TAB                = 43,
    SPACE              = 44,
    MINUS              = 45,
    EQUALS             = 46,
    LEFT_BRACKET       = 47,
    RIGHT_BRACKET      = 48,
    BACKSLASH          = 49,
    NON_US_HASH        = 50,
    SEMICOLON          = 51,
    APOSTROPHE         = 52,
    GRAVE              = 53,
    COMMA              = 54,
    PERIOD             = 55,
    SLASH              = 56,
    CAPS_LOCK          = 57,
    F1                 = 58,
    F2                 = 59,
    F3                 = 60,
    F4                 = 61,
    F5                 = 62,
    F6                 = 63,
    F7                 = 64,
    F8                 = 65,
    F9                 = 66,
    F10                = 67,
    F11                = 68,
    F12                = 69,
    PRINT_SCREEN       = 70,
    SCROLL_LOCK        = 71,
    PAUSE              = 72,
    INSERT             = 73,
    HOME               = 74,
    PAGE_UP            = 75,
    DELETE             = 76,
    END                = 77,
    PAGE_DOWN          = 78,
    RIGHT              = 79,
    LEFT               = 80,
    DOWN               = 81,
    UP                 = 82,
    NUM_LOCK_OR_CLEAR  = 83,
    KP_DIVIDE          = 84,
    KP_MULTIPLY        = 85,
    KP_MINUS           = 86,
    KP_PLUS            = 87,
    KP_ENTER           = 88,
    KP_1               = 89,
    KP_2               = 90,
    KP_3               = 91,
    KP_4               = 92,
    KP_5               = 93,
    KP_6               = 94,
    KP_7               = 95,
    KP_8               = 96,
    KP_9               = 97,
    KP_0               = 98,
    KP_PERIOD          = 99,
    NON_US_BACKSLASH   = 100,
    APPLICATION        = 101,
    POWER              = 102,
    KP_EQUALS          = 103,
    F13                = 104,
    F14                = 105,
    F15                = 106,
    F16                = 107,
    F17                = 108,
    F18                = 109,
    F19                = 110,
    F20                = 111,
    F21                = 112,
    F22                = 113,
    F23                = 114,
    F24                = 115,
    EXECUTE            = 116,
    HELP               = 117,
    MENU               = 118,
    SELECT             = 119,
    STOP               = 120,
    AGAIN              = 121,
    UNDO               = 122,
    CUT                = 123,
    COPY               = 124,
    PASTE              = 125,
    FIND               = 126,
    MUTE               = 127,
    VOLUME_UP          = 128,
    VOLUME_DOWN        = 129,
    KP_COMMA           = 133,
    KP_EQUALSAS400     = 134,
    INTERNATIONAL1     = 135,
    INTERNATIONAL2     = 136,
    INTERNATIONAL3     = 137,
    INTERNATIONAL4     = 138,
    INTERNATIONAL5     = 139,
    INTERNATIONAL6     = 140,
    INTERNATIONAL7     = 141,
    INTERNATIONAL8     = 142,
    INTERNATIONAL9     = 143,
    LANG1              = 144,
    LANG2              = 145,
    LANG3              = 146,
    LANG4              = 147,
    LANG5              = 148,
    LANG6              = 149,
    LANG7              = 150,
    LANG8              = 151,
    LANG9              = 152,
    ALT_ERASE          = 153,
    SYSREQ             = 154,
    CANCEL             = 155,
    CLEAR              = 156,
    PRIOR              = 157,
    ENTER_2            = 158,
    SEPARATOR          = 159,
    OUT                = 160,
    OPER               = 161,
    CLEARAGAIN         = 162,
    CRSEL              = 163,
    EXSEL              = 164,
    KP_00              = 176,
    KP_000             = 177,
    THOUSANDSSEPARATOR = 178,
    DECIMALSEPARATOR   = 179,
    CURRENCYUNIT       = 180,
    CURRENCYSUBUNIT    = 181,
    KP_LEFT_PAREN      = 182,
    KP_RIGHT_PAREN     = 183,
    KP_LEFT_BRACE      = 184,
    KP_RIGHT_BRACE     = 185,
    KP_TAB             = 186,
    KP_BACKSPACE       = 187,
    KP_A               = 188,
    KP_B               = 189,
    KP_C               = 190,
    KP_D               = 191,
    KP_E               = 192,
    KP_F               = 193,
    KP_XOR             = 194,
    KP_POWER           = 195,
    KP_PERCENT         = 196,
    KP_LESS            = 197,
    KP_GREATER         = 198,
    KP_AMPERSAND       = 199,
    KP_DBLAMPERSAND    = 200,
    KP_VERTICALBAR     = 201,
    KP_DBLVERTICALBAR  = 202,
    KP_COLON           = 203,
    KP_HASH            = 204,
    KP_SPACE           = 205,
    KP_AT              = 206,
    KP_EXCLAM          = 207,
    KP_MEMSTORE        = 208,
    KP_MEMRECALL       = 209,
    KP_MEMCLEAR        = 210,
    KP_MEMADD          = 211,
    KP_MEMSUBTRACT     = 212,
    KP_MEMMULTIPLY     = 213,
    KP_MEMDIVIDE       = 214,
    KP_PLUS_MINUS      = 215,
    KP_CLEAR           = 216,
    KP_CLEARENTRY      = 217,
    KP_BINARY          = 218,
    KP_OCTAL           = 219,
    KP_DECIMAL         = 220,
    KP_HEXADECIMAL     = 221,
    LEFT_CTRL          = 224,
    LEFT_SHIFT         = 225,
    LEFT_ALT           = 226,
    LEFT_META          = 227,
    RIGHT_CTRL         = 228,
    RIGHT_SHIFT        = 229,
    RIGHT_ALT          = 230,
    RIGHT_META         = 231,

    /** Not a key. Marks the number of scancodes. */
    COUNT              = 512,
}

InputDeviceFeatures :: bit_set[InputDeviceFeaturesBits;u8]
InputDeviceFeaturesBits :: enum {
    MOUSE         = 0, // 1
    KEYBOARD      = 1, // 2
    GAMEPAD       = 2, // 4
    TOUCHPAD      = 3, // 8
    ACCELEROMETER = 4, // 16 
    GYROSCOPE     = 5, // 32
}

GamepadAction :: enum {
    NONE,
    DPAD_LEFT,
    DPAD_DOWN,
    DPAD_RIGHT,
    DPAD_UP,
    FACE_LEFT,
    FACE_DOWN,
    FACE_RIGHT,
    FACE_UP,
    START,
    SELECT,
    STICK_LEFT,
    STICK_RIGHT,
    SHOULDER_LEFT,
    SHOULDER_RIGHT,
    STICK_LEFT_X_WEST,
    STICK_LEFT_X_EAST,
    STICK_LEFT_Y_NORTH,
    STICK_LEFT_Y_SOUTH,
    STICK_RIGHT_X_WEST,
    STICK_RIGHT_X_EAST,
    STICK_RIGHT_Y_NORTH,
    STICK_RIGHT_Y_SOUTH,
    TRIGGER_LEFT,
    TRIGGER_RIGHT,
    SYSTEM, // Maps to PSButton on Playstation Controllers, and XBox Button on XBox Controllers.
    COUNT = SYSTEM,
}

TouchpadAction :: enum {
    NONE,
    CLICK,
    TOUCH,
}

Touchpad :: struct {
    pos:                             m.vec2,
    rel_pos:                         m.vec2,
    dims:                            m.vec2,
    action_is_pressed_bitset:        bit_set[TouchpadAction;u8],
    action_has_been_pressed_bitset:  bit_set[TouchpadAction;u8],
    action_has_been_released_bitset: bit_set[TouchpadAction;u8],
}

Gamepad :: struct {
    action_is_pressed_bitset:        bit_set[GamepadAction],
    action_has_been_pressed_bitset:  bit_set[GamepadAction],
    action_has_been_released_bitset: bit_set[GamepadAction],
    action_value_unorms:             [GamepadAction]f32,
    supports_rumble:                 bool,
}

// An input device can contain one or more of these types of devices based on its features.
// e.g A controller can contain a gamepad, a touchpad, accelerometer, gyroscope, and LEDs
InputDevice :: struct {
    name:          string,
    vendor_id:     u16,
    product_id:    u16,
    features:      InputDeviceFeatures,
    mouse:         Mouse,
    touchpad:      Touchpad,
    keyboard:      Keyboard,
    gamepad:       Gamepad,
    accelerometer: m.vec3,
    gyroscope:     m.vec3,
    backend_data:  [OS_INPUT_DEVICE_BACKEND_SIZE]u8,
    arena:         virtual.Arena,
}

Event :: struct {
    type:    EventType,
    using _: struct #raw_union {
        input_device:    struct {
            id:         u64,
            vendor_id:  u16,
            product_id: u16,
            features:   InputDeviceFeatures,
        },
        gamepad_action:  struct {
            device_id:   u64,
            action:      GamepadAction,
            value_unorm: f32,
        },
        touchpad_action: struct {
            device_id:     u64,
            is_pressed:    bool,
            action:        TouchpadAction,
            action_bitset: bit_set[TouchpadAction;u8],
        },
        touchpad_moved:  struct {
            device_id: u64,
            pos:       m.vec2, // touchpad space
            rel_pos:   m.vec2,
        },
        accelerometer:   struct {
            device_id: u64,
            accel:     m.vec3,
        },
        gyroscope:   struct {
            device_id: u64,
            gyro:     m.vec3,
        },
        key:             struct {
            device_id:  u64, // 0 for virtual keyboard
            is_pressed: bool,
            is_repeat:  bool,
            scancode:   Scancode,
            keycode:    Keycode,
            mods:       KeyMod,
        },
        mouse_button:    struct {
            device_id:     u64, // 0 for virtual mouse
            button:        MouseButton,
            button_bitset: bit_set[MouseButton;u32],
            using pos:     m.vec2,
        },
        mouse_moved:     struct {
            device_id: u64, // 0 for virtual mouse
            using pos: m.vec2,
            rel_pos:   m.vec2,
        },
        mouse_scroll:    struct {
            device_id:  u64, // 0 for virtual mouse
            scroll_rel: m.vec2,
        },
        file_drop:       struct {
            paths: []string,
        },
        window:          struct {
            width:  u32,
            height: u32,
        },
    },
}

Mouse :: struct {
    using pos:                       m.vec2,
    rel_pos:                         m.vec2,
    pos_before_capture:              m.vec2,
    virtual_pos:                     m.vec2,
    button_is_pressed_bitset:        bit_set[MouseButton;u32],
    button_has_been_pressed_bitset:  bit_set[MouseButton;u32],
    button_has_been_released_bitset: bit_set[MouseButton;u32],
    scroll_rel:                      m.vec2,
    captured:                        bool,
}

Window :: struct {
    size:                m.vec2,
    pre_fullscreen_size: m.vec2,
    is_fullscreen:       bool,
    non_resizable:       bool,
}

Keyboard :: struct {
    key_mod_is_pressed_bitset:         KeyMod,
    key_mod_has_been_pressed_bitset:   KeyMod,
    key_mod_has_been_released_bitset:  KeyMod,
    scancode_is_pressed_bitset:        bit_array.Bit_Array,
    scancode_has_been_pressed_bitset:  bit_array.Bit_Array,
    scancode_has_been_released_bitset: bit_array.Bit_Array,
    keycode_is_pressed_bitset:         bit_array.Bit_Array,
    keycode_has_been_pressed_bitset:   bit_array.Bit_Array,
    keycode_has_been_released_bitset:  bit_array.Bit_Array,
}

Context :: struct {
    should_quit:                  bool,
    screen_size:                  m.vec2,
    window:                       Window,
    font:                         Font,
    virt_mouse:                   Mouse,
    virt_keyboard:                Keyboard,
    keyboard_scancode_to_keycode: map[Scancode]Keycode,
    keyboard_keycode_to_scancode: map[Keycode]Scancode,
    cursor:                       Cursor,
    event_queue:                  queue.Queue(Event),
    input_devices_map:            map[u64]InputDevice,
    cursors:                      [Cursor]OsCursor,
    ui:                           Ui,
    projection:                   m.mat4,
    shaders:                      [dynamic]^Shader,
    changed_shaders_queue:        queue.Queue(string),
    clear_color:                  m.vec4,
}

@(private)
FNV_HASH32_INIT: u32 : 0x811c9dc5
@(private = "file")
FNV_HASH32_PRIME :: 0x01000193
@(private)
FNV_HASH64_INIT: u64 : 0xcbf29ce484222325
@(private = "file")
FNV_HASH64_PRIME :: 0x00000100000001B3
@(private)
INIT_UI_STACK_SIZE :: 256
@(private)
EVENT_QUEUE_INIT_CAP :: 128
@(private)
CHANGED_SHADERS_QUEUE_CAP :: 32
@(private)
INPUT_DEVICE_MAP_CAP :: 256
when ODIN_OS == .Linux {
    @(private)
    OS_INPUT_DEVICE_BACKEND_SIZE :: 488
} else when ODIN_OS == .Windows {
    OS_INPUT_DEVICE_BACKEND_SIZE :: 120
}

when ODIN_DEBUG {
    @(private)
    TerminalLoggerOpts :: log.Default_Console_Logger_Opts
} else {
    @(private)
    TerminalLoggerOpts :: log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Date, .Time}
}

COLOR_BLACK :: Color{0, 0, 0, 255}
COLOR_WHITE :: Color{255, 255, 255, 255}
COLOR_RED :: Color{255, 0, 0, 255}
COLOR_GREEN :: Color{0, 255, 0, 255}
COLOR_BLUE :: Color{0, 0, 255, 255}
COLOR_YELLOW :: Color{255, 255, 0, 255}
COLOR_MAGENTA :: Color{255, 0, 255, 255}
COLOR_CYAN :: Color{0, 255, 255, 255}
COLOR_ORANGE :: Color{255, 128, 0, 255}
COLOR_PURPLE :: Color{128, 0, 255, 255}

@(private)
engine_rel_path := filepath.dir(#file)

@(private)
zephr_ctx: Context
@(private)
logger: log.Logger


init :: proc(icon_path: cstring, window_title: cstring, window_size: m.vec2, window_non_resizable: bool) {
    logger_init()
    context.logger = logger

    // TODO: This font is currently used for the UI elements, but we should allow the user to specify
    //       their own font for the UI elements.
    //       In the future, this font should only be used for the engine's editor.
    engine_font_path := create_resource_path("res/fonts/Rubik/Rubik-VariableFont_wght.ttf")

    //ok := audio_init();
    //log.assert(ok, "Failed to initialize audio");

    queue.init(&zephr_ctx.event_queue, EVENT_QUEUE_INIT_CAP)
    queue.init(&zephr_ctx.changed_shaders_queue, CHANGED_SHADERS_QUEUE_CAP)
    zephr_ctx.input_devices_map = make(map[u64]InputDevice)

    backend_init(window_title, window_size, icon_path, window_non_resizable)

    zephr_ctx.ui.elements = make([dynamic]UiElement, INIT_UI_STACK_SIZE)
    zephr_ctx.virt_mouse.pos = m.vec2{-1, -1}
    zephr_ctx.window.size = window_size
    zephr_ctx.window.non_resizable = window_non_resizable
    zephr_ctx.projection = orthographic_projection_2d(0, window_size.x, window_size.y, 0)
    zephr_ctx.clear_color = {0.2, 0.2, 0.2, 1}

    init_renderer(window_size)
    ui_init(engine_font_path)

    backend_init_cursors()

    zephr_ctx.screen_size = backend_get_screen_size()
    start_internal_timer()
}

deinit :: proc() {
    backend_shutdown()
    delete(zephr_ctx.input_devices_map)
    delete(zephr_ctx.keyboard_scancode_to_keycode)
    delete(zephr_ctx.keyboard_keycode_to_scancode)
    queue.destroy(&zephr_ctx.event_queue)
    queue.destroy(&zephr_ctx.changed_shaders_queue)
    delete(zephr_ctx.ui.elements)
    delete(zephr_ctx.shaders)
    //audio_close()
}

set_clear_color :: proc(color: m.vec4) {
    zephr_ctx.clear_color = color
}

should_quit :: proc() -> bool {
    return zephr_ctx.should_quit
}

quit :: proc() {
    zephr_ctx.should_quit = true
}

@(private)
consume_mouse_events :: proc() -> bool {
    defer clear(&zephr_ctx.ui.elements)

    #reverse for e in zephr_ctx.ui.elements {
        if (inside_rect(e.rect, zephr_ctx.virt_mouse.pos)) {
            zephr_ctx.ui.hovered_element = e.id
            return false
        }
    }

    return true
}

change_vsync :: proc(on: bool) {
    backend_change_vsync(on)
}

frame_start :: proc() {
    for id, &device in zephr_ctx.input_devices_map {
        if .MOUSE in device.features {
            device.mouse.rel_pos = m.vec2{0, 0}
            device.mouse.scroll_rel = m.vec2{0, 0}
            device.mouse.button_has_been_pressed_bitset = {.NONE}
            device.mouse.button_has_been_released_bitset = {.NONE}
        }

        if .TOUCHPAD in device.features {
            device.touchpad.rel_pos = m.vec2{0, 0}
            device.touchpad.action_has_been_pressed_bitset = {.NONE}
            device.touchpad.action_has_been_released_bitset = {.NONE}
        }

        if .KEYBOARD in device.features {
            device.keyboard.key_mod_has_been_pressed_bitset = {.NONE}
            device.keyboard.key_mod_has_been_released_bitset = {.NONE}
            bit_array.clear(&device.keyboard.scancode_has_been_pressed_bitset)
            bit_array.clear(&device.keyboard.scancode_has_been_released_bitset)
            bit_array.clear(&device.keyboard.keycode_has_been_pressed_bitset)
            bit_array.clear(&device.keyboard.keycode_has_been_released_bitset)
        }

        if .GAMEPAD in device.features {
            device.gamepad.action_has_been_pressed_bitset = {}
            device.gamepad.action_has_been_released_bitset = {}
        }
    }

    zephr_ctx.virt_mouse.rel_pos = m.vec2{}
    zephr_ctx.virt_mouse.scroll_rel = m.vec2{}
    zephr_ctx.virt_mouse.button_has_been_pressed_bitset = {.NONE}
    zephr_ctx.virt_mouse.button_has_been_released_bitset = {.NONE}

    zephr_ctx.virt_keyboard.key_mod_has_been_pressed_bitset = {.NONE}
    zephr_ctx.virt_keyboard.key_mod_has_been_released_bitset = {.NONE}
    bit_array.clear(&zephr_ctx.virt_keyboard.scancode_has_been_pressed_bitset)
    bit_array.clear(&zephr_ctx.virt_keyboard.scancode_has_been_released_bitset)
    bit_array.clear(&zephr_ctx.virt_keyboard.keycode_has_been_pressed_bitset)
    bit_array.clear(&zephr_ctx.virt_keyboard.keycode_has_been_released_bitset)

    if zephr_ctx.virt_mouse.captured {
        zephr_ctx.cursor = .INVISIBLE
    } else {
        zephr_ctx.cursor = .ARROW
    }

    gl.ClearColor(zephr_ctx.clear_color.r, zephr_ctx.clear_color.g, zephr_ctx.clear_color.b, zephr_ctx.clear_color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    //audio_update();

    //os_backend_frame_init();
}

frame_end :: proc() {
    defer free_all(context.temp_allocator)
    update_shaders_if_changed()

    if (zephr_ctx.ui.popup_open) {
        draw_color_picker_popup(&zephr_ctx.ui.popup_parent_constraints)
    }
    zephr_ctx.ui.popup_open = false

    if consume_mouse_events() {
        zephr_ctx.ui.hovered_element = 0
    }

    backend_swapbuffers()
    backend_set_cursor()
}

iter_events :: proc() -> ^Event {
    context.logger = logger

    if queue.len(zephr_ctx.event_queue) < queue.cap(zephr_ctx.event_queue) {
        backend_get_os_events()

        if queue.len(zephr_ctx.event_queue) == 0 {
            return nil
        }
    }

    ev := queue.front_ptr(&zephr_ctx.event_queue)
    queue.pop_front(&zephr_ctx.event_queue)
    return ev
}

get_input_device_by_id :: proc(device_id: u64) -> ^InputDevice {
    return &zephr_ctx.input_devices_map[device_id]
}

get_all_input_devices :: proc() -> ^map[u64]InputDevice {
    return &zephr_ctx.input_devices_map
}

get_window_size :: proc() -> m.vec2 {
    return zephr_ctx.window.size
}

toggle_fullscreen :: proc() {
    backend_toggle_fullscreen(zephr_ctx.window.is_fullscreen)

    zephr_ctx.window.is_fullscreen = !zephr_ctx.window.is_fullscreen
}

virt_mouse_button_is_pressed :: #force_inline proc(button: MouseButton) -> bool {
    return button in zephr_ctx.virt_mouse.button_is_pressed_bitset
}

virt_mouse_button_has_been_pressed :: #force_inline proc(button: MouseButton) -> bool {
    return button in zephr_ctx.virt_mouse.button_has_been_pressed_bitset
}

virt_mouse_button_has_been_released :: #force_inline proc(button: MouseButton) -> bool {
    return button in zephr_ctx.virt_mouse.button_has_been_released_bitset
}

virt_mouse_rel_pos :: #force_inline proc() -> m.vec2 {
    return zephr_ctx.virt_mouse.rel_pos
}

virt_mouse_pos :: #force_inline proc() -> m.vec2 {
    return zephr_ctx.virt_mouse.pos
}

toggle_cursor_capture :: proc() {
    if zephr_ctx.virt_mouse.captured {
        backend_release_cursor()
    } else {
        backend_grab_cursor()
    }

    zephr_ctx.virt_mouse.captured = !zephr_ctx.virt_mouse.captured
}

load_font :: proc(font_path: cstring) {
    // TODO: this function should be called from the game/future editor to load in new
    // fonts that will be used in the game.
    // TODO: I'm not sure how the path is supposed to be resolved since relative paths
    // are relative to the engine repo dir and not the game's repo dir.
    // I think we'll just create a custom binary format for fonts that we can load in??
    // Or dump out a texture atlas using another tool and load that in

    // Ideally we'd want to create a custom binary format for fonts when this is called that we can load in
    // and use to render text after the initial loading. This would allow the engine users
    // to select any font on their system and not have to include it in their game's repo.
    // This also allows us to add any extra data about the fonts that want, i.e SDF data, atlas texture coords, etc.

    // For now we'll just require that the ttf font file is included with the game.
}

gamepad_action_is_pressed :: #force_inline proc(gamepad: ^Gamepad, action: GamepadAction) -> bool {
    return action in gamepad.action_is_pressed_bitset
}

gamepad_action_value :: #force_inline proc(gamepad: ^Gamepad, action: GamepadAction) -> f32 {
    return gamepad.action_value_unorms[action]
}

gamepad_rumble :: proc(
    device: ^InputDevice,
    weak_motor: u16,
    strong_motor: u16,
    duration: time.Duration,
    delay: time.Duration = 0,
) {
    if !device.gamepad.supports_rumble do return

    backend_gamepad_rumble(device, weak_motor, strong_motor, duration, delay)
}

virt_keyboard_scancode_is_pressed :: proc(key: Scancode) -> bool {
    return bit_array.get(&zephr_ctx.virt_keyboard.scancode_is_pressed_bitset, key)
}

virt_keyboard_keycode_is_pressed :: proc(key: Keycode) -> bool {
    return bit_array.get(&zephr_ctx.virt_keyboard.keycode_is_pressed_bitset, key)
}

is_cursor_captured :: proc() -> bool {
    return zephr_ctx.virt_mouse.captured
}

@(private)
set_cursor :: proc(cursor: Cursor) {
    zephr_ctx.cursor = cursor
}

@(private)
input_device_get_checked :: proc(id: u64, features: InputDeviceFeatures) -> ^InputDevice {
    device := &zephr_ctx.input_devices_map[id]
    log.assert(
        device.features & features == features,
        fmt.tprintf("expected features '0x%x' but got '0x%x'", features, device.features),
    )
    return device
}

@(private)
os_event_queue_input_device_connected :: proc(
    key: u64,
    name: string,
    features: InputDeviceFeatures,
    vendor_id: u16,
    product_id: u16,
) -> ^InputDevice {
    found_device, found := &zephr_ctx.input_devices_map[key]
    if (found) {
        if found_device.vendor_id == 0 {
            found_device.vendor_id = vendor_id
        }
        if found_device.product_id == 0 {
            found_device.product_id = product_id
        }
        if found_device.name == "" {
            found_device.name = name
        }

        e: Event
        e.type = .INPUT_DEVICE_UPDATED
        e.input_device.id = key
        e.input_device.features |= features
        e.input_device.vendor_id = vendor_id
        e.input_device.product_id = product_id
        queue.push(&zephr_ctx.event_queue, e)

        return found_device
    }

    log.infof(
        "input device connected: name: %s, vendor_id: 0x%x, product_id: 0x%x, features: 0x%x",
        name,
        vendor_id,
        product_id,
        features,
    )

    device := InputDevice {
        name       = name,
        features   = features,
        vendor_id  = vendor_id,
        product_id = product_id,
    }

    zephr_ctx.input_devices_map[key] = device

    e: Event
    e.type = .INPUT_DEVICE_CONNECTED
    e.input_device.id = key
    e.input_device.features = features
    e.input_device.vendor_id = vendor_id
    e.input_device.product_id = product_id

    queue.push(&zephr_ctx.event_queue, e)

    return &zephr_ctx.input_devices_map[key]
}

get_first_input_device :: proc(features: InputDeviceFeatures) -> (u64, ^InputDevice) {
    for id, &device in zephr_ctx.input_devices_map {
        if device.features & features == features {
            return id, &device
        }
    }

    return 0, nil
}

@(private)
os_event_queue_input_device_disconnected :: proc(key: u64) {
    device := zephr_ctx.input_devices_map[key]

    e: Event

    e.type = .INPUT_DEVICE_DISCONNECTED
    e.input_device.id = key
    e.input_device.features = device.features
    e.input_device.vendor_id = device.vendor_id
    e.input_device.product_id = device.product_id

    queue.push(&zephr_ctx.event_queue, e)

    log.infof(
        "input device disconnected: name: %s, vendor_id: 0x%x, product_id: 0x%x, features: 0x%x",
        device.name,
        device.vendor_id,
        device.product_id,
        device.features,
    )

    delete_key(&zephr_ctx.input_devices_map, key)
}

@(private)
os_event_queue_raw_gamepad_action :: proc(key: u64, action: GamepadAction, value_unorm: f32, deadzone_unorm: f32) {
    value_unorm := value_unorm

    if (action == .NONE) {
        return
    }

    device := input_device_get_checked(key, {.GAMEPAD})
    if (value_unorm < deadzone_unorm) {     // TODO: user configurable deadzone, different for each stick and trigger
        value_unorm = 0
    }

    if (device.gamepad.action_value_unorms[action] == value_unorm) {
        return
    }

    if (value_unorm > 0) {
        device.gamepad.action_is_pressed_bitset |= {action}
        device.gamepad.action_has_been_pressed_bitset |= {action}
    } else {
        device.gamepad.action_is_pressed_bitset &= ~{action}
        device.gamepad.action_has_been_released_bitset |= {action}
    }

    e: Event
    e.type = value_unorm > 0 ? .RAW_GAMEPAD_ACTION_PRESSED : .RAW_GAMEPAD_ACTION_RELEASED
    e.gamepad_action.device_id = key
    e.gamepad_action.action = action
    e.gamepad_action.value_unorm = value_unorm

    queue.push(&zephr_ctx.event_queue, e)

    device.gamepad.action_value_unorms[action] = value_unorm
}

@(private)
os_event_queue_raw_touchpad_action :: proc(key: u64, action: TouchpadAction, is_pressed: bool) {
    device := input_device_get_checked(key, {.TOUCHPAD})
    if (is_pressed) {
        device.touchpad.action_is_pressed_bitset |= {action}
        device.touchpad.action_has_been_pressed_bitset |= {action}
    } else {
        device.touchpad.action_is_pressed_bitset &= ~{action}
        device.touchpad.action_has_been_released_bitset |= {action}
    }

    e: Event
    e.type = is_pressed ? .RAW_TOUCHPAD_ACTION_PRESSED : .RAW_TOUCHPAD_ACTION_RELEASED
    e.touchpad_action.device_id = key
    e.touchpad_action.action = action
    e.touchpad_action.action_bitset = device.touchpad.action_is_pressed_bitset

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_raw_touchpad_moved :: proc(key: u64, pos: m.vec2) {
    device := input_device_get_checked(key, {.TOUCHPAD})
    new_pos := m.vec2{clamp(pos.x, 0, device.touchpad.dims.x), clamp(pos.y, 0, device.touchpad.dims.y)}

    e: Event
    e.type = .RAW_TOUCHPAD_MOVED
    e.touchpad_moved.device_id = key
    e.touchpad_moved.pos = new_pos
    e.touchpad_moved.rel_pos = new_pos - device.touchpad.pos

    queue.push(&zephr_ctx.event_queue, e)

    device.touchpad.pos = new_pos
    device.touchpad.rel_pos = device.touchpad.rel_pos + e.touchpad_moved.rel_pos
}

@(private)
os_event_queue_raw_accelerometer_changed :: proc(key: u64, accel: m.vec3) {
    device := input_device_get_checked(key, {.ACCELEROMETER})
    device.accelerometer = accel

    e: Event
    e.type = .RAW_ACCELEROMETER_CHANGED
    e.accelerometer.device_id = key
    e.accelerometer.accel = accel

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_raw_gyroscope_changed :: proc(key: u64, gyro: m.vec3) {
    device := input_device_get_checked(key, {.GYROSCOPE})
    device.gyroscope = gyro

    e: Event
    e.type = .RAW_GYROSCOPE_CHANGED
    e.gyroscope.device_id = key
    e.gyroscope.gyro = gyro

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_raw_mouse_button :: proc(key: u64, button: MouseButton, is_pressed: bool) {
    device := input_device_get_checked(key, {.MOUSE})
    if is_pressed {
        device.mouse.button_is_pressed_bitset |= {button}
        device.mouse.button_has_been_pressed_bitset |= {button}
    } else {
        device.mouse.button_is_pressed_bitset &= ~{button}
        device.mouse.button_has_been_released_bitset |= {button}
    }

    e: Event
    e.type = is_pressed ? .RAW_MOUSE_BUTTON_PRESSED : .RAW_MOUSE_BUTTON_RELEASED
    e.mouse_button.device_id = key
    e.mouse_button.button = button
    e.mouse_button.button_bitset = device.mouse.button_is_pressed_bitset

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_raw_mouse_moved :: proc(key: u64, rel_pos: m.vec2) {
    device := input_device_get_checked(key, {.MOUSE})

    e: Event
    e.type = .RAW_MOUSE_MOVED
    e.mouse_moved.device_id = key
    e.mouse_moved.pos = m.vec2{0, 0}
    e.mouse_moved.rel_pos = rel_pos

    queue.push(&zephr_ctx.event_queue, e)

    //
    // update the mouse state with the new location
    device.mouse.rel_pos = device.mouse.rel_pos + rel_pos
}

@(private)
os_event_queue_raw_mouse_scroll :: proc(key: u64, scroll_rel: m.vec2) {
    e: Event
    e.type = .RAW_MOUSE_SCROLL
    e.mouse_scroll.device_id = key
    e.mouse_scroll.scroll_rel = scroll_rel

    device := input_device_get_checked(key, {.MOUSE})
    device.mouse.scroll_rel = device.mouse.scroll_rel + scroll_rel
}

@(private)
os_event_queue_virt_mouse_button :: proc(button: MouseButton, is_pressed: bool) {
    e: Event
    e.type = is_pressed ? .VIRT_MOUSE_BUTTON_PRESSED : .VIRT_MOUSE_BUTTON_RELEASED
    e.mouse_button.device_id = 0
    e.mouse_button.button = button
    e.mouse_button.pos = zephr_ctx.virt_mouse.pos

    if is_pressed {
        zephr_ctx.virt_mouse.button_is_pressed_bitset |= {button}
        zephr_ctx.virt_mouse.button_has_been_pressed_bitset |= {button}
    } else {
        zephr_ctx.virt_mouse.button_is_pressed_bitset &= ~{button}
        zephr_ctx.virt_mouse.button_has_been_released_bitset |= {button}
    }

    e.mouse_button.button_bitset = zephr_ctx.virt_mouse.button_is_pressed_bitset

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_virt_mouse_scroll :: proc(scroll_rel: m.vec2) {
    zephr_ctx.virt_mouse.scroll_rel = scroll_rel

    e: Event
    e.type = .VIRT_MOUSE_SCROLL
    e.mouse_scroll.device_id = 0
    e.mouse_scroll.scroll_rel = scroll_rel

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_raw_key_changed :: proc(key: u64, is_pressed: bool, scancode: Scancode) {
    device := input_device_get_checked(key, {.KEYBOARD})

    // the platform window system must only send out repeated presses and not any repeated releases.
    // on linux we call XkbSetDetectableAutoRepeat to disable repeated KeyRelease events.
    // this allows us to simply check a repeat if the key is already pressed.
    is_repeat := is_pressed && bit_array.get(&device.keyboard.scancode_is_pressed_bitset, scancode)

    //
    // get the keycode from the scancode and see if it is a key modifier.
    keycode := zephr_ctx.keyboard_scancode_to_keycode[scancode]
    key_mod: KeyModBits
    #partial switch (keycode) {
        case .LEFT_CTRL:
            key_mod = .LEFT_CTRL
        case .RIGHT_CTRL:
            key_mod = .RIGHT_CTRL
        case .LEFT_SHIFT:
            key_mod = .LEFT_SHIFT
        case .RIGHT_SHIFT:
            key_mod = .RIGHT_SHIFT
        case .LEFT_ALT:
            key_mod = .LEFT_ALT
        case .RIGHT_ALT:
            key_mod = .RIGHT_ALT
        case .LEFT_META:
            key_mod = .LEFT_META
        case .RIGHT_META:
            key_mod = .RIGHT_META
    }

    //
    // if is_pressed -> mark the scancode, keycode and key_mod as _pressed_ in the keyboard state
    // else ->  mark the scancode, keycode and key_mod as _released_ in the keyboard state
    if (is_pressed) {
        device.keyboard.key_mod_is_pressed_bitset |= {key_mod}
        device.keyboard.key_mod_has_been_pressed_bitset |= {key_mod}
        bit_array.set(&device.keyboard.scancode_is_pressed_bitset, scancode)
        bit_array.set(&device.keyboard.scancode_has_been_pressed_bitset, scancode)
        bit_array.set(&device.keyboard.keycode_is_pressed_bitset, keycode)
        bit_array.set(&device.keyboard.keycode_has_been_pressed_bitset, keycode)
    } else {
        device.keyboard.key_mod_is_pressed_bitset &= ~{key_mod}
        device.keyboard.key_mod_has_been_released_bitset |= {key_mod}
        bit_array.unset(&device.keyboard.scancode_is_pressed_bitset, scancode)
        bit_array.set(&device.keyboard.scancode_has_been_released_bitset, scancode)
        bit_array.unset(&device.keyboard.keycode_is_pressed_bitset, keycode)
        bit_array.set(&device.keyboard.keycode_has_been_released_bitset, keycode)
    }

    e: Event
    e.type = is_pressed ? .RAW_KEY_PRESSED : .RAW_KEY_RELEASED
    e.key.device_id = key
    e.key.mods = device.keyboard.key_mod_is_pressed_bitset
    e.key.is_pressed = is_pressed
    e.key.is_repeat = is_repeat
    e.key.scancode = scancode
    e.key.keycode = keycode

    queue.push(&zephr_ctx.event_queue, e)
}

@(private)
os_event_queue_virt_key_changed :: proc(is_pressed: bool, scancode: Scancode) {
    // the platform window system must only send out repeated presses and not any repeated releases.
    // on linux we call XkbSetDetectableAutoRepeat to disable repeated KeyRelease events.
    // this allows us to simply check a repeat if the key is already pressed.
    is_repeat := is_pressed && bit_array.get(&zephr_ctx.virt_keyboard.scancode_is_pressed_bitset, scancode)

    //
    // get the keycode from the scancode and see if it is a key modifier.
    keycode := zephr_ctx.keyboard_scancode_to_keycode[scancode]
    key_mod: KeyModBits
    #partial switch (keycode) {
        case .LEFT_CTRL:
            key_mod = .LEFT_CTRL
        case .RIGHT_CTRL:
            key_mod = .RIGHT_CTRL
        case .LEFT_SHIFT:
            key_mod = .LEFT_SHIFT
        case .RIGHT_SHIFT:
            key_mod = .RIGHT_SHIFT
        case .LEFT_ALT:
            key_mod = .LEFT_ALT
        case .RIGHT_ALT:
            key_mod = .RIGHT_ALT
        case .LEFT_META:
            key_mod = .LEFT_META
        case .RIGHT_META:
            key_mod = .RIGHT_META
    }

    //
    // if is_pressed -> mark the scancode, keycode and key_mod as _pressed_ in the keyboard state
    // else ->  mark the scancode, keycode and key_mod as _released_ in the keyboard state
    if (is_pressed) {
        zephr_ctx.virt_keyboard.key_mod_is_pressed_bitset |= {key_mod}
        zephr_ctx.virt_keyboard.key_mod_has_been_pressed_bitset |= {key_mod}
        bit_array.set(&zephr_ctx.virt_keyboard.scancode_is_pressed_bitset, scancode)
        bit_array.set(&zephr_ctx.virt_keyboard.scancode_has_been_pressed_bitset, scancode)
        bit_array.set(&zephr_ctx.virt_keyboard.keycode_is_pressed_bitset, keycode)
        bit_array.set(&zephr_ctx.virt_keyboard.keycode_has_been_pressed_bitset, keycode)
    } else {
        zephr_ctx.virt_keyboard.key_mod_is_pressed_bitset &= ~{key_mod}
        zephr_ctx.virt_keyboard.key_mod_has_been_released_bitset |= {key_mod}
        bit_array.unset(&zephr_ctx.virt_keyboard.scancode_is_pressed_bitset, scancode)
        bit_array.set(&zephr_ctx.virt_keyboard.scancode_has_been_released_bitset, scancode)
        bit_array.unset(&zephr_ctx.virt_keyboard.keycode_is_pressed_bitset, keycode)
        bit_array.set(&zephr_ctx.virt_keyboard.keycode_has_been_released_bitset, keycode)
    }

    e: Event
    e.type = is_pressed ? .VIRT_KEY_PRESSED : .VIRT_KEY_RELEASED
    e.key.device_id = 0
    e.key.mods = zephr_ctx.virt_keyboard.key_mod_is_pressed_bitset
    e.key.is_pressed = is_pressed
    e.key.is_repeat = is_repeat
    e.key.scancode = scancode
    e.key.keycode = keycode

    queue.push(&zephr_ctx.event_queue, e)
}

@(private, disabled = RELEASE_BUILD)
os_event_queue_drag_and_drop_file :: proc(paths: []string) {
    e: Event
    e.type = .FILE_DROP
    e.file_drop.paths = paths

    queue.push(&zephr_ctx.event_queue, e)
}


/////////////////////////////
//
//
// Utils
//
//
/////////////////////////////


@(private = "file")
fnv_hash32 :: proc(data: []byte, size: u64, hash: u32) -> u32 {
    hash := hash

    for i in 0 ..< size {
        hash ~= cast(u32)data[i]
        hash *= FNV_HASH32_PRIME
    }

    return hash
}

@(private = "file")
fnv_hash32_multipointer :: proc(data: [^]byte, size: u64, hash: u32) -> u32 {
    hash := hash

    for i in 0 ..< size {
        hash ~= cast(u32)data[i]
        hash *= FNV_HASH32_PRIME
    }

    return hash
}

@(private = "file")
fnv_hash64 :: proc(data: []byte, size: u64, hash: u64) -> u64 {
    hash := hash

    for i in 0 ..< size {
        hash ~= cast(u64)data[i]
        hash *= FNV_HASH64_PRIME
    }

    return hash
}

@(private = "file")
fnv_hash64_multipointer :: proc(data: [^]byte, size: u64, hash: u64) -> u64 {
    hash := hash

    for i in 0 ..< size {
        hash ~= cast(u64)data[i]
        hash *= FNV_HASH64_PRIME
    }

    return hash
}

fnv_hash :: proc{fnv_hash32, fnv_hash32_multipointer, fnv_hash64, fnv_hash64_multipointer}

@(private)
logger_init :: proc() {
    log_file, err := os.open("zephr.log", os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.eprintln("[ERROR] Failed to open log file. Logs will not be written")
        return
    }

    file_logger := log.create_file_logger(log_file)
    term_logger := log.create_console_logger(opt = TerminalLoggerOpts)

    logger = log.create_multi_logger(file_logger, term_logger)
}

@(private)
relative_path :: proc(path: string) -> string {
    return filepath.join([]string{engine_rel_path, path})
}

@(private)
create_resource_path :: proc(path: string) -> string {
    when RELEASE_BUILD { // We want a relative path for builds that we distribute
        return path
    } else {
        return filepath.join({engine_rel_path, path})
    }
}

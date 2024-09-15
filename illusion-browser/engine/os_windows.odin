//+build windows
//+private
package zephr

import "base:runtime"
import "core:container/bit_array"
import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math/bits"
import m "core:math/linalg/glsl"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:strconv"
import "core:strings"
import win32 "core:sys/windows"
import "core:time"

import gl "vendor:OpenGL"

// TODO: Moving a window that was created on a 1080 monitor to a 768 monitor cuts off the viewport from the top
// and possibly other sides. Fix that
// TODO: watch the shaders directory for hot-reloading
// BUG: setting the cursor every frame messes with the cursor for resizing when on the edge of the window
// TODO: handle start window in fullscreen
//       currently the way to "start" a window in fullscreen is to just create a regular window
//       and immediately fullscreen it. This works fine but there's a moment where you can see the regular-sized window.
//       Not a priority right now.
// TODO: only log debug when RELEASE_BUILD is false

@(private = "file")
GamepadActionPair :: struct {
    pos: GamepadAction,
    neg: GamepadAction,
}

@(private = "file")
WindowsGamepadActionInfo :: struct {
    bit_count:   u32,
    action_pair: GamepadActionPair,
}

#assert(size_of(WindowsInputDevice) == OS_INPUT_DEVICE_BACKEND_SIZE)

@(private = "file")
WindowsInputDevice :: struct {
    raw_input_device_handle: win32.HANDLE,
    hid_device_handle:       win32.HANDLE,
    preparsed_data:          win32.PHIDP_PREPARSED_DATA,
    preparsed_data_size:     u64,
    button_caps:             [^]win32.HIDP_BUTTON_CAPS,
    button_caps_count:       u16,
    value_caps:              [^]win32.HIDP_VALUE_CAPS,
    value_caps_count:        u16,
    gamepad_button_bindings: Bindings,
    found_e11d:              bool, // used for pause key as it can only be recognised with 2 events
}

@(private = "file")
Bindings :: struct {
    buttons:   []GamepadAction,
    hatswitch: []bit_set[GamepadAction],
    axes:      []GamepadActionPair,
}

OsCursor :: win32.HCURSOR

@(private = "file")
HID_STRING_CAP :: 2048
// 4093 comes from: https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidsdi/nf-hidsdi-hidd_getproductstring
@(private = "file")
HID_STRING_BYTE_CAP :: 4093

// I think these are just the XInput driver mapping
@(private = "file")
Xbox_Series_S_Button_Mapping := []GamepadAction {
    0  = .NONE,
    1  = .FACE_DOWN,
    2  = .FACE_RIGHT,
    3  = .FACE_LEFT,
    4  = .FACE_UP,
    5  = .SHOULDER_LEFT,
    6  = .SHOULDER_RIGHT,
    7  = .SELECT,
    8  = .START,
    9  = .STICK_LEFT,
    10 = .STICK_RIGHT,
}

@(private = "file")
Xbox_Series_S_Axis_Mapping := []GamepadActionPair {
    win32.HID_USAGE_GENERIC_X  = {.STICK_LEFT_X_EAST, .STICK_LEFT_X_WEST},
    win32.HID_USAGE_GENERIC_Y  = {.STICK_LEFT_Y_SOUTH, .STICK_LEFT_Y_NORTH},
    win32.HID_USAGE_GENERIC_RX = {.STICK_RIGHT_X_EAST, .STICK_RIGHT_X_WEST},
    win32.HID_USAGE_GENERIC_RY = {.STICK_RIGHT_Y_SOUTH, .STICK_RIGHT_Y_NORTH},
    win32.HID_USAGE_GENERIC_Z  = {.TRIGGER_LEFT, .TRIGGER_RIGHT},
}

@(private = "file")
Xbox_Series_S_Hatswitch_Mapping := []bit_set[GamepadAction] {
    1 = {.DPAD_UP},
    2 = {.DPAD_UP, .DPAD_RIGHT},
    3 = {.DPAD_RIGHT},
    4 = {.DPAD_RIGHT, .DPAD_DOWN},
    5 = {.DPAD_DOWN},
    6 = {.DPAD_DOWN, .DPAD_LEFT},
    7 = {.DPAD_LEFT},
    8 = {.DPAD_LEFT, .DPAD_UP},
}

@(private = "file")
DS3_Button_Mapping := []GamepadAction {
    0 = .NONE,
    1 = .FACE_UP,
    2 = .FACE_RIGHT,
    3 = .FACE_DOWN,
    4 = .FACE_LEFT,
    5 = .NONE, // TRIGGER_LEFT
    6 = .NONE, // TRIGGER_RIGHT
    7 = .SHOULDER_LEFT,
    8 = .SHOULDER_RIGHT,
    9 = .START,
    10 = .SELECT,
    11 = .STICK_LEFT,
    12 = .STICK_RIGHT,
    13 = .SYSTEM,
}

DS3_Axis_Mapping := []GamepadActionPair {
    // NOTE: No idea what this axis is for
    win32.HID_USAGE_GENERIC_SLIDER = {.NONE, .NONE},
    win32.HID_USAGE_GENERIC_X  = {.STICK_LEFT_X_EAST, .STICK_LEFT_X_WEST},
    win32.HID_USAGE_GENERIC_Y  = {.STICK_LEFT_Y_SOUTH, .STICK_LEFT_Y_NORTH},
    win32.HID_USAGE_GENERIC_RX = {.TRIGGER_LEFT, .NONE},
    win32.HID_USAGE_GENERIC_RY = {.TRIGGER_RIGHT, .NONE},
    win32.HID_USAGE_GENERIC_Z  = {.STICK_RIGHT_X_EAST, .STICK_RIGHT_X_WEST},
    win32.HID_USAGE_GENERIC_RZ = {.STICK_RIGHT_Y_SOUTH, .STICK_RIGHT_Y_NORTH},
}

@(private = "file")
DS3_Hatswitch_Mapping := []bit_set[GamepadAction] {
    0 = {.DPAD_UP},
    1 = {.DPAD_UP, .DPAD_RIGHT},
    2 = {.DPAD_RIGHT},
    3 = {.DPAD_RIGHT, .DPAD_DOWN},
    4 = {.DPAD_DOWN},
    5 = {.DPAD_DOWN, .DPAD_LEFT},
    6 = {.DPAD_LEFT},
    7 = {.DPAD_LEFT, .DPAD_UP},
    8 = {.NONE},
}

@(private = "file")
DS4_Button_Mapping := []GamepadAction {
    0  = .NONE,
    1  = .FACE_LEFT,
    2  = .FACE_DOWN,
    3  = .FACE_RIGHT,
    4  = .FACE_UP,
    5  = .SHOULDER_LEFT,
    6  = .SHOULDER_RIGHT,
    // Ignore the triggers because they're axes not buttons.
    7  = .NONE, // TRIGGER_LEFT
    8  = .NONE, // TRIGGER_RIGHT
    9  = .SELECT,
    10 = .START,
    11 = .STICK_LEFT,
    12 = .STICK_RIGHT,
    13 = .SYSTEM,
    // Ignored because we get the click from the touchpad events of the DS4.
    14 = .NONE, // Touchpad click.
}

@(private = "file")
DS4_Axis_Mapping := []GamepadActionPair {
    win32.HID_USAGE_GENERIC_X  = {.STICK_LEFT_X_EAST, .STICK_LEFT_X_WEST},
    win32.HID_USAGE_GENERIC_Y  = {.STICK_LEFT_Y_SOUTH, .STICK_LEFT_Y_NORTH},
    win32.HID_USAGE_GENERIC_RX = {.TRIGGER_LEFT, .NONE},
    win32.HID_USAGE_GENERIC_RY = {.TRIGGER_RIGHT, .NONE},
    win32.HID_USAGE_GENERIC_Z  = {.STICK_RIGHT_X_EAST, .STICK_RIGHT_X_WEST},
    win32.HID_USAGE_GENERIC_RZ = {.STICK_RIGHT_Y_SOUTH, .STICK_RIGHT_Y_NORTH},
}

@(private = "file")
DS4_Hatswitch_Mapping := []bit_set[GamepadAction] {
    0 = {.DPAD_UP},
    1 = {.DPAD_UP, .DPAD_RIGHT},
    2 = {.DPAD_RIGHT},
    3 = {.DPAD_RIGHT, .DPAD_DOWN},
    4 = {.DPAD_DOWN},
    5 = {.DPAD_DOWN, .DPAD_LEFT},
    6 = {.DPAD_LEFT},
    7 = {.DPAD_LEFT, .DPAD_UP},
    8 = {.NONE},
}

@(private = "file")
Switch_Button_Mapping := []GamepadAction{} // TODO: requires handshake and other stuff
@(private = "file")
Switch_Hatswitch_Mapping := []bit_set[GamepadAction]{} // TODO:
@(private = "file")
Switch_Axis_Mapping := []GamepadActionPair{} // TODO:

@(private = "file")
SupportedControllers := map[u32]Bindings {
    //0x045E_0202 = Xbox_One_Button_Mapping, // XBox Controller
    //0x045E_0285 = Xbox_One_Button_Mapping, // XBox Controller S
    //0x045E_0289 = Xbox_One_Button_Mapping, // XBox Controller S
    //0x045E_028E = Xbox_One_Button_Mapping, // XBox 360 Controller
    //0x045E_028F = Xbox_One_Button_Mapping, // XBox 360 Wireless Controller
    //0x045E_02D1 = Xbox_One_Button_Mapping, // XBox One Controller
    //0x045E_02DD = Xbox_One_Button_Mapping, // XBox One Controller (Firmware 2015)
    //0x045E_02E0 = Xbox_One_Button_Mapping, // XBox One Wireless Controller
    //0x045E_02E3 = Xbox_One_Button_Mapping, // XBox One Elite Controller
    //0x045E_02EA = Xbox_One_Button_Mapping, // XBox One Controller
    //0x045E_02FD = Xbox_One_Button_Mapping, // XBox One S Controller [Bluetooth]
    0x045E_02FF = {Xbox_Series_S_Button_Mapping, Xbox_Series_S_Hatswitch_Mapping, Xbox_Series_S_Axis_Mapping}, // XBox S Controller [Bluetooth]
    //0x045E_0B00 = Xbox_One_Button_Mapping, // XBox Elite Series 2 Controller (model 1797)
    //0x045E_0B12 = Xbox_One_Button_Mapping, // XBox Controller
    0x045E_0B13 = {Xbox_Series_S_Button_Mapping, Xbox_Series_S_Hatswitch_Mapping, Xbox_Series_S_Axis_Mapping}, // XBox Series X|S Controller Wireless
    0x054C_05C4 = {DS4_Button_Mapping, DS4_Hatswitch_Mapping, DS4_Axis_Mapping}, // DS4 Gen 1
    0x054C_09CC = {DS4_Button_Mapping, DS4_Hatswitch_Mapping, DS4_Axis_Mapping}, // DS4 Gen 2
    0x054C_0CE6 = {DS4_Button_Mapping, DS4_Hatswitch_Mapping, DS4_Axis_Mapping}, // PS5 DualSense
    //0x054C_0DF2 = DS5_Button_Mapping, // PS5 DualSense Edge (TODO: Could have extra buttons/axes)
    //0x057E_2009 = {Switch_Button_Mapping, Switch_Hatswitch_Mapping, Switch_Axis_Mapping}, // Switch Pro Controller
    0x7331_0002 = {Xbox_Series_S_Button_Mapping, Xbox_Series_S_Hatswitch_Mapping, Xbox_Series_S_Axis_Mapping}, // DS3 over DsHidMini as XInput
    0x054C_0268 = {DS3_Button_Mapping, DS3_Hatswitch_Mapping, DS3_Axis_Mapping}, // Genuine Sony DualShock 3 over DsHidMini Wired
}

@(private = "file")
WindowsEvent :: struct {
    type:   win32.UINT,
    lparam: win32.LPARAM,
    wparam: win32.WPARAM,
}

@(private = "file")
Os :: struct {
    hwnd:             win32.HWND,
    device_ctx:       win32.HDC,
    wgl_context:      win32.HGLRC,
    invisible_cursor: win32.HCURSOR,
    wglSwapIntervalEXT: win32.SwapIntervalEXTType,
    events:           queue.Queue(WindowsEvent),
}

@(private = "file")
w_os: Os

@(private = "file")
temp_hwnd: win32.HWND
@(private = "file")
temp_device_ctx: win32.HDC
@(private = "file")
temp_wgl_context: win32.HGLRC

@(private = "file")
win32_scancode_to_zephr_scancode_map := []Scancode {
    .NULL, // NULL
    .ESCAPE,
    .KEY_1,
    .KEY_2,
    .KEY_3,
    .KEY_4,
    .KEY_5,
    .KEY_6,
    .KEY_7,
    .KEY_8,
    .KEY_9,
    .KEY_0,
    .MINUS,
    .EQUALS,
    .BACKSPACE,
    .TAB,
    .Q,
    .W,
    .E,
    .R,
    .T,
    .Y,
    .U,
    .I,
    .O,
    .P,
    .LEFT_BRACKET,
    .RIGHT_BRACKET,
    .ENTER,
    .LEFT_CTRL,
    .A,
    .S,
    .D,
    .F,
    .G,
    .H,
    .J,
    .K,
    .L,
    .SEMICOLON,
    .APOSTROPHE,
    .GRAVE,
    .LEFT_SHIFT,
    .BACKSLASH,
    .Z,
    .X,
    .C,
    .V,
    .B,
    .N,
    .M,
    .COMMA,
    .PERIOD,
    .SLASH,
    .RIGHT_SHIFT,
    .KP_MULTIPLY,
    .LEFT_ALT,
    .SPACE,
    .CAPS_LOCK,
    .F1,
    .F2,
    .F3,
    .F4,
    .F5,
    .F6,
    .F7,
    .F8,
    .F9,
    .F10,
    .NUM_LOCK_OR_CLEAR,
    .SCROLL_LOCK,
    .KP_7,
    .KP_8,
    .KP_9,
    .KP_MINUS,
    .KP_4,
    .KP_5,
    .KP_6,
    .KP_PLUS,
    .KP_1,
    .KP_2,
    .KP_3,
    .KP_0,
    .KP_PERIOD,
    .PRINT_SCREEN, // ALT + PRINTSCREEN
    .NULL,
    .NON_US_HASH, // bracket angle
    .F11,
    .F12,
    .KP_EQUALS,
    .NULL, // OEM_1
    .NULL, // OEM_2
    .NULL, // OEM_3
    .NULL, // ERASEEOF
    .NULL, // OEM_4
    .NULL, // OEM_5
    .NULL,
    .NULL,
    .NULL, // ZOOM
    .HELP,
    .F13,
    .F14,
    .F15,
    .F16,
    .F17,
    .F18,
    .F19,
    .F20,
    .F21,
    .F22,
    .F23,
    .NULL, // OEM_6
    .NULL, // KATAKANA
    .NULL, // OEM_7
    .NULL,
    .NULL,
    .NULL,
    .NULL,
    .F24,
    .NULL, // SBCSCHAR
    .NULL,
    .NULL, // CONVERT
    .NULL,
    .NULL, // NONCONVERT
}

@(private = "file")
win32_scancode_0xe000_to_zephr_scancode_map := []Scancode {
    0x10 = .NULL, // MEDIA_PREVIOUS
    0x19 = .NULL, // MEDIA_NEXT
    0x1C = .KP_ENTER,
    0x1D = .RIGHT_CTRL,
    0x20 = .MUTE,
    0x21 = .NULL, // LAUNCH_APP2
    0x22 = .NULL, // MEDIA_PLAY
    0x24 = .NULL, // MEDIA_STOP
    0x2E = .VOLUME_DOWN,
    0x30 = .VOLUME_UP,
    0x32 = .NULL, // BROWSER_HOME
    0x35 = .KP_DIVIDE,
    /*
	sc_printScreen:
	- make: 0xE02A 0xE037
	- break: 0xE0B7 0xE0AA
	- MapVirtualKeyEx( VK_SNAPSHOT, MAPVK_VK_TO_VSC_EX, 0 ) returns scancode 0x54;
	- There is no VK_KEYDOWN with VK_SNAPSHOT.
	*/
    0x37 = .PRINT_SCREEN,
    0x38 = .RIGHT_ALT,
    0x46 = .CANCEL, /* CTRL + Pause */
    0x47 = .HOME,
    0x48 = .UP,
    0x49 = .PAGE_UP,
    0x4B = .LEFT,
    0x4D = .RIGHT,
    0x4F = .END,
    0x50 = .DOWN,
    0x51 = .PAGE_DOWN,
    0x52 = .INSERT,
    0x53 = .DELETE,
    0x5B = .LEFT_META,
    0x5C = .RIGHT_META,
    0x5D = .APPLICATION,
    0x5E = .POWER,
    0x5F = .NULL, // SLEEP
    0x63 = .NULL, // WAKE
    0x65 = .NULL, // BROWSER_SEARCH
    0x66 = .NULL, // BROWSER_FAVORITES
    0x67 = .NULL, // BROWSER_REFRESH
    0x68 = .NULL, // BROWSER_STOP
    0x69 = .NULL, // BROWSER_FORWARD
    0x6A = .NULL, // BROWSER_BACK
    0x6B = .NULL, // LAUNCH_APP1
    0x6C = .NULL, // LAUNCH_EMAIL
    0x6D = .NULL, // LAUNCH_MEDIA
}

@(private = "file")
win32_keycode_to_zephr_keycode_map := []Keycode {
    win32.VK_LBUTTON             = .NULL,
    win32.VK_RBUTTON             = .NULL,
    win32.VK_CANCEL              = .CANCEL,
    win32.VK_MBUTTON             = .NULL,
    win32.VK_XBUTTON1            = .NULL,
    win32.VK_XBUTTON2            = .NULL,
    win32.VK_BACK                = .BACKSPACE,
    win32.VK_TAB                 = .TAB,
    win32.VK_CLEAR               = .CLEAR,
    win32.VK_RETURN              = .ENTER,
    win32.VK_SHIFT               = .LEFT_SHIFT,
    win32.VK_CONTROL             = .LEFT_CTRL,
    win32.VK_MENU                = .LEFT_ALT,
    win32.VK_PAUSE               = .PAUSE,
    win32.VK_CAPITAL             = .NULL,
    win32.VK_KANA                = .NULL,
    win32.VK_IME_ON              = .NULL,
    win32.VK_JUNJA               = .NULL,
    win32.VK_FINAL               = .NULL,
    win32.VK_HANJA               = .NULL,
    win32.VK_IME_OFF             = .NULL,
    win32.VK_ESCAPE              = .ESCAPE,
    win32.VK_CONVERT             = .NULL,
    win32.VK_NONCONVERT          = .NULL,
    win32.VK_ACCEPT              = .NULL,
    win32.VK_MODECHANGE          = .NULL,
    win32.VK_SPACE               = .SPACE,
    win32.VK_PRIOR               = .PRIOR,
    win32.VK_NEXT                = .NULL,
    win32.VK_END                 = .END,
    win32.VK_HOME                = .HOME,
    win32.VK_LEFT                = .LEFT,
    win32.VK_UP                  = .UP,
    win32.VK_RIGHT               = .RIGHT,
    win32.VK_DOWN                = .DOWN,
    win32.VK_SELECT              = .SELECT,
    win32.VK_PRINT               = .PRINT_SCREEN,
    win32.VK_EXECUTE             = .EXECUTE,
    win32.VK_SNAPSHOT            = .NULL,
    win32.VK_INSERT              = .INSERT,
    win32.VK_DELETE              = .DELETE,
    win32.VK_HELP                = .HELP,
    '0'                          = .KEY_0,
    '1'                          = .KEY_1,
    '2'                          = .KEY_2,
    '3'                          = .KEY_3,
    '4'                          = .KEY_4,
    '5'                          = .KEY_5,
    '6'                          = .KEY_6,
    '7'                          = .KEY_7,
    '8'                          = .KEY_8,
    '9'                          = .KEY_9,
    'A'                          = .A,
    'B'                          = .B,
    'C'                          = .C,
    'D'                          = .D,
    'E'                          = .E,
    'F'                          = .F,
    'G'                          = .G,
    'H'                          = .H,
    'I'                          = .I,
    'J'                          = .J,
    'K'                          = .K,
    'L'                          = .L,
    'M'                          = .M,
    'N'                          = .N,
    'O'                          = .O,
    'P'                          = .P,
    'Q'                          = .Q,
    'R'                          = .R,
    'S'                          = .S,
    'T'                          = .T,
    'U'                          = .U,
    'V'                          = .V,
    'W'                          = .W,
    'X'                          = .X,
    'Y'                          = .Y,
    'Z'                          = .Z,
    win32.VK_LWIN                = .LEFT_META,
    win32.VK_RWIN                = .RIGHT_META,
    win32.VK_APPS                = .NULL,
    win32.VK_SLEEP               = .NULL,
    win32.VK_NUMPAD0             = .KP_0,
    win32.VK_NUMPAD1             = .KP_1,
    win32.VK_NUMPAD2             = .KP_2,
    win32.VK_NUMPAD3             = .KP_3,
    win32.VK_NUMPAD4             = .KP_4,
    win32.VK_NUMPAD5             = .KP_5,
    win32.VK_NUMPAD6             = .KP_6,
    win32.VK_NUMPAD7             = .KP_7,
    win32.VK_NUMPAD8             = .KP_8,
    win32.VK_NUMPAD9             = .KP_9,
    win32.VK_MULTIPLY            = .KP_MULTIPLY,
    win32.VK_ADD                 = .KP_PLUS,
    win32.VK_SEPARATOR           = .SEPARATOR,
    win32.VK_SUBTRACT            = .KP_MINUS,
    win32.VK_DECIMAL             = .KP_DECIMAL,
    win32.VK_DIVIDE              = .KP_DIVIDE,
    win32.VK_F1                  = .F1,
    win32.VK_F2                  = .F2,
    win32.VK_F3                  = .F3,
    win32.VK_F4                  = .F4,
    win32.VK_F5                  = .F5,
    win32.VK_F6                  = .F6,
    win32.VK_F7                  = .F7,
    win32.VK_F8                  = .F8,
    win32.VK_F9                  = .F9,
    win32.VK_F10                 = .F10,
    win32.VK_F11                 = .F11,
    win32.VK_F12                 = .F12,
    win32.VK_F13                 = .F13,
    win32.VK_F14                 = .F14,
    win32.VK_F15                 = .F15,
    win32.VK_F16                 = .F16,
    win32.VK_F17                 = .F17,
    win32.VK_F18                 = .F18,
    win32.VK_F19                 = .F19,
    win32.VK_F20                 = .F20,
    win32.VK_F21                 = .F21,
    win32.VK_F22                 = .F22,
    win32.VK_F23                 = .F23,
    win32.VK_F24                 = .F24,
    0x88                         = .NULL, // VK_NAVIGATION_VIEW
    0x89                         = .APPLICATION, // VK_NAVIGATION_MENU
    0x8A                         = .UP, // VK_NAVIGATION_UP
    0x8B                         = .DOWN, // VK_NAVIGATION_DOWN
    0x8C                         = .LEFT, // VK_NAVIGATION_LEFT
    0x8D                         = .RIGHT, // VK_NAVIGATION_RIGHT
    0x8E                         = .NULL, // VK_NAVIGATION_ACCPET
    0x8F                         = .NULL, // VK_NAVIGATION_CANCEL
    win32.VK_NUMLOCK             = .NUM_LOCK_OR_CLEAR,
    win32.VK_SCROLL              = .SCROLL_LOCK,
    win32.VK_OEM_NEC_EQUAL       = .NULL,
    win32.VK_OEM_FJ_MASSHOU      = .NULL,
    win32.VK_OEM_FJ_TOUROKU      = .NULL,
    win32.VK_OEM_FJ_LOYA         = .NULL,
    win32.VK_OEM_FJ_ROYA         = .NULL,
    win32.VK_LSHIFT              = .LEFT_SHIFT,
    win32.VK_RSHIFT              = .RIGHT_SHIFT,
    win32.VK_LCONTROL            = .LEFT_CTRL,
    win32.VK_RCONTROL            = .RIGHT_CTRL,
    win32.VK_LMENU               = .NULL,
    win32.VK_RMENU               = .NULL,
    win32.VK_BROWSER_BACK        = .NULL,
    win32.VK_BROWSER_FORWARD     = .NULL,
    win32.VK_BROWSER_REFRESH     = .NULL,
    win32.VK_BROWSER_STOP        = .NULL,
    win32.VK_BROWSER_SEARCH      = .NULL,
    win32.VK_BROWSER_FAVORITES   = .NULL,
    win32.VK_BROWSER_HOME        = .NULL,
    win32.VK_VOLUME_MUTE         = .MUTE,
    win32.VK_VOLUME_DOWN         = .VOLUME_DOWN,
    win32.VK_VOLUME_UP           = .VOLUME_UP,
    win32.VK_MEDIA_NEXT_TRACK    = .NULL,
    win32.VK_MEDIA_PREV_TRACK    = .NULL,
    win32.VK_MEDIA_STOP          = .NULL,
    win32.VK_MEDIA_PLAY_PAUSE    = .NULL,
    win32.VK_LAUNCH_MAIL         = .NULL,
    win32.VK_LAUNCH_MEDIA_SELECT = .NULL,
    win32.VK_LAUNCH_APP1         = .NULL,
    win32.VK_LAUNCH_APP2         = .NULL,
    win32.VK_OEM_1               = .SEMICOLON,
    win32.VK_OEM_PLUS            = .NULL,
    win32.VK_OEM_COMMA           = .NULL,
    win32.VK_OEM_MINUS           = .NULL,
    win32.VK_OEM_PERIOD          = .NULL,
    win32.VK_OEM_2               = .NULL,
    win32.VK_OEM_3               = .NULL,
    0xC3                         = .NULL, // VK_GAMEPAD_A
    0xC4                         = .NULL, // VK_GAMEPAD_B
    0xC5                         = .NULL, // VK_GAMEPAD_X
    0xC6                         = .NULL, // VK_GAMEPAD_Y
    0xC7                         = .NULL, // VK_GAMEPAD_RIGHT_SHOULDER
    0xC8                         = .NULL, // VK_GAMEPAD_LEFT_SHOULDER
    0xC9                         = .NULL, // VK_GAMEPAD_LEFT_TRIGGER
    0xCA                         = .NULL, // VK_GAMEPAD_RIGHT_TRIGGER
    0xCB                         = .NULL, // VK_GAMEPAD_DPAD_UP
    0xCC                         = .NULL, // VK_GAMEPAD_DPAD_DOWN
    0xCD                         = .NULL, // VK_GAMEPAD_DPAD_LEFT
    0xCE                         = .NULL, // VK_GAMEPAD_DPAD_RIGHT
    0xCF                         = .NULL, // VK_GAMEPAD_MENU
    0xD0                         = .NULL, // VK_GAMEPAD_VIEW
    0xD1                         = .NULL, // VK_GAMEPAD_LEFT_THUMBSTICK_BUTTON
    0xD2                         = .NULL, // VK_GAMEPAD_RIGHT_THUMBSTICK_BUTTON
    0xD3                         = .NULL, // VK_GAMEPAD_LEFT_THUMBSTICK_UP
    0xD4                         = .NULL, // VK_GAMEPAD_LEFT_THUMBSTICK_DOWN
    0xD5                         = .NULL, // VK_GAMEPAD_LEFT_THUMBSTICK_RIGHT
    0xD6                         = .NULL, // VK_GAMEPAD_LEFT_THUMBSTICK_LEFT
    0xD7                         = .NULL, // VK_GAMEPAD_RIGHT_THUMBSTICK_UP
    0xD8                         = .NULL, // VK_GAMEPAD_RIGHT_THUMBSTICK_DOWN
    0xD9                         = .NULL, // VK_GAMEPAD_RIGHT_THUMBSTICK_RIGHT
    0xDA                         = .NULL, // VK_GAMEPAD_RIGHT_THUMBSTICK_LEFT
    win32.VK_OEM_4               = .NULL,
    win32.VK_OEM_5               = .NULL,
    win32.VK_OEM_6               = .NULL,
    win32.VK_OEM_7               = .NULL,
    win32.VK_OEM_8               = .NULL,
    win32.VK_OEM_AX              = .NULL,
    win32.VK_OEM_102             = .NULL,
    win32.VK_ICO_HELP            = .NULL,
    win32.VK_ICO_00              = .NULL,
    win32.VK_PROCESSKEY          = .NULL,
    win32.VK_ICO_CLEAR           = .NULL,
    win32.VK_PACKET              = .NULL,
    win32.VK_OEM_RESET           = .NULL,
    win32.VK_OEM_JUMP            = .NULL,
    win32.VK_OEM_PA1             = .NULL,
    win32.VK_OEM_PA2             = .NULL,
    win32.VK_OEM_PA3             = .NULL,
    win32.VK_OEM_WSCTRL          = .NULL,
    win32.VK_OEM_CUSEL           = .NULL,
    win32.VK_OEM_ATTN            = .NULL,
    win32.VK_OEM_FINISH          = .NULL,
    win32.VK_OEM_COPY            = .NULL,
    win32.VK_OEM_AUTO            = .NULL,
    win32.VK_OEM_ENLW            = .NULL,
    win32.VK_OEM_BACKTAB         = .NULL,
    win32.VK_ATTN                = .NULL,
    win32.VK_CRSEL               = .CRSEL,
    win32.VK_EXSEL               = .EXSEL,
    win32.VK_EREOF               = .NULL,
    win32.VK_PLAY                = .NULL,
    win32.VK_ZOOM                = .NULL,
    win32.VK_NONAME              = .NULL,
    win32.VK_PA1                 = .NULL,
    win32.VK_OEM_CLEAR           = .NULL,
}

// https://learn.microsoft.com/en-us/windows/win32/inputdev/about-keyboard-input#scan-codes
// https://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/translate.pdf
@(private = "file")
scan1_scancode_to_zephr_scancode_map :: proc(scancode: u8, is_extended: bool) -> Scancode {
    switch scancode {
        case 0:
            return .NULL

        case 0x1E:
            return .A
        case 0x30:
            return .B
        case 0x2E:
            return .C
        case 0x20:
            return .D
        case 0x12:
            return .E
        case 0x21:
            return .F
        case 0x22:
            return .G
        case 0x23:
            return .H
        case 0x17:
            return .I
        case 0x24:
            return .J
        case 0x25:
            return .K
        case 0x26:
            return .L
        case 0x32:
            return .M
        case 0x31:
            return .N
        case 0x18:
            return .O
        case 0x19:
            return .P
        case 0x10:
            return .Q
        case 0x13:
            return .R
        case 0x1F:
            return .S
        case 0x14:
            return .T
        case 0x16:
            return .U
        case 0x2F:
            return .V
        case 0x11:
            return .W
        case 0x2D:
            return .X
        case 0x15:
            return .Y
        case 0x2C:
            return .Z

        case 0x02:
            return .KEY_1
        case 0x03:
            return .KEY_2
        case 0x04:
            return .KEY_3
        case 0x05:
            return .KEY_4
        case 0x06:
            return .KEY_5
        case 0x07:
            return .KEY_6
        case 0x08:
            return .KEY_7
        case 0x09:
            return .KEY_8
        case 0x0A:
            return .KEY_9
        case 0x0B:
            return .KEY_0

        case 0x1C:
            return .KP_ENTER if is_extended else .ENTER
        case 0x01:
            return .ESCAPE
        case 0x0E:
            return .BACKSPACE // Says "Keyboard Delete" on microsoft.com but it's actually backspace
        case 0x0F:
            return .TAB
        case 0x39:
            return .SPACE

        case 0x0C:
            return .MINUS
        case 0x0D:
            return .EQUALS
        case 0x1A:
            return .LEFT_BRACKET
        case 0x1B:
            return .RIGHT_BRACKET
        case 0x2B:
            return .BACKSLASH
        //case 0x2B: return = .NON_US_HASH, // European keyboards have a hash instead of a backslash. Maps to a different HID scancode
        case 0x27:
            return .SEMICOLON
        case 0x28:
            return .APOSTROPHE
        case 0x29:
            return .GRAVE
        case 0x33:
            return .COMMA
        case 0x34:
            return .PERIOD
        case 0x35:
            return .KP_DIVIDE if is_extended else .SLASH

        case 0x3A:
            return .CAPS_LOCK

        case 0x3B:
            return .F1
        case 0x3C:
            return .F2
        case 0x3D:
            return .F3
        case 0x3E:
            return .F4
        case 0x3F:
            return .F5
        case 0x40:
            return .F6
        case 0x41:
            return .F7
        case 0x42:
            return .F8
        case 0x43:
            return .F9
        case 0x44:
            return .F10
        case 0x57:
            return .F11
        case 0x58:
            return .F12

        case 0x54:
            return .PRINT_SCREEN // Only emitted on KeyRelease
        case 0x46:
            return .PAUSE if is_extended else .SCROLL_LOCK
        case 0x45:
            return .NUM_LOCK_OR_CLEAR if is_extended else .PAUSE
        //case 0xE11D45 = .PAUSE, // Some legacy stuff ???
        case 0x52:
            return .INSERT if is_extended else .KP_0
        case 0x47:
            return .HOME if is_extended else .KP_7
        case 0x49:
            return .PAGE_UP if is_extended else .KP_9
        case 0x53:
            return .DELETE if is_extended else .KP_PERIOD
        case 0x4F:
            return .END if is_extended else .KP_1
        case 0x51:
            return .PAGE_DOWN if is_extended else .KP_3
        case 0x4D:
            return .RIGHT if is_extended else .KP_6
        case 0x4B:
            return .LEFT if is_extended else .KP_4
        case 0x50:
            return .DOWN if is_extended else .KP_2
        case 0x48:
            return .UP if is_extended else .KP_8
        case 0x37:
            return .PRINT_SCREEN if is_extended else .KP_MULTIPLY
        case 0x4A:
            return .KP_MINUS
        case 0x4E:
            return .KP_PLUS
        case 0x4C:
            return .KP_5

        case 0x56:
            return .NON_US_BACKSLASH
        case 0x5D:
            if is_extended {
                return .APPLICATION
            } else {
                log.warnf("Pressed unmapped key: %d. Extended key: %s", scancode, is_extended)
            }
        case 0x5E:
            if is_extended {
                return .POWER
            } else {
                log.warnf("Pressed unmapped key: %d. Extended key: %s", scancode, is_extended)
            }
        case 0x59:
            return .KP_EQUALS
        case 0x64:
            return .F13
        case 0x65:
            return .F14
        case 0x66:
            return .F15
        case 0x67:
            return .F16
        case 0x68:
            return .F17
        case 0x69:
            return .F18
        case 0x6A:
            return .F19
        case 0x6B:
            return .F20
        case 0x6C:
            return .F21
        case 0x6D:
            return .F22
        case 0x6E:
            return .F23
        case 0x76:
            return .F24

        case 0x7E:
            return .KP_COMMA
        case 0x73:
            return .INTERNATIONAL1
        case 0x70:
            return .INTERNATIONAL2
        case 0x7D:
            return .INTERNATIONAL3
        case 0x79:
            return .INTERNATIONAL4
        case 0x7B:
            return .INTERNATIONAL5
        case 0x5C:
            return .RIGHT_META if is_extended else .INTERNATIONAL6
        case 0x72:
            return .LANG1 // Only emitted on Key Release
        case 0xF2:
            return .LANG1 // Legacy, Only emitted on Key Release
        case 0x71:
            return .LANG2 // Only emitted on Key Release
        case 0xF1:
            return .LANG2 // Legacy, Only emitted on Key Release
        case 0x78:
            return .LANG3
        case 0x77:
            return .LANG4
        //case 0x76: return .LANG5 // Conflicts with F24

        case 0x1D:
            return .RIGHT_CTRL if is_extended else .LEFT_CTRL
        case 0x2A:
            return .LEFT_SHIFT
        case 0x36:
            return .RIGHT_SHIFT
        case 0x38:
            return .RIGHT_ALT if is_extended else .LEFT_ALT
        case 0x5B:
            if is_extended {
                return .LEFT_META
            } else {
                log.warnf("Pressed unmapped key: %d. Extended key: %s", scancode, is_extended)
            }
        // End of Keyboard/Keypad section on microsoft.com
        // We currently don't map or care about the Consumer section
    }

    return .NULL
}

@(private = "file")
win32_scancode_to_zephr_scancode :: proc(win32_scancode: u32) -> Scancode {
    win32_scancode := win32_scancode
    if (win32_scancode < 0xE000) {
        if (win32_scancode >= cast(u32)len(win32_scancode_to_zephr_scancode_map)) {
            return .NULL
        }
        return win32_scancode_to_zephr_scancode_map[win32_scancode]
    } else {
        win32_scancode -= 0xE000
        if (win32_scancode >= cast(u32)len(win32_scancode_0xe000_to_zephr_scancode_map)) {
            return .NULL
        }
        return win32_scancode_0xe000_to_zephr_scancode_map[win32_scancode]
    }
}

@(private = "file")
windows_input_device :: proc(input_device: ^InputDevice) -> ^WindowsInputDevice {
    return cast(^WindowsInputDevice)&input_device.backend_data
}

@(private = "file")
init_legacy_gl :: proc(class_name: win32.wstring, hInstance: win32.HINSTANCE) {
    temp_hwnd = win32.CreateWindowExW(
        0,
        class_name,
        win32.L("Fake Window"),
        win32.WS_OVERLAPPEDWINDOW,
        0,
        0,
        1,
        1,
        nil,
        nil,
        hInstance,
        nil,
    )

    if temp_hwnd == nil {
        log.fatal("Failed to create fake window")
    }

    temp_device_ctx = win32.GetDC(temp_hwnd)

    if temp_device_ctx == nil {
        log.error("Failed to create device context for fake window")
    }

    pfd := win32.PIXELFORMATDESCRIPTOR {
        nSize      = size_of(win32.PIXELFORMATDESCRIPTOR),
        nVersion   = 1,
        dwFlags    = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL,
        iPixelType = win32.PFD_TYPE_RGBA,
        cColorBits = 32,
        cAlphaBits = 8,
        cDepthBits = 24,
        iLayerType = win32.PFD_MAIN_PLANE,
    }
    pixel_format := win32.ChoosePixelFormat(temp_device_ctx, &pfd)
    if pixel_format == 0 {
        log.error("Failed to choose pixel format for fake window")
    }

    status := win32.SetPixelFormat(temp_device_ctx, pixel_format, &pfd)
    if !status {
        log.error("Failed to set pixel format for fake window")
    }

    temp_wgl_context = win32.wglCreateContext(temp_device_ctx)

    if temp_wgl_context == nil {
        log.fatal("Failed to create WGL context")
        return
    }

    gl.load_up_to(3, 3, win32.gl_set_proc_address)

    win32.wglMakeCurrent(temp_device_ctx, temp_wgl_context)

    gl_version := gl.GetString(gl.VERSION)

    strs := strings.split(string(gl_version), " ")
    ver := strings.split(strs[0], ".")
    gl_major, gl_minor := strconv.atoi(ver[0]), strconv.atoi(ver[1])

    log.debugf("Fake Window GL: %d.%d", gl_major, gl_minor)

    if !(gl_major > 3 || (gl_major == 3 && gl_minor >= 3)) {
        log.fatalf(
            "You need at least OpenGL 3.3 to run this application. Your OpenGL version is %d.%d",
            gl_major,
            gl_minor,
        )
        title := win32.utf8_to_wstring("Failed to initialize OpenGL", context.temp_allocator)
        msg := win32.utf8_to_wstring(fmt.tprintf("You need at least OpenGL 3.3 to run this application. Your OpenGL version is %d.%d", gl_major, gl_minor), context.temp_allocator)
        win32.MessageBoxExW(w_os.hwnd, msg, title, win32.MB_OK | win32.MB_ICONERROR, 0)
        os.exit(1)
    }
}

@(private = "file")
init_gl :: proc(
    class_name: win32.wstring,
    window_title: win32.wstring,
    window_size: m.vec2,
    window_non_resizable: bool,
    hInstance: win32.HINSTANCE,
) {
    screen_size := m.vec2 {
        cast(f32)win32.GetSystemMetrics(win32.SM_CXSCREEN),
        cast(f32)win32.GetSystemMetrics(win32.SM_CYSCREEN),
    }

    // TODO: get all the monitors and log them with their resolutions

    win_x := screen_size.x / 2 - window_size.x / 2
    win_y := screen_size.y / 2 - window_size.y / 2

    rect := win32.RECT{0, 0, cast(i32)window_size.x, cast(i32)window_size.y}
    win32.AdjustWindowRect(&rect, win32.WS_OVERLAPPEDWINDOW, false)

    win_width := rect.right - rect.left
    win_height := rect.bottom - rect.top
    
    //odinfmt: disable
    win_style := win32.WS_OVERLAPPEDWINDOW if !window_non_resizable else (win32.WS_OVERLAPPEDWINDOW & ~win32.WS_THICKFRAME & ~win32.WS_MAXIMIZEBOX)
    //odinfmt: enable

    w_os.hwnd = win32.CreateWindowExW(
        0,
        class_name,
        window_title,
        win_style,
        cast(i32)win_x,
        cast(i32)win_y,
        win_width,
        win_height,
        nil,
        nil,
        hInstance,
        nil,
    )

    if w_os.hwnd == nil {
        log.fatal("Failed to create window")
        return
    }

    w_os.device_ctx = win32.GetDC(w_os.hwnd)

    if w_os.device_ctx == nil {
        log.fatal("Failed to create device context")
        return
    }

    wglChoosePixelFormatARB := cast(win32.ChoosePixelFormatARBType)win32.wglGetProcAddress("wglChoosePixelFormatARB")
    wglCreateContextAttribsARB := cast(win32.CreateContextAttribsARBType)win32.wglGetProcAddress(
        "wglCreateContextAttribsARB",
    )
    w_os.wglSwapIntervalEXT = cast(win32.SwapIntervalEXTType)win32.wglGetProcAddress("wglSwapIntervalEXT")
    
    //odinfmt: disable
    pixel_attribs := []i32 {
        win32.WGL_DRAW_TO_WINDOW_ARB, 1,
        win32.WGL_SUPPORT_OPENGL_ARB, 1,
        win32.WGL_DOUBLE_BUFFER_ARB,  1,
        win32.WGL_SWAP_METHOD_ARB,    win32.WGL_SWAP_EXCHANGE_ARB,
        // NOTE: WGL_SWAP_COPY_ARB works with wine but I think WGL_SWAP_EXCHANGE_ARB is faster right?
        //win32.WGL_SWAP_METHOD_ARB,    win32.WGL_SWAP_COPY_ARB,
        win32.WGL_PIXEL_TYPE_ARB,     win32.WGL_TYPE_RGBA_ARB,
        win32.WGL_ACCELERATION_ARB,   win32.WGL_FULL_ACCELERATION_ARB,
        win32.WGL_COLOR_BITS_ARB,     32,
        win32.WGL_ALPHA_BITS_ARB,     8,
        win32.WGL_DEPTH_BITS_ARB,     24,
        win32.WGL_STENCIL_BITS_ARB,   0,
        0,
    }
    //odinfmt: enable

    
    //odinfmt: disable
    ctx_attribs := []i32 {
        win32.WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
        win32.WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        win32.WGL_CONTEXT_PROFILE_MASK_ARB,  win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    }
    //odinfmt: enable

    pixel_format: i32
    num_formats: u32
    success := wglChoosePixelFormatARB(w_os.device_ctx, raw_data(pixel_attribs), nil, 1, &pixel_format, &num_formats)

    if !success {
        log.error("Failed to choose pixel format")
        return
    }

    pfd: win32.PIXELFORMATDESCRIPTOR
    win32.DescribePixelFormat(w_os.device_ctx, pixel_format, size_of(win32.PIXELFORMATDESCRIPTOR), &pfd)
    success = win32.SetPixelFormat(w_os.device_ctx, pixel_format, &pfd)

    if !success {
        log.error("Failed to set pixel format")
        return
    }

    w_os.wgl_context = wglCreateContextAttribsARB(w_os.device_ctx, nil, raw_data(ctx_attribs))

    if w_os.wgl_context == nil {
        log.fatal("Failed to create WGL context")
        return
    }

    win32.wglMakeCurrent(temp_device_ctx, nil)
    win32.wglDeleteContext(temp_wgl_context)
    win32.ReleaseDC(temp_hwnd, temp_device_ctx)
    win32.DestroyWindow(temp_hwnd)

    win32.wglMakeCurrent(w_os.device_ctx, w_os.wgl_context)

    gl_version := gl.GetString(gl.VERSION)
    log.infof("GL Version: %s", gl_version)

    new_success := w_os.wglSwapIntervalEXT(1)
    if !new_success {
        log.error("Failed to enable v-sync")
    }

    gl.load_up_to(3, 3, win32.gl_set_proc_address)

    win32.ShowWindow(w_os.hwnd, win32.SW_NORMAL)

    gl.Enable(gl.BLEND)
    gl.Enable(gl.MULTISAMPLE)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

@(private = "file")
window_proc :: proc "stdcall" (
    hwnd: win32.HWND,
    msg: win32.UINT,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) -> win32.LRESULT {
    context = runtime.default_context()
    context.logger = logger

    result: win32.LRESULT

    switch msg {
        case win32.WM_CLOSE:
            e: Event
            e.type = .WINDOW_CLOSED
            queue.push(&zephr_ctx.event_queue, e)
        case win32.WM_DROPFILES:
            hdrop := cast(win32.HDROP)wparam

            paths := make([dynamic]string, 0, 8)
            defer delete(paths)

            num_files := win32.DragQueryFileW(hdrop, 0xFFFFFFFF, nil, 0)

            for i in 0 ..< num_files {
                path_len := win32.DragQueryFileW(hdrop, i, nil, 0)

                if path_len == 0 {
                    log.error("Failed to get required length for the name(s) of the dropped file(s)")
                    break
                }

                path := make([^]win32.wchar_t, path_len + 1, context.temp_allocator)

                res := win32.DragQueryFileW(hdrop, i, path, path_len + 1)

                if res == 0 {
                    log.error("Failed to query the dropped file's name")
                    break
                }

                utf8_path, _ := win32.wstring_to_utf8(path, cast(int)res)
                append(&paths, utf8_path)
            }

            os_event_queue_drag_and_drop_file(paths[:])

            win32.DragFinish(hdrop)
        case win32.WM_INPUTLANGCHANGE:
            keyboard_map_update()
        case win32.WM_SIZE:
            width := win32.LOWORD(auto_cast lparam)
            height := win32.HIWORD(auto_cast lparam)
            zephr_ctx.window.size = m.vec2{cast(f32)width, cast(f32)height}
            zephr_ctx.projection = orthographic_projection_2d(0, zephr_ctx.window.size.x, zephr_ctx.window.size.y, 0)
            resize_multisample_fb(i32(width), i32(height))

            e: Event
            e.window.width = cast(u32)width
            e.window.height = cast(u32)height

            queue.push(&zephr_ctx.event_queue, e)
        case win32.WM_MOUSEMOVE:
            if zephr_ctx.virt_mouse.captured {
                // restrict the cursor to the center of the window
                rect: win32.RECT
                win32.GetWindowRect(hwnd, &rect)
                win32.SetCursorPos(
                    i32(zephr_ctx.window.size.x / 2) + rect.left,
                    i32(zephr_ctx.window.size.y / 2) + rect.top,
                )
                return 0
            }

            x := win32.GET_X_LPARAM(lparam)
            y := win32.GET_Y_LPARAM(lparam)
            pos := m.vec2{clamp(cast(f32)x, 0, zephr_ctx.window.size.x), clamp(cast(f32)y, 0, zephr_ctx.window.size.y)}
            rel_pos := pos - zephr_ctx.virt_mouse.pos

            e: Event
            e.type = .VIRT_MOUSE_MOVED
            e.mouse_moved.device_id = 0
            e.mouse_moved.pos = pos
            e.mouse_moved.rel_pos = rel_pos
            zephr_ctx.virt_mouse.pos = pos
            zephr_ctx.virt_mouse.rel_pos = rel_pos

            queue.push(&zephr_ctx.event_queue, e)
        case win32.WM_MOUSEWHEEL:
            // This will be a multiple of win32.WHEEL_DELTA which is 120
            wheel_delta := win32.GET_WHEEL_DELTA_WPARAM(wparam)
            scroll_rel := m.vec2{cast(f32)wheel_delta / win32.WHEEL_DELTA, 0}

            os_event_queue_virt_mouse_scroll(scroll_rel)
        case win32.WM_MOUSEHWHEEL:
            wheel_delta := win32.GET_WHEEL_DELTA_WPARAM(wparam)
            scroll_rel := m.vec2{0, cast(f32)wheel_delta / win32.WHEEL_DELTA}

            os_event_queue_virt_mouse_scroll(scroll_rel)
        case win32.WM_LBUTTONDOWN:
            fallthrough
        case win32.WM_LBUTTONUP:
            os_event_queue_virt_mouse_button(.LEFT, msg == win32.WM_LBUTTONDOWN)
        case win32.WM_MBUTTONDOWN:
            fallthrough
        case win32.WM_MBUTTONUP:
            os_event_queue_virt_mouse_button(.MIDDLE, msg == win32.WM_MBUTTONDOWN)
        case win32.WM_RBUTTONDOWN:
            fallthrough
        case win32.WM_RBUTTONUP:
            os_event_queue_virt_mouse_button(.RIGHT, msg == win32.WM_RBUTTONDOWN)
        case win32.WM_XBUTTONDOWN:
            fallthrough
        case win32.WM_XBUTTONUP:
            btn: MouseButton = .NONE

            switch win32.HIWORD(auto_cast wparam) {
                case win32.XBUTTON1:
                    btn = .BACK
                case win32.XBUTTON2:
                    btn = .FORWARD
            }

            if btn != .NONE {
                os_event_queue_virt_mouse_button(btn, msg == win32.WM_XBUTTONDOWN)
            }
        // SYSKEYUP/DOWN is needed to receive ALT and F10 keys
        case win32.WM_SYSKEYUP:
            fallthrough
        case win32.WM_SYSKEYDOWN:
            fallthrough
        case win32.WM_KEYUP:
            fallthrough
        case win32.WM_KEYDOWN:
            // Bits 16-23 hold the scancode
            win32_scancode := (lparam & 0xFF0000) >> 16
            is_extended := lparam & (1 << 24) != 0
            win32_keycode := cast(u32)wparam

            scancode := scan1_scancode_to_zephr_scancode_map(cast(u8)win32_scancode, is_extended)
            os_event_queue_virt_key_changed(msg == win32.WM_KEYDOWN || msg == win32.WM_SYSKEYDOWN, scancode)

            // Pass down the sys keys so ALT + F4 works but only if it's not F10 because that locks us up until it's pressed again
            if (msg == win32.WM_SYSKEYDOWN || msg == win32.WM_SYSKEYUP) && scancode != .F10 {
                return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
            }

        //wchar_t utf16_string[32]
        // flags := 0x4 // do not change keyboard state
        // key_state: [256]u8
        // win32.GetKeyboardState(key_state)
        // ret := win32.ToUnicode(win32_keycode, win32_scancode, key_state, utf16_string, CORE_ARRAY_COUNT(utf16_string), flags)
        // if ret > 0 {
        // 	// CoreIAlctor frame_alctor = game_tls_frame_alctor();
        // 	// CoreString string = os_windows_utf16_to_utf8(utf16_string, frame_alctor);
        // 	os_event_queue_virt_key_input_utf8(string.data, string.size - 1);
        // }
        case win32.WM_INPUT:
            switch wparam {
                case 0:
                    // RIM_INPUT
                    raw_input_handle := cast(win32.HRAWINPUT)lparam

                    raw_input_size: win32.UINT = 0
                    res := win32.GetRawInputData(
                        raw_input_handle,
                        win32.RID_INPUT,
                        nil,
                        &raw_input_size,
                        size_of(win32.RAWINPUTHEADER),
                    )
                    if (res != 0) {
                        log.errorf("Failed to GetRawInputData: %d. Last Error: %d", res, win32.GetLastError())
                        break
                    }

                    raw_input: win32.RAWINPUT
                    res = win32.GetRawInputData(
                        raw_input_handle,
                        win32.RID_INPUT,
                        &raw_input,
                        &raw_input_size,
                        size_of(win32.RAWINPUTHEADER),
                    )
                    if res != raw_input_size {
                        log.errorf(
                            "GetRawInputData returned an unexpected size. Expected: %d, got: %d",
                            raw_input_size,
                            res,
                        )
                        break
                    }

                    raw_input_device_handle := raw_input.header.hDevice
                    key := transmute(u64)raw_input_device_handle
                    found_device := key in zephr_ctx.input_devices_map
                    if !found_device {
                        break
                    }

                    input_device := &zephr_ctx.input_devices_map[key]
                    input_device_backend := windows_input_device(input_device)

                    switch raw_input.header.dwType {
                        case win32.RIM_TYPEMOUSE:
                            if !(.MOUSE in input_device.features) {
                                break
                            }
                            if (raw_input.data.mouse.usFlags & win32.MOUSE_MOVE_ABSOLUTE) == 0 &&
                               (raw_input.data.mouse.lLastX != 0 || raw_input.data.mouse.lLastY != 0) {
                                rel_pos := m.vec2 {
                                    cast(f32)raw_input.data.mouse.lLastX,
                                    cast(f32)raw_input.data.mouse.lLastY,
                                }
                                os_event_queue_raw_mouse_moved(key, rel_pos)

                                // Get relative position for the virt mouse from raw input when the cursor is captured
                                if zephr_ctx.virt_mouse.captured {
                                    e: Event
                                    e.type = .VIRT_MOUSE_MOVED
                                    e.mouse_moved.device_id = 0
                                    e.mouse_moved.pos = zephr_ctx.virt_mouse.pos + rel_pos
                                    e.mouse_moved.rel_pos = rel_pos
                                    zephr_ctx.virt_mouse.rel_pos = rel_pos
                                    zephr_ctx.virt_mouse.virtual_pos = zephr_ctx.virt_mouse.pos + rel_pos

                                    queue.push(&zephr_ctx.event_queue, e)
                                }
                            }

                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_WHEEL == win32.RI_MOUSE_WHEEL {
                                rel_pos := m.vec2{0, cast(f32)raw_input.data.mouse.usButtonData / win32.WHEEL_DELTA}
                                os_event_queue_raw_mouse_scroll(key, rel_pos)
                            }

                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_HWHEEL == win32.RI_MOUSE_HWHEEL {
                                rel_pos := m.vec2{cast(f32)raw_input.data.mouse.usButtonData / win32.WHEEL_DELTA, 0}
                                os_event_queue_raw_mouse_scroll(key, rel_pos)
                            }

                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_1_DOWN ==
                               win32.RI_MOUSE_BUTTON_1_DOWN {
                                os_event_queue_raw_mouse_button(key, .LEFT, true)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_2_DOWN ==
                               win32.RI_MOUSE_BUTTON_2_DOWN {
                                os_event_queue_raw_mouse_button(key, .RIGHT, true)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_3_DOWN ==
                               win32.RI_MOUSE_BUTTON_3_DOWN {
                                os_event_queue_raw_mouse_button(key, .MIDDLE, true)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_4_DOWN ==
                               win32.RI_MOUSE_BUTTON_4_DOWN {
                                os_event_queue_raw_mouse_button(key, .BACK, true)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_5_DOWN ==
                               win32.RI_MOUSE_BUTTON_5_DOWN {
                                os_event_queue_raw_mouse_button(key, .FORWARD, true)
                            }

                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_1_UP ==
                               win32.RI_MOUSE_BUTTON_1_UP {
                                os_event_queue_raw_mouse_button(key, .LEFT, false)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_2_UP ==
                               win32.RI_MOUSE_BUTTON_2_UP {
                                os_event_queue_raw_mouse_button(key, .RIGHT, false)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_3_UP ==
                               win32.RI_MOUSE_BUTTON_3_UP {
                                os_event_queue_raw_mouse_button(key, .MIDDLE, false)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_4_UP ==
                               win32.RI_MOUSE_BUTTON_4_UP {
                                os_event_queue_raw_mouse_button(key, .BACK, false)
                            }
                            if raw_input.data.mouse.usButtonFlags & win32.RI_MOUSE_BUTTON_5_UP ==
                               win32.RI_MOUSE_BUTTON_5_UP {
                                os_event_queue_raw_mouse_button(key, .FORWARD, false)
                            }
                        case win32.RIM_TYPEKEYBOARD:
                            if !(.KEYBOARD in input_device.features) {
                                break
                            }
                            win32_scancode := raw_input.data.keyboard.MakeCode
                            if raw_input.data.keyboard.Flags & win32.RI_KEY_E0 == win32.RI_KEY_E0 {
                                win32_scancode |= 0xE000
                            } else if raw_input.data.keyboard.Flags & win32.RI_KEY_E1 == win32.RI_KEY_E1 {
                                win32_scancode |= 0xE100
                            }
                            is_pressed := !(raw_input.data.keyboard.Flags & win32.RI_KEY_BREAK == win32.RI_KEY_BREAK)

                            switch (win32_scancode) {
                                //0xE11D: first part of the Pause
                                //0xE02A: first part of the PrintScreen scancode if no Shift, Control or Alt keys are pressed
                                //0xE02A, 0xE0AA, 0xE036, 0xE0B6: generated in addition of Insert, Delete, Home, End, Page Up, Page Down, Up, Down, Left, Right when num lock is on; or when num lock is off but one or both shift keys are pressed
                                //0xE02A, 0xE0AA, 0xE036, 0xE0B6: generated in addition of Numpad Divide and one or both Shift keys are pressed
                                //When holding a key down, the pre/postfix (0xE02A) is not repeated!
                                case 0xE11D:
                                    input_device_backend.found_e11d = true;return 0
                                case 0xE02A:
                                    return 0
                                case 0xE0AA:
                                    return 0
                                case 0xE0B6:
                                    return 0
                                case 0xE036:
                                    return 0
                            }

                            if (input_device_backend.found_e11d) {
                                if (win32_scancode == 0x45) {
                                    os_event_queue_raw_key_changed(key, is_pressed, .PAUSE)
                                }
                                input_device_backend.found_e11d = false
                                break
                            }

                            scancode := win32_scancode_to_zephr_scancode(cast(u32)win32_scancode)
                            os_event_queue_raw_key_changed(key, is_pressed, scancode)

                        //win32_keycode := win32.MapVirtualKeyW(cast(u32)win32_scancode, win32.MAPVK_VSC_TO_VK_EX)

                        //wchar_t utf16_string[32]
                        //UINT flags = 0x4 // do not change keyboard state
                        //BYTE key_state[256]
                        //win32.GetKeyboardState(key_state)
                        //int ret = win32.ToUnicode(win32_keycode, win32_scancode, key_state, utf16_string, len(utf16_string), flags)
                        //if ret > 0 {
                        //	CoreIAlctor frame_alctor = game_tls_frame_alctor()
                        //	CoreString string = os_windows_utf16_to_utf8(utf16_string, frame_alctor)
                        //	os_event_queue_raw_key_input_utf8(input_device_id, string.data, string.size - 1)
                        //}
                        case win32.RIM_TYPEHID:
                            if .TOUCHPAD in input_device.features {
                                has_touch := false
                                has_click := false

                                for b in 0 ..< input_device_backend.button_caps_count {
                                    usage_count: win32.ULONG = 0
                                    cap := input_device_backend.button_caps[b]

                                    res := win32.HidP_GetUsages(
                                        .Input,
                                        cap.UsagePage,
                                        0,
                                        nil,
                                        &usage_count,
                                        input_device_backend.preparsed_data,
                                        cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                        raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                    )
                                    usages := make([^]win32.USAGE, usage_count)

                                    res = win32.HidP_GetUsages(
                                        .Input,
                                        cap.UsagePage,
                                        0,
                                        usages,
                                        &usage_count,
                                        input_device_backend.preparsed_data,
                                        cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                        raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                    )

                                    if res != win32.HIDP_STATUS_SUCCESS {
                                        log.errorf(
                                            "Failed to get Touchpad device's button event data: 0x%X",
                                            cast(u32)res,
                                        )
                                        break
                                    }

                                    for u in 0 ..< usage_count {
                                        usage := usages[u]
                                        if cap.UsagePage == win32.HID_USAGE_PAGE_DIGITIZER {
                                            // When tapping/touching the touchpad
                                            // Tip switch is usually for Stylus pens but is also used as a button click(in this case touch)
                                            // for other digitizer devices.
                                            if usage == win32.HID_USAGE_DIGITIZER_TIP_SWITCH {
                                                has_touch = true
                                                if !(.TOUCH in input_device.touchpad.action_is_pressed_bitset) {
                                                    os_event_queue_raw_touchpad_action(key, .TOUCH, true)
                                                }
                                            }
                                        }
                                        if cap.UsagePage == win32.HID_USAGE_PAGE_BUTTON {
                                            // When clicking the touchpad's physical button
                                            if usage == 1 {     // Button 1
                                                has_click = true
                                                if !(.CLICK in input_device.touchpad.action_is_pressed_bitset) {
                                                    os_event_queue_raw_touchpad_action(key, .CLICK, true)
                                                }
                                            }
                                        }
                                    }
                                }

                                if !has_touch && .TOUCH in input_device.touchpad.action_is_pressed_bitset {
                                    os_event_queue_raw_touchpad_action(key, .TOUCH, false)
                                }
                                if !has_click && .CLICK in input_device.touchpad.action_is_pressed_bitset {
                                    os_event_queue_raw_touchpad_action(key, .CLICK, false)
                                }

                                pos := input_device.touchpad.pos

                                for v in 0 ..< input_device_backend.value_caps_count {
                                    value: u32
                                    cap := input_device_backend.value_caps[v]

                                    res := win32.HidP_GetUsageValue(
                                        .Input,
                                        cap.UsagePage,
                                        0,
                                        cap.NotRange.Usage,
                                        &value,
                                        input_device_backend.preparsed_data,
                                        cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                        raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                    )

                                    if res != win32.HIDP_STATUS_SUCCESS {
                                        log.errorf(
                                            "Failed to get Touchpad device's movement event data: 0x%X",
                                            cast(u32)res,
                                        )
                                        break
                                    }

                                    if cap.UsagePage == win32.HID_USAGE_PAGE_GENERIC {
                                        // For X and Y position
                                        if cap.NotRange.Usage == win32.HID_USAGE_GENERIC_X {
                                            pos.x = cast(f32)value
                                        } else if cap.NotRange.Usage == win32.HID_USAGE_GENERIC_Y {
                                            pos.y = cast(f32)value
                                        }
                                    }
                                    if cap.UsagePage == win32.HID_USAGE_PAGE_DIGITIZER {
                                        // ??? Some special touchpad stuff
                                    }
                                }

                                if pos != input_device.touchpad.pos {
                                    os_event_queue_raw_touchpad_moved(key, pos)
                                }
                            } else if .GAMEPAD in input_device.features {
                                actions_found: bit_set[GamepadAction]
                                usage_count: win32.ULONG = 0
                                // Sane controllers only have a single button cap with
                                // a Range of button usages
                                cap := input_device_backend.button_caps[0]

                                res := win32.HidP_GetUsages(
                                    .Input,
                                    cap.UsagePage,
                                    0,
                                    nil,
                                    &usage_count,
                                    input_device_backend.preparsed_data,
                                    cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                    raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                )
                                usages := make([^]win32.USAGE, usage_count)

                                res = win32.HidP_GetUsages(
                                    .Input,
                                    cap.UsagePage,
                                    0,
                                    usages,
                                    &usage_count,
                                    input_device_backend.preparsed_data,
                                    cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                    raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                )

                                if res != win32.HIDP_STATUS_SUCCESS {
                                    log.errorf("Failed to get Gamepad device's button event data: 0x%X", cast(u32)res)
                                    break
                                }

                                for u in 0 ..< usage_count {
                                    usage := usages[u]
                                    action := input_device_backend.gamepad_button_bindings.buttons[usage]
                                    actions_found |= {action}
                                    if !(action in input_device.gamepad.action_is_pressed_bitset) {
                                        os_event_queue_raw_gamepad_action(key, action, 1, 0)
                                    }
                                }

                                for v in 0 ..< input_device_backend.value_caps_count {
                                    value: u32
                                    cap := input_device_backend.value_caps[v]

                                    res := win32.HidP_GetUsageValue(
                                        .Input,
                                        cap.UsagePage,
                                        0,
                                        cap.NotRange.Usage,
                                        &value,
                                        input_device_backend.preparsed_data,
                                        cast(win32.PCHAR)&raw_input.data.hid.bRawData[0],
                                        raw_input.data.hid.dwCount * raw_input.data.hid.dwSizeHid,
                                    )

                                    if res != win32.HIDP_STATUS_SUCCESS {
                                        log.errorf(
                                            "Failed to get Gamepad device's value event data: 0x%X",
                                            cast(u32)res,
                                        )
                                        break
                                    }

                                    if cap.NotRange.Usage == win32.HID_USAGE_GENERIC_HATSWITCH {
                                        dpad_actions := input_device_backend.gamepad_button_bindings.hatswitch[value]

                                        if .NONE in dpad_actions {
                                            continue
                                        }

                                        for card(dpad_actions) != 0 {
                                            action := cast(GamepadAction)transmute(u32)bits.count_trailing_zeros(
                                                dpad_actions,
                                            )
                                            actions_found |= {action}
                                            if !(action in input_device.gamepad.action_is_pressed_bitset) {
                                                os_event_queue_raw_gamepad_action(key, action, 1, 0)
                                            }
                                            dpad_actions &= ~{action}
                                        }
                                    } else {
                                        info := input_device_backend.gamepad_button_bindings.axes[cap.NotRange.Usage]
                                        max := (1 << cap.BitSize) - 1
                                        norm_value := cast(f32)value / cast(f32)max

                                        if info.neg != .NONE {
                                            norm_value = (norm_value * 2.0) - 1.0

                                            // TODO: configurable deadzones
                                            if norm_value < 0 {
                                                norm_value = -norm_value
                                                action := info.neg
                                                actions_found |= {action}
                                                os_event_queue_raw_gamepad_action(key, action, norm_value, 0.10)
                                            } else {
                                                action := info.pos
                                                actions_found |= {action}
                                                os_event_queue_raw_gamepad_action(key, action, norm_value, 0.10)
                                            }
                                        } else {
                                            action := info.pos
                                            actions_found |= {action}
                                            os_event_queue_raw_gamepad_action(key, info.pos, norm_value, 0.05)
                                        }
                                    }
                                }

                                actions_not_found := ~actions_found
                                actions_not_found &= ~{.NONE}
                                for card(actions_not_found) != 0 {
                                    action := cast(GamepadAction)transmute(u32)bits.count_trailing_zeros(
                                        actions_not_found,
                                    )
                                    if action in input_device.gamepad.action_is_pressed_bitset &&
                                       !(action in actions_found) {
                                        os_event_queue_raw_gamepad_action(key, action, 0, 0)
                                    }
                                    actions_not_found &= ~{action}
                                }
                            }
                    }
            }
        case win32.WM_INPUT_DEVICE_CHANGE:
            raw_input_device_handle := transmute(win32.HANDLE)lparam

            switch wparam {
                case 1:
                    // GIDC_ARRIVAL
                    device_info: win32.RID_DEVICE_INFO
                    device_info.cbSize = size_of(win32.RID_DEVICE_INFO)
                    device_info_size: u32 = size_of(win32.RID_DEVICE_INFO)
                    res := win32.GetRawInputDeviceInfoW(
                        raw_input_device_handle,
                        win32.RIDI_DEVICEINFO,
                        &device_info,
                        &device_info_size,
                    )

                    if cast(i32)res == -1 || res == 0 {
                        log.error("Failed to query raw input device's info")
                        break
                    }

                    device_name_len: win32.UINT
                    res = win32.GetRawInputDeviceInfoW(raw_input_device_handle, win32.RIDI_DEVICENAME, nil, &device_name_len)

                    if cast(i32)res == -1 {
                        log.error("Failed to query raw input device's name length")
                        break
                    }

                    device_name := make([^]win32.wchar_t, device_name_len)
                    defer free(device_name)

                    res = win32.GetRawInputDeviceInfoW(
                        raw_input_device_handle,
                        win32.RIDI_DEVICENAME,
                        device_name,
                        &device_name_len,
                    )

                    if cast(i32)res == -1 || res == 0 {
                        log.error("Failed to query raw input device's name ")
                        break
                    }

                    hid_device_handle := win32.CreateFileW(
                        device_name,
                        0,
                        win32.FILE_SHARE_READ | win32.FILE_SHARE_WRITE | win32.FILE_SHARE_DELETE,
                        nil,
                        win32.OPEN_EXISTING,
                        0,
                        nil,
                    )
                    if hid_device_handle == win32.INVALID_HANDLE_VALUE {
                        log.errorf(
                            "Got an invalid HID handle for input device: %s",
                            win32.wstring_to_utf8(device_name, cast(int)device_name_len),
                        )
                        break
                    }

                    attr: win32.HIDD_ATTRIBUTES
                    attr.Size = size_of(win32.HIDD_ATTRIBUTES)
                    win32.HidD_GetAttributes(hid_device_handle, &attr)

                    manufacturer_name: [HID_STRING_CAP]win32.wchar_t
                    have_manufacturer_name := win32.HidD_GetManufacturerString(
                        hid_device_handle,
                        &manufacturer_name,
                        HID_STRING_BYTE_CAP,
                    )

                    product_name: [HID_STRING_CAP]win32.wchar_t
                    have_product_name := win32.HidD_GetProductString(
                        hid_device_handle,
                        &product_name,
                        HID_STRING_BYTE_CAP,
                    )

                    arena: virtual.Arena
                    err := virtual.arena_init_static(&arena, mem.Megabyte * 4)
                    log.assert(err == nil, "Failed to init memory arena for input device")
                    arena_allocator := virtual.arena_allocator(&arena)

                    name := fmt.aprintf(
                        "unknown input device 0x%x 0x%x",
                        device_info.hid.dwVendorId,
                        device_info.hid.dwProductId,
                        allocator = arena_allocator,
                    )
                    switch cast(int)(have_manufacturer_name && manufacturer_name[0] != 0) *
                        2 + cast(int)(have_product_name && product_name[0] != 0) {
                        case 1:
                            name_utf8, _ := win32.utf16_to_utf8(product_name[:])
                            name = strings.clone(strings.trim_space(name_utf8), arena_allocator)
                        case 2:
                            name_utf8, _ := win32.utf16_to_utf8(manufacturer_name[:])
                            name = strings.clone(strings.trim_space(name_utf8), arena_allocator)
                        case 3:
                            manufacturer_utf8, _ := win32.utf16_to_utf8(manufacturer_name[:])
                            product_utf8, _ := win32.utf16_to_utf8(product_name[:], arena_allocator)
                            name = fmt.aprintf(
                                "%s %s",
                                strings.trim_space(manufacturer_utf8),
                                strings.trim_space(product_utf8),
                                allocator = arena_allocator,
                            )
                    }

                    switch device_info.dwType {
                        case win32.RIM_TYPEMOUSE:
                            key := transmute(u64)raw_input_device_handle
                            input_device := os_event_queue_input_device_connected(
                                key,
                                name,
                                {.MOUSE},
                                attr.VendorID,
                                attr.ProductID,
                            )
                            input_device.name = name
                            input_device.arena = arena
                            input_device_backend := windows_input_device(input_device)
                            input_device_backend.raw_input_device_handle = raw_input_device_handle
                            input_device_backend.hid_device_handle = hid_device_handle
                        case win32.RIM_TYPEKEYBOARD:
                            key := transmute(u64)raw_input_device_handle
                            input_device := os_event_queue_input_device_connected(
                                key,
                                name,
                                {.KEYBOARD},
                                attr.VendorID,
                                attr.ProductID,
                            )
                            input_device.name = name
                            input_device.arena = arena
                            input_device_backend := windows_input_device(input_device)
                            input_device_backend.raw_input_device_handle = raw_input_device_handle
                            input_device_backend.hid_device_handle = hid_device_handle
                        case win32.RIM_TYPEHID:
                            preparsed_data_size: win32.UINT
                            res := win32.GetRawInputDeviceInfoW(
                                raw_input_device_handle,
                                win32.RIDI_PREPARSEDDATA,
                                nil,
                                &preparsed_data_size,
                            )
                            if (res != 0) {
                                log.errorf("Failed to get HID device's preparsed data size. Error: %d", res)
                                break
                            }
                            if (preparsed_data_size == 0) {
                                log.error("HID device's preparsed data size is 0")
                                break
                            }

                            preparsed_data := make([^]win32.HIDP_PREPARSED_DATA, preparsed_data_size, arena_allocator)
                            res = win32.GetRawInputDeviceInfoW(
                                raw_input_device_handle,
                                win32.RIDI_PREPARSEDDATA,
                                preparsed_data,
                                &preparsed_data_size,
                            )
                            if (cast(int)res == -1 || res == 0) {
                                log.error("Failed to get HID device's preparsed data: Error %d", win32.GetLastError())
                                break
                            }
                            if res != preparsed_data_size {
                                log.debugf(
                                    "Failed to get HID device's preparsed data. Expected: %d bytes but only copied: %d bytes",
                                    preparsed_data_size,
                                    res,
                                )
                            }

                            caps: win32.HIDP_CAPS
                            nts := win32.HidP_GetCaps(preparsed_data, &caps)
                            if (nts != win32.HIDP_STATUS_SUCCESS) {
                                log.error("Failed to get HID device's capabilities")
                                break
                            }

                            if (caps.NumberInputButtonCaps == 0) {
                                log.warn("HID device reports it has 0 button capabilities, skipping device")
                                break
                            }

                            if (caps.NumberInputValueCaps == 0) {
                                log.warn("HID device reports it has 0 buttons, skipping device")
                                break
                            }

                            button_caps_count := caps.NumberInputButtonCaps
                            button_caps := make([^]win32.HIDP_BUTTON_CAPS, caps.NumberInputButtonCaps, arena_allocator)
                            nts = win32.HidP_GetButtonCaps(.Input, button_caps, &button_caps_count, preparsed_data)
                            if (nts != win32.HIDP_STATUS_SUCCESS) {
                                log.error("Failed to get HID device's button capabilities")
                                break
                            }

                            value_caps_count := caps.NumberInputValueCaps
                            value_caps := make([^]win32.HIDP_VALUE_CAPS, caps.NumberInputValueCaps, arena_allocator)
                            nts = win32.HidP_GetValueCaps(.Input, value_caps, &value_caps_count, preparsed_data)
                            if (nts != win32.HIDP_STATUS_SUCCESS) {
                                log.error("Failed to get HID device's value capabilities")
                                break
                            }

                            switch device_info.hid.usUsagePage {
                                case win32.HID_USAGE_PAGE_GENERIC:
                                    if device_info.hid.usUsage == win32.HID_USAGE_GENERIC_GAMEPAD || device_info.hid.usUsage == win32.HID_USAGE_GENERIC_JOYSTICK {
                                        // TODO: Gyroscope, Accelerator, Touchpad (PlayStation only) and Rumble support.
                                        gamepad_id := device_info.hid.dwVendorId << 16 | device_info.hid.dwProductId
                                        if !(gamepad_id in SupportedControllers) {
                                            // TODO: Add support for more controllers in the future.
                                            // We can either have the user write a config file or send them
                                            // a utility program that can extract this data from their controller
                                            // and add support in the engine.
                                            log.warnf(
                                                "Controller not supported. Vendor: 0x%X, Product: 0x%X",
                                                device_info.hid.dwVendorId,
                                                device_info.hid.dwProductId,
                                            )
                                            virtual.arena_destroy(&arena)
                                            return 0
                                        }

                                        if caps.NumberInputButtonCaps > 1 {
                                            log.warn(
                                                "Controller has more than a single button capability. Not supported yet.",
                                            )
                                        }

                                        log.debug(caps)
                                        for b in 0 ..< caps.NumberInputButtonCaps {
                                            if !button_caps[b].IsRange {
                                                log.warn("Non-Range button capability found. Not supported yet.")
                                            }
                                            cap := button_caps[b]
                                            // log.debug(button_caps[b])
                                            // log.debug(button_caps[b].Range)
                                        }
                                        for v in 0 ..< caps.NumberInputValueCaps {
                                            if value_caps[v].IsRange {
                                                log.warn("Axis with Range found. Not supported yet.")
                                            }
                                            // log.debug(value_caps[v])
                                            // log.debug(value_caps[v].NotRange)
                                        }

                                        key := transmute(u64)raw_input_device_handle
                                        input_device := os_event_queue_input_device_connected(
                                            key,
                                            name,
                                            {.GAMEPAD},
                                            cast(u16)device_info.hid.dwVendorId,
                                            cast(u16)device_info.hid.dwProductId,
                                        )

                                        input_device.name = name
                                        input_device.arena = arena
                                        input_device_backend := windows_input_device(input_device)
                                        input_device_backend.raw_input_device_handle = raw_input_device_handle
                                        input_device_backend.hid_device_handle = hid_device_handle
                                        input_device_backend.preparsed_data = preparsed_data
                                        input_device_backend.preparsed_data_size = cast(u64)preparsed_data_size
                                        input_device_backend.button_caps = button_caps
                                        input_device_backend.button_caps_count = button_caps_count
                                        input_device_backend.value_caps = value_caps
                                        input_device_backend.value_caps_count = value_caps_count
                                        input_device_backend.gamepad_button_bindings = SupportedControllers[gamepad_id]
                                    }
                                case win32.HID_USAGE_PAGE_DIGITIZER:
                                    if device_info.hid.usUsage == win32.HID_USAGE_DIGITIZER_TOUCH_PAD {
                                        dims: m.vec2

                                        for v in 0 ..< caps.NumberInputValueCaps {
                                            if value_caps[v].UsagePage == win32.HID_USAGE_PAGE_GENERIC {
                                                if value_caps[v].NotRange.Usage == win32.HID_USAGE_GENERIC_X {
                                                    dims.x = cast(f32)value_caps[v].LogicalMax
                                                } else if value_caps[v].NotRange.Usage == win32.HID_USAGE_GENERIC_Y {
                                                    dims.y = cast(f32)value_caps[v].LogicalMax
                                                }
                                            }
                                        }

                                        key := transmute(u64)raw_input_device_handle
                                        input_device := os_event_queue_input_device_connected(
                                            key,
                                            name,
                                            {.TOUCHPAD},
                                            cast(u16)device_info.hid.dwVendorId,
                                            cast(u16)device_info.hid.dwProductId,
                                        )
                                        input_device.name = name
                                        input_device.arena = arena
                                        input_device.touchpad.dims = dims
                                        input_device_backend := windows_input_device(input_device)
                                        input_device_backend.raw_input_device_handle = raw_input_device_handle
                                        input_device_backend.hid_device_handle = hid_device_handle
                                        input_device_backend.preparsed_data = preparsed_data
                                        input_device_backend.preparsed_data_size = cast(u64)preparsed_data_size
                                        input_device_backend.button_caps = button_caps
                                        input_device_backend.button_caps_count = button_caps_count
                                        input_device_backend.value_caps = value_caps
                                        input_device_backend.value_caps_count = value_caps_count
                                    }
                            }
                    }
                case 2:
                    // GIDC_REMOVAL
                    key := transmute(u64)raw_input_device_handle
                    device := &zephr_ctx.input_devices_map[key]
                    if (device != nil) {
                        os_event_queue_input_device_disconnected(key)
                        virtual.arena_destroy(&device.arena)
                        bit_array.destroy(&device.keyboard.keycode_is_pressed_bitset)
                        bit_array.destroy(&device.keyboard.keycode_has_been_pressed_bitset)
                        bit_array.destroy(&device.keyboard.keycode_has_been_released_bitset)
                        bit_array.destroy(&device.keyboard.scancode_is_pressed_bitset)
                        bit_array.destroy(&device.keyboard.scancode_has_been_pressed_bitset)
                        bit_array.destroy(&device.keyboard.scancode_has_been_released_bitset)
                    }
            }
        case:
            result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)
    }

    return result
}

backend_init :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
    context.logger = logger

    queue.init(&w_os.events)

    class_name := win32.L("zephr.main_window")
    window_title := win32.utf8_to_wstring(string(window_title))

    hInstance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
    hIcon := win32.LoadImageW(
        nil,
        win32.utf8_to_wstring(string(icon_path)),
        win32.IMAGE_ICON,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_LOADFROMFILE,
    )
    wc := win32.WNDCLASSEXW {
        cbSize        = size_of(win32.WNDCLASSEXW),
        style         = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
        lpfnWndProc   = cast(win32.WNDPROC)window_proc,
        hInstance     = hInstance,
        lpszClassName = class_name,
        hIcon         = cast(win32.HICON)hIcon,
        hIconSm       = cast(win32.HICON)hIcon, // TODO: maybe we can have a 16x16 icon here. can be used on linux too
    }

    status := win32.RegisterClassExW(&wc)

    if status == 0 {
        log.error("Failed to register class")
    }

    // Make process aware of system scaling per monitor
    win32.SetProcessDpiAwarenessContext(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

    init_legacy_gl(class_name, hInstance)
    init_gl(class_name, window_title, window_size, window_non_resizable, hInstance)

    input_devices_types := []win32.RAWINPUTDEVICE {
         {
            usUsagePage = win32.HID_USAGE_PAGE_GENERIC,
            dwFlags = win32.RIDEV_DEVNOTIFY,
            usUsage = win32.HID_USAGE_GENERIC_MOUSE,
            hwndTarget = w_os.hwnd,
        },
         {
            usUsagePage = win32.HID_USAGE_PAGE_GENERIC,
            dwFlags = win32.RIDEV_DEVNOTIFY,
            usUsage = win32.HID_USAGE_GENERIC_KEYBOARD,
            hwndTarget = w_os.hwnd,
        },
         {
            usUsagePage = win32.HID_USAGE_PAGE_GENERIC,
            dwFlags = win32.RIDEV_DEVNOTIFY,
            usUsage = win32.HID_USAGE_GENERIC_GAMEPAD,
            hwndTarget = w_os.hwnd,
        },
         {
            usUsagePage = win32.HID_USAGE_PAGE_GENERIC,
            dwFlags = win32.RIDEV_DEVNOTIFY,
            usUsage = win32.HID_USAGE_GENERIC_JOYSTICK,
            hwndTarget = w_os.hwnd,
        },
         {
            usUsagePage = win32.HID_USAGE_PAGE_DIGITIZER,
            dwFlags = win32.RIDEV_DEVNOTIFY,
            usUsage = win32.HID_USAGE_DIGITIZER_TOUCH_PAD,
            hwndTarget = w_os.hwnd,
        },
    }

    when !RELEASE_BUILD {
        win32.DragAcceptFiles(w_os.hwnd, win32.TRUE)
    }

    if win32.RegisterRawInputDevices(
           raw_data(input_devices_types),
           cast(u32)len(input_devices_types),
           size_of(win32.RAWINPUTDEVICE),
       ) ==
       win32.FALSE {
        log.error("Failed to register raw input devices. Error: %x", win32.GetLastError())
        return
    }

    keyboard_map_update()
}

@(private = "file")
keyboard_map_update :: proc() {
    // reset the key codes to map directly to the virtual key codes
    for sc in Scancode {
        zephr_ctx.keyboard_scancode_to_keycode[sc] = auto_cast sc
        zephr_ctx.keyboard_keycode_to_scancode[auto_cast sc] = sc
    }

    for win32_scancode in 0 ..< 0xff {
        keyboard_map_apply_scancode(cast(u32)win32_scancode)
    }

    for win32_scancode in 0xE000 ..< 0xE06E {
        keyboard_map_apply_scancode(cast(u32)win32_scancode)
    }

    keyboard_map_apply_scancode(0xE11D) // PAUSE
}

keyboard_map_apply_scancode :: proc(win32_scancode: u32) {
    scancode := win32_scancode_to_zephr_scancode(win32_scancode)
    if scancode == .NULL {
        return
    }

    keycode: Keycode
    win32_keycode := win32.MapVirtualKeyW(win32_scancode, win32.MAPVK_VSC_TO_VK_EX)
    if win32_keycode < cast(u32)len(win32_keycode_to_zephr_keycode_map) {
        keycode = win32_keycode_to_zephr_keycode_map[win32_keycode]
    } else {
        keycode = .NULL
    }

    if keycode != .NULL {
        zephr_ctx.keyboard_scancode_to_keycode[scancode] = keycode
        zephr_ctx.keyboard_keycode_to_scancode[keycode] = scancode
    }
}

backend_change_vsync :: proc(on: bool) {
    w_os.wglSwapIntervalEXT(on ? 1 : 0)
}

backend_get_os_events :: proc() {
    msg: win32.MSG

    for win32.PeekMessageW(&msg, w_os.hwnd, 0, 0, win32.PM_REMOVE) != win32.FALSE {
        win32.TranslateMessage(&msg)
        win32.DispatchMessageW(&msg)
    }
}

backend_shutdown :: proc() {
    for id, &device in zephr_ctx.input_devices_map {
        virtual.arena_destroy(&device.arena)
        // The bit arrays can't be allocated using the arena because the 
        // Bit_Array struct allocates it itself using a dynamic array.
        bit_array.destroy(&device.keyboard.keycode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_released_bitset)
        bit_array.destroy(&device.keyboard.scancode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_released_bitset)
    }

    win32.wglMakeCurrent(w_os.device_ctx, nil)
    win32.wglDeleteContext(w_os.wgl_context)
    win32.ReleaseDC(w_os.hwnd, w_os.device_ctx)
    win32.DestroyWindow(w_os.hwnd)
}

backend_swapbuffers :: proc() {
    win32.SwapBuffers(w_os.device_ctx)
}

backend_set_cursor :: proc() {
    win32.SetCursor(zephr_ctx.cursors[zephr_ctx.cursor])
}

backend_init_cursors :: proc() {
    cursor_mask_and := []win32.c_int{0xFF}
    cursor_mask_xor := []win32.c_int{0x00}
    zephr_ctx.cursors[.INVISIBLE] = win32.CreateCursor(
        nil,
        0,
        0,
        1,
        1,
        raw_data(cursor_mask_and),
        raw_data(cursor_mask_xor),
    )
    zephr_ctx.cursors[.ARROW] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_ARROW,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.IBEAM] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_IBEAM,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.CROSSHAIR] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_CROSS,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.HAND] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_HAND,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.HRESIZE] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_SIZEWE,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.VRESIZE] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_SIZENS,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
    zephr_ctx.cursors[.DISABLED] =
    auto_cast win32.LoadImageW(
        nil,
        auto_cast win32._IDC_NO,
        win32.IMAGE_CURSOR,
        0,
        0,
        win32.LR_DEFAULTSIZE | win32.LR_SHARED,
    )
}

backend_gamepad_rumble :: proc(
    device: ^InputDevice,
    weak_motor: u16,
    strong_motor: u16,
    duration: time.Duration,
    delay: time.Duration,
) {
    // TODO:
}

backend_grab_cursor :: proc() {
    pos: win32.POINT
    win32.GetCursorPos(&pos)
    zephr_ctx.virt_mouse.pos_before_capture = {cast(f32)pos.x, cast(f32)pos.y}
    zephr_ctx.virt_mouse.virtual_pos = {cast(f32)pos.x, cast(f32)pos.y}
    zephr_ctx.cursor = .INVISIBLE
    win32.SetCursor(w_os.invisible_cursor)
    win32.SetCapture(w_os.hwnd)
}

backend_release_cursor :: proc() {
    win32.ReleaseCapture()
    win32.SetCursorPos(
        cast(win32.c_int)zephr_ctx.virt_mouse.pos_before_capture.x,
        cast(win32.c_int)zephr_ctx.virt_mouse.pos_before_capture.y,
    )
    win32.SetCursor(zephr_ctx.cursors[.ARROW])
}

backend_get_screen_size :: proc() -> m.vec2 {
    screen_size := m.vec2 {
        cast(f32)win32.GetSystemMetrics(win32.SM_CXSCREEN),
        cast(f32)win32.GetSystemMetrics(win32.SM_CYSCREEN),
    }
    return screen_size
}

backend_toggle_fullscreen :: proc(fullscreen: bool) {
    context.logger = logger
    // TODO: handle multiple monitors

    if fullscreen {
        w := cast(i32)zephr_ctx.window.pre_fullscreen_size.x
        h := cast(i32)zephr_ctx.window.pre_fullscreen_size.y
        
            //odinfmt: disable
        win_style := (win32.WS_OVERLAPPEDWINDOW if !zephr_ctx.window.non_resizable else win32.WS_OVERLAPPEDWINDOW & ~win32.WS_MAXIMIZEBOX & ~win32.WS_THICKFRAME) | win32.WS_VISIBLE
        //odinfmt: enable


        rect := win32.RECT{0, 0, w, h}
        win32.AdjustWindowRect(&rect, win_style, false)

        w = rect.right - rect.left
        h = rect.bottom - rect.top
        x := cast(i32)(zephr_ctx.screen_size.x / 2 - cast(f32)w / 2)
        y := cast(i32)(zephr_ctx.screen_size.y / 2 - cast(f32)h / 2)

        win32.SetWindowLongPtrW(w_os.hwnd, win32.GWL_STYLE, cast(win32.LONG_PTR)(win_style))
        win32.SetWindowPos(w_os.hwnd, nil, x, y, w, h, win32.SWP_FRAMECHANGED)
    } else {
        zephr_ctx.window.pre_fullscreen_size = zephr_ctx.window.size
        w := cast(i32)zephr_ctx.screen_size.x
        h := cast(i32)zephr_ctx.screen_size.y
        result := win32.SetWindowLongPtrW(
            w_os.hwnd,
            win32.GWL_STYLE,
            cast(win32.LONG_PTR)(win32.WS_VISIBLE | win32.WS_POPUPWINDOW),
        )
        win32.SetWindowPos(w_os.hwnd, win32.HWND_TOP, 0, 0, w, h, win32.SWP_FRAMECHANGED)
    }
}

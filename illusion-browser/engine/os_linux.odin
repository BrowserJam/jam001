//+build linux
//+private
package zephr

import "base:runtime"
import "core:container/bit_array"
import "core:container/queue"
import "core:fmt"
import "core:log"
import m "core:math/linalg/glsl"
import "core:mem"
import "core:mem/virtual"
import "core:net"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:time"

import gl "vendor:OpenGL"
import "vendor:stb/image"
import x11 "vendor:x11/xlib"

import "3rdparty/evdev"
import "3rdparty/glx"
import "3rdparty/inotify"
import "3rdparty/udev"

// TODO: support controller-specific stuff like haptics and adaptive triggers on DualSense
// TODO: support controller audio devices (DS4, DualSense, Xbox Series)
// TODO: support changing controller LEDs through evdev (maybe not lol cuz idk how this would work in Windows, I think
//       we would have to have controller specific stuff which would be a lot)

@(private = "file")
LinuxEvdevBinding :: struct {
    // this maps to struct input_event in <linux/input.h>
    type:        u16,
    code:        u16,
    is_positive: bool,
}

#assert(size_of(LinuxEvdevRange) == 8)

@(private = "file")
LinuxEvdevRange :: struct {
    // this maps to struct input_event in <linux/input.h>
    min: i32,
    max: i32,
}

#assert(size_of(LinuxInputDevice) == OS_INPUT_DEVICE_BACKEND_SIZE)

@(private = "file")
LinuxInputDevice :: struct {
    mouse_devnode:         string,
    touchpad_devnode:      string,
    keyboard_devnode:      string,
    gamepad_devnode:       string,
    motion_sensor_devnode: string,
    mouse_evdev:           ^evdev.libevdev,
    touchpad_evdev:        ^evdev.libevdev,
    keyboard_evdev:        ^evdev.libevdev,
    gamepad_evdev:         ^evdev.libevdev,
    motion_sensor_evdev:   ^evdev.libevdev,
    gamepad_bindings:      Bindings,
    gamepad_action_ranges: [cast(int)GamepadAction.COUNT + 1]LinuxEvdevRange,
    gamepad_rumble_id:     i16,
}

@(private = "file")
XdndState :: struct {
    transient:       struct {
        exchange_started: bool,
        source_window:    x11.Window,
        proposed_type:    x11.Atom,
    },
    xdnd_version:    u32,
    xdnd_aware:      x11.Atom,
    xdnd_enter:      x11.Atom,
    xdnd_leave:      x11.Atom,
    xdnd_drop:       x11.Atom,
    xdnd_selection:  x11.Atom,
    XDND_DATA:       x11.Atom,
    xdnd_type_list:  x11.Atom,
    supported_types: [6]x11.Atom,
}

@(private = "file")
Os :: struct {
    x11_display:        ^x11.Display,
    x11_window:         x11.Window,
    x11_colormap:       x11.Colormap,
    xkb:                x11.XkbDescPtr,
    xim:                x11.XIM,
    glx_context:        glx.Context,
    window_delete_atom: x11.Atom,
    xdnd:               XdndState,
    xinput_opcode:      i32,
    udevice:            ^udev.udev,
    udev_monitor:       ^udev.udev_monitor,
    inotify_fd:         os.Handle,
}

Bindings :: [GamepadAction]LinuxEvdevBinding

OsCursor :: x11.Cursor

@(private = "file")
XA_STRING :: x11.Atom(31)
@(private = "file")
XA_CARDINAL :: x11.Atom(6)
@(private = "file")
XDND_PROTOCOL_VERSION :: 5

@(private = "file")
l_os: Os

// TODO: No rumble support over wireless. We get a ENOSYS
// Seems to be a driver issue that we can't do anything about.
@(private = "file")
Xbox_Series_S_Bindings_Wireless :: #partial Bindings {
    .DPAD_LEFT = {type = EV_ABS, code = ABS_HAT0X, is_positive = false},
    .DPAD_DOWN = {type = EV_ABS, code = ABS_HAT0Y, is_positive = true},
    .DPAD_RIGHT = {type = EV_ABS, code = ABS_HAT0X, is_positive = true},
    .DPAD_UP = {type = EV_ABS, code = ABS_HAT0Y, is_positive = false},
    .FACE_LEFT = {type = EV_KEY, code = BTN_NORTH, is_positive = true},
    .FACE_DOWN = {type = EV_KEY, code = BTN_SOUTH, is_positive = true},
    .FACE_RIGHT = {type = EV_KEY, code = BTN_EAST, is_positive = true},
    .FACE_UP = {type = EV_KEY, code = BTN_WEST, is_positive = true},
    .START = {type = EV_KEY, code = BTN_START, is_positive = true},
    .SELECT = {type = EV_KEY, code = BTN_SELECT, is_positive = true},
    .STICK_LEFT = {type = EV_KEY, code = BTN_THUMBL, is_positive = true},
    .STICK_RIGHT = {type = EV_KEY, code = BTN_THUMBR, is_positive = true},
    .SHOULDER_LEFT = {type = EV_KEY, code = BTN_TL, is_positive = true},
    .SHOULDER_RIGHT = {type = EV_KEY, code = BTN_TR, is_positive = true},
    .STICK_LEFT_X_WEST = {type = EV_ABS, code = ABS_X, is_positive = false},
    .STICK_LEFT_X_EAST = {type = EV_ABS, code = ABS_X, is_positive = true},
    .STICK_LEFT_Y_NORTH = {type = EV_ABS, code = ABS_Y, is_positive = false},
    .STICK_LEFT_Y_SOUTH = {type = EV_ABS, code = ABS_Y, is_positive = true},
    .STICK_RIGHT_X_WEST = {type = EV_ABS, code = ABS_Z, is_positive = false},
    .STICK_RIGHT_X_EAST = {type = EV_ABS, code = ABS_Z, is_positive = true},
    .STICK_RIGHT_Y_NORTH = {type = EV_ABS, code = ABS_RZ, is_positive = false},
    .STICK_RIGHT_Y_SOUTH = {type = EV_ABS, code = ABS_RZ, is_positive = true},
    .TRIGGER_LEFT = {type = EV_ABS, code = ABS_BRAKE, is_positive = true},
    .TRIGGER_RIGHT = {type = EV_ABS, code = ABS_GAS, is_positive = true},
    .SYSTEM = {type = EV_KEY, code = BTN_MODE, is_positive = true},
}

@(private = "file")
Xbox_Series_S_Bindings_Wired :: #partial Bindings {
    .DPAD_LEFT = {type = EV_ABS, code = ABS_HAT0X, is_positive = false},
    .DPAD_DOWN = {type = EV_ABS, code = ABS_HAT0Y, is_positive = true},
    .DPAD_RIGHT = {type = EV_ABS, code = ABS_HAT0X, is_positive = true},
    .DPAD_UP = {type = EV_ABS, code = ABS_HAT0Y, is_positive = false},
    .FACE_LEFT = {type = EV_KEY, code = BTN_NORTH, is_positive = true},
    .FACE_DOWN = {type = EV_KEY, code = BTN_SOUTH, is_positive = true},
    .FACE_RIGHT = {type = EV_KEY, code = BTN_EAST, is_positive = true},
    .FACE_UP = {type = EV_KEY, code = BTN_WEST, is_positive = true},
    .START = {type = EV_KEY, code = BTN_START, is_positive = true},
    .SELECT = {type = EV_KEY, code = BTN_SELECT, is_positive = true},
    .STICK_LEFT = {type = EV_KEY, code = BTN_THUMBL, is_positive = true},
    .STICK_RIGHT = {type = EV_KEY, code = BTN_THUMBR, is_positive = true},
    .SHOULDER_LEFT = {type = EV_KEY, code = BTN_TL, is_positive = true},
    .SHOULDER_RIGHT = {type = EV_KEY, code = BTN_TR, is_positive = true},
    .STICK_LEFT_X_WEST = {type = EV_ABS, code = ABS_X, is_positive = false},
    .STICK_LEFT_X_EAST = {type = EV_ABS, code = ABS_X, is_positive = true},
    .STICK_LEFT_Y_NORTH = {type = EV_ABS, code = ABS_Y, is_positive = false},
    .STICK_LEFT_Y_SOUTH = {type = EV_ABS, code = ABS_Y, is_positive = true},
    .STICK_RIGHT_X_WEST = {type = EV_ABS, code = ABS_RX, is_positive = false},
    .STICK_RIGHT_X_EAST = {type = EV_ABS, code = ABS_RX, is_positive = true},
    .STICK_RIGHT_Y_NORTH = {type = EV_ABS, code = ABS_RY, is_positive = false},
    .STICK_RIGHT_Y_SOUTH = {type = EV_ABS, code = ABS_RY, is_positive = true},
    .TRIGGER_LEFT = {type = EV_ABS, code = ABS_Z, is_positive = true},
    .TRIGGER_RIGHT = {type = EV_ABS, code = ABS_RZ, is_positive = true},
    .SYSTEM = {type = EV_KEY, code = BTN_MODE, is_positive = true},
}

@(private = "file")
DualShock_3_Bindings :: #partial Bindings {
    .DPAD_LEFT = {type = EV_KEY, code = BTN_DPAD_LEFT, is_positive = true},
    .DPAD_DOWN = {type = EV_KEY, code = BTN_DPAD_DOWN, is_positive = true},
    .DPAD_RIGHT = {type = EV_KEY, code = BTN_DPAD_RIGHT, is_positive = true},
    .DPAD_UP = {type = EV_KEY, code = BTN_DPAD_UP, is_positive = true},
    .FACE_LEFT = {type = EV_KEY, code = BTN_WEST, is_positive = true},
    .FACE_DOWN = {type = EV_KEY, code = BTN_SOUTH, is_positive = true},
    .FACE_RIGHT = {type = EV_KEY, code = BTN_EAST, is_positive = true},
    .FACE_UP = {type = EV_KEY, code = BTN_NORTH, is_positive = true},
    .START = {type = EV_KEY, code = BTN_START, is_positive = true},
    .SELECT = {type = EV_KEY, code = BTN_SELECT, is_positive = true},
    .STICK_LEFT = {type = EV_KEY, code = BTN_THUMBL, is_positive = true},
    .STICK_RIGHT = {type = EV_KEY, code = BTN_THUMBR, is_positive = true},
    .SHOULDER_LEFT = {type = EV_KEY, code = BTN_TL, is_positive = true},
    .SHOULDER_RIGHT = {type = EV_KEY, code = BTN_TR, is_positive = true},
    .STICK_LEFT_X_WEST = {type = EV_ABS, code = ABS_X, is_positive = false},
    .STICK_LEFT_X_EAST = {type = EV_ABS, code = ABS_X, is_positive = true},
    .STICK_LEFT_Y_NORTH = {type = EV_ABS, code = ABS_Y, is_positive = false},
    .STICK_LEFT_Y_SOUTH = {type = EV_ABS, code = ABS_Y, is_positive = true},
    .STICK_RIGHT_X_WEST = {type = EV_ABS, code = ABS_RX, is_positive = false},
    .STICK_RIGHT_X_EAST = {type = EV_ABS, code = ABS_RX, is_positive = true},
    .STICK_RIGHT_Y_NORTH = {type = EV_ABS, code = ABS_RY, is_positive = false},
    .STICK_RIGHT_Y_SOUTH = {type = EV_ABS, code = ABS_RY, is_positive = true},
    .TRIGGER_LEFT = {type = EV_ABS, code = ABS_Z, is_positive = true},
    .TRIGGER_RIGHT = {type = EV_ABS, code = ABS_RZ, is_positive = true},
    .SYSTEM = {type = EV_KEY, code = BTN_MODE, is_positive = true},
}

@(private = "file")
DualShock_4_Bindings :: #partial Bindings {
    .DPAD_LEFT = {type = EV_ABS, code = ABS_HAT0X, is_positive = false},
    .DPAD_DOWN = {type = EV_ABS, code = ABS_HAT0Y, is_positive = true},
    .DPAD_RIGHT = {type = EV_ABS, code = ABS_HAT0X, is_positive = true},
    .DPAD_UP = {type = EV_ABS, code = ABS_HAT0Y, is_positive = false},
    .FACE_LEFT = {type = EV_KEY, code = BTN_WEST, is_positive = true},
    .FACE_DOWN = {type = EV_KEY, code = BTN_SOUTH, is_positive = true},
    .FACE_RIGHT = {type = EV_KEY, code = BTN_EAST, is_positive = true},
    .FACE_UP = {type = EV_KEY, code = BTN_NORTH, is_positive = true},
    .START = {type = EV_KEY, code = BTN_START, is_positive = true},
    .SELECT = {type = EV_KEY, code = BTN_SELECT, is_positive = true},
    .STICK_LEFT = {type = EV_KEY, code = BTN_THUMBL, is_positive = true},
    .STICK_RIGHT = {type = EV_KEY, code = BTN_THUMBR, is_positive = true},
    .SHOULDER_LEFT = {type = EV_KEY, code = BTN_TL, is_positive = true},
    .SHOULDER_RIGHT = {type = EV_KEY, code = BTN_TR, is_positive = true},
    .STICK_LEFT_X_WEST = {type = EV_ABS, code = ABS_X, is_positive = false},
    .STICK_LEFT_X_EAST = {type = EV_ABS, code = ABS_X, is_positive = true},
    .STICK_LEFT_Y_NORTH = {type = EV_ABS, code = ABS_Y, is_positive = false},
    .STICK_LEFT_Y_SOUTH = {type = EV_ABS, code = ABS_Y, is_positive = true},
    .STICK_RIGHT_X_WEST = {type = EV_ABS, code = ABS_RX, is_positive = false},
    .STICK_RIGHT_X_EAST = {type = EV_ABS, code = ABS_RX, is_positive = true},
    .STICK_RIGHT_Y_NORTH = {type = EV_ABS, code = ABS_RY, is_positive = false},
    .STICK_RIGHT_Y_SOUTH = {type = EV_ABS, code = ABS_RY, is_positive = true},
    .TRIGGER_LEFT = {type = EV_ABS, code = ABS_Z, is_positive = true},
    .TRIGGER_RIGHT = {type = EV_ABS, code = ABS_RZ, is_positive = true},
    .SYSTEM = {type = EV_KEY, code = BTN_MODE, is_positive = true},
}

@(private = "file")
DualSense_Bindings :: DualShock_4_Bindings

@(private = "file")
Switch_Pro_Bindings :: #partial Bindings {
    .DPAD_LEFT = {type = EV_ABS, code = ABS_HAT0X, is_positive = false},
    .DPAD_DOWN = {type = EV_ABS, code = ABS_HAT0Y, is_positive = true},
    .DPAD_RIGHT = {type = EV_ABS, code = ABS_HAT0X, is_positive = true},
    .DPAD_UP = {type = EV_ABS, code = ABS_HAT0Y, is_positive = false},
    .FACE_LEFT = {type = EV_KEY, code = BTN_WEST, is_positive = true},
    .FACE_DOWN = {type = EV_KEY, code = BTN_SOUTH, is_positive = true},
    .FACE_RIGHT = {type = EV_KEY, code = BTN_EAST, is_positive = true},
    .FACE_UP = {type = EV_KEY, code = BTN_NORTH, is_positive = true},
    .START = {type = EV_KEY, code = BTN_START, is_positive = true},
    .SELECT = {type = EV_KEY, code = BTN_SELECT, is_positive = true},
    .STICK_LEFT = {type = EV_KEY, code = BTN_THUMBL, is_positive = true},
    .STICK_RIGHT = {type = EV_KEY, code = BTN_THUMBR, is_positive = true},
    .SHOULDER_LEFT = {type = EV_KEY, code = BTN_TL, is_positive = true},
    .SHOULDER_RIGHT = {type = EV_KEY, code = BTN_TR, is_positive = true},
    .STICK_LEFT_X_WEST = {type = EV_ABS, code = ABS_X, is_positive = false},
    .STICK_LEFT_X_EAST = {type = EV_ABS, code = ABS_X, is_positive = true},
    .STICK_LEFT_Y_NORTH = {type = EV_ABS, code = ABS_Y, is_positive = false},
    .STICK_LEFT_Y_SOUTH = {type = EV_ABS, code = ABS_Y, is_positive = true},
    .STICK_RIGHT_X_WEST = {type = EV_ABS, code = ABS_RX, is_positive = false},
    .STICK_RIGHT_X_EAST = {type = EV_ABS, code = ABS_RX, is_positive = true},
    .STICK_RIGHT_Y_NORTH = {type = EV_ABS, code = ABS_RY, is_positive = false},
    .STICK_RIGHT_Y_SOUTH = {type = EV_ABS, code = ABS_RY, is_positive = true},
    .TRIGGER_LEFT = {type = EV_KEY, code = BTN_TL2, is_positive = true},
    .TRIGGER_RIGHT = {type = EV_KEY, code = BTN_TR2, is_positive = true},
    .SYSTEM = {type = EV_KEY, code = BTN_MODE, is_positive = true},
}

@(private = "file")
SupportedControllers := map[u32]Bindings {
    0x045E_0B12 = Xbox_Series_S_Bindings_Wired, // XBox Series S|X Controller Wired
    0x045E_0B13 = Xbox_Series_S_Bindings_Wireless, // XBox Series S|X Controller Wireless
    //0x0E6F_0162 = PDP_Xbox_One_Wired, // Performance Designed Products' Xbox One Controller
    0x054C_0268 = DualShock_3_Bindings, // Genuine Sony DualShock 3 (Wired & Wireless)
    0x054C_05C4 = DualShock_4_Bindings, // Genuine Sony DualShock 4 Gen1 (Wired & Wireless)
    0x054C_09CC = DualShock_4_Bindings, // Genuine Sony DualShock 4 Gen2 (Wired & Wireless)
    0x054C_0CE6 = DualSense_Bindings, // Genuine Sony DualSense
    0x057E_2009 = Switch_Pro_Bindings, // Switch Pro Controller
}

@(private = "file")
evdev_scancode_to_zephr_scancode_map := []Scancode {
    0   = .NULL,
    1   = .ESCAPE,
    2   = .KEY_1,
    3   = .KEY_2,
    4   = .KEY_3,
    5   = .KEY_4,
    6   = .KEY_5,
    7   = .KEY_6,
    8   = .KEY_7,
    9   = .KEY_8,
    10  = .KEY_9,
    11  = .KEY_0,
    12  = .MINUS,
    13  = .EQUALS,
    14  = .BACKSPACE,
    15  = .TAB,
    16  = .Q,
    17  = .W,
    18  = .E,
    19  = .R,
    20  = .T,
    21  = .Y,
    22  = .U,
    23  = .I,
    24  = .O,
    25  = .P,
    26  = .LEFT_BRACKET,
    27  = .RIGHT_BRACKET,
    28  = .ENTER,
    29  = .LEFT_CTRL,
    30  = .A,
    31  = .S,
    32  = .D,
    33  = .F,
    34  = .G,
    35  = .H,
    36  = .J,
    37  = .K,
    38  = .L,
    39  = .SEMICOLON,
    40  = .APOSTROPHE,
    41  = .GRAVE,
    42  = .LEFT_SHIFT,
    43  = .BACKSLASH,
    44  = .Z,
    45  = .X,
    46  = .C,
    47  = .V,
    48  = .B,
    49  = .N,
    50  = .M,
    51  = .COMMA,
    52  = .PERIOD,
    53  = .SLASH,
    54  = .RIGHT_SHIFT,
    55  = .KP_MULTIPLY,
    56  = .LEFT_ALT,
    57  = .SPACE,
    58  = .CAPS_LOCK,
    59  = .F1,
    60  = .F2,
    61  = .F3,
    62  = .F4,
    63  = .F5,
    64  = .F6,
    65  = .F7,
    66  = .F8,
    67  = .F9,
    68  = .F10,
    69  = .NUM_LOCK_OR_CLEAR,
    70  = .SCROLL_LOCK,
    71  = .KP_7,
    72  = .KP_8,
    73  = .KP_9,
    74  = .KP_MINUS,
    75  = .KP_4,
    76  = .KP_5,
    77  = .KP_6,
    78  = .KP_PLUS,
    79  = .KP_1,
    80  = .KP_2,
    81  = .KP_3,
    82  = .KP_0,
    83  = .KP_PERIOD,
    // 84
    85  = .LANG5, // KEY_ZENKAKUHANKAKU
    86  = .NON_US_BACKSLASH, // KEY_102ND
    87  = .F11,
    88  = .F12,
    89  = .INTERNATIONAL1, // KEY_RO,
    90  = .LANG3, // KEY_KATAKANA
    91  = .LANG4, // KEY_HIRAGANA
    92  = .INTERNATIONAL4, // KEY_HENKAN
    93  = .INTERNATIONAL2, // KEY_KATAKANAHIRAGANA
    94  = .INTERNATIONAL5, // KEY_MUHENKAN
    95  = .INTERNATIONAL5, // KEY_KPJOCOMMA
    96  = .KP_ENTER,
    97  = .RIGHT_CTRL,
    98  = .KP_DIVIDE,
    99  = .SYSREQ,
    100 = .RIGHT_ALT,
    101 = .NULL, // KEY_LINEFEED
    102 = .HOME,
    103 = .UP,
    104 = .PAGE_UP,
    105 = .LEFT,
    106 = .RIGHT,
    107 = .END,
    108 = .DOWN,
    109 = .PAGE_DOWN,
    110 = .INSERT,
    111 = .DELETE,
    112 = .NULL, // KEY_MACRO
    113 = .MUTE,
    114 = .VOLUME_DOWN,
    115 = .VOLUME_UP,
    116 = .POWER,
    117 = .KP_EQUALS,
    118 = .KP_PLUS_MINUS,
    119 = .PAUSE,
    // 120
    121 = .KP_COMMA,
    122 = .LANG1, // KEY_HANGUEL
    123 = .LANG2, // KEY_HANJA
    124 = .INTERNATIONAL3, // KEY_YEN
    125 = .LEFT_META,
    126 = .RIGHT_META,
    127 = .APPLICATION, // KEY_COMPOSE
    128 = .STOP,
    129 = .AGAIN,
    130 = .NULL, // KEY_PROPS
    131 = .UNDO,
    132 = .NULL, // KEY_FRONT
    133 = .COPY,
    134 = .NULL, // KEY_OPEN
    135 = .PASTE,
    136 = .FIND,
    137 = .CUT,
    138 = .HELP,
    139 = .MENU,
    140 = .NULL, // CALCULATOR
    141 = .NULL, // KEY_SETUP
    142 = .NULL, // SLEEP
    143 = .NULL, // KEY_WAKEUP
    144 = .NULL, // KEY_FILE
    145 = .NULL, // KEY_SENDFILE
    146 = .NULL, // KEY_DELETEFILE
    147 = .NULL, // KEY_XFER
    148 = .NULL, // KEY_PROG1
    149 = .NULL, // KEY_PROG2
    150 = .NULL, // WWW
    151 = .NULL, // KEY_MSDOS
    152 = .NULL, // KEY_COFFEE
    153 = .NULL, // KEY_DIRECTION
    154 = .NULL, // KEY_CYCLEWINDOWS
    155 = .NULL, // MAIL
    156 = .NULL, // AC_BOOKMARKS
    157 = .NULL, // COMPUTER
    158 = .NULL, // AC_BACK
    159 = .NULL, // AC_FORWARD
    160 = .NULL, // KEY_CLOSECD
    161 = .NULL, // EJECT
    162 = .NULL, // KEY_EJECTCLOSECD
    163 = .NULL, // AUDIO_NEXT
    164 = .NULL, // AUDIO_PLAY
    165 = .NULL, // AUDIO_PREV
    166 = .NULL, // AUDIO_STOP
    167 = .NULL, // KEY_RECORD
    168 = .NULL, // AUDIO_REWIND
    169 = .NULL, // KEY_PHONE
    170 = .NULL, // KEY_ISO
    171 = .NULL, // KEY_CONFIG
    172 = .NULL, // AC_HOME
    173 = .NULL, // AC_REFRESH
    174 = .NULL, // KEY_EXIT
    175 = .NULL, // KEY_MOVE
    176 = .NULL, // KEY_EDIT
    177 = .NULL, // KEY_SCROLLUP
    178 = .NULL, // KEY_SCROLLDOWN
    179 = .KP_LEFT_PAREN,
    180 = .KP_RIGHT_PAREN,
    181 = .NULL, // KEY_NEW
    182 = .NULL, // KEY_REDO
    183 = .F13,
    184 = .F14,
    185 = .F15,
    186 = .F16,
    187 = .F17,
    188 = .F18,
    189 = .F19,
    190 = .F20,
    191 = .F21,
    192 = .F22,
    193 = .F23,
    194 = .F24,
    // 195-199
    200 = .NULL, // KEY_PLAYCD
    201 = .NULL, // KEY_PAUSECD
    202 = .NULL, // KEY_PROG3
    203 = .NULL, // KEY_PROG4
    // 204
    205 = .NULL, // KEY_SUSPEND
    206 = .NULL, // KEY_CLOSE
    207 = .NULL, // KEY_PLAY
    208 = .NULL, // AUDIO_FASTFORWARD
    209 = .NULL, // KEY_BASSBOOST
    210 = .NULL, // KEY_PRINT
    211 = .NULL, // KEY_HP
    212 = .NULL, // KEY_CAMERA
    213 = .NULL, // KEY_SOUND
    214 = .NULL, // KEY_QUESTION
    215 = .NULL, // KEY_EMAIL
    216 = .NULL, // KEY_CHAT
    217 = .NULL, // AC_SEARCH
    218 = .NULL, // KEY_CONNECT
    219 = .NULL, // KEY_FINANCE
    220 = .NULL, // KEY_SPORT
    221 = .NULL, // KEY_SHOP
    222 = .ALT_ERASE,
    223 = .CANCEL,
    224 = .NULL, // BRIGHTNESS_DOWN
    225 = .NULL, // BRIGHNESS_UP
    226 = .NULL, // KEY_MEDIA
    227 = .NULL, // DISPLAY_SWITCH
    228 = .NULL, // KBD_ILLUM_TOGGLE
    229 = .NULL, // KBD_ILLUM_DOWN
    230 = .NULL, // KBD_ILLUM_UP
    231 = .NULL, // KEY_SEND
    232 = .NULL, // KEY_REPLY
    233 = .NULL, // KEY_FORWARDEMAIL
    234 = .NULL, // KEY_SAVE
    235 = .NULL, // KEY_DOCUMENTS
    236 = .NULL, // KEY_BATTERY
}

keyboard_fn_keysym_to_keycode := []Keycode {
    0x08 = .BACKSPACE,
    0x09 = .TAB,
    0x0b = .CLEAR,
    0x0d = .ENTER,
    0x13 = .PAUSE,
    0x14 = .SCROLL_LOCK,
    0x15 = .SYSREQ,
    0x1b = .ESCAPE,
    0x50 = .HOME,
    0x51 = .LEFT,
    0x52 = .UP,
    0x53 = .RIGHT,
    0x54 = .DOWN,
    0x55 = .PAGE_UP,
    0x56 = .PAGE_DOWN,
    0x57 = .END,
    0x60 = .SELECT,
    0x61 = .PRINT_SCREEN,
    0x62 = .EXECUTE,
    0x63 = .INSERT,
    0x65 = .UNDO,
    0x67 = .MENU,
    0x68 = .FIND,
    0x69 = .CANCEL,
    0x6a = .HELP,
    0x7f = .NUM_LOCK_OR_CLEAR,
    0x80 = .KP_SPACE,
    0x89 = .KP_TAB,
    0x8d = .KP_ENTER,
    0xbd = .KP_EQUALS,
    0xaa = .KP_MULTIPLY,
    0xab = .KP_PLUS,
    0xad = .KP_MINUS,
    0xae = .KP_DECIMAL,
    0xaf = .KP_DIVIDE,
    0xb0 = .KP_0,
    0xb1 = .KP_1,
    0xb2 = .KP_2,
    0xb3 = .KP_3,
    0xb4 = .KP_4,
    0xb5 = .KP_5,
    0xb6 = .KP_6,
    0xb7 = .KP_7,
    0xb8 = .KP_8,
    0xb9 = .KP_9,
    0xbe = .F1,
    0xbf = .F2,
    0xc0 = .F3,
    0xc1 = .F4,
    0xc2 = .F5,
    0xc3 = .F6,
    0xc4 = .F7,
    0xc5 = .F8,
    0xc6 = .F9,
    0xc7 = .F10,
    0xc8 = .F11,
    0xc9 = .F12,
    0xca = .F13,
    0xcb = .F14,
    0xcc = .F15,
    0xcd = .F16,
    0xce = .F17,
    0xcf = .F18,
    0xd0 = .F19,
    0xd1 = .F20,
    0xd2 = .F21,
    0xd3 = .F22,
    0xd4 = .F23,
    0xd5 = .F24,
    0xe1 = .LEFT_SHIFT,
    0xe2 = .RIGHT_SHIFT,
    0xe3 = .LEFT_CTRL,
    0xe4 = .RIGHT_CTRL,
    0xe5 = .CAPS_LOCK,
    0xe6 = .CAPS_LOCK,
    0xe7 = .LEFT_META,
    0xe8 = .RIGHT_META,
    0xe9 = .LEFT_ALT,
    0xea = .RIGHT_ALT,
    0xeb = .LEFT_META,
    0xec = .RIGHT_META,
    0xff = .DELETE,
}

keyboard_fn_ex_keysym_to_keycode := []Keycode {
    0x03 = .RIGHT_ALT,
    0xff = .NULL,
}

keyboard_latin_1_fn_ex_keysym_to_keycode := []Keycode {
    0x20 = .SPACE,
    0x27 = .APOSTROPHE,
    0x2c = .COMMA,
    0x2d = .MINUS,
    0x2e = .PERIOD,
    0x2f = .SLASH,
    0x30 = .KEY_0,
    0x31 = .KEY_1,
    0x32 = .KEY_2,
    0x33 = .KEY_3,
    0x34 = .KEY_4,
    0x35 = .KEY_5,
    0x36 = .KEY_6,
    0x37 = .KEY_7,
    0x38 = .KEY_8,
    0x39 = .KEY_9,
    0x3b = .SEMICOLON,
    0x3d = .EQUALS,
    0x5b = .LEFT_BRACKET,
    0x5c = .BACKSLASH,
    0x5d = .RIGHT_BRACKET,
    0x60 = .GRAVE,
    0x61 = .A,
    0x62 = .B,
    0x63 = .C,
    0x64 = .D,
    0x65 = .E,
    0x66 = .F,
    0x67 = .G,
    0x68 = .H,
    0x69 = .I,
    0x6a = .J,
    0x6b = .K,
    0x6c = .L,
    0x6d = .M,
    0x6e = .N,
    0x6f = .O,
    0x70 = .P,
    0x71 = .Q,
    0x72 = .R,
    0x73 = .S,
    0x74 = .T,
    0x75 = .U,
    0x76 = .V,
    0x77 = .W,
    0x78 = .X,
    0x79 = .Y,
    0x7a = .Z,
    0xff = .NULL,
}

@(private = "file")
x11_go_fullscreen :: proc() {
    // remove the resizing constraint before going fullscreen so WMs such as gnome
    // can add the _NET_WM_ACTION_FULLSCREEN action to the _NET_WM_ALLOWED_ACTIONS atom
    // and properly fullscreen the window
    size_hints := x11.AllocSizeHints()

    zephr_ctx.window.pre_fullscreen_size = zephr_ctx.window.size
    if (size_hints != nil) {
        size_hints.flags = {.PPosition, .PSize}
        size_hints.width = cast(i32)zephr_ctx.window.size.x
        size_hints.height = cast(i32)zephr_ctx.window.size.y
        x11.SetWMNormalHints(l_os.x11_display, l_os.x11_window, size_hints)
        x11.Free(size_hints)
    }

    xev: x11.XEvent
    wm_state := x11.InternAtom(l_os.x11_display, "_NET_WM_STATE", false)
    fullscreen := x11.InternAtom(l_os.x11_display, "_NET_WM_STATE_FULLSCREEN", false)
    xev.type = .ClientMessage
    xev.xclient.window = l_os.x11_window
    xev.xclient.message_type = wm_state
    xev.xclient.format = 32
    xev.xclient.data.l[0] = 1 // _NET_WM_STATE_ADD
    xev.xclient.data.l[1] = cast(int)fullscreen
    xev.xclient.data.l[2] = 0
    x11.SendEvent(
        l_os.x11_display,
        x11.DefaultRootWindow(l_os.x11_display),
        false,
        {.SubstructureNotify, .SubstructureRedirect},
        &xev,
    )
}

@(private = "file")
x11_return_fullscreen :: proc() {
    xev: x11.XEvent
    wm_state := x11.InternAtom(l_os.x11_display, "_NET_WM_STATE", false)
    fullscreen := x11.InternAtom(l_os.x11_display, "_NET_WM_STATE_FULLSCREEN", false)
    xev.type = .ClientMessage
    xev.xclient.window = l_os.x11_window
    xev.xclient.message_type = wm_state
    xev.xclient.format = 32
    xev.xclient.data.l[0] = 0 // _NET_WM_STATE_REMOVE
    xev.xclient.data.l[1] = cast(int)fullscreen
    xev.xclient.data.l[2] = 0
    x11.SendEvent(
        l_os.x11_display,
        x11.DefaultRootWindow(l_os.x11_display),
        false,
        {.SubstructureNotify, .SubstructureRedirect},
        &xev,
    )

    // restore the resizing constraint as well as the pre-fullscreen window size
    // when returning from fullscreen
    size_hints := x11.AllocSizeHints()

    if (size_hints != nil) {
        size_hints.flags = {.PPosition, .PSize}
        size_hints.width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
        size_hints.height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
        if (zephr_ctx.window.non_resizable) {
            size_hints.flags |= {.PMinSize, .PMaxSize}
            size_hints.min_width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
            size_hints.min_height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
            size_hints.max_width = cast(i32)zephr_ctx.window.pre_fullscreen_size.x
            size_hints.max_height = cast(i32)zephr_ctx.window.pre_fullscreen_size.y
        }
        x11.SetWMNormalHints(l_os.x11_display, l_os.x11_window, size_hints)
        x11.Free(size_hints)
    }
}

backend_toggle_fullscreen :: proc(fullscreen: bool) {
    if fullscreen {
        x11_return_fullscreen()
    } else {
        x11_go_fullscreen()
    }
}

@(private = "file")
x11_assign_window_icon :: proc(icon_path: cstring, window_title: cstring) {
    icon_width, icon_height: i32
    icon_data := image.load(icon_path, &icon_width, &icon_height, nil, 4)
    defer image.image_free(icon_data)
    log.assert(icon_data != nil, "Failed to load icon image")

    target_size := 2 + icon_width * icon_height

    data := make([]u64, target_size)
    defer delete(data)

    // first two elements are width and height
    data[0] = cast(u64)icon_width
    data[1] = cast(u64)icon_height

    for i in 0 ..< (icon_width * icon_height) {
        data[i + 2] =
            (cast(u64)icon_data[i * 4] << 16) |
            (cast(u64)icon_data[i * 4 + 1] << 8) |
            (cast(u64)icon_data[i * 4 + 2] << 0) |
            (cast(u64)icon_data[i * 4 + 3] << 24)
    }

    net_wm_icon := x11.InternAtom(l_os.x11_display, "_NET_WM_ICON", false)
    x11.ChangeProperty(
        l_os.x11_display,
        l_os.x11_window,
        net_wm_icon,
        XA_CARDINAL,
        32,
        x11.PropModeReplace,
        raw_data(data),
        target_size,
    )
}

backend_get_screen_size :: proc() -> m.vec2 {
    size := get_active_monitor_dims(x11.DefaultRootWindow(l_os.x11_display))

    return m.vec2{size.z, size.w}
}

@(private = "file")
get_active_monitor_dims :: proc(root: x11.Window) -> m.vec4 {
    c_pos := get_cursor_pos(root)

    scr_resources := x11.XRRGetScreenResources(l_os.x11_display, root)
    log.assert(scr_resources != nil, "Failed to get X11 screen resources")
    defer x11.XRRFreeScreenResources(scr_resources)

    dims: m.vec4

    for i in 0 ..< scr_resources.noutput {
        output_info := x11.XRRGetOutputInfo(l_os.x11_display, scr_resources, scr_resources.outputs[i])
        if output_info.connection == .RR_Connected {
            if output_info.crtc == 0 { // ??? idk lol gets rid of a crtc error and the displays work fine anyway
                x11.XRRFreeOutputInfo(output_info)
                continue
            }
            crtc_info := x11.XRRGetCrtcInfo(l_os.x11_display, scr_resources, output_info.crtc)
            if crtc_info != nil {
                if cast(i32)c_pos.x >= crtc_info.x &&
                   cast(i32)c_pos.x <= cast(i32)crtc_info.width + crtc_info.x &&
                   cast(i32)c_pos.y >= crtc_info.y &&
                   cast(i32)c_pos.y <= cast(i32)crtc_info.height + crtc_info.y {
                    log.infof("Active Monitor is %d with Resolution %dx%d", i, crtc_info.width, crtc_info.height)
                    dims =  {
                        cast(f32)crtc_info.x,
                        cast(f32)crtc_info.y,
                        cast(f32)crtc_info.width,
                        cast(f32)crtc_info.height,
                    }
                } else {
                    log.infof("Found Monitor %d with Resolution %dx%d", i, crtc_info.width, crtc_info.height)
                }
                x11.XRRFreeCrtcInfo(crtc_info)
            }
        }
        x11.XRRFreeOutputInfo(output_info)
    }

    if dims == {0, 0, 0, 0} {
        log.error("Failed to find the active monitor")
    }

    return dims
}

@(private = "file")
x11_create_window :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
    screen_num := x11.DefaultScreen(l_os.x11_display)

    // Load up GL/GLX before creating the window to be able to use the FBConfig's visual info when creating the window.
    gl.load_up_to(
        3,
        3,
        proc(p: rawptr, name: cstring) {(cast(^rawptr)p)^ = glx.GetProcAddressARB(raw_data(string(name)))},
    )

    glx_major: i32
    glx_minor: i32
    glx.QueryVersion(l_os.x11_display, &glx_major, &glx_minor)

    log.infof("Loaded GLX: %d.%d", glx_major, glx_minor)
    
    //odinfmt: disable
    visual_attributes := []i32 {
        glx.X_RENDERABLE, 1,
        glx.DRAWABLE_TYPE, glx.WINDOW_BIT,
        glx.X_VISUAL_TYPE, glx.TRUE_COLOR,
        glx.RENDER_TYPE, glx.RGBA_BIT,
        glx.BUFFER_SIZE, 8,
        glx.RED_SIZE, 8,
        glx.GREEN_SIZE, 8,
        glx.BLUE_SIZE, 8,
        glx.ALPHA_SIZE, 8,
        glx.DEPTH_SIZE, 24,
        glx.DOUBLEBUFFER, 1,
        x11.None,
    }
    //odinfmt: enable

    num_fbc: i32
    fbc := glx.ChooseFBConfig(l_os.x11_display, screen_num, raw_data(visual_attributes), &num_fbc)
    visual_info := glx.GetVisualFromFBConfig(l_os.x11_display, fbc[0])
    defer x11.Free(visual_info)
    defer x11.Free(fbc)

    //odinfmt: disable
    context_attributes := []i32 {
        glx.CONTEXT_MAJOR_VERSION_ARB, 3,
        glx.CONTEXT_MINOR_VERSION_ARB, 3,
        glx.CONTEXT_PROFILE_MASK_ARB,  glx.CONTEXT_CORE_PROFILE_BIT_ARB,
        x11.None,
    }
    //odinfmt: enable

    l_os.glx_context = glx.CreateContextAttribsARB(l_os.x11_display, fbc[0], nil, true, raw_data(context_attributes))

    if l_os.glx_context == nil {
        log.error("Failed to create GLX context")
        return
    }

    root := x11.RootWindow(l_os.x11_display, visual_info.screen)
    active_monitor_dims := get_active_monitor_dims(root)

    l_os.x11_colormap = x11.CreateColormap(l_os.x11_display, root, visual_info.visual, x11.ColormapAlloc.AllocNone)

    attributes: x11.XSetWindowAttributes
    attributes.event_mask =  {
        .Exposure,
        .KeyPress,
        .KeyRelease,
        .StructureNotify,
        .ButtonPress,
        .ButtonRelease,
        .PointerMotion,
        .EnterWindow,
        .LeaveWindow,
    }
    attributes.colormap = l_os.x11_colormap

    window_start_x :=
        (cast(i32)active_monitor_dims.z / 2 - cast(i32)window_size.x / 2) + cast(i32)active_monitor_dims.x
    window_start_y :=
        (cast(i32)active_monitor_dims.w / 2 - cast(i32)window_size.y / 2) + cast(i32)active_monitor_dims.y

    l_os.x11_window = x11.CreateWindow(
        l_os.x11_display,
        root,
        window_start_x,
        window_start_y,
        cast(u32)window_size.x,
        cast(u32)window_size.y,
        0,
        visual_info.depth,
        .InputOutput,
        visual_info.visual,
        {.CWColormap, .CWEventMask},
        &attributes,
    )

    if (icon_path != "") {
        x11_assign_window_icon(icon_path, window_title)
    }

    // Hints to the WM that the window is a normal window
    // Of course this is only a hint and the WM can ignore it
    net_wm_window_type := x11.InternAtom(l_os.x11_display, "_NET_WM_WINDOW_TYPE", false)
    net_wm_window_type_normal := x11.InternAtom(l_os.x11_display, "_NET_WM_WINDOW_TYPE_NORMAL", false)
    x11.ChangeProperty(
        l_os.x11_display,
        l_os.x11_window,
        net_wm_window_type,
        x11.XA_ATOM,
        32,
        x11.PropModeReplace,
        &net_wm_window_type_normal,
        1,
    )

    // define Xdnd atoms
    l_os.xdnd.xdnd_enter = x11.InternAtom(l_os.x11_display, "XdndEnter", false)
    l_os.xdnd.xdnd_leave = x11.InternAtom(l_os.x11_display, "XdndLeave", false)
    l_os.xdnd.xdnd_drop = x11.InternAtom(l_os.x11_display, "XdndDrop", false)
    l_os.xdnd.xdnd_selection = x11.InternAtom(l_os.x11_display, "XdndSelection", false)
    l_os.xdnd.XDND_DATA = x11.InternAtom(l_os.x11_display, "XDND_DATA", false)
    l_os.xdnd.xdnd_type_list = x11.InternAtom(l_os.x11_display, "XdndTypeList", false)
    l_os.xdnd.supported_types = [?]x11.Atom {
        x11.InternAtom(l_os.x11_display, "text/plain", false),
        x11.InternAtom(l_os.x11_display, "text/plain;charset=utf-8", false),
        x11.InternAtom(l_os.x11_display, "text/uri-list", false),
        x11.InternAtom(l_os.x11_display, "UTF8_STRING", false),
        x11.InternAtom(l_os.x11_display, "TEXT", false),
        x11.InternAtom(l_os.x11_display, "STRING", false),
    }

    l_os.xdnd.xdnd_version = XDND_PROTOCOL_VERSION

    // Add XdndAware property to the window
    l_os.xdnd.xdnd_aware = x11.InternAtom(l_os.x11_display, "XdndAware", false)
    x11.ChangeProperty(
        l_os.x11_display,
        l_os.x11_window,
        l_os.xdnd.xdnd_aware,
        x11.XA_ATOM,
        32,
        x11.PropModeReplace,
        &l_os.xdnd.xdnd_version,
        1,
    )

    wm_delete_window := x11.InternAtom(l_os.x11_display, "WM_DELETE_WINDOW", false)
    x11.SetWMProtocols(l_os.x11_display, l_os.x11_window, &wm_delete_window, 1)
    l_os.window_delete_atom = wm_delete_window

    // set window name
    {
        UTF8_STRING := x11.InternAtom(l_os.x11_display, "UTF8_STRING", false)
        x11.StoreName(l_os.x11_display, l_os.x11_window, window_title)
        text_property: x11.XTextProperty
        text_property.value = raw_data(string(window_title))
        text_property.format = 8
        text_property.encoding = UTF8_STRING
        text_property.nitems = len(window_title)
        x11.SetWMName(l_os.x11_display, l_os.x11_window, &text_property)
        net_wm_name := x11.InternAtom(l_os.x11_display, "_NET_WM_NAME", false)
        wm_class := x11.InternAtom(l_os.x11_display, "WM_CLASS", false)
        x11.ChangeProperty(
            l_os.x11_display,
            l_os.x11_window,
            net_wm_name,
            UTF8_STRING,
            8,
            x11.PropModeReplace,
            raw_data(string(window_title)),
            cast(i32)len(window_title),
        )
        x11.ChangeProperty(
            l_os.x11_display,
            l_os.x11_window,
            wm_class,
            XA_STRING,
            8,
            x11.PropModeReplace,
            raw_data(string(window_title)),
            cast(i32)len(window_title),
        )

        // name to be displayed when the window is reduced to an icon
        net_wm_icon_name := x11.InternAtom(l_os.x11_display, "_NET_WM_ICON_NAME", false)
        x11.ChangeProperty(
            l_os.x11_display,
            l_os.x11_window,
            net_wm_icon_name,
            UTF8_STRING,
            8,
            x11.PropModeReplace,
            raw_data(string(window_title)),
            cast(i32)len(window_title),
        )

        text_property.encoding = XA_STRING
        x11.SetWMIconName(l_os.x11_display, l_os.x11_window, &text_property)

        class_hint := x11.AllocClassHint()

        if (class_hint != nil) {
            class_hint.res_name = window_title
            class_hint.res_class = window_title
            x11.SetClassHint(l_os.x11_display, l_os.x11_window, class_hint)
            x11.Free(class_hint)
        }
    }

    size_hints := x11.AllocSizeHints()

    if (size_hints != nil) {
        size_hints.flags = {.PPosition, .PSize}
        /* size_hints->win_gravity = StaticGravity; */
        size_hints.x = window_start_x
        size_hints.y = window_start_y
        size_hints.width = cast(i32)window_size.x
        size_hints.height = cast(i32)window_size.y
        if (window_non_resizable) {
            size_hints.flags |= {.PMinSize, .PMaxSize}
            size_hints.min_width = cast(i32)window_size.x
            size_hints.min_height = cast(i32)window_size.y
            size_hints.max_width = cast(i32)window_size.x
            size_hints.max_height = cast(i32)window_size.y
        }
        x11.SetWMNormalHints(l_os.x11_display, l_os.x11_window, size_hints)
        x11.Free(size_hints)
    }

    x11.MapWindow(l_os.x11_display, l_os.x11_window)

    glx.MakeCurrent(l_os.x11_display, l_os.x11_window, l_os.glx_context)

    gl_version := gl.GetString(gl.VERSION)
    log.infof("GL Version: %s", gl_version)

    glx.SwapIntervalEXT(l_os.x11_display, l_os.x11_window, 1)

    // we enable blending for text
    gl.Enable(gl.BLEND)
    gl.Enable(gl.DEPTH_TEST)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
}

@(private = "file")
keyboard_map_update :: proc() {
    // reset the scancodes to map directly to the keycodes
    for sc in Scancode {
        zephr_ctx.keyboard_scancode_to_keycode[sc] = auto_cast sc
        zephr_ctx.keyboard_keycode_to_scancode[auto_cast sc] = sc
    }

    state: x11.XkbStateRec
    x11.XkbGetUpdatedMap(l_os.x11_display, x11.XkbAllClientInfoMask, l_os.xkb)

    group: u8 = 0
    if x11.XkbGetState(l_os.x11_display, x11.XkbUseCoreKbd, &state) == .Success {
        group = state.group
    }

    first_keycode := l_os.xkb.min_key_code
    last_keycode := l_os.xkb.max_key_code
    if (last_keycode > cast(u8)len(evdev_scancode_to_zephr_scancode_map) - 8) {
        last_keycode = cast(u8)len(evdev_scancode_to_zephr_scancode_map) - 8 - 1
    }

    // documentation here: https://www.x.org/releases/current/doc/libX11/XKB/xkblib.html
    // evdev keycodes are 8 less than x11 keycodes
    x11.XkbGetKeySyms(l_os.x11_display, cast(u32)first_keycode, cast(u32)(last_keycode - first_keycode), l_os.xkb)
    cmap := l_os.xkb._map
    for x11keycode in 8 ..< last_keycode {
        sym_map := &cmap.key_sym_map[x11keycode]
        sym_start_idx := sym_map.offset
        // since we do not want any key modifiers, our shift is 0
        shift := 0
        sym_idx := cast(int)sym_start_idx + (cast(int)sym_map.width * cast(int)group) + shift
        sym := cmap.syms[sym_idx]

        scancode := evdev_scancode_to_zephr_scancode_map[x11keycode - 8]
        keycode := keyboard_keysym_to_keycode(cast(x11.KeySym)sym)

        when ODIN_DEBUG {
            log.debugf("scancode: %s -> key_sym: %s = 0x%x", scancode, x11.KeysymToString(cast(x11.KeySym)sym), sym)
        }

        zephr_ctx.keyboard_scancode_to_keycode[scancode] = keycode
        zephr_ctx.keyboard_keycode_to_scancode[keycode] = scancode
    }

    when ODIN_DEBUG {
        for sc in Scancode {
            log.debugf("scancode: %s -> keycode: %s", sc, zephr_ctx.keyboard_scancode_to_keycode[sc])
        }
    }
}

@(private = "file")
keyboard_keysym_to_keycode :: proc(key_sym: x11.KeySym) -> Keycode {
    key_sym := cast(u32)key_sym
    if key_sym >= 0xff00 && key_sym <= 0xffff {
        return keyboard_fn_keysym_to_keycode[key_sym - 0xff00]
    } else if key_sym >= 0xfe00 && key_sym <= 0xfeff {
        return keyboard_fn_ex_keysym_to_keycode[key_sym - 0xfe00]
    } else if key_sym >= 0x100 && key_sym <= 0x1ff {
        return .NULL
    } else if key_sym <= 0xff {
        return keyboard_latin_1_fn_ex_keysym_to_keycode[key_sym]
    } else {
        return .NULL
    }
}

@(private = "file")
x11_error_handler :: proc "c" (display: ^x11.Display, event: ^x11.XErrorEvent) -> i32 {
    context = runtime.default_context()
    context.logger = logger

    buf := make([^]u8, 2048)
    defer free(buf)
    x11.GetErrorText(display, cast(i32)event.error_code, buf, 2048)
    str := strings.string_from_ptr(buf, 2048)
    log.errorf("X11 Error: %s", str)
    return 0
}

backend_init :: proc(window_title: cstring, window_size: m.vec2, icon_path: cstring, window_non_resizable: bool) {
    context.logger = logger

    l_os.x11_display = x11.OpenDisplay(nil)

    x11.SetErrorHandler(x11_error_handler)

    if l_os.x11_display == nil {
        log.error("Failed to open X11 display")
        return
    }

    {
        // loads the XMODIFIERS environment variable to see what IME to use
        x11.SetLocaleModifiers("")
        l_os.xim = x11.OpenIM(l_os.x11_display, nil, nil, nil)
        if (l_os.xim == nil) {
            // fallback to internal input method
            x11.SetLocaleModifiers("@im=none")
            l_os.xim = x11.OpenIM(l_os.x11_display, nil, nil, nil)
        }

        // HACK: this is a workaround to force xlib to send us a MappingNotify
        // event when the keyboard layout changes. No event is sent if this isn't called
        x11.KeysymToKeycode(l_os.x11_display, .XK_F1)

        x11.AutoRepeatOn(l_os.x11_display)
        major: i32 = 1
        minor: i32 = 0
        success := x11.XkbQueryExtension(l_os.x11_display, nil, nil, nil, &major, &minor)
        log.assert(cast(bool)success, "XKB extension not available")
        success = x11.XkbUseExtension(l_os.x11_display, &major, &minor)
        log.assert(cast(bool)success, "Failed to initialize XKB extension")

        l_os.xkb = x11.XkbGetMap(l_os.x11_display, x11.XkbAllClientInfoMask, x11.XkbUseCoreKbd)

        // this will remove KeyRelease events for held keys.
        repeat: b32
        x11.XkbSetDetectableAutoRepeat(l_os.x11_display, true, &repeat)

        x11.XkbSelectEvents(
            l_os.x11_display,
            x11.XkbUseCoreKbd,
            {.MapNotify, .ActionMessage},
            {.MapNotify, .ActionMessage},
        )

        keyboard_map_update()
    }

    {
        // TODO: check if user is part of 'input' group which is needed to read raw input events
    }

    {
        l_os.udevice = udev.new()

        {
            l_os.udev_monitor = udev.monitor_new_from_netlink(l_os.udevice, "udev")

            // Monitor all hid devices that get plugged or unplugged, we don't monitor
            // the input subsystem here because some devices get merged as the first hid ancestor
            // and that gets used as part of the device id, so when a device gets disconnected
            // we can find the same hid ancestor using udev.device_get_parent_with_subsystem_devtype()
            // NOTE: The aforementioned procedure does returns a nil parent if the monitored subsystem is set to input
            // (even if the syspath matches) for whatever reason.
            udev.monitor_filter_add_match_subsystem_devtype(l_os.udev_monitor, "hid", nil)
            udev.monitor_enable_receiving(l_os.udev_monitor)

            fd := udev.monitor_get_fd(l_os.udev_monitor)
            fd_flags, err := linux.fcntl(fd, linux.F_GETFL)
            linux.fcntl(fd, linux.F_SETFL, fd_flags | {.NONBLOCK})
        }

        enumerate := udev.enumerate_new(l_os.udevice)
        // For our initialization enumerator we enumerate the input subsystem instead of the hid subsystem
        // because some devices aren't listed under the hid subsystem (e.g laptop's keyboard)
        // so this ensures we get as many input devices as possible while not running into issues when disconnecting
        // devices.
        // TODO: devices listed under /devices/virtual/ are still not (dis)connecting (when hot-plugged) properly.
        // This mouse I have seems to be added as a regular hid device at first but then the hid device is removed
        // and two virtual "input" devices are added under /devices/virtual/input/inputXXX/
        // I currently have no way of handling that and the engine ends up thinking the mouse was quickly connected
        // and disconnected.
        // These same virtual devices have a problem of not finding the proper ancestor when disconnecting if they were
        // added to the engine device map through the initialization enumeration.
        // This is not a regression of the new code, it's been like this forever.
        udev.enumerate_add_match_subsystem(enumerate, "input")
        udev.enumerate_scan_devices(enumerate)

        first_device := udev.enumerate_get_list_entry(enumerate)

        list_entry: ^udev.udev_list_entry
        for list_entry = first_device; list_entry != nil; list_entry = udev.list_entry_get_next(list_entry) {
            syspath := udev.list_entry_get_name(list_entry)
            dev := udev.device_new_from_syspath(l_os.udevice, syspath)

            udev_device_try_add(dev)

            udev.device_unref(dev)
        }

        udev.enumerate_unref(enumerate)
    }

    x11_create_window(window_title, window_size, icon_path, window_non_resizable)

    when !RELEASE_BUILD {
        l_os.inotify_fd = inotify.init1(os.O_NONBLOCK)
        watch_shaders()
    }
}

backend_change_vsync :: proc(on: bool) {
    glx.SwapIntervalEXT(l_os.x11_display, l_os.x11_window, on ? 1 : 0)
}

@(private = "file", disabled = RELEASE_BUILD)
watch_shaders :: proc() {
    wd := inotify.add_watch(l_os.inotify_fd, "engine/shaders", inotify.IN_MODIFY)

    if wd < 0 {
        log.errorf("Failed to watch shaders directory")
    }
}

backend_gamepad_rumble :: proc(
    device: ^InputDevice,
    weak_motor: u16,
    strong_motor: u16,
    duration: time.Duration,
    delay: time.Duration,
) {
    context.logger = logger

    device_backend := linux_input_device(device)
    effect: evdev.ff_effect
    effect.type = FF_RUMBLE
    effect.id = device_backend.gamepad_rumble_id
    effect.replay.length = cast(u16)time.duration_milliseconds(duration)
    effect.replay.delay = cast(u16)time.duration_milliseconds(delay)
    effect.u.rumble.weak_magnitude = weak_motor
    effect.u.rumble.strong_magnitude = strong_motor
    gamepad_fd := evdev.get_fd(device_backend.gamepad_evdev)
    errno := linux.ioctl(cast(linux.Fd)gamepad_fd, EVIOCSFF(), cast(uintptr)&effect)
    if linux.Errno(-errno) != .NONE {
        log.errorf("Failed to prepare rumble for gamepad: %s. Errno: %s", device.name, errno)
        return
    }

    play: evdev.input_event
    play.type = EV_FF
    play.code = cast(u16)device_backend.gamepad_rumble_id
    play.value = 1
    written, err := linux.write(cast(linux.Fd)gamepad_fd, mem.byte_slice(&play, size_of(play)))
    if err != .NONE {
        log.errorf("Failed to rumble gamepad: %s. Errno: %s", device.name, err)
    }
}

@(private = "file")
linux_input_device :: proc(input_device: ^InputDevice) -> ^LinuxInputDevice {
    return cast(^LinuxInputDevice)&input_device.backend_data
}

@(private = "file")
udev_device_try_add :: proc(dev: ^udev.udev_device) {
    arena: virtual.Arena
    err := virtual.arena_init_static(&arena, mem.Megabyte * 2)
    log.assert(err == nil, "Failed to init memory arena for input device")
    arena_allocator := virtual.arena_allocator(&arena)

    context.allocator = arena_allocator

    device_features: InputDeviceFeatures
    mouse_devnode: string
    touchpad_devnode: string
    keyboard_devnode: string
    gamepad_devnode: string
    motion_sensor_devnode: string
    mouse_evdev: ^evdev.libevdev
    touchpad_evdev: ^evdev.libevdev
    keyboard_evdev: ^evdev.libevdev
    gamepad_evdev: ^evdev.libevdev
    motion_sensor_evdev: ^evdev.libevdev

    subsystem := udev.device_get_subsystem(dev)
    if subsystem == "" {
        return
    }

    sysname := udev.device_get_sysname(dev)

    dev_name: string
    vendor_id: u16
    product_id: u16

    // TODO: sound devices

    add_feature: if subsystem == "input" {
        /* udev rules reference: http://cgit.freedesktop.org/systemd/systemd/tree/src/udev/udev-builtin-input_id.c */

        // The accelerometer is different than the gyro BUT they both use the same devnode (at least for gamepad!)
        // Accel maps to ABS_X, ABS_Y, ABX_Z (range is -32767-32767 ish for modern controllers and -512-512 for DS3)
        // and the gyro maps to ABS_RX, ABS_RY, ABS_RZ (range is 32 million ish for modern controllers) (DS3 only has a single axis for gyro
        // which isn't handled by the kernel driver)

        if !strings.has_prefix(string(sysname), "event") {
            break add_feature
        }

        if prop_val := udev.device_get_property_value(dev, "ID_INPUT_JOYSTICK"); prop_val == "1" {
            gamepad_devnode = strings.clone_from_cstring(udev.device_get_devnode(dev))
            // open joystick devices as read-write to be able to use rumble
            gamepad_devnode_fd, errno := os.open(gamepad_devnode, os.O_RDWR | os.O_NONBLOCK)
            if gamepad_devnode_fd < 0 {
                log.errorf(
                    "Failed to open gamepad device node '%s' as read-write, falling back to read-only. Errno %s",
                    gamepad_devnode,
                    errno,
                )
                gamepad_devnode_fd, errno = os.open(gamepad_devnode, os.O_RDONLY | os.O_NONBLOCK)
            }

            if (errno == os.ERROR_NONE) {
                dev_name, vendor_id, product_id = evdev_device_info(gamepad_devnode_fd, &gamepad_evdev)
                gamepad_id := cast(u32)vendor_id << 16 | cast(u32)product_id
                if !(gamepad_id in SupportedControllers) {
                    log.warnf("Controller not supported. Vendor ID: 0x%X, Product ID: 0x%X", vendor_id, product_id)
                    os.close(gamepad_devnode_fd)
                    break add_feature
                }
                log.debugf("joystick device: %s", dev_name)
                device_features |= {.GAMEPAD}
            } else {
                log.errorf("Failed to open gamepad device node '%s': errno %d", gamepad_devnode, errno)
            }
        }
        if prop_val := udev.device_get_property_value(dev, "ID_INPUT_ACCELEROMETER"); prop_val == "1" {
            motion_sensor_devnode = strings.clone_from_cstring(udev.device_get_devnode(dev))
            motion_sensor_devnode_fd, errno := os.open(motion_sensor_devnode, os.O_RDONLY | os.O_NONBLOCK)

            if (errno == os.ERROR_NONE) {
                dev_name, vendor_id, product_id = evdev_device_info(motion_sensor_devnode_fd, &motion_sensor_evdev)
                log.debugf("accelerometer device: %s", dev_name)
                device_features |= {.ACCELEROMETER}
            } else {
                log.errorf("failed to open accelerometer device node '%s': errno %d", motion_sensor_devnode, errno)
            }

            // Check for gyroscope properties here as well since the accelerometer device is the same for the gyro
            // (at least for gamepads, idk about other accel devices)
            if evdev_check_gyroscope_properties(motion_sensor_evdev) {
                log.debugf("gyroscope device: %s", dev_name)
                device_features |= {.GYROSCOPE}
            }
        }
        if prop_val := udev.device_get_property_value(dev, "ID_INPUT_MOUSE"); prop_val == "1" {
            if devlinks := udev.device_get_property_value(dev, "DEVLINKS"); devlinks != "" {
                mouse_devnode = strings.clone_from_cstring(udev.device_get_devnode(dev))
                mouse_devnode_fd, errno := os.open(mouse_devnode, os.O_RDONLY, os.O_NONBLOCK)

                if (errno == os.ERROR_NONE) {
                    dev_name, vendor_id, product_id = evdev_device_info(mouse_devnode_fd, &mouse_evdev)
                    log.debugf("mouse device: %s", dev_name)
                    device_features |= {.MOUSE}
                } else {
                    log.errorf("failed to open mouse device node '%s': errno %d", mouse_devnode, errno)
                }
            }
        }
        if prop_val := udev.device_get_property_value(dev, "ID_INPUT_TOUCHPAD"); prop_val == "1" {
            touchpad_devnode = strings.clone_from_cstring(udev.device_get_devnode(dev))
            touchpad_devnode_fd, errno := os.open(touchpad_devnode, os.O_RDONLY, os.O_NONBLOCK)

            if (errno == os.ERROR_NONE) {
                dev_name, vendor_id, product_id = evdev_device_info(touchpad_devnode_fd, &touchpad_evdev)
                log.debugf("touchpad device: %s", dev_name)
                device_features |= {.TOUCHPAD}
            } else {
                log.errorf("failed to open touchpad device node '%s': errno %d", touchpad_devnode, errno)
            }
        }
        // TODO: ignoring DEVLINKS also ignores my bluetooth keyboard
        if prop_val := udev.device_get_property_value(dev, "ID_INPUT_KEYBOARD"); prop_val == "1" {
            if devlinks := udev.device_get_property_value(dev, "DEVLINKS"); devlinks != "" {
                keyboard_devnode = strings.clone_from_cstring(udev.device_get_devnode(dev))
                keyboard_devnode_fd, errno := os.open(keyboard_devnode, os.O_RDONLY, os.O_NONBLOCK)

                if (errno == os.ERROR_NONE) {
                    dev_name, vendor_id, product_id = evdev_device_info(keyboard_devnode_fd, &keyboard_evdev)
                    log.debugf("keyboard device: %s", dev_name)
                    device_features |= {.KEYBOARD}
                } else {
                    log.errorf("failed to open keyboard device node '%s': errno %d", keyboard_devnode, errno)
                }
            }
        }

        if card(device_features) == 0 {
            /* Fall back to old style input classes */
            prop_val := udev.device_get_property_value(dev, "ID_CLASS")
            if prop_val != "" {
                log.warn("Couldn't recognize device, falling back to old style input classes.")
                if prop_val == "joystick" {
                    device_features |= {.GAMEPAD}
                } else if prop_val == "mouse" {
                    device_features |= {.MOUSE}
                } else if prop_val == "kbd" {
                    device_features |= {.KEYBOARD}
                }
            } else {
                // TODO: udev is not running, try guessing the device class
                //log.warn("udev is not running on this machine. We should try guessing the device class")
                //log.warn("guessing device class for device '%s'", devnode)
            }
        }
    } else if subsystem == "leds" {
        // LEDs aren't exposed through evdev for PlayStation controllers, therefore, we enumerate the available LED devices
        // and assign the virtual LED device file to the InputDevice that owns the controller.

        // There are 2 types of LED "devices". an RGB LED device, and a single value (on-off) LED device
        // Technically there are 3 types, RGB, On-Off, and a single light LED with a brightness slider.
        // Not sure if we're gonna expose different devices for these?

        // TODO: leds require us to write directly to the sysfs files because they provide no device file.
        // this also means we'll have to somehow merge a sysfs udev device with the evdev gamepad device which means
        // we'll need to look at the common ancestor in the syspath between the devices and merge accordingly. idk how this will look like in code tho.
        // We kinda already do ancestor/parent-based merging for devices, so we'll just do the same for LEDs, although
        // we'll only accept LEDs as part of a pre-existing device and not their own standalone "input" device.
        // On second thought, maybe we should allow standalone LED input devices, because we don't know the order in which
        // the enumeration happens, we could enumerate over the LED device of a controller first and THEN we get to the
        // actual gamepad device.
        //log.debug(sysname)
        //log.debug(syspath)
        //log.debug(udev.device_get_devnode(dev))
    }

    if card(device_features) == 0 {
        virtual.arena_destroy(&arena)
        return
    }

    if devnode := udev.device_get_devnode(dev); devnode != "" {
        log.debug(devnode)
    }

    if card(device_features) != 0 {
        // Finding the hid ancestor works nicely for merging leds, motion sensors, gamepad, mouse, and touchpad devices.
        // I think it works for basically all devices we care about because at the base all devices we care about
        // are hid devices, this also makes linux behave closer to Windows because on Windows we only look at hid devices.
        parent := udev.device_get_parent_with_subsystem_devtype(dev, "hid", nil)

        id_string := string(udev.device_get_sysname(parent if parent != nil else dev))
        id := fnv_hash(raw_data(id_string), cast(u64)len(id_string), FNV_HASH64_INIT)

        input_device := os_event_queue_input_device_connected(id, dev_name, device_features, vendor_id, product_id)

        if input_device != nil {
            input_device.arena = arena
            input_device_backend := linux_input_device(input_device)
            if .MOUSE in device_features {
                input_device_backend.mouse_devnode = mouse_devnode
                input_device_backend.mouse_evdev = mouse_evdev
                input_device.features |= {.MOUSE}
            }
            if .TOUCHPAD in device_features {
                input_device_backend.touchpad_devnode = touchpad_devnode
                input_device_backend.touchpad_evdev = touchpad_evdev
                input_device.features |= {.TOUCHPAD}

                abs_info := evdev.get_abs_info(touchpad_evdev, ABS_X)
                if abs_info != nil {
                    input_device.touchpad.dims.x = cast(f32)abs_info.maximum
                } else {
                    log.error("Failed to get horizontal touchpad dimension")
                }

                abs_info = evdev.get_abs_info(touchpad_evdev, ABS_Y)
                if abs_info != nil {
                    input_device.touchpad.dims.y = cast(f32)abs_info.maximum
                } else {
                    log.error("Failed to get vertical touchpad dimension")
                }
            }
            if .KEYBOARD in device_features {
                input_device_backend.keyboard_devnode = keyboard_devnode
                input_device_backend.keyboard_evdev = keyboard_evdev
                input_device.features |= {.KEYBOARD}
            }
            if .GAMEPAD in device_features {
                input_device_backend.gamepad_devnode = gamepad_devnode
                input_device_backend.gamepad_evdev = gamepad_evdev
                input_device.features |= {.GAMEPAD}

                gamepad_id: u32 = cast(u32)input_device.vendor_id << 16 | cast(u32)input_device.product_id
                //
                // TODO: have a user configurable GAMEPAD_ACTION -> EVDEV BINDING, just in case the game drivers are different.
                //
                input_device_backend.gamepad_bindings = SupportedControllers[gamepad_id]

                // Check rumble capabilities and set data
                effect: evdev.ff_effect
                // All devices that support FF_RUMBLE also support FF_PERIODIC
                // https://docs.kernel.org/input/ff.html
                // But we're not querying for capabilities here so it fails with FF_PERIODIC
                effect.type = FF_RUMBLE
                effect.id = -1
                gamepad_fd := evdev.get_fd(gamepad_evdev)
                errno := linux.ioctl(cast(linux.Fd)gamepad_fd, EVIOCSFF(), cast(uintptr)&effect)
                if linux.Errno(-errno) == .NONE {
                    input_device.gamepad.supports_rumble = true
                    input_device_backend.gamepad_rumble_id = effect.id
                } else {
                    log.errorf(
                        "Failed to query rumble capabilities for device: %s. Errno: %s",
                        input_device.name,
                        errno,
                    )
                }

                for action in GamepadAction {
                    b := &input_device_backend.gamepad_bindings[action]
                    range := &input_device_backend.gamepad_action_ranges[action]
                    range.min = 0
                    range.max = 1
                    if (b.type == EV_ABS) {
                        abs_info := evdev.get_abs_info(gamepad_evdev, cast(u32)b.code)
                        if abs_info != nil {
                            range.min = abs_info.minimum
                            range.max = abs_info.maximum
                        } else {
                            log.errorf("Failed to get gamepad axis range for key: %d.", b.code)
                        }
                    }
                }
            }
            if .ACCELEROMETER in device_features {
                input_device_backend.motion_sensor_devnode = motion_sensor_devnode
                input_device_backend.motion_sensor_evdev = motion_sensor_evdev
                input_device.features |= {.ACCELEROMETER}
            }
            if .GYROSCOPE in device_features {
                input_device_backend.motion_sensor_devnode = motion_sensor_devnode
                input_device_backend.motion_sensor_evdev = motion_sensor_evdev
                input_device.features |= {.GYROSCOPE}
            }
        }
    }
}

@(private = "file")
udev_device_try_remove :: proc(dev: ^udev.udev_device) {
    parent := udev.device_get_parent_with_subsystem_devtype(dev, "hid", nil)
    id_string := string(udev.device_get_sysname(parent if parent != nil else dev))
    id := fnv_hash(raw_data(id_string), cast(u64)len(id_string), FNV_HASH64_INIT)
    ok := id in zephr_ctx.input_devices_map

    if (ok) {
        device := zephr_ctx.input_devices_map[id]
        device_backend := linux_input_device(&device)
        os_event_queue_input_device_disconnected(id)

        virtual.arena_destroy(&device.arena)
        bit_array.destroy(&device.keyboard.keycode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_released_bitset)
        bit_array.destroy(&device.keyboard.scancode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_released_bitset)
        evdev.free(device_backend.mouse_evdev)
        evdev.free(device_backend.gamepad_evdev)
        evdev.free(device_backend.touchpad_evdev)
        evdev.free(device_backend.keyboard_evdev)
        evdev.free(device_backend.motion_sensor_evdev)
    }
}

@(private = "file")
udev_has_event :: proc() -> bool {
    fd := udev.monitor_get_fd(l_os.udev_monitor)

    fds := []linux.Poll_Fd{linux.Poll_Fd{fd = fd, events = {.IN}}}

    ret, err := linux.poll(fds, 0)

    if ret == -1 {
        log.errorf("Polling udev monitor fd failed with errno: %s", err)
        return false
    }

    return .IN in fds[0].revents
}

@(private = "file")
evdev_device_info :: proc(
    fd: os.Handle,
    evdevice: ^^evdev.libevdev,
    allocator: mem.Allocator = context.allocator,
) -> (
    name: string,
    vendor_id: u16,
    product_id: u16,
) {
    ret := evdev.new_from_fd(fd, evdevice)

    if linux.Errno(-ret) != .NONE {
        log.errorf("Failed to create evdev device for device with fd: %d. Errno: %s", fd, linux.Errno(-ret))
    }

    name = strings.clone_from_cstring(evdev.get_name(evdevice^), allocator)
    vendor_id = evdev.get_id_vendor(evdevice^)
    product_id = evdev.get_id_product(evdevice^)

    if name == "" {
        name = fmt.aprintf("unknown input device 0x%x 0x%x", vendor_id, product_id, allocator = allocator)
    }

    return name, vendor_id, product_id
}

evdev_check_gyroscope_properties :: proc(device: ^evdev.libevdev) -> bool {
    if evdev.has_event_code(device, EV_ABS, ABS_RX) &&
        evdev.has_event_code(device, EV_ABS, ABS_RY) &&
        evdev.has_event_code(device, EV_ABS, ABS_RZ) {
            return true
    }

    return false
}

backend_shutdown :: proc() {
    for _, &device in zephr_ctx.input_devices_map {
        input_device_backend := linux_input_device(&device)
        evdev.free(input_device_backend.mouse_evdev)
        evdev.free(input_device_backend.gamepad_evdev)
        evdev.free(input_device_backend.touchpad_evdev)
        evdev.free(input_device_backend.keyboard_evdev)
        evdev.free(input_device_backend.motion_sensor_evdev)
        virtual.arena_destroy(&device.arena)
        bit_array.destroy(&device.keyboard.keycode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.keycode_has_been_released_bitset)
        bit_array.destroy(&device.keyboard.scancode_is_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_pressed_bitset)
        bit_array.destroy(&device.keyboard.scancode_has_been_released_bitset)
    }

    glx.MakeCurrent(l_os.x11_display, 0, nil)
    glx.DestroyContext(l_os.x11_display, l_os.glx_context)

    x11.DestroyWindow(l_os.x11_display, l_os.x11_window)
    x11.FreeColormap(l_os.x11_display, l_os.x11_colormap)
    x11.CloseDisplay(l_os.x11_display)
}

backend_swapbuffers :: proc() {
    glx.SwapBuffers(l_os.x11_display, l_os.x11_window)
}

backend_get_os_events :: proc() {
    xev: x11.XEvent

    for udev_has_event() {
        if queue.len(zephr_ctx.event_queue) == queue.cap(zephr_ctx.event_queue) {
            return
        }

        dev := udev.monitor_receive_device(l_os.udev_monitor)
        action := udev.device_get_action(dev)

        if (action == "bind" || action == "add") {
            enumerate := udev.enumerate_new(l_os.udevice)

            udev.enumerate_add_match_parent(enumerate, dev)
            udev.enumerate_add_match_subsystem(enumerate, "input")
            udev.enumerate_scan_devices(enumerate)

            first_device := udev.enumerate_get_list_entry(enumerate)

            list_entry: ^udev.udev_list_entry
            for list_entry = first_device; list_entry != nil; list_entry = udev.list_entry_get_next(list_entry) {
                syspath := udev.list_entry_get_name(list_entry)
                child := udev.device_new_from_syspath(l_os.udevice, syspath)

                udev_device_try_add(child)

                udev.device_unref(child)
            }

            udev.enumerate_unref(enumerate)
        } else if (action == "unbind" || action == "remove") {
            udev_device_try_remove(dev)
        }

        udev.device_unref(dev)
    }

    for id, &input_device in zephr_ctx.input_devices_map {
        input_device_backend := linux_input_device(&input_device)

        if .MOUSE in input_device.features {
            has_event := evdev.has_event_pending(input_device_backend.mouse_evdev)
            if has_event < 0 {
                log.errorf(
                    "Failed to check for pending evdev event for mouse device: %s. Errno: %s",
                    input_device.name,
                    linux.Errno(-has_event),
                )
            }

            for has_event >= 1 {
                ev: evdev.input_event
                ret := evdev.next_event(input_device_backend.mouse_evdev, .NORMAL, &ev)

                if ret < 0 {
                    log.errorf(
                        "Failed to get next evdev event for mouse device: %s. Errno: %s",
                        input_device.name,
                        linux.Errno(-ret),
                    )
                    break
                }

                rel_pos := m.vec2{0, 0}
                scroll_rel := m.vec2{0, 0}

                switch ev.type {
                    case EV_KEY:
                        btn: MouseButton = .NONE
                        switch ev.code {
                            case BTN_LEFT:
                                btn = .LEFT
                            case BTN_RIGHT:
                                btn = .RIGHT
                            case BTN_MIDDLE:
                                btn = .MIDDLE
                            case BTN_SIDE:
                                btn = .BACK
                            case BTN_EXTRA:
                                btn = .FORWARD
                        }

                        if btn != .NONE {
                            os_event_queue_raw_mouse_button(id, btn, cast(bool)ev.value)
                        }
                    case EV_REL:
                        switch ev.code {
                            case REL_X:
                                rel_pos.x += cast(f32)ev.value
                            case REL_Y:
                                rel_pos.y += cast(f32)ev.value
                            case REL_HWHEEL:
                                scroll_rel.x += cast(f32)ev.value
                            case REL_WHEEL:
                                scroll_rel.y += cast(f32)ev.value
                        }
                }

                if rel_pos.x != 0 || rel_pos.y != 0 {
                    os_event_queue_raw_mouse_moved(id, rel_pos)
                }

                if scroll_rel.x != 0 || scroll_rel.y != 0 {
                    os_event_queue_raw_mouse_scroll(id, scroll_rel)
                }

                has_event = evdev.has_event_pending(input_device_backend.mouse_evdev)
            }
        }
        if .TOUCHPAD in input_device.features {
            has_event := evdev.has_event_pending(input_device_backend.touchpad_evdev)
            if has_event < 0 {
                log.errorf(
                    "Failed to check for pending evdev event for touchpad device: %s. Errno: %s",
                    input_device.name,
                    linux.Errno(-has_event),
                )
            }

            for has_event >= 1 {
                ev: evdev.input_event
                ret := evdev.next_event(input_device_backend.touchpad_evdev, .NORMAL, &ev)

                if ret < 0 {
                    log.errorf(
                        "Failed to get next evdev event for touchpad device: %s. Errno: %s",
                        input_device.name,
                        linux.Errno(-ret),
                    )
                    break
                }

                pos := input_device.touchpad.pos

                switch ev.type {
                    case EV_KEY:
                        actions: TouchpadAction = .NONE
                        switch ev.code {
                            case BTN_LEFT:
                                actions = .CLICK
                            case BTN_TOUCH:
                                actions = .TOUCH
                        }
                        if actions != .NONE {
                            os_event_queue_raw_touchpad_action(id, actions, cast(bool)ev.value)
                        }
                    case EV_ABS:
                        switch ev.code {
                            case ABS_X:
                                pos.x = cast(f32)ev.value
                            case ABS_Y:
                                pos.y = cast(f32)ev.value
                        }
                }

                if (pos != input_device.touchpad.pos) {
                    os_event_queue_raw_touchpad_moved(id, pos)
                }

                has_event = evdev.has_event_pending(input_device_backend.touchpad_evdev)
            }
        }
        if .KEYBOARD in input_device.features {
            has_event := evdev.has_event_pending(input_device_backend.keyboard_evdev)
            if has_event < 0 {
                log.errorf(
                    "Failed to check for pending evdev event for keyboard device: %s. Errno: %s",
                    input_device.name,
                    linux.Errno(-has_event),
                )
            }

            for has_event >= 1 {
                ev: evdev.input_event
                ret := evdev.next_event(input_device_backend.keyboard_evdev, .NORMAL, &ev)

                if ret < 0 {
                    log.errorf(
                        "Failed to get next evdev event for keyboard device: %s. Errno: %s",
                        input_device.name,
                        linux.Errno(-ret),
                    )
                    break
                }

                switch ev.type {
                    case EV_KEY:
                        // TODO: finish this
                        //{
                        //  // remove the control modifier, as it casues control codes to be returned
                        //  XKeyEvent xkey = {0};
                        //  xkey.type = KeyPress;
                        //  xkey.serial = 0;
                        //  xkey.send_event = false;
                        //  xkey.display = os_backend->connection;
                        //  xkey.window = os_window_backend->x11;
                        //  xkey.root = DefaultRootWindow(os_backend->connection);
                        //  xkey.time = 0;
                        //  xkey.state |= (input_device->keyboard.key_mod_is_pressed_bitset & OS_KEY_MOD_SHIFT) ? ShiftMask : 0;
                        //  xkey.state |= (input_device->keyboard.key_mod_is_pressed_bitset & OS_KEY_MOD_LEFT_ALT) ? Mod1Mask : 0;
                        //  xkey.state |= (input_device->keyboard.key_mod_is_pressed_bitset & OS_KEY_MOD_RIGHT_ALT) ? Mod5Mask : 0;
                        //  xkey.keycode = e->code + 8; // x11 keycode is evdev keycode + 8

                        //  char string[4] = {0};
                        //  X11KeySym keysym = 0;
                        //  uint8_t string_length = Xutf8LookupString(os_window_backend->xic, &xkey, string, sizeof(string), &keysym, NULL);

                        //  // do not send any keys like ctrl, shift, function, arrow, escape, return, backspace.
                        //  // instead, send regular key events.
                        //  if (string_length && !(keysym >= 0xfd00 && keysym <= 0xffff)) {
                        //    os_event_queue_raw_key_input_utf8(input_device_id, string, string_length);
                        //  }
                        //}

                        is_pressed := ev.value >= 1 // 0 == key release, 1 == key press, 2 == key repeat
                        scancode: Scancode
                        if ev.code < cast(u16)len(evdev_scancode_to_zephr_scancode_map) {
                            scancode = evdev_scancode_to_zephr_scancode_map[ev.code]
                        } else {
                            scancode = .NULL
                        }
                        os_event_queue_raw_key_changed(id, is_pressed, scancode)
                }

                has_event = evdev.has_event_pending(input_device_backend.keyboard_evdev)
            }
        }
        if .GAMEPAD in input_device.features {
            has_event := evdev.has_event_pending(input_device_backend.gamepad_evdev)
            if has_event < 0 {
                log.errorf(
                    "Failed to check for pending evdev event for gamepad device: %s. Errno: %s",
                    input_device.name,
                    linux.Errno(-has_event),
                )
            }

            for has_event >= 1 {
                ev: evdev.input_event
                ret := evdev.next_event(input_device_backend.gamepad_evdev, .NORMAL, &ev)

                if ret < 0 {
                    log.errorf(
                        "Failed to get next evdev event for gamepad device: %s. Errno: %s",
                        input_device.name,
                        linux.Errno(-ret),
                    )
                    break
                }

                for action in GamepadAction {
                    b := &input_device_backend.gamepad_bindings[action]
                    if (b.type == ev.type && b.code == ev.code) {
                        range := &input_device_backend.gamepad_action_ranges[action]
                        midpoint := range.min + ((range.max - range.min) / 2)
                        value := clamp(ev.value, range.min, range.max)
                        value -= midpoint
                        if (!b.is_positive) {
                            value = -value
                        }

                        deadzone := evdev.get_abs_flat(input_device_backend.gamepad_evdev, cast(u32)b.code)

                        value_max := cast(f32)(range.max - midpoint)
                        value_unorm := cast(f32)value / value_max
                        deadzone_unorm := cast(f32)deadzone / cast(f32)range.max

                        os_event_queue_raw_gamepad_action(id, action, value_unorm, deadzone_unorm)
                    }
                }

                has_event = evdev.has_event_pending(input_device_backend.gamepad_evdev)
            }
        }
        if .ACCELEROMETER in input_device.features || .GYROSCOPE in input_device.features {
            has_event := evdev.has_event_pending(input_device_backend.motion_sensor_evdev)
            if has_event < 0 {
                log.errorf(
                    "Failed to check for pending evdev event for motion sensor device: %s. Errno: %s",
                    input_device.name,
                    linux.Errno(-has_event),
                )
            }

            for has_event >= 1 {
                ev: evdev.input_event
                ret := evdev.next_event(input_device_backend.motion_sensor_evdev, .NORMAL, &ev)

                if ret < 0 {
                    log.errorf(
                        "Failed to get next evdev event for motion sensor device: %s. Errno: %s",
                        input_device.name,
                        linux.Errno(-ret),
                    )
                    break
                }

                if ev.type == EV_ABS {
                    if .ACCELEROMETER in input_device.features {
                        if ev.code == ABS_X {
                            input_device.accelerometer.x = cast(f32)ev.value
                        } else if ev.code == ABS_Y {
                            input_device.accelerometer.y = cast(f32)ev.value
                        } else if ev.code == ABS_Z {
                            input_device.accelerometer.z = cast(f32)ev.value
                        }

                        os_event_queue_raw_accelerometer_changed(id, input_device.accelerometer)
                    }

                    if .GYROSCOPE in input_device.features {
                        if ev.code == ABS_RX {
                            input_device.gyroscope.x = cast(f32)ev.value
                        } else if ev.code == ABS_RY {
                            input_device.gyroscope.y = cast(f32)ev.value
                        } else if ev.code == ABS_RZ {
                            input_device.gyroscope.z = cast(f32)ev.value
                        }

                        os_event_queue_raw_gyroscope_changed(id, input_device.gyroscope)
                    }
                }

                has_event = evdev.has_event_pending(input_device_backend.motion_sensor_evdev)
            }
        }
    }

    when !RELEASE_BUILD {
        for {
            bytes := make([]byte, 8 * size_of(inotify.Event) + 256, context.temp_allocator)
            bytes_read, err := os.read(l_os.inotify_fd, bytes)

            if bytes_read == -1 && err == os.EAGAIN {
                break
            }

            if err != os.ERROR_NONE {
                log.errorf("Failed to read inotify events. Errno: %d", err)
                break
            }

            i := 0
            for i < bytes_read {
                event := (^inotify.Event)(&bytes[i])
                if event.mask & inotify.IN_MODIFY != 0 {
                    n := 0
                    #no_bounds_check for n < int(event.length) && event.name[n] != 0 {
                        n += 1
                    }
                    #no_bounds_check name := cast(string)mem.slice_ptr(&event.name[0], n)
                    queue.push(&zephr_ctx.changed_shaders_queue, name)
                }

                i += size_of(inotify.Event) + cast(int)event.length
            }
        }
    }

    e: Event
    for (cast(bool)x11.Pending(l_os.x11_display)) {
        if queue.len(zephr_ctx.event_queue) == queue.cap(zephr_ctx.event_queue) {
            return
        }

        x11.NextEvent(l_os.x11_display, &xev)

        if xev.type == .ConfigureNotify {
            xce := xev.xconfigure

            if (xce.width != cast(i32)zephr_ctx.window.size.x || xce.height != cast(i32)zephr_ctx.window.size.y) {
                zephr_ctx.window.size = m.vec2{cast(f32)xce.width, cast(f32)xce.height}
                zephr_ctx.projection = orthographic_projection_2d(
                    0,
                    zephr_ctx.window.size.x,
                    zephr_ctx.window.size.y,
                    0,
                )
                resize_multisample_fb(xce.width, xce.height)

                e.type = .WINDOW_RESIZED
                e.window.width = cast(u32)xce.width
                e.window.height = cast(u32)xce.height

                queue.push(&zephr_ctx.event_queue, e)
            }
        } else if xev.type == .DestroyNotify {
            // window destroy event
            e.type = .WINDOW_CLOSED

            queue.push(&zephr_ctx.event_queue, e)
        } else if xev.type == .ClientMessage {
            // window close event
            if (cast(x11.Atom)xev.xclient.data.l[0] == l_os.window_delete_atom) {
                e.type = .WINDOW_CLOSED
                queue.push(&zephr_ctx.event_queue, e)
            } else if xev.xclient.message_type == l_os.xdnd.xdnd_enter {
                xdnd_enter(xev.xclient.data.l)
            } else if xev.xclient.message_type == l_os.xdnd.xdnd_leave {
                // clear xdnd's transient state
                l_os.xdnd.transient = {}
            } else if xev.xclient.message_type == l_os.xdnd.xdnd_drop {
                if xev.xclient.data.l[0] != cast(int)l_os.xdnd.transient.source_window {
                    break
                }

                x11.ConvertSelection(
                    l_os.x11_display,
                    l_os.xdnd.xdnd_selection,
                    l_os.xdnd.transient.proposed_type,
                    l_os.xdnd.XDND_DATA,
                    l_os.x11_window,
                    cast(x11.Time)xev.xclient.data.l[2],
                )
            }
        } else if xev.type == .KeyPress || xev.type == .KeyRelease {
            // TODO:
            //{
            //  // remove the control modifier, as it casues control codes to be returned
            //  xe.xkey.state &= ~ControlMask;

            //  char string[4] = {0};
            //  X11KeySym keysym = 0;
            //  uint8_t string_length = Xutf8LookupString(os_window_backend->xic, &xe.xkey, string, sizeof(string), &keysym, NULL);

            //  // do not send any keys like ctrl, shift, function, arrow, escape, return, backspace.
            //  // instead, send regular key events.
            //  if (string_length && !(keysym >= 0xfd00 && keysym <= 0xffff)) {
            //    os_event_queue_virt_key_input_utf8(string, string_length);
            //  }
            //}

            // an X11 keycode is basically a scancode.
            // they both represent a physical key.
            // map evdev enumeration to our keycode
            evdev_keycode := xev.xkey.keycode - 8
            scancode: Scancode
            if (evdev_keycode < cast(u32)len(evdev_scancode_to_zephr_scancode_map)) {
                scancode = evdev_scancode_to_zephr_scancode_map[evdev_keycode]
            } else {
                scancode = .NULL
            }
            os_event_queue_virt_key_changed(xev.type == .KeyPress, scancode)
        } else if xev.type == .ButtonPress || xev.type == .ButtonRelease {
            // Only handle press event for mouse buttons 4,5 (y scroll) and 6,7 (h scroll)
            if cast(int)xev.xbutton.button >= 4 && cast(int)xev.xbutton.button <= 7 {
                if xev.type == .ButtonPress {
                    scroll_rel := m.vec2{}
                    #partial switch xev.xbutton.button {
                        case .Button4:
                            scroll_rel.y = 1
                        case .Button5:
                            scroll_rel.y = -1
                        case cast(x11.MouseButton)6:
                            scroll_rel.x = 1
                        case cast(x11.MouseButton)7:
                            scroll_rel.x = -1
                    }

                    os_event_queue_virt_mouse_scroll(scroll_rel)
                }
            } else {
                btn: MouseButton = .NONE
                #partial switch xev.xbutton.button {
                    case .Button1:
                        btn = .LEFT
                    case .Button2:
                        btn = .MIDDLE
                    case .Button3:
                        btn = .RIGHT
                    case cast(x11.MouseButton)8:
                        btn = .BACK
                    case cast(x11.MouseButton)9:
                        btn = .FORWARD
                    case:
                        log.warnf("Unknown mouse button pressed: %d", xev.xbutton.button)
                }
                if btn != .NONE {
                    os_event_queue_virt_mouse_button(btn, xev.type == .ButtonPress)
                }
            }
        } else if xev.type == .MappingNotify {
            // input device mapping changed
            if (xev.xmapping.request == .MappingKeyboard) {
                x11.RefreshKeyboardMapping(&xev.xmapping)
                keyboard_map_update()
            }
        } else if xev.type == .MotionNotify {
            if zephr_ctx.virt_mouse.captured {
                return
            }

            x := xev.xmotion.x
            y := xev.xmotion.y

            pos := m.vec2{clamp(cast(f32)x, 0, zephr_ctx.window.size.x), clamp(cast(f32)y, 0, zephr_ctx.window.size.y)}
            e.type = .VIRT_MOUSE_MOVED
            e.mouse_moved.device_id = 0
            e.mouse_moved.pos = pos
            e.mouse_moved.rel_pos = pos - zephr_ctx.virt_mouse.pos
            zephr_ctx.virt_mouse.rel_pos = pos - zephr_ctx.virt_mouse.pos
            zephr_ctx.virt_mouse.pos = pos

            queue.push(&zephr_ctx.event_queue, e)
        } else if xev.type == .GenericEvent {
            if zephr_ctx.virt_mouse.captured &&
               xev.xcookie.extension == l_os.xinput_opcode &&
               x11.GetEventData(l_os.x11_display, &xev.xcookie) &&
               xev.xcookie.evtype == cast(i32)x11.XIEventType.RawMotion {
                re := cast(^x11.XIRawEvent)xev.xcookie.data
                if re.valuators.mask_len > 0 {
                    values := re.raw_values
                    rel_pos := m.vec2{}
                    if x11.XIMaskIsSet(re.valuators.mask, 0) {
                        zephr_ctx.virt_mouse.virtual_pos.x += cast(f32)values[0]
                        rel_pos.x = cast(f32)values[0]
                    }

                    if x11.XIMaskIsSet(re.valuators.mask, 1) {
                        zephr_ctx.virt_mouse.virtual_pos.y += cast(f32)values[1]
                        rel_pos.y = cast(f32)values[1]
                    }

                    e.type = .VIRT_MOUSE_MOVED
                    e.mouse_moved.device_id = 0
                    e.mouse_moved.pos = zephr_ctx.virt_mouse.virtual_pos
                    e.mouse_moved.rel_pos = rel_pos
                    zephr_ctx.virt_mouse.rel_pos = rel_pos

                    queue.push(&zephr_ctx.event_queue, e)
                }

                x11.FreeEventData(l_os.x11_display, &xev.xcookie)
            }
        } else if xev.type == .SelectionNotify {
            if xev.xselection.property != l_os.xdnd.XDND_DATA {
                break
            }
            if paths := xdnd_receive_data(xev.xselection); paths != nil {
                os_event_queue_drag_and_drop_file(paths)
            }
        }
    }
}

backend_set_cursor :: proc() {
    x11.DefineCursor(l_os.x11_display, l_os.x11_window, zephr_ctx.cursors[zephr_ctx.cursor])
}

backend_init_cursors :: proc() {
    zephr_ctx.cursors[.ARROW] = x11.CreateFontCursor(l_os.x11_display, .XC_left_ptr)
    zephr_ctx.cursors[.IBEAM] = x11.CreateFontCursor(l_os.x11_display, .XC_xterm)
    zephr_ctx.cursors[.CROSSHAIR] = x11.CreateFontCursor(l_os.x11_display, .XC_crosshair)
    zephr_ctx.cursors[.HAND] = x11.CreateFontCursor(l_os.x11_display, .XC_hand1)
    zephr_ctx.cursors[.HRESIZE] = x11.CreateFontCursor(l_os.x11_display, .XC_sb_h_double_arrow)
    zephr_ctx.cursors[.VRESIZE] = x11.CreateFontCursor(l_os.x11_display, .XC_sb_v_double_arrow)

    // non-standard cursors
    zephr_ctx.cursors[.DISABLED] = x11.cursorLibraryLoadCursor(l_os.x11_display, "crossed_circle")
}

@(private = "file")
enable_raw_mouse_input :: proc() {
    context.logger = logger

    ev, err: i32
    if !x11.QueryExtension(l_os.x11_display, "XInputExtension", &l_os.xinput_opcode, &ev, &err) {
        log.error("XInput extension not available")
        return
    }

    major: i32 = 2
    minor: i32 = 0
    if x11.XIQueryVersion(l_os.x11_display, &major, &minor) == .BadRequest {
        log.error("XInput2 not available")
        return
    }

    mask_len :: ((cast(i32)x11.XIEventType.RawMotion >> 3) + 1)
    mask: [mask_len]u8

    em := x11.XIEventMask {
        deviceid = x11.XIAllMasterDevices,
        mask_len = mask_len,
        mask     = raw_data(mask[:]),
    }

    x11.XISetMask(em.mask, .RawMotion)
    // This ONLY works with the root window
    x11.XISelectEvents(l_os.x11_display, x11.DefaultRootWindow(l_os.x11_display), &em, 1)
}

@(private = "file")
disable_raw_mouse_input :: proc() {
    mask: [1]u8

    em := x11.XIEventMask {
        deviceid = x11.XIAllMasterDevices,
        mask_len = 1,
        mask     = raw_data(mask[:]),
    }

    x11.XISelectEvents(l_os.x11_display, x11.DefaultRootWindow(l_os.x11_display), &em, 1)
}

@(private = "file")
get_cursor_pos :: proc(window: x11.Window) -> m.vec2 {
    log.assert(l_os.x11_display != nil, "Attempted to use display before initialization")

    root, child: x11.Window
    root_x, root_y, child_x, child_y: i32
    mask: x11.KeyMask
    x11.QueryPointer(l_os.x11_display, window, &root, &child, &root_x, &root_y, &child_x, &child_y, &mask)
    return {cast(f32)child_x, cast(f32)child_y}
}

backend_grab_cursor :: proc() {
    log.assert(l_os.x11_window != 0, "Attempted to use window before initialization")

    enable_raw_mouse_input()
    cursor_pos := get_cursor_pos(l_os.x11_window)

    zephr_ctx.virt_mouse.pos_before_capture = cursor_pos
    zephr_ctx.virt_mouse.virtual_pos = cursor_pos
    x11.GrabPointer(
        l_os.x11_display,
        l_os.x11_window,
        true,
        {.PointerMotion, .ButtonPress, .ButtonRelease},
        .GrabModeAsync,
        .GrabModeAsync,
        l_os.x11_window,
        x11.None,
        x11.CurrentTime,
    )
    x11.HideCursor(l_os.x11_display, l_os.x11_window)
}

backend_release_cursor :: proc() {
    disable_raw_mouse_input()
    x11.WarpPointer(
        l_os.x11_display,
        x11.None,
        l_os.x11_window,
        0,
        0,
        0,
        0,
        cast(i32)zephr_ctx.virt_mouse.pos_before_capture.x,
        cast(i32)zephr_ctx.virt_mouse.pos_before_capture.y,
    )
    x11.UngrabPointer(l_os.x11_display, x11.CurrentTime)
    x11.ShowCursor(l_os.x11_display, l_os.x11_window)
}

@(private = "file")
xdnd_enter :: proc(client_data_l: [5]int) {
    if client_data_l[1] & 0x1 == 1 {
        // More than three data types
        l_os.xdnd.transient.exchange_started = true
        l_os.xdnd.transient.source_window = cast(x11.Window)client_data_l[0]
        actual_type: x11.Atom
        actual_format: i32
        num_of_items, bytes_after_return: uint
        data: rawptr
        res := x11.GetWindowProperty(
            l_os.x11_display,
            l_os.xdnd.transient.source_window,
            l_os.xdnd.xdnd_type_list,
            0,
            1024,
            false,
            x11.AnyPropertyType,
            &actual_type,
            &actual_format,
            &num_of_items,
            &bytes_after_return,
            &data,
        )
        if res == cast(i32)x11.Status.Success && actual_type != x11.None {
            source_types := cast([^]x11.Atom)data
            out: for i in 0 ..< num_of_items {
                for supported_type in l_os.xdnd.supported_types {
                    if supported_type == source_types[i] {
                        l_os.xdnd.transient.proposed_type = supported_type
                        break out
                    }
                }
            }
            x11.Free(data)
        }
    } else {
        l_os.xdnd.transient.exchange_started = true
        l_os.xdnd.transient.source_window = cast(x11.Window)client_data_l[0]
        // Only three data types
        outer: for i in 2 ..< 5 {
            for supported_type in l_os.xdnd.supported_types {
                if supported_type == cast(x11.Atom)client_data_l[i] {
                    l_os.xdnd.transient.proposed_type = supported_type
                    break outer
                }
            }
        }
    }
}

xdnd_receive_data :: proc(xselection: x11.XSelectionEvent) -> []string {
    actual_type: x11.Atom = x11.None
    actual_format: i32
    num_of_items, bytes_after_return: uint
    data: rawptr

    res := x11.GetWindowProperty(
        l_os.x11_display,
        l_os.x11_window,
        l_os.xdnd.XDND_DATA,
        0,
        1024,
        false,
        x11.AnyPropertyType,
        &actual_type,
        &actual_format,
        &num_of_items,
        &bytes_after_return,
        &data,
    )

    if res == cast(i32)x11.Status.Success {
        defer x11.Free(data)
        defer x11.DeleteProperty(l_os.x11_display, l_os.x11_window, l_os.xdnd.XDND_DATA)

        bytes := cast([^]u8)data

        // if CR is present, we replace it with a null terminator
        for i in 0 ..< num_of_items {
            if bytes[i] == 0xD {
                bytes[i] = 0
            }
        }

        str_from_ptr := strings.string_from_ptr(bytes, cast(int)num_of_items - 2)
        unsplit_str := strings.clone(str_from_ptr)
        defer delete(unsplit_str)
        // we trim unsplit_str here so we don't get an empty string in the slice
        strs := strings.split_lines(unsplit_str, context.temp_allocator)

        for &str in strs {
            str = strings.trim_prefix(strings.trim_space(str), "file://")
            // get rid of the null terminator we added in place of the carriage return
            str = strings.trim_suffix(str, "\x00")
            // we decode the string because it may contain unicode or uri encoded characters
            decoded_str, _ := net.percent_decode(str, context.temp_allocator)
            str = strings.clone(decoded_str, context.temp_allocator)
        }

        return strs
    } else {
        log.error("Failed to receive Drag n Drop data")

        return nil
    }
}

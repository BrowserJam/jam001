// +build linux
//+private
package zephr

import "3rdparty/evdev"

/*
* Event types
*/

EV_SYN :: 0x00
EV_KEY :: 0x01
EV_REL :: 0x02
EV_ABS :: 0x03
EV_MSC :: 0x04
EV_SW :: 0x05
EV_LED :: 0x11
EV_SND :: 0x12
EV_REP :: 0x14
EV_FF :: 0x15
EV_PWR :: 0x16
EV_FF_STATUS :: 0x17
EV_MAX :: 0x1f
EV_CNT :: (EV_MAX + 1)

/*
 * Synchronization events.
 */

SYN_REPORT :: 0
SYN_DROPPED :: 3

/*
* Absolute axes
*/

ABS_X :: 0x00
ABS_Y :: 0x01
ABS_Z :: 0x02
ABS_RX :: 0x03
ABS_RY :: 0x04
ABS_RZ :: 0x05
ABS_GAS :: 0x09
ABS_BRAKE :: 0x0a
ABS_HAT0X :: 0x10
ABS_HAT0Y :: 0x11
ABS_HAT1X :: 0x12
ABS_HAT1Y :: 0x13
ABS_HAT2X :: 0x14
ABS_HAT2Y :: 0x15
ABS_HAT3X :: 0x16
ABS_HAT3Y :: 0x17

/*
 * LEDs
 */

LED_NUML     :: 0x00
LED_CAPSL    :: 0x01
LED_SCROLLL  :: 0x02
LED_COMPOSE  :: 0x03
LED_KANA     :: 0x04
LED_SLEEP    :: 0x05
LED_SUSPEND  :: 0x06
LED_MUTE     :: 0x07
LED_MISC     :: 0x08
LED_MAIL     :: 0x09
LED_CHARGING :: 0x0a
LED_MAX      :: 0x0f
LED_CNT      :: (LED_MAX+1)

/* Buttons */

BTN_SOUTH :: 0x130
BTN_EAST :: 0x131
BTN_WEST :: 0x134
BTN_NORTH :: 0x133
BTN_TL :: 0x136
BTN_TR :: 0x137
BTN_TL2 :: 0x138
BTN_TR2 :: 0x139
BTN_SELECT :: 0x13a
BTN_START :: 0x13b
BTN_THUMBL :: 0x13d
BTN_THUMBR :: 0x13e
BTN_MODE :: 0x13c

BTN_DPAD_UP :: 0x220
BTN_DPAD_DOWN :: 0x221
BTN_DPAD_LEFT :: 0x222
BTN_DPAD_RIGHT :: 0x223

BTN_LEFT :: 0x110
BTN_RIGHT :: 0x111
BTN_MIDDLE :: 0x112
BTN_SIDE :: 0x113
BTN_EXTRA :: 0x114
BTN_TOUCH :: 0x14a

/* Relative axes */

REL_X :: 0x00
REL_Y :: 0x01
REL_HWHEEL :: 0x06
REL_WHEEL :: 0x08

/*
 * Force feedback effect types
 */

FF_RUMBLE :: 0x50
FF_PERIODIC :: 0x51
FF_CONSTANT :: 0x52
FF_SPRING :: 0x53
FF_FRICTION :: 0x54
FF_DAMPER :: 0x55
FF_INERTIA :: 0x56
FF_RAMP :: 0x57

FF_EFFECT_MIN :: FF_RUMBLE
FF_EFFECT_MAX :: FF_RAMP

_IOC_WRITE: u32 : 1

_IOC_NRBITS :: 8
_IOC_TYPEBITS :: 8
_IOC_SIZEBITS :: 14

_IOC_NRSHIFT :: 0
_IOC_TYPESHIFT :: (_IOC_NRSHIFT + _IOC_NRBITS) // 0 + 8 = 8
_IOC_SIZESHIFT :: (_IOC_TYPESHIFT + _IOC_TYPEBITS) // (0 + 8) + 8 = 16
_IOC_DIRSHIFT :: (_IOC_SIZESHIFT + _IOC_SIZEBITS) // 16 + 14 = 30


_IOC :: proc(dir: u32, type: rune, nr: u32, size: u32) -> u32 {
    return(
        ((dir) << _IOC_DIRSHIFT) |
        ((cast(u32)type) << _IOC_TYPESHIFT) |
        ((nr) << _IOC_NRSHIFT) |
        ((size) << _IOC_SIZESHIFT) \
    )
}

_IOW :: proc(type: rune, nr: u32, size: u32) -> u32 {
    return _IOC(_IOC_WRITE, type, nr, size)
}

EVIOCSFF :: proc() -> u32 {
    return _IOW('E', 0x80, size_of(evdev.ff_effect)) /* send a force effect to a force feedback device */
}

//+build linux
package evdev

import "core:sys/linux"

@(private)
Err :: i32

libevdev_read_flag :: enum {
    SYNC       = 1, /**< Process data in sync mode */
    NORMAL     = 2, /**< Process data in normal mode */
    FORCE_SYNC = 4, /**< Pretend the next event is a SYN_DROPPED and
	require the caller to sync */
    BLOCKING   = 8, /**< The fd is not in O_NONBLOCK and a read may block */
}

@(private)
libevdev_read_status :: enum {
    /**
	 * libevdev_next_event() has finished without an error
	 * and an event is available for processing.
	 *
	 * @see libevdev_next_event
	 */
    SUCCESS = 0,
    /**
	 * Depending on the libevdev_next_event() read flag:
	 * * libevdev received a SYN_DROPPED from the device, and the caller should
	 * now resync the device, or,
	 * * an event has been read in sync mode.
	 *
	 * @see libevdev_next_event
	 */
    SYNC    = 1,
}

libevdev :: struct {}

#assert(size_of(input_event) == 24)

input_event :: struct {
    timeval: linux.Time_Val,
    type:    u16,
    code:    u16,
    value:   i32,
}

/**
 * struct input_absinfo - used by EVIOCGABS/EVIOCSABS ioctls
 * @value: latest reported value for the axis.
 * @minimum: specifies minimum value for the axis.
 * @maximum: specifies maximum value for the axis.
 * @fuzz: specifies fuzz value that is used to filter noise from
 *	the event stream.
 * @flat: values that are within this value will be discarded by
 *	joydev interface and reported as 0 instead.
 * @resolution: specifies resolution for the values reported for
 *	the axis.
 *
 * Note that input core does not clamp reported values to the
 * [minimum, maximum] limits, such task is left to userspace.
 *
 * The default resolution for main axes (ABS_X, ABS_Y, ABS_Z)
 * is reported in units per millimeter (units/mm), resolution
 * for rotational axes (ABS_RX, ABS_RY, ABS_RZ) is reported
 * in units per radian.
 * When INPUT_PROP_ACCELEROMETER is set the resolution changes.
 * The main axes (ABS_X, ABS_Y, ABS_Z) are then reported in
 * units per g (units/g) and in units per degree per second
 * (units/deg/s) for rotational axes (ABS_RX, ABS_RY, ABS_RZ).
 */
input_absinfo :: struct {
    value:      i32,
    minimum:    i32,
    maximum:    i32,
    fuzz:       i32,
    flat:       i32,
    resolution: i32,
}

/**
 * struct ff_effect - defines force feedback effect
 * @type: type of the effect (FF_CONSTANT, FF_PERIODIC, FF_RAMP, FF_SPRING,
 *	FF_FRICTION, FF_DAMPER, FF_RUMBLE, FF_INERTIA, or FF_CUSTOM)
 * @id: an unique id assigned to an effect
 * @direction: direction of the effect
 * @trigger: trigger conditions (struct ff_trigger)
 * @replay: scheduling of the effect (struct ff_replay)
 * @u: effect-specific structure (one of ff_constant_effect, ff_ramp_effect,
 *	ff_periodic_effect, ff_condition_effect, ff_rumble_effect) further
 *	defining effect parameters
 *
 * This structure is sent through ioctl from the application to the driver.
 * To create a new effect application should set its @id to -1; the kernel
 * will return assigned @id which can later be used to update or delete
 * this effect.
 *
 * Direction of the effect is encoded as follows:
 *	0 deg -> 0x0000 (down)
 *	90 deg -> 0x4000 (left)
 *	180 deg -> 0x8000 (up)
 *	270 deg -> 0xC000 (right)
 */
ff_effect :: struct {
    type:      u16,
    id:        i16,
    direction: u16,
    trigger:   ff_trigger,
    replay:    ff_replay,
    u:         struct #raw_union {
        constant:  ff_constant_effect,
        ramp:      ff_ramp_effect,
        periodic:  ff_periodic_effect,
        condition: [2]ff_condition_effect, /* One for each axis */
        rumble:    ff_rumble_effect,
    },
}


/**
 * struct ff_trigger - defines what triggers the force-feedback effect
 * @button: number of the button triggering the effect
 * @interval: controls how soon the effect can be re-triggered
 */
ff_trigger :: struct {
    button:   u16,
    interval: u16,
}


/**
 * struct ff_replay - defines scheduling of the force-feedback effect
 * @length: duration of the effect
 * @delay: delay before effect should start playing
 */
ff_replay :: struct {
    length: u16,
    delay:  u16,
}

/**
 * struct ff_constant_effect - defines parameters of a constant force-feedback effect
 * @level: strength of the effect; may be negative
 * @envelope: envelope data
 */
ff_constant_effect :: struct {
    level:    i16,
    envelope: ff_envelope,
}

/**
 * struct ff_ramp_effect - defines parameters of a ramp force-feedback effect
 * @start_level: beginning strength of the effect; may be negative
 * @end_level: final strength of the effect; may be negative
 * @envelope: envelope data
 */
ff_ramp_effect :: struct {
    start_level: i16,
    end_level:   i16,
    envelope:    ff_envelope,
}

/**
 * struct ff_condition_effect - defines a spring or friction force-feedback effect
 * @right_saturation: maximum level when joystick moved all way to the right
 * @left_saturation: same for the left side
 * @right_coeff: controls how fast the force grows when the joystick moves
 *	to the right
 * @left_coeff: same for the left side
 * @deadband: size of the dead zone, where no force is produced
 * @center: position of the dead zone
 */
ff_condition_effect :: struct {
    right_saturation: u16,
    left_saturation:  u16,
    right_coeff:      i16,
    left_coeff:       i16,
    deadband:         u16,
    center:           i16,
}

/**
 * struct ff_periodic_effect - defines parameters of a periodic force-feedback effect
 * @waveform: kind of the effect (wave)
 * @period: period of the wave (ms)
 * @magnitude: peak value
 * @offset: mean value of the wave (roughly)
 * @phase: 'horizontal' shift
 * @envelope: envelope data
 * @custom_len: number of samples (FF_CUSTOM only)
 * @custom_data: buffer of samples (FF_CUSTOM only)
 *
 * Known waveforms - FF_SQUARE, FF_TRIANGLE, FF_SINE, FF_SAW_UP,
 * FF_SAW_DOWN, FF_CUSTOM. The exact syntax FF_CUSTOM is undefined
 * for the time being as no driver supports it yet.
 *
 * Note: the data pointed by custom_data is copied by the driver.
 * You can therefore dispose of the memory after the upload/update.
 */
ff_periodic_effect :: struct {
    waveform:    u16,
    period:      u16,
    magnitude:   i16,
    offset:      i16,
    phase:       u16,
    envelope:    ff_envelope,
    custom_len:  u32,
    custom_data: ^i16,
}

/**
 * struct ff_rumble_effect - defines parameters of a periodic force-feedback effect
 * @strong_magnitude: magnitude of the heavy motor
 * @weak_magnitude: magnitude of the light one
 *
 * Some rumble pads have two motors of different weight. Strong_magnitude
 * represents the magnitude of the vibration generated by the heavy one.
 */
ff_rumble_effect :: struct {
    strong_magnitude: u16,
    weak_magnitude:   u16,
}


/**
 * struct ff_envelope - generic force-feedback effect envelope
 * @attack_length: duration of the attack (ms)
 * @attack_level: level at the beginning of the attack
 * @fade_length: duration of fade (ms)
 * @fade_level: level at the end of fade
 *
 * The @attack_level and @fade_level are absolute values; when applying
 * envelope force-feedback core will convert to positive/negative
 * value based on polarity of the default level of the effect.
 * Valid range for the attack and fade levels is 0x0000 - 0x7fff
 */
ff_envelope :: struct {
    attack_length: u16,
    attack_level:  u16,
    fade_length:   u16,
    fade_level:    u16,
}

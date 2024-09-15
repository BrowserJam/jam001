package zephr

import "base:intrinsics"
import "core:math"
import m "core:math/linalg/glsl"

Color :: struct {
    r, g, b, a: u8,
}

orthographic_projection_2d :: proc(left, right, bottom, top: f32) -> m.mat4 {
    result := m.identity(m.mat4)

    result[0][0] = 2 / (right - left)
    result[3][0] = -(right + left) / (right - left)
    result[1][1] = 2 / (top - bottom)
    result[3][1] = -(top + bottom) / (top - bottom)
    result[2][2] = -1
    result[3][3] = 1

    return result
}

mult_color :: proc(color: Color, scalar: f32) -> Color {
    color := color

    color.r = clamp(cast(u8)(cast(f32)color.r * scalar), 0, 255)
    color.g = clamp(cast(u8)(cast(f32)color.g * scalar), 0, 255)
    color.b = clamp(cast(u8)(cast(f32)color.b * scalar), 0, 255)

    return color
}

hsv2rgb :: proc(h: f32, s: f32, v: f32) -> Color {
    c := v * s
    x := (c * (1 - abs(math.mod(h / 60.0, 2) - 1)))
    m := v - c

    r, g, b: f32

    if (h >= 0 && h < 60) {
        r = c
        g = x
        b = 0
    } else if (h >= 60 && h < 120) {
        r = x
        g = c
        b = 0
    } else if (h >= 120 && h < 180) {
        r = 0
        g = c
        b = x
    } else if (h >= 180 && h < 240) {
        r = 0
        g = x
        b = c
    } else if (h >= 240 && h < 300) {
        r = x
        g = 0
        b = c
    } else {
        r = c
        g = 0
        b = x
    }

    return (Color){(u8)((r + m) * 255), (u8)((g + m) * 255), (u8)((b + m) * 255), 255}
}

determine_color_contrast :: proc(bg: Color) -> Color {
    white_contrast := get_contrast(bg, COLOR_WHITE)
    black_contrast := get_contrast(bg, COLOR_BLACK)

    return white_contrast > black_contrast ? COLOR_WHITE : COLOR_BLACK
}

@(private)
get_srgb :: proc(component: f32) -> f32 {
    return (component / 255 <= 0.03928) ? component / 255 / 12.92 : math.pow((component / 255 + 0.055) / 1.055, 2.4)
}

get_luminance :: proc(color: Color) -> f32 {
    return(
        ((0.2126 * get_srgb(cast(f32)color.r)) +
            (0.7152 * get_srgb(cast(f32)color.g)) +
            (0.0722 * get_srgb(cast(f32)color.b))) /
        255 \
    )
}

@(private)
get_contrast :: proc(fg: Color, bg: Color) -> f32 {
    l1 := get_luminance(fg)
    l2 := get_luminance(bg)

    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

//
//
// Easing functions
//
//

ease_out_circ :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.sqrt(1 - math.pow(t - 1, 2))
}

ease_out_cubic :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return 1 - math.pow(1 - t, 3)
}

ease_out_elastic :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    c4: T = (2 * math.PI) / 3

    if t == 0 {
        return 0
    } else if t == 1 {
        return 1
    } else {
        return math.pow(2, -10 * t) * math.sin_f32((t * 10 - 0.75) * c4) + 1
    }
}

ease_in_quint :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.pow(t, 5)
}

ease_out_bounce :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    t := t
    n1: T = 7.5625
    d1: T = 2.75
    if (t < 1 / d1) {
        return n1 * t * t
    } else if (t < 2 / d1) {
        t -= 1.5 / d1
        return n1 * (t) * t + 0.75
    } else if (t < 2.5 / d1) {
        t -= 2.25 / d1
        return n1 * (t) * t + 0.9375
    } else {
        t -= 2.625 / d1
        return n1 * (t) * t + 0.984375
    }
}

ease_in_out_quint :: proc(t: f32) -> f32 {
    return t < 0.5 ? 16 * t * t * t * t * t : 1 - math.pow(-2 * t + 2, 5) / 2
}

ease_in_out_back :: proc(t: f64) -> f64 {
    c1 := 1.70158
    c2 := c1 * 1.525

    if t < 0.5 {
        return (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
    } else {
        return (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    }
}

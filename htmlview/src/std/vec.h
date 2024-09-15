#pragma once

#include "std/Types.h"

#include "math.h"

#ifdef max
#undef max
#endif

#ifdef min
#undef min
#endif

#define max(lhs, rhs) ((lhs) > (rhs) ? (lhs) : (rhs))
#define min(lhs, rhs) ((lhs) < (rhs) ? (lhs) : (rhs))

#define f32_clamp(x, l, h) min(max(l, (x)), h)
#define f32_saturate(x) f32_clamp(x, 0.0f, 1.0f)

typedef union v2 {
  struct {
    f32 x, y;
  };
  f32 c[2];

#if __cplusplus
  v2() : x(0), y(0) {}
  explicit v2(f32 v) : x(v), y(v) {}
  v2(f32 x, f32 y) : x(x), y(y) {}
#endif
} v2;

typedef union v3 {
  struct {
    f32 x, y, z;
  };
  f32 c[3];

#if __cplusplus
  void operator+=(union v3 other) {
    x += other.x;
    y += other.y;
    z += other.z;
  }
#endif
} v3;

typedef union {
  struct {
    f32 x, y, z, w;
  };
  f32 c[4];
} v4;

typedef struct mat4x4 {
  v4 c0;
  v4 c1;
  v4 c2;
  v4 c3;
} mat4x4;

#define PI \
  (3.1415926535897932384626433832795028841971693993751058209749445923078164062)
#define TWO_PI_RCP (1.0 / (2.0 * PI))
#define PI_RCP (1.0 / PI)

#if __cplusplus
extern "C" {
#endif

v2 v2_init(f32 x, f32 y);
v2 v2_min(v2 a, v2 b);
v2 v2_max(v2 a, v2 b);
f32 v2_cross(v2 a, v2 b);
v2 v2_sub(v2 a, v2 b);

v3 v3_zero();
v3 v3_splat(f32 v);
v3 v3_init(f32 x, f32 y, f32 z);
f32 v3_dot(v3 l, v3 r);
// Saturating dot product
f32 v3_dot_sat(v3 l, v3 r);
f32 v3_length(v3 in);
v3 v3_normalize(v3 in);
v3 v3_cross(v3 a, v3 b);
v3 v3_add(v3 a, v3 b);
v3 v3_neg(v3 a);
v3 v3_sub(v3 a, v3 b);
v3 v3_scale(f32 s, v3 x);
v3 v3_mad(v3 a, f32 b, v3 c);
v3 v3_mul(v3 a, v3 b);
v3 v3_div(v3 a, f32 b);
v3 v3_msub(f32 a, v3 b, v3 c);
v3 v3_applyQuat(v3 x, v4 q);
v3 v3_transform(v3 x, const mat4x4 *mat);
v3 v3_transform_dir(v3 x, const mat4x4 *mat);
v3 v3_transform_dir_0001(v3 x, const mat4x4 *mat);

v4 v4_init(f32 x, f32 y, f32 z, f32 w);
f32 v4_dot(v4 a, v4 b);
v4 v4_scale(f32 s, v4 x);
v4 v4_add(v4 a, v4 x);

mat4x4 mat4x4_id();
mat4x4 mat4x4_scale(f32 s);
mat4x4 mat4x4_mul(mat4x4 a, mat4x4 b);
mat4x4 mat4x4_compose(v3 translation, v4 orientation, v3 scale);
mat4x4 mat4x4_compose_view(v3 translation, v4 orientation);
mat4x4 mat4x4_proj(f32 A, f32 B, f32 C, f32 D, f32 E);
mat4x4 mat4x4_proj7(f32 A, f32 B, f32 C, f32 D, f32 E, f32 F, f32 G);
mat4x4 mat4x4_perspective(f32 width, f32 height, f32 near, f32 far);
mat4x4 mat4x4_perspective_fov(f32 width,
                              f32 height,
                              f32 near,
                              f32 far,
                              f32 fov);
mat4x4 mat4x4_transpose(mat4x4 x);
mat4x4 mat4x4_rotate(v4 orientation);

v4 quat_mul(v4 a, v4 b);
v4 quat_fromAngleAxis(v3 axis, f32 angle);
v4 quat_conjugate(v4 a);

f32 mat2_det(f32 c0_x, f32 c0_y, f32 c1_x, f32 c1_y);
mat4x4 mat3_cofactor(mat4x4 A);

#if __cplusplus
}
#endif

#if __cplusplus
inline v3 operator+(v3 a, v3 b) {
  return v3_add(a, b);
}

inline v3 operator-(v3 a, v3 b) {
  return v3_sub(a, b);
}

inline v3 operator*(v3 a, v3 b) {
  return v3_mul(a, b);
}

inline v3 operator*(f32 a, v3 b) {
  return v3_scale(a, b);
}

inline v3 operator/(v3 a, f32 b) {
  return v3_div(a, b);
}

inline v3 operator-(v3 a) {
  return v3_neg(a);
}

inline v2 xy(v3 a) {
  return {a.x, a.y};
}

inline v2 yx(v2 a) {
  return {a.y, a.x};
}

inline v2 operator-(v2 a, v2 b) {
  return v2_sub(a, b);
}

inline v2 operator+(v2 a, v2 b) {
  return {a.x + b.x, a.y + b.y};
}

inline v2 operator*(f32 a, v2 b) {
  return {a * b.x, a * b.y};
}

inline v2 operator*(v2 a, v2 b) {
  return {a.x * b.x, a.y * b.y};
}

inline v2 operator/(v2 a, f32 b) {
  return {a.x / b, a.y / b};
}

inline v2 abs(v2 v) {
  return {fabsf(v.x), fabsf(v.y)};
}

inline v3 xyz(v4 a) {
  return v3_init(a.x, a.y, a.z);
}
inline v3 wzy(v4 a) {
  return v3_init(a.w, a.z, a.y);
}
inline v3 yzw(v4 a) {
  return v3_init(a.y, a.z, a.w);
}

inline v4 operator*(f32 a, v4 b) {
  return v4_scale(a, b);
}

inline v4 operator+(v4 a, v4 b) {
  return v4_add(a, b);
}

inline f32 dot(v3 a, v3 b) {
  return v3_dot(a, b);
}

#endif

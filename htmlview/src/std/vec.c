#include "std/vec.h"

#include <math.h>

v3 v3_zero() {
  return v3_splat(0.0);
}

v3 v3_splat(f32 v) {
  return (v3){v, v, v};
}

v3 v3_init(f32 x, f32 y, f32 z) {
  return (v3){x, y, z};
}

v4 v4_init(f32 x, f32 y, f32 z, f32 w) {
  return (v4){x, y, z, w};
}

f32 v3_dot(v3 l, v3 r) {
  return l.x * r.x + l.y * r.y + l.z * r.z;
}

// Saturating dot product
f32 v3_dot_sat(v3 l, v3 r) {
  return f32_saturate(l.x * r.x + l.y * r.y + l.z * r.z);
}

f32 v3_length(v3 in) {
  return sqrtf(v3_dot(in, in));
}

v3 v3_normalize(v3 in) {
  v3 ret;
  f32 l = v3_length(in);
  ret.x = in.x / l;
  ret.y = in.y / l;
  ret.z = in.z / l;
  return ret;
}

v3 v3_cross(v3 a, v3 b) {
  v3 ret;
  ret.x = a.y * b.z - a.z * b.y;
  ret.y = a.z * b.x - a.x * b.z;
  ret.z = a.x * b.y - a.y * b.x;
  return ret;
}

v3 v3_add(v3 a, v3 b) {
  v3 ret;
  ret.x = a.x + b.x;
  ret.y = a.y + b.y;
  ret.z = a.z + b.z;
  return ret;
}

v3 v3_neg(v3 a) {
  v3 ret;
  ret.x = -a.x;
  ret.y = -a.y;
  ret.z = -a.z;
  return ret;
}

v3 v3_sub(v3 a, v3 b) {
  return v3_add(a, v3_neg(b));
}

v3 v3_scale(f32 s, v3 x) {
  v3 ret;
  ret.x = s * x.x;
  ret.y = s * x.y;
  ret.z = s * x.z;
  return ret;
}

v3 v3_div(v3 a, f32 b) {
  v3 ret;
  ret.x = a.x / b;
  ret.y = a.y / b;
  ret.z = a.z / b;
  return ret;
}

v3 v3_mad(v3 a, f32 b, v3 c) {
  v3 ret;
  ret.x = a.x + b * c.x;
  ret.y = a.y + b * c.y;
  ret.z = a.z + b * c.z;
  return ret;
}

v3 v3_mul(v3 a, v3 b) {
  v3 ret;
  ret.x = a.x * b.x;
  ret.y = a.y * b.y;
  ret.z = a.z * b.z;
  return ret;
}

v3 v3_msub(f32 a, v3 b, v3 c) {
  v3 ret;
  ret.x = a * b.x - c.x;
  ret.y = a * b.y - c.y;
  ret.z = a * b.z - c.z;
  return ret;
}

mat4x4 mat4x4_rotate(v4 orientation) {
  mat4x4 ret;

  f32 x = orientation.x, y = orientation.y, z = orientation.z,
      w = orientation.w;
  f32 x2 = x + x, y2 = y + y, z2 = z + z;
  f32 xx = x * x2, xy = x * y2, xz = x * z2;
  f32 yy = y * y2, yz = y * z2, zz = z * z2;
  f32 wx = w * x2, wy = w * y2, wz = w * z2;

  ret.c0 = (v4){(1.0f - (yy + zz)), (xy + wz), (xz - wy), 0.0f};
  ret.c1 = (v4){(xy - wz), (1 - (xx + zz)), (yz + wx), 0.0f};
  ret.c2 = (v4){(xz + wy), (yz - wx), (1 - (xx + yy)), 0.0f};
  ret.c3 = (v4){0, 0, 0, 1};

  return ret;
}

mat4x4 mat4x4_compose(v3 translation, v4 orientation, v3 scale) {
  mat4x4 ret;

  f32 x = orientation.x, y = orientation.y, z = orientation.z,
      w = orientation.w;
  f32 x2 = x + x, y2 = y + y, z2 = z + z;
  f32 xx = x * x2, xy = x * y2, xz = x * z2;
  f32 yy = y * y2, yz = y * z2, zz = z * z2;
  f32 wx = w * x2, wy = w * y2, wz = w * z2;

  f32 sx = scale.x, sy = scale.y, sz = scale.z;

  ret.c0 = (v4){(1.0f - (yy + zz)) * sx, (xy + wz) * sx, (xz - wy) * sx, 0.0f};
  ret.c1 = (v4){(xy - wz) * sy, (1 - (xx + zz)) * sy, (yz + wx) * sy, 0.0f};
  ret.c2 = (v4){(xz + wy) * sz, (yz - wx) * sz, (1 - (xx + yy)) * sz, 0.0f};
  ret.c3 = (v4){translation.x, translation.y, translation.z, 1.0f};

  return ret;
}

f32 v4_dot(v4 a, v4 b) {
  return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

mat4x4 mat4x4_mul(mat4x4 a, mat4x4 b) {
  mat4x4 ret;
  a = mat4x4_transpose(a);

  ret.c0 = v4_init(v4_dot(a.c0, b.c0), v4_dot(a.c1, b.c0), v4_dot(a.c2, b.c0),
                   v4_dot(a.c3, b.c0));
  ret.c1 = v4_init(v4_dot(a.c0, b.c1), v4_dot(a.c1, b.c1), v4_dot(a.c2, b.c1),
                   v4_dot(a.c3, b.c1));
  ret.c2 = v4_init(v4_dot(a.c0, b.c2), v4_dot(a.c1, b.c2), v4_dot(a.c2, b.c2),
                   v4_dot(a.c3, b.c2));
  ret.c3 = v4_init(v4_dot(a.c0, b.c3), v4_dot(a.c1, b.c3), v4_dot(a.c2, b.c3),
                   v4_dot(a.c3, b.c3));

  return ret;
}

mat4x4 mat4x4_compose_view(v3 translation, v4 orientation) {
  mat4x4 R, T;

  f32 x = -orientation.x, y = -orientation.y, z = -orientation.z,
      w = orientation.w;
  f32 x2 = x + x, y2 = y + y, z2 = z + z;
  f32 xx = x * x2, xy = x * y2, xz = x * z2;
  f32 yy = y * y2, yz = y * z2, zz = z * z2;
  f32 wx = w * x2, wy = w * y2, wz = w * z2;

  R.c0 = (v4){(1.0f - (yy + zz)), (xy + wz), (xz - wy), 0.0f};
  R.c1 = (v4){(xy - wz), (1 - (xx + zz)), (yz + wx), 0.0f};
  R.c2 = (v4){(xz + wy), (yz - wx), (1 - (xx + yy)), 0.0f};
  R.c3 = (v4){0, 0, 0, 1};

  T = mat4x4_id();
  T.c3 = (v4){-translation.x, -translation.y, -translation.z, 1.0f};

  return mat4x4_mul(R, T);
}

mat4x4 mat4x4_id() {
  mat4x4 ret;
  ret.c0 = v4_init(1, 0, 0, 0);
  ret.c1 = v4_init(0, 1, 0, 0);
  ret.c2 = v4_init(0, 0, 1, 0);
  ret.c3 = v4_init(0, 0, 0, 1);
  return ret;
}

mat4x4 mat4x4_scale(f32 s) {
  mat4x4 ret;
  ret.c0 = v4_init(s, 0, 0, 0);
  ret.c1 = v4_init(0, s, 0, 0);
  ret.c2 = v4_init(0, 0, s, 0);
  ret.c3 = v4_init(0, 0, 0, 1);
  return ret;
}

mat4x4 mat4x4_proj(f32 A, f32 B, f32 C, f32 D, f32 E) {
  mat4x4 ret;
  ret.c0 = v4_init(A, 0, 0, 0);
  ret.c1 = v4_init(0, B, 0, 0);
  ret.c2 = v4_init(0, 0, C, E);
  ret.c3 = v4_init(0, 0, D, 0);
  return ret;
}

mat4x4 mat4x4_proj7(f32 A, f32 B, f32 C, f32 D, f32 E, f32 F, f32 G) {
  mat4x4 ret;
  ret.c0 = v4_init(A, 0, 0, 0);
  ret.c1 = v4_init(0, B, 0, 0);
  ret.c2 = v4_init(C, D, E, F);
  ret.c3 = v4_init(0, 0, G, 0);
  return ret;
}

mat4x4 mat4x4_perspective(f32 width, f32 height, f32 near, f32 far) {
  f32 TwoNearZ = near + near;
  f32 fRange = far / (near - far);

  return mat4x4_proj(TwoNearZ / width, TwoNearZ / height, fRange, -1,
                     fRange * near);
}

mat4x4 mat4x4_perspective_fov(f32 width,
                              f32 height,
                              f32 near,
                              f32 far,
                              f32 fov) {
  f32 S = 1.0f / tanf(fov * 0.5);
  f32 aspect = height / width;
  f32 TwoNearZ = near + near;
  f32 fRange = far / (near - far);

  return mat4x4_proj(aspect * S, S, fRange, -1, fRange * near);
}

mat4x4 mat4x4_transpose(mat4x4 x) {
  mat4x4 ret;
  ret.c0 = v4_init(x.c0.x, x.c1.x, x.c2.x, x.c3.x);
  ret.c1 = v4_init(x.c0.y, x.c1.y, x.c2.y, x.c3.y);
  ret.c2 = v4_init(x.c0.z, x.c1.z, x.c2.z, x.c3.z);
  ret.c3 = v4_init(x.c0.w, x.c1.w, x.c2.w, x.c3.w);
  return ret;
}

v4 quat_mul(v4 a, v4 b) {
  f32 qax = a.x, qay = a.y, qaz = a.z, qaw = a.w;
  f32 qbx = b.x, qby = b.y, qbz = b.z, qbw = b.w;

  v4 ret;
  ret.x = qax * qbw + qaw * qbx + qay * qbz - qaz * qby;
  ret.y = qay * qbw + qaw * qby + qaz * qbx - qax * qbz;
  ret.z = qaz * qbw + qaw * qbz + qax * qby - qay * qbx;
  ret.w = qaw * qbw - qax * qbx - qay * qby - qaz * qbz;

  return ret;
}

v4 quat_fromAngleAxis(v3 axis, f32 angle) {
  f32 halfAngle = angle / 2.0f;

  f32 s = sinf(halfAngle);

  v4 ret;
  ret.x = axis.x * s;
  ret.y = axis.y * s;
  ret.z = axis.z * s;
  ret.w = cosf(halfAngle);
  return ret;
}

v3 v3_applyQuat(v3 x, v4 q) {
  f32 vx = x.x, vy = x.y, vz = x.z;
  f32 qx = q.x, qy = q.y, qz = q.z, qw = q.w;

  // t = 2 * cross( q.xyz, v );
  f32 tx = 2 * (qy * vz - qz * vy);
  f32 ty = 2 * (qz * vx - qx * vz);
  f32 tz = 2 * (qx * vy - qy * vx);

  // v + q.w * t + cross( q.xyz, t );
  v3 ret;
  ret.x = vx + qw * tx + qy * tz - qz * ty;
  ret.y = vy + qw * ty + qz * tx - qx * tz;
  ret.z = vz + qw * tz + qx * ty - qy * tx;

  return ret;
}

v4 quat_conjugate(v4 a) {
  v4 ret = a;
  ret.x = -ret.x;
  ret.y = -ret.y;
  ret.z = -ret.z;
  return ret;
}

v2 v2_init(f32 x, f32 y) {
  return (v2){x, y};
}

v2 v2_min(v2 a, v2 b) {
  v2 ret;
  ret.x = min(a.x, b.x);
  ret.y = min(a.y, b.y);
  return ret;
}

v2 v2_max(v2 a, v2 b) {
  v2 ret;
  ret.x = max(a.x, b.x);
  ret.y = max(a.y, b.y);
  return ret;
}

f32 v2_cross(v2 a, v2 b) {
  return a.x * b.y - b.x * a.y;
}

v2 v2_sub(v2 a, v2 b) {
  v2 ret;
  ret.x = a.x - b.x;
  ret.y = a.y - b.y;
  return ret;
}

v3 v3_transform(v3 x, const mat4x4 *mat) {
  v4 x4 = v4_init(x.x, x.y, x.z, 1.0f);
  v3 ret;
  ret.x = v4_dot(v4_init(mat->c0.x, mat->c1.x, mat->c2.x, mat->c3.x), x4);
  ret.y = v4_dot(v4_init(mat->c0.y, mat->c1.y, mat->c2.y, mat->c3.y), x4);
  ret.z = v4_dot(v4_init(mat->c0.z, mat->c1.z, mat->c2.z, mat->c3.z), x4);
  return ret;
}

v4 v4_mul(v4 a, v4 b) {
  v4 ret;
  ret.x = a.x * b.x;
  ret.y = a.y * b.y;
  ret.z = a.z * b.z;
  ret.w = a.w * b.w;
  return ret;
}

v4 v4_add(v4 a, v4 b) {
  v4 ret;
  ret.x = a.x + b.x;
  ret.y = a.y + b.y;
  ret.z = a.z + b.z;
  ret.w = a.w + b.w;
  return ret;
}

v3 v3_transform_dir(v3 x, const mat4x4 *mat) {
  v4 X = v4_init(x.x, x.x, x.x, x.x);
  v4 Y = v4_init(x.y, x.y, x.y, x.y);
  v4 Z = v4_init(x.z, x.z, x.z, x.z);

  v4 ret = v4_mul(mat->c0, X);
  ret = v4_add(ret, v4_mul(mat->c1, Y));
  ret = v4_add(ret, v4_mul(mat->c2, Z));

  return v3_init(ret.x, ret.y, ret.z);
}

v3 v3_transform_dir_0001(v3 x, const mat4x4 *mat) {
  v3 ret;
  ret.x = mat->c0.x * x.x + mat->c1.x * x.y + mat->c2.y * x.z;
  ret.y = mat->c0.y * x.x + mat->c1.y * x.y + mat->c2.y * x.z;
  ret.z = mat->c0.z * x.x + mat->c1.z * x.y + mat->c2.z * x.z;

  return ret;
}

v3 v3_transform_dir_old(v3 x, const mat4x4 *mat) {
  v4 X = v4_init(x.x, x.x, x.x, x.x);
  v4 Y = v4_init(x.y, x.y, x.y, x.y);
  v4 Z = v4_init(x.z, x.z, x.z, x.z);

  v4 x4 = v4_init(x.x, x.y, x.z, 0.0f);
  v3 ret;
  ret.x = v4_dot(v4_init(mat->c0.x, mat->c1.x, mat->c2.x, mat->c3.x), x4);
  ret.y = v4_dot(v4_init(mat->c0.y, mat->c1.y, mat->c2.y, mat->c3.y), x4);
  ret.z = v4_dot(v4_init(mat->c0.z, mat->c1.z, mat->c2.z, mat->c3.z), x4);
  return ret;
}

v4 v4_scale(f32 s, v4 x) {
  v4 ret;
  ret.x = s * x.x;
  ret.y = s * x.y;
  ret.z = s * x.z;
  ret.w = s * x.w;
  return ret;
}

f32 mat2_det(f32 c0_x, f32 c0_y, f32 c1_x, f32 c1_y) {
  return c0_x * c1_y - c0_y * c1_x;
}

mat4x4 mat3_cofactor(mat4x4 A) {
  mat4x4 ret;

  f32 a1 = A.c0.x;
  f32 b1 = A.c0.y;
  f32 c1 = A.c0.z;

  f32 a2 = A.c1.x;
  f32 b2 = A.c1.y;
  f32 c2 = A.c1.z;

  f32 a3 = A.c2.x;
  f32 b3 = A.c2.y;
  f32 c3 = A.c2.z;

  ret.c0 = v4_init(+mat2_det(b2, c2, b3, c3), -mat2_det(a2, c2, a3, c3),
                   +mat2_det(a2, b2, a3, b3), 0);
  ret.c1 = v4_init(-mat2_det(b1, c1, b3, c3), +mat2_det(a1, c1, a3, c3),
                   -mat2_det(a1, b1, a3, b3), 0);
  ret.c2 = v4_init(+mat2_det(b1, c1, b2, c2), -mat2_det(a1, c1, a2, c2),
                   +mat2_det(a1, b1, a2, b2), 0);
  ret.c3 = v4_init(0, 0, 0, 0);
  return ret;
}

# Math Library

## Purpose

Self-contained math layer for vector, matrix and quaternion operations. Most of the surface lives inline in the header so call sites get them inlined without LTO; only the libc-backed scalars (`sin`, `cos`, etc.) and RNG live in the `.c`.

## Files

- `engine/src/math/math_types.h` — `vec2`, `vec3`, `vec4`, `quat` (alias for vec4), `mat4`, `vertex_3d` (`vec3 position` + `vec2 texture_coordinates`).
- `engine/src/math/hfst_math.h` — constants, scalar wrappers, vec/mat/quat operations.
- `engine/src/math/hfst_math.c` — `hfstsin/cos/tan/acos/sqrt/abs`, RNG.

## Public API

Constants: `HFST_PI`, `HFST_PI_2`, `HFST_HALF_PI`, `HFST_QUARTER_PI`, `HFST_SQRT_TWO`, `HFST_SQRT_THREE`, `HFST_DEG2RAD_MULTIPLIER`, `HFST_RAD2DEG_MULTIPLIER`, `HFST_INFINITY = 1e30f`, `HFST_FLOAT_EPSILON ≈ 1.19e-7`.

Scalars (`HAPI`): `hfstsin`, `hfstcos`, `hfsttan`, `hfstacos`, `hfstsqrt`, `hfstabs`, `hfstrandom`, `hfstrandom_in_range`, `hfstrandom_f`, `hfstrandom_in_range_f`, `is_power_of_2`, `deg_to_rad`, `rad_to_deg`.

Vectors (inline): per-element `_create/zero/one/up/down/left/right/forward/back`, `_add/sub/mul/div`, `_mul_scalar`, `_length/length_squared`, `_normalize/_normalized`, `_compare(tolerance)`, `_distance`, `_dot`, `vec3_cross`, `vec3_from_vec4`, `vec3_to_vec4`, `vec4_to_vec3`, `vec4_from_vec3`.

Matrices (inline): `mat4_identity`, `mat4_multiply`, `mat4_orthographic`, `mat4_perspective`, `mat4_look_at`, `mat4_transposed`, `mat4_inverse`, `mat4_translation`, `mat4_scale`, `mat4_euler_x/y/z/xyz`, `mat4_forward/backward/up/down/left/right`.

Quaternions (inline): `quat_identity/normal/normalize/conjugate/inverse/mul/dot`, `quat_to_mat4`, `quat_to_rotation_matrix(q, center)`, `quat_from_axis_angle`, `quat_slerp`.

## How it works

`vec*` types are unions over `f32 elements[N]` and named struct members so callers can write either `v.x` / `v.r` / `v.s` / `v.u` or `v.elements[0]`. `mat4` is a flat `f32 data[16]` in column-major order — `data[0..3]` is the first column, `data[12..15]` is the translation column.

Matrix multiplication assumes the `vec3` direction extractors (`mat4_forward`, etc.) read the rotation block at columns 0/1/2; `data[2,6,10]` is the third column reflecting the negative-Z forward convention.

`mat4_perspective` is a right-handed perspective (negative-Z forward, `data[10] = -((f+n)/(f-n))`, `data[11] = -1`). `mat4_orthographic` uses negative reciprocal differences to invert the frustum into NDC.

Quaternion `_to_mat4` normalises first; `quat_slerp` falls back to nlerp + normalize when `dot > 0.9995`.

`hfstrandom` lazily seeds with `platform_get_absolute_time` cast to `u32`.

## Design decisions & rationale

- **Heavy use of `HFSTINLINE` (`static inline` / `__forceinline`)** — keeps the math header inline-only so callers don't pay a function-call cost and the compiler can vectorise around them.
- **Right-handed, negative-Z forward** — visible in `mat4_forward = -data[2..10]` and `mat4_perspective`'s `-1` in `data[11]`. Matches the testbed's `state->camera_position.z = 30.0f` and `mat4_inverse(translation)` view setup.
- **Single `HFSTINLINE` macro** — different on MSVC (`__forceinline`) vs Clang/GCC (`static inline`) so behaviour can be tuned per-toolchain without spreading conditionals through the header.
- **`SIMD` placeholders** — `vec4_create` and `vec4_from_vec3` have a `#if defined(KUSE_SIMD)` branch using `_mm_setr_ps` (`hfst_math.h:543/573`). `KUSE_SIMD` is never defined; this is the entry point for a future SIMD pass.
- **`stdlib.h` `rand()`** — kept for now (`hfst_math.c:6`); intentionally not custom because we don't need a high-quality RNG yet.

## Known limitations

- The `KUSE_SIMD` SIMD path in `vec4_from_vec3` references `x, y, z, w` directly (`hfst_math.h:575`) which don't exist in that scope — the branch will fail to compile if ever enabled.
- `vec4` element field group `f32 w, a, q` (`math_types.h:59`) overlaps with `vec3`'s `f32 z, b, p, w` (`math_types.h:34`) — the `w` alias on vec3 is suspicious; vec3 has no fourth component, but the union member `w` exists. Reading `vec3.w` reads adjacent memory.
- `mat4_inverse` allocates no scratch but is large; expect it to be a hot spot if used per-frame.
- `vec3_compare` has `const b8` return (`hfst_math.h:496`) — the `const` is meaningless on a value return; harmless.
- `vec2_normalize` and friends don't guard against zero-length input.
- `string_to_vec*` parsers in `hstring.c` produce these types but don't validate ranges.

## Related docs

- [`renderer/frontend-backend-split.md`](../renderer/frontend-backend-split.md) — projection/view set up here, consumed by the renderer.
- [`testbed/testbed.md`](../testbed/testbed.md) — camera implementation uses Euler matrices and `mat4_inverse`.

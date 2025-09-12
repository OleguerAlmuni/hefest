#pragma once

#include "math_types.h"

#include "defines.h"

#define HFST_PI 3.14159265358979323846f
#define HFST_PI_2 2.0f * HFST_PI
#define HFST_HALF_PI 0.5f * HFST_PI
#define HFST_QUARTER_PI 0.25f * HFST_PI
#define HFST_ONE_OVER_PI 1.0f / HFST_PI
#define HFST_ONE_OVER_TWO_PI 1.0f / HFST_PI_2
#define HFST_SQRT_TWO 1.41421356237309504880f
#define HFST_SQRT_THREE 1.73205080756887729352f
#define HFST_SQRT_ONE_OVER_TWO 0.70710678118654752440f
#define HFST_SQRT_ONE_OVER_THREE 0.57735026918962576450f
#define HFST_DEG2RAD_MULTIPLIER HFST_PI / 180.0f
#define HFST_RAD2DEG_MULTIPLIER 180.0f / HFST_PI

// The multiplier to convert seconds to milliseconds.
#define HFST_SEC_TO_MS_MULTIPLIER 1000.0f

// The multiplier to convert milliseconds to seconds.
#define HFST_MS_TO_SEC_MULTIPLIER 0.001f

// A huge number that should be larger than any valid number used.
#define HFST_INFINITY 1e30f

// Smallest positive number where 1.0 + FLOAT_EPSILON != 0
#define HFST_FLOAT_EPSILON 1.192092896e-07f


// ------------------------------------------
// General math functions
// ------------------------------------------
HAPI f32 hfstsin(f32 x);
HAPI f32 hfstcos(f32 x);
HAPI f32 hfsttan(f32 x);
HAPI f32 hfstacos(f32 x);
HAPI f32 hfstsqrt(f32 x);
HAPI f32 hfstabs(f32 x);

/**
 * Indicates if the value is a power of 2. 0 is considered _not_ a power of 2.
 * @param value The value to be interpreted.
 * @returns True if a power of 2, otherwise false.
 */
HFSTINLINE b8 is_power_of_2(u64 value) {
    return (value != 0) && ((value & (value - 1)) == 0);
}

HAPI i32 hfstrandom();
HAPI i32 hfstrandom_in_range(i32 min, i32 max);

HAPI f32 hfstrandom_f();
HAPI f32 hfstrandom_in_range_f(f32 min, f32 max);

// ------------------------------------------
// Vector 2
// ------------------------------------------

/**
 * @brief Creates and returns a new 2-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @return A new 2-element vector.
 */
HFSTINLINE vec2 vec2_create(f32 x, f32 y) {
    vec2 out_vector;
    out_vector.x = x;
    out_vector.y = y;
    return out_vector;
}

/**
 * @brief Creates and returns a 2-component vector with all components set to 0.0f.
 */
HFSTINLINE vec2 vec2_zero() {
    return (vec2){0.0f, 0.0f};
}

/**
 * @brief Creates and returns a 2-component vector with all components set to 1.0f.
 */
HFSTINLINE vec2 vec2_one() {
    return (vec2){1.0f, 1.0f};
}

/**
 * @brief Creates and returns a 2-component vector pointing up (0, 1).
 */
HFSTINLINE vec2 vec2_up() {
    return (vec2){0.0f, 1.0f};
}

/**
 * @brief Creates and returns a 2-component vector pointing down (0, -1).
 */
HFSTINLINE vec2 vec2_down() {
    return (vec2){0.0f, -1.0f};
}

/**
 * @brief Creates and returns a 2-component vector pointing left (-1, 0).
 */
HFSTINLINE vec2 vec2_left() {
    return (vec2){-1.0f, 0.0f};
}

/**
 * @brief Creates and returns a 2-component vector pointing right (1, 0).
 */
HFSTINLINE vec2 vec2_right() {
    return (vec2){1.0f, 0.0f};
}

/**
 * @brief Adds vector_2 to vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec2 vec2_add(vec2 vector_1, vec2 vector_2) {
    return (vec2){
        vector_1.x + vector_2.x,
        vector_1.y + vector_2.y};
}

/**
 * @brief Subtracts vector_2 from vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec2 vec2_sub(vec2 vector_1, vec2 vector_2) {
    return (vec2){
        vector_1.x - vector_2.x,
        vector_1.y - vector_2.y};
}

/**
 * @brief Multiplies vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec2 vec2_mul(vec2 vector_1, vec2 vector_2) {
    return (vec2){
        vector_1.x * vector_2.x,
        vector_1.y * vector_2.y};
}

/**
 * @brief Divides vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec2 vec2_div(vec2 vector_1, vec2 vector_2) {
    return (vec2){
        vector_1.x / vector_2.x,
        vector_1.y / vector_2.y};
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
HFSTINLINE f32 vec2_length_squared(vec2 vector) {
    return vector.x * vector.x + vector.y * vector.y;
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
HFSTINLINE f32 vec2_length(vec2 vector) {
    return hfstsqrt(vec2_length_squared(vector));
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
HFSTINLINE void vec2_normalize(vec2* vector) {
    const f32 length = vec2_length(*vector);
    vector->x /= length;
    vector->y /= length;
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
HFSTINLINE vec2 vec2_normalized(vec2 vector) {
    vec2_normalize(&vector);
    return vector;
}

/**
 * @brief Compares all elements of vector_1 and vector_2 and ensures the difference
 * is less than tolerance.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @param tolerance The difference tolerance. Typically K_FLOAT_EPSILON or similar.
 * @return True if within tolerance; otherwise false. 
 */
HFSTINLINE b8 vec2_compare(vec2 vector_1, vec2 vector_2, f32 tolerance) {
    if (hfstabs(vector_1.x - vector_2.x) > tolerance) {
        return FALSE;
    }

    if (hfstabs(vector_1.y - vector_2.y) > tolerance) {
        return FALSE;
    }

    return TRUE;
}

/**
 * @brief Returns the distance between vector_1 and vector_2.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The distance between vector_1 and vector_2.
 */
HFSTINLINE f32 vec2_distance(vec2 vector_1, vec2 vector_2) {
    vec2 d = (vec2){
        vector_1.x - vector_2.x,
        vector_1.y - vector_2.y};
    return vec2_length(d);
}

// ------------------------------------------
// Vector 3
// ------------------------------------------

/**
 * @brief Creates and returns a new 3-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @param z The z value.
 * @return A new 3-element vector.
 */
HFSTINLINE vec3 vec3_create(f32 x, f32 y, f32 z) {
    return (vec3){x, y, z};
}

/**
 * @brief Returns a new vec3 containing the x, y and z components of the 
 * supplied vec4, essentially dropping the w component.
 * 
 * @param vector The 4-component vector to extract from.
 * @return A new vec3 
 */
HFSTINLINE vec3 vec3_from_vec4(vec4 vector) {
    return (vec3){vector.x, vector.y, vector.z};
}

/**
 * @brief Returns a new vec4 using vector as the x, y and z components and w for w.
 * 
 * @param vector The 3-component vector.
 * @param w The w component.
 * @return A new vec4 
 */
HFSTINLINE vec4 vec3_to_vec4(vec3 vector, f32 w) {
    return (vec4){vector.x, vector.y, vector.z, w};
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 0.0f.
 */
HFSTINLINE vec3 vec3_zero() {
    return (vec3){0.0f, 0.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 1.0f.
 */
HFSTINLINE vec3 vec3_one() {
    return (vec3){1.0f, 1.0f, 1.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing up (0, 1, 0).
 */
HFSTINLINE vec3 vec3_up() {
    return (vec3){0.0f, 1.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing down (0, -1, 0).
 */
HFSTINLINE vec3 vec3_down() {
    return (vec3){0.0f, -1.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing left (-1, 0, 0).
 */
HFSTINLINE vec3 vec3_left() {
    return (vec3){-1.0f, 0.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing right (1, 0, 0).
 */
HFSTINLINE vec3 vec3_right() {
    return (vec3){1.0f, 0.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing forward (0, 0, -1).
 */
HFSTINLINE vec3 vec3_forward() {
    return (vec3){0.0f, 0.0f, -1.0f};
}

/**
 * @brief Creates and returns a 3-component vector pointing backward (0, 0, 1).
 */
HFSTINLINE vec3 vec3_back() {
    return (vec3){0.0f, 0.0f, 1.0f};
}

/**
 * @brief Adds vector_2 to vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec3 vec3_add(vec3 vector_1, vec3 vector_2) {
    return (vec3){
        vector_1.x + vector_2.x,
        vector_1.y + vector_2.y,
        vector_1.z + vector_2.z};
}

/**
 * @brief Subtracts vector_2 from vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec3 vec3_sub(vec3 vector_1, vec3 vector_2) {
    return (vec3){
        vector_1.x - vector_2.x,
        vector_1.y - vector_2.y,
        vector_1.z - vector_2.z};
}

/**
 * @brief Multiplies vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec3 vec3_mul(vec3 vector_1, vec3 vector_2) {
    return (vec3){
        vector_1.x * vector_2.x,
        vector_1.y * vector_2.y,
        vector_1.z * vector_2.z};
}

/**
 * @brief Multiplies all elements of vector_1 by scalar and returns a copy of the result.
 * 
 * @param vector_1 The vector to be multiplied.
 * @param scalar The scalar value.
 * @return A copy of the resulting vector.
 */
HFSTINLINE vec3 vec3_mul_scalar(vec3 vector_1, f32 scalar) {
    return (vec3){
        vector_1.x * scalar,
        vector_1.y * scalar,
        vector_1.z * scalar};
}

/**
 * @brief Divides vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec3 vec3_div(vec3 vector_1, vec3 vector_2) {
    return (vec3){
        vector_1.x / vector_2.x,
        vector_1.y / vector_2.y,
        vector_1.z / vector_2.z};
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
HFSTINLINE f32 vec3_length_squared(vec3 vector) {
    return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z;
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
HFSTINLINE f32 vec3_length(vec3 vector) {
    return hfstsqrt(vec3_length_squared(vector));
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
HFSTINLINE void vec3_normalize(vec3* vector) {
    const f32 length = vec3_length(*vector);
    vector->x /= length;
    vector->y /= length;
    vector->z /= length;
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
HFSTINLINE vec3 vec3_normalized(vec3 vector) {
    vec3_normalize(&vector);
    return vector;
}

/**
 * @brief Returns the dot product between the provided vectors. Typically used
 * to calculate the difference in direction.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The dot product. 
 */
HFSTINLINE f32 vec3_dot(vec3 vector_1, vec3 vector_2) {
    f32 p = 0;
    p += vector_1.x * vector_2.x;
    p += vector_1.y * vector_2.y;
    p += vector_1.z * vector_2.z;
    return p;
}

/**
 * @brief Calculates and returns the cross product of the supplied vectors.
 * The cross product is a new vector which is orthoganal to both provided vectors.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The cross product. 
 */
HFSTINLINE vec3 vec3_cross(vec3 vector_1, vec3 vector_2) {
    return (vec3){
        vector_1.y * vector_2.z - vector_1.z * vector_2.y,
        vector_1.z * vector_2.x - vector_1.x * vector_2.z,
        vector_1.x * vector_2.y - vector_1.y * vector_2.x};
}

/**
 * @brief Compares all elements of vector_1 and vector_2 and ensures the difference
 * is less than tolerance.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @param tolerance The difference tolerance. Typically K_FLOAT_EPSILON or similar.
 * @return True if within tolerance; otherwise false. 
 */
HFSTINLINE const b8 vec3_compare(vec3 vector_1, vec3 vector_2, f32 tolerance) {
    if (hfstabs(vector_1.x - vector_2.x) > tolerance) {
        return FALSE;
    }

    if (hfstabs(vector_1.y - vector_2.y) > tolerance) {
        return FALSE;
    }

    if (hfstabs(vector_1.z - vector_2.z) > tolerance) {
        return FALSE;
    }

    return TRUE;
}

/**
 * @brief Returns the distance between vector_1 and vector_2.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The distance between vector_1 and vector_2.
 */
HFSTINLINE f32 vec3_distance(vec3 vector_1, vec3 vector_2) {
    vec3 d = (vec3){
        vector_1.x - vector_2.x,
        vector_1.y - vector_2.y,
        vector_1.z - vector_2.z};
    return vec3_length(d);
}


// ------------------------------------------
// Vector 4
// ------------------------------------------

/**
 * @brief Creates and returns a new 4-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @param z The z value.
 * @param w The w value.
 * @return A new 4-element vector.
 */
HFSTINLINE vec4 vec4_create(f32 x, f32 y, f32 z, f32 w) {
    vec4 out_vector;
#if defined(KUSE_SIMD)
    out_vector.data = _mm_setr_ps(x, y, z, w);
#else
    out_vector.x = x;
    out_vector.y = y;
    out_vector.z = z;
    out_vector.w = w;
#endif
    return out_vector;
}

/**
 * @brief Returns a new vec3 containing the x, y and z components of the 
 * supplied vec4, essentially dropping the w component.
 * 
 * @param vector The 4-component vector to extract from.
 * @return A new vec3 
 */
HFSTINLINE vec3 vec4_to_vec3(vec4 vector) {
    return (vec3){vector.x, vector.y, vector.z};
}

/**
 * @brief Returns a new vec4 using vector as the x, y and z components and w for w.
 * 
 * @param vector The 3-component vector.
 * @param w The w component.
 * @return A new vec4 
 */
HFSTINLINE vec4 vec4_from_vec3(vec3 vector, f32 w) {
#if defined(KUSE_SIMD)
    vec4 out_vector;
    out_vector.data = _mm_setr_ps(x, y, z, w);
    return out_vector;
#else
    return (vec4){vector.x, vector.y, vector.z, w};
#endif
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 0.0f.
 */
HFSTINLINE vec4 vec4_zero() {
    return (vec4){0.0f, 0.0f, 0.0f, 0.0f};
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 1.0f.
 */
HFSTINLINE vec4 vec4_one() {
    return (vec4){1.0f, 1.0f, 1.0f, 1.0f};
}

/**
 * @brief Adds vector_2 to vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec4 vec4_add(vec4 vector_1, vec4 vector_2) {
    vec4 result;
     for (u64 i = 0; i < 4; ++i) {
        result.elements[i] = vector_1.elements[i] + vector_2.elements[i];
    }
    return result;
}

/**
 * @brief Subtracts vector_2 from vector_1 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec4 vec4_sub(vec4 vector_1, vec4 vector_2) {
    vec4 result;
    for (u64 i = 0; i < 4; ++i) {
        result.elements[i] = vector_1.elements[i] - vector_2.elements[i];
    }
    return result;
}

/**
 * @brief Multiplies vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec4 vec4_mul(vec4 vector_1, vec4 vector_2) {
    vec4 result;
    for (u64 i = 0; i < 4; ++i) {
        result.elements[i] = vector_1.elements[i] * vector_2.elements[i];
    }
    return result;
}

/**
 * @brief Divides vector_1 by vector_2 and returns a copy of the result.
 * 
 * @param vector_1 The first vector.
 * @param vector_2 The second vector.
 * @return The resulting vector. 
 */
HFSTINLINE vec4 vec4_div(vec4 vector_1, vec4 vector_2) {
    vec4 result;
    for (u64 i = 0; i < 4; ++i) {
        result.elements[i] = vector_1.elements[i] / vector_2.elements[i];
    }
    return result;
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
HFSTINLINE f32 vec4_length_squared(vec4 vector) {
    return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z + vector.w * vector.w;
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
HFSTINLINE f32 vec4_length(vec4 vector) {
    return hfstsqrt(vec4_length_squared(vector));
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
HFSTINLINE void vec4_normalize(vec4* vector) {
    const f32 length = vec4_length(*vector);
    vector->x /= length;
    vector->y /= length;
    vector->z /= length;
    vector->w /= length;
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
HFSTINLINE vec4 vec4_normalized(vec4 vector) {
    vec4_normalize(&vector);
    return vector;
}

HFSTINLINE f32 vec4_dot_f32(
    f32 a0, f32 a1, f32 a2, f32 a3,
    f32 b0, f32 b1, f32 b2, f32 b3) {
    f32 p;
    p =
        a0 * b0 +
        a1 * b1 +
        a2 * b2 +
        a3 * b3;
    return p;
}


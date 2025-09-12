#include "hfst_math.h"

#include "platform/platform.h"

#include <math.h>
#include <stdlib.h>

static b8 rand_seeded = FALSE;

/**
 * Note that these are here in order to prevent having to import the
 * entire <math.h> library everywhere.
 */

f32 hfstsin(f32 x) {
    return sinf(x);
}

f32 hfstcos(f32 x) {
    return cosf(x);
}

f32 hfsttan(f32 x) {
    return tanf(x);
}

f32 hfstacos(f32 x) {
    return acosf(x);
}

f32 hfstsqrt(f32 x) {
    return sqrtf(x);
}

f32 hfstabs(f32 x) {
    return fabsf(x);
}

i32 hfstrandom() {
    if (!rand_seeded) {
        srand((u32)platform_get_absolute_time());
        rand_seeded = TRUE;
    }
    return rand();
}

i32 hfstrandom_in_range(i32 min, i32 max) {
    if (!rand_seeded) {
        srand((u32)platform_get_absolute_time());
        rand_seeded = TRUE;
    }
    return (rand() % (max - min + 1)) + min;
}

f32 hfstrandom_f() {
    return (float)hfstrandom() / (f32)RAND_MAX;
}

f32 hfstrandom_in_range_f(f32 min, f32 max) {
    return min + ((float)hfstrandom() / ((f32)RAND_MAX / (max - min)));
}
#include "core/metrics.h"

#include "core/hmemory.h"
#include "core/logger.h"
#include "platform/platform.h"

#include <stdio.h>

static const char* section_names[METRICS_SECTION_MAX] = {
    "frame      ",
    "platform   ",
    "game update",
    "game render",
    "render     ",
    "gpu        ",
    "upload buf ",
    "upload img "
};

typedef struct metrics_state {
    // Rolling window of committed per-frame totals, in milliseconds.
    f64 samples[METRICS_SECTION_MAX][METRICS_WINDOW_SIZE];
    // Number of valid entries in the window, saturating at METRICS_WINDOW_SIZE.
    u32 sample_count;
    // Write cursor into the ring.
    u32 next_index;

    // Time accumulated in the current frame, in milliseconds.
    f64 current[METRICS_SECTION_MAX];
    // Absolute time at which each open section was begun, in seconds.
    f64 section_start[METRICS_SECTION_MAX];
    b8 section_open[METRICS_SECTION_MAX];

    // Lifetime accumulators, independent of the frame loop.
    f64 total_ms[METRICS_SECTION_MAX];
    u64 call_count[METRICS_SECTION_MAX];

    u64 frame_count;
    b8 in_frame;
} metrics_state;

static metrics_state* state_ptr = 0;

b8 metrics_initialize(u64* memory_requirement, void* state) {
    *memory_requirement = sizeof(metrics_state);
    if (state == 0) {
        return true;
    }

    state_ptr = state;
    hzero_memory(state_ptr, sizeof(metrics_state));
    return true;
}

void metrics_shutdown(void* state) {
    state_ptr = 0;
}

void metrics_frame_begin(void) {
    if (!state_ptr) {
        return;
    }

    if (state_ptr->in_frame) {
        HWARN("metrics_frame_begin called twice without an intervening metrics_frame_end.");
        return;
    }

    for (u32 i = 0; i < METRICS_SECTION_MAX; ++i) {
        state_ptr->current[i] = 0.0;
        state_ptr->section_open[i] = false;
    }

    state_ptr->in_frame = true;
    metrics_section_begin(METRICS_SECTION_FRAME);
}

void metrics_frame_end(void) {
    if (!state_ptr || !state_ptr->in_frame) {
        return;
    }

    metrics_section_end(METRICS_SECTION_FRAME);

    // Commit this frame's totals into the ring.
    u32 index = state_ptr->next_index;
    for (u32 i = 0; i < METRICS_SECTION_MAX; ++i) {
        if (state_ptr->section_open[i]) {
            HWARN("Section '%s' was begun but never ended; its time is discarded.", section_names[i]);
            state_ptr->current[i] = 0.0;
        }
        state_ptr->samples[i][index] = state_ptr->current[i];
    }

    state_ptr->next_index = (index + 1) % METRICS_WINDOW_SIZE;
    if (state_ptr->sample_count < METRICS_WINDOW_SIZE) {
        state_ptr->sample_count++;
    }

    state_ptr->frame_count++;
    state_ptr->in_frame = false;
}

void metrics_section_begin(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX) {
        return;
    }

    if (state_ptr->section_open[section]) {
        HWARN("metrics_section_begin: section '%s' is already open.", section_names[section]);
        return;
    }

    state_ptr->section_start[section] = platform_get_absolute_time();
    state_ptr->section_open[section] = true;
}

void metrics_section_end(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX) {
        return;
    }

    if (!state_ptr->section_open[section]) {
        HWARN("metrics_section_end: section '%s' was not open.", section_names[section]);
        return;
    }

    f64 elapsed_ms = (platform_get_absolute_time() - state_ptr->section_start[section]) * 1000.0;
    state_ptr->current[section] += elapsed_ms;
    state_ptr->total_ms[section] += elapsed_ms;
    state_ptr->call_count[section]++;
    state_ptr->section_open[section] = false;
}

void metrics_section_add_ms(metrics_section section, f64 milliseconds) {
    if (!state_ptr || section >= METRICS_SECTION_MAX) {
        return;
    }

    state_ptr->current[section] += milliseconds;
    state_ptr->total_ms[section] += milliseconds;
    state_ptr->call_count[section]++;
}

f64 metrics_section_average_ms(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX || state_ptr->sample_count == 0) {
        return 0.0;
    }

    f64 total = 0.0;
    for (u32 i = 0; i < state_ptr->sample_count; ++i) {
        total += state_ptr->samples[section][i];
    }
    return total / (f64)state_ptr->sample_count;
}

f64 metrics_section_min_ms(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX || state_ptr->sample_count == 0) {
        return 0.0;
    }

    f64 lowest = state_ptr->samples[section][0];
    for (u32 i = 1; i < state_ptr->sample_count; ++i) {
        if (state_ptr->samples[section][i] < lowest) {
            lowest = state_ptr->samples[section][i];
        }
    }
    return lowest;
}

f64 metrics_section_max_ms(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX || state_ptr->sample_count == 0) {
        return 0.0;
    }

    f64 highest = state_ptr->samples[section][0];
    for (u32 i = 1; i < state_ptr->sample_count; ++i) {
        if (state_ptr->samples[section][i] > highest) {
            highest = state_ptr->samples[section][i];
        }
    }
    return highest;
}

f64 metrics_frames_per_second(void) {
    f64 average = metrics_section_average_ms(METRICS_SECTION_FRAME);
    if (average <= 0.0) {
        return 0.0;
    }
    return 1000.0 / average;
}

f64 metrics_section_total_ms(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX) {
        return 0.0;
    }
    return state_ptr->total_ms[section];
}

u64 metrics_section_call_count(metrics_section section) {
    if (!state_ptr || section >= METRICS_SECTION_MAX) {
        return 0;
    }
    return state_ptr->call_count[section];
}

u32 metrics_sample_count(void) {
    return state_ptr ? state_ptr->sample_count : 0;
}

u64 metrics_frame_count(void) {
    return state_ptr ? state_ptr->frame_count : 0;
}

const char* metrics_section_name(metrics_section section) {
    if (section >= METRICS_SECTION_MAX) {
        return "unknown";
    }
    return section_names[section];
}

const char* metrics_report_str(void) {
    // Static storage so that the per-second reporting path allocates nothing.
    static char buffer[1024];

    if (!state_ptr || state_ptr->sample_count == 0) {
        snprintf(buffer, sizeof(buffer), "Metrics: no samples yet.");
        return buffer;
    }

    i32 offset = snprintf(
        buffer, sizeof(buffer),
        "Frame timing over %u frames (%.1f FPS):\n",
        state_ptr->sample_count, metrics_frames_per_second());

    for (u32 i = 0; i < METRICS_SECTION_MAX; ++i) {
        i32 written = snprintf(
            buffer + offset, sizeof(buffer) - offset,
            "  %s  avg %7.3f ms   min %7.3f ms   max %7.3f ms\n",
            section_names[i],
            metrics_section_average_ms((metrics_section)i),
            metrics_section_min_ms((metrics_section)i),
            metrics_section_max_ms((metrics_section)i));

        if (written < 0 || (u64)(offset + written) >= sizeof(buffer)) {
            break;
        }
        offset += written;
    }

    // Uploads mostly happen outside the frame loop, so the window says nothing
    // useful about them. Report their lifetime total instead.
    if ((u64)offset < sizeof(buffer)) {
        snprintf(
            buffer + offset, sizeof(buffer) - offset,
            "  uploads      buffers: %llu in %.3f ms   images: %llu in %.3f ms\n",
            metrics_section_call_count(METRICS_SECTION_UPLOAD),
            metrics_section_total_ms(METRICS_SECTION_UPLOAD),
            metrics_section_call_count(METRICS_SECTION_UPLOAD_IMAGE),
            metrics_section_total_ms(METRICS_SECTION_UPLOAD_IMAGE));
    }

    return buffer;
}

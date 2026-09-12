#pragma once

#include "defines.h"

/**
 * Per-frame timing instrumentation.
 *
 * The engine measures itself by bracketing named sections with
 * metrics_section_begin/end. Each section accumulates within a frame and is
 * committed once per frame, so a section entered several times in one frame
 * reports the total rather than the last occurrence.
 *
 * Samples are kept in a rolling window rather than reported per frame, because
 * a single frame's timing is mostly noise. All results are in milliseconds.
 *
 * NOTE: this measures host-side time only. A queue submission returns as soon
 * as the work is submitted, so METRICS_SECTION_RENDER reports how long the CPU
 * spent recording and submitting, not how long the GPU took to execute. Device
 * timing requires timestamp queries.
 */

// Number of frames kept in the rolling window.
#define METRICS_WINDOW_SIZE 120

typedef enum metrics_section {
    // Whole loop iteration. Opened and closed by metrics_frame_begin/end.
    METRICS_SECTION_FRAME = 0,
    // Draining OS events.
    METRICS_SECTION_PLATFORM,
    // Game-side update callback.
    METRICS_SECTION_GAME_UPDATE,
    // Game-side render callback.
    METRICS_SECTION_GAME_RENDER,
    // Recording and submitting the frame's rendering work.
    METRICS_SECTION_RENDER,
    // Resource uploads to device memory.
    METRICS_SECTION_UPLOAD,

    METRICS_SECTION_MAX
} metrics_section;

b8 metrics_initialize(u64* memory_requirement, void* state);
void metrics_shutdown(void* state);

/** Begins a frame. Opens METRICS_SECTION_FRAME and clears the accumulators. */
HAPI void metrics_frame_begin(void);

/** Ends a frame, committing every section's accumulated time to the window. */
HAPI void metrics_frame_end(void);

HAPI void metrics_section_begin(metrics_section section);
HAPI void metrics_section_end(metrics_section section);

/** Mean time for a section over the window, in milliseconds. */
HAPI f64 metrics_section_average_ms(metrics_section section);
HAPI f64 metrics_section_min_ms(metrics_section section);
HAPI f64 metrics_section_max_ms(metrics_section section);

/** Frames per second derived from the mean frame time over the window. */
HAPI f64 metrics_frames_per_second(void);

/**
 * Lifetime total for a section, in milliseconds, together with the number of
 * times it was entered. Unlike the windowed statistics these accumulate from
 * start-up and are independent of the frame loop, which makes them the right
 * tool for one-off work such as the resource uploads performed during
 * initialization.
 */
HAPI f64 metrics_section_total_ms(metrics_section section);
HAPI u64 metrics_section_call_count(metrics_section section);

/** Number of frames currently held in the window. */
HAPI u32 metrics_sample_count(void);

/** Total frames measured since start-up. */
HAPI u64 metrics_frame_count(void);

HAPI const char* metrics_section_name(metrics_section section);

/**
 * Formats the current window as a multi-line report. The returned pointer is to
 * internal storage, is valid until the next call, and must not be freed.
 */
HAPI const char* metrics_report_str(void);

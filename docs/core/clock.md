# Clock

## Purpose

Trivial wall-clock timer used by the application loop to compute frame delta. Wraps `platform_get_absolute_time` so callers don't depend on platform headers.

## Files

- `engine/src/core/clock.h` / `clock.c`.

## Public API

- `struct clock { f64 start_time; f64 elsapsed; }` (typo: `elsapsed`).
- `clock_start(clock*)`, `clock_stop(clock*)`, `clock_update(clock*)`.

All marked `HAPI`.

## How it works

`clock_start` snapshots `platform_get_absolute_time()` and zeros `elsapsed`. `clock_update` recomputes `elsapsed = now - start_time` if started; if `start_time == 0` it is a no-op. `clock_stop` sets `start_time = 0` (does not zero `elsapsed`).

`application_run` (`application.c:152`) starts one clock at loop entry, then calls `clock_update` each iteration to update `elsapsed` for delta calculation.

## Design decisions & rationale

- **No pause/accumulate semantics** — start, query, stop. Keeps the surface tiny; multiple clocks can be stacked for stopwatch-style measurements.
- **Backed by `platform_get_absolute_time`** — Win32 uses `QueryPerformanceCounter` (high-resolution), Linux uses `clock_gettime`. Both produce monotonic seconds as `f64`.
- **`elsapsed` typo preserved** — public field, changing it breaks the testbed (it doesn't read the field). Worth a future cleanup.

## Known limitations

- No "delta since last update" helper — application computes that itself.
- Clocks are independent objects; no global engine clock.

## Related docs

- [`platform/platform-layer.md`](../platform/platform-layer.md) — `platform_get_absolute_time`.

# Logging and Assertions

## Purpose

Single funnel for everything the engine wants to say. Six severity levels, formatted prefix, optional file mirror, and a hard-stop assertion variant for invariants. Assertions delegate their failure messages through the same logger so a tripped invariant lands in the same console and log file as everything else.

## Files

- `engine/src/core/logger.h` / `logger.c` — log levels, public macros, file sink.
- `engine/src/core/asserts.h` — `HASSERT`, `HASSERT_MSG`, `HASSERT_DEBUG`, `debug_break()`.

## Public API

- `log_level` enum: `LOG_LEVEL_FATAL`/`ERROR`/`WARN`/`INFO`/`DEBUG`/`TRACE` (0..5).
- `b8 initialize_logging(u64* memory_requirement, void* state)` — two-call init pattern.
- `void shutdown_logging(void* state)`.
- `void log_output(log_level, const char* fmt, ...)`.
- Macros: `HFATAL`, `HERROR`, `HWARN`, `HINFO`, `HDEBUG`, `HTRACE` — each compiles to a no-op when its `LOG_*_ENABLED` define is zero.
- Assertions: `HASSERT(expr)`, `HASSERT_MSG(expr, msg)`, `HASSERT_DEBUG(expr)`. All three call `report_assertion_failure(...)` (defined in `logger.c:104`) then `debug_break()`.

## How it works

`log_output` prefixes the message with `[LEVEL]:`, formats via `string_format_v` into a 32 KB stack buffer, and routes to either `platform_console_write_error` (for FATAL/ERROR) or `platform_console_write` (with a colour code = level). The same formatted line is mirrored to a file handle held in `logger_system_state.log_file_handle`, opened once during `initialize_logging` as `console.log` in write mode (truncates on every run).

The state struct is just the file handle — required size is reported during the first init call so `application_create` can carve it out of the systems linear allocator.

Assertions are macros so they capture `__FILE__` and `__LINE__` at the call site. `debug_break()` is `__debugbreak()` on MSVC and `__builtin_trap()` elsewhere. `HASSERT_DEBUG` is empty unless `_DEBUG` is defined.

## Design decisions & rationale

- **Macro-based level gating** — each log macro is wrapped in `#if LOG_*_ENABLED` so disabled levels emit nothing, including no argument evaluation. Useful for `HTRACE` in hot paths. Defined in `logger.h:5-14` (see `d4a5c2e`).
- **Logger sits below most other systems** — it itself uses `filesystem` and `hstring`, so it must be initialized after them in raw dependency order, but `application.c:88` initialises it third (after events + memory) and before everything else. The early bring-up logs use `platform_console_write*` directly, which is fine since the platform layer has its own startup sequencing (see `d4a5c2e`).
- **File mirror is synchronous** — every `log_output` writes to console.log immediately. `logger.c:60-62` calls this out as a TODO to move off the main thread. Accept the cost for now since logging is bursty during init/shutdown only.
- **Six levels including TRACE/DEBUG** — `KRELEASE` is intended to compile DEBUG/TRACE out (`logger.h:11`), but no Makefile sets `KRELEASE`, so today every level is live (see `BUILD.md`).
- **Assertions log via the same logger** — the failure message is formatted with `LOG_LEVEL_FATAL`, so it lands in `console.log` *before* `debug_break` halts the process (see `d4a5c2e`).
- **`HAPI` on `log_output`** — exported so the testbed (and any future tooling) can call it directly. `report_assertion_failure` is also exported because assertions can fire from any module that includes `asserts.h`.

## Known limitations

- File I/O on the main thread.
- `console.log` is truncated, not rotated; previous-run logs are lost.
- 32 KB stack buffers in `log_output` — anything larger silently truncates inside `vsnprintf`.
- `initialize_logging` calls `HFATAL/HERROR/.../HTRACE` once each as a smoke test (`logger.c:43-48`); marked as a TODO and left in.
- The `logger_system_state` is allocated via the systems allocator but the file handle inside it owns a `FILE*` that must be closed during `shutdown_logging` — currently not closed (`logger.c:54-57` TODO).

## Related docs

- [`core/string-library.md`](string-library.md) — `string_format_v`.
- [`platform/filesystem.md`](../platform/filesystem.md) — backing file I/O.
- [`systems/initialization-pattern.md`](../systems/initialization-pattern.md) — the size/init handshake.

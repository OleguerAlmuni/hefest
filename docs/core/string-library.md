# String Library

## Purpose

Thin replacement layer for libc string operations, plus formatted output and a growing set of "parse a primitive (or vec2/3/4) from a string" helpers. The longer-term intent (visible in `hmemory.c:7` "TODO: Custom string library") is to remove the engine's `<string.h>` dependency entirely; today most calls still forward to libc.

## Files

- `engine/src/core/hstring.h` / `hstring.c`.

## Public API

- Length / copy / compare / format: `string_length`, `string_duplicate`, `strings_equal`, `strings_equal_insensitive`, `string_format(dest, fmt, ...)`, `string_format_v(dest, fmt, va_list)`, `string_copy`, `string_ncopy`, `string_trim`, `string_substring`, `string_index_of`.
- Parsers: `string_to_vec4/vec3/vec2`, `string_to_f32/f64`, `string_to_i8..i64`, `string_to_u8..u64`, `string_to_bool`.

All `HAPI`.

## How it works

The simple ones forward to libc: `strlen`, `strcmp`, `strcpy`, `strncpy`. `string_duplicate` allocates with `MEMORY_TAG_STRING` so duplicated strings show up in the memory report. `string_format_v` formats into a 32 KB stack buffer via `vsnprintf` then memcpys into the caller-provided destination.

The numeric/vector parsers are `sscanf`-based, with a quirk: every `string_to_*` returns `result != -1` rather than `result == n_expected`, so a partial match like "1.0 abc" parsing a `vec2` returns `true` with only `x` filled in.

`string_format_v` accepts a `void*` for the va_list and casts it to `__builtin_va_list` inside — works around an MSVC headers issue where `va_list` is `typedef char* va_list` in some translation units (also documented in `logger.c:82`).

## Design decisions & rationale

- **Allocations tagged STRING** — duplicated strings show up under their own tag in `get_memory_usage_str` (see `9eeba7c`).
- **Stack-buffer formatting (32 KB)** — `string_format_v` is reentrant and doesn't allocate, but the buffer cap is implicit. Caller must ensure `dest` is at least the formatted length + 1.
- **Parser surface mirrors `defines.h` types** — there's a parser per fundamental type so call-sites don't pick the wrong width.
- **`__builtin_va_list` workaround** — preserves portability between Clang on Windows and Clang on Linux despite MS headers redefining `va_list`.

## Known limitations / open issues

The current working tree (`engine/src/core/hstring.{h,c}`, uncommitted) introduces several issues:

- `string_to_vec2/3/4` call `kzero_memory` (`hstring.c:132/142/152`) which doesn't exist anywhere in the engine — likely a leftover from a prefix rename. Should be `hzero_memory`. Will fail to link as-is.
- `string_to_bool` (`hstring.c:262`) calls `strings_equali`, which doesn't exist. The header declares `strings_equal_insensitive`. Same root cause.
- `strings_equal_insensitive` (`hstring.c:28-34`) checks `_GNUC_` (single underscores) rather than `__GNUC__`, then falls through with no return on the GCC path, returning garbage. The Windows path (`_MSC_VER`) is fine.
- All `string_to_*` parsers return `result != -1`, not `result == expected`. A partial parse is reported as success.
- `string_substring` writes a terminator at `dest[start + length]` instead of `dest[length]` — the terminator lands at the wrong index when `start > 0`.
- `string_index_of` declares its parameter as `char*` instead of `const char*`, forcing callers to cast.
- The headers depend on `math/math_types.h` for `vec*` parsing — fine, but it does mean every consumer of `hstring.h` pulls in math types.

These are pre-existing in the working tree; mentioning them so they get flagged in audit, not implying they need fixing in this docs pass.

## Related docs

- [`core/logging-and-asserts.md`](logging-and-asserts.md) — heavy user of `string_format_v`.
- [`core/memory-subsystem.md`](memory-subsystem.md) — `MEMORY_TAG_STRING`.

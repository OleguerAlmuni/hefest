# Filesystem

## Purpose

Stdio-backed file I/O wrapped behind a small handle abstraction. Used by the logger to mirror messages into `console.log` and by the Vulkan shader loader to read SPIR-V binaries. Adds `read_all_bytes` and a line-at-a-time path for convenience.

## Files

- `engine/src/platform/filesystem.h` / `filesystem.c`.

## Public API

- `struct file_handle { void* handle; b8 is_valid; }` — `handle` is an opaque `FILE*`.
- `enum file_modes` — `FILE_MODE_READ = 0x1`, `FILE_MODE_WRITE = 0x2` (combinable).
- `filesystem_exists(path)` — `_stat`-based.
- `filesystem_open(path, mode, binary, out_handle)` — picks `r/w/r+` and the `b` suffix from the flags.
- `filesystem_close(handle)`.
- `filesystem_read_line(handle, char** out_line)` — allocates `MEMORY_TAG_STRING`, caller frees.
- `filesystem_write_line(handle, text)` — appends `\n`, fflushes.
- `filesystem_read(handle, data_size, out_data, out_bytes_read)` — caller-owned buffer.
- `filesystem_read_all_bytes(handle, u8** out_bytes, out_bytes_read)` — allocates `MEMORY_TAG_STRING` (yes, even for binary blobs).
- `filesystem_write(handle, data_size, data, out_bytes_written)` — fflushes.

All `HAPI`.

## How it works

Each function takes a `file_handle*`, casts the inner `void* handle` to `FILE*`, and forwards to `fopen`/`fread`/`fwrite`/`fputs`. `_open` builds a libc mode string from the bit flags and binary boolean: read+write becomes `w+` (truncates the file — see Known limitations).

`filesystem_read_all_bytes` seeks to the end to compute the size, rewinds, allocates that many bytes (`MEMORY_TAG_STRING`), and reads. Used by `vulkan_shader_utils.create_shader_module` to slurp the compiled SPIR-V.

`filesystem_write` and `filesystem_write_line` both `fflush` after writing — the rationale at `filesystem.c:74` is "to prevent data loss in the event of a crash".

## Design decisions & rationale

- **Opaque handle** — keeps `<stdio.h>` out of consumer headers (`9ed48a5`). Only the logger and the shader loader see the implementation.
- **Allocates with `MEMORY_TAG_STRING`** for both line reads and `read_all_bytes`. SPIR-V blobs are technically `MEMORY_TAG_RENDERER`-shaped, but tagging them STRING is consistent with "buffer of bytes I just read in".
- **`_stat` (Windows-style underscore prefix)** — used unconditionally (`filesystem.c:11`). Linux's `clang` accepts `_stat` because the headers expose both; this is a portability fragility worth knowing.
- **No path manipulation helpers** — paths are raw `const char*`, callers (`texture_system.load_texture`) build them via `string_format`.

## Known limitations

- `filesystem_open` with read+write picks `w+`, which truncates. There is no append mode.
- `filesystem_read` returns `false` on partial reads (`*out_bytes_read != data_size`) but still leaves whatever was read in the buffer. Callers should still check `out_bytes_read`.
- `filesystem_read_all_bytes` allocates with `MEMORY_TAG_STRING`, masking the real owner in the memory report.
- `filesystem_close` is the only cleanup; abandoned handles leak the `FILE*`.
- `_stat` is non-portable spelled this way; works because both clang-windows and clang-linux happen to accept it. Should be `stat` on Linux.
- No directory listing, mkdir, rename, or absolute-path resolution.
- Synchronous, blocking I/O only.

## Related docs

- [`core/logging-and-asserts.md`](../core/logging-and-asserts.md) — primary writer.
- [`renderer/vulkan-shaders.md`](../renderer/vulkan-shaders.md) — primary reader (SPIR-V).

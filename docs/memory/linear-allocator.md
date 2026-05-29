# Linear Allocator

## Purpose

Bump allocator over a fixed-size block. Hands out monotonically increasing pointers; never frees individually. The application's "systems allocator" is one of these and holds the state for every subsystem registered during `application_create`.

## Files

- `engine/src/memory/linear_allocator.h` / `linear_allocator.c`.

## Public API

- `struct linear_allocator { u64 total_size; u64 allocated; void* memory; b8 owns_memory; }`.
- `linear_allocator_create(total_size, memory, out_allocator)` — pass `memory = 0` to make the allocator own its backing block (allocated via `hallocate(MEMORY_TAG_LINEAR_ALLOCATOR)`).
- `linear_allocator_destroy(allocator)` — frees backing memory only if it was self-allocated.
- `linear_allocator_allocate(allocator, size)` — returns NULL and logs an error if exhausted.
- `linear_allocator_free_all(allocator)` — resets `allocated = 0` and zeros the memory.

All `HAPI`.

## How it works

`allocate` returns `memory + allocated`, then advances `allocated`. Out-of-space results in `HERROR` and `NULL`. `free_all` rewinds the cursor to zero. There is no per-allocation header, no alignment.

`application_create` calls `linear_allocator_create(64 MiB, 0, ...)` so the allocator owns its block. Every subsequent subsystem `*_initialize` sizes its state with the two-call pattern, then carves that many bytes out of the systems allocator.

## Design decisions & rationale

- **Two ownership modes** — `memory = 0` allocates internally; passing an external block makes the allocator a pure cursor over someone else's memory. The texture system uses the *first* mode implicitly (the systems allocator carves it). The systems allocator itself uses the first mode in `application.c:72`.
- **Reset-only, never per-element free** — perfect fit for "allocate at startup, live for the program's life". Gets all the subsystem state into one cache-friendly contiguous block.
- **No alignment** — `allocate(size)` returns the next byte. Subsystems that need alignment get it because their states are mostly cache-line-friendly structs starting at fresh offsets; nothing in the engine requests over-alignment yet.
- **Introduced together with the new init pattern** — `0a3992b` adds the linear allocator alongside the Vulkan-style two-call subsystem init. The two are designed to work together.

## Known limitations

- Out-of-memory returns `NULL` but most callers (`application.c`) don't null-check before using the pointer. A 64 MiB exhaustion would crash on first dereference.
- No alignment.
- `linear_allocator_allocate` does `(void*)memory + allocated` which relies on GNU C void-pointer arithmetic — fine on Clang.
- No "release back to here" marker support; can't temporarily push a frame allocation.

## Related docs

- [`core/application.md`](../core/application.md) — creates and feeds the systems allocator.
- [`core/memory-subsystem.md`](../core/memory-subsystem.md) — `hallocate` underneath.
- [`testing/unit-tests.md`](../testing/unit-tests.md) — covered by `linear_allocator_tests.c`.

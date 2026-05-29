# Memory Subsystem

## Purpose

Single funnel for engine heap allocations, with per-purpose accounting via `memory_tag`. Wraps `platform_allocate` so the OS-specific allocator stays behind the platform layer, and produces a human-readable usage report (`get_memory_usage_str`).

## Files

- `engine/src/core/hmemory.h` / `hmemory.c`.

## Public API

- `enum memory_tag` — UNKNOWN, ARRAY, LINEAR_ALLOCATOR, DARRAY, DICT, RING_QUEUE, BST, STRING, APPLICATION, JOB, TEXTURE, MATERIAL_INSTANCE, RENDERER, GAME, TRANSFORM, ENTITY, ENTITY_NODE, SCENE.
- `void memory_system_initialize(u64* memory_requirement, void* state)`, `void memory_system_shutdown(void* state)`.
- `void* hallocate(u64 size, memory_tag tag)`.
- `void hfree(void* block, u64 size, memory_tag tag)` — caller passes the original size.
- `void* hzero_memory(void*, u64)`, `hcopy_memory(...)`, `hset_memory(...)` — thin wrappers over `platform_*_memory`.
- `char* get_memory_usage_str()` — newly-allocated string, freed by caller.
- `u64 get_memory_alloc_count()` — total `hallocate` calls since init.

All marked `HAPI` so the game can use them.

## How it works

Internal state is tiny: `total_allocated` plus `tagged_allocations[MEMORY_TAG_MAX_TAGS]` and a running `alloc_count`. `hallocate` calls `platform_allocate(size, false)`, zeros the block, and adjusts the totals. `hfree` symmetrically subtracts.

`get_memory_usage_str` walks the per-tag array and prints best-fit units (B/KiB/MiB/GiB) into a 8000-byte stack buffer, then returns a `string_duplicate` of it. The testbed reports it once per init via `application.c:159`.

`hzero_memory` and friends route to platform helpers (`platform_zero_memory`, etc.) — there is currently no fast-path implementation; they call `memset`/`memcpy` underneath.

## Design decisions & rationale

- **Tags, not allocators** — `memory_tag` is for *attribution*, not pool selection. All allocations come from the same `platform_allocate`. The point is to be able to say "the texture system is holding 12 MiB" at runtime without pulling in a profiler.
- **Caller passes the size to `hfree`** — avoids per-allocation header bookkeeping. The price is that mismatched sizes silently corrupt totals; in practice every freer already knows the size (most users hold a struct or have a `darray` header to consult).
- **Initialised early, after events** — `application.c:83` runs the size query, allocates from the systems allocator, then runs the real init. Allocations happening *before* `memory_system_initialize` (e.g. the `application_state` itself, the systems allocator's own backing memory) bypass tracking — `state_ptr` is NULL so the conditionals at `hmemory.c:65,83` short-circuit. This is intentional: it lets the early stages bootstrap without circular dependencies, at the cost of a small under-count.
- **No alignment** — `hallocate` is `// TODO: Memory alignment` (`hmemory.c:71`). For Vulkan staging buffers and uniform layouts the renderer relies on Vulkan-side alignment requirements, not on `hallocate` providing it.
- **`MEMORY_TAG_UNKNOWN` warns** — using it triggers `HWARN`. Prods callers to classify allocations rather than letting the unknown bucket grow.

## Known limitations

- Tracking is a single global; no per-thread counters and no allocation timestamps.
- `get_memory_usage_str` allocates `MEMORY_TAG_STRING` itself, so calling it changes the very totals it reports.
- No leak detector — `memory_system_shutdown` simply nulls `state_ptr`. If `total_allocated > 0` at shutdown, no warning is emitted.
- Imports `<string.h>` and `<stdio.h>` directly (note: `// TODO: Custom string library.`); a future move to fully custom strings would touch this file too.

## Related docs

- [`platform/platform-layer.md`](../platform/platform-layer.md) — `platform_allocate` etc.
- [`memory/linear-allocator.md`](../memory/linear-allocator.md) — sub-allocator carved out of one `hallocate`.

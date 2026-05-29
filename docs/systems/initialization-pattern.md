# Subsystem Initialization Pattern

## Purpose

Standard handshake for bringing every subsystem up. Each subsystem's `*_initialize` is called twice: once with `state == 0` to report the size of its internal state, then again with a caller-allocated block of that size. This decouples the subsystem from any allocator and lets the application place all subsystem state in one contiguous, lifetime-bounded block.

## Files

This is a convention, not a module — it lives in every `*_initialize` signature. The pattern is enforced in:

- `engine/src/core/application.c:75-136` — the orchestrator.
- `engine/src/memory/linear_allocator.h` / `.c` — backing allocator.
- `engine/src/core/logger.h:33`, `event.h:29`, `hmemory.h:29`, `input.h:152`, `platform/platform.h:5`, `renderer/renderer_frontend.h:5`, `systems/texture_system.h:11`.

## The pattern

```c
// 1) size query: state = NULL
u64 size;
subsystem_initialize(&size, NULL);

// 2) carve memory from the systems linear allocator
void* state = linear_allocator_allocate(&app_state->systems_allocator, size);

// 3) actually initialize, given backing memory
subsystem_initialize(&size, state);
```

Inside the subsystem:

```c
b8 subsystem_initialize(u64* memory_requirement, void* state) {
    *memory_requirement = sizeof(subsystem_state);
    if (state == NULL) {
        return true;            // size-query mode
    }
    state_ptr = state;          // file-static pointer to subsystem state
    // ... normal init ...
    return true;
}
```

`state_ptr` is a `static` in each subsystem's translation unit; only one instance of each subsystem can exist per process.

## Subsystems using this pattern

Initialised in this order in `application_create`:

1. `event_system` — must come first because input depends on it.
2. `memory_system` — note: `event_system` already allocated through it via `darray`, but `memory_system_initialize` only sets up the *tracker*; allocations work without it (untracked).
3. `logging` — needs filesystem (which needs no init) and platform_console_write (raw stdio; works pre-platform_init).
4. `input_system`.
5. (Engine event handlers registered here.)
6. `platform_system` — creates the window.
7. `renderer_system` — needs the window for surface creation.
8. `texture_system` — needs the renderer for `create_texture`.

## Design decisions & rationale

- **Mirrors Vulkan idioms** — Vulkan's "call to query size, call to fill" is the same handshake (`vkEnumerateInstanceLayerProperties`, etc.). The engine adopts it deliberately so subsystems feel familiar to anyone who knows Vulkan (`0a3992b`).
- **Decouples allocator from subsystem** — subsystems don't call `hallocate` for their state; whoever drives them passes memory in. Lets the application use a linear allocator for all of them and never face fragmentation.
- **Pre-init memory ordering** — events comes before memory because event_system uses `hallocate` indirectly (via `darray`) but tracking is optional; the size-query path doesn't allocate. Logger third because it depends on filesystem (stateless wrapper) and the platform console functions, both of which work without their owners being initialised. This ordering was settled in `ed7a8a3` (Refactor Part 3) when every existing subsystem was migrated.
- **State pointer is module-static** — one subsystem instance per process. Trades flexibility (no two renderers, no per-thread events) for simplicity.
- **Shutdown takes the state pointer** — symmetric with the second init call. The application keeps the pointer alongside the size in `application_state`.

## Known limitations

- No "would init" check — calling `*_initialize(&size, NULL)` twice is fine, but calling the real init twice is undefined behaviour in most subsystems (overwrites `state_ptr`, leaks owned resources).
- Subsystem init failures don't roll back prior subsystems — `application_create` returns false but `application_run` is not called, so the allocator block is leaked at process exit.
- Subsystems that allocate via `hallocate` *during* their init (e.g. logger creates a file handle, event creates darrays) place those allocations outside the systems allocator, so the systems-allocator size doesn't reflect total footprint.

## Related docs

- [`memory/linear-allocator.md`](../memory/linear-allocator.md) — the allocator on the other end.
- [`core/application.md`](../core/application.md) — orchestrator.
- Every subsystem doc.

# Hefest Engine — Documentation

Hefest is a custom game engine written in C using the Vulkan graphics API. It is built incrementally as a learning project, layer by layer, with the engine compiled as a shared library (`engine.dll` / `libengine.so`) and consumed by an executable (`testbed`) that defines the game side via a `game` struct of function pointers.

This `docs/` folder is the curated, audit-oriented companion to the source. Where the source tells you *what*, these docs try to tell you *why* — what each subsystem is for, how it is shaped, and which design decisions deserve a second look. Each subsystem doc cites the commits where its decisions show up so you can re-read the diffs in context.

## Read in this order

1. [`ARCHITECTURE.md`](ARCHITECTURE.md) — layering, frame lifecycle, init pattern, big picture.
2. [`TIMELINE.md`](TIMELINE.md) — chronological build of the engine, commit by commit.
3. [`BUILD.md`](BUILD.md) — Makefiles, build scripts, shader compilation, Windows vs Linux.
4. Core systems: [logging](core/logging-and-asserts.md) → [application](core/application.md) → [memory](core/memory-subsystem.md) → [events](core/event-system.md) → [input](core/input-system.md) → [clock](core/clock.md) → [strings](core/string-library.md).
5. Data structures & math: [darray](containers/darray.md), [hashtable](containers/hashtable.md), [linear allocator](memory/linear-allocator.md), [math library](math/math-library.md).
6. Platform: [platform layer](platform/platform-layer.md), [filesystem](platform/filesystem.md).
7. Renderer: [frontend/backend split](renderer/frontend-backend-split.md) → [vulkan-backend](renderer/vulkan-backend.md) → device → swapchain → renderpass → framebuffer & sync → command buffers → pipeline → buffers → images → shaders.
8. Resources & systems: [texture system](resources/texture-system.md), [initialization pattern](systems/initialization-pattern.md).
9. Test infrastructure & game side: [unit tests](testing/unit-tests.md), [testbed](testbed/testbed.md).

## Status snapshot

- Last committed milestone: `15fbee3` — texture system & hashtable wired in.
- Working-tree edits in `engine/src/core/hstring.c/h` are uncommitted; see [string library](core/string-library.md) for the open issues this introduces.
- The renderer can present a textured quad with a free-flying camera; assets are loaded from `assets/textures/` via `stb_image`.
- A small unit-test target (`tests/`) covers `linear_allocator` and `hashtable` only.

## Conventions used in these docs

- File paths are repo-relative (e.g. `engine/src/core/event.c`).
- Commit hashes are the short form from `git log` and resolve via `git show <hash>`.
- Each subsystem doc follows the same template (Purpose / Files / Public API / How it works / Design decisions & rationale / Known limitations / Related docs) so they can be skimmed side-by-side during an audit.

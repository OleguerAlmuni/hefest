# Architecture Overview

## Layering

```
+-------------------------------------------------------------+
| testbed/  (executable)                                      |
|   - create_game(), game_state, camera + input glue          |
+----------------------------|--------------------------------+
                             | engine public API (HAPI)
+----------------------------v--------------------------------+
| engine.dll / libengine.so                                   |
|                                                             |
|  entry.h  --> application_create / application_run          |
|                                                             |
|  Subsystems (each owns its own state, two-call init):       |
|    logger  events  memory  input  texture_system            |
|    clock   strings           ^                              |
|                              |                              |
|  Renderer frontend  --[fn ptrs]-->  Renderer backend        |
|                                       (Vulkan today)        |
|                                                             |
|  Platform abstraction (platform.h)                          |
+----------------------------|--------------------------------+
                             | OS / Vulkan loader
+----------------------------v--------------------------------+
| Win32 (HWND, WM_*)   |   Linux/XCB+X11   |   Vulkan driver  |
+-------------------------------------------------------------+
```

The engine is a shared library. The user (game side) lives in `testbed/` and links against `engine.lib` / `libengine.so`. The user must implement `b8 create_game(game* out_game)`; `entry.h` provides `main()` and calls `application_create` then `application_run` (`engine/src/entry.h`).

## Frame lifecycle

`application_run` (`engine/src/core/application.c:150`) drives the loop:

1. `platform_pump_messages()` — drains OS events, which call back into the input system, which fires events.
2. `clock_update()` — produces `delta_time`.
3. `game->update(delta)` — testbed updates camera state, then calls `renderer_set_view(view)`.
4. `game->render(delta)` — currently a no-op; the engine drives drawing.
5. `renderer_draw_frame(packet)`:
   - `renderer_begin_frame` → `vulkan_renderer_backend_begin_frame` (acquire image, wait fences, begin renderpass).
   - `update_global_state(projection, view, ...)` — writes the global UBO.
   - `update_object(geometry_render_data)` — binds material shader, writes per-object descriptor, binds vertex/index buffer, `vkCmdDrawIndexed`.
   - `renderer_end_frame` → submit + present.
6. `input_update(delta)` — copies current keyboard/mouse state to "previous" so `input_was_*` works next frame.

## Subsystem initialization pattern

Almost every subsystem uses the **two-call sizing pattern** introduced in `0a3992b` (Refactor Part 2):

```c
u64 size;
subsystem_initialize(&size, 0);          // first call: report required state size
void* mem = linear_allocator_allocate(&app->systems_allocator, size);
subsystem_initialize(&size, mem);        // second call: actually initialize, given backing memory
```

`application_create` (`engine/src/core/application.c:71`) creates a 64 MiB linear allocator and carves all subsystem state out of it. This puts the engine in control of where subsystem state lives (one big block, never fragmented), mirrors how the Vulkan loader queries sizes, and removes the need for a heap-allocator dependency inside subsystems.

Subsystems using this pattern: `event_system`, `memory_system`, `logger`, `input_system`, `platform_system`, `renderer_system`, `texture_system`. See [systems/initialization-pattern.md](systems/initialization-pattern.md).

## Memory ownership

Two layers:

- **`hmemory`** (`engine/src/core/hmemory.c`) wraps `platform_allocate` and tracks per-tag totals via `MEMORY_TAG_*`. All engine allocations go through `hallocate(size, tag)`.
- **`linear_allocator`** (`engine/src/memory/linear_allocator.c`) bump-allocates inside an existing block. Subsystem state is sub-allocated from the application's 64 MiB systems allocator and never freed individually — the whole block is reclaimed at shutdown.

`hmemory` does *not* track per-allocation metadata, only running totals; freeing requires the caller to pass back the size. There is no allocator hook into `platform_allocate` for alignment or NUMA — both flagged as `// TODO: Memory alignment.` in `hmemory.c:71/88`.

## Renderer frontend / backend split

`renderer_frontend.c` (`engine/src/renderer/renderer_frontend.c`) holds API-agnostic state (projection, view, the test diffuse texture pointer) and calls into a `renderer_backend` struct of function pointers. `renderer_backend_create` (`engine/src/renderer/renderer_backend.c:5`) populates that struct based on a `renderer_backend_type` — today only `RENDERER_BACKEND_TYPE_VULKAN` is implemented. This is the seam where OpenGL or DirectX backends would slot in without touching the frontend or game code.

The frontend currently has small leakages worth knowing about:
- `renderer_set_view(mat4)` is exported as `HAPI` so `testbed/game.c:134` can push the camera matrix in. Marked `// HACK` in the header.
- A debug texture-swap event handler lives directly in the frontend (`event_on_debug_event`), wired to `EVENT_CODE_DEBUG0` for testing the texture system.

See [renderer/frontend-backend-split.md](renderer/frontend-backend-split.md) and the per-Vulkan docs.

## Asset pipeline (current)

```
assets/textures/<name>.png
  └──> filesystem_open / fopen
        └──> stb_image (vendored)
              └──> texture_system_acquire(name) -> texture* (ref-counted, hashtable<name,ref>)
                    └──> renderer_create_texture
                          └──> vulkan_renderer_create_texture
                                ├── staging buffer
                                ├── vulkan_image (DEVICE_LOCAL)
                                ├── layout transition + buffer→image copy
                                └── VkSampler
                                      └── bound via vulkan_material_shader's per-object descriptor set
```

Shaders are GLSL → SPIR-V via `glslc` in `post-build.bat` / `post-build.sh`, output to `bin/assets/shaders/`. The runtime loads `Builtin.MaterialShader.{vert,frag}.spv`.

## Static state

The engine uses module-static state pointers (`static <subsystem>_state* state_ptr;`) that get assigned during the second `*_initialize` call. This means every subsystem has exactly one instance per process — fine for a single-game engine, deliberately not designed for re-entrant use.

## Type and platform conventions

- Fixed-width types `u8/u16/u32/u64`, `i8/.../i64`, `f32/f64`, `b8/b32`. Static-asserted in `engine/src/defines.h`.
- Platform detection compiles in only one of `HPLATFORM_WINDOWS` / `HPLATFORM_LINUX` etc. Each platform `.c` is wrapped in `#if HPLATFORM_*` so the build can include all platform sources unconditionally.
- `HAPI` is `__declspec(dllexport)` when building the engine (`-DHEXPORT`) and `dllimport` when consuming it (`-DHIMPORT`). On non-MSVC it falls back to `__attribute__((visibility("default")))`.

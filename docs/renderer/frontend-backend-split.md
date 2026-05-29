# Renderer Frontend / Backend Split

## Purpose

Decouple the engine's concept of "draw a frame" from any specific graphics API. The frontend owns API-agnostic state (projection, view, the active scene's bookkeeping); the backend is a struct of function pointers populated for whichever API the build supports — currently only Vulkan.

## Files

- `engine/src/renderer/renderer_types.inl` — `renderer_backend_type`, `global_uniform_object`, `object_uniform_object`, `geometry_render_data`, `renderer_backend` (the function-pointer table), `render_packet`.
- `engine/src/renderer/renderer_frontend.h` / `renderer_frontend.c` — public engine API for the renderer.
- `engine/src/renderer/renderer_backend.h` / `renderer_backend.c` — dispatcher that wires a `renderer_backend` to a specific implementation.

## Public API

- `b8 renderer_system_initialize(memory_requirement, state, application_name)`, `void renderer_system_shutdown(state)`.
- `void renderer_on_resized(width, height)`.
- `b8 renderer_draw_frame(render_packet*)`.
- `void renderer_set_view(mat4)` — `HAPI`, currently called by testbed (marked HACK).
- `void renderer_create_texture(name, w, h, channels, pixels, has_transparency, out_texture)` / `renderer_destroy_texture(texture*)` — used by the texture system.

`renderer_backend` holds: `frame_number`, `initialize`, `shutdown`, `resized`, `begin_frame`, `update_global_state`, `end_frame`, `update_object`, `create_texture`, `destroy_texture`.

## How it works

`renderer_system_initialize` (`renderer_frontend.c:59`) calls `renderer_backend_create(RENDERER_BACKEND_TYPE_VULKAN, &state.backend)`, which assigns the Vulkan implementations to each function pointer (`renderer_backend.c:7-15`). The frontend then calls `state.backend.initialize`. After init it sets up a default perspective matrix for 1280×720 / 45° / 0.1–1000 and a starting view.

`renderer_draw_frame` (`renderer_frontend.c:124`) is the per-frame entry point:

1. `renderer_begin_frame` → `state.backend.begin_frame`.
2. `state.backend.update_global_state(projection, view, ...)` — pushes the global UBO for the frame.
3. Build a single `geometry_render_data` (one fake object today) with the diffuse texture (acquired through the texture system or default if unset).
4. `state.backend.update_object(data)` — binds the material shader, writes the per-object descriptor + push constants, draws indexed.
5. `renderer_end_frame` → `state.backend.end_frame`, increments `frame_number`.

`renderer_on_resized` rebuilds the projection at the new aspect ratio and notifies the backend.

## Design decisions & rationale

- **Function-pointer table over a v-table interface** — plain C, no `void*` self argument; the backend holds its own state internally (`vulkan_backend.c:30` has a static `vulkan_context`), so the function pointers don't need it threaded through. Trade-off: there can only ever be one active backend instance.
- **`render_packet` is the seam for future scene data** — today it carries only `delta_time` (`renderer_types.inl:60`). Marked `// TODO: Refactor packet creation` in `application.c:186`. Whatever scene/material/object lists the engine eventually needs will land here.
- **Frontend knows about textures, projection, view** — these are universal across APIs, so they live in the API-agnostic layer. Anything API-specific (descriptors, command buffers, fences) stays in the backend.
- **`renderer_set_view` exposed as `HAPI`** — explicitly marked HACK (`renderer_frontend.h:13`). The testbed wants to drive the camera; the proper fix is for the game to write a higher-level state and the renderer to read it from the packet, but the seam isn't there yet.
- **One debug texture-swap event handler in the frontend** — `event_on_debug_event` (`renderer_frontend.c:35`) toggles between two assets on `EVENT_CODE_DEBUG0`. Convenient for testing the texture system; should leave when production-grade texture management arrives.
- **Projection clip is hard-coded** — 0.1f near, 1000.0f far, 45° FOV (`renderer_frontend.c:79-81`). Fine for now.

## Known limitations

- Single backend at a time, baked at compile time. `renderer_backend_type::OPENGL/DIRECTX` are enumerated but unimplemented (`renderer_backend.c` only handles `VULKAN`).
- Frontend cannot describe more than one drawable per frame — the call to `update_object` in `renderer_draw_frame` is a single hardcoded entry.
- Per-frame allocation: `data.textures[16]` is 16 pointers but only `data.textures[0]` is used.

## Related docs

- [`renderer/vulkan-backend.md`](vulkan-backend.md) — the only backend in the table.
- [`resources/texture-system.md`](../resources/texture-system.md) — owner of the textures the frontend hands to the backend.

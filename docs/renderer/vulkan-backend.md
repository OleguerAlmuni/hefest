# Vulkan Backend

## Purpose

The Vulkan implementation of the renderer backend. Owns the `VkInstance`, the device, the swapchain, the main renderpass, the per-frame command buffers and synchronization, and the single `vulkan_material_shader`. Brings everything up in `vulkan_renderer_backend_initialize` and tears it down in reverse.

## Files

- `engine/src/renderer/vulkan/vulkan_backend.h` / `vulkan_backend.c` — top-level orchestration.
- `engine/src/renderer/vulkan/vulkan_types.inl` — every Vulkan-specific struct: `vulkan_buffer`, `vulkan_device`, `vulkan_image`, `vulkan_renderpass`, `vulkan_framebuffer`, `vulkan_swapchain`, `vulkan_command_buffer`, `vulkan_fence`, `vulkan_pipeline`, `vulkan_material_shader`, `vulkan_context` (the holistic state).

## Public API

Only the function pointers wired into `renderer_backend`:

- `vulkan_renderer_backend_initialize/shutdown`
- `vulkan_renderer_backend_on_resized`
- `vulkan_renderer_backend_begin_frame/end_frame`
- `vulkan_renderer_update_global_state(projection, view, view_position, ambient, mode)`
- `vulkan_backend_update_object(geometry_render_data)`
- `vulkan_renderer_create_texture/destroy_texture`

## How it works

State lives in a single file-static `vulkan_context context;` (`vulkan_backend.c:30`). Initialization order:

1. Cache the framebuffer size from `application_get_framebuffer_size` (defaults to 800×600 if zero).
2. Build a list of required instance extensions: generic surface + per-platform surface (`platform_get_required_extension_names`) + `VK_EXT_debug_utils` in debug builds.
3. Validation layers (`VK_LAYER_KHRONOS_validation`) only in `_DEBUG`, with availability check.
4. Create the instance, debug messenger, surface (`platform_create_vulkan_surface`).
5. `vulkan_device_create` — physical device pick + queues + command pool + depth format detection.
6. `vulkan_swapchain_create`, `vulkan_renderpass_create` (one main renderpass at `(0,0,w,h)`, clear colour `(0, 0, 0.2, 1)`, depth 1.0).
7. `regenerate_framebuffers` — one framebuffer per swapchain image, two attachments (colour view + depth view).
8. `create_command_buffers` — one primary command buffer per swapchain image.
9. Sync objects: `image_available_semaphores` (per in-flight frame), `queue_complete_semaphores` (per swapchain image), `in_flight_fences` (per in-flight frame), and an `images_in_flight` array of fence pointers (per swapchain image, initialised to NULL).
10. `vulkan_material_shader_create` — built-in shader.
11. `create_buffers` — one giant device-local vertex buffer and one device-local index buffer (each `1 MiB * sizeof(...)`).
12. Temporary test code: upload a 4-vertex / 6-index quad and `vulkan_material_shader_acquire_resources` for object id 0.

`begin_frame`:

- Boot out if the swapchain is being recreated or if a resize is pending → call `recreate_swapchain` and return false (frontend skips the frame).
- Wait on the in-flight fence for the current logical frame slot.
- Acquire the next image; the per-frame `image_available_semaphore` signals when ready.
- If the acquired image is already in flight from a prior frame, wait on its fence.
- Reset the current frame's fence and the command buffer; begin recording.
- Set viewport (flipped Y by giving negative height — Vulkan-convention NDC trick) and scissor.
- Begin the main renderpass against the framebuffer at `image_index`.

`update_global_state` binds the material shader and writes the global UBO via `vulkan_material_shader_update_global_state`.

`update_object` writes per-object descriptor state, binds the same vertex buffer (offset 0) and index buffer, and `vkCmdDrawIndexed(6, 1, 0, 0, 0)` — the hardcoded quad.

`end_frame` ends the renderpass, ends the command buffer, submits with `wait = image_available[current_frame]`, `signal = queue_complete[image_index]`, and the in-flight fence as the submission fence; then `vulkan_swapchain_present`.

`on_resized` does *not* recreate the swapchain immediately — it bumps `framebuffer_size_generation`. The next `begin_frame` notices the mismatch with `framebuffer_size_last_generation` and runs `recreate_swapchain`.

`recreate_swapchain` waits idle, requeries swapchain support, recreates swapchain + framebuffers + command buffers + per-image semaphores, resets `images_in_flight` to NULL.

## Design decisions & rationale

- **Single-context, file-static state** — clean and simple, but precludes multiple Vulkan instances (e.g. for tools). Acceptable for a game engine.
- **Two semaphore arrays of different sizes** — `image_available` is per in-flight frame, `queue_complete` is per swapchain image. This avoids the "wrong-frame-signals-wrong-image" hazard when MAX_FRAMES_IN_FLIGHT and image count differ. The pattern (with `images_in_flight` mapping image → fence) is the standard layered Vulkan synchronization model.
- **Generation counter for resize, not immediate teardown** — `on_resized` is called from a wndproc that may run mid-frame; deferring the actual swapchain recreate to `begin_frame` avoids tearing into resources that the GPU is still using. `c74df37` introduced this; bug fixes for swapchain went into `0a3992b`.
- **Vertex/index buffers sized 1Mi×stride at startup** — temporary "big enough" allocation for the quad. Will need a real allocator for arbitrary geometry.
- **Negative-height viewport** — `(viewport.y = h, viewport.height = -h)` flips Y to match a top-left-origin convention without a separate matrix. Requires `VK_KHR_maintenance1` or Vulkan 1.1+, available everywhere now.
- **Validation layers off in non-debug builds** — `_DEBUG` gates layer enabling and the debug messenger. Production builds get zero validation overhead.
- **`VK_API_VERSION_1_4`** — set on the application info; effectively a "minimum Vulkan" hint. Requires a 1.4-capable loader.

## Known limitations

- One material shader, one quad. Geometry is hardcoded test data (`vulkan_backend.c:241-272`).
- `images_in_flight` resets to NULL pointers in `recreate_swapchain` but the underlying `in_flight_fences` array is preserved — correct, but easy to miss.
- `vulkan_renderer_backend_shutdown` calls `vkDeviceWaitIdle` *twice* (`:287` and `:299`), the second being defensive.
- Initial framebuffer-size fallback is 800×600 when `application_get_framebuffer_size` reports zero. The actual window is 1280×720 from `testbed/src/entry.c:14`. The first frame after resize fixes it.
- No HDR, no MSAA, no compute, no secondary command buffers, no multiple subpasses.
- The temporary vertex upload in init uses a `0` fence (`vulkan_backend.c:271`) which is a NULL-fence single-use copy — works but leaves no synchronisation handle for the caller.

## Related docs

Specific subsystems:

- [`vulkan-device.md`](vulkan-device.md), [`vulkan-swapchain.md`](vulkan-swapchain.md), [`vulkan-renderpass.md`](vulkan-renderpass.md)
- [`vulkan-framebuffer-and-sync.md`](vulkan-framebuffer-and-sync.md), [`vulkan-command-buffers.md`](vulkan-command-buffers.md)
- [`vulkan-pipeline.md`](vulkan-pipeline.md), [`vulkan-buffers.md`](vulkan-buffers.md), [`vulkan-images.md`](vulkan-images.md)
- [`vulkan-shaders.md`](vulkan-shaders.md)

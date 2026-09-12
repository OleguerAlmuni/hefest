# Build Timeline

Chronological story of the engine, with commit hashes for `git show <hash>` reference.

## 1. Foundations

- `80f7776` — first commit, empty scaffolding.
- `d4a5c2e` — **Logging and assertions.** `logger.c/h` with `HFATAL..HTRACE`, `asserts.h` with `HASSERT*`. From here on every subsystem reports through this.
- `bcf6207` — **Win32 platform layer.** `platform_win32.c` registers a window class, runs `WM_*` pump, wires console output. Logger updated to take per-platform colour codes.
- `984b00b` — **Application layer + entry point relocation.** `main()` moves into the engine library (`engine/src/entry.h`); the user defines `create_game()` and a `game` struct. `application_create` / `application_run` introduced.
- `381c91c` — **Memory subsystem.** `hmemory.c/h`, `MEMORY_TAG_*`, allocation totals per tag.

## 2. Core systems

- `ebaf91d` — **Event system + dynamic arrays.** `event.c/h` (1024-deep listener table indexed by event code), `darray.c/h` with the header-prefix layout used everywhere else.
- `1312407` — **Input system base.** `input.c/h`, current vs previous keyboard/mouse state, `input_process_*` entry points called by the platform layer.
- `ff7fe9e` — **Win32 input handling.** `WM_KEY*` / mouse messages mapped to `keys` / `buttons` and pushed into the input system, which fires events.

## 3. Renderer bring-up

- `9eeba7c` — **Renderer frontend & backend skeleton, custom string library, custom clock, Vulkan init started.** `renderer_frontend.c`, `renderer_backend.c` dispatch, `clock.c`, `hstring.c`. The frontend/backend seam is established here.
- `4e36d92` — **Vulkan platform middle-layer + physical device selection.** `vulkan_platform.h` per-OS surface creation; device selection scores GPUs and picks queue families.
- `169a1d1` — **Logical device + queue retrieval.** `vulkan_device.c`, graphics/present/transfer queues, command pool.
- `cf0f038` — **Swapchain.** `vulkan_swapchain.c`, format/present-mode selection, depth attachment, framebuffer slots.
- `21fb1af` — **Renderpass.** `vulkan_renderpass.c`, single colour + depth attachment with clear values.
- `dd710f3` — **Command buffers and pool.** `vulkan_command_buffer.c`, single-use helpers for transfers.
- `bf941cc` — **Framebuffer & sync objects.** `vulkan_framebuffer.c`, `vulkan_fence.c`, semaphores for image-available / queue-complete.
- `c74df37` — **Cleared the screen end-to-end.** All Vulkan elements wired into `application_run`; resize logic added (`framebuffer_size_generation` counter, `recreate_swapchain`).

## 4. Math + build cleanup

- `a486adc` — Build process updates; math library started.
- `40e70bb` — **Math library complete.** `hfst_math.h/c` with vec2/3/4, mat4, quaternion (slerp included), perspective/ortho/look-at, Euler→matrix, axis-angle.

## 5. Refactor pass

- `a3a0bce` — **Refactor Part 1.** Reworks `darray` and switches engine boolean handling.
- `0a3992b` — **Refactor Part 2.** Adds the `tests/` project (`linear_allocator`, `hashtable` later) and `expect.h` macros; introduces `linear_allocator`; adopts the **Vulkan-style two-call init** pattern; fixes left/right alt/ctrl/shift collapsing into the same key code; fixes a swapchain bug; adds `get_memory_alloc_count` for per-frame allocation diagnostics.
- `ed7a8a3` — **Refactor Part 3.** Migrates every existing subsystem to the new init/shutdown pattern. After this, `application_create` is a sequence of `*_initialize(&size, 0)` → carve memory → `*_initialize(&size, mem)` calls.

## 6. Drawing pipeline

- `9ed48a5` — **Filesystem + shader modules.** `filesystem.c/h` (fopen-based), `vulkan_shader_utils.c` to load SPIR-V from disk.
- `f3dec9d` — **Graphics pipeline.** `vulkan_pipeline.c`, configurable wireframe, vertex input description, dynamic viewport/scissor.
- `bc84638` — **Vulkan buffers for the object shader.** `vulkan_buffer.c`, staging-buffer-based uploads (host-visible → DEVICE_LOCAL via copy command).
- `f1e9a1d` — **Temporary quad geometry** uploaded directly in `vulkan_renderer_backend_initialize` and drawn with `vkCmdDrawIndexed(6, ...)`.
- `37a6314` — **Uniforms + descriptors.** Global UBO (projection, view) and a global descriptor set per in-flight frame; `vulkan_object_shader_*` (later renamed) created here.
- `c859db3` — **Push constants + model matrix.** Per-draw model matrix delivered via push constants instead of per-object UBO writes.
- `ad1dabf` — **Temporary camera movement** in the testbed: WASD/QE/space/X for translation, arrows / A-D for yaw/pitch, `mat4_inverse` of camera transform pushed into the renderer via `renderer_set_view`.

## 7. Textures

- `c97f06b` — **Texture loading implementation** (in-memory pixels → GPU image + sampler).
- `fdf1f7e` — **Descriptors, images and samplers wired into the shader.** Per-object descriptor set gains a combined image sampler binding; default texture introduced (256×256 procedural checkerboard generated in code so the renderer can run with no assets).
- `8f0f881` — **Texture from disk: started.** `stb_image` vendored; first call path reading PNGs.
- `e7527ed` — **Texture from disk: finished.** `texture_system_acquire` ↔ `load_texture` ↔ `renderer_create_texture` end-to-end.
- `d1ce0fe` — **Rename `vulkan_object_shader` → `vulkan_material_shader`** to match its actual role (a shader plus its material descriptor set, not a per-object resource).
- `7d2d12b` — **Linux support.** `platform_linux.c` (XCB + X11 + xkbcommon), `Makefile.*.linux.mak`, `build-all.sh`, `post-build.sh`. Vulkan surface creation switches on platform.
- `15fbee3` — **Texture system + hashtable.** `texture_system.c` adds reference-counted lookup by name; `hashtable.c/h` introduced as the lookup container. `auto_release` controls whether refcount → 0 frees the GPU resource.

- `317f497` — **VLA removal and Linux fixes.** Every variable-length array replaced with a fixed bound or a heap allocation; `-Werror=vla` added to the engine makefile so they cannot come back.
- `a0f9a24` — **Non-discrete GPU support.** Physical-device selection falls back to an integrated GPU when no discrete one is present; every per-swapchain-image array sized from `swapchain.image_count` (bounded by `VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT`) instead of a hardcoded 3; per-image render-finished semaphores; sampler anisotropy clamped to the device limit.

## 8. Materials

- **Material system.** `material_system.c/h` adds reference-counted, name-keyed materials loaded from `.hmt` files in `assets/materials/`. A material bundles a diffuse colour with its texture maps, so the renderer binds one material per draw instead of loose textures. `geometry_render_data` now carries a `material*` rather than an object id and a texture array; `object_uniform_object` becomes `material_uniform_object`; the Vulkan material shader keys its instance descriptor sets off `material->internal_id` and picks samplers by declared `texture_use` instead of array position. See [systems/material-system.md](systems/material-system.md).
- **Geometry system.** `geometry_system.c/h` makes vertex and index data a reference-counted resource paired with a material, replacing the single quad that used to be uploaded inside `vulkan_renderer_backend_initialize`. The renderer backend gains `create_geometry`/`destroy_geometry`/`draw_geometry`, `render_packet` carries a list of geometries for the frame, and the material shader's `update_object` splits into `set_model` (push constant) and `apply_material` (descriptor set) so one material can serve many draws. Also fixes `upload_data_range`, which wrote into the staging buffer at the destination's offset — harmless while every caller passed zero, out of bounds once geometry uploads pass real offsets. See [systems/geometry-system.md](systems/geometry-system.md).
- **Resource system and loaders.** `resource_system.c/h` plus `resources/loaders/` (`text`, `binary`, `image`, `material`) give every asset type one entry point, `resource_system_load(name, type, &resource)`, dispatched to a registered loader. Each loader owns a `type_path` subdirectory and builds `<base>/<type_path>/<name><ext>`, so callers stop knowing where assets live. `stb_image` moves out of `texture_system.c` into `image_loader.c`, the `.hmt` parser moves out of `material_system.c` into `material_loader.c`, and `vulkan_shader_utils.c` reads SPIR-V through the binary loader. `filesystem_read_all_bytes` now fills a caller-supplied buffer instead of allocating one, with `filesystem_size` and `filesystem_read_all_text` added alongside. Base path is `assets`, since `post-build.sh` copies the tree into `bin/` and `run.sh` runs from there. See [systems/resource-system.md](systems/resource-system.md).

## 9. Multiple renderpasses

- **Support for multiple renderpasses.** The renderer moves from one renderpass to two: a world pass that clears colour and depth, and a UI pass that clears nothing and presents. `vulkan_renderpass` gains clear flags plus `has_prev_pass`/`has_next_pass`, which drive attachment load ops and image layout transitions so the two passes hand the same swapchain image between them. `begin_renderpass`/`end_renderpass` join the backend interface and the frontend drives both passes per frame. A second builtin shader, `vulkan_ui_shader`, draws `vertex_2d` geometry under an orthographic projection with depth testing disabled; the graphics pipeline gains a vertex stride parameter and a depth-test toggle to support it. The `vulkan_fence` and `vulkan_framebuffer` wrappers are removed in favour of raw handles created inline, as upstream does — but every per-swapchain-image array stays bounded by `VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT` rather than the hardcoded 3 and 2 the series uses. See [renderer/vulkan-renderpass.md](renderer/vulkan-renderpass.md) and [renderer/vulkan-sync.md](renderer/vulkan-sync.md).

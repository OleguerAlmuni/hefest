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

## Currently uncommitted

`engine/src/core/hstring.{h,c}` has working-tree edits adding a swath of `string_to_*` parsers and vector parsers. Several call into `kzero_memory` and `strings_equali`, which don't exist — see [core/string-library.md](core/string-library.md) "Known limitations".

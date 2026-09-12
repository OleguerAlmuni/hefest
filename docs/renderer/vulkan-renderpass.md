# Vulkan Renderpass

## Purpose

Creates and runs the engine's renderpasses. There are two: a **world** pass that clears colour
and depth and draws the scene, and a **UI** pass that clears nothing and draws on top of the
world pass's output before presenting.

Both render into the same swapchain image. The world pass leaves it in
`COLOR_ATTACHMENT_OPTIMAL`; the UI pass takes it from there and transitions it to
`PRESENT_SRC_KHR`. That handoff is what `has_prev_pass` / `has_next_pass` encode.

## Files

- `engine/src/renderer/vulkan/vulkan_renderpass.h` / `vulkan_renderpass.c`.
- `vulkan_renderpass` struct in `vulkan_types.inl`.
- `context.main_renderpass` (world) and `context.ui_renderpass` in `vulkan_backend.c`.

## Public API

- `vulkan_renderpass_create(context, out_renderpass, render_area, clear_color, depth, stencil, clear_flags, has_prev_pass, has_next_pass)`
- `vulkan_renderpass_destroy(context, renderpass)`
- `vulkan_renderpass_begin(command_buffer, renderpass, framebuffer)`
- `vulkan_renderpass_end(command_buffer, renderpass)`

`clear_flags` is a bitmask of `renderpass_clear_flag`:

| Flag | Value |
|---|---|
| `RENDERPASS_CLEAR_NONE_FLAG` | `0x0` |
| `RENDERPASS_CLEAR_COLOR_BUFFER_FLAG` | `0x1` |
| `RENDERPASS_CLEAR_DEPTH_BUFFER_FLAG` | `0x2` |
| `RENDERPASS_CLEAR_STENCIL_BUFFER_FLAG` | `0x4` |

The struct exposes `render_area` and `clear_color` as `vec4`s (the area is
`(x, y, width, height)`), plus `depth`, `stencil`, the clear flags, the two adjacency flags, and
a `vulkan_render_pass_state` enum that is tracked but not strictly enforced.

The two built-in passes are selected by `builtin_renderpass` id
(`BUILTIN_RENDERPASS_WORLD`, `BUILTIN_RENDERPASS_UI`) through
`renderer_backend.begin_renderpass` / `end_renderpass`, which the renderer frontend drives once
per pass per frame.

## How it works

The clear flags drive both attachment setup and the begin-time clear values, so a pass that
clears nothing costs no clear values and loads instead:

- A set `COLOR_BUFFER` flag makes the colour attachment `LOAD_OP_CLEAR`; unset makes it
  `LOAD_OP_LOAD`, which is how the UI pass preserves what the world pass drew.
- A set `DEPTH_BUFFER` flag adds the depth attachment at all. The UI pass has no depth
  attachment and its pipeline is created with depth testing disabled.
- `initialLayout` is `COLOR_ATTACHMENT_OPTIMAL` when `has_prev_pass`, else `UNDEFINED`.
  `finalLayout` is `COLOR_ATTACHMENT_OPTIMAL` when `has_next_pass`, else `PRESENT_SRC_KHR`.

`attachmentCount` is counted as attachments are appended rather than fixed at two, since the UI
pass has only one.

## How it works

`create` builds a `VkRenderPassCreateInfo` with one colour attachment (using the swapchain's image format, `LOAD_OP_CLEAR`, `STORE_OP_STORE`, final layout `PRESENT_SRC_KHR`) and one depth-stencil attachment (using `device.depth_format`, also clear-and-store, final layout `DEPTH_STENCIL_ATTACHMENT_OPTIMAL`). One subpass references both attachments and one subpass dependency synchronizes against `EARLY_FRAGMENT_TESTS_BIT | COLOR_ATTACHMENT_OUTPUT_BIT`.

`begin` builds a `VkRenderPassBeginInfo` and fills the clear values array only for the buffers the flags say to clear, leaving `pClearValues` null when there are none. It then calls `vkCmdBeginRenderPass(VK_SUBPASS_CONTENTS_INLINE)`, transitions the command buffer state to `IN_RENDER_PASS`, and updates the renderpass state to match.

`end` calls `vkCmdEndRenderPass` and resets state.

## Design decisions & rationale

- **One renderpass for everything** — everything renders to the same colour+depth target and presents directly. Adequate for the current scope; multi-pass rendering (post-processing, shadows) will need additional renderpasses.
- **Final layout `PRESENT_SRC_KHR`** — the renderpass itself transitions the colour attachment for presentation, removing the need for a separate barrier before `vkQueuePresentKHR`.
- **Clear values stored on the struct** — the backend writes them at create time and never changes them; mutating these requires a full renderpass recreate, which is fine since the values aren't dynamic.
- **Two state enums for the same lifecycle** — `vulkan_render_pass_state` and `vulkan_command_buffer_state` mirror each other (`vulkan_types.inl:63` and `:104`). The redundancy lets either side validate independently; in practice neither is asserted on.

## Known limitations

- Single subpass; no input attachments, no MSAA.
- Hardcoded subpass dependency configuration; subpass changes would require touching both `create` and the dependency.
- The state enum is informational only — it's set but never asserted.
- The clear values are stored as separate floats `(r, g, b, a)` rather than a `vec4`; consistent with the function signature but an awkward seam.

## Related docs

- [`vulkan-backend.md`](vulkan-backend.md) — owner of `main_renderpass`.
- [`vulkan-sync.md`](vulkan-sync.md) — framebuffers, fences and semaphores.

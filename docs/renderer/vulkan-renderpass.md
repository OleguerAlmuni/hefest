# Vulkan Renderpass

## Purpose

Creates and runs a single colour-plus-depth renderpass with explicit clear values, area, and stencil. The engine has exactly one renderpass today (`context.main_renderpass`) shared by every framebuffer.

## Files

- `engine/src/renderer/vulkan/vulkan_renderpass.h` / `vulkan_renderpass.c`.
- `vulkan_renderpass` struct in `vulkan_types.inl:72`.

## Public API

- `vulkan_renderpass_create(context, out_renderpass, x, y, w, h, r, g, b, a, depth, stencil)`.
- `vulkan_renderpass_destroy(context, renderpass)`.
- `vulkan_renderpass_begin(command_buffer, renderpass, framebuffer)`.
- `vulkan_renderpass_end(command_buffer, renderpass)`.

The struct exposes the area `(x, y, w, h)`, clear colour `(r, g, b, a)`, `depth`, `stencil`, and a `vulkan_render_pass_state` enum (`READY`, `RECORDING`, `IN_RENDER_PASS`, `RECORDING_ENDED`, `SUBMITTED`, `NOT_ALLOCATED`) that's tracked but not strictly enforced.

## How it works

`create` builds a `VkRenderPassCreateInfo` with one colour attachment (using the swapchain's image format, `LOAD_OP_CLEAR`, `STORE_OP_STORE`, final layout `PRESENT_SRC_KHR`) and one depth-stencil attachment (using `device.depth_format`, also clear-and-store, final layout `DEPTH_STENCIL_ATTACHMENT_OPTIMAL`). One subpass references both attachments and one subpass dependency synchronizes against `EARLY_FRAGMENT_TESTS_BIT | COLOR_ATTACHMENT_OUTPUT_BIT`.

`begin` builds a `VkRenderPassBeginInfo`, fills the two-element clear values array (clear colour + depth/stencil), calls `vkCmdBeginRenderPass(VK_SUBPASS_CONTENTS_INLINE)`, transitions the command buffer state to `IN_RENDER_PASS`, and updates the renderpass state to match.

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
- [`vulkan-framebuffer-and-sync.md`](vulkan-framebuffer-and-sync.md) — framebuffers reference this renderpass.

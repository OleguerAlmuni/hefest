# Vulkan Framebuffer & Sync

## Purpose

Two related responsibilities glued together because they share a lifecycle: framebuffers (the bridge between renderpass attachments and image views) and fences (the GPU↔CPU synchronization primitive). Semaphores live on the `vulkan_context` directly and are described here for completeness.

## Files

- `engine/src/renderer/vulkan/vulkan_framebuffer.h` / `vulkan_framebuffer.c`.
- `engine/src/renderer/vulkan/vulkan_fence.h` / `vulkan_fence.c`.
- Structs: `vulkan_framebuffer` (`vulkan_types.inl:83`), `vulkan_fence` (`:120`).

## Public API

Framebuffer:

- `vulkan_framebuffer_create(context, renderpass, w, h, attachment_count, attachments[], out_framebuffer)`.
- `vulkan_framebuffer_destroy(context, framebuffer)`.

Fence:

- `vulkan_fence_create(context, create_signaled, out_fence)`.
- `vulkan_fence_destroy(context, fence)`.
- `b8 vulkan_fence_wait(context, fence, timeout_ns)`.
- `vulkan_fence_reset(context, fence)`.

## How it works

`vulkan_framebuffer_create` copies the attachment array into heap memory owned by the framebuffer struct (so the caller's array can go out of scope), holds a pointer back to its renderpass, and `vkCreateFramebuffer`s. The backend's `regenerate_framebuffers` (`vulkan_backend.c:649`) creates one per swapchain image with two attachments: the swapchain's colour view and the swapchain's depth attachment view.

`vulkan_fence` wraps a `VkFence` with an `is_signaled` bool. `wait` calls `vkWaitForFences(1, &handle, true, timeout)` and updates the bool on success. `reset` calls `vkResetFences` and clears the flag.

Semaphores aren't wrapped in a struct — `image_available_semaphores` and `queue_complete_semaphores` are darrays of raw `VkSemaphore` (`vulkan_context`).

## Design decisions & rationale

- **Two semaphore arrays of different lengths** (covered in [`vulkan-backend.md`](vulkan-backend.md)) — `image_available` is sized to `max_frames_in_flight`, `queue_complete` is sized to `image_count`. This avoids the wrong-frame-signals-wrong-image bug when those numbers differ.
- **`is_signaled` shadow on `vulkan_fence`** — lets `wait` early-out if the fence was already known signaled. Important for the in-flight-fence pattern in `begin_frame` where the fence is created with `create_signaled = true` so the first frame doesn't wait on a never-signaled fence.
- **Framebuffer owns its attachment-list copy** — frees on destroy. Means the backend can build attachment arrays on the stack and pass them in.
- **Fence/semaphore creation kept thin** — the orchestration (which fence belongs to which frame, which semaphore to which submit) lives in `vulkan_backend.c`. The wrappers don't try to encode that.

## Known limitations

- `vulkan_fence` `is_signaled` is updated by `wait` and `reset` but the fence can also become signaled passively (via a submission that completes); the bool can lag the real state. `wait` always re-queries the underlying fence so this is informational only.
- No semaphore wrapper. Adding one would centralise creation/destruction (currently scattered through `vulkan_backend.c` and `recreate_swapchain`).
- Framebuffer destroy frees the attachments array via the engine memory functions, but creates with `MEMORY_TAG_RENDERER` — confirm tag consistency on extension.

## Related docs

- [`vulkan-backend.md`](vulkan-backend.md) — orchestrates fences and semaphores per frame.
- [`vulkan-renderpass.md`](vulkan-renderpass.md) — framebuffers reference one of these.
- [`vulkan-swapchain.md`](vulkan-swapchain.md) — owns the framebuffer array.

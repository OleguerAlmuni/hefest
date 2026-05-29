# Vulkan Swapchain

## Purpose

Owns the present-target images, their views, the depth attachment, the per-image framebuffers (set up by the backend but stored here), and image acquisition / present.

## Files

- `engine/src/renderer/vulkan/vulkan_swapchain.h` / `vulkan_swapchain.c`.
- `vulkan_swapchain` struct in `vulkan_types.inl:90`.
- `vulkan_swapchain_support_info` struct in `vulkan_types.inl:25`.

## Public API

- `vulkan_swapchain_create(context, w, h, out_swapchain)`.
- `vulkan_swapchain_recreate(context, w, h, swapchain)`.
- `vulkan_swapchain_destroy(context, swapchain)`.
- `b8 vulkan_swapchain_acquire_next_image_index(context, swapchain, timeout, sem, fence, out_image_index)`.
- `void vulkan_swapchain_present(context, swapchain, gfx_queue, present_queue, render_complete_sem, image_index)`.

The struct exposes: `image_format`, `max_frames_in_flight`, `handle`, `image_count`, `images`, `views`, `depth_attachment` (a `vulkan_image`), `framebuffers` (a darray populated by the backend).

## How it works

`create` chooses an SRGB BGRA8 format if available (else first format), `MAILBOX` present mode if available (else `FIFO`), an extent clamped to `surfaceCapabilities` min/max, and `image_count = min_image_count + 1` clamped to `max_image_count`. `max_frames_in_flight = 2` (double-buffered logical frames regardless of swapchain length). It creates the depth attachment (one `vulkan_image` whose format comes from `device.depth_format`).

`acquire_next_image_index` calls `vkAcquireNextImageKHR`. On `VK_ERROR_OUT_OF_DATE_KHR` it triggers swapchain recreation through the backend (the function returns `false` so the caller skips the frame).

`present` builds a `VkPresentInfoKHR` and calls `vkQueuePresentKHR`. On out-of-date / suboptimal it bumps `framebuffer_size_generation` to force recreate next frame.

`recreate` is `destroy` then `create`, plus repopulating the framebuffers via the backend's `regenerate_framebuffers`.

## Design decisions & rationale

- **MAILBOX preferred** — lower latency than FIFO when triple-buffering is available; falls back gracefully.
- **`max_frames_in_flight = 2`** — a logical concept independent of `image_count`. Lets the engine pipeline two CPU frames ahead while the GPU works on one. The semaphore arrays are sized accordingly (acquire) or per swapchain image (present).
- **Depth attachment owned by the swapchain** — recreated together with the colour images on resize, since they must match dimensions.
- **`framebuffers` darray on the swapchain** — the backend allocates and fills this; it lives on the swapchain because its lifetime is the swapchain's. Recreating the swapchain destroys and rebuilds it.
- **Framebuffer-size generation lives on the context** — when `present` returns suboptimal, bumping the counter rather than recreating immediately defers the work to the start of the next frame, where everything else is set up to handle it.

## Known limitations

- No HDR or wide-gamut format selection.
- No support for changing `max_frames_in_flight` at runtime.
- Format fallback is "first available" — could pick a non-SRGB format that produces incorrect colour output. Practically every GPU exposes BGRA8 SRGB.

## Related docs

- [`vulkan-backend.md`](vulkan-backend.md) — drives `acquire`/`present` per frame, owns framebuffers.
- [`vulkan-images.md`](vulkan-images.md) — depth attachment uses `vulkan_image`.

# Vulkan Command Buffers

## Purpose

Allocate, record, reset and free `VkCommandBuffer`s. Adds a "single-use" helper pair that allocates a transient command buffer, lets the caller record into it, then submits and waits — used for one-shot transfers like staging-buffer copies and image layout transitions.

## Files

- `engine/src/renderer/vulkan/vulkan_command_buffer.h` / `vulkan_command_buffer.c`.
- `vulkan_command_buffer` struct in `vulkan_types.inl:113`, with `vulkan_command_buffer_state` enum at `:104`.

## Public API

- `vulkan_command_buffer_allocate(context, pool, is_primary, out_cb)`.
- `vulkan_command_buffer_free(context, pool, cb)`.
- `vulkan_command_buffer_begin(cb, is_single_use, is_renderpass_continue, is_simultaneous_use)` — flags map to `VkCommandBufferUsageFlags`.
- `vulkan_command_buffer_end(cb)`.
- `vulkan_command_buffer_reset(cb)` — flips state back to `READY`.
- `vulkan_command_buffer_update_submitted(cb)` — flips state to `SUBMITTED`.
- `vulkan_command_buffer_allocate_and_begin_single_use(context, pool, out_cb)`.
- `vulkan_command_buffer_end_single_use(context, pool, cb, queue)` — ends, submits, waits, frees.

## How it works

The struct stores a `VkCommandBuffer handle` and a state enum. `_allocate` calls `vkAllocateCommandBuffers` and transitions to `READY`. `_begin` builds a `VkCommandBufferBeginInfo` with flags translated from the three booleans and calls `vkBeginCommandBuffer`, transitioning to `RECORDING`.

`single_use` is the canonical Vulkan idiom for transient operations:

```c
vulkan_command_buffer_allocate_and_begin_single_use(...);  // allocate + begin with ONE_TIME_SUBMIT
// record commands (buffer copies, image transitions)
vulkan_command_buffer_end_single_use(...);                 // end, submit, vkQueueWaitIdle, free
```

The backend uses these for vertex/index uploads (`vulkan_backend.c:271`) and for texture creation (`vulkan_backend.c:856`).

## Design decisions & rationale

- **State enum tracks the lifecycle** — `READY → RECORDING → IN_RENDER_PASS → RECORDING_ENDED → SUBMITTED → READY` (after reset). Useful for debugging; not asserted on.
- **Single-use helpers as a pair** — keeps the caller's code linear instead of repeating the begin/end/submit/wait dance everywhere. Trade: each transfer waits the queue idle, which serialises uploads. Fine at startup; would need batching for runtime streaming.
- **`is_renderpass_continue` and `is_simultaneous_use` exposed but always false** — the existing call sites pass `false, false, false`. Kept in the API for future secondary command buffers.
- **Per-image command buffers** — the backend's `graphics_command_buffers` darray is `image_count`-sized, so each frame's recording happens against a buffer that's always tied to the same swapchain image. Together with `images_in_flight`, this guarantees no buffer is recorded into while it's still in use.

## Known limitations

- `vkQueueWaitIdle` inside `end_single_use` serialises every transient transfer. Acceptable for setup; bottleneck for runtime.
- No allocate-from-pool reuse: every single-use call allocates a new buffer.
- The state enum is informational; mismatched usage doesn't fault.

## Related docs

- [`vulkan-backend.md`](vulkan-backend.md) — owns the per-image command buffers.
- [`vulkan-buffers.md`](vulkan-buffers.md) — uses single-use buffers for staging copies.
- [`vulkan-images.md`](vulkan-images.md) — uses single-use buffers for layout transitions.

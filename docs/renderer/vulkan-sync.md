# Vulkan Synchronization

## Purpose

The fences and semaphores that keep CPU and GPU from stepping on each other, and the
framebuffers that bind renderpass attachments to swapchain image views.

Both used to have wrapper types. The multiple-renderpass work removed them: framebuffers are
created inline in the backend (two sets of them now, one per renderpass), and fences are raw
`VkFence` handles. What remains here is the sizing and ordering, which is where the real
complexity lives.

## Files

- `engine/src/renderer/vulkan/vulkan_backend.c` — `regenerate_framebuffers`, and all fence and
  semaphore creation, waiting and destruction.
- `engine/src/renderer/vulkan/vulkan_types.inl` — the `vulkan_context` sync fields.

## Framebuffers

`regenerate_framebuffers()` creates **two** framebuffers per swapchain image:

- `context.world_framebuffers[i]` — for `main_renderpass`, with two attachments: the swapchain
  colour view and the shared depth attachment view.
- `context.swapchain.framebuffers[i]` — for `ui_renderpass`, with one attachment: the swapchain
  colour view only. The UI pass has no depth buffer.

Both target the same swapchain image. The world pass leaves it in
`COLOR_ATTACHMENT_OPTIMAL`, the UI pass picks it up from there and transitions it to
`PRESENT_SRC_KHR`. See [vulkan-renderpass](vulkan-renderpass.md).

They are destroyed and recreated together on swapchain recreation.

## Fences and semaphores

| Object | Count | Indexed by |
|---|---|---|
| `image_available_semaphores` (darray) | `max_frames_in_flight` | `current_frame` |
| `queue_complete_semaphores` (darray) | `image_count` | `image_index` |
| `in_flight_fences` | `max_frames_in_flight` | `current_frame` |
| `images_in_flight` (borrowed pointers) | `image_count` | `image_index` |

The render-finished semaphores being **per swapchain image** rather than per frame-in-flight is
a deliberate divergence from the series. When `image_count != max_frames_in_flight` — which is
the normal case on an integrated GPU — signalling a per-frame semaphore while a previous
presentation still waits on it trips
`VUID-vkQueuePresentKHR-pWaitSemaphores` and can hang. They are destroyed and recreated on
swapchain recreation, since the image count can change.

The fixed-size arrays are bounded by `VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT` (8), asserted against
the driver-reported count in `vulkan_swapchain.c`. Kohi sizes these `[3]` and `[2]`, which is a
silent out-of-bounds write on any driver that hands back more images. On the development machine
`minImageCount` is 3 with no maximum, so the count is a driver decision, not a constant.

### Ordering

The wait-and-reset sequence lives in `vulkan_renderer_backend_begin_frame`, immediately after
image acquisition:

1. Wait on `in_flight_fences[current_frame]` — the previous use of this frame slot is done.
2. Acquire the next image index.
3. If `images_in_flight[image_index]` is set, wait on it too — another frame may still be using
   this particular image.
4. Point `images_in_flight[image_index]` at this frame's fence.
5. Reset that fence, so the upcoming submission can signal it.

Kohi does steps 3–5 in `end_frame`, after the command buffer has already been recorded. Doing
them before recording is the correct order: it is what guarantees the command buffer being
reset and re-recorded is not still in flight.

## Known limitations

- `free_data_range` in the backend is a stub, so nothing reclaims vertex/index buffer ranges.
- `VULKAN_MAX_SWAPCHAIN_IMAGE_COUNT` is a compile-time bound; a driver reporting more than 8
  swapchain images would trip the assert rather than adapting.

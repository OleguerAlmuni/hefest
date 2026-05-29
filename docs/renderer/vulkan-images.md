# Vulkan Images

## Purpose

Wraps `VkImage` + `VkDeviceMemory` + optional `VkImageView`. Provides layout transitions and buffer-to-image copies. Used for the swapchain depth attachment and for every texture uploaded by `vulkan_renderer_create_texture`.

## Files

- `engine/src/renderer/vulkan/vulkan_image.h` / `vulkan_image.c`.
- `vulkan_image` struct in `vulkan_types.inl:55`.

## Public API

- `vulkan_image_create(context, image_type, w, h, format, tiling, usage, memory_flags, create_view, view_aspect_flags, out_image)`.
- `vulkan_image_view_create(context, format, image, aspect_flags)` — separately, if `create_view` was false at create time.
- `vulkan_image_transition_layout(context, command_buffer, image, format, old_layout, new_layout)`.
- `vulkan_image_copy_from_buffer(context, image, buffer_handle, command_buffer)`.
- `vulkan_image_destroy(context, image)`.

## How it works

`create` calls `vkCreateImage`, queries memory requirements, allocates device memory, binds, and (if requested) creates a view via `vulkan_image_view_create` with the supplied aspect flags. `destroy` tears down view → memory → image in that order.

`transition_layout` builds an `VkImageMemoryBarrier` with src/dst access and stage masks chosen from the old/new layout pair (`UNDEFINED → TRANSFER_DST_OPTIMAL`, `TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL`). Anything else logs and returns; only the two transitions used by texture upload are encoded.

`copy_from_buffer` records a `vkCmdCopyBufferToImage` for the entire image extent (single mip, single array layer) into the supplied command buffer (typically a single-use one). The caller owns the command buffer's lifecycle.

The texture creation path in `vulkan_backend.c:vulkan_renderer_create_texture` is the canonical user:

```c
staging = vulkan_buffer_create(HOST_VISIBLE | HOST_COHERENT)
vulkan_buffer_load_data(staging, pixels)
vulkan_image_create(2D, RGBA8_UNORM, OPTIMAL, ..., DEVICE_LOCAL, view=true, COLOR_BIT, &image)
single-use command buffer:
  transition UNDEFINED → TRANSFER_DST_OPTIMAL
  copy_from_buffer(staging.handle)
  transition TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL
end+submit+wait
vulkan_buffer_destroy(staging)
vkCreateSampler(...)
```

## Design decisions & rationale

- **Two layout pairs only** — the function fast-exits on unsupported transitions (`fdf1f7e`). All current consumers stick to `UNDEFINED → TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL`. Adding more pairs (e.g. for read-back or compute) means extending this function.
- **Image owns its view** — they're 1:1 in the engine's usage. If a future renderer needs multiple views of the same image, the view will need to come out.
- **Mip / array layer = 1** — both `create` and `copy_from_buffer` assume single mip and single layer. Reasonable for the current 2D textures and depth attachment; mip generation is not implemented.
- **Aspect flags chosen at create time** — colour vs depth-stencil. Lets the same code path produce both.

## Known limitations

- No mip-mapping. `vulkan_renderer_create_texture` uses `mipLodBias = 0`, `minLod = maxLod = 0` (`vulkan_backend.c:901`).
- No multi-layer arrays / cubemaps.
- Layout transitions hardcode `srcQueueFamilyIndex = dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED` — fine since transfers happen on the graphics queue.
- `vulkan_image_view_create` writes into `image->view` directly; calling it twice without destroying the prior view leaks.
- `internal_data` for textures is a `vulkan_texture_data { vulkan_image image; VkSampler sampler; }` allocated separately in `MEMORY_TAG_TEXTURE`.

## Related docs

- [`resources/texture-system.md`](../resources/texture-system.md) — feeds CPU pixels here.
- [`vulkan-shaders.md`](vulkan-shaders.md) — combined image-sampler descriptors reference these.
- [`vulkan-buffers.md`](vulkan-buffers.md) — staging buffers for upload.

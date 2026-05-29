# Vulkan Buffers

## Purpose

`VkBuffer` + backing `VkDeviceMemory` wrapped together. Supports the staging-buffer pattern (host-visible upload → device-local destination via `vkCmdCopyBuffer`) and a `lock/unlock` pair for direct mapping. Used for vertex, index, uniform, and staging buffers.

## Files

- `engine/src/renderer/vulkan/vulkan_buffer.h` / `vulkan_buffer.c`.
- `vulkan_buffer` struct in `vulkan_types.inl:15`.

## Public API

- `b8 vulkan_buffer_create(context, size, usage, memory_property_flags, bind_on_create, out_buffer)`.
- `vulkan_buffer_destroy(context, buffer)`.
- `vulkan_bufer_resize(context, new_size, buffer, queue, pool)` — note the typo `bufer`.
- `vulkan_buffer_bind(context, buffer, offset)`.
- `void* vulkan_buffer_lock_memory(context, buffer, offset, size, flags)`, `vulkan_buffer_unlock_memory(context, buffer)`.
- `vulkan_buffer_load_data(context, buffer, offset, size, flags, data)` — short helper that maps, copies, unmaps.
- `vulkan_buffer_copy_to(context, pool, fence, queue, src_handle, src_offset, dst_handle, dst_offset, size)` — single-use command buffer with `vkCmdCopyBuffer`.

The struct exposes: `total_size`, `handle`, `usage`, `is_locked`, `memory`, `memory_index`, `memory_property_flags`.

## How it works

`create` calls `vkCreateBuffer`, queries `vkGetBufferMemoryRequirements`, picks a memory type via `context.find_memory_index(type_filter, property_flags)` (`vulkan_backend.c:608`), allocates `VkDeviceMemory`, and optionally `vkBindBufferMemory`s. Memory property flags drive whether the buffer is `HOST_VISIBLE | HOST_COHERENT` (staging, uniforms) or `DEVICE_LOCAL` (vertex, index, the device-side uniform).

`load_data` is the one-shot helper for host-visible buffers: `vkMapMemory` → `memcpy` → `vkUnmapMemory`. Used by staging buffers and by per-object uniforms.

`copy_to` is the staging idiom: allocate-and-begin a single-use command buffer, `vkCmdCopyBuffer`, end-and-submit-and-wait, free.

The end-to-end upload flow (`vulkan_backend.c:upload_data_range`):

```c
vulkan_buffer_create(staging, HOST_VISIBLE | HOST_COHERENT)
vulkan_buffer_load_data(staging, ...)               // map+copy
vulkan_buffer_copy_to(staging.handle -> dest.handle) // single-use cmd, wait queue idle
vulkan_buffer_destroy(staging)
```

## Design decisions & rationale

- **Memory and buffer in one struct** — Vulkan separates them but the engine has no use for that flexibility. Bundling makes lifetime obvious.
- **`bind_on_create` flag** — lets callers create-then-bind in two steps (e.g. allocating from a custom suballocator); today every call passes `true`.
- **Single-use copy submission inside `copy_to`** — same trade as elsewhere: simple, but each transfer waits queue idle. The backend's startup quad upload pays this cost twice.
- **Memory property flags retained on the struct** — not used today, but kept so future barrier insertion can decide whether host-coherent flushes are needed.

## Known limitations

- `vulkan_bufer_resize` typo in the function name. Internally rebuilds and copies; called from nowhere today.
- Each staging upload allocates a fresh staging buffer; no staging arena.
- `lock_memory`'s `flags` and `size` parameters allow partial maps but the helper `load_data` always passes 0 / full size.
- `is_locked` flag is set by lock and cleared by unlock but never validated.
- No alignment annotations on the buffer struct; the renderer relies on Vulkan-side requirements alone.

## Related docs

- [`vulkan-images.md`](vulkan-images.md) — image creation uses the same `find_memory_index`.
- [`vulkan-shaders.md`](vulkan-shaders.md) — global and per-object uniform buffers live here.
- [`vulkan-command-buffers.md`](vulkan-command-buffers.md) — `copy_to` uses single-use buffers.

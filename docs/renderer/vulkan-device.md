# Vulkan Device

## Purpose

Selects a `VkPhysicalDevice` based on swapchain/queue requirements, creates the `VkDevice`, retrieves graphics/present/transfer queues and a graphics command pool, and detects a usable depth format.

## Files

- `engine/src/renderer/vulkan/vulkan_device.h` / `vulkan_device.c`.
- `vulkan_device` struct in `vulkan_types.inl:33`.

## Public API

- `b8 vulkan_device_create(vulkan_context*)` — picks GPU, creates device, queues, command pool, populates `context->device`.
- `void vulkan_device_destroy(vulkan_context*)`.
- `void vulkan_device_query_swapchain_support(physical, surface, out_support_info)`.
- `b8 vulkan_device_detect_depth_format(vulkan_device*)`.

The struct exposes:

```c
VkPhysicalDevice physical_device;
VkDevice logical_device;
vulkan_swapchain_support_info swapchain_support;   // capabilities, formats, present_modes (darrays)
i32 graphics_queue_index, present_queue_index, transfer_queue_index;
VkQueue graphics_queue, present_queue, transfer_queue;
VkCommandPool graphics_command_pool;
VkPhysicalDeviceProperties properties;
VkPhysicalDeviceFeatures features;
VkPhysicalDeviceMemoryProperties memory;
VkFormat depth_format;
```

## How it works

Selection iterates `vkEnumeratePhysicalDevices`, queries swapchain support against the surface, and accepts the first GPU that satisfies a fixed requirements set: discrete preferred, graphics + present + transfer queues found, sampler anisotropy, and at least one swapchain format and present mode. It then creates a `VkDevice` enabling those queue families (with `VK_QUEUE_FAMILY_IGNORED`-aware deduplication), retrieves the queues, and creates a graphics-family command pool with `VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT`.

`detect_depth_format` walks `VK_FORMAT_D32_SFLOAT`, `VK_FORMAT_D32_SFLOAT_S8_UINT`, `VK_FORMAT_D24_UNORM_S8_UINT` and returns the first one with `VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT` in optimal tiling.

`query_swapchain_support` writes into a `vulkan_swapchain_support_info` whose `formats` and `present_modes` arrays are darrays — they're freed in device destruction.

## Design decisions & rationale

- **Three potentially-distinct queue families** — graphics, present, transfer. The backend creates explicit transfer ops on the graphics queue today (since `transfer_queue_index` typically maps to graphics), but the structure is in place for a true async-transfer queue.
- **Anisotropy required** — the texture sampler in `vulkan_renderer_create_texture` enables 16x anisotropy unconditionally (`vulkan_backend.c:894`). The device pick guarantees it's available.
- **Single graphics command pool** — `VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT` so individual command buffers can be reset (used per swapchain image). No transient pool yet.
- **Depth format selection at device-create time** — bound to the device, not the renderpass. Lets the renderpass and swapchain depth attachment use the same format without re-querying.

## Known limitations

- First-acceptable-device selection — no scoring across multiple discrete GPUs.
- Queue family detection treats graphics/present/transfer as required; integrated GPUs that don't expose a separate transfer family will pick graphics for both, which is fine.
- No `VK_KHR_portability_subset` handling for MoltenVK / Apple platforms (none supported anyway).

## Related docs

- [`vulkan-backend.md`](vulkan-backend.md) — owner of the `vulkan_device`.
- [`vulkan-swapchain.md`](vulkan-swapchain.md) — consumer of `swapchain_support`.

# Geometry System

## Purpose

Owns the vertex and index data the renderer draws. Before this system the engine had a
single hardcoded quad uploaded inside `vulkan_renderer_backend_initialize`; now geometry is
a first-class, reference-counted resource that pairs vertex/index buffers with a material.

A `geometry` is what a draw call operates on: upload it once, then submit it any number of
times per frame with different model matrices.

## Files

- `engine/src/resources/resource_types.h` — the `geometry` struct and `GEOMETRY_NAME_MAX_LENGTH`.
- `engine/src/systems/geometry_system.h` / `geometry_system.c`.
- `engine/src/renderer/vulkan/vulkan_backend.c` — `vulkan_renderer_create_geometry`,
  `destroy_geometry`, `draw_geometry`.
- `engine/src/renderer/vulkan/vulkan_types.inl` — `vulkan_geometry_data`,
  `VULKAN_MAX_GEOMETRY_COUNT`.

## Public API

- `struct geometry_system_config { u32 max_geometry_count; }` — `application.c` passes 4096.
- `struct geometry_config { u32 vertex_size; u32 vertex_count; void* vertices; u32 index_size; u32 index_count; void* indices; char name[]; char material_name[]; }`
- `b8 geometry_system_initialize(memory_requirement, state, config)`
- `void geometry_system_shutdown(state)`
- `geometry* geometry_system_acquire_by_id(u32 id)`
- `geometry* geometry_system_acquire_from_config(geometry_config config, b8 auto_release)`
- `void geometry_system_release(geometry* geometry)`
- `geometry* geometry_system_get_default()`
- `geometry* geometry_system_get_default_2d()`
- `geometry_config geometry_system_generate_plane_config(width, height, x_segments, y_segments, tile_x, tile_y, name, material_name)`
- `#define DEFAULT_GEOMETRY_NAME "default"`

## How it works

State is two contiguous blocks from the systems linear allocator, per the
[two-call init pattern](initialization-pattern.md): the `geometry_system_state` struct, then
a flat `geometry_reference[max_geometry_count]` array. Unlike the texture and material
systems there is **no hashtable** — geometry is looked up by index, not by name, because
nothing acquires geometry by name yet.

`geometry_reference` holds `{ reference_count, geometry, auto_release }`. Note the geometry
is stored **by value** inside the reference, where the material system stores materials in a
separate array and the reference holds a handle.

`acquire_from_config` linearly scans for a slot whose `geometry.id == INVALID_ID`, claims it,
sets `reference_count = 1`, and calls `create_geometry`, which:

1. Hands the vertex/index data to `renderer_create_geometry` for GPU upload. On failure the
   slot is rolled back to `INVALID_ID`.
2. Acquires the named material through the material system, falling back to the default
   material if the named one cannot be loaded.

`geometry_system_release` decrements and, at zero with `auto_release`, calls
`destroy_geometry`, which frees the GPU range, empties the name, and releases the material
reference.

Two default geometries are built in code so the renderer always has something valid to draw:
a 10×10 `vertex_3d` quad and a `vertex_2d` one for the UI pass.

## GPU side

`vulkan_geometry_data` records where a geometry lives inside the two shared buffers
(`object_vertex_buffer`, `object_index_buffer`): offset, count and size for both vertices and
indices. Uploads are bump-allocated — `context.geometry_vertex_offset` and
`geometry_index_offset` only ever advance.

`vulkan_renderer_create_geometry` handles re-upload: if `internal_id` is already valid it
keeps a copy of the old range, writes the new data, then frees the old range afterwards so
the geometry is never in an unusable state mid-swap.

`vulkan_renderer_draw_geometry` binds the vertex buffer at the geometry's offset, applies the
material, and issues `vkCmdDrawIndexed` — or `vkCmdDraw` when the geometry has no indices.

The material shader's old `vulkan_material_shader_update_object` is split in two here:
`set_model` pushes the model matrix as a push constant, and `apply_material` updates and
binds the material's descriptor set. Splitting them lets one material serve many draws
without re-uploading its UBO per object.

## A fix that this episode forced

`upload_data_range` used to write into the staging buffer at the *destination's* offset and
pass memory-property flags where `VkMemoryMapFlags` were expected:

```c
vulkan_buffer_load_data(context, &staging, offset, size, flags, data);  // wrong
vulkan_buffer_load_data(context, &staging, 0, size, 0, data);           // right
```

The staging buffer is created fresh at exactly `size` bytes each call, so data always belongs
at offset 0. This was harmless while the only caller was the temp quad passing `offset = 0`.
Geometry uploads pass real offsets, which would have written past the end of the staging
allocation.

## Known limitations

- `free_data_range` is a stub. Vertex and index buffer space is never reclaimed, so repeated
  uploads leak GPU buffer range until the buffers are exhausted.
- `VULKAN_MAX_GEOMETRY_COUNT` is a fixed 4096 with a `TODO` to make it dynamic, and it is
  independent of `geometry_system_config.max_geometry_count` — the two can disagree.
- `geometry_config.vertices` / `.indices` are heap-allocated by
  `geometry_system_generate_plane_config` and must be freed by the caller. The header says as
  much and calls itself "not production code".
- `geometry_config` carries `vertex_size`/`index_size` and untyped `void*` buffers, so the
  vertex format is a runtime value rather than a type. That is what lets the same system feed
  both the 3D world pass and the 2D UI pass, at the cost of the compiler no longer checking it.

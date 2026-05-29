# Vulkan Graphics Pipeline

## Purpose

Builds a `VkPipeline` from the inputs that vary per shader (vertex attributes, descriptor set layouts, shader stages, viewport/scissor, wireframe). Wraps it together with its layout in a `vulkan_pipeline` for binding.

## Files

- `engine/src/renderer/vulkan/vulkan_pipeline.h` / `vulkan_pipeline.c`.
- `vulkan_pipeline` struct in `vulkan_types.inl:131`.

## Public API

- `b8 vulkan_graphics_pipeline_create(context, renderpass, attribute_count, attributes, descriptor_set_layout_count, descriptor_set_layouts, stage_count, stages, viewport, scissor, is_wireframe, out_pipeline)`.
- `vulkan_pipeline_destroy(context, pipeline)`.
- `vulkan_pipeline_bind(command_buffer, bind_point, pipeline)`.

## How it works

`create` populates the standard set of `VkPipeline*StateCreateInfo` structs:

- Viewport / scissor as supplied (single each).
- Rasterizer: `is_wireframe ? VK_POLYGON_MODE_LINE : VK_POLYGON_MODE_FILL`, back-face culling, counter-clockwise front (matches the negative-Y viewport flip used by the backend).
- Multisampling: 1 sample, no super-sampling.
- Depth/stencil: depth test + write enabled, `LESS_OR_EQUAL` compare, no stencil.
- Color blend: a single attachment with `SRC_ALPHA / ONE_MINUS_SRC_ALPHA` blending and write mask `RGBA`.
- Dynamic state: `VIEWPORT`, `SCISSOR`, `LINE_WIDTH` — re-set every frame in `begin_frame` (`vulkan_backend.c:491`).
- Vertex input: one binding (`stride = sizeof(vertex_3d) = 20`) and the supplied attribute descriptors.
- Pipeline layout: built from the supplied descriptor set layouts plus a single push-constant range covering 128 bytes for `mat4` model matrix + spare (used by the material shader for per-draw model push).

`bind` is a wrapper around `vkCmdBindPipeline`.

## Design decisions & rationale

- **Caller supplies viewport/scissor at creation time, but they're also dynamic state** — the static values are placeholders; the runtime viewport comes from `vkCmdSetViewport`. Keeps the create call self-contained for tests/tools that don't run the full frame.
- **Push constants reserved at layout creation** — the material shader doesn't yet push the model matrix (the API surface is still per-object UBO), but the layout reserves space so that flip can land without recreating the pipeline.
- **Negative-Y viewport + CCW front face** — combined choice. The rasterizer interprets winding under the (now flipped) NDC space.
- **Blend hardcoded for alpha-over** — adequate for textured quads; opaque-only or additive paths would need configurability here.

## Known limitations

- Single binding only — interleaved vertex layouts only.
- Single push-constant range, single descriptor set layout count is whatever the caller passes (material shader passes 2: global + object).
- No pipeline cache (`VkPipelineCache` is `VK_NULL_HANDLE`); every shader recompile rebuilds from source.
- Wireframe is per-pipeline at create time, not toggleable.

## Related docs

- [`vulkan-shaders.md`](vulkan-shaders.md) — sole consumer (today).
- [`vulkan-backend.md`](vulkan-backend.md) — sets dynamic viewport/scissor.

# Vulkan Material Shader

## Purpose

The single built-in shader: a vertex+fragment pair that reads a global UBO (projection, view) and a per-object UBO + diffuse sampler, and renders textured geometry. Owns its own descriptor pools, descriptor set layouts, descriptor sets, uniform buffers, and graphics pipeline. The rename from "object_shader" to "material_shader" (`d1ce0fe`) reflects that it's a material descriptor system more than a per-object one.

## Files

- `engine/src/renderer/vulkan/shaders/vulkan_material_shader.h` / `vulkan_material_shader.c`.
- `engine/src/renderer/vulkan/vulkan_shader_utils.h` / `vulkan_shader_utils.c` — SPIR-V loader.
- `vulkan_material_shader` struct in `vulkan_types.inl:157`.
- `vulkan_object_shader_object_state` (`vulkan_types.inl:146`) — per-object descriptor state with up to 3 frames of in-flight tracking.

## Public API

- `vulkan_material_shader_create(context, out_shader)` — load `Builtin.MaterialShader.{vert,frag}.spv`, set up descriptors, pipeline, uniform buffers.
- `vulkan_material_shader_destroy(context, shader)`.
- `vulkan_material_shader_use(context, shader)` — `vkCmdBindPipeline`.
- `vulkan_material_shader_update_global_state(context, shader, delta_time)` — pushes the global UBO and binds the global descriptor set for the current frame.
- `vulkan_material_shader_update_object(context, shader, geometry_render_data)` — pushes per-object UBO, writes diffuse sampler, binds object descriptor set.
- `vulkan_material_shader_acquire_resources(context, shader, out_object_id)` / `release_resources(... id)` — mint/return a slot in the object state pool.

## How it works

**Layout**:

- Global descriptor set: binding 0 = uniform buffer (vertex stage), holds `global_uniform_object` (projection, view, two reserved mat4s = 256 bytes total).
- Per-object descriptor set: binding 0 = uniform buffer (`object_uniform_object` = diffuse colour + reserved = 64 bytes), binding 1 = combined image sampler — both fragment stage.

**Pools**:

- Global pool: `max_frames_in_flight` uniform-buffer descriptors.
- Object pool: `VULKAN_OBJECT_MAX_OBJECT_COUNT (= 1024)` uniform buffers and 1024 combined image samplers; `FREE_DESCRIPTOR_SET_BIT` so individual sets can be freed (which `release_resources` would do).

**Buffers**:

- One global uniform buffer sized for `max_frames_in_flight` copies, host-visible coherent.
- One object uniform buffer sized for 1024 objects (`object_uniform_buffer_index` is a bump cursor — TODO comment notes a free-list is needed).

**Pipeline**: built via `vulkan_graphics_pipeline_create` with two attributes (vec3 position, vec2 texture_coordinates) and the global + object descriptor set layouts.

**Per-frame** (`update_global_state`): writes `global_ubo` into the right slot of the global uniform buffer, optionally rewrites the descriptor (gated by descriptor `generations[current_frame] == INVALID_ID`), and `vkCmdBindDescriptorSets` for set 0.

**Per-object** (`update_object`): writes `object_uniform_object` into the assigned slot of the object uniform buffer, writes the combined image-sampler descriptor with the texture's `vulkan_texture_data::image.view` and `sampler`, binds set 1.

**Resource acquire**: returns a slot index from `0..VULKAN_OBJECT_MAX_OBJECT_COUNT`. The temporary code in `vulkan_renderer_backend_initialize` calls this once for object id 0 and never releases it.

`vulkan_shader_utils.create_shader_module` reads `assets/shaders/<name>.<type>.spv` from disk via the filesystem layer, calls `vkCreateShaderModule`, and fills a `vulkan_shader_stage` with the create info, the module handle, and the pipeline-stage create info ready to plug into the pipeline.

## Design decisions & rationale

- **Two-tier descriptor model** — global (frame-frequency) vs object (object-frequency). Lets the global UBO be updated once per frame and the object UBO per draw, matching how scene data naturally fans out (`37a6314`, `fdf1f7e`).
- **Per-frame slots, descriptor generation** — `descriptor_states[d].generations[frame]` tracks when each descriptor was last written. Avoids redundant `vkUpdateDescriptorSets` when nothing changed.
- **Push-constant slot reserved in pipeline layout, not yet used** — the model matrix is currently delivered via per-object UBO writes. Push constants (`c859db3`) live in the layout but the shader uses the UBO path. Switching is a shader edit, not a pipeline rebuild.
- **Object pool sized 1024 with bump cursor** — temporary; `// TODO: Manage a free list of some kind here instead.` (`vulkan_types.inl:178`). After 1024 acquires the cursor will run off and `release_resources` won't recycle.
- **Fragment-stage sampler bindings** — diffuse only for now. Adding normal/specular/etc. extends `VULKAN_OBJECT_SHADER_DESCRIPTOR_COUNT`.
- **Renamed from `vulkan_object_shader`** — the descriptors are about material binding (texture, diffuse colour) more than per-object identity. The rename in `d1ce0fe` clarified the naming without changing structure.

## Known limitations

- One shader, hardcoded by name `"Builtin.MaterialShader"`.
- Object descriptor pool `maxSets = VULKAN_OBJECT_MAX_OBJECT_COUNT` — a hard cap.
- No descriptor versioning across multiple textures yet — the diffuse sampler is rewritten unconditionally each draw.
- The descriptor `generations` array is sized [3] (`vulkan_types.inl:140-141`) presumably for triple-buffering but `max_frames_in_flight = 2`. The third slot is unused.
- `release_resources` is declared (`vulkan_material_shader.h:17`) but not yet wired into a per-object lifecycle.

## Related docs

- [`vulkan-pipeline.md`](vulkan-pipeline.md), [`vulkan-buffers.md`](vulkan-buffers.md), [`vulkan-images.md`](vulkan-images.md)
- [`platform/filesystem.md`](../platform/filesystem.md) — used by `create_shader_module`.
- [`renderer/frontend-backend-split.md`](frontend-backend-split.md) — `global_uniform_object` and `object_uniform_object` types live in `renderer_types.inl`.

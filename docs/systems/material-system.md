# Material System

## Purpose

Reference-counted, name-keyed material cache. A material bundles a diffuse colour with
the texture maps that describe a surface, so the renderer binds *one* material instead of
juggling loose textures per draw. Materials are described by plain-text `.hmt` files under
`assets/materials/`, and the system owns both the parsing and the GPU-side descriptor
resources the renderer needs to draw with them.

This is the same reference-counting shape as [texture-system](../resources/texture-system.md),
one level up: the texture system caches images, the material system caches *combinations*
of them.

## Files

- `engine/src/resources/resource_types.h` — `material`, `texture_map`, `texture_use`,
  `MATERIAL_MAX_NAME_LENGTH`.
- `engine/src/systems/material_system.h` / `material_system.c`.
- `engine/src/resources/loaders/material_loader.c` — parses the `.hmt` format.
- `engine/src/renderer/vulkan/shaders/vulkan_material_shader.c` — per-material descriptor
  sets and the instance UBO.
- `assets/materials/*.hmt` — material definitions.

## Public API

- `struct material_system_config { u32 max_material_count; }` — `application.c` passes 4096.
- `struct material_config { char name[]; material_type type; b8 auto_release; vec4 diffuse_color; char diffuse_map_name[]; }`
- `enum material_type { MATERIAL_TYPE_WORLD, MATERIAL_TYPE_UI }`
- `b8 material_system_initialize(memory_requirement, state, config)`
- `void material_system_shutdown(state)`
- `material* material_system_acquire(const char* name)` — loads `assets/materials/<name>.hmt`.
- `material* material_system_acquire_from_config(material_config config)` — skips the file.
- `void material_system_release(const char* name)`
- `#define DEFAULT_MATERIAL_NAME "default"`

## How it works

State is sized in three contiguous blocks out of the systems linear allocator, following
the [two-call init pattern](initialization-pattern.md): the `material_system_state` struct,
a flat `material[max_material_count]` array, then a hashtable backing block of
`material_reference[max_material_count]`.

`material_reference` holds `{ reference_count, handle, auto_release }`. The table is
pre-filled with `handle = INVALID_ID`, so a lookup on an unknown name still returns a valid
sentinel rather than failing.

`material_system_acquire(name)` asks the [resource system](resource-system.md) for a
`RESOURCE_TYPE_MATERIAL`, which the material loader resolves to
`assets/materials/<name>.hmt` and parses into a `material_config`. That config is forwarded to
`acquire_from_config` and the resource is then unloaded.

`acquire_from_config(config)`:

1. The literal name `"default"` short-circuits to the default material.
2. Look up the reference; if `reference_count == 0`, latch in the supplied `auto_release`.
3. Increment the count. If `handle == INVALID_ID`, scan the material array for a free slot
   (`id == INVALID_ID`), claim it, and `load_material(config, m)`.
4. Bump `generation`, set `m->id = ref.handle`, write the reference back.

`load_material` copies the name and diffuse colour, acquires the diffuse texture through
the texture system (falling back to the default texture with a warning if it is missing),
then calls `renderer_create_material`, which reaches the Vulkan backend and allocates one
descriptor set **per swapchain image** plus a slot in the shared instance UBO.

`material_system_release(name)` decrements; when `auto_release && reference_count == 0` it
calls `destroy_material`, which releases the texture reference, calls
`renderer_destroy_material`, and invalidates `id`/`generation`/`internal_id`.

The default material is built in code (`create_default_material`): white diffuse colour
pointing at the texture system's procedural checkerboard, so the renderer always has
something valid to bind even with no assets on disk. It is never reference-counted and
`release` ignores it.

## The `.hmt` file format

Line-oriented `key=value`. Blank lines and lines starting with `#` are skipped. Keys are
matched case-insensitively via `strings_equal_insensitive`.

```
#material file

version=0.1
name=test_material
diffuse_color=1.0 1.0 1.0 1.0
diffuse_map_name=cobblestone_floor_tiled_32
type=world
```

`type` selects which shader the material binds to: `ui` routes it to the UI shader and the UI
renderpass, anything else (including an absent `type`) means a world material. `version` is
parsed but not yet acted on. `diffuse_color` is four floats via
`string_to_vec4`; a parse failure warns and falls back to white. `diffuse_map_name` is a
texture name **without** extension or directory — the texture system resolves it to
`assets/textures/<name>.png`.

Kohi names this format `.kmt`; Hefest uses `.hmt` for the same reason every other `k`
prefix became `h`.

## Renderer side

`vulkan_material_shader_instance_ubo` (`vulkan_types.inl`) is the per-material UBO payload —
just `diffuse_color` plus reserved vectors. The UI shader has its own twin,
`vulkan_ui_shader_instance_ubo`. `vulkan_material_shader` keeps
`instance_states[VULKAN_MAX_MATERIAL_COUNT]`, each holding one descriptor set per swapchain
image and a `vulkan_descriptor_state` per binding tracking `generations` and `ids`.

Two details worth noting:

- The instance UBO is re-uploaded when `descriptor_state.generation != material->generation`,
  not just once. That is what makes a material edit visible without recreating the material.
- The object descriptor pool is created with `VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT`
  because `release_resources` calls `vkFreeDescriptorSets`. Freeing individual sets from a
  pool without that flag is undefined behaviour.

`renderer_create_material` and `destroy_material` switch on `material->type` to acquire and
release resources from the right shader, and `draw_geometry` uses it to pick which shader's
`set_model`/`apply_material` to call.

Sampler binding is driven by `shader->sampler_uses[]` rather than a positional texture
array, so binding 1 resolves through `TEXTURE_USE_MAP_DIFFUSE` to
`material->diffuse_map.texture`. Adding a second map type means adding a use and a case,
not renumbering an array.

## Known limitations

- `internal_id` allocation in the Vulkan shader is a monotonically increasing counter with a
  `TODO` for a free list, so churning materials will exhaust `VULKAN_MAX_MATERIAL_COUNT`
  even if the live count stays low.
- Only the diffuse map is supported; `load_material` has a `TODO` for other maps.

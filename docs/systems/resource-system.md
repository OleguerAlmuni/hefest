# Resource System

## Purpose

A single front door for getting things off disk. Before this system, every subsystem
opened its own files: the texture system called `stb_image` directly, the material system
had its own `.hmt` parser, and `vulkan_shader_utils` read SPIR-V through `filesystem_*`.
Each knew its own path layout and its own cleanup rules.

The resource system replaces that with one call — `resource_system_load(name, type,
&resource)` — dispatched to a registered *loader* per resource type. Callers no longer know
where assets live on disk or what decodes them.

## Files

- `engine/src/resources/resource_types.h` — `resource_type`, `resource`, `image_resource_data`,
  and `material_config` (moved here from `material_system.h`).
- `engine/src/systems/resource_system.h` / `resource_system.c`.
- `engine/src/resources/loaders/` — `text_loader`, `binary_loader`, `image_loader`,
  `material_loader`.
- `engine/src/platform/filesystem.c` — gains `filesystem_size` and `filesystem_read_all_text`.

## Public API

- `struct resource_system_config { u32 max_loader_count; char* asset_base_path; }` —
  `application.c` passes 32 and `"assets"`.
- `struct resource { u32 loader_id; const char* name; char* full_path; u64 data_size; void* data; }`
- `b8 resource_system_initialize(memory_requirement, state, config)`
- `void resource_system_shutdown(state)`
- `b8 resource_system_register_loader(resource_loader loader)`
- `b8 resource_system_load(const char* name, resource_type type, resource* out_resource)`
- `b8 resource_system_load_custom(const char* name, const char* custom_type, resource* out_resource)`
- `void resource_system_unload(resource* resource)`
- `const char* resource_system_base_path()`

## How it works

State is the `resource_system_state` struct followed by a flat
`resource_loader[max_loader_count]` array, both carved from the systems linear allocator via
the [two-call init pattern](initialization-pattern.md).

A `resource_loader` is a small vtable:

```c
typedef struct resource_loader {
    u32 id;
    resource_type type;
    const char* custom_type;
    const char* type_path;
    b8 (*load)(struct resource_loader* self, const char* name, resource* out_resource);
    void (*unload)(struct resource_loader* self, resource* resource);
} resource_loader;
```

`type_path` is the subdirectory the loader owns. Every loader builds its path the same way:

```
<asset_base_path>/<type_path>/<name><extension>
```

so the image loader (`type_path = "textures"`, extension `.png`) resolves `cobblestone` to
`assets/textures/cobblestone.png`, and the material loader (`type_path = "materials"`,
extension `.hmt`) resolves `test_material` to `assets/materials/test_material.hmt`. The text
and binary loaders use an empty `type_path` and no extension, so the caller supplies the
whole relative path — which is why `create_shader_module` now asks for
`shaders/Builtin.MaterialShader.vert.spv`.

Loaders are auto-registered in `resource_system_initialize`. Registration rejects a second
loader for an already-registered type, and `id` is the index into the array — which is what
`resource.loader_id` stores, so `resource_system_unload` can find the loader that produced a
resource without the caller tracking it.

### The base path

`asset_base_path` is `"assets"`, not upstream Kohi's `"../assets"`. `post-build.sh` copies the
whole asset tree into `bin/` and compiles shaders into `bin/assets/shaders/`, and `run.sh`
runs the binary from `bin/` — so assets sit directly beneath the working directory.

## What moved

| Was | Now |
|---|---|
| `texture_system.c` owned `STB_IMAGE_IMPLEMENTATION` and called `stbi_load` | `image_loader.c` does; `load_texture` consumes `image_resource_data` |
| `material_system.c::load_configuration_file` parsed `.hmt` | `material_loader.c::material_loader_load` does |
| `vulkan_shader_utils.c` called `filesystem_read_all_bytes` | asks the binary loader for `RESOURCE_TYPE_BINARY` |
| `material_config` lived in `material_system.h` | lives in `resource_types.h`, since the loader produces it |

All four loaders delegate their `unload` to `resource_unload` in `loaders/loader_utils.c`,
which frees the path and the data under a caller-supplied memory tag.

`filesystem_read_all_bytes` also changed shape: it used to allocate `*out_bytes` for the
caller, and now fills a caller-supplied buffer. Loaders size the buffer with the new
`filesystem_size` first. `filesystem_read_all_text` is the same idea for text.

## Known limitations

- Every loader has a `TODO: Should be using an allocator here` on its `hallocate` calls; they
  all allocate straight from the global tagged allocator.
- `resource_system_shutdown` only nulls the state pointer. Resources still held by callers at
  shutdown are not unloaded.
- Extensions are hardcoded per loader with a `TODO: Try different extensions` — a texture must
  be `.png`, a material must be `.hmt`.
- `load` writes `out_resource->loader_id` before calling the loader, so a failed load leaves a
  valid-looking `loader_id` behind unless the loader clears it.

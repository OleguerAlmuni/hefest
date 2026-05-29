# Texture System

## Purpose

Reference-counted, name-keyed texture cache. Loads PNGs from `assets/textures/<name>.png` via `stb_image`, hands the pixels to the renderer to upload, and tracks references so multiple acquirers share the same GPU resource. Provides a procedurally-generated default texture so the renderer can run without any assets present.

## Files

- `engine/src/resources/resource_types.h` — `texture` struct (id, w/h, channels, generation, `internal_data`).
- `engine/src/systems/texture_system.h` / `texture_system.c`.
- `engine/src/vendor/stb_image.h` — vendored PNG/JPG decoder (used with `STB_IMAGE_IMPLEMENTATION` in `texture_system.c:11`).

## Public API

- `struct texture_system_config { u32 max_texture_count; }` — `application.c:130` passes 65536.
- `b8 texture_system_initialize(memory_requirement, state, config)`.
- `void texture_system_shutdown(state)`.
- `texture* texture_system_acquire(name, auto_release)` — bumps refcount, lazily loads on first acquire.
- `void texture_system_release(name)` — drops refcount, frees GPU resource if `auto_release && refcount == 0`.
- `texture* texture_system_get_default_texture()`.
- `#define DEFAULT_TEXTURE_NAME "default"`.

## How it works

State is sized in three contiguous blocks: the `texture_system_state` struct, then a flat array of `texture[max_texture_count]`, then a hashtable backing block of `texture_reference[max_texture_count]`. All carved out of the systems linear allocator via the two-call init pattern.

`texture_reference` holds `{ reference_count, handle, auto_release }`. The hashtable is filled with `{ handle = INVALID_ID, ref_count = 0 }` so a get on an unknown name returns a valid sentinel.

`acquire(name, auto_release)`:

1. Reject the literal `"default"` name (warn and return the default texture).
2. Look up the reference; if `ref_count == 0`, latch in the supplied `auto_release`.
3. Increment `ref_count`. If `handle == INVALID_ID`, scan the texture array for a free slot, mark it the new handle, and `load_texture(name, t)`.
4. Write the updated reference back via `hashtable_set`.

`load_texture` formats the path as `assets/textures/%s.png`, calls `stbi_load` with 4 forced channels and `flip_vertically_on_load = true` (Vulkan's NDC), scans alpha for transparency, then `renderer_create_texture(name, w, h, 4, data, has_transparency, &temp_texture)`. The temp texture is swapped in atomically with the existing one (so a hot-reload pattern is possible) and the old GPU texture is destroyed. Generation increments per successful load.

`release(name)` decrements; if `auto_release && ref_count == 0`, calls `renderer_destroy_texture` and resets the slot.

The default texture is created procedurally in `create_default_textures` (`texture_system.c:208`): a 256×256 RGBA blue/white-ish checkerboard built in code so the engine has *something* to render even with `assets/textures/` empty.

## Design decisions & rationale

- **Hashtable for name lookup, array for storage** — separates the question "do we already have it?" from the storage. Slots are reused on release; the hashtable is filled with sentinel references upfront so unknown lookups return a valid struct rather than missing-key errors (`15fbee3`).
- **`auto_release` per texture** — set on first acquire and latched. Lets a caller indicate "I want this evicted when the last reference drops" without pulling in a separate eviction policy.
- **Default texture, generated in code** — eliminates the chicken-and-egg "renderer needs a texture before assets are loadable" problem (`fdf1f7e`). Also doubles as a recognizable visual for missing textures.
- **`generation` counter on `texture`** — the descriptor system uses this to detect "the texture I'm pointing at has been replaced" without comparing pointers. Resets to 0 on first load and increments on reload.
- **Atomic swap on reload** — `load_texture` builds the new GPU resource into a stack `temp_texture`, then `*t = temp_texture` and destroys the old one. Means a mid-frame reload doesn't observe a half-built texture.
- **PNG-only today** — `format_str = "assets/textures/%s.%s"` is in place but `load_texture` always passes `"png"` (`texture_system.c:267`). The `// TODO: try different extensions` is the seam for JPG/TGA/etc.

## Known limitations

- `load_texture` has a stray brace mismatch at `texture_system.c:138`: `HERROR(...) { return 0; }` — the `{...}` parses as a compound statement after the macro, so `return 0;` runs unconditionally inside the success branch. Worth fixing.
- Linear scan for a free slot in `acquire` — O(max_texture_count) on each first-time load. Acceptable at 65536 / cold path; would matter for runtime streaming.
- Uses `strings_equal_insensitive` (`texture_system.c:105/162`) which has the broken GCC fallback flagged in [`core/string-library.md`](../core/string-library.md). On Clang-on-Windows it works; on Clang-on-Linux the function returns garbage. Worth checking the Linux build.
- `stbi_load` allocates with stb's internal allocator, not `hallocate`; `stbi_image_free(data)` is called after the upload, so it's transient — but those bytes don't show up in the memory report.
- No mip generation, so `vkCreateSampler`'s `maxLod = 0`.

## Related docs

- [`renderer/vulkan-images.md`](../renderer/vulkan-images.md) — recipient of the pixel data.
- [`containers/hashtable.md`](../containers/hashtable.md) — backing lookup.
- [`renderer/frontend-backend-split.md`](../renderer/frontend-backend-split.md) — frontend calls `texture_system_acquire` / `_get_default_texture` from its debug event handler.

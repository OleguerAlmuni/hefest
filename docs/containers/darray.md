# Dynamic Array (`darray`)

## Purpose

Generic, type-erased growable array implemented with the "header before pointer" trick: callers hold a pointer that points to the first element; capacity/length/stride are stored in three `u64`s immediately before that pointer. Macros wrap the void* API with `typeof(value)` so call sites stay type-safe.

## Files

- `engine/src/containers/darray.h` / `darray.c`.

## Public API

Underlying functions (rare to call directly):

- `_darray_create(length, stride)`, `_darray_destroy(array)`.
- `_darray_resize(array)` — doubles capacity.
- `_darray_push(array, value_ptr)`, `_darray_pop(array, dest)`.
- `_darray_insert_at(array, index, value_ptr)`, `_darray_pop_at(array, index, dest)`.
- `_darray_field_get/set(array, field)` for `DARRAY_CAPACITY/LENGTH/STRIDE`.

Macros (the actual public surface):

- `darray_create(type)` — capacity = `DARRAY_DEFAULT_CAPACITY` (1).
- `darray_reserve(type, capacity)`.
- `darray_destroy(array)`.
- `darray_push(array, value)` — uses `typeof(value)` to take the address of an rvalue.
- `darray_pop(array, value_ptr)`, `darray_insert_at(array, index, value)`, `darray_pop_at(array, index, value_ptr)`.
- `darray_clear`, `darray_capacity`, `darray_length`, `darray_stride`, `darray_length_set`.

## How it works

`_darray_create` allocates `header_size + length*stride` bytes (`MEMORY_TAG_DARRAY`), zeroes it, writes the three `u64` fields, and returns a pointer **past** the header. Every other function recovers the header by stepping back `DARRAY_FIELD_LENGTH * sizeof(u64)` bytes.

`darray_push` stamps `typeof(value) temp = value;` so even a literal can have its address taken, then calls `_darray_push`. If the array is full, `_darray_resize` allocates a new buffer at `2 * capacity`, copies the elements, destroys the old buffer, and returns the new pointer — `darray_push` reassigns `array` to that returned pointer, hence the `array = _darray_push(...)` pattern in the macros.

`_darray_insert_at` and `_darray_pop_at` use `hcopy_memory` to slide tail elements; the slide size is `stride * (length - index)` rather than `length - index - 1`, so the copy reads the element past the array end (typically harmless trailing garbage but technically out-of-bounds).

## Design decisions & rationale

- **Pointer-into-the-buffer ergonomics** — `array[i]` works directly with the right type because the user keeps a `T*`. The trade is that `array` must be reassigned after every `push` (since `_darray_resize` returns a new pointer), which is what the macros enforce.
- **Header pre-pended in same allocation** — single allocation per array, no separate metadata block. `_darray_destroy` recomputes the total size from the header before freeing.
- **`typeof()` for `darray_push`** — relies on a GCC/Clang extension. Both clang Windows and clang Linux are the supported toolchains, so this is safe.
- **Tag `MEMORY_TAG_DARRAY`** — every dynamic array is visible in `get_memory_usage_str`. Useful when investigating event-system memory: each registered event code holds its own `darray`.
- **Refactor history** — `a3a0bce` (Refactor Part 1) reworked darrays. The Vulkan backend uses them heavily for swapchain images, command buffers, and synchronization primitives (see `vulkan_backend.c`).

## Known limitations

- `_darray_insert_at` and `_darray_pop_at` slide `length - index` elements instead of `length - index - 1`; one byte past the array end is read each time.
- Pushing onto a freshly-resized array re-uses the old `length` snapshot; if the array was passed through several macros without reassignment, the caller can corrupt it. Macros mostly prevent this, raw `_darray_push` does not.
- No `darray_resize_to(new_length)` helper.
- `darray_create` defaults to capacity 1 — every new array does at least one realloc on the second push. Acceptable; explicit `darray_reserve` is provided.
- Hashtable tests live alongside but darray itself has no unit tests today.

## Related docs

- [`core/event-system.md`](../core/event-system.md) — primary user.
- [`renderer/vulkan-backend.md`](../renderer/vulkan-backend.md) — uses `darray_reserve` extensively for command-buffer / semaphore / fence arrays.

# Hashtable

## Purpose

Fixed-size, name-keyed lookup table where the caller supplies the backing memory. Two flavours — value tables that store copies, and pointer tables that store `void*` slots and don't take ownership. Used today exclusively by the texture system.

## Files

- `engine/src/containers/hashtable.h` / `hashtable.c`.

## Public API

- `struct hashtable { u64 element_size; u32 element_count; b8 is_pointer_type; void* memory; }`.
- `hashtable_create(element_size, element_count, memory, is_pointer_type, out_table)`.
- `hashtable_destroy(table)` — zeros the struct; does not free `memory`.
- Value-table calls: `hashtable_set(table, name, value)`, `hashtable_get(table, name, out_value)`, `hashtable_fill(table, value)`.
- Pointer-table calls: `hashtable_set_ptr(table, name, value)`, `hashtable_get_ptr(table, name, out_value)`.

All `HAPI`.

## How it works

`hash_name` (`hashtable.c:6`) computes `hash = hash * 97 + ch` over the bytes of `name`, then takes `hash % element_count`. The bucket is the modular hash directly — there is no probing, no chaining, no collision handling. Two names that hash to the same bucket simply overwrite each other.

`hashtable_create` validates inputs and zeroes the caller-provided memory. The caller is responsible for sizing the block as `element_size * element_count`.

`hashtable_fill` writes `value` into every slot — used by the texture system to seed the table with an "invalid" `texture_reference` so a `get` on an unknown name returns a sentinel rather than zeroes.

## Design decisions & rationale

- **Caller-supplied memory** — keeps the hashtable allocator-agnostic and slots cleanly into the systems linear allocator. The texture system carves `element_size * max_texture_count` bytes out of its own state block (`texture_system.c:46-64`).
- **No collision handling** — deliberate simplification (`15fbee3`). Works because the texture system sizes its table to `max_texture_count = 65536` against a small expected key set, and texture names are well-known. Will fail silently if collisions become real.
- **Pointer vs value variants** — pointer tables store the bare `void*` (cast through `(void**)memory`), value tables store copies of `element_size` bytes. The `is_pointer_type` flag is checked on every call to refuse the wrong API.
- **`hashtable_fill` for sentinels** — the texture system sets every entry to `texture_reference{ handle = INVALID_ID, ref_count = 0 }` so `hashtable_get` on a never-seen name returns a valid struct rather than uninitialised memory.

## Known limitations

- Single-bucket-per-key: collisions overwrite. With 16-bit-ish hashes in 16-bit modulus this is plausible at small `element_count`.
- No iteration API.
- No `hashtable_unset` — the texture system writes a "released" sentinel back via `hashtable_set` with reset fields (`texture_system.c:184`), which leaves the entry occupying its bucket but flagged.
- `hashtable_destroy` does not free memory (TODO at `hashtable.c:43`); paired with the no-allocator design, this is consistent — the systems allocator owns the memory.
- The hash function is the ASCII multiply-add; case-sensitive. Texture names are lower-cased by convention.

## Related docs

- [`resources/texture-system.md`](../resources/texture-system.md) — only consumer.
- [`systems/initialization-pattern.md`](../systems/initialization-pattern.md) — allocator strategy for hashtable backing memory.

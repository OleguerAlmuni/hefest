# Event System

## Purpose

Decoupled in-process pub/sub. Modules fire events by `u16` code with up to 16 bytes of payload (`event_context`); listeners register a callback and an opaque `listener` pointer. Used for OS events (quit, resize), input events (key/button/mouse), and ad-hoc debug events (`EVENT_CODE_DEBUG0..4`).

## Files

- `engine/src/core/event.h` / `event.c`.

## Public API

- `event_context` — 16-byte union over the common scalar/array shapes (`i64[2]`, `u16[8]`, `c[16]`, etc.).
- `typedef b8 (*PFN_on_event)(u16 code, void* sender, void* listener_inst, event_context data)` — return `true` to stop propagation.
- `void event_system_initialize(u64*, void*)`, `void event_system_shutdown(void*)`.
- `b8 event_register(u16 code, void* listener, PFN_on_event on_event)`.
- `b8 event_unregister(u16 code, void* listener, PFN_on_event on_event)`.
- `b8 event_fire(u16 code, void* sender, event_context context)`.
- `enum system_event_code` — quit (0x01), key pressed/released (0x02/0x03), button pressed/released (0x04/0x05), mouse moved (0x06), mouse wheel (0x07), resized (0x08), debug0..4 (0x10..0x14). Application codes should start above 255.

## How it works

State is a fixed-size lookup `event_code_entry registered[MAX_MESSAGE_CODES]` where `MAX_MESSAGE_CODES = 16384`. Each entry holds a lazily-created `darray<registered_event>` of `{listener, callback}` pairs. `event_register` appends after a duplicate-listener check; `event_unregister` walks the array and `darray_pop_at`s the match. `event_fire` walks the array; if any callback returns `true`, propagation stops (event considered handled).

Events are fired synchronously on the calling thread — there is no queue. The input system fires `EVENT_CODE_KEY_*` directly from inside `input_process_key` (`input.c:62`), so by the time `event_fire` returns, every listener has already run.

## Design decisions & rationale

- **Codes, not types** — `u16` codes plus a 16-byte payload union, instead of one struct per event. Keeps registration cheap and lets the platform layer raise events without including every consumer's headers (see `ebaf91d`).
- **Synchronous dispatch** — no queue, no thread-safety concerns. The price is reentrancy: a listener can fire another event from inside the callback, which works as long as you don't unregister the currently-firing listener (the `i = 1` start in the loops at `event.c:62/89` is a stale typo — see Known limitations).
- **`listener` is opaque** — passed back in the callback so a single global function can serve multiple subscribers. The renderer frontend uses this in `event_on_debug_event` (`renderer_frontend.c:35`).
- **16-byte payload** — fits two `u64`s or four `u32`s, enough for "key + modifier" or "x + y" without heap allocation. Larger payloads must use a separate channel (e.g. set state directly, fire a code as a signal).
- **Lazy darray per code** — only codes that ever had a registration allocate. With 16384 slots and most unused, this matters.

## Known limitations

- `event_register` and `event_unregister` start their search at index `1` (`event.c:62` and `:89`), so a duplicate registration on index 0 is missed and the first registered listener cannot be unregistered. This appears to be an off-by-one that's been latent since `ebaf91d`. Worth fixing.
- `event_system_initialize` calls `hzero_memory(state, sizeof(state))` (`event.c:35`) — `sizeof(state)` is `sizeof(void*)`, not `sizeof(*state_ptr)`. The state is zero-initialised by `hallocate` so this is benign today, but the intent is broken.
- No queueing means slow listeners block the firer.
- `MAX_MESSAGE_CODES = 16384` — the `registered[]` table costs ~256 KiB at process start for an array of pointers. Acceptable but worth knowing.

## Related docs

- [`core/input-system.md`](input-system.md) — heaviest producer.
- [`core/application.md`](application.md) — registers `EVENT_CODE_APPLICATION_QUIT`, `KEY_*`, `RESIZED`.

# Input System

## Purpose

Owns the canonical keyboard and mouse state. The platform layer translates raw OS messages into `keys`/`buttons` and pushes them in via `input_process_*`. The input system fires events on transitions and exposes "is/was" queries so the game can detect both held state and edges (`is_key_down(K) && was_key_up(K)` is a press-this-frame).

## Files

- `engine/src/core/input.h` / `input.c`.

## Public API

- `enum buttons` — `BUTTON_LEFT`, `RIGHT`, `MIDDLE`.
- `enum keys` — Win32-style virtual-key codes (`KEY_A=0x41`, `KEY_LSHIFT=0xA0`, etc., distinct codes for left/right modifiers).
- `void input_system_initialize(u64*, void*)`, `void input_system_shutdown(void*)`, `void input_update(f64 delta_time)`.
- Queries (all `HAPI`): `input_is_key_down/up`, `input_was_key_down/up`, `input_is_button_down/up`, `input_was_button_down/up`, `input_get_mouse_position`, `input_get_previous_mouse_position`.
- Producers (called by the platform layer): `input_process_key(keys, b8 pressed)`, `input_process_button`, `input_process_mouse_move(i16 x, i16 y)`, `input_process_mouse_wheel(i8)`.

## How it works

State is two snapshots: `keyboard_current`/`keyboard_previous` (256 booleans) and `mouse_current`/`mouse_previous`. `input_process_key` only updates state and fires an event when the bit changes (edge-triggered), so spamming the same value does nothing.

`input_update(delta)` is called *last* in the per-frame loop (`application.c:213`). It memcopies `current → previous`. After this, "was" queries reflect the just-finished frame.

The `keys` enum uses Win32 virtual-key codes literally (e.g. `KEY_A=0x41`). The Linux platform layer (`platform_linux.c`) maps X11 keysyms onto the same enum so callers stay platform-agnostic.

## Design decisions & rationale

- **Virtual-key code values** — keep the enum identical to `WM_KEYDOWN`/`WM_KEYUP` payloads on Windows (`1312407`). Costs a translation table on Linux but means zero translation on Windows.
- **Distinct left/right modifiers** — `0a3992b` notes "Fixed issue where left alt and right alt (and ctrl and shift) keys seemed the same to the input system." Modern OSes report distinct codes; merging them was the bug. Now `KEY_LSHIFT` and `KEY_RSHIFT` are separate.
- **Edge-triggered events, level state** — events only fire on transitions, but `input_is_key_down` always reads the live state. Lets games choose either model per query.
- **Update at frame end, not start** — `input_update` runs after `game->update` and `renderer_draw_frame` (`application.c:213`). This way, within a single frame, both `is` and `was` reflect the state seen at frame begin; rolling the snapshot at the end keeps the next frame consistent.
- **256-element keyboard array** — flat lookup keyed by raw `keys` value. Cheap; trades a few unused slots for branch-free queries.

## Known limitations

- `input_system_shutdown` is a stub.
- The mouse `x`, `y` are stored as `i16` in `mouse_state` (line 13) but `input_process_mouse_move` takes `i16` and `input_get_mouse_position` widens to `i32`. Beyond ±32K the cast in the win32 layer (`GET_X_LPARAM` is `i32`) silently wraps.
- No gamepad/joystick support.
- Mouse wheel events have no internal state — the only consumer is the event listener.
- The input subsystem is initialised before any platform input source exists (`application.c:96`), but the platform layer pumps messages on the same thread so there is no race.

## Related docs

- [`core/event-system.md`](event-system.md) — `EVENT_CODE_KEY_*`, `EVENT_CODE_BUTTON_*`, `EVENT_CODE_MOUSE_*`.
- [`platform/platform-layer.md`](../platform/platform-layer.md) — origin of every key/button event.

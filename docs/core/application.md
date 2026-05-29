# Application Layer

## Purpose

Orchestrates the engine: owns the systems linear allocator, brings every subsystem up in dependency order, runs the main loop, and tears everything down. The `game` struct is the user's seam — application calls into game-supplied function pointers each frame.

## Files

- `engine/src/entry.h` — `main()` lives here; user provides `create_game(out_game)`.
- `engine/src/game_types.h` — the `game` struct (function pointers + `state` + `application_state` slots).
- `engine/src/core/application.h` / `application.c` — `application_config`, `application_create`, `application_run`, `application_get_framebuffer_size`.

## Public API

- `application_config` — `start_pos_{x,y}`, `start_width`, `start_height`, `name`.
- `b8 application_create(struct game*)` — set up everything, including the game.
- `b8 application_run()` — block until the user quits.
- `void application_get_framebuffer_size(u32*, u32*)` — used by the Vulkan backend during init.

## How it works

`main()` (`entry.h:13`) calls `create_game`, validates that all four function pointers (`initialize`, `update`, `render`, `on_resize`) are set, then `application_create(&game_inst)` → `application_run()`.

`application_create` (`application.c:59`) does the following, all guarded by the two-call init pattern (`systems/initialization-pattern.md`):

1. Allocate the `application_state` itself with `MEMORY_TAG_APPLICATION` (note: this happens *before* the memory subsystem is initialised, so the allocation is tracked as zero — minor accounting gap).
2. Create a 64 MiB `linear_allocator` (`application.c:71`).
3. Initialize each subsystem twice — once to query size, once with carved memory: events → memory → logging → input. Then register engine-level event handlers (quit, key pressed/released, resize). Then platform → renderer → texture.
4. Call `game->initialize` and a one-shot `game->on_resize` so the game sees the starting framebuffer size.

`application_run` (`application.c:150`) is the main loop:

- `platform_pump_messages` → returns false to stop the loop.
- If not suspended (i.e. window not minimized): `clock_update`, compute delta, call `game->update`, `game->render`, build a `render_packet`, `renderer_draw_frame(packet)`, then frame-time bookkeeping and `input_update(delta)`.
- Optional sleep-back-to-OS path is gated behind `b8 limit_frames = false;` (line 201) — currently disabled.

Shutdown unregisters the event handlers and shuts down each subsystem in reverse dependency order. `event_unregister` for `EVENT_CODE_RESIZED` is missing — minor leak.

`application_on_event` handles `EVENT_CODE_APPLICATION_QUIT` (sets `is_running=false`); `application_on_key` translates `KEY_ESCAPE` into a quit fire; `application_on_resized` updates dimensions and calls `renderer_on_resized`, suspending the loop when the window is minimized (width or height zero).

## Design decisions & rationale

- **Entry point inside the engine** — moved here in `984b00b`. The user only writes `create_game()`, which keeps platform `main` boilerplate (and any future per-platform entry quirks) in the engine.
- **Game owns its own state, engine owns application state** — `game.state` is allocated by the user (`testbed/src/entry.c:22`); `game.application_state` is allocated by the engine. The double-init guard at `application.c:60` rejects a second call.
- **64 MiB systems allocator, sized once** — chosen as "big enough" for current subsystem state. There is no reservation calculation; if the carve runs out, `linear_allocator_allocate` logs and returns 0 (which most subsystems would dereference). Acceptable until the texture system or others grow large dynamic state.
- **ESC = quit baked in** — `application_on_key` (line 259) interprets `KEY_ESCAPE` directly; the game never sees it. Convenient during development, will need to move once a menu/UI exists.
- **Render packet is built in the loop, not by the game** — see TODO at `application.c:186`. Today the packet only carries `delta_time`; the renderer pulls everything else from its own state. This is the seam where future scene data will land.

## Known limitations

- `application_on_resized` does not unregister on shutdown.
- `application_state` is allocated before `memory_system_initialize`, so its size doesn't appear in the per-tag totals.
- `KEY_ESCAPE` quitting is hardcoded; no way for the game to opt out.
- Frame limiter is wired but disabled (`limit_frames = false`).

## Related docs

- [`systems/initialization-pattern.md`](../systems/initialization-pattern.md)
- [`core/event-system.md`](event-system.md)
- [`testbed/testbed.md`](../testbed/testbed.md)

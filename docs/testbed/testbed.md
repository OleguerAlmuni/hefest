# Testbed

## Purpose

The "game" half of the engine seam — a tiny executable that links against `engine` and exists so the engine has a real consumer. Implements `create_game()`, a 6-DoF camera, and a few debug key bindings. The renderer's hardcoded textured quad is what shows up on screen; the testbed mainly drives the camera matrix.

## Files

- `testbed/src/entry.c` — `create_game()` definition, sets `application_config` and game function pointers, allocates `game_state`.
- `testbed/src/game.h` — `game_state` (delta time, camera state).
- `testbed/src/game.c` — `game_initialize`, `game_update`, `game_render`, `game_on_resize`, plus `camera_pitch`, `camera_yaw`, `recalculate_view_matrix`.
- `Makefile.testbed.windows.mak`, `Makefile.testbed.linux.mak`.

## Public API

This *is* the user side, so its only "public" surface is `create_game(game* out_game)`, called by `engine/src/entry.h`'s `main`. It writes:

- `app_config` = window pos `(100, 100)`, size 1280×720, name "Hefest Testbed".
- The four function pointers.
- `state = hallocate(sizeof(game_state), MEMORY_TAG_GAME)`.

## Controls

- `W` / `S` — forward / backward in current view direction.
- `Q` / `E` — left / right strafe.
- `Space` / `X` — up / down.
- `A` / `D` or `Left` / `Right` — yaw.
- `Up` / `Down` — pitch (clamped to ±89° to avoid gimbal lock).
- `M` (key-up edge) — log allocation count delta since the last press.
- `T` (key-up edge) — fire `EVENT_CODE_DEBUG0`, swapping the active diffuse texture between `cobblestone_floor_tiled_32` and `sandstone_blocks_tiled_32`.
- `Esc` — quit (handled by the application layer, not the testbed).

## How it works

`game_initialize` puts the camera at `(0, 0, 30)`, marks the view dirty.

`game_update`:

1. Reads `M` and `T` edges via `input_is_key_up && input_was_key_down`.
2. Walks the input states to accumulate yaw/pitch/translation.
3. If translation is nonzero, normalises and applies `temp_move_speed = 50.0f`.
4. `recalculate_view_matrix(state)` rebuilds `state->view = inverse(rotation * translation)` if dirty.
5. **HACK**: calls `renderer_set_view(state->view)` (`game.c:134`). Marked HACK because the renderer's frontend exposes this directly to the game; the proper path is for the engine to read the view from the render packet.

`game_render` is empty — actual drawing is the engine's responsibility today.

`recalculate_view_matrix` builds `mat4_euler_xyz(pitch, yaw, roll)`, multiplies by `mat4_translation(position)`, and inverts. Note: `mat4_multiply(rotation, translation)` produces `R * T`, which is "rotate the world then translate". Inverting gives the camera-space transform.

## Design decisions & rationale

- **`HACK: renderer_set_view`** — the seam between game and renderer is incomplete. The cleaner pattern is to put view/projection on a frame's render packet and let the game write it there. Today the testbed pokes the frontend directly; documented as `// HACK` (`renderer_frontend.h:13`, `game.c:134`).
- **Pitch clamp at 89°** — basic gimbal-lock guard.
- **`M` toggles allocation diagnostics** — uses `get_memory_alloc_count()` to print the delta since last keypress. Useful for spotting per-frame leaks during development (`0a3992b`).
- **`T` fires debug event** — cleanest way to test the texture system's reference-counted swap without baking it into the renderer.
- **No `game_render` body** — every draw decision is currently in the engine; the game contract leaves room for the user to plug in their own scene-building, but nothing here does so.

## Known limitations

- Camera position only; no roll.
- No mouse-look (yaw/pitch are keyboard-driven only).
- Reads the view matrix forward axis from the *current* `state->view`, which is post-inverse — `mat4_forward(state->view)` reads the inverse-of-camera as if it were a model matrix. Looks correct in the current setup; worth verifying with a more aggressive transform.
- `state` is allocated but not freed at shutdown.
- Texture-swap key is hardcoded; the two test asset names are baked into `renderer_frontend.c:36`, not the testbed.

## Related docs

- [`core/application.md`](../core/application.md) — invokes `create_game`, owns the loop.
- [`renderer/frontend-backend-split.md`](../renderer/frontend-backend-split.md) — `renderer_set_view` consumer.
- [`math/math-library.md`](../math/math-library.md) — every camera math op.

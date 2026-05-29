# Platform Layer

## Purpose

OS abstraction. Provides window/console/timing/memory primitives and routes raw OS input messages into the engine's input system. Two implementations live behind `platform.h`: Win32 (`platform_win32.c`) and Linux/XCB (`platform_linux.c`). The build pulls both `.c` files but each is wrapped in `#if HPLATFORM_*` so only one body compiles.

## Files

- `engine/src/platform/platform.h` — public API.
- `engine/src/platform/platform_win32.c` — Windows implementation (HWND, WM_*).
- `engine/src/platform/platform_linux.c` — Linux implementation (XCB + X11 + xkbcommon).
- `engine/src/renderer/vulkan/vulkan_platform.h` — companion entry points for Vulkan surface creation and required-extension lists, implemented in the same files.

## Public API

- `platform_system_startup(memory_requirement, state, name, x, y, w, h)` / `platform_system_shutdown(state)`.
- `platform_pump_messages()` — returns false to stop the application loop.
- Memory: `platform_allocate`, `platform_free`, `platform_zero_memory`, `platform_copy_memory`, `platform_set_memory`.
- Console: `platform_console_write(message, colour)` / `platform_console_write_error(message, colour)` — `colour` is the `log_level`, mapped to ANSI colours / Win32 console attributes.
- Time: `platform_get_absolute_time()` returns seconds as `f64`. `platform_sleep(ms)` is internal-only (not `HAPI`).
- Vulkan companions (`vulkan_platform.h`): `platform_create_vulkan_surface(vulkan_context*)`, `platform_get_required_extension_names(const char*** names_darray)`.

## How it works

**Windows** (`platform_win32.c`): registers a window class with `win32_process_message` as the wndproc, creates a top-level window, holds the `HINSTANCE`/`HWND`/`VkSurfaceKHR` in `platform_state`. The wndproc translates `WM_KEYDOWN/UP`, `WM_LBUTTONDOWN`, `WM_MOUSEMOVE`, etc. into `input_process_*` calls; the input system fires events from there. `platform_get_absolute_time` uses `QueryPerformanceCounter`/`QueryPerformanceFrequency`. `platform_create_vulkan_surface` uses `vkCreateWin32SurfaceKHR`.

**Linux** (`platform_linux.c`): connects to the X server via XCB on top of Xlib (`XOpenDisplay` → `XGetXCBConnection`), turns off auto-key-repeat, registers `WM_DELETE_WINDOW`, and runs an XCB event loop. `translate_keycode` maps X11 keysyms onto the `keys` enum. `platform_get_absolute_time` uses `clock_gettime`.

`platform_system_startup` follows the two-call sizing pattern: `state == 0` reports `sizeof(platform_state)`, `state != 0` actually creates the window. The state pointer is held in a file-static for the rest of the process.

## Design decisions & rationale

- **Both `.c` files always compiled, then `#if`'d to empty** — `Makefile.engine.linux.mak:11` globs all `.c` recursively. Easier than per-platform source lists; the unused file becomes an empty translation unit.
- **Vulkan surface creation lives in the platform layer** — `platform_create_vulkan_surface` is implemented per OS and writes into `vulkan_context::surface`. The Vulkan backend doesn't need to know about HWND or xcb_window_t (`4e36d92`).
- **Direct `input_process_*` calls** — the platform message handler doesn't fire events itself; it pushes raw transitions into the input system which then fires the event. Keeps "what is currently down" authoritative even if a listener handled the event before all sinks saw it.
- **Distinct left/right modifier translation** — fixed in `0a3992b`. The Win32 path tests the LParam scancode/extended-bit; the Linux path uses `XK_Shift_L`/`XK_Shift_R` directly.
- **Full XCB+X11 stack on Linux** — XCB is asynchronous and faster, but XKB key translation is easier with Xlib's `XkbKeycodeToKeysym`. The hybrid (`X11-xcb`) is a deliberate compromise (`7d2d12b`).

## Known limitations

- No multi-window support. The platform state holds exactly one HWND/window.
- No DPI awareness on Windows; resize events report client pixels.
- Linux event loop is `xcb_poll_for_event`-based — fast, but does not block when idle, so when the application is running the platform layer always returns to the engine.
- No clipboard, no file dialogs, no audio — just window + input + timer + memory + console.
- Console colours: Windows path uses console attributes; Linux path uses ANSI escapes and assumes the terminal supports them.

## Related docs

- [`core/input-system.md`](../core/input-system.md) — primary downstream consumer.
- [`renderer/vulkan-backend.md`](../renderer/vulkan-backend.md) — uses `platform_create_vulkan_surface` and `platform_get_required_extension_names`.
- [`platform/filesystem.md`](filesystem.md) — sibling module.

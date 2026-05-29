# Build System

## Layout

The repo builds three artefacts from one shared engine:

| Artefact | Source root | Output |
|---|---|---|
| `engine` (shared lib) | `engine/src/` | `bin/engine.dll` (Win) / `bin/libengine.so` (Linux) |
| `testbed` (game exe) | `testbed/src/` | `bin/testbed.exe` / `bin/testbed` |
| `tests` (unit tests) | `tests/src/` | `bin/tests.exe` / `bin/tests` |

Each has a per-platform Makefile at the repo root:

- `Makefile.engine.windows.mak`, `Makefile.engine.linux.mak`
- `Makefile.testbed.windows.mak`, `Makefile.testbed.linux.mak`
- `Makefile.tests.windows.mak`, `Makefile.tests.linux.mak`

Drivers:

- `build-all.bat` / `build-all.sh` — runs the three Makefiles in order (engine → testbed → tests).
- `clean-all.bat` / `clean-all.sh` — invokes the `clean` target on each.
- `post-build.bat` / `post-build.sh` — compiles GLSL shaders to SPIR-V via `glslc` and copies `assets/` into `bin/assets/`.

## Compiler & flags

Always Clang. Common flags across Makefiles:

- `-g -fdeclspec` — debug info; `__declspec` accepted on non-MSVC for the `HAPI` macro.
- Engine: `-DHEXPORT` so `HAPI` becomes `dllexport`.
- testbed / tests: `-DHIMPORT` so `HAPI` becomes `dllimport`.
- `-D_DEBUG` everywhere; release flags are not yet wired up.
- `-Werror=vla -MD` (Linux engine + Windows tests) — bans variable-length arrays and emits dependency files.
- Linux engine adds `-fPIC` and includes `.d` deps via `-include $(OBJ_FILES:.o=.d)`.

Source discovery:

- Windows uses `dir /S /B` + a `rwildcard` Make function (`Makefile.engine.windows.mak:13`).
- Linux uses `find $(ASSEMBLY) -name *.c`.

## Dependencies

- **Vulkan SDK** — `$(VULKAN_SDK)/include` and `$(VULKAN_SDK)/lib`. Linker pulls `vulkan-1` (Win) or `vulkan` (Linux).
- **Linux only** — `xcb`, `X11`, `X11-xcb`, `xkbcommon` (with the `libx11-dev` and `libxkbcommon-x11-dev` apt packages noted in `platform_linux.c:14-16`).
- **Windows only** — `user32`.
- No third-party C dependencies otherwise. `stb_image.h` is vendored at `engine/src/vendor/stb_image.h`.

## Shader pipeline

`post-build.bat` / `.sh` compiles two GLSL files with `glslc`:

- `assets/shaders/Builtin.MaterialShader.vert.glsl` → `bin/assets/shaders/Builtin.MaterialShader.vert.spv`
- `assets/shaders/Builtin.MaterialShader.frag.glsl` → `bin/assets/shaders/Builtin.MaterialShader.frag.spv`

The runtime loads them by name via `vulkan_shader_utils.create_shader_module` using `BUILTIN_SHADER_NAME_MATERIAL = "Builtin.MaterialShader"`.

After shaders, the script copies the entire `assets/` directory into `bin/assets/` so PNGs end up where `texture_system.load_texture` expects them (`assets/textures/<name>.png`).

## Typical workflow

```
> build-all.bat            (or ./build-all.sh)
> post-build.bat           (or ./post-build.sh) -- compiles shaders + copies assets
> bin\testbed.exe          (or ./bin/testbed)
```

Shader changes are not auto-rebuilt by the Makefiles — you must rerun `post-build`.

## Quirks worth knowing

- The Windows engine Makefile builds `engine.dll` directly into `bin/`; `testbed` links against `engine.lib`, but no separate import-lib step is shown — Clang on Windows generates it as a side-effect.
- Object files live in `obj/<assembly>/...` mirroring the source tree.
- There is no release build configuration; `KRELEASE` is referenced in `logger.h:11` but never defined by any Makefile, so debug/trace logs are always compiled in.
- Both `clean-all.{bat,sh}` and the per-Makefile `clean` only delete the assembly's own outputs; the `bin/assets/` copy is not cleaned.

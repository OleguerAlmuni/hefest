# Hefest Engine

A small C game engine with a Vulkan renderer. The runnable application is the
`testbed`, which links against the engine shared library.

## Prerequisites

- **Clang** — the engine and testbed are compiled and linked exclusively with `clang`.
- **GNU Make**
- **Vulkan SDK** — the `VULKAN_SDK` environment variable must be set (used by the
  Makefiles and by `post-build` to compile shaders with `glslc`).
- **Linux only** — X11/xcb development packages: `libx11-dev`, `libxcb1-dev`,
  `libx11-xcb-dev`, `libxkbcommon-x11-dev`.

## Build & Run

Run all commands **from the repository root**. The sequence is: build everything,
run the post-build step (compiles shaders to SPIR-V and copies `assets/` into `bin/`),
then launch the app.

### Linux

```bash
./build-all.sh
./post-build.sh
./run.sh            # or: cd bin && ./testbed
```

`run.sh` launches the app from `bin/` so that `libengine.so` is found (the testbed is
linked with `-Wl,-rpath,.`).

### Windows

```bat
build-all.bat
post-build.bat
bin\testbed.exe
```

> **Note:** Shader changes are not picked up by the build — rerun `post-build` after
> editing anything under `assets/shaders/`.

## Controls

| Key | Action |
|---|---|
| `W` / `S` | Move forward / backward |
| `Q` / `E` | Strafe left / right |
| `Space` / `X` | Move up / down |
| `A` / `←` &nbsp;·&nbsp; `D` / `→` | Yaw camera left / right |
| `↑` / `↓` | Pitch camera up / down |
| `T` | Swap texture (debug) |
| `M` | Log allocation count (debug) |
| `Esc` | Quit |


# Unit Tests

## Purpose

Small, in-house test runner for the engine's pure data-structure code. Two suites today: the linear allocator and the hashtable. The runner produces a separate `tests.exe` / `tests` executable that links against `engine` and runs registered tests sequentially, reporting pass/fail counts.

## Files

- `tests/src/main.c` — entry point; calls register-functions and runs.
- `tests/src/test_manager.h` / `test_manager.c` — registration + execution.
- `tests/src/expect.h` — assertion macros: `expect_should_be`, `expect_should_not_be`, `expect_float_to_be`, `expect_to_be_true`, `expect_to_be_false`. Failure logs file + line and `return false`.
- `tests/src/memory/linear_allocator_tests.h` / `.c`.
- `tests/src/containers/hashtable_tests.h` / `.c`.
- `Makefile.tests.windows.mak`, `Makefile.tests.linux.mak`.

## Public API

- `typedef u8 (*PFN_test)();` — test functions return 1 (pass), 0 (fail), or `BYPASS = 2`.
- `void test_manager_init()`.
- `void test_manager_register_test(PFN_test, char* desc)` — typically wrapped by per-suite `*_register_tests()`.
- `void test_manager_run_tests()` — executes all, prints summary via the engine's logger.

## How it works

`main.c` calls `test_manager_init`, then each suite's `*_register_tests` (`linear_allocator_register_tests`, `hashtable_register_tests`), then `test_manager_run_tests`. The runner walks the registration list, calls each function, and tallies results. Test functions use the `expect_*` macros to compare and short-circuit on failure.

`expect_*` macros all log via `HERROR` from the engine, so test output appears in the same console.log file (which can be confusing if both `testbed.exe` and `tests.exe` write the same log; running `tests.exe` from a different working directory avoids the collision).

## Design decisions & rationale

- **Reuse the engine's logger** — tests ship as a separate exe but link the same engine, so `HERROR`/`HINFO` from inside `expect_*` go through `log_output` and into `console.log` (`0a3992b`).
- **Three-way return (`pass`, `fail`, `BYPASS`)** — `BYPASS = 2` lets a test disable itself without removing the registration (e.g. for known-broken cases). Used sparingly today.
- **Macro-based assertions** — file/line capture is cleaner with macros than a function. The macros `return false;` directly, so each test function is structured as a sequence of `expect_*` followed by `return true;`.
- **Coverage limited to data structures** — the renderer and platform layers aren't unit-testable without a Vulkan context and a window, so tests focus on the parts that are.

## Known limitations

- No teardown hook; each test must clean up after itself.
- Coverage is `linear_allocator` + `hashtable` only. `darray`, `hstring` parsers, math, event system are uncovered.
- No fixtures or parameterisation.
- The engine's `console.log` is shared with `testbed.exe` if both are run in the same working directory.
- `expect_should_be` uses `%lld` regardless of operand type; printing a `f32` through it would format-mangle. There's a separate `expect_float_to_be` for that.

## Related docs

- [`memory/linear-allocator.md`](../memory/linear-allocator.md) — primary test target.
- [`containers/hashtable.md`](../containers/hashtable.md) — primary test target.
- [`BUILD.md`](../BUILD.md) — `Makefile.tests.*.mak`.

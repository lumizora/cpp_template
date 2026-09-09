# AGENTS.md

## Project

- C++17 CMake template using FetchContent only; do not add Conan or vcpkg.
- `cpp_template_core` is the cross-platform static library; `cpp_template` is the CLI executable.
- Keep third-party dependencies private to the targets that use them.

## Build and test

```sh
cmake --preset default
cmake --build --preset default

cmake --preset test --fresh
cmake --build --preset test
ctest --preset test
```

Use `cmake --preset bench --fresh` and `cmake --build --preset bench` for benchmarks.
Use the `offline` preset to verify cached, network-free builds.
Use `sanitize` for ASan/UBSan, `analyze` for compiler-integrated clang-tidy, and
`release` for installation/archive tests. Release packaging disables local overrides
and system package preference; ship the `Runtime` component only.

## Dependency changes

- Add or update dependencies only in `cmake/Dependencies.cmake`; preserve pinned tags and SHA256 hashes.
- Reuse `add_dependency()`, `add_header_dependency()`, or `add_binary_dependency()` from `cmake/DependencyManager.cmake`.
- Keep cached sources immutable in `.deps-cache/`; generated files and compiled dependencies belong to each build directory. Use `.deps-override/` for dependency development.
- Run `python3 scripts/check_deps_pinned.py` and `python3 tests/cmake/test_dependencies.py` after changing dependency metadata or the engine. Both are also registered with CTest.

## Code and repository conventions

- Format with the repository `.clang-format` (Google style, 4 spaces, 120 columns).
- Follow `.clang-tidy`, `.editorconfig`, and pre-commit configuration.
- Put reusable business logic in `src/core/`; keep CLI wiring in `src/main.cpp`.
- Add pure logic tests under `tests/unit/` and cross-library behavior under `tests/integration/`.
- Keep `STB_IMAGE_IMPLEMENTATION` centralized in `src/core/stb_impl.cpp`.
- Keep CLI results on stdout and diagnostics on stderr. `--json` emits one object;
  image errors must fail without partial stdout. Exercise this through `cli_contract`.

## Platform notes

- Retain MSVC UTF-8 handling and the `/MD` CRT policy in the dependency manager.
- GLFW is optional (`CPP_TEMPLATE_WITH_GLFW=ON`): a binary dependency on MSVC x64 and a source dependency on other supported desktop targets. Use `glfw::glfw`.
- See `README.md` for cache migration, offline builds, and supported presets. Use `ci` to test with local overrides disabled and project warnings treated as errors.

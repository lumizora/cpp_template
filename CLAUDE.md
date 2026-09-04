# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A minimal C++ project template centered on a pure-CMake (FetchContent) dependency manager. No Conan / vcpkg. Ships with presets, a layered static library + executable, unit/integration tests, benchmarks, code-style config, and pre-commit hooks. Cross-platform target (Win64 wired for the binary dependency).

## Build Commands

### Quick Start
```powershell
cmake --preset default
cmake --build --preset default
.\build\default\Release\cpp_template.exe --name world --repeat 3 --json
```

### Testing
```powershell
cmake --preset test --fresh      # BUILD_TESTING=ON
cmake --build --preset test
ctest --preset test
```

### Benchmarking
```powershell
cmake --preset bench --fresh     # BUILD_BENCHMARKING=ON
cmake --build --preset bench
.\build\bench\benchmarks\Release\bench_format.exe
```

### Offline/CI Builds
```powershell
cmake --preset offline --fresh   # Use pre-fetched .deps-cache, no network
cmake --preset ci                # No local overrides (.deps-override/)
```

## Architecture

- **`cpp_template_core`** (static lib, always built, cross-platform): example business logic.
  - `greeting.{h,cpp}` — `make_greeting()` via fmt, `build_info()` JSON via nlohmann_json, logging via spdlog.
  - `image_info.{h,cpp}` — `image_size()` via stb_image (header-only dependency).
  - `stb_impl.cpp` — centralized `STB_IMAGE_IMPLEMENTATION` unit.
  - Dependencies: `fmt`, `spdlog`, `nlohmann_json`, `stb` (all PRIVATE).
- **`cpp_template`** (executable): CLI11 CLI (`--name/--repeat/--json/--image/--verbose`), links `cpp_template_core`, and — when the GLFW binary dep exists — prints `glfwGetVersionString()` (`HAVE_GLFW` macro).

## Dependency Management

### Three Dependency Forms (all exercised by the template)

- **`add_dependency()`** — CMake-based source deps (git/URL). Used by `fmt`, `nlohmann_json`, `spdlog`, `CLI11`.
- **`add_header_dependency()`** — header-only libs without CMakeLists. Used by `stb`.
- **`add_binary_dependency()`** — precompiled binaries (download → SHA256 verify → IMPORTED target). Used by `glfw` (Win64, ~3 MB).

### Engine (`cmake/DependencyManager.cmake`)

- Shared source cache `.deps-cache/` (survives `build/` wipes).
- Enforced `/MD` CRT on MSVC.
- `OVERRIDE_FIND_PACKAGE` for transitive dedup (fmt → spdlog `SPDLOG_FMT_EXTERNAL=ON`).
- `GIT_SHALLOW` for large repos.
- Local override: `.deps-override/<name>`.
- Offline mode: `DEPS_OFFLINE=ON`.

### Manifest (`cmake/Dependencies.cmake`)

Lockfile. `GIT_TAG` pins versions (prefer 40-char SHA in production). Test/bench deps (googletest, benchmark) fetched only when `BUILD_TESTING` / `BUILD_BENCHMARKING` is ON.

### CI Check (`scripts/check_deps_pinned.py`)

Rejects floating refs (branch names, `HEAD`); requires valid `URL_HASH SHA256=<64hex>` for binary deps.

## Code Style

- `.clang-format`: Google style, 4 spaces, 120 columns.
- `.clang-tidy`: C++17 check set, excludes third-party headers.
- `.editorconfig`: UTF-8, LF, trailing newline, trim trailing whitespace.
- pre-commit hooks (`.pre-commit-config.yaml`): trailing whitespace, LF endings, clang-format, editorconfig, pinned deps.

## Platform Notes

- **Windows (MSVC)**: `/utf-8` compile option; `main.cpp` sets `SetConsoleOutputCP(CP_UTF8)`.
- **Binary dep (GLFW)**: Win64 only. DLL deployed via `binary_dep_deploy()`. To support other platforms, add their `(OS, arch)` blocks in `cmake/Dependencies.cmake`.

## File Organization

```
cpp-template/
├── cmake/
│   ├── DependencyManager.cmake    # Dependency engine (cache, ABI, offline, override)
│   └── Dependencies.cmake         # Lockfile (pinned versions, three forms)
├── src/
│   ├── core/                      # Static library cpp_template_core
│   └── main.cpp                   # CLI + demo wiring
├── tests/
│   ├── unit/                      # Pure logic tests (cpp_template_core only)
│   └── integration/               # fmt + spdlog + json interop
├── benchmarks/
│   └── bench_format.cpp
├── scripts/check_deps_pinned.py
├── .deps-cache/                   # FetchContent source cache (git-ignored)
├── .deps-override/                # Local dependency overrides (git-ignored)
└── build/                         # Per-preset build artifacts (git-ignored)
```

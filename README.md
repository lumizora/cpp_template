# cpp-template

一个以 **纯 CMake(FetchContent)依赖管理** 为核心的 C++ 项目模板,无 Conan / vcpkg
等外部包管理器。开箱即用:预设(preset)、分层静态库、单元/集成测试、性能基准、
代码规范与 pre-commit 钩子、离线可复现构建。

## 依赖管理(核心特性)

`cmake/DependencyManager.cmake` 是依赖引擎,`cmake/Dependencies.cmake` 是锁文件。
支持 **三种依赖形式**,模板中均有实例:

| 形式 | 引擎函数 | 模板实例 |
| --- | --- | --- |
| CMake 工程(源码) | `add_dependency()` | `fmt`、`nlohmann_json`、`spdlog`、`CLI11` |
| header-only(无 CMakeLists) | `add_header_dependency()` | `stb` |
| 预编译二进制 | `add_binary_dependency()` | `glfw`(Win64,约 3 MB) |

引擎能力:

- **共享源码缓存** `.deps-cache/`(跨构建目录复用,`build/` 删除后仍保留)。
- **离线可复现**:`cmake --preset offline`(`DEPS_OFFLINE=ON`)纯用缓存,不联网。
- **ABI 一致**:MSVC 下强制 `/MD` 动态 CRT,避免多静态库 stdio 缓冲隔离。
- **传递依赖去重**:fmt 经 `EXPOSE_FIND_PACKAGE` 声明,spdlog 用
  `SPDLOG_FMT_EXTERNAL=ON` 复用同一份 fmt,无 ODR 冲突。
- **本地覆盖**:把依赖 checkout 到 `.deps-override/<name>` 即替换拉取版本。
- **供应链校验**:二进制依赖 `URL_HASH SHA256=<64hex>` 必填,`file(DOWNLOAD
  EXPECTED_HASH)` 不一致即失败。
- `scripts/check_deps_pinned.py`:CI 校验源码依赖禁止浮动引用(分支名/HEAD),
  二进制依赖必须有合法 SHA256。

## 快速开始

```powershell
cmake --preset default
cmake --build --preset default
.\build\default\Release\cpp_template.exe --name world --repeat 3 --json
```

首次配置由 FetchContent 拉取依赖到 `.deps-cache/`,之后可离线:

```powershell
cmake --preset offline --fresh   # 不联网,纯缓存
```

## 源码结构

```
src/
├── core/                # 静态库 cpp_template_core(示例业务逻辑)
│   ├── greeting.{h,cpp} # fmt + spdlog + nlohmann_json
│   ├── image_info.{h,cpp}  # stb_image(header-only 依赖示例)
│   └── stb_impl.cpp     # STB_IMAGE_IMPLEMENTATION 单实现单元
└── main.cpp             # CLI11 + core + GLFW 版本(二进制依赖示例)
```

分层:纯逻辑核心库与可执行程序分离,核心库无二进制依赖,跨平台可测。

## 添加一个新依赖

```cmake
# cmake/Dependencies.cmake
add_dependency(newlib
  VERSION 1.0.0
  GIT_REPOSITORY https://github.com/org/newlib.git
  GIT_TAG v1.0.0            # 生产建议 40 位 commit SHA
  GIT_SHALLOW
  SYSTEM
  CMAKE_ARGS -DNEWLIB_TESTS=OFF)
```

```cmake
# CMakeLists.txt
target_link_libraries(cpp_template_core PRIVATE newlib::newlib)
```

- header-only 且无 CMakeLists → `add_header_dependency()`。
- 源码编译极慢 / 仅提供预编译包 → `add_binary_dependency()` + `binary_dep_deploy()`。
- 生产环境把 `GIT_TAG` 换成 40 位 SHA:`git ls-remote <url> refs/tags/<tag>`。
- 二进制依赖 SHA256 取值(Windows):`certutil -hashfile <file.zip> SHA256`。

## 测试

```powershell
cmake --preset test --fresh      # BUILD_TESTING=ON,拉取 gtest
cmake --build --preset test
ctest --preset test
```

- `tests/unit/test_greeting.cpp` — 核心库行为(仅链接 `cpp_template_core`,跨平台)。
- `tests/integration/test_deps.cpp` — fmt + spdlog + json 联用,验证依赖去重。

## 性能基准

```powershell
cmake --preset bench --fresh     # BUILD_BENCHMARKING=ON,拉取 benchmark 库
cmake --build --preset bench
.\build\bench\benchmarks\Release\bench_format.exe
```

- 过滤:`--benchmark_filter=Format`;输出 JSON:`--benchmark_format=json`。

## 代码规范

- `.clang-format` — 基于 Google,4 空格 / 120 列。
- `.clang-tidy` — C++17 检查集,排除第三方头。
- `.editorconfig` — UTF-8 / LF / 尾行换行 / 去尾空格。
- pre-commit:`pip install pre-commit && pre-commit install`。

## 许可

模板代码按你的项目需求选择许可证;依赖许可证见各自仓库(fmt/spdlog/nlohmann_json/
CLI11/stb/GLFW 均为宽松许可)。

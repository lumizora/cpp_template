# cpp-template

C++17 项目模板：纯 CMake / FetchContent、静态核心库、CLI、测试及可选图形依赖示例。
需要 CMake >= 3.25、Ninja 和 C++17 编译器；测试另需 Python >= 3.8 与 Git。
Windows 使用已初始化 MSVC 环境的终端，例如 Developer PowerShell。

## 构建与测试

```sh
cmake --preset default
cmake --build --preset default

cmake --preset test --fresh
cmake --build --preset test
ctest --preset test
```

产物位于 `build/<preset>/bin/<configuration>/`。例如：

```sh
./build/default/bin/Release/cpp_template --name world --repeat 3
```

Windows 对应 `build/default/bin/Release/cpp_template.exe`。

| Preset | 用途 |
| --- | --- |
| `default` | 默认 Release，无图形系统依赖 |
| `debug`（仅 build） | 在 `default` 配置目录构建 Debug |
| `test` | GoogleTest + 依赖引擎回归检查 |
| `ci` | 测试开启、自有代码警告视为错误、禁止本地覆盖和系统包偏好 |
| `offline` | 从匹配的依赖缓存配置、构建 |
| `bench` | Google Benchmark 示例 |
| `sanitize` | GCC/Clang、Unix 平台 Debug ASan + UBSan |
| `analyze` | 编译自有 target 时实际执行 clang-tidy |
| `release` | 严格依赖配置、安装与 TGZ/ZIP 应用包 |

`sanitize` 和 `analyze` 使用单配置 Ninja，程序位于 `build/<preset>/bin/`。

```sh
cmake --preset bench
cmake --build --preset bench
./build/bench/bin/Release/bench_format
```

## CLI 契约

`--version` 输出 CMake 项目版本。正常结果写入 stdout，日志/错误写入 stderr；
参数错误或图片读取失败返回非零退出码。
`--json` 始终输出单个 JSON 对象，包含 `project`、`version`、`greeting`、`repeat`，
不随 `--repeat` 重复输出对象；`--image` 成功时增加 `image` 的路径、宽、高、通道数。
图片失败时 stdout 为空。旧 JSON 中硬编码的 `deps` 字段已移除，实际依赖记录随发布包交付。

```sh
./build/default/bin/Release/cpp_template --json --verbose --name world
./build/default/bin/Release/cpp_template --json --image "图片 with spaces.png"
```

## 基座边界

- `src/core/`：可复用逻辑；`cpp_template::core` 是 `cpp_template_core` 的别名。
- `src/main.cpp`：CLI 接线。公共核心头文件使用标准库类型，不暴露第三方类型。
- `cmake/Dependencies.cmake`：唯一依赖清单，所有现有下载内容由 SHA256 固定。
- `cmake/DependencyManager.cmake`：三种依赖入口与共享的参数、缓存、离线策略。
- `tests/`：C++ 行为测试，以及无需网络的依赖引擎回归检查。

C++17、警告和 UTF-8 选项只应用于自有 target；MSVC 源码依赖与项目使用统一 CRT 默认策略。

## 缓存与离线

下载源码按仓库/ref 或 URL/hash 区分，存入 `.deps-cache/sources/<name>/<key>/src`；
二进制包按平台和内容标识存入 `.deps-cache/binary/`。同一个缓存项的填充由文件锁保护，
成功配置或布局校验后才写入完成标记。不同 pin 不会覆盖旧版本。

所有生成文件、依赖编译目录和下载子构建都位于 `build/<preset>/`，不跨构建目录共享。
`DEPS_CACHE_DIR` 可指定共享下载源码缓存位置。缓存源码不要直接修改；开发依赖使用本地覆盖。

先完成一次在线配置，再使用离线 preset；所需 pin 未缓存时会明确失败：

```sh
cmake --preset test
cmake --preset offline -DBUILD_TESTING=ON -DDEPS_ALLOW_OVERRIDE=OFF
cmake --build --preset offline
ctest --test-dir build/offline -C Release --output-on-failure --no-tests=error
```

迁移旧版本时，各 build 目录第一次配置请加 `--fresh`。旧缓存不会被删除，
但原来的 `<name>-src` 布局不视作已验证的新缓存，首次迁移需要联网重新填充。

## 修改依赖

继续使用三个入口：`add_dependency()`、`add_header_dependency()`、`add_binary_dependency()`。
源码支持 `URL + URL_HASH SHA256=...` 或 `GIT_REPOSITORY + GIT_TAG`。
Git tag 仅接受版本标签或 40 位 SHA；生产清单优先使用带哈希的归档。
`GIT_SHALLOW` 仅适用于版本标签，不能与 commit SHA 混用。
`CMAKE_ARGS -DOPTION=VALUE` 在源码依赖作用域设置选项，不强制覆盖父工程 cache。

本地覆盖放在 `.deps-override/<name>`（名称小写），或通过 `DEPS_OVERRIDE_DIR` 指定根目录。
也支持显式 `FETCHCONTENT_SOURCE_DIR_<UPPERCASE_NAME>`。
自动覆盖不会被写入 CMake cache；`DEPS_ALLOW_OVERRIDE=OFF` 会拒绝显式覆盖。
`DEPS_PREFER_PACKAGE=ON` 仅用于开发环境，使用已安装包时不属于清单锁定的构建。

清单修改后运行：

```sh
python3 scripts/check_deps_pinned.py
python3 tests/cmake/test_dependencies.py
```

清单检查使用 CMake 自身解析规则，检查 Windows、Linux、macOS 以及测试/基准分支。

## 可选 GLFW 示例

```sh
cmake --preset default -DCPP_TEMPLATE_WITH_GLFW=ON
cmake --build --preset default
```

MSVC x64 使用官方 GLFW 3.4 DLL，其余支持的桌面平台从源码构建。
Linux 示例使用 X11，Ubuntu/Debian 额外安装：

```sh
sudo apt install libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev
```

应用只查询 GLFW 版本，不包含 OpenGL 头文件，也不创建窗口。
二进制入口当前面向 Release 共享库，其他标准配置默认拒绝隐式回退。
确认工具链、架构及跨 DLL 的 ABI/内存所有权兼容后，才可声明 `ALLOW_RELEASE_FALLBACK`。
GLFW 的 C ABI 示例显式开启此选项；不要将它当成适用于任意 C++ DLL 的默认策略。

## 质量检查与发布

```sh
cmake --preset sanitize --fresh
cmake --build --preset sanitize
ctest --preset sanitize

# 先将 clang-tidy 加入 PATH；CI 固定使用 22.1.8。
cmake --preset analyze --fresh
cmake --build --preset analyze

cmake --preset release --fresh
cmake --build --preset release
ctest --preset release
cmake --install build/release --config Release --prefix "$PWD/build/install" --component Runtime
cpack --config build/release/CPackConfig.cmake -C Release -B build/packages
```

Sanitizer 作用于自有代码（含 stb 实现所在编译单元），不承诺覆盖预编译库或其他依赖内部。
发布要求关闭本地覆盖、系统包偏好和 Sanitizer，只允许 Release 安装。
包中包含应用、所需第三方共享库（如有）、许可证，以及
`share/cpp_template/dependencies.json` 和 `build-info.json`，记录实际启用的运行时依赖
版本/来源/hash 与构建工具链。测试/基准依赖不随包交付。
发布测试会搬移安装目录、解压两种归档，再清除库搜索环境变量并执行程序。

这是应用分发基座，不是 SDK 导出；不打包操作系统框架或 Linux 系统运行库，
也不承诺跨架构或跨系统版本兼容。依赖清单不是标准 SPDX/CycloneDX SBOM，
签名、漏洞扫描、SDK 导出及 PCH/LTO 在有明确交付或性能要求时再接入。

## 自动化与代码规范

`.github/workflows/ci.yml` 覆盖 Windows/MSVC、Linux/GCC 与 Clang、macOS/AppleClang，
包括 CMake 3.25 基线、Release/Debug、静态/共享依赖、可选 GLFW、基准编译、
全新离线构建、安装/归档验证，以及独立的 clang-tidy 和 ASan/UBSan 作业。

格式遵循 `.clang-format`、`.editorconfig`；静态分析配置为 `.clang-tidy`。

```sh
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

## 许可证

模板代码采用 [MIT License](LICENSE)。第三方依赖遵循各自源码中的许可证。

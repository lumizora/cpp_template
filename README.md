# cpp-template

一个以 **纯 CMake(FetchContent) 依赖管理** 为核心的 C++ 项目模板，无 Conan / vcpkg 等外部包管理器。

开箱即用：

- CMake Presets
- Ninja Multi-Config
- 分层静态库结构
- 单元测试 / 集成测试
- 性能基准
- 代码规范与 pre-commit 钩子
- 离线可复现构建
- Windows / Linux / macOS 跨平台构建

## 依赖管理(核心特性)

`cmake/DependencyManager.cmake` 是依赖引擎，
`cmake/Dependencies.cmake` 是依赖锁文件。

支持三种依赖形式：

| 形式 | 引擎函数 | 模板实例 |
| --- | --- | --- |
| CMake 工程(源码) | `add_dependency()` | `fmt`、`nlohmann_json`、`spdlog`、`CLI11`、`GLFW(Linux/macOS)` |
| header-only(无 CMakeLists) | `add_header_dependency()` | `stb` |
| 预编译二进制 | `add_binary_dependency()` | `GLFW(Windows x64)` |

## 快速开始

### Windows

```powershell
cmake --preset default
cmake --build --preset default

.\build\default\Release\cpp_template.exe --name world --repeat 3 --json
```

### Linux

安装依赖：

```bash
sudo apt update

sudo apt install -y \
    build-essential \
    ninja-build \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev
```

构建：

```bash
cmake --preset default
cmake --build --preset default
```

## CMake Presets

| preset | 用途 |
| --- | --- |
| `default` | 默认 Release 构建 |
| `offline` | 离线构建 |
| `test` | 单元测试 |
| `bench` | 性能基准 |

## GLFW 跨平台策略

| 平台 | 方式 |
| --- | --- |
| Windows x64 | 官方预编译包 |
| Linux | 源码构建 |
| macOS | 源码构建 |

应用层统一：

```cmake
target_link_libraries(
    app
    PRIVATE
    glfw::glfw
)
```

无需关心平台差异。

## 添加新依赖

### CMake 工程依赖

```cmake
add_dependency(newlib
  VERSION 1.0.0
  GIT_REPOSITORY https://github.com/org/newlib.git
  GIT_TAG v1.0.0
  GIT_SHALLOW
  SYSTEM
)
```

### Header-only

```cmake
add_header_dependency(stb)
```

### 二进制依赖

```cmake
add_binary_dependency(glfw
  VERSION 3.4
  URL ...
  URL_HASH SHA256=<hash>
  IMPLIB xxx.lib
  RUNTIME xxx.dll
)
```

## 测试

```bash
cmake --preset test --fresh
cmake --build --preset test
ctest --preset test
```

## 性能基准

```bash
cmake --preset bench --fresh
cmake --build --preset bench
```

## 代码规范

- `.clang-format`
- `.clang-tidy`
- `.editorconfig`
- pre-commit

安装：

```bash
pip install pre-commit
pre-commit install
```

运行：

```bash
pre-commit run --all-files
```

## CI Matrix

推荐：

```
Windows
 └── MSVC

Linux
 ├── GCC
 └── Clang

macOS
 └── AppleClang
```

统一执行：

```bash
cmake --preset default
cmake --build --preset default
ctest --preset test
```

## License

模板代码许可证根据项目需求选择。

第三方依赖许可证：

- fmt
- spdlog
- nlohmann_json
- CLI11
- stb
- GLFW

均以各自仓库 LICENSE 文件为准。

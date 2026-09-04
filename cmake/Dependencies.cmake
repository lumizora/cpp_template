# ---------------------------------------------------------------------------
# 依赖清单 = 锁文件
#
# 覆盖 cmake/DependencyManager.cmake 支持的三种依赖形式:
#   1) add_dependency(...)         CMake 工程(源码拉取,git/URL + GIT_TAG 钉死)
#   2) add_header_dependency(...)   header-only 无 CMakeLists(如 stb)
#   3) add_binary_dependency(...)  预编译二进制(下载 -> SHA256 校验 -> IMPORTED)
#
# 生产环境请把 GIT_TAG 换成 40 位 commit SHA(逐字节可复现):
#   git ls-remote https://github.com/fmtlib/fmt.git refs/tags/10.2.1
# 此处用版本 tag 保证可构建;check_deps_pinned.py 允许版本 tag,但禁止分支名。
#
# GIT_SHALLOW:--depth 1 浅克隆。nlohmann_json 全量历史约 273MB,浅克隆仅几 MB。
# 注意:GIT_TAG 为 commit SHA 时 FetchContent 会忽略 GIT_SHALLOW(浅克隆按 SHA
# 不可靠);届时大仓库应改用 URL+URL_HASH:
#   curl -sL https://github.com/nlohmann/json/archive/refs/tags/v3.11.3.tar.gz | sha256sum
#   add_dependency(nlohmann_json URL <tarball> URL_HASH sha256=<hash> ...)
#
# 声明顺序很重要:被 EXPOSE_FIND_PACKAGE 的叶子库必须先于依赖它的库。
# fmt 先声明并 EXPOSE,spdlog 用 SPDLOG_FMT_EXTERNAL=ON 内部 find_package(fmt)
# 时会被重定向到同一份 fmt -- 传递依赖去重。
# ---------------------------------------------------------------------------

# ===========================================================================
# 形式 1:add_dependency -- CMake 工程依赖(git 源码拉取)
# ===========================================================================

add_dependency(fmt
  VERSION 10.2.1
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG        10.2.1
  GIT_SHALLOW
  EXPOSE_FIND_PACKAGE SYSTEM
  CMAKE_ARGS -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=OFF)

add_dependency(nlohmann_json
  VERSION 3.11.3
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG        v3.11.3
  GIT_SHALLOW
  EXPOSE_FIND_PACKAGE SYSTEM
  CMAKE_ARGS -DJSON_Testing=OFF -DJSON_Install=OFF)

add_dependency(spdlog
  VERSION 1.13.0
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG        v1.13.0
  GIT_SHALLOW
  SYSTEM
  CMAKE_ARGS -DSPDLOG_FMT_EXTERNAL=ON        # 复用上面的 fmt,不再内嵌
             -DSPDLOG_BUILD_TESTS=OFF
             -DSPDLOG_BUILD_EXAMPLE=OFF
             -DSPDLOG_INSTALL=OFF)

# CLI11:现代 C++ 命令行参数解析(header-only,自带 CMake target CLI11::CLI11)。
add_dependency(cli11
  VERSION 2.7.2
  GIT_REPOSITORY https://github.com/CLIUtils/CLI11.git
  GIT_TAG        v2.7.2
  GIT_SHALLOW
  SYSTEM
  CMAKE_ARGS -DCLI11_BUILD_TESTS=OFF
             -DCLI11_BUILD_EXAMPLES=OFF
             -DCLI11_BUILD_DOCS=OFF
             -DCLI11_INSTALL=OFF)

# ===========================================================================
# 形式 2:add_header_dependency -- header-only 无 CMakeLists(如 stb)
# ===========================================================================
# stb:单文件图像库(读取尺寸等)。无构建脚本,走专用引擎函数:FetchContent 取
# 源码 -> INTERFACE 库(仅暴露 include 路径),不经 add_subdirectory。
# GIT_TAG 为 commit SHA(逐字节可复现);stb 无 semver tag。
add_header_dependency(stb
  GIT_REPOSITORY https://github.com/nothings/stb.git
  GIT_TAG        2c980bb59875b0d32144a71867fbdebb2f77cd20
  SYSTEM)

# ===========================================================================
# 形式 3:add_binary_dependency -- 预编译二进制(下载 + SHA256 校验)
# ===========================================================================
# 轻量级示例:GLFW(窗口库)官方预编译 Win64 包,约 3 MB,相比 ONNX Runtime /
# FFmpeg 这类数百 MB 的重型包更适合做模板示例。下载 -> URL_HASH 校验 -> 解压
# -> IMPORTED 目标。平台强绑定:每个 (OS,arch) 各 pin 一份 URL + SHA256。
# SHA256 取值:certutil -hashfile glfw-3.4.bin.WIN64.zip SHA256
if(WIN32 AND CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
  add_binary_dependency(glfw
    VERSION     3.4
    URL         https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.bin.WIN64.zip
    URL_HASH    SHA256=54EFA829400F2A0537F742B2B3BDD74E437BB4F2F048E4B7D3C5557D11A611E6
    SUBDIR      glfw-3.4.bin.WIN64
    INCLUDE_DIR include
    IMPLIB      lib-vc2022/glfw3dll.lib
    RUNTIME     lib-vc2022/glfw3.dll
    SYSTEM)
endif()

# ===========================================================================
# 测试 / 基准依赖(仅对应开关 ON 时拉取,与生产依赖同机制)
# ===========================================================================

if(BUILD_TESTING)
  add_dependency(googletest
    VERSION 1.14.0
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.14.0
    GIT_SHALLOW
    SYSTEM
    CMAKE_ARGS -DINSTALL_GTEST=OFF)
endif()

if(BUILD_BENCHMARKING)
  add_dependency(benchmark
    VERSION 1.9.5
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG        v1.9.5
    GIT_SHALLOW
    SYSTEM
    CMAKE_ARGS -DBENCHMARK_ENABLE_TESTING=OFF
               -DBENCHMARK_INSTALL=OFF)
endif()

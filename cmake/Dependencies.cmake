# ---------------------------------------------------------------------------
# 依赖清单 = 锁文件
#
# 覆盖 cmake/DependencyManager.cmake 支持的三种依赖形式:
#   1) add_dependency(...)         CMake 工程(源码拉取,git/URL + pin)
#   2) add_header_dependency(...)  header-only 无 CMakeLists(如 stb)
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
#   add_dependency(nlohmann_json URL <tarball> URL_HASH SHA256=<hash> ...)
#
# 声明顺序很重要:被 EXPOSE_FIND_PACKAGE 的叶子库必须先于依赖它的库。
# fmt 先声明并 EXPOSE,spdlog 用 SPDLOG_FMT_EXTERNAL=ON 内部 find_package(fmt)
# 时会被重定向到同一份 fmt -- 传递依赖去重。
# ---------------------------------------------------------------------------

# ===========================================================================
# 形式 1:add_dependency -- CMake 工程依赖(git / URL 源码拉取)
# ===========================================================================

add_dependency(fmt
  VERSION 10.2.1
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG        10.2.1
  GIT_SHALLOW
  EXPOSE_FIND_PACKAGE
  SYSTEM
  CMAKE_ARGS
    -DFMT_TEST=OFF
    -DFMT_DOC=OFF
    -DFMT_INSTALL=OFF)

add_dependency(nlohmann_json
  VERSION 3.11.3
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG        v3.11.3
  GIT_SHALLOW
  EXPOSE_FIND_PACKAGE
  SYSTEM
  CMAKE_ARGS
    -DJSON_Testing=OFF
    -DJSON_Install=OFF)

add_dependency(spdlog
  VERSION 1.13.0
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG        v1.13.0
  GIT_SHALLOW
  SYSTEM
  CMAKE_ARGS
    -DSPDLOG_FMT_EXTERNAL=ON        # 复用上面的 fmt,不再内嵌
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
  CMAKE_ARGS
    -DCLI11_BUILD_TESTS=OFF
    -DCLI11_BUILD_EXAMPLES=OFF
    -DCLI11_BUILD_DOCS=OFF
    -DCLI11_INSTALL=OFF)

# ===========================================================================
# 形式 2:add_header_dependency -- header-only 无 CMakeLists(如 stb)
# ===========================================================================
#
# stb:单文件图像库(读取尺寸等)。无构建脚本,走专用引擎函数:
# FetchContent 取源码 -> INTERFACE 库(仅暴露 include 路径),不经 add_subdirectory。
# GIT_TAG 为 commit SHA(逐字节可复现);stb 无 semver tag。
add_header_dependency(stb
  GIT_REPOSITORY https://github.com/nothings/stb.git
  GIT_TAG        2c980bb59875b0d32144a71867fbdebb2f77cd20
  SYSTEM)

# ===========================================================================
# GLFW -- 平台差异示例
# ===========================================================================
#
# Windows x64:
#   GLFW 官方提供预编译 WIN64 包,走 add_binary_dependency。
#
# Linux:
#   GLFW 官方 release 不提供 Linux 预编译二进制包,走源码构建。
#   仍然使用 add_dependency,因此完整继承:
#     .deps-cache / DEPS_OFFLINE / .deps-override / SYSTEM / CMAKE_ARGS
#
#   Linux 默认构建 X11 backend:
#     - 适用于 Ubuntu / GitHub Codespaces / CI
#     - 避免 Wayland 开发依赖
#
#   Ubuntu/Debian 需要安装:
#
#     编译工具:
#       build-essential
#       ninja-build
#
#     X11:
#       libx11-dev
#       libxrandr-dev
#       libxinerama-dev
#       libxcursor-dev
#       libxi-dev
#
#     OpenGL:
#       libgl1-mesa-dev
#       libglu1-mesa-dev
#
#   其中:
#
#       libgl1-mesa-dev
#
#   提供:
#
#       /usr/include/GL/gl.h
#
#   缺少时会导致:
#
#       fatal error:
#           GL/gl.h: No such file or directory
#
#
# macOS:
#   虽有官方预编译包,这里统一走源码构建,减少平台二进制清单维护成本。
#
#
# 上层统一链接 glfw::glfw:
#
#   Windows binary target:
#       add_binary_dependency
#           -> glfw::glfw
#
#   Linux/macOS:
#       add_dependency
#           -> glfw
#           -> glfw::glfw ALIAS
#
# ===========================================================================


if(WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64)$")


  # SHA256:
  #
  #   certutil -hashfile glfw-3.4.bin.WIN64.zip SHA256
  #
  add_binary_dependency(glfw

    VERSION 3.4

    URL
      https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.bin.WIN64.zip

    URL_HASH
      SHA256=54EFA829400F2A0537F742B2B3BDD74E437BB4F2F048E4B7D3C5557D11A611E6

    SUBDIR
      glfw-3.4.bin.WIN64

    INCLUDE_DIR
      include

    IMPLIB
      lib-vc2022/glfw3dll.lib

    RUNTIME
      lib-vc2022/glfw3.dll

    SYSTEM
  )


elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")


  # Linux/Codespaces:
  #
  # GLFW 官方不提供 Linux 预编译 binary release,
  # 因此采用源码构建。
  #
  # URL tarball + SHA256:
  #
  #   相比 GIT_TAG:
  #     - 内容固定
  #     - 可复现
  #     - 更符合依赖锁文件语义
  #
  #
  # Ubuntu/Debian 系统依赖:
  #
  #   sudo apt install \
  #       build-essential \
  #       ninja-build \
  #       libgl1-mesa-dev \
  #       libglu1-mesa-dev \
  #       libx11-dev \
  #       libxrandr-dev \
  #       libxinerama-dev \
  #       libxcursor-dev \
  #       libxi-dev


  add_dependency(glfw

    VERSION 3.4

    URL
      https://github.com/glfw/glfw/archive/refs/tags/3.4.tar.gz

    URL_HASH
      SHA256=c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01

    SYSTEM

    CMAKE_ARGS

      # Linux window backend
      -DGLFW_BUILD_X11=ON
      -DGLFW_BUILD_WAYLAND=OFF

      # 不构建 GLFW 附带内容
      -DGLFW_BUILD_DOCS=OFF
      -DGLFW_BUILD_TESTS=OFF
      -DGLFW_BUILD_EXAMPLES=OFF

      # 第三方依赖,不执行安装
      -DGLFW_INSTALL=OFF
  )


  # 统一 target:
  #
  # Windows:
  #   glfw::glfw
  #
  # Linux:
  #   glfw
  #
  # 统一:
  #   glfw::glfw

  if(TARGET glfw AND NOT TARGET glfw::glfw)

    add_library(
      glfw::glfw
      ALIAS
      glfw
    )

  endif()


elseif(APPLE)


  add_dependency(glfw

    VERSION 3.4

    URL
      https://github.com/glfw/glfw/archive/refs/tags/3.4.tar.gz

    URL_HASH
      SHA256=c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01

    SYSTEM

    CMAKE_ARGS

      # macOS backend
      -DGLFW_BUILD_COCOA=ON

      # 不构建 GLFW 附带内容
      -DGLFW_BUILD_DOCS=OFF
      -DGLFW_BUILD_TESTS=OFF
      -DGLFW_BUILD_EXAMPLES=OFF

      # 第三方依赖,不执行安装
      -DGLFW_INSTALL=OFF
  )


  if(TARGET glfw AND NOT TARGET glfw::glfw)

    add_library(
      glfw::glfw
      ALIAS
      glfw
    )

  endif()


else()


  message(FATAL_ERROR
    "Unsupported GLFW platform: "
    "${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}"
  )


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
    CMAKE_ARGS
      -DINSTALL_GTEST=OFF)
endif()

if(BUILD_BENCHMARKING)
  add_dependency(benchmark
    VERSION 1.9.5
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG        v1.9.5
    GIT_SHALLOW
    SYSTEM
    CMAKE_ARGS
      -DBENCHMARK_ENABLE_TESTING=OFF
      -DBENCHMARK_INSTALL=OFF)
endif()

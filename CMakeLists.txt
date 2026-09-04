cmake_minimum_required(VERSION 3.25)
project(cpp_template LANGUAGES C CXX)

# ---- 全局编译标准 ----------------------------------------------------------
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# MSVC:源文件为 UTF-8。不加 /utf-8 时 MSVC 按系统代码页(如 936/GBK)解析,
# 注释中 UTF-8 中文字符若含 0x5C(反斜杠)会被当作行续接,吞掉下一行代码。
if(MSVC)
  add_compile_options(/utf-8)
endif()

# ---- 测试 / 基准开关 -------------------------------------------------------
# 必须早于依赖清单:Dependencies.cmake 据此决定是否拉取 GoogleTest / Benchmark。
option(BUILD_TESTING      "构建单元测试与集成测试" OFF)
option(BUILD_BENCHMARKING "构建性能基准"            OFF)

# ---- 依赖引擎 + 清单 -------------------------------------------------------
# 引擎设置 ABI 策略,必须在拉取任何依赖之前 include。
list(APPEND CMAKE_MESSAGE_CONTEXT "deps")
include(${CMAKE_SOURCE_DIR}/cmake/DependencyManager.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/Dependencies.cmake)
list(POP_BACK CMAKE_MESSAGE_CONTEXT)

# ===========================================================================
# 分层示例:纯逻辑核心库 + 可执行程序
# ===========================================================================

# ---- cpp_template_core:示例业务逻辑(跨平台)--------------------------------
# 演示 add_dependency(fmt/spdlog/nlohmann_json) 与 add_header_dependency(stb)。
# 依赖均仅 .cpp 使用 -> PRIVATE;对外接口只暴露标准库类型。
add_library(cpp_template_core STATIC
  src/core/greeting.cpp
  src/core/image_info.cpp
  src/core/stb_impl.cpp)
target_include_directories(cpp_template_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(cpp_template_core
  PRIVATE
    fmt::fmt
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    stb::stb)

# ---- 主程序 ----------------------------------------------------------------
add_executable(cpp_template src/main.cpp)
target_link_libraries(cpp_template
  PRIVATE
    cpp_template_core
    CLI11::CLI11
    spdlog::spdlog)

# 二进制依赖示例(GLFW,Win64):可用时链接 + 部署 DLL + 打开 HAVE_GLFW 宏。
if(TARGET glfw::glfw)
  target_link_libraries(cpp_template PRIVATE glfw::glfw)
  target_compile_definitions(cpp_template PRIVATE HAVE_GLFW=1)
  binary_dep_deploy(cpp_template glfw)      # DLL 复制到 exe 旁
endif()

# ---- 测试 ------------------------------------------------------------------
if(BUILD_TESTING)
  enable_testing()
  add_subdirectory(tests)
endif()

# ---- 性能基准 --------------------------------------------------------------
if(BUILD_BENCHMARKING)
  add_subdirectory(benchmarks)
endif()

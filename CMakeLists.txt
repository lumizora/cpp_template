cmake_minimum_required(VERSION 3.25)

project(
  cpp_template
  LANGUAGES C CXX
)


# ---------------------------------------------------------------------------
# 全局输出目录
# ---------------------------------------------------------------------------

set(CMAKE_EXPORT_COMPILE_COMMANDS
    ON
    CACHE BOOL
    "Export compile_commands.json")


set(CMAKE_RUNTIME_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/lib)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/lib)


# ---------------------------------------------------------------------------
# MSVC UTF-8
# ---------------------------------------------------------------------------

if(MSVC)
  add_compile_options(/utf-8)
endif()


# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

option(
  BUILD_TESTING
  "构建单元测试与集成测试"
  OFF)

option(
  BUILD_BENCHMARKING
  "构建性能基准"
  OFF)


# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

list(APPEND CMAKE_MESSAGE_CONTEXT deps)

include(
  ${CMAKE_SOURCE_DIR}/cmake/DependencyManager.cmake)

include(
  ${CMAKE_SOURCE_DIR}/cmake/Dependencies.cmake)

list(POP_BACK CMAKE_MESSAGE_CONTEXT)



# ---------------------------------------------------------------------------
# Core Library
# ---------------------------------------------------------------------------

add_library(
  cpp_template_core STATIC

  src/core/greeting.cpp
  src/core/image_info.cpp
  src/core/stb_impl.cpp
)


target_compile_features(
  cpp_template_core
  PUBLIC
  cxx_std_17
)


target_include_directories(
  cpp_template_core

  PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)


target_link_libraries(
  cpp_template_core

  PRIVATE
    fmt::fmt
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    stb::stb
)



# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

add_executable(
  cpp_template

  src/main.cpp
)


target_link_libraries(
  cpp_template

  PRIVATE
    cpp_template_core
    CLI11::CLI11
    spdlog::spdlog
)



# ---------------------------------------------------------------------------
# GLFW
# ---------------------------------------------------------------------------

if(TARGET glfw::glfw)

  target_link_libraries(
    cpp_template
    PRIVATE
    glfw::glfw
  )


  target_compile_definitions(
    cpp_template
    PRIVATE
    HAVE_GLFW=1
  )


  if(DEFINED glfw_RUNTIME_LIBS
     AND glfw_RUNTIME_LIBS)

    binary_dep_deploy(
      cpp_template
      glfw
    )

  endif()

endif()



# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

if(BUILD_TESTING)

  enable_testing()

  add_subdirectory(tests)

endif()



# ---------------------------------------------------------------------------
# Benchmarks
# ---------------------------------------------------------------------------

if(BUILD_BENCHMARKING)

  add_subdirectory(benchmarks)

endif()

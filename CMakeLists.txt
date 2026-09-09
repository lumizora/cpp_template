cmake_minimum_required(VERSION 3.25)
project(cpp_template VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")

option(BUILD_TESTING "Build unit and integration tests" OFF)
option(BUILD_BENCHMARKING "Build benchmarks" OFF)
option(CPP_TEMPLATE_WITH_GLFW "Build the optional GLFW dependency example" OFF)
option(CPP_TEMPLATE_WARNINGS_AS_ERRORS "Treat project warnings as errors" OFF)
option(CPP_TEMPLATE_SANITIZERS "Enable AddressSanitizer and UndefinedBehaviorSanitizer" OFF)
option(CPP_TEMPLATE_CLANG_TIDY "Run clang-tidy on project targets" OFF)
option(CPP_TEMPLATE_PACKAGING "Enable application installation and release archives" OFF)

if(CPP_TEMPLATE_SANITIZERS AND (WIN32 OR NOT CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang"))
  message(FATAL_ERROR "ASan/UBSan preset requires GCC or Clang on a Unix-like platform")
endif()
if(CPP_TEMPLATE_CLANG_TIDY)
  find_program(CPP_TEMPLATE_CLANG_TIDY_EXECUTABLE NAMES clang-tidy REQUIRED)
endif()

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/DependencyManager.cmake")
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/Dependencies.cmake")

# Apply policies to our targets only, not to third-party projects.
function(cpp_template_target_defaults target)
  target_compile_features(${target} PRIVATE cxx_std_17)
  target_compile_definitions(${target} PRIVATE CPP_TEMPLATE_VERSION="${PROJECT_VERSION}")
  set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF
    COMPILE_WARNING_AS_ERROR "${CPP_TEMPLATE_WARNINGS_AS_ERRORS}")
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /utf-8)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
  endif()
  if(CPP_TEMPLATE_SANITIZERS)
    target_compile_options(${target} PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all)
    # Static core consumers need to link the sanitizer runtime too.
    target_link_options(${target} PUBLIC -fsanitize=address,undefined -fno-sanitize-recover=all)
  endif()
  if(CPP_TEMPLATE_CLANG_TIDY)
    set_property(TARGET ${target} PROPERTY CXX_CLANG_TIDY "${CPP_TEMPLATE_CLANG_TIDY_EXECUTABLE}")
  endif()
endfunction()

add_library(cpp_template_core STATIC
  src/core/greeting.cpp
  src/core/image_info.cpp
  src/core/stb_impl.cpp)
add_library(cpp_template::core ALIAS cpp_template_core)
target_compile_features(cpp_template_core PUBLIC cxx_std_17)
target_include_directories(cpp_template_core PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(cpp_template_core PRIVATE
  fmt::fmt spdlog::spdlog nlohmann_json::nlohmann_json stb::stb)
cpp_template_target_defaults(cpp_template_core)

add_executable(cpp_template src/main.cpp)
target_link_libraries(cpp_template PRIVATE cpp_template_core CLI11::CLI11 spdlog::spdlog nlohmann_json::nlohmann_json)
cpp_template_target_defaults(cpp_template)

if(CPP_TEMPLATE_WITH_GLFW)
  target_link_libraries(cpp_template PRIVATE glfw::glfw)
  target_compile_definitions(cpp_template PRIVATE HAVE_GLFW=1 GLFW_INCLUDE_NONE)
  binary_dep_deploy(cpp_template glfw)
endif()

if(BUILD_TESTING)
  enable_testing()
  add_subdirectory(tests)
endif()

if(BUILD_BENCHMARKING)
  add_subdirectory(benchmarks)
endif()

if(CPP_TEMPLATE_PACKAGING)
  include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/Packaging.cmake")
endif()

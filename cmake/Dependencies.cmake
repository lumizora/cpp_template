# Dependency manifest: versions retained, archive contents locked by SHA256.
# Declare fmt before spdlog so find_package(fmt) resolves to the same target.
add_dependency(fmt
  VERSION 10.2.1
  URL https://codeload.github.com/fmtlib/fmt/tar.gz/10.2.1
  URL_HASH SHA256=1250e4cc58bf06ee631567523f48848dc4596133e163f02615c97f78bab6c811
  EXPOSE_FIND_PACKAGE SYSTEM
  CMAKE_ARGS -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=OFF)

add_dependency(nlohmann_json
  VERSION 3.11.3
  URL https://codeload.github.com/nlohmann/json/tar.gz/v3.11.3
  URL_HASH SHA256=0d8ef5af7f9794e3263480193c491549b2ba6cc74bb018906202ada498a79406
  EXPOSE_FIND_PACKAGE SYSTEM
  CMAKE_ARGS -DJSON_Testing=OFF -DJSON_Install=OFF)

add_dependency(spdlog
  VERSION 1.13.0
  URL https://codeload.github.com/gabime/spdlog/tar.gz/v1.13.0
  URL_HASH SHA256=534f2ee1a4dcbeb22249856edfb2be76a1cf4f708a20b0ac2ed090ee24cfdbc9
  SYSTEM
  CMAKE_ARGS -DSPDLOG_FMT_EXTERNAL=ON -DSPDLOG_BUILD_TESTS=OFF
    -DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_INSTALL=OFF)

add_dependency(CLI11
  VERSION 2.7.2
  URL https://codeload.github.com/CLIUtils/CLI11/tar.gz/v2.7.2
  URL_HASH SHA256=46eef3101da70852ec7af026e09d485ccee81813331c8c6052d39344443b83da
  SYSTEM
  CMAKE_ARGS -DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_EXAMPLES=OFF
    -DCLI11_BUILD_DOCS=OFF -DCLI11_INSTALL=OFF)

add_header_dependency(stb
  VERSION 2c980bb59875b0d32144a71867fbdebb2f77cd20
  URL https://codeload.github.com/nothings/stb/tar.gz/2c980bb59875b0d32144a71867fbdebb2f77cd20
  URL_HASH SHA256=9a955b1b49a4410088a2e0ee2a9c057c3c907d0c1d75454144cb980aca0ba515
  SYSTEM)

# Optional example: Windows MSVC x64 uses a prebuilt DLL; other supported
# desktop targets build from source. The application always links glfw::glfw.
if(CPP_TEMPLATE_WITH_GLFW)
  if(WIN32 AND MSVC AND MSVC_CXX_ARCHITECTURE_ID STREQUAL "x64")
    add_binary_dependency(glfw
      VERSION 3.4
      URL https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.bin.WIN64.zip
      URL_HASH SHA256=54EFA829400F2A0537F742B2B3BDD74E437BB4F2F048E4B7D3C5557D11A611E6
      SUBDIR glfw-3.4.bin.WIN64
      INCLUDE_DIR include
      IMPLIB lib-vc2022/glfw3dll.lib
      RUNTIME lib-vc2022/glfw3.dll
      ALLOW_RELEASE_FALLBACK # GLFW exposes a C ABI; no cross-DLL CRT ownership in this example.
      SYSTEM)
  elseif(WIN32 OR APPLE OR CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(_glfw_options -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_TESTS=OFF
      -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_INSTALL=OFF)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
      list(APPEND _glfw_options -DGLFW_BUILD_X11=ON -DGLFW_BUILD_WAYLAND=OFF)
    endif()
    add_dependency(glfw
      VERSION 3.4
      URL https://github.com/glfw/glfw/archive/refs/tags/3.4.tar.gz
      URL_HASH SHA256=c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01
      SYSTEM
      CMAKE_ARGS ${_glfw_options})
    if(TARGET glfw AND NOT TARGET glfw::glfw)
      add_library(glfw::glfw ALIAS glfw)
    endif()
    unset(_glfw_options)
  else()
    message(FATAL_ERROR "GLFW example unsupported on ${CMAKE_SYSTEM_NAME}; disable CPP_TEMPLATE_WITH_GLFW")
  endif()
endif()

if(BUILD_TESTING)
  add_dependency(googletest
    VERSION 1.14.0
    URL https://codeload.github.com/google/googletest/tar.gz/v1.14.0
    URL_HASH SHA256=8ad598c73ad796e0d8280b082cebd82a630d73e73cd3c70057938a6501bba5d7
    SYSTEM
    CMAKE_ARGS -DINSTALL_GTEST=OFF)
endif()

if(BUILD_BENCHMARKING)
  add_dependency(benchmark
    VERSION 1.9.5
    URL https://codeload.github.com/google/benchmark/tar.gz/v1.9.5
    URL_HASH SHA256=9631341c82bac4a288bef951f8b26b41f69021794184ece969f8473977eaa340
    SYSTEM
    CMAKE_ARGS -DBENCHMARK_ENABLE_TESTING=OFF -DBENCHMARK_INSTALL=OFF)
endif()

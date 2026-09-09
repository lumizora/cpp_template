# Pure-CMake dependency helpers. Downloaded sources are immutable cache entries;
# generated files, objects and FetchContent subbuilds always belong to this build.
include_guard(GLOBAL)
set(FETCHCONTENT_BASE_DIR "${CMAKE_BINARY_DIR}/_deps")
include(FetchContent)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(DEPS_CACHE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.deps-cache" CACHE PATH "Shared dependency source cache")
option(DEPS_OFFLINE "Use matching cached dependencies only" OFF)
option(DEPS_ALLOW_OVERRIDE "Allow local dependency overrides" ON)
option(DEPS_PREFER_PACKAGE "Prefer installed packages in development builds" OFF)

# Keep one CRT policy across our targets and source-built dependencies.
# DLL boundaries still require compatible ownership and ABI conventions.
if(MSVC AND NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

function(_deps_check_arguments name)
  if(NOT name MATCHES "^[A-Za-z][A-Za-z0-9_]*$")
    message(FATAL_ERROR "[deps] Invalid dependency name: ${name}")
  endif()
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
    message(FATAL_ERROR "[deps] ${name}: unknown arguments or missing values: ${ARG_UNPARSED_ARGUMENTS};${ARG_KEYWORDS_MISSING_VALUES}")
  endif()
endfunction()

function(_deps_check_hash name hash)
  string(LENGTH "${hash}" _length)
  if(NOT _length EQUAL 71 OR NOT hash MATCHES "^SHA256=[0-9a-fA-F]+$")
    message(FATAL_ERROR "[deps] ${name}: URL_HASH must be SHA256=<64 hex digits>")
  endif()
endfunction()

# Keep the resolved source and declared provenance available to release packaging.
function(_deps_record name source)
  set_property(GLOBAL PROPERTY "DEPS_${name}_SOURCE" "${source}")
  foreach(_field VERSION URL URL_HASH GIT_REPOSITORY GIT_TAG)
    set_property(GLOBAL PROPERTY "DEPS_${name}_${_field}" "${ARG_${_field}}")
  endforeach()
endfunction()

# Also used by the offline manifest checker: CMake parses its own syntax.
macro(_deps_parse_source name)
  cmake_parse_arguments(ARG "PREFER_PACKAGE;EXPOSE_FIND_PACKAGE;SYSTEM;GIT_SHALLOW"
    "VERSION;GIT_REPOSITORY;GIT_TAG;URL;URL_HASH" "CMAKE_ARGS;COMPONENTS" ${ARGN})
  _deps_check_arguments("${name}")
  if(ARG_GIT_REPOSITORY AND ARG_URL)
    message(FATAL_ERROR "[deps] ${name}: choose either GIT_REPOSITORY or URL")
  elseif(ARG_GIT_REPOSITORY)
    string(LENGTH "${ARG_GIT_TAG}" _tag_length)
    set(_commit FALSE)
    if(_tag_length EQUAL 40 AND ARG_GIT_TAG MATCHES "^[0-9a-fA-F]+$")
      set(_commit TRUE)
    endif()
    if(NOT _commit AND NOT ARG_GIT_TAG MATCHES "^v?[0-9]+\\.[0-9]+\\.[0-9]+([-+][A-Za-z0-9.-]+)?$")
      message(FATAL_ERROR "[deps] ${name}: GIT_TAG must be a commit SHA or version tag")
    endif()
    if(_commit AND ARG_GIT_SHALLOW)
      message(FATAL_ERROR "[deps] ${name}: GIT_SHALLOW cannot be combined with a commit SHA; use a hashed archive")
    endif()
  elseif(ARG_URL)
    _deps_check_hash("${name}" "${ARG_URL_HASH}")
    if(ARG_GIT_TAG OR ARG_GIT_SHALLOW)
      message(FATAL_ERROR "[deps] ${name}: Git options cannot be used with URL")
    endif()
  else()
    message(FATAL_ERROR "[deps] ${name}: GIT_REPOSITORY or URL is required")
  endif()
  foreach(_arg IN LISTS ARG_CMAKE_ARGS)
    if(NOT _arg MATCHES "^(-D)?([A-Za-z_][A-Za-z0-9_]*)(:[A-Za-z_]+)?=(.*)$")
      message(FATAL_ERROR "[deps] ${name}: invalid CMAKE_ARGS entry: ${_arg}")
    endif()
  endforeach()
endmacro()

function(_deps_source name header_only)
  _deps_parse_source("${name}" ${ARGN})
  set(_package_name "${name}")
  string(TOLOWER "${name}" name)
  string(TOUPPER "${name}" _up)
  set(_override "${FETCHCONTENT_SOURCE_DIR_${_up}}")
  # FetchContent otherwise copies a scoped override into its cache on first use.
  set("FETCHCONTENT_SOURCE_DIR_${_up}" "" CACHE PATH "Explicit dependency source override")
  if(NOT DEPS_ALLOW_OVERRIDE AND _override)
    message(FATAL_ERROR "[deps] ${name}: source override is forbidden; remove FETCHCONTENT_SOURCE_DIR_${_up} or configure --fresh")
  endif()
  if(DEPS_ALLOW_OVERRIDE AND NOT _override)
    set(_override_root "$ENV{DEPS_OVERRIDE_DIR}")
    if(NOT _override_root)
      set(_override_root "${CMAKE_CURRENT_SOURCE_DIR}/.deps-override")
    endif()
    if(IS_DIRECTORY "${_override_root}/${name}")
      set(_override "${_override_root}/${name}")
    endif()
  endif()

  if((DEPS_PREFER_PACKAGE OR ARG_PREFER_PACKAGE) AND NOT _override AND NOT header_only)
    if(NOT DEPS_ALLOW_OVERRIDE)
      message(FATAL_ERROR "[deps] ${name}: installed-package preference is forbidden in strict builds")
    endif()
    set(_find_args CONFIG QUIET)
    if(ARG_VERSION)
      list(PREPEND _find_args "${ARG_VERSION}" EXACT)
    endif()
    if(ARG_COMPONENTS)
      list(APPEND _find_args COMPONENTS ${ARG_COMPONENTS})
    endif()
    find_package(${_package_name} ${_find_args})
    if(${_package_name}_FOUND)
      message(STATUS "[deps] ${name}: installed package (development mode)")
      return()
    endif()
  endif()

  string(SHA256 _key "${ARG_GIT_REPOSITORY}|${ARG_GIT_TAG}|${ARG_URL}|${ARG_URL_HASH}")
  set(_entry "${DEPS_CACHE_DIR}/sources/${name}/${_key}")
  set(_args SOURCE_DIR "${_entry}/src"
    BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/_deps/${name}-build"
    SUBBUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/_deps/${name}-subbuild")
  if(ARG_GIT_REPOSITORY)
    list(APPEND _args GIT_REPOSITORY "${ARG_GIT_REPOSITORY}" GIT_TAG "${ARG_GIT_TAG}")
    if(ARG_GIT_SHALLOW)
      list(APPEND _args GIT_SHALLOW TRUE)
    endif()
  else()
    list(APPEND _args URL "${ARG_URL}" URL_HASH "${ARG_URL_HASH}" TLS_VERIFY TRUE)
  endif()
  if(ARG_SYSTEM)
    list(APPEND _args SYSTEM)
  endif()
  if(ARG_EXPOSE_FIND_PACKAGE)
    list(APPEND _args OVERRIDE_FIND_PACKAGE)
  endif()
  if(header_only)
    # A header-only checkout may acquire a CMakeLists.txt upstream; never execute it.
    list(APPEND _args SOURCE_SUBDIR "__headers_only__")
  endif()

  # Normal variables are inherited by add_subdirectory; no global cache FORCE.
  foreach(_arg IN LISTS ARG_CMAKE_ARGS)
    string(REGEX MATCH "^(-D)?([A-Za-z_][A-Za-z0-9_]*)(:[A-Za-z_]+)?=(.*)$" _match "${_arg}")
    set("${CMAKE_MATCH_2}" "${CMAKE_MATCH_4}")
  endforeach()

  # Do not inherit a stale FULLY_DISCONNECTED cache value from the old engine.
  # Offline behavior is enforced here before FetchContent can download anything.
  set(FETCHCONTENT_FULLY_DISCONNECTED OFF)
  if(_override)
    if(NOT IS_DIRECTORY "${_override}")
      message(FATAL_ERROR "[deps] ${name}: override directory does not exist: ${_override}")
    endif()
    set("FETCHCONTENT_SOURCE_DIR_${_up}" "${_override}")
    message(STATUS "[deps] ${name}: local override -> ${_override}")
  else()
    file(MAKE_DIRECTORY "${_entry}")
    file(LOCK "${_entry}/.lock" GUARD FUNCTION TIMEOUT 120)
    if(EXISTS "${_entry}/.ready" AND IS_DIRECTORY "${_entry}/src")
      set("FETCHCONTENT_SOURCE_DIR_${_up}" "${_entry}/src")
      message(STATUS "[deps] ${name}: cached source -> ${_entry}/src")
    elseif(DEPS_OFFLINE)
      message(FATAL_ERROR "[deps] ${name}: offline cache missing for requested pin -> ${_entry}")
    else()
      set("FETCHCONTENT_SOURCE_DIR_${_up}" "")
      message(STATUS "[deps] ${name}: fetching ${ARG_GIT_TAG}${ARG_URL_HASH}")
    endif()
  endif()

  FetchContent_Declare(${name} ${_args})
  FetchContent_MakeAvailable(${name})
  FetchContent_GetProperties(${name})
  _deps_record("${name}" "${${name}_SOURCE_DIR}")
  if(NOT _override)
    if(NOT "${${name}_SOURCE_DIR}" STREQUAL "${_entry}/src")
      message(FATAL_ERROR "[deps] ${name}: an earlier declaration/provider changed the locked source")
    endif()
    file(WRITE "${_entry}/.ready" "${_key}\n")
  endif()
  if(header_only AND NOT TARGET ${name}::${name})
    add_library(${name}::${name} INTERFACE IMPORTED GLOBAL)
    set_target_properties(${name}::${name} PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${${name}_SOURCE_DIR}")
    if(ARG_SYSTEM)
      set_property(TARGET ${name}::${name} PROPERTY
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${${name}_SOURCE_DIR}")
    endif()
  endif()
endfunction()

function(add_dependency name)
  _deps_source("${name}" FALSE ${ARGN})
endfunction()

function(add_header_dependency name)
  _deps_source("${name}" TRUE ${ARGN})
endfunction()

# ---------------------------------------------------------------------------
# add_binary_dependency(name
#   VERSION <ver>
#   URL <url>
#   URL_HASH SHA256=<hex>        # 供应链校验(必填)
#   SUBDIR <rel-dir>             # 解压后的内层目录(如 glfw-3.4.bin.WIN64)
#   INCLUDE_DIR <rel-path>       # 头文件根(相对包根)
#   [IMPLIB <rel-path> ...]      # Windows 导入库(.lib/.dll.a);首个为主库
#   [LIBRARY <rel-path> ...]     # Linux/macOS 共享库(.so/.dylib);首个为主库
#   [RUNTIME <rel-path> ...]     # 需部署到产物旁的运行期文件(.dll/.so/.dylib)
#   [SYSTEM]                     # 头标记 SYSTEM,抑制告警
# )
# 预编译二进制专用:下载 -> 校验 -> 解压 -> IMPORTED 目标。
# 适用于源码构建耗时极长(如 ONNX Runtime)或仅提供预编译包的依赖。
# 与 add_dependency 共享 .deps-cache / DEPS_OFFLINE / .deps-override 语义。
#
# 平台规则:
#   Windows : IMPLIB 必填;RUNTIME 可选但动态库通常应提供。
#             首个 IMPLIB -> IMPORTED_IMPLIB_RELEASE;
#             若有 RUNTIME,首个 RUNTIME -> IMPORTED_LOCATION_RELEASE。
#   Linux/macOS:
#             LIBRARY 必填;首个 LIBRARY -> IMPORTED_LOCATION_RELEASE;
#             其余 LIBRARY -> INTERFACE_LINK_LIBRARIES。
#
# 二进制缓存按 CMAKE_SYSTEM_NAME/CMAKE_SYSTEM_PROCESSOR 隔离,避免同一源码树在
# Windows / WSL / Linux / macOS 间共享 .deps-cache 时相互污染。
# 预编译包只有 Release;其他标准配置仅在 ALLOW_RELEASE_FALLBACK 时映射到 Release。
# ---------------------------------------------------------------------------
macro(_deps_parse_binary name)
  set(options SYSTEM ALLOW_RELEASE_FALLBACK)
  set(oneValueArgs VERSION URL URL_HASH SUBDIR INCLUDE_DIR)
  set(multiValueArgs IMPLIB LIBRARY RUNTIME)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  _deps_check_arguments("${name}")
  _deps_check_hash("${name}" "${ARG_URL_HASH}")
  if(NOT ARG_VERSION)
    message(FATAL_ERROR "[deps] ${name}: 二进制依赖必须提供 VERSION")
  endif()
  if(NOT ARG_URL OR NOT ARG_URL_HASH)
    message(FATAL_ERROR "[deps] ${name}: 二进制依赖必须提供 URL 与 URL_HASH")
  endif()
  if(NOT ARG_INCLUDE_DIR)
    message(FATAL_ERROR "[deps] ${name}: 二进制依赖必须提供 INCLUDE_DIR")
  endif()

  # 链接模型按目标平台(CMAKE_SYSTEM_NAME)判断,而非宿主平台。
  # 因而 toolchain/cross-compile 场景也使用目标平台对应的 IMPORTED 属性。
  if(WIN32)
    if(NOT ARG_IMPLIB)
      message(FATAL_ERROR
        "[deps] ${name}: Windows 二进制依赖必须提供 IMPLIB")
    endif()
  elseif(UNIX)
    if(NOT ARG_LIBRARY)
      message(FATAL_ERROR
        "[deps] ${name}: ${CMAKE_SYSTEM_NAME} 二进制依赖必须提供 LIBRARY")
    endif()
  else()
    message(FATAL_ERROR
      "[deps] ${name}: 暂不支持二进制依赖平台 "
      "${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}")
  endif()
endmacro()

function(add_binary_dependency name)
  _deps_parse_binary("${name}" ${ARGN})

  # 平台 key:同一个仓库在 Windows/WSL/Linux/macOS 间共享源码目录时,
  # 不允许复用另一目标平台已解压的二进制包。
  set(_platform "${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
  string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" _platform "${_platform}")
  if(_platform STREQUAL "-")
    set(_platform "unknown-platform")
  endif()

  # 不同 pin 使用不同缓存项,更新失败不会破坏仍在使用的旧版本。
  string(SHA256 _fingerprint
    "${ARG_VERSION}|${ARG_URL}|${ARG_URL_HASH}|${ARG_SUBDIR}")
  set(_root "${DEPS_CACHE_DIR}/binary/${name}/${_platform}/${_fingerprint}")
  set(_stamp "${_root}/.ready")
  set(_source "${_root}/src")

  # 正常下载路径下,包根默认是 <root>/src[/SUBDIR]。
  set(_src "${_source}")
  if(ARG_SUBDIR)
    set(_src "${_src}/${ARG_SUBDIR}")
  endif()

  # 1) 本地覆盖。
  # 优先使用平台专用目录:
  #   .deps-override/<name>/<CMAKE_SYSTEM_NAME>-<CMAKE_SYSTEM_PROCESSOR>
  # 其次兼容旧布局:
  #   .deps-override/<name>
  # 覆盖目录应直接指向“包根”(即其中可找到 INCLUDE_DIR/IMPLIB/LIBRARY)。
  set(_skip_download FALSE)
  if(DEPS_ALLOW_OVERRIDE)
    set(_ov "$ENV{DEPS_OVERRIDE_DIR}")
    if(_ov STREQUAL "")
      set(_ov "${CMAKE_CURRENT_SOURCE_DIR}/.deps-override")
    endif()

    set(_ov_platform "${_ov}/${name}/${_platform}")
    set(_ov_legacy   "${_ov}/${name}")

    if(IS_DIRECTORY "${_ov_platform}")
      set(_src "${_ov_platform}")
      set(_skip_download TRUE)
      message(STATUS "[deps] ${name}: 本地覆盖 -> ${_ov_platform}")
    elseif(IS_DIRECTORY "${_ov_legacy}")
      set(_src "${_ov_legacy}")
      set(_skip_download TRUE)
      message(STATUS "[deps] ${name}: 本地覆盖 -> ${_ov_legacy}")
    endif()
  endif()

  # 2) 判断缓存是否与当前 pin 完全一致。
  set(_cache_hit FALSE)
  if(NOT _skip_download)
    file(MAKE_DIRECTORY "${_root}")
    file(LOCK "${_root}/.lock" GUARD FUNCTION TIMEOUT 120)
  endif()
  if(NOT _skip_download AND EXISTS "${_stamp}" AND IS_DIRECTORY "${_source}")
    file(READ "${_stamp}" _cached_fingerprint)
    string(STRIP "${_cached_fingerprint}" _cached_fingerprint)
    if(_cached_fingerprint STREQUAL _fingerprint)
      set(_cache_hit TRUE)
      message(STATUS
        "[deps] ${name}: 使用二进制缓存 -> ${_root}")
    endif()
  endif()

  # 3) 下载 + 校验 + 解压。
  if(NOT _skip_download AND NOT _cache_hit)
    if(DEPS_OFFLINE)
      message(FATAL_ERROR
        "[deps] ${name}: 离线模式但当前平台/pin的二进制缓存缺失 -> ${_root}")
    endif()

    # 保留 URL 中原始归档文件名/扩展名,兼容 .zip/.tar.gz/.tar.xz 等。
    string(REGEX REPLACE "^.*/" "" _archive_name "${ARG_URL}")
    string(REGEX REPLACE "[?#].*$" "" _archive_name "${_archive_name}")
    if(_archive_name STREQUAL "")
      set(_archive_name "${name}-${ARG_VERSION}.archive")
    endif()
    set(_archive "${_root}/${_archive_name}")

    message(STATUS
      "[deps] ${name}: 下载预编译包 @ ${ARG_VERSION} "
      "(${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR})")

    file(DOWNLOAD "${ARG_URL}" "${_archive}"
         STATUS _st EXPECTED_HASH "${ARG_URL_HASH}" TLS_VERIFY ON
         TIMEOUT 300 INACTIVITY_TIMEOUT 30 SHOW_PROGRESS)
    list(GET _st 0 _rc)
    if(NOT _rc EQUAL 0)
      file(REMOVE "${_archive}")
      message(FATAL_ERROR "[deps] ${name}: 下载失败 -> ${_st}")
    endif()

    # 此目录只属于当前 pin,且没有有效完成标记;可安全重试解压。
    file(REMOVE_RECURSE "${_source}")
    file(MAKE_DIRECTORY "${_source}")
    file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_source}")
  endif()

  # 4) 校验包布局。尽早在 configure 阶段报错,避免错误拖到链接阶段。
  set(_inc "${_src}/${ARG_INCLUDE_DIR}")
  if(NOT IS_DIRECTORY "${_inc}")
    message(FATAL_ERROR
      "[deps] ${name}: INCLUDE_DIR 不存在 -> ${_inc}")
  endif()

  set(_implibs)
  foreach(_rel IN LISTS ARG_IMPLIB)
    set(_abs "${_src}/${_rel}")
    if(NOT EXISTS "${_abs}")
      message(FATAL_ERROR "[deps] ${name}: IMPLIB 不存在 -> ${_abs}")
    endif()
    list(APPEND _implibs "${_abs}")
  endforeach()

  set(_libraries)
  foreach(_rel IN LISTS ARG_LIBRARY)
    set(_abs "${_src}/${_rel}")
    if(NOT EXISTS "${_abs}")
      message(FATAL_ERROR "[deps] ${name}: LIBRARY 不存在 -> ${_abs}")
    endif()
    list(APPEND _libraries "${_abs}")
  endforeach()

  set(_runtime)
  foreach(_rel IN LISTS ARG_RUNTIME)
    set(_abs "${_src}/${_rel}")
    if(NOT EXISTS "${_abs}")
      message(FATAL_ERROR "[deps] ${name}: RUNTIME 不存在 -> ${_abs}")
    endif()
    list(APPEND _runtime "${_abs}")
  endforeach()
  if(NOT _skip_download)
    file(WRITE "${_stamp}" "${_fingerprint}\n")
  endif()

  # 5) IMPORTED 目标(幂等:重复配置不重建)。
  if(NOT TARGET ${name}::${name})
    add_library(${name}::${name} SHARED IMPORTED GLOBAL)

    set_target_properties(${name}::${name} PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_inc}"
      IMPORTED_CONFIGURATIONS RELEASE)

    if(ARG_SYSTEM)
      set_target_properties(${name}::${name} PROPERTIES
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_inc}")
    endif()

    if(WIN32)
      # Windows 动态库:
      #   .lib/.dll.a -> IMPORTED_IMPLIB (链接期)
      #   .dll        -> IMPORTED_LOCATION (运行期;若提供)
      set(_rest_implibs "${_implibs}")
      list(POP_FRONT _rest_implibs _first_implib)
      set_target_properties(${name}::${name} PROPERTIES
        IMPORTED_IMPLIB_RELEASE "${_first_implib}")

      if(_runtime)
        list(GET _runtime 0 _first_runtime)
        set_target_properties(${name}::${name} PROPERTIES
          IMPORTED_LOCATION_RELEASE "${_first_runtime}")
      endif()

      if(_rest_implibs)
        set_property(TARGET ${name}::${name} APPEND PROPERTY
          INTERFACE_LINK_LIBRARIES "${_rest_implibs}")
      endif()
    else()
      # ELF / Mach-O 动态库:
      # 首个 .so/.dylib 是主 IMPORTED_LOCATION,其余作为同一依赖组的链接库。
      set(_rest_libraries "${_libraries}")
      list(POP_FRONT _rest_libraries _first_library)
      set_target_properties(${name}::${name} PROPERTIES
        IMPORTED_LOCATION_RELEASE "${_first_library}")

      if(_rest_libraries)
        set_property(TARGET ${name}::${name} APPEND PROPERTY
          INTERFACE_LINK_LIBRARIES "${_rest_libraries}")
      endif()
    endif()

    # A Release-only binary must not silently stand in for a Debug ABI.
    foreach(_cfg DEBUG RELWITHDEBINFO MINSIZEREL)
      if(ARG_ALLOW_RELEASE_FALLBACK)
        set_property(TARGET ${name}::${name} PROPERTY MAP_IMPORTED_CONFIG_${_cfg} RELEASE)
      else()
        set_property(TARGET ${name}::${name} PROPERTY MAP_IMPORTED_CONFIG_${_cfg} "UNSUPPORTED_${_cfg}")
      endif()
    endforeach()

    message(STATUS
      "[deps] ${name}: binary @ ${_src} "
      "(${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR})")
  endif()

  # 即使目标此前已存在,也刷新当前 configure 对应的运行期文件记录。
  # binary_dep_deploy() 通过该 INTERNAL cache 变量读取。
  set("${name}_RUNTIME_LIBS" "${_runtime}" CACHE INTERNAL
      "runtime files of binary dependency ${name}" FORCE)
  _deps_record("${name}" "${_src}")
endfunction()

# ---------------------------------------------------------------------------
# binary_dep_deploy(target <dep>...)
# 把各二进制依赖显式列在 RUNTIME 中的运行期文件复制到 <target> 产物旁。
# Windows 典型为 .dll;Linux/macOS 也可显式部署 .so/.dylib。
# 在 add_executable / target_link_libraries 之后调用。
#
# Unix 下若确实部署了运行期共享库到产物旁,同时加入相对 RPATH:
#   Linux/*BSD : $ORIGIN
#   macOS      : @loader_path
# 使“复制到可执行文件旁”这一部署语义真正可运行。
# ---------------------------------------------------------------------------
function(binary_dep_deploy target)
  if(NOT TARGET ${target})
    message(FATAL_ERROR
      "[deps] binary_dep_deploy: target 不存在 -> ${target}")
  endif()

  set(_runtime_files)
  foreach(_dep IN LISTS ARGN)
    set(_runtime_var "${_dep}_RUNTIME_LIBS")
    if(DEFINED ${_runtime_var})
      list(APPEND _runtime_files ${${_runtime_var}})
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _runtime_files)
  # Ninja/Make must re-run deployment when only a runtime DLL changes.
  set_property(TARGET ${target} APPEND PROPERTY LINK_DEPENDS ${_runtime_files})

  foreach(_runtime IN LISTS _runtime_files)
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
              "${_runtime}" "$<TARGET_FILE_DIR:${target}>"
      VERBATIM)
  endforeach()

  # Windows loader 默认搜索 exe 所在目录,无需 RPATH。
  # Unix loader 不保证如此,因此仅在实际部署了 runtime 文件时补相对 RPATH。
  if(_runtime_files)
    if(APPLE)
      set_property(TARGET ${target} APPEND PROPERTY BUILD_RPATH "@loader_path")
    elseif(UNIX)
      set_property(TARGET ${target} APPEND PROPERTY BUILD_RPATH "$ORIGIN")
    endif()
  endif()
endfunction()

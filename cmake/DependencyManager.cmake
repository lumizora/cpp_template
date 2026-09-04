# ---------------------------------------------------------------------------
# 纯 CMake 依赖管理引擎
#
# 设计目标:可复现 / 可离线 / ABI 一致 / 传递依赖去重 / 本地可覆盖
# 依赖 CMake >= 3.25 (OVERRIDE_FIND_PACKAGE 3.24, SYSTEM 头 3.25)
# ---------------------------------------------------------------------------
include_guard(GLOBAL)

# 统一源码缓存目录:必须在 include(FetchContent) 之前以 CACHE 变量设置。
# 原因:FetchContent.cmake 在模块加载时(L1927)会执行
#   set(FETCHCONTENT_BASE_DIR "${CMAKE_BINARY_DIR}/_deps" CACHE PATH ...)
# 若在此之前已存在同名 cache 变量,该行是 no-op;否则它写入默认值,
# 此后再设普通变量无法覆盖。放这里才生效,且可被 -D 覆盖。
if(NOT DEFINED FETCHCONTENT_BASE_DIR)
  set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/.deps-cache" CACHE PATH
      "FetchContent source cache (shared across builds)")
endif()

include(FetchContent)

# ---- 全局策略 -------------------------------------------------------------
# CMP0077 NEW:被拉取库的 option() 遵守我们传入的普通变量,而非污染 cache。
# 这是干净配置第三方库的关键。
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

option(DEPS_OFFLINE        "使用已预取的缓存,禁止联网"            OFF)
option(DEPS_ALLOW_OVERRIDE "允许 .deps-override/<name> 本地覆盖"  ON)
option(DEPS_PREFER_PACKAGE "优先用系统/已安装包,找不到再拉源码"   OFF)

# 离线模式:FetchContent 不联网,源码必须已存在于缓存中。
if(DEPS_OFFLINE)
  set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "" FORCE)
endif()

# ---- ABI 一致性:让被拉取库与主项目共用同一 CRT(仅 MSVC) -------------------
# 必须用动态 CRT(/MD,MultiThreaded*DLL):多个静态库 + /MT 会让每个库各自
# 链接一份 CRT,stdio 缓冲区相互隔离 -- fmt::print 写入 fmt 私有 stdout
# 缓冲,进程退出只刷新主程序的缓冲,输出被静默丢弃。/MD 共享单一 CRT 实例。
# 用户可在 include 之前自行覆盖。
if(MSVC AND NOT DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
  set(CMAKE_MSVC_RUNTIME_LIBRARY
      "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

# ---------------------------------------------------------------------------
# add_dependency(name
#   VERSION <ver>
#   [GIT_REPOSITORY <url> GIT_TAG <sha-or-tag>]
#   [URL <url> URL_HASH <sha256>]
#   [PREFER_PACKAGE]          # 先 find_package,失败再拉源码
#   [EXPOSE_FIND_PACKAGE]     # 声明 OVERRIDE,供其它依赖的 find_package 命中
#   [SYSTEM]                  # 头文件标记为 SYSTEM,抑制告警(CMake 3.25+)
#   [GIT_SHALLOW]             # 浅克隆(--depth 1),适合 tag;大幅减小大仓库下载
#   [CMAKE_ARGS arg ...]      # 转发给子项目的配置参数
#   [COMPONENTS c ...])       # find_package 时的组件
# ---------------------------------------------------------------------------
function(add_dependency name)
  set(options PREFER_PACKAGE EXPOSE_FIND_PACKAGE SYSTEM GIT_SHALLOW)
  set(oneValueArgs VERSION GIT_REPOSITORY GIT_TAG URL URL_HASH)
  set(multiValueArgs CMAKE_ARGS COMPONENTS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  string(TOUPPER "${name}" _UP)

  # 1) 本地覆盖:开发时把依赖 checkout 到 .deps-override/<name> 即生效
  if(DEPS_ALLOW_OVERRIDE)
    set(_ov "$ENV{DEPS_OVERRIDE_DIR}")
    if(_ov STREQUAL "")
      set(_ov "${CMAKE_SOURCE_DIR}/.deps-override")
    endif()
    if(EXISTS "${_ov}/${name}")
      set("FETCHCONTENT_SOURCE_DIR_${_UP}" "${_ov}/${name}" CACHE PATH "" FORCE)
      message(STATUS "[deps] ${name}: 本地覆盖 -> ${_ov}/${name}")
    endif()
  endif()

  # 2) 优先使用已安装包(可选策略)
  if((DEPS_PREFER_PACKAGE OR ARG_PREFER_PACKAGE)
     AND NOT FETCHCONTENT_FULLY_DISCONNECTED
     AND NOT DEFINED CACHE{FETCHCONTENT_SOURCE_DIR_${_UP}})
    find_package("${name}" "${ARG_VERSION}" QUIET COMPONENTS ${ARG_COMPONENTS})
    if(${name}_FOUND)
      message(STATUS "[deps] ${name}: 使用已安装包")
      return()
    endif()
  endif()

  # 3) 组织 FetchContent_Declare 参数
  set(_args)
  if(ARG_GIT_REPOSITORY)
    list(APPEND _args GIT_REPOSITORY "${ARG_GIT_REPOSITORY}"
                      GIT_TAG        "${ARG_GIT_TAG}")
    if(ARG_GIT_SHALLOW)
      list(APPEND _args GIT_SHALLOW)     # --depth 1,仅对 tag/branch 可靠
    endif()
  elseif(ARG_URL)
    if(NOT ARG_URL_HASH)
      message(FATAL_ERROR "[deps] ${name}: URL 源必须提供 URL_HASH(供应链校验)")
    endif()
    list(APPEND _args URL "${ARG_URL}" URL_HASH "${ARG_URL_HASH}")
  else()
    message(FATAL_ERROR "[deps] ${name}: 必须指定 GIT_REPOSITORY 或 URL")
  endif()

  if(ARG_EXPOSE_FIND_PACKAGE)
    list(APPEND _args OVERRIDE_FIND_PACKAGE)   # CMake 3.24+
  endif()
  if(ARG_SYSTEM)
    list(APPEND _args SYSTEM)                  # CMake 3.25+
  endif()
  if(ARG_CMAKE_ARGS)
    list(APPEND _args CMAKE_ARGS ${ARG_CMAKE_ARGS})
  endif()

  FetchContent_Declare("${name}" ${_args})

  # 将 CMAKE_ARGS 预设为强制 cache 变量,确保子项目 option() 遵守清单。
  # 原因:FetchContent 的 CMAKE_ARGS 在 add_subdirectory 路径下不可靠
  # (CMake 3.31 实测未传给 spdlog,SPDLOG_FMT_EXTERNAL 仍为默认 OFF,
  #  导致 spdlog 内嵌 fmt -- 与外部 fmt 形成 ODR 冲突)。
  # 清单即权威:改选项请改清单(每次配置均 FORCE 覆盖)。
  foreach(_arg IN LISTS ARG_CMAKE_ARGS)
    # 支持 -DVAR=VALUE / VAR=VALUE / -DVAR:TYPE=VALUE
    string(REGEX REPLACE "^-D" "" _arg "${_arg}")
    string(REGEX REPLACE "^([^:=]+):[^=]*=" "\\1=" _arg "${_arg}")
    if(_arg MATCHES "^([^=]+)=(.*)$")
      set(_vname "${CMAKE_MATCH_1}")
      set(_vval  "${CMAKE_MATCH_2}")
      if(_vval MATCHES "^(ON|OFF|TRUE|FALSE|YES|NO|1|0)$")
        set("${_vname}" "${_vval}" CACHE BOOL "" FORCE)
      else()
        set("${_vname}" "${_vval}" CACHE STRING "" FORCE)
      endif()
    endif()
  endforeach()

  message(STATUS "[deps] ${name}: 拉取源码 @ ${ARG_GIT_TAG}${ARG_URL_HASH}")
  FetchContent_MakeAvailable("${name}")
endfunction()

# ---------------------------------------------------------------------------
# add_header_dependency(name
#   VERSION <ver>
#   GIT_REPOSITORY <url> GIT_TAG <sha-or-tag> [GIT_SHALLOW]
#   [URL <url> URL_HASH <sha256>]      # 或 tarball 源(供应链校验)
#   [SYSTEM]                            # 头标记 SYSTEM,抑制告警
# )
# header-only 依赖专用:无 CMakeLists.txt,不能 add_subdirectory。
# FetchContent 取源码后直接建 INTERFACE 库 name::name(仅暴露 include 路径)。
# 关键:FetchContent_MakeAvailable 在内容无 CMakeLists.txt 时会优雅跳过
# add_subdirectory(CMake 文档明示"It is not an error for there to be no
# CMakeLists.txt file"),故无需调用 3.30+ 已弃用的 FetchContent_Populate。
# 与 add_dependency 共享 .deps-cache / DEPS_OFFLINE / .deps-override 语义。
# ---------------------------------------------------------------------------
function(add_header_dependency name)
  set(options SYSTEM GIT_SHALLOW)
  set(oneValueArgs VERSION GIT_REPOSITORY GIT_TAG URL URL_HASH)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "" ${ARGN})

  string(TOUPPER "${name}" _UP)

  # 1) 本地覆盖:开发时把依赖 checkout 到 .deps-override/<name> 即生效
  if(DEPS_ALLOW_OVERRIDE)
    set(_ov "$ENV{DEPS_OVERRIDE_DIR}")
    if(_ov STREQUAL "")
      set(_ov "${CMAKE_SOURCE_DIR}/.deps-override")
    endif()
    if(EXISTS "${_ov}/${name}")
      set("FETCHCONTENT_SOURCE_DIR_${_UP}" "${_ov}/${name}" CACHE PATH "" FORCE)
      message(STATUS "[deps] ${name}: 本地覆盖 -> ${_ov}/${name}")
    endif()
  endif()

  # 2) 组织 FetchContent_Declare 参数(无 CMAKE_ARGS / EXPOSE_FIND_PACKAGE:
  #    header-only 无构建脚本,也不参与 find_package 覆盖)
  set(_args)
  if(ARG_GIT_REPOSITORY)
    list(APPEND _args GIT_REPOSITORY "${ARG_GIT_REPOSITORY}"
                      GIT_TAG        "${ARG_GIT_TAG}")
    if(ARG_GIT_SHALLOW)
      list(APPEND _args GIT_SHALLOW)     # 仅对 tag/branch 可靠;SHA 时被忽略
    endif()
  elseif(ARG_URL)
    if(NOT ARG_URL_HASH)
      message(FATAL_ERROR "[deps] ${name}: URL 源必须提供 URL_HASH(供应链校验)")
    endif()
    list(APPEND _args URL "${ARG_URL}" URL_HASH "${ARG_URL_HASH}")
  else()
    message(FATAL_ERROR "[deps] ${name}: 必须指定 GIT_REPOSITORY 或 URL")
  endif()

  FetchContent_Declare("${name}" ${_args})

  # 3) 取源码:无 CMakeLists.txt -> MakeAvailable 跳过 add_subdirectory,仅下载。
  FetchContent_MakeAvailable("${name}")
  FetchContent_GetProperties("${name}")     # 确保 <name>_SOURCE_DIR 在当前作用域可见

  # 4) IMPORTED INTERFACE 目标(幂等:重复配置不重建)
  #    用 IMPORTED 而非普通 INTERFACE:目标名带 "::" 仅对 IMPORTED/ALIAS 合法
  #    (与 add_binary_dependency 一致);普通 INTERFACE 库名不允许含 "::"。
  if(NOT TARGET ${name}::${name})
    add_library(${name}::${name} INTERFACE IMPORTED GLOBAL)
    set(_inc "${${name}_SOURCE_DIR}")
    set_target_properties(${name}::${name} PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_inc}")
    if(ARG_SYSTEM)
      set_target_properties(${name}::${name} PROPERTIES
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_inc}")
    endif()
    message(STATUS "[deps] ${name}: header-only @ ${_inc}")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# add_binary_dependency(name
#   VERSION <ver>
#   URL <url>
#   URL_HASH SHA256=<hex>        # 供应链校验(必填)
#   SUBDIR <rel-dir>             # 解压后的内层目录(如 glfw-3.4.bin.WIN64)
#   INCLUDE_DIR <rel-path>       # 头文件根(相对 SUBDIR)
#   IMPLIB <rel-path> ...        # 导入库(.lib),链接期;可多份(多库场景各一份)
#   RUNTIME <rel-path> ...       # 运行期库(.dll),由 binary_dep_deploy 复制到产物旁
#   [SYSTEM]                     # 头标记 SYSTEM,抑制告警
# )
# 预编译二进制专用:下载 -> 校验 -> 解压 -> IMPORTED 目标。
# 适用于源码构建耗时极长(如 ONNX Runtime)或仅提供预编译包的依赖。
# 与 add_dependency 共享 .deps-cache / DEPS_OFFLINE / .deps-override 语义,
# 但平台强绑定:每个 (OS,arch) 需各 pin 一份 URL + SHA256。
# 预编译包通常只有 Release,Debug/RelWithDebInfo 经 MAP_IMPORTED_CONFIG 映射过去。
# ---------------------------------------------------------------------------
function(add_binary_dependency name)
  set(options SYSTEM)
  set(oneValueArgs VERSION URL URL_HASH SUBDIR INCLUDE_DIR)
  set(multiValueArgs IMPLIB RUNTIME)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_URL OR NOT ARG_URL_HASH)
    message(FATAL_ERROR "[deps] ${name}: 二进制依赖必须提供 URL 与 URL_HASH")
  endif()

  # 缓存根:与源码缓存并列,落在 .deps-cache/ 下(已 gitignore)
  set(_root  "${FETCHCONTENT_BASE_DIR}/${name}-binary")
  set(_stamp "${_root}/.extracted")
  set(_src   "${_root}/src")
  if(ARG_SUBDIR)
    set(_src "${_src}/${ARG_SUBDIR}")
  endif()

  # 1) 本地覆盖:把解压好的包放到 .deps-override/<name> 即生效
  set(_skip_download FALSE)
  if(DEPS_ALLOW_OVERRIDE)
    set(_ov "$ENV{DEPS_OVERRIDE_DIR}")
    if(_ov STREQUAL "")
      set(_ov "${CMAKE_SOURCE_DIR}/.deps-override")
    endif()
    if(EXISTS "${_ov}/${name}")
      set(_src "${_ov}/${name}")
      set(_skip_download TRUE)
      message(STATUS "[deps] ${name}: 本地覆盖 -> ${_ov}/${name}")
    endif()
  endif()

  # 2) 下载 + 校验 + 解压(离线 / 已缓存 / 覆盖 时跳过)
  if(NOT _skip_download AND NOT EXISTS "${_stamp}")
    if(DEPS_OFFLINE)
      message(FATAL_ERROR "[deps] ${name}: 离线模式但缓存缺失 -> ${_root}")
    endif()
    file(MAKE_DIRECTORY "${_root}")
    set(_archive "${_root}/${name}-${ARG_VERSION}.zip")
    message(STATUS "[deps] ${name}: 下载预编译包 @ ${ARG_VERSION}")
    file(DOWNLOAD "${ARG_URL}" "${_archive}"
         STATUS _st EXPECTED_HASH "${ARG_URL_HASH}" SHOW_PROGRESS)
    list(GET _st 0 _rc)
    if(NOT _rc EQUAL 0)
      file(REMOVE "${_archive}")
      message(FATAL_ERROR "[deps] ${name}: 下载失败 -> ${_st}")
    endif()
    file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_root}/src")
    file(TOUCH "${_stamp}")
  endif()

  # 3) IMPORTED 目标(幂等:重复配置不重建)
  if(NOT TARGET ${name}::${name})
    add_library(${name}::${name} SHARED IMPORTED GLOBAL)
    set(_inc "${_src}/${ARG_INCLUDE_DIR}")
    # IMPLIB 支持多库(如 FFmpeg 的 avformat/avcodec/swscale/avutil 各一份 .lib):
    # 首个设 IMPORTED_IMPLIB_RELEASE(单库场景与旧实现一致),其余经
    # INTERFACE_LINK_LIBRARIES 追加为绝对路径。MSVC 链接期只需 .lib 列表即可。
    set(_implibs)
    foreach(_il IN LISTS ARG_IMPLIB)
      list(APPEND _implibs "${_src}/${_il}")
    endforeach()
    set(_first_implib "")
    set(_rest_implibs "")
    if(_implibs)
      list(POP_FRONT _implibs _first_implib)
      set(_rest_implibs "${_implibs}")
    endif()
    set_target_properties(${name}::${name} PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_inc}"
      IMPORTED_CONFIGURATIONS RELEASE
      IMPORTED_IMPLIB_RELEASE "${_first_implib}")
    if(_rest_implibs)
      set_target_properties(${name}::${name} PROPERTIES
        INTERFACE_LINK_LIBRARIES "${_rest_implibs}")
    endif()
    if(ARG_SYSTEM)
      set_target_properties(${name}::${name} PROPERTIES
        INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${_inc}")
    endif()
    foreach(_cfg Debug RelWithDebInfo MinSizeRel)
      set_target_properties(${name}::${name} PROPERTIES
        MAP_IMPORTED_CONFIG_${_cfg} Release)
    endforeach()

    # 记录运行期 DLL,供 binary_dep_deploy() 读取
    set(_rt)
    foreach(_r IN LISTS ARG_RUNTIME)
      list(APPEND _rt "${_src}/${_r}")
    endforeach()
    set("${name}_RUNTIME_LIBS" "${_rt}" CACHE INTERNAL "runtime DLLs of ${name}")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# binary_dep_deploy(target <dep>...)
# 把各二进制依赖的 DLL 复制到 <target> 产物旁(exe 启动前必须就位)。
# 在 add_executable / target_link_libraries 之后调用。
# ---------------------------------------------------------------------------
function(binary_dep_deploy target)
  foreach(_dep IN LISTS ARGN)
    foreach(_dll IN LISTS ${_dep}_RUNTIME_LIBS)
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_dll}" "$<TARGET_FILE_DIR:${target}>")
    endforeach()
  endforeach()
endfunction()

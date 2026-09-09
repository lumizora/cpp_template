# ---------------------------------------------------------------------------
# 单元测试与集成测试
#
# 仅在 BUILD_TESTING=ON 时由根 CMakeLists.txt 加入构建。GoogleTest 由
# Dependencies.cmake 同一开关下拉取,与生产依赖共用同一套 ABI/CRT 策略。
# ---------------------------------------------------------------------------
include(GoogleTest)

# ---- 单元测试:核心库行为;JSON 依赖用于验证序列化结果---------------------
add_executable(test_greeting unit/test_greeting.cpp)
target_link_libraries(test_greeting PRIVATE cpp_template_core nlohmann_json::nlohmann_json gtest_main)
cpp_template_target_defaults(test_greeting)
gtest_discover_tests(test_greeting)

# ---- 依赖冒烟测试:fmt + spdlog + json 联用(验证传递依赖去重)---------------
add_executable(test_deps integration/test_deps.cpp)
target_link_libraries(test_deps
  PRIVATE
    fmt::fmt
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    gtest_main)
cpp_template_target_defaults(test_deps)
gtest_discover_tests(test_deps)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME dependency_engine
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/test_dependencies.py")
set_tests_properties(dependency_engine PROPERTIES TIMEOUT 120)
add_test(NAME dependency_manifest
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/check_deps_pinned.py")
add_test(NAME cli_contract
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/integration/test_cli.py"
    "$<TARGET_FILE:cpp_template>" "${PROJECT_VERSION}")
set_tests_properties(cli_contract PROPERTIES TIMEOUT 120)

# ---------------------------------------------------------------------------
# 单元测试与集成测试
#
# 仅在 BUILD_TESTING=ON 时由根 CMakeLists.txt 加入构建。GoogleTest 由
# Dependencies.cmake 同一开关下拉取,与生产依赖共用同一套 ABI/CRT 策略。
# ---------------------------------------------------------------------------
include(GoogleTest)

# ---- 单元测试:核心库行为(仅链接 cpp_template_core,跨平台)-----------------
add_executable(test_greeting unit/test_greeting.cpp)
target_link_libraries(test_greeting PRIVATE cpp_template_core gtest_main)
gtest_discover_tests(test_greeting)

# ---- 依赖冒烟测试:fmt + spdlog + json 联用(验证传递依赖去重)---------------
add_executable(test_deps integration/test_deps.cpp)
target_link_libraries(test_deps
  PRIVATE
    fmt::fmt
    spdlog::spdlog
    nlohmann_json::nlohmann_json
    gtest_main)
gtest_discover_tests(test_deps)

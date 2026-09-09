# ---------------------------------------------------------------------------
# 性能基准(Google Benchmark)
#
# 仅在 BUILD_BENCHMARKING=ON 时由根 CMakeLists.txt 加入构建。benchmark 库由
# Dependencies.cmake 同一开关下拉取,与生产依赖共用同一套 ABI/CRT 策略。
# 基准不纳入 ctest(无 pass/fail 语义),直接运行二进制查看结果。
#
# 链接 benchmark::benchmark_main(库提供 main()),源文件不再写 BENCHMARK_MAIN(),
# 否则与库的 main() 冲突(MSVC LNK2005 重复符号)。
# ---------------------------------------------------------------------------
add_executable(bench_format bench_format.cpp)
target_link_libraries(bench_format
  PRIVATE
    fmt::fmt
    benchmark::benchmark_main)
cpp_template_target_defaults(bench_format)

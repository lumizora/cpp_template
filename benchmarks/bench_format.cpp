#include <benchmark/benchmark.h>
#include <fmt/format.h>
#include <string>

// 示例基准:演示 Google Benchmark 接线与 API,并证明基准二进制可链接项目依赖
// (此处为 fmt)。实际使用时请替换为待优化的自有代码。
//
// 运行:./build/bench/Release/bench_format.exe
// 过滤:--benchmark_filter=Format
// 输出 JSON:--benchmark_format=json
static void FmtFormatToString(benchmark::State& state) {
    for (auto _ : state) {
        std::string s = fmt::format("answer={} tag={}", 42, "demo");
        benchmark::DoNotOptimize(s);
    }
}
BENCHMARK(FmtFormatToString);

// 对照组:std::string 拼接 + std::to_string,与 fmt::format 做横向比较,
// 演示如何在同一文件里做多实现对比基准。
static void StdStringConcat(benchmark::State& state) {
    for (auto _ : state) {
        std::string s = "answer=";
        s += std::to_string(42);
        s += " tag=demo";
        benchmark::DoNotOptimize(s);
    }
}
BENCHMARK(StdStringConcat);

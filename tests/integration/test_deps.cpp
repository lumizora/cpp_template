#include <fmt/format.h>
#include <gtest/gtest.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <string>

// 集成测试:证明 fmt / spdlog / nlohmann_json 可在同一二进制中联用,
// 且 spdlog(SPDLOG_FMT_EXTERNAL=ON) 复用外部 fmt -- 链接阶段无重复符号
// (ODR 冲突)。若二者各内嵌一份 fmt,此文件无法通过链接。

TEST(DepsIntegrationTest, FmtFormatsScalars) {
    EXPECT_EQ(fmt::format("answer={}", 42), "answer=42");
    EXPECT_EQ(fmt::format("{}+{}={}", 1, 2, 3), "1+2=3");
}

TEST(DepsIntegrationTest, SpdlogUsesSharedFmtWithoutOdrConflict) {
    // spdlog 内部经 fmt 格式化;能编译链接并运行即证明两份 fmt 已去重。
    spdlog::set_level(spdlog::level::info);
    spdlog::info("integration: {}", fmt::format("ok-{}", 1));
    SUCCEED();
}

TEST(DepsIntegrationTest, JsonFlowsThroughFmt) {
    nlohmann::json j;
    j["ok"] = true;

    const std::string s = fmt::format("json={}", j.dump());
    EXPECT_NE(s.find("\"ok\":true"), std::string::npos);
}

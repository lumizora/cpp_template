#include <fmt/format.h>
#include <gtest/gtest.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <string>

// 依赖联用的冒烟测试。外部 fmt 配置由构建清单控制;
// 单次成功链接与运行本身不能证明不存在所有 ODR 问题。

TEST(DepsIntegrationTest, FmtFormatsScalars) {
    EXPECT_EQ(fmt::format("answer={}", 42), "answer=42");
    EXPECT_EQ(fmt::format("{}+{}={}", 1, 2, 3), "1+2=3");
}

TEST(DepsIntegrationTest, SpdlogFormatsMessage) {
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

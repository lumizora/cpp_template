#include "core/greeting.h"

#include <gtest/gtest.h>
#include <nlohmann/json.hpp>
#include <string>

// 核心库单元测试:验证 make_greeting / build_info 的行为。
// 仅链接 cpp_template_core,无 GLFW 等二进制依赖,跨平台。

TEST(GreetingTest, MakeGreeting) {
    EXPECT_EQ(cpp_template::make_greeting("world"), "Hello, world!");
    EXPECT_NE(cpp_template::make_greeting("模板").find("模板"), std::string::npos);
}

TEST(GreetingTest, BuildInfoIsJson) {
    const auto info = nlohmann::json::parse(cpp_template::build_info("world"));
    EXPECT_EQ(info.at("project"), "cpp-template");
    EXPECT_EQ(info.at("greeting"), "Hello, world!");
}

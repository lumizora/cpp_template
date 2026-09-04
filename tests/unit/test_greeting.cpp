#include "core/greeting.h"

#include <gtest/gtest.h>
#include <string>

// 核心库单元测试:验证 make_greeting / build_info 的行为。
// 仅链接 cpp_template_core,无 GLFW 等二进制依赖,跨平台。

TEST(GreetingTest, MakeGreeting) {
    EXPECT_EQ(cpp_template::make_greeting("world"), "Hello, world!");
    EXPECT_NE(cpp_template::make_greeting("模板").find("模板"), std::string::npos);
}

TEST(GreetingTest, BuildInfoIsJson) {
    const std::string info = cpp_template::build_info("world");
    EXPECT_NE(info.find("\"project\""), std::string::npos);
    EXPECT_NE(info.find("\"cpp-template\""), std::string::npos);
}

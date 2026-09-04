#pragma once

#include <string>
#include <string_view>

namespace cpp_template {

// 用 fmt 构造问候语(add_dependency 拉取的依赖示例)。
std::string make_greeting(std::string_view name);

// 用 nlohmann_json 构造一段元信息 JSON(add_dependency 拉取的依赖示例)。
std::string build_info(std::string_view name);

}  // namespace cpp_template

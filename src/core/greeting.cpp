#include "core/greeting.h"

#include <fmt/format.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

namespace cpp_template {

std::string make_greeting(std::string_view name) {
    spdlog::debug("make_greeting(name={})", name);
    return fmt::format("Hello, {}!", name);
}

std::string build_info(std::string_view name) {
    nlohmann::json info = {
        {"project", "cpp-template"},
        {"greeting", make_greeting(name)},
        {"dependencies", {"fmt", "spdlog", "nlohmann_json", "cli11", "stb", "glfw"}},
    };
    return info.dump(2);
}

}  // namespace cpp_template

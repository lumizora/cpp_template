#include "core/greeting.h"
#include "core/image_info.h"

#include <CLI/CLI.hpp>
#include <iostream>
#include <nlohmann/json.hpp>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>
#include <string>

#if defined(HAVE_GLFW)
#include <GLFW/glfw3.h>
#endif

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#endif

int main(int argc, char** argv) try {
#if defined(_WIN32) || defined(_WIN64)
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    CLI::App app{"C++ 项目模板:纯 CMake(FetchContent)依赖管理示例"};
    argv = app.ensure_utf8(argv);
    app.set_version_flag("--version", CPP_TEMPLATE_VERSION);

    std::string name = "world";
    int repeat = 1;
    bool verbose = false;
    bool json = false;
    std::string image;

    app.add_option("-n,--name", name, "问候对象")->capture_default_str();
    app.add_option("-r,--repeat", repeat, "问候重复次数")->capture_default_str()->check(CLI::PositiveNumber);
    app.add_flag("-v,--verbose", verbose, "输出 debug 日志");
    app.add_flag("--json", json, "以 JSON 输出元信息(nlohmann_json)");
    const auto* image_option = app.add_option("--image", image, "读取图片尺寸(演示 stb header-only 依赖)");

    CLI11_PARSE(app, argc, argv);

    spdlog::set_default_logger(spdlog::stderr_color_mt("cli"));
    std::cout.exceptions(std::ios::badbit | std::ios::failbit);

    if (verbose) {
        spdlog::set_level(spdlog::level::debug);
    }

    std::optional<cpp_template::ImageSize> size;
    if (image_option->count() != 0) {
        size = cpp_template::image_size(image);
        if (!size) {
            return 1;
        }
    }

    if (json) {
        auto info = nlohmann::json::parse(cpp_template::build_info(name));
        info["repeat"] = repeat;
        if (size) {
            info["image"] = {
                {"path", image}, {"width", size->width}, {"height", size->height}, {"channels", size->channels}};
        }
        std::cout << info.dump(2) << '\n';
    } else {
        for (int i = 0; i < repeat; ++i) {
            std::cout << cpp_template::make_greeting(name) << '\n';
        }
        if (size) {
            std::cout << "image " << image << ": " << size->width << 'x' << size->height << 'x' << size->channels
                      << '\n';
        }
    }

#if defined(HAVE_GLFW)
    // 二进制依赖示例(add_binary_dependency 拉取的 GLFW)。
    spdlog::info("GLFW {}", glfwGetVersionString());
#endif

    std::cout.flush();
    return 0;
} catch (const std::exception& error) {
    std::cerr << "error: " << error.what() << '\n';
    return 1;
}

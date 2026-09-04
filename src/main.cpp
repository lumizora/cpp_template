#include "core/greeting.h"
#include "core/image_info.h"

#include <CLI/CLI.hpp>
#include <spdlog/spdlog.h>
#include <string>

#if defined(HAVE_GLFW)
#include <GLFW/glfw3.h>
#endif

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#endif

int main(int argc, char** argv) {
#if defined(_WIN32) || defined(_WIN64)
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    CLI::App app{"C++ 项目模板:纯 CMake(FetchContent)依赖管理示例"};

    std::string name = "world";
    int repeat = 1;
    bool verbose = false;
    bool json = false;
    std::string image;

    app.add_option("-n,--name", name, "问候对象")->capture_default_str();
    app.add_option("-r,--repeat", repeat, "问候重复次数")->capture_default_str()->check(CLI::PositiveNumber);
    app.add_flag("-v,--verbose", verbose, "输出 debug 日志");
    app.add_flag("--json", json, "以 JSON 输出元信息(nlohmann_json)");
    app.add_option("--image", image, "读取图片尺寸(演示 stb header-only 依赖)");

    CLI11_PARSE(app, argc, argv);

    if (verbose) {
        spdlog::set_level(spdlog::level::debug);
    }

    for (int i = 0; i < repeat; ++i) {
        spdlog::info("{}", cpp_template::make_greeting(name));
    }

    if (json) {
        spdlog::info("{}", cpp_template::build_info(name));
    }

    if (!image.empty()) {
        if (const auto size = cpp_template::image_size(image)) {
            spdlog::info("image {}: {}x{}x{}", image, size->width, size->height, size->channels);
        }
    }

#if defined(HAVE_GLFW)
    // 二进制依赖示例(add_binary_dependency 拉取的 GLFW)。
    spdlog::info("GLFW {}", glfwGetVersionString());
#endif

    return 0;
}

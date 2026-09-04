#pragma once

#include <optional>
#include <string_view>

namespace cpp_template {

struct ImageSize {
    int width = 0;
    int height = 0;
    int channels = 0;
};

// 用 stb_image 读取图片尺寸(add_header_dependency 拉取的 header-only 依赖示例)。
// 读取失败返回 std::nullopt。
std::optional<ImageSize> image_size(std::string_view path);

}  // namespace cpp_template

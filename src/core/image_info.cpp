#include "core/image_info.h"

#include <spdlog/spdlog.h>
#include <stb_image.h>
#include <string>

namespace cpp_template {

std::optional<ImageSize> image_size(std::string_view path) {
    int w = 0, h = 0, c = 0;
    const std::string p(path);
    if (stbi_info(p.c_str(), &w, &h, &c) == 0) {
        spdlog::warn("无法读取图片尺寸: {} ({})", p, stbi_failure_reason());
        return std::nullopt;
    }
    return ImageSize{w, h, c};
}

}  // namespace cpp_template

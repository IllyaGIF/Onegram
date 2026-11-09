#include "media/VideoCodec.h"

namespace tgcalls {

namespace {

bool SameName(const std::string &value, const char *name) {
    size_t i = 0;
    for (; name[i] != 0; ++i) {
        if (i >= value.size()) {
            return false;
        }
        char a = value[i];
        char b = name[i];
        if (a >= 'a' && a <= 'z') {
            a = (char)(a - 'a' + 'A');
        }
        if (b >= 'a' && b <= 'z') {
            b = (char)(b - 'a' + 'A');
        }
        if (a != b) {
            return false;
        }
    }
    return i == value.size();
}

}

VideoCodecType VideoCodecTypeFromName(const std::string &name) {
    if (SameName(name, "VP8")) {
        return VideoCodecType::VP8;
    }
    if (SameName(name, "H264")) {
        return VideoCodecType::H264;
    }
    return VideoCodecType::Unknown;
}

const char *VideoCodecName(VideoCodecType type) {
    switch (type) {
        case VideoCodecType::VP8:
            return "VP8";
        case VideoCodecType::H264:
            return "H264";
        default:
            return "";
    }
}

}

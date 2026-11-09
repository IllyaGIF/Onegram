#include "media/VideoProfile.h"

#if !defined(ONEGRAM_ARMV6)
#include "media/VideoToolboxH264Encoder.h"
#endif

#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/types.h>

namespace tgcalls {

namespace {

enum DeviceClass {
    DeviceArmv6,
    DeviceCortexA8,
    DeviceA4,
    DeviceA5,
    DeviceA6,
    DeviceA7,
    DeviceA8Plus
};

pthread_once_t profileOnce = PTHREAD_ONCE_INIT;
VideoProfile *profile = 0;

std::string Machine() {
    size_t size = 0;
    if (sysctlbyname("hw.machine", 0, &size, 0, 0) != 0 || size == 0) {
        return std::string();
    }
    std::vector<char> buffer(size + 1, 0);
    if (sysctlbyname("hw.machine", &buffer[0], &size, 0, 0) != 0) {
        return std::string();
    }
    return std::string(&buffer[0]);
}

bool Parse(const std::string &machine, const char *prefix, int *major, int *minor) {
    const size_t length = strlen(prefix);
    if (machine.compare(0, length, prefix) != 0) {
        return false;
    }
    const char *version = machine.c_str() + length;
    char *end = 0;
    *major = (int)strtol(version, &end, 10);
    *minor = (end != 0 && *end == ',') ? (int)strtol(end + 1, 0, 10) : 0;
    return true;
}

DeviceClass Classify(const std::string &machine) {
    int major = 0;
    int minor = 0;
    if (Parse(machine, "iPhone", &major, &minor)) {
        if (major <= 1) {
            return DeviceArmv6;
        }
        if (major == 2) {
            return DeviceCortexA8;
        }
        if (major == 3) {
            return DeviceA4;
        }
        if (major == 4) {
            return DeviceA5;
        }
        if (major == 5) {
            return DeviceA6;
        }
        if (major == 6) {
            return DeviceA7;
        }
        return DeviceA8Plus;
    }
    if (Parse(machine, "iPod", &major, &minor)) {
        if (major <= 2) {
            return DeviceArmv6;
        }
        if (major == 3) {
            return DeviceCortexA8;
        }
        if (major == 4) {
            return DeviceA4;
        }
        if (major == 5) {
            return DeviceA5;
        }
        return DeviceA8Plus;
    }
    if (Parse(machine, "iPad", &major, &minor)) {
        if (major == 1) {
            return DeviceA4;
        }
        if (major == 2) {
            return DeviceA5;
        }
        if (major == 3) {
            return minor <= 3 ? DeviceA5 : DeviceA6;
        }
        if (major == 4) {
            return DeviceA7;
        }
        return DeviceA8Plus;
    }
#if defined(__arm64__) || defined(__aarch64__)
    return DeviceA8Plus;
#elif defined(ONEGRAM_ARMV6)
    return DeviceArmv6;
#else
    return DeviceA5;
#endif
}

void AddStep(std::vector<VideoLadderStep> &ladder, int width, int height, int fps, int minBitrate, int maxPixels) {
    if (width * height <= maxPixels) {
        VideoLadderStep step = { width, height, fps, minBitrate };
        ladder.push_back(step);
    }
}

void BuildLadder(std::vector<VideoLadderStep> &ladder, int maxPixels, int maxFps) {
    AddStep(ladder, 1280, 720, 30, 1100000, maxPixels);
    AddStep(ladder, 960, 540, 30, 750000, maxPixels);
    AddStep(ladder, 640, 480, 30, 450000, maxPixels);
    AddStep(ladder, 640, 480, 20, 300000, maxPixels);
    AddStep(ladder, 480, 360, 20, 180000, maxPixels);
    AddStep(ladder, 352, 288, 15, 100000, maxPixels);
    AddStep(ladder, 192, 144, 15, 60000, maxPixels);
    AddStep(ladder, 160, 120, 10, 0, maxPixels);
    for (size_t i = 0; i < ladder.size(); ++i) {
        if (ladder[i].fps > maxFps) {
            ladder[i].fps = maxFps;
        }
    }
}

void CreateProfile() {
    profile = new VideoProfile();
    profile->machine = Machine();
    const DeviceClass deviceClass = Classify(profile->machine);
    int maxPixels = 0;
    int maxSoftwarePixels = 0;
    int maxSoftwareFps = 30;
    switch (deviceClass) {
        case DeviceArmv6:
            profile->canSend = true;
            profile->maxSendBitrate = 120000;
            profile->maxReceiveBitrate = 180000;
            maxSoftwarePixels = 192 * 144;
            maxSoftwareFps = 12;
            profile->softwareEncoderSpeed = -16;
            break;
        case DeviceCortexA8:
            profile->canSend = true;
            profile->maxSendBitrate = 250000;
            profile->maxReceiveBitrate = 350000;
            maxPixels = 352 * 288;
            maxSoftwarePixels = 352 * 288;
            break;
        case DeviceA4:
            profile->canSend = true;
            profile->maxSendBitrate = 450000;
            profile->maxReceiveBitrate = 700000;
            maxPixels = 480 * 360;
            maxSoftwarePixels = 352 * 288;
            break;
        case DeviceA5:
            profile->canSend = true;
            profile->maxSendBitrate = 1000000;
            profile->maxReceiveBitrate = 1400000;
            maxPixels = 640 * 480;
            maxSoftwarePixels = 480 * 360;
            break;
        case DeviceA6:
            profile->canSend = true;
            profile->maxSendBitrate = 1600000;
            profile->maxReceiveBitrate = 2200000;
            maxPixels = 1280 * 720;
            maxSoftwarePixels = 640 * 480;
            profile->softwareEncoderSpeed = -10;
            break;
        case DeviceA7:
            profile->canSend = true;
            profile->maxSendBitrate = 2200000;
            profile->maxReceiveBitrate = 3000000;
            maxPixels = 1280 * 720;
            maxSoftwarePixels = 960 * 540;
            profile->softwareEncoderSpeed = -8;
            break;
        default:
            profile->canSend = true;
            profile->maxSendBitrate = 2800000;
            profile->maxReceiveBitrate = 4000000;
            maxPixels = 1280 * 720;
            maxSoftwarePixels = 1280 * 720;
            profile->softwareEncoderSpeed = -6;
            break;
    }
    profile->startBitrate = profile->maxSendBitrate < 300000 ? profile->maxSendBitrate : 300000;
    BuildLadder(profile->ladder, maxPixels, 30);
    BuildLadder(profile->softwareLadder, maxSoftwarePixels, maxSoftwareFps);
}

}

size_t VideoProfile::initialStepIndex(const std::vector<VideoLadderStep> &steps) const {
    for (size_t i = 0; i < steps.size(); ++i) {
        if (steps[i].minBitrate <= startBitrate) {
            return i;
        }
    }
    return steps.empty() ? 0 : steps.size() - 1;
}

bool VideoProfile::initialCaptureStep(VideoLadderStep &step) const {
#if defined(ONEGRAM_ARMV6)
    const std::vector<VideoLadderStep> &steps = softwareLadder;
#else
    const std::vector<VideoLadderStep> &steps = VideoToolboxH264Encoder::isAvailable() ? ladder : softwareLadder;
#endif
    if (steps.empty()) {
        return false;
    }
    step = steps[initialStepIndex(steps)];
    return true;
}

const VideoProfile &VideoProfile::current() {
    pthread_once(&profileOnce, &CreateProfile);
    return *profile;
}

}

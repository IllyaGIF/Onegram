#ifndef TGCALLS_MEDIA_VIDEO_PROFILE_H
#define TGCALLS_MEDIA_VIDEO_PROFILE_H

#include <string>
#include <vector>

namespace tgcalls {

struct VideoLadderStep {
    int width;
    int height;
    int fps;
    int minBitrate;
};

struct VideoProfile {
    std::string machine;
    bool canSend = false;
    int maxSendBitrate = 0;
    int maxReceiveBitrate = 0;
    int startBitrate = 0;
    int softwareEncoderSpeed = -12;
    std::vector<VideoLadderStep> ladder;
    std::vector<VideoLadderStep> softwareLadder;

    size_t initialStepIndex(const std::vector<VideoLadderStep> &steps) const;
    bool initialCaptureStep(VideoLadderStep &step) const;

    static const VideoProfile &current();
};

}

#endif

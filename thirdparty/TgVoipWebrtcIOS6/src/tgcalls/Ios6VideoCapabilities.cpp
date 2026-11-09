#include "Ios6VideoCapabilities.h"

#include "media/VideoDecoder.h"
#include "media/VideoEncoder.h"
#include "media/VideoProfile.h"

namespace tgcalls {

bool Ios6CanSendVideo() {
    return VideoProfile::current().canSend && !SupportedVideoEncoders().empty();
}

bool Ios6CanReceiveVideo() {
    return !SupportedVideoDecoders().empty();
}

}

#ifndef TGCALLS_MEDIA_NEGOTIATOR_H
#define TGCALLS_MEDIA_NEGOTIATOR_H

#include "v2/Signaling.h"
#include "rtp/RtpPacket.h"

#include "absl/types/optional.h"

#include <stdint.h>
#include <string>
#include <utility>
#include <vector>

namespace tgcalls {

struct NegotiatedPayloadType {
    uint8_t id = 0;
    std::string name;
    uint32_t clockrate = 0;
    uint32_t channels = 0;
    bool hasRtx = false;
    uint8_t rtxId = 0;
    bool nack = false;
    bool pictureLossIndication = false;
    bool fullIntraRequest = false;
    bool receiverEstimatedMaxBitrate = false;
    bool transportFeedback = false;
    std::vector<std::pair<std::string, std::string>> parameters;

    std::string parameter(const std::string &key) const;
};

struct NegotiatedStream {
    bool active = false;
    uint32_t ssrc = 0;
    uint32_t rtxSsrc = 0;
    std::vector<NegotiatedPayloadType> payloadTypes;
    rtp::RtpExtensionMap extensions;

    const NegotiatedPayloadType *payloadType(uint8_t id) const;
    const NegotiatedPayloadType *payloadTypeForRtx(uint8_t rtxId) const;
};

struct NegotiatedMedia {
    uint32_t revision = 0;
    NegotiatedStream incomingAudio;
    NegotiatedStream outgoingAudio;
    NegotiatedStream incomingVideo;
    NegotiatedStream outgoingVideo;
};

struct VideoCodecSupport {
    std::string name;
    std::vector<std::pair<std::string, std::string>> parameters;
};

class MediaNegotiator {
public:
    struct Capabilities {
        std::vector<VideoCodecSupport> videoDecoders;
        std::vector<VideoCodecSupport> videoEncoders;
        bool transportFeedback = false;
    };

    struct RemoteResult {
        absl::optional<signaling::NegotiateChannelsMessage> answer;
        bool mediaChanged = false;
    };

    MediaNegotiator(bool isOutgoing, const Capabilities &capabilities);

    bool offerOutgoingVideo();
    bool outgoingVideoOffered() const { return _videoEnabled; }
    bool canSendVideo() const { return !_capabilities.videoEncoders.empty(); }

    absl::optional<signaling::NegotiateChannelsMessage> takePendingOffer();
    RemoteResult handleRemoteNegotiation(const signaling::NegotiateChannelsMessage &message);

    const NegotiatedMedia &media() const { return _media; }
    uint32_t localAudioSsrc() const { return _audioSsrc; }
    uint32_t localVideoSsrc() const { return _videoSsrc; }

private:
    signaling::MediaContent makeOutgoingAudioContent() const;
    signaling::MediaContent makeOutgoingVideoContent() const;
    bool answerAudio(const signaling::MediaContent &offer, signaling::MediaContent *answer, NegotiatedStream *stream) const;
    bool answerVideo(const signaling::MediaContent &offer, signaling::MediaContent *answer, NegotiatedStream *stream) const;
    void applyAnswer(const signaling::NegotiateChannelsMessage &answer);
    uint32_t generateSsrc(const std::vector<uint32_t> &taken) const;

    bool _isOutgoing;
    Capabilities _capabilities;
    bool _needsNegotiation;
    bool _hasPendingOffer;
    uint32_t _pendingExchangeId;
    uint32_t _audioSsrc;
    uint32_t _videoSsrc;
    uint32_t _videoRtxSsrc;
    bool _videoEnabled;
    NegotiatedMedia _media;
};

}

#endif

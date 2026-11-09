#include "v2/MediaNegotiator.h"

#include <stdlib.h>

namespace tgcalls {

namespace {

const uint8_t kOpusPayloadType = 111;
const uint8_t kFirstVideoPayloadType = 100;
const int kAbsSendTimeId = 3;
const int kTransportSequenceNumberId = 2;
const int kVideoOrientationId = 4;

bool EqualsIgnoringCase(const std::string &lhs, const std::string &rhs) {
    if (lhs.size() != rhs.size()) {
        return false;
    }
    for (size_t i = 0; i < lhs.size(); ++i) {
        char a = lhs[i];
        char b = rhs[i];
        if (a >= 'A' && a <= 'Z') {
            a = (char)(a - 'A' + 'a');
        }
        if (b >= 'A' && b <= 'Z') {
            b = (char)(b - 'A' + 'a');
        }
        if (a != b) {
            return false;
        }
    }
    return true;
}

std::string ParameterValue(const std::vector<std::pair<std::string, std::string>> &parameters, const std::string &key) {
    for (size_t i = 0; i < parameters.size(); ++i) {
        if (parameters[i].first == key) {
            return parameters[i].second;
        }
    }
    return std::string();
}

signaling::FeedbackType Feedback(const char *type, const char *subtype) {
    signaling::FeedbackType feedback;
    feedback.type = type;
    feedback.subtype = subtype;
    return feedback;
}

void ApplyFeedback(const std::vector<signaling::FeedbackType> &feedbackTypes, NegotiatedPayloadType *payload) {
    for (size_t i = 0; i < feedbackTypes.size(); ++i) {
        const signaling::FeedbackType &feedback = feedbackTypes[i];
        if (feedback.type == "nack" && feedback.subtype.empty()) {
            payload->nack = true;
        } else if (feedback.type == "nack" && feedback.subtype == "pli") {
            payload->pictureLossIndication = true;
        } else if (feedback.type == "ccm" && feedback.subtype == "fir") {
            payload->fullIntraRequest = true;
        } else if (feedback.type == "goog-remb") {
            payload->receiverEstimatedMaxBitrate = true;
        } else if (feedback.type == "transport-cc") {
            payload->transportFeedback = true;
        }
    }
}

std::vector<signaling::FeedbackType> FilterVideoFeedback(const std::vector<signaling::FeedbackType> &feedbackTypes, bool transportFeedback) {
    std::vector<signaling::FeedbackType> result;
    for (size_t i = 0; i < feedbackTypes.size(); ++i) {
        const signaling::FeedbackType &feedback = feedbackTypes[i];
        const bool supported =
            (feedback.type == "nack" && (feedback.subtype.empty() || feedback.subtype == "pli")) ||
            (feedback.type == "ccm" && feedback.subtype == "fir") ||
            feedback.type == "goog-remb" ||
            (feedback.type == "transport-cc" && transportFeedback);
        if (supported) {
            result.push_back(feedback);
        }
    }
    return result;
}

std::vector<webrtc::RtpExtension> FilterExtensions(const std::vector<webrtc::RtpExtension> &extensions, bool video, bool transportFeedback, rtp::RtpExtensionMap *map) {
    std::vector<webrtc::RtpExtension> result;
    map->clear();
    for (size_t i = 0; i < extensions.size(); ++i) {
        const rtp::RtpExtensionType type = rtp::RtpExtensionMap::typeForUri(extensions[i].uri);
        bool supported = false;
        switch (type) {
            case rtp::RtpExtensionAbsSendTime:
                supported = true;
                break;
            case rtp::RtpExtensionTransportSequenceNumber:
                supported = transportFeedback;
                break;
            case rtp::RtpExtensionVideoOrientation:
                supported = video;
                break;
            default:
                supported = false;
                break;
        }
        if (supported && map->registerExtension(type, extensions[i].id)) {
            result.push_back(extensions[i]);
        }
    }
    return result;
}

void ParseExtensions(const std::vector<webrtc::RtpExtension> &extensions, rtp::RtpExtensionMap *map) {
    map->clear();
    for (size_t i = 0; i < extensions.size(); ++i) {
        map->registerUri(extensions[i].uri, extensions[i].id);
    }
}

NegotiatedPayloadType MakeNegotiatedPayload(const signaling::PayloadType &payload) {
    NegotiatedPayloadType result;
    result.id = (uint8_t)payload.id;
    result.name = payload.name;
    result.clockrate = payload.clockrate;
    result.channels = payload.channels;
    result.parameters = payload.parameters;
    ApplyFeedback(payload.feedbackTypes, &result);
    return result;
}

bool IsRtx(const signaling::PayloadType &payload) {
    return EqualsIgnoringCase(payload.name, "rtx");
}

bool CodecMatches(const VideoCodecSupport &support, const signaling::PayloadType &payload) {
    if (!EqualsIgnoringCase(support.name, payload.name) || payload.clockrate != 90000) {
        return false;
    }
    for (size_t i = 0; i < support.parameters.size(); ++i) {
        const std::string &key = support.parameters[i].first;
        const std::string value = ParameterValue(payload.parameters, key);
        if (key == "packetization-mode") {
            const std::string effective = value.empty() ? "0" : value;
            if (effective != support.parameters[i].second) {
                return false;
            }
        } else if (key == "profile-level-id") {
            if (value.size() < 2 || support.parameters[i].second.size() < 2 || !EqualsIgnoringCase(value.substr(0, 2), support.parameters[i].second.substr(0, 2))) {
                return false;
            }
        } else if (!value.empty() && value != support.parameters[i].second) {
            return false;
        }
    }
    return true;
}

void LinkRtx(const std::vector<signaling::PayloadType> &payloadTypes, NegotiatedStream *stream) {
    for (size_t i = 0; i < payloadTypes.size(); ++i) {
        if (!IsRtx(payloadTypes[i])) {
            continue;
        }
        const int apt = atoi(ParameterValue(payloadTypes[i].parameters, "apt").c_str());
        for (size_t j = 0; j < stream->payloadTypes.size(); ++j) {
            if (stream->payloadTypes[j].id == apt) {
                stream->payloadTypes[j].hasRtx = true;
                stream->payloadTypes[j].rtxId = (uint8_t)payloadTypes[i].id;
            }
        }
    }
}

uint32_t RtxSsrcFromGroups(const signaling::MediaContent &content) {
    for (size_t i = 0; i < content.ssrcGroups.size(); ++i) {
        const signaling::SsrcGroup &group = content.ssrcGroups[i];
        if (group.semantics == "FID" && group.ssrcs.size() >= 2 && group.ssrcs[0] == content.ssrc) {
            return group.ssrcs[1];
        }
    }
    return 0;
}

}

std::string NegotiatedPayloadType::parameter(const std::string &key) const {
    return ParameterValue(parameters, key);
}

const NegotiatedPayloadType *NegotiatedStream::payloadType(uint8_t id) const {
    for (size_t i = 0; i < payloadTypes.size(); ++i) {
        if (payloadTypes[i].id == id) {
            return &payloadTypes[i];
        }
    }
    return 0;
}

const NegotiatedPayloadType *NegotiatedStream::payloadTypeForRtx(uint8_t rtxId) const {
    for (size_t i = 0; i < payloadTypes.size(); ++i) {
        if (payloadTypes[i].hasRtx && payloadTypes[i].rtxId == rtxId) {
            return &payloadTypes[i];
        }
    }
    return 0;
}

MediaNegotiator::MediaNegotiator(bool isOutgoing, const Capabilities &capabilities) :
_isOutgoing(isOutgoing),
_capabilities(capabilities),
_needsNegotiation(true),
_hasPendingOffer(false),
_pendingExchangeId(0),
_audioSsrc(0),
_videoSsrc(0),
_videoRtxSsrc(0),
_videoEnabled(false) {
    std::vector<uint32_t> taken;
    _audioSsrc = generateSsrc(taken);
    taken.push_back(_audioSsrc);
    _videoSsrc = generateSsrc(taken);
    taken.push_back(_videoSsrc);
    _videoRtxSsrc = generateSsrc(taken);
}

uint32_t MediaNegotiator::generateSsrc(const std::vector<uint32_t> &taken) const {
    for (;;) {
        const uint32_t value = arc4random();
        if (value == 0) {
            continue;
        }
        bool collision = false;
        for (size_t i = 0; i < taken.size(); ++i) {
            if (taken[i] == value) {
                collision = true;
            }
        }
        if (value == _media.incomingAudio.ssrc || value == _media.incomingVideo.ssrc || value == _media.incomingVideo.rtxSsrc) {
            collision = true;
        }
        if (!collision) {
            return value;
        }
    }
}

bool MediaNegotiator::offerOutgoingVideo() {
    if (_videoEnabled || !canSendVideo()) {
        return false;
    }
    _videoEnabled = true;
    _needsNegotiation = true;
    return true;
}

signaling::MediaContent MediaNegotiator::makeOutgoingAudioContent() const {
    signaling::MediaContent content;
    content.type = signaling::MediaContent::Type::Audio;
    content.ssrc = _audioSsrc;
    signaling::PayloadType opus;
    opus.id = kOpusPayloadType;
    opus.name = "opus";
    opus.clockrate = 48000;
    opus.channels = 2;
    opus.parameters.push_back(std::make_pair(std::string("minptime"), std::string("10")));
    opus.parameters.push_back(std::make_pair(std::string("useinbandfec"), std::string("1")));
    if (_capabilities.transportFeedback) {
        opus.feedbackTypes.push_back(Feedback("transport-cc", ""));
    }
    content.payloadTypes.push_back(opus);
    content.rtpExtensions.push_back(webrtc::RtpExtension(rtp::RtpExtensionMap::uriForType(rtp::RtpExtensionAbsSendTime), kAbsSendTimeId));
    content.rtpExtensions.push_back(webrtc::RtpExtension(rtp::RtpExtensionMap::uriForType(rtp::RtpExtensionTransportSequenceNumber), kTransportSequenceNumberId));
    return content;
}

signaling::MediaContent MediaNegotiator::makeOutgoingVideoContent() const {
    signaling::MediaContent content;
    content.type = signaling::MediaContent::Type::Video;
    content.ssrc = _videoSsrc;
    signaling::SsrcGroup group;
    group.semantics = "FID";
    group.ssrcs.push_back(_videoSsrc);
    group.ssrcs.push_back(_videoRtxSsrc);
    content.ssrcGroups.push_back(group);
    uint32_t nextPayloadType = kFirstVideoPayloadType;
    for (size_t i = 0; i < _capabilities.videoEncoders.size(); ++i) {
        const VideoCodecSupport &codec = _capabilities.videoEncoders[i];
        signaling::PayloadType payload;
        payload.id = nextPayloadType++;
        payload.name = codec.name;
        payload.clockrate = 90000;
        payload.channels = 0;
        payload.parameters = codec.parameters;
        payload.feedbackTypes.push_back(Feedback("goog-remb", ""));
        if (_capabilities.transportFeedback) {
            payload.feedbackTypes.push_back(Feedback("transport-cc", ""));
        }
        payload.feedbackTypes.push_back(Feedback("ccm", "fir"));
        payload.feedbackTypes.push_back(Feedback("nack", ""));
        payload.feedbackTypes.push_back(Feedback("nack", "pli"));
        signaling::PayloadType rtx;
        rtx.id = nextPayloadType++;
        rtx.name = "rtx";
        rtx.clockrate = 90000;
        rtx.channels = 0;
        rtx.parameters.push_back(std::make_pair(std::string("apt"), std::to_string(payload.id)));
        content.payloadTypes.push_back(payload);
        content.payloadTypes.push_back(rtx);
    }
    content.rtpExtensions.push_back(webrtc::RtpExtension(rtp::RtpExtensionMap::uriForType(rtp::RtpExtensionAbsSendTime), kAbsSendTimeId));
    content.rtpExtensions.push_back(webrtc::RtpExtension(rtp::RtpExtensionMap::uriForType(rtp::RtpExtensionTransportSequenceNumber), kTransportSequenceNumberId));
    content.rtpExtensions.push_back(webrtc::RtpExtension(rtp::RtpExtensionMap::uriForType(rtp::RtpExtensionVideoOrientation), kVideoOrientationId));
    return content;
}

absl::optional<signaling::NegotiateChannelsMessage> MediaNegotiator::takePendingOffer() {
    if (!_needsNegotiation || _hasPendingOffer) {
        return absl::nullopt;
    }
    _needsNegotiation = false;
    _hasPendingOffer = true;
    do {
        _pendingExchangeId = arc4random();
    } while (_pendingExchangeId == 0);
    signaling::NegotiateChannelsMessage offer;
    offer.exchangeId = _pendingExchangeId;
    offer.contents.push_back(makeOutgoingAudioContent());
    if (_videoEnabled) {
        offer.contents.push_back(makeOutgoingVideoContent());
    }
    return offer;
}

bool MediaNegotiator::answerAudio(const signaling::MediaContent &offer, signaling::MediaContent *answer, NegotiatedStream *stream) const {
    for (size_t i = 0; i < offer.payloadTypes.size(); ++i) {
        const signaling::PayloadType &payload = offer.payloadTypes[i];
        if (!EqualsIgnoringCase(payload.name, "opus") || payload.clockrate != 48000) {
            continue;
        }
        signaling::PayloadType accepted = payload;
        accepted.feedbackTypes.clear();
        for (size_t j = 0; j < payload.feedbackTypes.size(); ++j) {
            if (payload.feedbackTypes[j].type == "transport-cc" && _capabilities.transportFeedback) {
                accepted.feedbackTypes.push_back(payload.feedbackTypes[j]);
            }
        }
        answer->type = signaling::MediaContent::Type::Audio;
        answer->ssrc = offer.ssrc;
        answer->ssrcGroups = offer.ssrcGroups;
        answer->payloadTypes.push_back(accepted);
        answer->rtpExtensions = FilterExtensions(offer.rtpExtensions, false, _capabilities.transportFeedback, &stream->extensions);
        stream->active = true;
        stream->ssrc = offer.ssrc;
        stream->rtxSsrc = 0;
        stream->payloadTypes.push_back(MakeNegotiatedPayload(accepted));
        return true;
    }
    return false;
}

bool MediaNegotiator::answerVideo(const signaling::MediaContent &offer, signaling::MediaContent *answer, NegotiatedStream *stream) const {
    std::vector<signaling::PayloadType> accepted;
    for (size_t i = 0; i < offer.payloadTypes.size(); ++i) {
        const signaling::PayloadType &payload = offer.payloadTypes[i];
        if (IsRtx(payload)) {
            continue;
        }
        for (size_t j = 0; j < _capabilities.videoDecoders.size(); ++j) {
            if (CodecMatches(_capabilities.videoDecoders[j], payload)) {
                signaling::PayloadType filtered = payload;
                filtered.feedbackTypes = FilterVideoFeedback(payload.feedbackTypes, _capabilities.transportFeedback);
                accepted.push_back(filtered);
                break;
            }
        }
    }
    if (accepted.empty()) {
        return false;
    }
    const size_t codecCount = accepted.size();
    for (size_t i = 0; i < offer.payloadTypes.size(); ++i) {
        const signaling::PayloadType &payload = offer.payloadTypes[i];
        if (!IsRtx(payload)) {
            continue;
        }
        const int apt = atoi(ParameterValue(payload.parameters, "apt").c_str());
        for (size_t j = 0; j < codecCount; ++j) {
            if ((int)accepted[j].id == apt) {
                signaling::PayloadType rtx = payload;
                rtx.feedbackTypes.clear();
                accepted.push_back(rtx);
                break;
            }
        }
    }
    answer->type = signaling::MediaContent::Type::Video;
    answer->ssrc = offer.ssrc;
    answer->ssrcGroups = offer.ssrcGroups;
    answer->payloadTypes = accepted;
    answer->rtpExtensions = FilterExtensions(offer.rtpExtensions, true, _capabilities.transportFeedback, &stream->extensions);
    stream->active = true;
    stream->ssrc = offer.ssrc;
    stream->rtxSsrc = RtxSsrcFromGroups(offer);
    for (size_t i = 0; i < codecCount; ++i) {
        stream->payloadTypes.push_back(MakeNegotiatedPayload(accepted[i]));
    }
    LinkRtx(accepted, stream);
    return true;
}

void MediaNegotiator::applyAnswer(const signaling::NegotiateChannelsMessage &answer) {
    NegotiatedStream audio;
    NegotiatedStream video;
    for (size_t i = 0; i < answer.contents.size(); ++i) {
        const signaling::MediaContent &content = answer.contents[i];
        if (content.type == signaling::MediaContent::Type::Audio && content.ssrc == _audioSsrc) {
            for (size_t j = 0; j < content.payloadTypes.size(); ++j) {
                if (EqualsIgnoringCase(content.payloadTypes[j].name, "opus")) {
                    audio.payloadTypes.push_back(MakeNegotiatedPayload(content.payloadTypes[j]));
                }
            }
            if (!audio.payloadTypes.empty()) {
                audio.active = true;
                audio.ssrc = _audioSsrc;
                ParseExtensions(content.rtpExtensions, &audio.extensions);
            }
        } else if (content.type == signaling::MediaContent::Type::Video && content.ssrc == _videoSsrc && _videoEnabled) {
            for (size_t j = 0; j < content.payloadTypes.size(); ++j) {
                if (!IsRtx(content.payloadTypes[j])) {
                    video.payloadTypes.push_back(MakeNegotiatedPayload(content.payloadTypes[j]));
                }
            }
            if (!video.payloadTypes.empty()) {
                video.active = true;
                video.ssrc = _videoSsrc;
                video.rtxSsrc = _videoRtxSsrc;
                LinkRtx(content.payloadTypes, &video);
                ParseExtensions(content.rtpExtensions, &video.extensions);
            }
        }
    }
    _media.outgoingAudio = audio;
    _media.outgoingVideo = video;
    ++_media.revision;
}

MediaNegotiator::RemoteResult MediaNegotiator::handleRemoteNegotiation(const signaling::NegotiateChannelsMessage &message) {
    RemoteResult result;
    if (_hasPendingOffer) {
        if (message.exchangeId == _pendingExchangeId) {
            _hasPendingOffer = false;
            applyAnswer(message);
            result.mediaChanged = true;
            return result;
        }
        if (_isOutgoing) {
            return result;
        }
        _hasPendingOffer = false;
        _needsNegotiation = true;
    }
    signaling::NegotiateChannelsMessage answer;
    answer.exchangeId = message.exchangeId;
    NegotiatedStream incomingAudio;
    NegotiatedStream incomingVideo;
    for (size_t i = 0; i < message.contents.size(); ++i) {
        const signaling::MediaContent &content = message.contents[i];
        signaling::MediaContent accepted;
        if (content.type == signaling::MediaContent::Type::Audio && !incomingAudio.active) {
            if (answerAudio(content, &accepted, &incomingAudio)) {
                answer.contents.push_back(accepted);
            }
        } else if (content.type == signaling::MediaContent::Type::Video && !incomingVideo.active) {
            if (answerVideo(content, &accepted, &incomingVideo)) {
                answer.contents.push_back(accepted);
            }
        }
    }
    _media.incomingAudio = incomingAudio;
    _media.incomingVideo = incomingVideo;
    ++_media.revision;
    result.answer = answer;
    result.mediaChanged = true;
    return result;
}

}

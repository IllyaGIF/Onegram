#include "EncryptedConnection.h"

#include "CryptoHelper.h"
#include "rtc_base/logging.h"
#include "rtc_base/byte_buffer.h"
#include "rtc_base/time_utils.h"

#include <syslog.h>

#include "Ios6DiagnosticLog.h"

namespace tgcalls {
namespace {

constexpr auto kSingleMessagePacketSeqBit = (uint32_t(1) << 31);
constexpr auto kMessageRequiresAckSeqBit = (uint32_t(1) << 30);
constexpr uint32_t kMaxAllowedCounter = uint32_t(0xFFFFFFFFu)
    & ~kSingleMessagePacketSeqBit
    & ~kMessageRequiresAckSeqBit;

static_assert(kMaxAllowedCounter < kSingleMessagePacketSeqBit, "bad");
static_assert(kMaxAllowedCounter < kMessageRequiresAckSeqBit, "bad");

constexpr auto kAckSerializedSize = sizeof(uint32_t) + sizeof(uint8_t);
constexpr auto kNotAckedMessagesLimit = 64 * 1024;
constexpr auto kMaxIncomingPacketSize = 128 * 1024;
constexpr auto kKeepIncomingCountersCount = 64;
constexpr auto kMaxFullPacketSize = 1500;

constexpr auto kMaxOuterPacketSize = kMaxFullPacketSize - 48;

constexpr auto kMaxSignalingPacketSize = 16 * 1024;

constexpr auto kServiceCauseAcks = 1;
constexpr auto kServiceCauseResend = 2;

static constexpr uint8_t kAckId = uint8_t(-1);
static constexpr uint8_t kEmptyId = uint8_t(-2);
static constexpr uint8_t kCustomId = uint8_t(127);

void AppendSeq(rtc::CopyOnWriteBuffer &buffer, uint32_t seq) {
    const auto bytes = rtc::HostToNetwork32(seq);
    buffer.AppendData(reinterpret_cast<const char*>(&bytes), sizeof(bytes));
}

void WriteSeq(void *bytes, uint32_t seq) {
    *reinterpret_cast<uint32_t*>(bytes) = rtc::HostToNetwork32(seq);
}

uint32_t ReadSeq(const void *bytes) {
    return rtc::NetworkToHost32(*reinterpret_cast<const uint32_t*>(bytes));
}

uint32_t CounterFromSeq(uint32_t seq) {
    return seq & ~kSingleMessagePacketSeqBit & ~kMessageRequiresAckSeqBit;
}

absl::nullopt_t LogError(
        const char *message,
        const std::string &additional = std::string()) {
    RTC_LOG(LS_ERROR) << "ERROR! " << message << additional;
    return absl::nullopt;
}

bool ConstTimeIsDifferent(const void *a, const void *b, size_t size) {
    auto ca = reinterpret_cast<const char*>(a);
    auto cb = reinterpret_cast<const char*>(b);
    volatile auto different = false;
    for (const auto ce = ca + size; ca != ce; ++ca, ++cb) {
        different = different | (*ca != *cb);
    }
    return different;
}

bool MessageRequiresAck(const Message &message) {
	const auto data = &message.data;
	if (const auto value = absl::get_if<CandidatesListMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<VideoFormatsMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<RequestVideoMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<RemoteMediaStateMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<AudioDataMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<VideoDataMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<UnstructuredDataMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<VideoParametersMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<RemoteBatteryLevelIsLowMessage>(data)) {
		return value->kRequiresAck;
	} else if (const auto value = absl::get_if<RemoteNetworkStatusMessage>(data)) {
		return value->kRequiresAck;
	}
	return false;
}

rtc::CopyOnWriteBuffer SerializeRawMessageWithSeq(
        const rtc::CopyOnWriteBuffer &message,
        uint32_t seq,
        bool singleMessagePacket) {
    rtc::ByteBufferWriter writer;
    writer.WriteUInt32(seq);
    writer.WriteUInt8(kCustomId);
    writer.WriteUInt32((uint32_t)message.size());
    writer.WriteBytes((const uint8_t *)message.data(), message.size());

    auto result = rtc::CopyOnWriteBuffer();
    result.AppendData(writer.Data(), writer.Length());

    return result;
}

}

#ifdef TGCALLS_IOS6_AUDIO_ONLY

EncryptedConnection::EncryptedConnection(
    Type type,
    const EncryptionKey &key,
    void (*requestSendService)(void *context, int delayMs, int cause),
    void *requestSendServiceContext) :
_type(type),
_key(key),
_delayIntervals(DelayIntervalsByType(type)),
_requestSendServiceC(requestSendService),
_requestSendServiceContext(requestSendServiceContext),
_requestSendService() {
    assert(_key.value);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC service.bridge.construct hasC=%d context=%p",
        requestSendService != 0 ? 1 : 0,
        requestSendServiceContext
    );
}

#endif


EncryptedConnection::EncryptedConnection(
    Type type,
    const EncryptionKey &key,
    std::function<void(int delayMs, int cause)> requestSendService) :
_type(type),
_key(key),
_delayIntervals(DelayIntervalsByType(type)),
_requestSendService(std::move(requestSendService)) {
#ifdef TGCALLS_IOS6_AUDIO_ONLY
    _requestSendServiceC = 0;
    _requestSendServiceContext = 0;
#endif

    assert(_key.value);
}


void EncryptedConnection::requestSendService(
        int delayMs,
        int cause) {
#ifdef TGCALLS_IOS6_AUDIO_ONLY
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC service.bridge.enter hasC=%d context=%p delay=%d cause=%d fallback=%d",
        _requestSendServiceC != 0 ? 1 : 0,
        _requestSendServiceContext,
        delayMs,
        cause,
        _requestSendService ? 1 : 0
    );

    if (_requestSendServiceC != 0) {
        _requestSendServiceC(
            _requestSendServiceContext,
            delayMs,
            cause
        );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC service.bridge.exit mode=c"
        );

        return;
    }

    if (_requestSendService) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC service.bridge.fallback.before"
        );

        _requestSendService(
            delayMs,
            cause
        );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC service.bridge.fallback.after"
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC service.bridge.exit mode=fallback"
    );
#else
    _requestSendService(
        delayMs,
        cause
    );
#endif
}


absl::optional<rtc::CopyOnWriteBuffer> EncryptedConnection::encryptRawPacket(rtc::CopyOnWriteBuffer const &buffer) {
    auto seq = ++_counter;

    rtc::ByteBufferWriter writer;
    writer.WriteUInt32(seq);

    auto result = rtc::CopyOnWriteBuffer();
    result.AppendData(writer.Data(), writer.Length());

    result.AppendData(buffer);

    auto encryptedPacket = encryptPrepared(result);

    rtc::CopyOnWriteBuffer encryptedBuffer;
    encryptedBuffer.AppendData(encryptedPacket.bytes.data(), encryptedPacket.bytes.size());
    return encryptedBuffer;
}

absl::optional<rtc::CopyOnWriteBuffer> EncryptedConnection::decryptRawPacket(rtc::CopyOnWriteBuffer const &buffer) {
    if (buffer.size() < 21 || buffer.size() > kMaxIncomingPacketSize) {
        return absl::nullopt;
    }

    const auto x = (_key.isOutgoing ? 8 : 0) + (_type == Type::Signaling ? 128 : 0);
    const auto key = _key.value->data();
    const auto msgKey = reinterpret_cast<const uint8_t*>(buffer.data());
    const auto encryptedData = msgKey + 16;
    const auto dataSize = buffer.size() - 16;

    auto aesKeyIv = PrepareAesKeyIv(key, msgKey, x);

    auto decryptionBuffer = rtc::Buffer(dataSize);
    AesProcessCtr(
        MemorySpan{ encryptedData, dataSize },
        decryptionBuffer.data(),
        std::move(aesKeyIv));

    const auto msgKeyLarge = ConcatSHA256(
        MemorySpan{ key + 88 + x, 32 },
        MemorySpan{ decryptionBuffer.data(), decryptionBuffer.size() });
    if (ConstTimeIsDifferent(msgKeyLarge.data() + 8, msgKey, 16)) {
        return absl::nullopt;
    }

    const auto incomingSeq = ReadSeq(decryptionBuffer.data());
    const auto incomingCounter = CounterFromSeq(incomingSeq);
    if (!registerIncomingCounter(incomingCounter)) {
        return absl::nullopt;
    }

    rtc::CopyOnWriteBuffer resultBuffer;
    resultBuffer.AppendData(decryptionBuffer.data() + 4, decryptionBuffer.size() - 4);
    return resultBuffer;
}

auto EncryptedConnection::prepareForSending(const Message &message)
-> absl::optional<EncryptedPacket> {
    const auto messageRequiresAck = MessageRequiresAck(message);

    const auto singleMessagePacket = !haveAdditionalMessages() && !messageRequiresAck;
    const auto maybeSeq = computeNextSeq(messageRequiresAck, singleMessagePacket);
    if (!maybeSeq) {
        return absl::nullopt;
    }
    const auto seq = *maybeSeq;
    auto serialized = SerializeMessageWithSeq(message, seq, singleMessagePacket);
    
    return prepareForSendingMessageInternal(serialized, seq, messageRequiresAck);
}

absl::optional<EncryptedConnection::EncryptedPacket> EncryptedConnection::prepareForSendingRawMessage(rtc::CopyOnWriteBuffer &message, bool messageRequiresAck) {
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.enter size=%lu ack=%d",
        (unsigned long)message.size(),
        messageRequiresAck ? 1 : 0);
    const auto singleMessagePacket = !haveAdditionalMessages() && !messageRequiresAck;
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.beforeSeq single=%d additional=%d",
        singleMessagePacket ? 1 : 0,
        haveAdditionalMessages() ? 1 : 0);
    const auto maybeSeq = computeNextSeq(messageRequiresAck, singleMessagePacket);
    if (!maybeSeq) {
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.noSeq");
        return absl::nullopt;
    }
    const auto seq = *maybeSeq;
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.seq seq=%u", seq);
    auto serialized = SerializeRawMessageWithSeq(message, seq, singleMessagePacket);
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.serialized size=%lu", (unsigned long)serialized.size());
    
    auto result = prepareForSendingMessageInternal(serialized, seq, messageRequiresAck);
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareRaw.exit has=%d", result ? 1 : 0);
    return result;
}
	    
absl::optional<EncryptedConnection::EncryptedPacket> EncryptedConnection::prepareForSendingMessageInternal(rtc::CopyOnWriteBuffer &serialized, uint32_t seq, bool messageRequiresAck) {
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.enter size=%lu seq=%u ack=%d",
        (unsigned long)serialized.size(),
        seq,
        messageRequiresAck ? 1 : 0);
    if (!enoughSpaceInPacket(serialized, 0)) {
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.tooLarge size=%lu", (unsigned long)serialized.size());
        return LogError("Too large packet: ", std::to_string(serialized.size()));
    }
    const auto notYetAckedCopy = messageRequiresAck
        ? serialized
        : rtc::CopyOnWriteBuffer();
    if (!messageRequiresAck) {
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.noAck.skipAppend size=%lu additional=%d",
            (unsigned long)serialized.size(),
            haveAdditionalMessages() ? 1 : 0);
        auto result = encryptPrepared(serialized);
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.noAck.afterEncrypt bytes=%lu", (unsigned long)result.bytes.size());
        return result;
    }
    const auto type = uint8_t(serialized.cdata()[4]);
    const auto sendEnqueued = !_myNotYetAckedMessages.empty();
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.ack type=%u enqueued=%d notAcked=%lu",
        (unsigned int)type,
        sendEnqueued ? 1 : 0,
        (unsigned long)_myNotYetAckedMessages.size());
    if (sendEnqueued) {
        RTC_LOG(LS_INFO) << logHeader()
            << "Enqueue SEND:type" << type << "#" << CounterFromSeq(seq);
    } else {
        RTC_LOG(LS_INFO) << logHeader()
            << "Add SEND:type" << type << "#" << CounterFromSeq(seq);
        appendAdditionalMessages(serialized);
    }
	MessageForResend resend;
	resend.data = notYetAckedCopy;
	resend.lastSent = rtc::TimeMillis();
    _myNotYetAckedMessages.push_back(resend);
    if (!sendEnqueued) {
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.ack.beforeEncrypt size=%lu notAcked=%lu",
            (unsigned long)serialized.size(),
            (unsigned long)_myNotYetAckedMessages.size());
        auto result = encryptPrepared(serialized);
        syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.ack.afterEncrypt bytes=%lu counter=%u",
            (unsigned long)result.bytes.size(),
            result.counter);
        return result;
    }
    for (auto &queued : _myNotYetAckedMessages) {
        queued.lastSent = 0;
    }
    syslog(LOG_NOTICE, "IOS6WEBRTC cxx.enc.prepareInternal.ack.service");
    return prepareForSendingService(0);
}

auto EncryptedConnection::prepareForSendingService(int cause)
-> absl::optional<EncryptedPacket> {
    if (cause == kServiceCauseAcks) {
        _sendAcksTimerActive = false;
    } else if (cause == kServiceCauseResend) {
        _resendTimerActive = false;
    }
    if (!haveAdditionalMessages()) {
        return absl::nullopt;
    }
    const auto messageRequiresAck = false;
    const auto singleMessagePacket = false;
    const auto seq = computeNextSeq(messageRequiresAck, singleMessagePacket);
    if (!seq) {
        return absl::nullopt;
    }
    auto serialized = SerializeEmptyMessageWithSeq(*seq);
    assert(enoughSpaceInPacket(serialized, 0));

    RTC_LOG(LS_INFO) << logHeader()
        << "SEND:empty#" << CounterFromSeq(*seq);

    appendAdditionalMessages(serialized);
    return encryptPrepared(serialized);
}

bool EncryptedConnection::haveAdditionalMessages() const {
    return !_myNotYetAckedMessages.empty() || !_acksToSendSeqs.empty();
}

absl::optional<uint32_t> EncryptedConnection::computeNextSeq(
        bool messageRequiresAck,
        bool singleMessagePacket) {
    if (messageRequiresAck && _myNotYetAckedMessages.size() >= kNotAckedMessagesLimit) {
        return LogError("Too many not ACKed messages.");
    } else if (_counter == kMaxAllowedCounter) {
        return LogError("Outgoing packet limit reached.");
    }

    return (++_counter)
        | (singleMessagePacket ? kSingleMessagePacketSeqBit : 0)
        | (messageRequiresAck ? kMessageRequiresAckSeqBit : 0);
}

size_t EncryptedConnection::packetLimit() const {
    switch (_type) {
        case Type::Signaling:
            return kMaxSignalingPacketSize;
        default:
            return kMaxOuterPacketSize;
    }
}

bool EncryptedConnection::enoughSpaceInPacket(const rtc::CopyOnWriteBuffer &buffer, size_t amount) const {
    const auto limit = packetLimit();
    return (amount < limit)
        && (16 + buffer.size() + amount <= limit);
}

void EncryptedConnection::appendAcksToSend(rtc::CopyOnWriteBuffer &buffer) {
    auto i = _acksToSendSeqs.begin();
    while ((i != _acksToSendSeqs.end())
        && enoughSpaceInPacket(
            buffer,
            kAckSerializedSize)) {

        RTC_LOG(LS_INFO) << logHeader()
            << "Add ACK#" << CounterFromSeq(*i);

        AppendSeq(buffer, *i);
        buffer.AppendData(&kAckId, 1);
        ++i;
    }
    _acksToSendSeqs.erase(_acksToSendSeqs.begin(), i);
    for (const auto seq : _acksToSendSeqs) {
        RTC_LOG(LS_INFO) << logHeader()
            << "Skip ACK#" << CounterFromSeq(seq)
            << " (no space, length: " << kAckSerializedSize << ", already: " << buffer.size() << ")";
    }
}

size_t EncryptedConnection::fullNotAckedLength() const {
    assert(_myNotYetAckedMessages.size() < kNotAckedMessagesLimit);

    auto result = size_t();
    for (const auto &message : _myNotYetAckedMessages) {
        result += message.data.size();
    }
    return result;
}

void EncryptedConnection::appendAdditionalMessages(rtc::CopyOnWriteBuffer &buffer) {
    appendAcksToSend(buffer);

    if (_myNotYetAckedMessages.empty()) {
        return;
    }

    const auto now = rtc::TimeMillis();
    for (auto &resending : _myNotYetAckedMessages) {
        const auto sent = resending.lastSent;
        const auto when = sent
            ? (sent + _delayIntervals.minDelayBeforeMessageResend)
            : 0;

        assert(resending.data.size() >= 5);
        const auto counter = CounterFromSeq(ReadSeq(resending.data.data()));
        const auto type = uint8_t(resending.data.data()[4]);
        if (when > now) {
            RTC_LOG(LS_INFO) << logHeader()
                << "Skip RESEND:type" << type << "#" << counter
                << " (wait " << (when - now) << "ms).";
            break;
        } else if (enoughSpaceInPacket(buffer, resending.data.size())) {
            RTC_LOG(LS_INFO) << logHeader()
                << "Add RESEND:type" << type << "#" << counter;
            buffer.AppendData(resending.data);
            resending.lastSent = now;
        } else {
            RTC_LOG(LS_INFO) << logHeader()
                << "Skip RESEND:type" << type << "#" << counter
                << " (no space, length: " << resending.data.size() << ", already: " << buffer.size() << ")";
            break;
        }
    }
    if (!_resendTimerActive) {
        _resendTimerActive = true;
        requestSendService(
            _delayIntervals.maxDelayBeforeMessageResend,
            kServiceCauseResend);
    }
}

auto EncryptedConnection::encryptPrepared(const rtc::CopyOnWriteBuffer &buffer)
-> EncryptedPacket {
    auto result = EncryptedPacket();
    result.counter = CounterFromSeq(ReadSeq(buffer.data()));
    result.bytes.resize(16 + buffer.size());

    const auto x = (_key.isOutgoing ? 0 : 8) + (_type == Type::Signaling ? 128 : 0);
    const auto key = _key.value->data();

    const auto msgKeyLarge = ConcatSHA256(
        MemorySpan{ key + 88 + x, 32 },
        MemorySpan{ buffer.data(), buffer.size() });
    const auto msgKey = result.bytes.data();
    memcpy(msgKey, msgKeyLarge.data() + 8, 16);

    auto aesKeyIv = PrepareAesKeyIv(key, msgKey, x);

    AesProcessCtr(
        MemorySpan{ buffer.data(), buffer.size() },
        result.bytes.data() + 16,
        std::move(aesKeyIv));

    return result;
}

bool EncryptedConnection::registerIncomingCounter(uint32_t incomingCounter) {
    auto &list = _largestIncomingCounters;

    const auto position = std::lower_bound(list.begin(), list.end(), incomingCounter);
    const auto largest = list.empty() ? 0 : list.back();
    if (position != list.end() && *position == incomingCounter) {
        // The packet is in the list already.
        return false;
    } else if (incomingCounter + kKeepIncomingCountersCount <= largest) {
        // The packet is too old.
        return false;
    }
    const auto eraseTill = std::find_if(list.begin(), list.end(), [&](uint32_t counter) {
        return (counter + kKeepIncomingCountersCount > incomingCounter);
    });
    if (eraseTill != list.begin()) {
        list.erase(list.begin(), eraseTill);
    }

    const auto insertPosition = std::lower_bound(list.begin(), list.end(), incomingCounter);
    list.insert(insertPosition, incomingCounter);
    return true;
}

auto EncryptedConnection::handleIncomingPacket(const char *bytes, size_t size)
-> absl::optional<DecryptedPacket> {
    if (size < 21 || size > kMaxIncomingPacketSize) {
        return LogError("Bad incoming packet size: ", std::to_string(size));
    }

    const auto x = (_key.isOutgoing ? 8 : 0) + (_type == Type::Signaling ? 128 : 0);
    const auto key = _key.value->data();
    const auto msgKey = reinterpret_cast<const uint8_t*>(bytes);
    const auto encryptedData = msgKey + 16;
    const auto dataSize = size - 16;

    auto aesKeyIv = PrepareAesKeyIv(key, msgKey, x);

    auto decryptionBuffer = rtc::Buffer(dataSize);
    AesProcessCtr(
        MemorySpan{ encryptedData, dataSize },
        decryptionBuffer.data(),
        std::move(aesKeyIv));

    const auto msgKeyLarge = ConcatSHA256(
        MemorySpan{ key + 88 + x, 32 },
        MemorySpan{ decryptionBuffer.data(), decryptionBuffer.size() });
    if (ConstTimeIsDifferent(msgKeyLarge.data() + 8, msgKey, 16)) {
        return LogError("Bad incoming data hash.");
    }

    const auto incomingSeq = ReadSeq(decryptionBuffer.data());
    const auto incomingCounter = CounterFromSeq(incomingSeq);
    if (!registerIncomingCounter(incomingCounter)) {
        return LogError("Already handled packet received.", std::to_string(incomingCounter));
    }
    return processPacket(decryptionBuffer, incomingSeq);
}

absl::optional<EncryptedConnection::DecryptedRawPacket> EncryptedConnection::handleIncomingRawPacket(const char *bytes, size_t size) {
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.enter size=%lu bytesNull=%d",
        (unsigned long)size,
        bytes == NULL ? 1 : 0
    );

    if (size < 21 || size > kMaxIncomingPacketSize) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC enc.raw.badSize size=%lu",
            (unsigned long)size
        );

        return LogError(
            "Bad incoming packet size: ",
            std::to_string(size)
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.header.begin"
    );

    const auto x =
        (_key.isOutgoing ? 8 : 0) +
        (_type == Type::Signaling ? 128 : 0);

    const auto key = _key.value->data();

    const auto msgKey =
        reinterpret_cast<const uint8_t*>(bytes);

    const auto encryptedData =
        msgKey + 16;

    const auto dataSize =
        size - 16;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.header.done x=%d dataSize=%lu",
        (int)x,
        (unsigned long)dataSize
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.aes.prepare"
    );

    auto aesKeyIv =
        PrepareAesKeyIv(
            key,
            msgKey,
            x
        );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.aes.ivReady"
    );

    auto decryptionBuffer =
        rtc::Buffer(dataSize);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.aes.before size=%lu",
        (unsigned long)decryptionBuffer.size()
    );

    AesProcessCtr(
        MemorySpan{
            encryptedData,
            dataSize
        },
        decryptionBuffer.data(),
        std::move(aesKeyIv)
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.aes.after"
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.hash.before"
    );

    const auto msgKeyLarge =
        ConcatSHA256(
            MemorySpan{
                key + 88 + x,
                32
            },
            MemorySpan{
                decryptionBuffer.data(),
                decryptionBuffer.size()
            }
        );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.hash.after"
    );

    if (ConstTimeIsDifferent(
            msgKeyLarge.data() + 8,
            msgKey,
            16
        )) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC enc.raw.hash.fail"
        );

        return LogError(
            "Bad incoming data hash."
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.hash.ok"
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.seq.before buffer=%lu",
        (unsigned long)decryptionBuffer.size()
    );

    const auto incomingSeq =
        ReadSeq(
            decryptionBuffer.data()
        );

    const auto incomingCounter =
        CounterFromSeq(
            incomingSeq
        );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.seq.done seq=%u counter=%u",
        (unsigned int)incomingSeq,
        (unsigned int)incomingCounter
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.register.before"
    );

    if (!registerIncomingCounter(
            incomingCounter
        )) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC enc.raw.register.duplicate counter=%u",
            (unsigned int)incomingCounter
        );

        return LogError(
            "Already handled packet received.",
            std::to_string(incomingCounter)
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.register.ok"
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.process.before seq=%u",
        (unsigned int)incomingSeq
    );

    auto result =
        processRawPacket(
            decryptionBuffer,
            incomingSeq
        );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC enc.raw.process.after has=%d",
        result ? 1 : 0
    );

    return result;
}

auto EncryptedConnection::processPacket(
    const rtc::Buffer &fullBuffer,
    uint32_t packetSeq)
-> absl::optional<DecryptedPacket> {
    assert(fullBuffer.size() >= 5);

    auto additionalMessage = false;
    auto firstMessageRequiringAck = true;
    auto newRequiringAckReceived = false;

    auto currentSeq = packetSeq;
    auto currentCounter = CounterFromSeq(currentSeq);
    rtc::ByteBufferReader reader(
        reinterpret_cast<const char *>(fullBuffer.data() + 4),
        fullBuffer.size() - 4);

    auto result = absl::optional<DecryptedPacket>();
    while (true) {
        const auto type = uint8_t(*reader.Data());
        const auto singleMessagePacket = ((currentSeq & kSingleMessagePacketSeqBit) != 0);
        if (singleMessagePacket && additionalMessage) {
            return LogError("Single message packet bit in not first message.");
        }

        if (type == kEmptyId) {
            if (additionalMessage) {
                return LogError("Empty message should be only the first one in the packet.");
            }
            RTC_LOG(LS_INFO) << logHeader()
                << "Got RECV:empty" << "#" << currentCounter;
            reader.Consume(1);
        } else if (type == kAckId) {
            if (!additionalMessage) {
                return LogError("Ack message must not be the first one in the packet.");
            }
            ackMyMessage(currentSeq);
            reader.Consume(1);
        } else if (auto message = DeserializeMessage(reader, singleMessagePacket)) {
            const auto messageRequiresAck = ((currentSeq & kMessageRequiresAckSeqBit) != 0);
            const auto skipMessage = messageRequiresAck
                ? !registerSentAck(currentCounter, firstMessageRequiringAck)
                : (additionalMessage && !registerIncomingCounter(currentCounter));
            if (messageRequiresAck) {
                firstMessageRequiringAck = false;
                if (!skipMessage) {
                    newRequiringAckReceived = true;
                }
                sendAckPostponed(currentSeq);
                RTC_LOG(LS_INFO) << logHeader()
                    << (skipMessage ? "Repeated RECV:type" : "Got RECV:type") << type << "#" << currentCounter;
            }
            if (!skipMessage) {
                appendReceivedMessage(result, std::move(*message), currentSeq);
            }
        } else {
            return LogError("Could not parse message from packet, type: ", std::to_string(type));
        }
        if (!reader.Length()) {
            break;
        } else if (singleMessagePacket) {
            return LogError("Single message didn't fill the entire packet.");
        } else if (reader.Length() < 5) {
            return LogError("Bad remaining data size: ", std::to_string(reader.Length()));
        }
        const auto success = reader.ReadUInt32(&currentSeq);
        assert(success);
        (void)success;
        currentCounter = CounterFromSeq(currentSeq);

        additionalMessage = true;
    }

    if (!_acksToSendSeqs.empty()) {
        if (newRequiringAckReceived) {
            requestSendService(0, 0);
        } else if (!_sendAcksTimerActive) {
            _sendAcksTimerActive = true;
            requestSendService(
                _delayIntervals.maxDelayBeforeAckResend,
                kServiceCauseAcks);
        }
    }

    return result;
}

auto EncryptedConnection::processRawPacket(
    const rtc::Buffer &fullBuffer,
    uint32_t packetSeq)
-> absl::optional<DecryptedRawPacket> {
    assert(fullBuffer.size() >= 5);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC processRaw.enter size=%lu seq=%u counter=%u data=%p",
        (unsigned long)fullBuffer.size(),
        (unsigned int)packetSeq,
        (unsigned int)CounterFromSeq(packetSeq),
        (const void *)fullBuffer.data()
    );

    auto additionalMessage = false;
    auto firstMessageRequiringAck = true;
    auto newRequiringAckReceived = false;

    auto currentSeq = packetSeq;
    auto currentCounter = CounterFromSeq(currentSeq);
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC processRaw.reader.before payload=%p payloadLen=%lu",
        (const void *)(fullBuffer.data() + 4),
        (unsigned long)(fullBuffer.size() - 4)
    );

    rtc::ByteBufferReader reader(
        reinterpret_cast<const char *>(fullBuffer.data() + 4), // Skip seq.
        fullBuffer.size() - 4);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC processRaw.reader.after len=%lu data=%p",
        (unsigned long)reader.Length(),
        (const void *)reader.Data()
    );

    auto result = absl::optional<DecryptedRawPacket>();
    while (true) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.loop.begin len=%lu seq=%u additional=%d data=%p",
            (unsigned long)reader.Length(),
            (unsigned int)currentSeq,
            additionalMessage ? 1 : 0,
            (const void *)reader.Data()
        );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.type.before"
        );

        const auto type = uint8_t(*reader.Data());

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.type.after type=%u len=%lu",
            (unsigned int)type,
            (unsigned long)reader.Length()
        );

        const auto singleMessagePacket = ((currentSeq & kSingleMessagePacketSeqBit) != 0);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.flags single=%d requiresAck=%d counter=%u",
            singleMessagePacket ? 1 : 0,
            ((currentSeq & kMessageRequiresAckSeqBit) != 0) ? 1 : 0,
            (unsigned int)currentCounter
        );
        if (singleMessagePacket && additionalMessage) {
            return LogError("Single message packet bit in not first message.");
        }

        if (type == kEmptyId) {
            if (additionalMessage) {
                return LogError("Empty message should be only the first one in the packet.");
            }
            RTC_LOG(LS_INFO) << logHeader()
                << "Got RECV:empty" << "#" << currentCounter;
            reader.Consume(1);
        } else if (type == kAckId) {
            if (!additionalMessage) {
                return LogError("Ack message must not be the first one in the packet.");
            }
            ackMyMessage(currentSeq);
            reader.Consume(1);
        } else if (type == kCustomId) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.custom.consume.before len=%lu",
                (unsigned long)reader.Length()
            );

            reader.Consume(1);

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.custom.consume.after len=%lu data=%p",
                (unsigned long)reader.Length(),
                (const void *)reader.Data()
            );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.deserialize.before single=%d len=%lu",
                singleMessagePacket ? 1 : 0,
                (unsigned long)reader.Length()
            );

            if (auto message = DeserializeRawMessage(reader, singleMessagePacket)) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.deserialize.after ok=1 messageSize=%lu remaining=%lu",
                    (unsigned long)message->size(),
                    (unsigned long)reader.Length()
                );

                const auto messageRequiresAck = ((currentSeq & kMessageRequiresAckSeqBit) != 0);

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.message.flags requiresAck=%d firstAck=%d additional=%d",
                    messageRequiresAck ? 1 : 0,
                    firstMessageRequiringAck ? 1 : 0,
                    additionalMessage ? 1 : 0
                );
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.register.before counter=%u",
                    (unsigned int)currentCounter
                );

                const auto skipMessage = messageRequiresAck
                    ? !registerSentAck(currentCounter, firstMessageRequiringAck)
                    : (additionalMessage && !registerIncomingCounter(currentCounter));

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.register.after skip=%d",
                    skipMessage ? 1 : 0
                );

                if (messageRequiresAck) {
                    firstMessageRequiringAck = false;
                    if (!skipMessage) {
                        newRequiringAckReceived = true;
                    }
                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC processRaw.ackPost.before seq=%u",
                        (unsigned int)currentSeq
                    );

                    sendAckPostponed(currentSeq);

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC processRaw.ackPost.after"
                    );

                    RTC_LOG(LS_INFO) << logHeader()
                        << (skipMessage ? "Repeated RECV:type" : "Got RECV:type") << type << "#" << currentCounter;
                }
                if (!skipMessage) {
                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC processRaw.append.before size=%lu seq=%u hasResult=%d",
                        (unsigned long)message->size(),
                        (unsigned int)currentSeq,
                        result ? 1 : 0
                    );

                    appendReceivedRawMessage(
                        result,
                        std::move(*message),
                        currentSeq
                    );

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC processRaw.append.after hasResult=%d additional=%lu",
                        result ? 1 : 0,
                        result
                            ? (unsigned long)result->additional.size()
                            : 0UL
                    );
                }
            } else {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.deserialize.after ok=0 remaining=%lu",
                    (unsigned long)reader.Length()
                );

                return LogError("Could not parse message from packet, type: ", std::to_string(type));
            }
        } else {
            return LogError("Could not parse message from packet, type: ", std::to_string(type));
        }
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.message.done remaining=%lu",
            (unsigned long)reader.Length()
        );

        if (!reader.Length()) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.loop.complete"
            );

            break;
        } else if (singleMessagePacket) {
            return LogError("Single message didn't fill the entire packet.");
        } else if (reader.Length() < 5) {
            return LogError("Bad remaining data size: ", std::to_string(reader.Length()));
        }
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.nextSeq.before len=%lu",
            (unsigned long)reader.Length()
        );

        const auto success = reader.ReadUInt32(&currentSeq);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC processRaw.nextSeq.after success=%d seq=%u",
            success ? 1 : 0,
            (unsigned int)currentSeq
        );

        assert(success);
        (void)success;
        currentCounter = CounterFromSeq(currentSeq);

        additionalMessage = true;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC processRaw.acks.begin count=%lu newAck=%d timer=%d",
        (unsigned long)_acksToSendSeqs.size(),
        newRequiringAckReceived ? 1 : 0,
        _sendAcksTimerActive ? 1 : 0
    );

    if (!_acksToSendSeqs.empty()) {
        if (newRequiringAckReceived) {
#ifdef TGCALLS_IOS6_AUDIO_ONLY
            if (!_sendAcksTimerActive) {
                _sendAcksTimerActive = true;

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.ackService.defer delay=10 cause=%d acks=%lu",
                    (int)kServiceCauseAcks,
                    (unsigned long)_acksToSendSeqs.size()
                );

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.ackService.callback.before"
                );

                requestSendService(
                    10,
                    kServiceCauseAcks
                );

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC processRaw.ackService.callback.after"
                );
            }
#else
            requestSendService(0, 0);
#endif
        } else if (!_sendAcksTimerActive) {
            _sendAcksTimerActive = true;

#ifdef TGCALLS_IOS6_AUDIO_ONLY
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.ackService.normal.before delay=%d cause=%d",
                (int)_delayIntervals.maxDelayBeforeAckResend,
                (int)kServiceCauseAcks
            );
#endif

            requestSendService(
                _delayIntervals.maxDelayBeforeAckResend,
                kServiceCauseAcks);

#ifdef TGCALLS_IOS6_AUDIO_ONLY
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC processRaw.ackService.normal.after"
            );
#endif
        }
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC processRaw.return has=%d additional=%lu",
        result ? 1 : 0,
        result
            ? (unsigned long)result->additional.size()
            : 0UL
    );

    return result;
}

void EncryptedConnection::appendReceivedMessage(
        absl::optional<DecryptedPacket> &to,
        Message &&message,
        uint32_t incomingSeq) {
    DecryptedMessage decrypted;
	decrypted.message = std::move(message);
	decrypted.counter = CounterFromSeq(incomingSeq);
    if (to) {
        to->additional.push_back(std::move(decrypted));
    } else {
        DecryptedPacket packet;
		packet.main = std::move(decrypted);
		to = packet;
    }
}

void EncryptedConnection::appendReceivedRawMessage(
        absl::optional<DecryptedRawPacket> &to,
        rtc::CopyOnWriteBuffer &&message,
        uint32_t incomingSeq) {
    DecryptedRawMessage decrypted;
	decrypted.message = std::move(message);
	decrypted.counter = CounterFromSeq(incomingSeq);
    if (to) {
        to->additional.push_back(std::move(decrypted));
    } else {
        DecryptedRawPacket packet;
		packet.main = std::move(decrypted);
		to = packet;
    }
}

const char *EncryptedConnection::logHeader() const {
    return (_type == Type::Signaling) ? "(signaling) " : "(transport) ";
}

bool EncryptedConnection::registerSentAck(uint32_t counter, bool firstInPacket) {
    auto &list = _acksSentCounters;

    const auto position = std::lower_bound(list.begin(), list.end(), counter);
    const auto already = (position != list.end()) && (*position == counter);

    const auto was = list;
    if (firstInPacket) {
        list.erase(list.begin(), position);
        if (!already) {
            list.insert(list.begin(), counter);
        }
    } else if (!already) {
        list.insert(position, counter);
    }
    return !already;
}

void EncryptedConnection::sendAckPostponed(uint32_t incomingSeq) {
    auto &list = _acksToSendSeqs;
    const auto already = std::find(list.begin(), list.end(), incomingSeq);
    if (already == list.end()) {
        list.push_back(incomingSeq);
    }
}

void EncryptedConnection::ackMyMessage(uint32_t seq) {
    auto type = uint8_t(0);
    auto &list = _myNotYetAckedMessages;
    for (auto i = list.begin(), e = list.end(); i != e; ++i) {
        assert(i->data.size() >= 5);
        if (ReadSeq(i->data.cdata()) == seq) {
            type = uint8_t(i->data.cdata()[4]);
            list.erase(i);
            break;
        }
    }
    RTC_LOG(LS_INFO) << logHeader()
        << (type ? "Got ACK:type" + std::to_string(type) + "#" : "Repeated ACK#")
        << CounterFromSeq(seq);
}

auto EncryptedConnection::DelayIntervalsByType(Type type) -> DelayIntervals {
    auto result = DelayIntervals();
    const auto signaling = (type == Type::Signaling);

    result.minDelayBeforeMessageResend = signaling ? 3000 : 300;

    result.maxDelayBeforeMessageResend = signaling ? 5000 : 1000;
    result.maxDelayBeforeAckResend = signaling ? 5000 : 1000;

    return result;
}

rtc::CopyOnWriteBuffer EncryptedConnection::SerializeEmptyMessageWithSeq(uint32_t seq) {
    auto result = rtc::CopyOnWriteBuffer(5);
    uint8_t *bytes = reinterpret_cast<uint8_t *>(result.MutableData());
    WriteSeq(bytes, seq);
    bytes[4] = kEmptyId;
    return result;
}

}
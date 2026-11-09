#include "Manager.h"
#include "NetworkManager.h"
#include "VideoState.h"
#include "media/VideoDecoder.h"
#include "media/VideoEncoder.h"
#include "media/VideoProfile.h"
#include "v2/Signaling.h"

#include "CryptoHelper.h"

#include "rtc_base/byte_buffer.h"
#include "rtc_base/logging.h"
#include "StaticThreads.h"

#include <fstream>
#include <iomanip>
#include <stdio.h>
#include <string.h>
#include <syslog.h>
#include <sstream>
#ifdef TGCALLS_IOS6_AUDIO_ONLY
#include <dispatch/dispatch.h>
#endif

#include "Ios6DiagnosticLog.h"

namespace tgcalls {
namespace {

void dumpStatsLog(const FilePath &path, const CallStats &stats) {
	if (path.data.empty()) {
		return;
	}
    std::ofstream file;
    file.open(path.data.c_str());

    file << "{";
    file << "\"v\":\"" << 1 << "\"";
    file << ",";

    file << "\"codec\":\"" << stats.outgoingCodec << "\"";
    file << ",";

    file << "\"bitrate\":[";
    bool addComma = false;
    for (auto &it : stats.bitrateRecords) {
        if (addComma) {
            file << ",";
        }
        file << "{";
        file << "\"t\":\"" << it.timestamp << "\"";
        file << ",";
        file << "\"b\":\"" << it.bitrate << "\"";
        file << "}";
        addComma = true;
    }
    file << "]";
    file << ",";

    file << "\"network\":[";
    addComma = false;
    for (auto &it : stats.networkRecords) {
        if (addComma) {
            file << ",";
        }
        file << "{";
        file << "\"t\":\"" << it.timestamp << "\"";
        file << ",";
        file << "\"e\":\"" << (int)(it.endpointType) << "\"";
        file << ",";
        file << "\"w\":\"" << (it.isLowCost ? 1 : 0) << "\"";
        file << "}";
        addComma = true;
    }
    file << "]";

    file << "}";

	file.close();
}

std::string fingerprintFromKey(const EncryptionKey &key) {
	if (!key.value) {
		return "00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF";
	}
	const auto digest = ConcatSHA256(MemorySpan{ key.value->data(), EncryptionKey::kSize });
	std::ostringstream result;
	result << std::uppercase << std::hex << std::setfill('0');
	for (size_t i = 0; i < digest.size(); i++) {
		if (i != 0) {
			result << ":";
		}
		result << std::setw(2) << (unsigned int)digest[i];
	}
	return result.str();
}

Message makeRemoteNetworkStatusMessage(bool isLowCost, bool isLowDataRequested) {
	RemoteNetworkStatusMessage payload;
	payload.isLowCost = isLowCost;
	payload.isLowDataRequested = isLowDataRequested;
	Message message;
	message.data = payload;
	return message;
}

std::string ios6JsonEscape(const std::string &value) {
	std::string result;
	result.reserve(value.size() + 8);
	for (char c : value) {
		if (c == '\\' || c == '"') {
			result.push_back('\\');
			result.push_back(c);
		} else if (c == '\n') {
			result += "\\n";
		} else if (c == '\r') {
			result += "\\r";
		} else if (c == '\t') {
			result += "\\t";
		} else {
			result.push_back(c);
		}
	}
	return result;
}



}

bool Manager::ResolvedNetworkStatus::operator==(const ResolvedNetworkStatus &rhs) const {
    if (rhs.isLowCost != isLowCost) {
        return false;
    }
    if (rhs.isLowDataRequested != isLowDataRequested) {
        return false;
    }
    return true;
}

bool Manager::ResolvedNetworkStatus::operator!=(const ResolvedNetworkStatus &rhs) const {
    return !(*this == rhs);
}

Manager::Manager(rtc::Thread *thread, Descriptor &&descriptor) :
_thread(thread),
_encryptionKey(descriptor.encryptionKey),
#ifdef TGCALLS_IOS6_AUDIO_ONLY
_signaling(
	EncryptedConnection::Type::Signaling,
	_encryptionKey,
	&Manager::ios56SendSignalingService,
	this),
#else
_signaling(
	EncryptedConnection::Type::Signaling,
	_encryptionKey,
	[=](int delayMs, int cause) {
		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.cb.enter this=%p delay=%d cause=%d",
			(void *)this,
			delayMs,
			cause
		);

		sendSignalingAsync(delayMs, cause);

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.cb.exit this=%p",
			(void *)this
		);
	}),
#endif
_useRawSignaling(descriptor.version == "7.0.0"),
_enableP2P(descriptor.config.enableP2P),
_enableTCP(descriptor.config.allowTCP),
_enableStunMarking(descriptor.config.enableStunMarking),
_protocolVersion(descriptor.config.protocolVersion),
_statsLogPath(descriptor.config.statsLogPath),
_rtcServers(std::move(descriptor.rtcServers)),
_proxy(std::move(descriptor.proxy)),
_mediaDevicesConfig(std::move(descriptor.mediaDevicesConfig)),
_videoCapture(std::move(descriptor.videoCapture)),
_stateUpdated(std::move(descriptor.stateUpdated)),
_remoteMediaStateUpdated(std::move(descriptor.remoteMediaStateUpdated)),
_remoteBatteryLevelIsLowUpdated(std::move(descriptor.remoteBatteryLevelIsLowUpdated)),
_remotePrefferedAspectRatioUpdated(std::move(descriptor.remotePrefferedAspectRatioUpdated)),
_signalingDataEmitted(std::move(descriptor.signalingDataEmitted)),
_signalBarsUpdated(std::move(descriptor.signalBarsUpdated)),
_audioLevelUpdated(std::move(descriptor.audioLevelUpdated)),
_createAudioDeviceModule(std::move(descriptor.createAudioDeviceModule)),
_enableHighBitrateVideo(descriptor.config.enableHighBitrateVideo),
_dataSaving(descriptor.config.dataSaving),
_outgoingVideoSource(descriptor.outgoingVideoSource),
_incomingVideoSink(descriptor.incomingVideoSink) {
	fprintf(stderr, "IOS6WEBRTC cxx.manager.init.enter servers=%lu enableP2P=%d enableTCP=%d protocol=%d\n",
		(unsigned long)_rtcServers.size(),
		_enableP2P ? 1 : 0,
		_enableTCP ? 1 : 0,
		(int)_protocolVersion);
	fflush(stderr);
	syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.init.enter servers=%lu enableP2P=%d enableTCP=%d protocol=%d",
		(unsigned long)_rtcServers.size(),
		_enableP2P ? 1 : 0,
		_enableTCP ? 1 : 0,
		(int)_protocolVersion);
	assert(_thread->IsCurrent());
	assert(_stateUpdated);
	assert(_signalingDataEmitted);

    _preferredCodecs = descriptor.config.preferredVideoCodecs;
	_negotiator.reset(new MediaNegotiator(_encryptionKey.isOutgoing, localMediaCapabilities()));

	_sendSignalingMessage = [=](const Message &message) {
		fprintf(stderr, "IOS6WEBRTC cxx.manager.signaling.prepare.enter\n");
		fflush(stderr);
		syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.signaling.prepare.enter");
		if (const auto candidates = absl::get_if<CandidatesListMessage>(&message.data)) {
			fprintf(stderr, "IOS6WEBRTC cxx.manager.signaling.candidates count=%lu ufrag=%lu pwd=%lu\n",
				(unsigned long)candidates->candidates.size(),
				(unsigned long)candidates->iceParameters.ufrag.size(),
				(unsigned long)candidates->iceParameters.pwd.size());
			fflush(stderr);
			syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.signaling.candidates count=%lu ufrag=%lu pwd=%lu",
				(unsigned long)candidates->candidates.size(),
				(unsigned long)candidates->iceParameters.ufrag.size(),
				(unsigned long)candidates->iceParameters.pwd.size());
			RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.signaling.candidates count=" << candidates->candidates.size()
				<< " ufragLen=" << candidates->iceParameters.ufrag.size()
				<< " pwdLen=" << candidates->iceParameters.pwd.size();
				if (!_sentIos6V2Bootstrap) {
					return sendIos6Bootstrap(*candidates);
				}
			} else if (absl::get_if<RemoteNetworkStatusMessage>(&message.data)) {
			RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.signaling.dropRemoteNetworkStatus";
			return uint32_t(0);
		} else if (absl::get_if<RemoteMediaStateMessage>(&message.data)) {
			RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.signaling.dropRemoteMediaState";
			return uint32_t(0);
		} else if (absl::get_if<VideoFormatsMessage>(&message.data)) {
			RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.signaling.dropVideoFormats";
			return uint32_t(0);
		} else {
			RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.signaling.dropOther";
			return uint32_t(0);
		}
		if (const auto prepared = _signaling.prepareForSending(message)) {
			fprintf(stderr, "IOS6WEBRTC cxx.manager.signaling.emit bytes=%lu counter=%u\n",
				(unsigned long)prepared->bytes.size(),
				prepared->counter);
			fflush(stderr);
			syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.signaling.emit bytes=%lu counter=%u",
				(unsigned long)prepared->bytes.size(),
				prepared->counter);
			_signalingDataEmitted(prepared->bytes);
			return prepared->counter;
		}
		fprintf(stderr, "IOS6WEBRTC cxx.manager.signaling.prepare.nil\n");
		fflush(stderr);
		syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.signaling.prepare.nil");
		return uint32_t(0);
	};
	_sendTransportMessage = [=](Message message) {
        const char *messageType =
            absl::get_if<AudioDataMessage>(&message.data)
                ? "audio"
            : absl::get_if<RemoteMediaStateMessage>(&message.data)
                ? "mediaState"
            : absl::get_if<RemoteNetworkStatusMessage>(&message.data)
                ? "networkStatus"
            : absl::get_if<RemoteBatteryLevelIsLowMessage>(&message.data)
                ? "battery"
            : absl::get_if<UnstructuredDataMessage>(&message.data)
                ? "unstructured"
                : "other";

        if (strcmp(messageType, "audio") != 0) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC manager.transport.out.enter type=%s",
                messageType
            );
        }

		std::shared_ptr<Message> messagePtr(new Message(message));

		_networkManager->perform([messagePtr](NetworkManager *networkManager) {
            const char *queuedType =
                absl::get_if<AudioDataMessage>(&messagePtr->data)
                    ? "audio"
                : absl::get_if<RemoteMediaStateMessage>(&messagePtr->data)
                    ? "mediaState"
                : absl::get_if<RemoteNetworkStatusMessage>(&messagePtr->data)
                    ? "networkStatus"
                : absl::get_if<RemoteBatteryLevelIsLowMessage>(&messagePtr->data)
                    ? "battery"
                : absl::get_if<UnstructuredDataMessage>(&messagePtr->data)
                    ? "unstructured"
                    : "other";

            if (strcmp(queuedType, "audio") != 0) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC manager.transport.out.network type=%s",
                    queuedType
                );
            }

			networkManager->sendMessage(*messagePtr);
		});
	};
}

Manager::~Manager() {
	assert(_thread->IsCurrent());
	if (_mediaTransport) {
		_mediaTransport->shutdown();
	}
}

#ifdef TGCALLS_IOS6_AUDIO_ONLY

void Manager::ios56SendSignalingService(
        void *context,
        int delayMs,
        int cause) {
    Manager *manager =
        static_cast<Manager *>(context);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC service.thunk.enter context=%p manager=%p delay=%d cause=%d",
        context,
        (void *)manager,
        delayMs,
        cause
    );

    if (manager != 0) {
        manager->sendSignalingAsync(
            delayMs,
            cause
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC service.thunk.exit"
    );
}

#endif


void Manager::sendSignalingAsync(int delayMs, int cause) {
	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC service.async.enter this=%p thread=%p delay=%d cause=%d",
		(void *)this,
		(void *)_thread,
		delayMs,
		cause
	);

	std::weak_ptr<Manager> weak(shared_from_this());
	rtc::Thread *thread = _thread;

	auto task = [weak, cause] {
		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.task.enter cause=%d",
			cause
		);

		const auto strong = weak.lock();

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.task.lock strong=%d",
			strong ? 1 : 0
		);

		if (!strong) {
			return;
		}

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.task.prepare.before cause=%d",
			cause
		);

		if (const auto prepared =
				strong->_signaling.prepareForSendingService(cause)) {

			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC service.task.prepare.after has=1 bytes=%lu",
				(unsigned long)prepared->bytes.size()
			);

			strong->_signalingDataEmitted(
				prepared->bytes
			);

			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC service.task.emit.after"
			);
		} else {
			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC service.task.prepare.after has=0"
			);
		}

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.task.exit"
		);
	};

#ifdef TGCALLS_IOS6_AUDIO_ONLY

	if (delayMs > 0) {
		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.ios56.delay.schedule ms=%d cause=%d",
			delayMs,
			cause
		);

		std::shared_ptr<decltype(task)> taskPtr(
			new decltype(task)(std::move(task))
		);

		int64_t ns =
			(int64_t)delayMs *
			1000000LL;

		dispatch_after(
			dispatch_time(
				DISPATCH_TIME_NOW,
				ns
			),
			dispatch_get_global_queue(
				DISPATCH_QUEUE_PRIORITY_DEFAULT,
				0
			),
			^{
				syslog(
					LOG_NOTICE,
					"IOS6WEBRTC service.ios56.delay.fire ms=%d cause=%d",
					delayMs,
					cause
				);

				thread->PostTask(
					[taskPtr]() {
						(*taskPtr)();
					}
				);
			}
		);

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC service.ios56.delay.scheduled"
		);

		return;
	}

	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC service.ios56.post.before cause=%d",
		cause
	);

	thread->PostTask(
		std::move(task)
	);

	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC service.ios56.post.after"
	);

#else

	if (delayMs) {
		_thread->PostDelayedTask(
			std::move(task),
			webrtc::TimeDelta::Millis(delayMs)
		);
	} else {
		_thread->PostTask(
			std::move(task)
		);
	}

#endif

	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC service.async.exit"
	);
}

void Manager::start() {
	fprintf(stderr, "IOS6WEBRTC cxx.manager.start.enter servers=%lu\n", (unsigned long)_rtcServers.size());
	fflush(stderr);
	syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.start.enter servers=%lu", (unsigned long)_rtcServers.size());
	const auto weak = std::weak_ptr<Manager>(shared_from_this());
	const auto thread = _thread;
	const auto sendSignalingMessage = [=](Message message) {
		std::shared_ptr<Message> messagePtr(new Message(message));
		thread->PostTask([=]() mutable {
			const auto strong = weak.lock();
			if (!strong) {
				return;
			}
			strong->_sendSignalingMessage(std::move(*messagePtr));
		});
	};
	EncryptionKey encryptionKey = _encryptionKey;
	bool isOutgoing = _encryptionKey.isOutgoing;
	bool enableP2P = _enableP2P;
	bool enableTCP = _enableTCP;
	bool enableStunMarking = _enableStunMarking;
	std::vector<RtcServer> rtcServers = _rtcServers;
	std::shared_ptr<std::unique_ptr<Proxy>> proxyPtr(new std::unique_ptr<Proxy>(std::move(_proxy)));
	_mediaTransport.reset(new MediaTransport());
	std::shared_ptr<MediaTransport> mediaTransport = _mediaTransport;
	syslog(LOG_NOTICE, "IOS6MEDIA video.hubs source=%d sink=%d", _outgoingVideoSource ? 1 : 0, _incomingVideoSink ? 1 : 0);
	if (!_outgoingVideoSource) {
		_outgoingVideoSource.reset(new VideoSourceHub());
	}
	if (!_incomingVideoSink) {
		_incomingVideoSink.reset(new VideoSinkHub());
	}
	std::shared_ptr<VideoSourceHub> outgoingVideoSource = _outgoingVideoSource;
	std::shared_ptr<VideoSinkHub> incomingVideoSink = _incomingVideoSink;
	fprintf(stderr, "IOS6WEBRTC cxx.manager.network.before\n");
	fflush(stderr);
	syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.network.before");
	_networkManager.reset(new ThreadLocalObject<NetworkManager>(StaticThreads::getNetworkThread(), [weak, thread, sendSignalingMessage, encryptionKey, isOutgoing, enableP2P, enableTCP, enableStunMarking, rtcServers, proxyPtr, mediaTransport] () mutable {
		fprintf(stderr, "IOS6WEBRTC cxx.manager.network.construct.lambda servers=%lu\n", (unsigned long)rtcServers.size());
		fflush(stderr);
		syslog(LOG_NOTICE, "IOS6WEBRTC cxx.manager.network.construct.lambda servers=%lu", (unsigned long)rtcServers.size());
		return std::make_shared<NetworkManager>(
            StaticThreads::getNetworkThread(),
			encryptionKey,
            isOutgoing,
			enableP2P,
            enableTCP,
            enableStunMarking,
			rtcServers,
            std::move(*proxyPtr),
            mediaTransport,
			[=](const NetworkManager::State &state) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC manager.network.state.callback ready=%d failed=%d",
                    state.isReadyToSendData ? 1 : 0,
                    state.isFailed ? 1 : 0
                );

				thread->PostTask([=] {
					const auto strong = weak.lock();
					if (!strong) {
						return;
					}
                    State mappedState;
                    if (state.isFailed) {
                        mappedState = State::Failed;
                    } else {
                        mappedState = state.isReadyToSendData
                            ? State::Established
                            : State::Reconnecting;
                    }
                    bool isFirstConnection = false;
					if (state.isReadyToSendData) {
						if (!strong->_didConnectOnce) {
							strong->_didConnectOnce = true;
                            isFirstConnection = true;
						}
					}
                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC manager.network.state.apply ready=%d failed=%d first=%d didConnect=%d mapped=%d",
                        state.isReadyToSendData ? 1 : 0,
                        state.isFailed ? 1 : 0,
                        isFirstConnection ? 1 : 0,
                        strong->_didConnectOnce ? 1 : 0,
                        (int)mappedState
                    );

					strong->_state = mappedState;
					strong->_stateUpdated(mappedState);

					strong->_mediaManager->perform([=](MediaManager *mediaManager) {
                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC manager.media.setConnected.begin connected=%d",
                            state.isReadyToSendData ? 1 : 0
                        );

						mediaManager->setIsConnected(state.isReadyToSendData);

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC manager.media.setConnected.end connected=%d",
                            state.isReadyToSendData ? 1 : 0
                        );
					});

                    if (isFirstConnection) {
                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC manager.initialMessages.begin"
                        );

                        strong->sendInitialSignalingMessages();

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC manager.initialMessages.end"
                        );
                    }
				});
			},
			[=](DecryptedMessage message) {
				std::shared_ptr<DecryptedMessage> messagePtr(new DecryptedMessage(message));
				thread->PostTask([=]() mutable {
					if (const auto strong = weak.lock()) {
						strong->receiveMessage(std::move(*messagePtr));
					}
				});
			},
			sendSignalingMessage,
			[=](int delayMs, int cause) {
				const auto task = [=] {
					if (const auto strong = weak.lock()) {
						strong->_networkManager->perform([=](NetworkManager *networkManager) {
							networkManager->sendTransportService(cause);
							});
					}
				};
				if (delayMs) {
					thread->PostDelayedTask(task, webrtc::TimeDelta::Millis(delayMs));
				} else {
					thread->PostTask(task);
				}
			});
	}));
	ProtocolVersion protocolVersion = _protocolVersion;
	std::shared_ptr<VideoCaptureInterface> videoCapture = _videoCapture;
	MediaDevicesConfig mediaDevicesConfig = _mediaDevicesConfig;
	bool enableHighBitrateVideo = _enableHighBitrateVideo;
	std::function<void(int)> signalBarsUpdated = _signalBarsUpdated;
	std::function<void(float)> audioLevelUpdated = _audioLevelUpdated;
	std::vector<std::string> preferredCodecs = _preferredCodecs;
	std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)> createAudioDeviceModule = _createAudioDeviceModule;
	_mediaManager.reset(new ThreadLocalObject<MediaManager>(StaticThreads::getMediaThread(), [weak, isOutgoing, protocolVersion, thread, sendSignalingMessage, videoCapture, mediaDevicesConfig, enableHighBitrateVideo, signalBarsUpdated, audioLevelUpdated, preferredCodecs, createAudioDeviceModule, mediaTransport, outgoingVideoSource, incomingVideoSink]() {
		return std::make_shared<MediaManager>(
            StaticThreads::getMediaThread(),
			isOutgoing,
            protocolVersion,
			mediaDevicesConfig,
			videoCapture,
			sendSignalingMessage,
			[=](Message message) {
				std::shared_ptr<Message> messagePtr(new Message(message));
				thread->PostTask([=]() mutable {
					const auto strong = weak.lock();
					if (!strong) {
						return;
					}
					strong->_sendTransportMessage(std::move(*messagePtr));
				});
			},
            signalBarsUpdated,
            audioLevelUpdated,
			createAudioDeviceModule,
			enableHighBitrateVideo,
            preferredCodecs,
            mediaTransport,
            outgoingVideoSource,
            incomingVideoSink);
	}));
    _networkManager->perform([](NetworkManager *networkManager) {
        networkManager->start();
    });
	applyNegotiatedMedia();
	_mediaManager->perform([](MediaManager *mediaManager) {
		mediaManager->start();
	});
}

void Manager::receiveSignalingData(const std::vector<uint8_t> &data) {
#ifdef TGCALLS_IOS6_AUDIO_ONLY
	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC manager.rx.enter len=%lu ptr=%d",
		(unsigned long)data.size(),
		data.empty() ? 0 : 1
	);

	syslog(
		LOG_NOTICE,
		"IOS6WEBRTC manager.rx.beforeRaw"
	);

	auto processRawMessage = [this](const rtc::CopyOnWriteBuffer &raw) {
		if (raw.size() == 0) {
			syslog(LOG_NOTICE,
				"IOS6WEBRTC v2.rx.raw.empty");
			return;
		}

		std::vector<uint8_t> bytes(
			raw.data(),
			raw.data() + raw.size()
		);

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC v2.rx.raw len=%lu first=%02x%02x%02x%02x",
			(unsigned long)bytes.size(),
			bytes.size() > 0 ? (unsigned int)bytes[0] : 0,
			bytes.size() > 1 ? (unsigned int)bytes[1] : 0,
			bytes.size() > 2 ? (unsigned int)bytes[2] : 0,
			bytes.size() > 3 ? (unsigned int)bytes[3] : 0
		);

		const auto parsed = signaling::Message::parse(bytes);
		if (!parsed) {
			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC v2.rx.parse.fail len=%lu",
				(unsigned long)bytes.size()
			);
			return;
		}

		const auto messageData = &parsed->data;

		if (const auto initialSetup =
				absl::get_if<signaling::InitialSetupMessage>(messageData)) {

			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC v2.remote.initialSetup ufrag=%s pwdLen=%lu renomination=%d fingerprints=%lu",
				initialSetup->ufrag.c_str(),
				(unsigned long)initialSetup->pwd.size(),
				initialSetup->supportsRenomination ? 1 : 0,
				(unsigned long)initialSetup->fingerprints.size()
			);

			if (!initialSetup->fingerprints.empty()) {
				_ios6RemoteDtlsHash =
					initialSetup->fingerprints[0].hash;
				_ios6RemoteDtlsFingerprint =
					initialSetup->fingerprints[0].fingerprint;
				_ios6RemoteDtlsSetup =
					initialSetup->fingerprints[0].setup;

				_ios6RemoteDtlsReady =
					!_ios6RemoteDtlsHash.empty()
					&& !_ios6RemoteDtlsFingerprint.empty();

				syslog(
					LOG_NOTICE,
					"IOS6WEBRTC dtls.remote hash=%s setup=%s fingerprint=%s ready=%d",
					_ios6RemoteDtlsHash.c_str(),
					_ios6RemoteDtlsSetup.c_str(),
					_ios6RemoteDtlsFingerprint.c_str(),
					_ios6RemoteDtlsReady ? 1 : 0
				);
			} else {
				_ios6RemoteDtlsReady = false;

				syslog(
					LOG_ERR,
					"IOS6WEBRTC dtls.remote.missingFingerprint"
				);
			}

			CandidatesListMessage bridge;
			bridge.iceParameters.ufrag = initialSetup->ufrag;
			bridge.iceParameters.pwd = initialSetup->pwd;
			bridge.iceParameters.supportsRenomination =
				initialSetup->supportsRenomination;

			std::shared_ptr<DecryptedMessage> messagePtr(
				new DecryptedMessage()
			);
			messagePtr->message.data = bridge;

			X509 *localDtlsCertificate =
				_ios6DtlsCertificate.certificate();

			EVP_PKEY *localDtlsPrivateKey =
				_ios6DtlsCertificate.privateKey();

			const std::string remoteDtlsHash =
				_ios6RemoteDtlsHash;

			const std::string remoteDtlsFingerprint =
				_ios6RemoteDtlsFingerprint;

			const std::string remoteDtlsSetup =
				_ios6RemoteDtlsSetup;

			const bool remoteDtlsReady =
				_ios6RemoteDtlsReady;

			_networkManager->perform(
				[
					messagePtr,
					localDtlsCertificate,
					localDtlsPrivateKey,
					remoteDtlsHash,
					remoteDtlsFingerprint,
					remoteDtlsSetup,
					remoteDtlsReady
				](NetworkManager *networkManager) mutable {

#ifdef TGCALLS_IOS6_AUDIO_ONLY
					if (remoteDtlsReady &&
						localDtlsCertificate != NULL &&
						localDtlsPrivateKey != NULL) {

						networkManager->setIos6DtlsParameters(
							localDtlsCertificate,
							localDtlsPrivateKey,
							remoteDtlsHash,
							remoteDtlsFingerprint,
							remoteDtlsSetup
						);
					}
#endif

					networkManager->receiveSignalingMessage(
						std::move(*messagePtr)
					);
				}
			);

			return;
		}

		if (const auto candidates =
				absl::get_if<signaling::CandidatesMessage>(messageData)) {

			syslog(
				LOG_NOTICE,
				"IOS6WEBRTC v2.remote.candidates count=%lu",
				(unsigned long)candidates->iceCandidates.size()
			);

			CandidatesListMessage bridge;

			for (size_t i = 0;
				 i < candidates->iceCandidates.size();
				 ++i) {

				const std::string &sdp =
					candidates->iceCandidates[i].sdpString;

				syslog(
					LOG_NOTICE,
					"IOS6WEBRTC v2.remote.candidate index=%lu sdp=%s",
					(unsigned long)i,
					sdp.c_str()
				);

				cricket::Candidate candidate;
				candidate.FromString(sdp);
				bridge.candidates.push_back(candidate);
			}

			std::shared_ptr<DecryptedMessage> messagePtr(
				new DecryptedMessage()
			);
			messagePtr->message.data = bridge;

			_networkManager->perform(
				[messagePtr](NetworkManager *networkManager) mutable {
					networkManager->receiveSignalingMessage(
						std::move(*messagePtr)
					);
				}
			);

			return;
		}

		if (const auto negotiate =
				absl::get_if<signaling::NegotiateChannelsMessage>(
					messageData)) {
			handleRemoteNegotiation(*negotiate);
			return;
		}

		if (const auto mediaState =
				absl::get_if<signaling::MediaStateMessage>(
					messageData)) {
			handleRemoteMediaState(*mediaState);
			return;
		}

		syslog(
			LOG_NOTICE,
			"IOS6WEBRTC v2.remote.other"
		);
	};

	if (_useRawSignaling) {
		if (auto decrypted = _signaling.decryptRawPacket(rtc::CopyOnWriteBuffer(data.data(), data.size()))) {
			processRawMessage(*decrypted);
		}
	} else if (auto decrypted = _signaling.handleIncomingRawPacket(
			(const char *)data.data(),
			data.size())) {
		processRawMessage(decrypted->main.message);

		for (const auto &additional : decrypted->additional) {
			processRawMessage(additional.message);
		}
	}
#else
	if (auto decrypted = _signaling.handleIncomingPacket(
			(const char*)data.data(),
			data.size())) {
		receiveMessage(std::move(decrypted->main));
		for (auto &message : decrypted->additional) {
			receiveMessage(std::move(message));
		}
	}
#endif
}

void Manager::receiveMessage(DecryptedMessage &&message) {
	const auto data = &message.message.data;
	if (const auto candidatesList = absl::get_if<CandidatesListMessage>(data)) {
		std::shared_ptr<DecryptedMessage> messagePtr(new DecryptedMessage(message));
		_networkManager->perform([messagePtr](NetworkManager *networkManager) mutable {
			networkManager->receiveSignalingMessage(std::move(*messagePtr));
		});
	} else if (const auto videoFormats = absl::get_if<VideoFormatsMessage>(data)) {
		std::shared_ptr<DecryptedMessage> messagePtr(new DecryptedMessage(message));
		_mediaManager->perform([messagePtr](MediaManager *mediaManager) mutable {
			mediaManager->receiveMessage(std::move(*messagePtr));
		});
    } else if (const auto remoteMediaState = absl::get_if<RemoteMediaStateMessage>(data)) {
		if (_remoteMediaStateUpdated) {
			_remoteMediaStateUpdated(
				remoteMediaState->audio,
				remoteMediaState->video);
		}
		VideoState video = remoteMediaState->video;
        _mediaManager->perform([video](MediaManager *mediaManager) {
            mediaManager->remoteVideoStateUpdated(video);
        });
	} else if (const auto remoteBatteryLevelIsLow = absl::get_if<RemoteBatteryLevelIsLowMessage>(data)) {
        if (_remoteBatteryLevelIsLowUpdated) {
			_remoteBatteryLevelIsLowUpdated(remoteBatteryLevelIsLow->batteryLow);
        }
    } else if (const auto remoteNetworkStatus = absl::get_if<RemoteNetworkStatusMessage>(data)) {
        _remoteNetworkIsLowCost = remoteNetworkStatus->isLowCost;
        _remoteIsLowDataRequested = remoteNetworkStatus->isLowDataRequested;
        updateCurrentResolvedNetworkStatus();
    } else {
        if (const auto videoParameters = absl::get_if<VideoParametersMessage>(data)) {
            float value = ((float)videoParameters->aspectRatio) / 1000.0;
			if (_remotePrefferedAspectRatioUpdated) {
				_remotePrefferedAspectRatioUpdated(value);
			}
        }
		std::shared_ptr<DecryptedMessage> messagePtr(new DecryptedMessage(message));
		_mediaManager->perform([=](MediaManager *mediaManager) mutable {
			mediaManager->receiveMessage(std::move(*messagePtr));
		});
	}
}

void Manager::setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture) {
	assert(_didConnectOnce);

	if (_videoCapture == videoCapture) {
		return;
	}
    _videoCapture = videoCapture;
    _mediaManager->perform([videoCapture](MediaManager *mediaManager) {
        mediaManager->setSendVideo(videoCapture);
    });
}

void Manager::sendVideoDeviceUpdated() {
    _mediaManager->perform([](MediaManager *mediaManager) {
        mediaManager->sendVideoDeviceUpdated();
    });
}

void Manager::setRequestedVideoAspect(float aspect) {
    _mediaManager->perform([aspect](MediaManager *mediaManager) {
        mediaManager->setRequestedVideoAspect(aspect);
    });
}

void Manager::setMuteOutgoingAudio(bool mute) {
	_mediaManager->perform([mute](MediaManager *mediaManager) {
		mediaManager->setMuteOutgoingAudio(mute);
	});
	if (_localMediaState.isMuted != mute) {
		_localMediaState.isMuted = mute;
		sendMediaState();
	}
}

void Manager::setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
	_mediaManager->perform([sink](MediaManager *mediaManager) {
		mediaManager->setIncomingVideoOutput(sink);
	});
}

void Manager::setIsLowBatteryLevel(bool isLowBatteryLevel) {
	if (_localMediaState.isBatteryLow != isLowBatteryLevel) {
		_localMediaState.isBatteryLow = isLowBatteryLevel;
		sendMediaState();
	}
}

void Manager::setIsLocalNetworkLowCost(bool isLocalNetworkLowCost) {
    if (isLocalNetworkLowCost != _localNetworkIsLowCost) {
        _networkManager->perform([isLocalNetworkLowCost](NetworkManager *networkManager) {
            networkManager->setIsLocalNetworkLowCost(isLocalNetworkLowCost);
        });

        _localNetworkIsLowCost = isLocalNetworkLowCost;
        updateCurrentResolvedNetworkStatus();
    }
}

void Manager::getNetworkStats(std::function<void (TrafficStats, CallStats)> completion) {
	rtc::Thread *thread = _thread;
	std::weak_ptr<Manager> weak(shared_from_this());
	std::shared_ptr<std::function<void (TrafficStats, CallStats)>> completionPtr(new std::function<void (TrafficStats, CallStats)>(std::move(completion)));
	FilePath statsLogPath = _statsLogPath;
    _networkManager->perform([thread, weak, completionPtr, statsLogPath](NetworkManager *networkManager) {
        auto networkStats = networkManager->getNetworkStats();

        CallStats callStats;
        networkManager->fillCallStats(callStats);

		std::shared_ptr<CallStats> callStatsPtr(new CallStats(std::move(callStats)));
        thread->PostTask([weak, networkStats, completionPtr, callStatsPtr, statsLogPath] {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }

            strong->_mediaManager->perform([networkStats, completionPtr, callStatsPtr, statsLogPath](MediaManager *mediaManager) {
                CallStats callStats = std::move(*callStatsPtr);
                mediaManager->fillCallStats(callStats);
                dumpStatsLog(statsLogPath, callStats);
                (*completionPtr)(networkStats, callStats);
            });
        });
    });
}

void Manager::updateCurrentResolvedNetworkStatus() {
    bool localIsLowDataRequested = false;
    switch (_dataSaving) {
        case DataSaving::Never:
            localIsLowDataRequested = false;
            break;
        case DataSaving::Mobile:
            localIsLowDataRequested = !_localNetworkIsLowCost;
            break;
        case DataSaving::Always:
            localIsLowDataRequested = true;
        default:
            break;
    }

    ResolvedNetworkStatus localStatus;
    localStatus.isLowCost = _localNetworkIsLowCost;
    localStatus.isLowDataRequested = localIsLowDataRequested;

    if (!_currentResolvedLocalNetworkStatus.has_value() || *_currentResolvedLocalNetworkStatus != localStatus) {
        _currentResolvedLocalNetworkStatus = localStatus;

        switch (_protocolVersion) {
            case ProtocolVersion::V1:
                RTC_LOG(LS_INFO) << "IOS6WEBRTC manager.skipNetworkStatusUpdate";
                break;
            default:
                break;
        }
    }

    ResolvedNetworkStatus status;
    status.isLowCost = _localNetworkIsLowCost && _remoteNetworkIsLowCost;
    status.isLowDataRequested = localIsLowDataRequested || _remoteIsLowDataRequested;

    if (!_currentResolvedNetworkStatus.has_value() || *_currentResolvedNetworkStatus != status) {
        _currentResolvedNetworkStatus = status;
        _mediaManager->perform([status](MediaManager *mediaManager) {
            mediaManager->setNetworkParameters(status.isLowCost, status.isLowDataRequested);
        });
    }
}

void Manager::sendInitialSignalingMessages() {
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC manager.sendInitial.enter"
    );
    _mediaStateReady = true;
    sendMediaState();
}

MediaNegotiator::Capabilities Manager::localMediaCapabilities() {
	MediaNegotiator::Capabilities capabilities;
	capabilities.transportFeedback = true;
	capabilities.videoDecoders = SupportedVideoDecoders();
	if (VideoProfile::current().canSend) {
		capabilities.videoEncoders = SupportedVideoEncoders();
	}
	return capabilities;
}

void Manager::setOutgoingVideoEnabled(bool enabled) {
	if (enabled && !_negotiator->canSendVideo()) {
		enabled = false;
	}
	const signaling::MediaStateMessage::VideoState videoState = enabled ? signaling::MediaStateMessage::VideoState::Active : signaling::MediaStateMessage::VideoState::Inactive;
	syslog(LOG_NOTICE, "IOS6WEBRTC video.outgoing.enabled value=%d negotiation=%d offered=%d", enabled ? 1 : 0, _negotiationStarted ? 1 : 0, _negotiator->outgoingVideoOffered() ? 1 : 0);
	if (enabled && _negotiator->offerOutgoingVideo()) {
		if (_negotiationStarted) {
			sendPendingOffer();
		}
		applyNegotiatedMedia();
	}
	if (_localMediaState.videoState != videoState) {
		_localMediaState.videoState = videoState;
		sendMediaState();
	}
}

uint32_t Manager::emitRawSignaling(const std::vector<uint8_t> &serialized, bool requiresAck) {
	if (serialized.empty()) {
		return 0;
	}
	rtc::CopyOnWriteBuffer buffer;
	buffer.AppendData(serialized.data(), serialized.size());
	if (_useRawSignaling) {
		const auto raw = _signaling.encryptRawPacket(buffer);
		if (!raw) {
			return 0;
		}
		_signalingDataEmitted(std::vector<uint8_t>(raw->data(), raw->data() + raw->size()));
		return 1;
	}
	const auto packet = _signaling.prepareForSendingRawMessage(buffer, requiresAck);
	if (!packet) {
		return 0;
	}
	_signalingDataEmitted(packet->bytes);
	return packet->counter;
}

uint32_t Manager::sendIos6Bootstrap(const CandidatesListMessage &candidates) {
	if (!_ios6DtlsCertificate.certificate() && !_ios6DtlsCertificate.generate()) {
		syslog(LOG_ERR, "IOS6WEBRTC dtls.certificate.generate.failed");
		return 0;
	}
	_sentIos6V2Bootstrap = true;
	const std::string fingerprint = _ios6DtlsCertificate.fingerprint();
	const std::string initialJson = std::string("{\"@type\":\"InitialSetup\",\"ufrag\":\"") + ios6JsonEscape(candidates.iceParameters.ufrag)
		+ "\",\"pwd\":\"" + ios6JsonEscape(candidates.iceParameters.pwd)
		+ "\",\"renomination\":true,\"fingerprints\":[{\"hash\":\"sha-256\",\"setup\":\"actpass\",\"fingerprint\":\""
		+ fingerprint + "\"}]}";
	std::ostringstream candidatesJson;
	candidatesJson << "{\"@type\":\"Candidates\",\"candidates\":[";
	for (size_t i = 0; i < candidates.candidates.size(); i++) {
		if (i != 0) {
			candidatesJson << ",";
		}
		candidatesJson << "{\"sdpString\":\"" << ios6JsonEscape(candidates.candidates[i].ToString()) << "\"}";
	}
	candidatesJson << "]}";
	const std::string candidatesJsonString = candidatesJson.str();

	uint32_t counter = emitRawSignaling(std::vector<uint8_t>(initialJson.begin(), initialJson.end()), true);
	if (_encryptionKey.isOutgoing) {
		_negotiationStarted = true;
		if (const auto offer = _negotiator->takePendingOffer()) {
			signaling::Message message;
			message.data = *offer;
			const uint32_t offerCounter = emitRawSignaling(message.serialize(), false);
			if (offerCounter != 0) {
				counter = offerCounter;
			}
		}
	}
	const uint32_t candidatesCounter = emitRawSignaling(std::vector<uint8_t>(candidatesJsonString.begin(), candidatesJsonString.end()), false);
	if (candidatesCounter != 0) {
		counter = candidatesCounter;
	}
	syslog(LOG_NOTICE, "IOS6WEBRTC manager.bootstrap.sent candidates=%lu outgoing=%d counter=%u",
		(unsigned long)candidates.candidates.size(),
		_encryptionKey.isOutgoing ? 1 : 0,
		counter);
	return counter;
}

void Manager::sendPendingOffer() {
	if (const auto offer = _negotiator->takePendingOffer()) {
		signaling::Message message;
		message.data = *offer;
		emitRawSignaling(message.serialize(), true);
		syslog(LOG_NOTICE, "IOS6WEBRTC negotiation.offer.sent exchange=%u contents=%lu",
			(unsigned int)offer->exchangeId,
			(unsigned long)offer->contents.size());
	}
}

void Manager::handleRemoteNegotiation(const signaling::NegotiateChannelsMessage &message) {
	syslog(LOG_NOTICE, "IOS6WEBRTC negotiation.remote exchange=%u contents=%lu",
		(unsigned int)message.exchangeId,
		(unsigned long)message.contents.size());
	MediaNegotiator::RemoteResult result = _negotiator->handleRemoteNegotiation(message);
	_negotiationStarted = true;
	if (result.answer) {
		signaling::Message answer;
		answer.data = *result.answer;
		emitRawSignaling(answer.serialize(), true);
		syslog(LOG_NOTICE, "IOS6WEBRTC negotiation.answer.sent exchange=%u contents=%lu",
			(unsigned int)result.answer->exchangeId,
			(unsigned long)result.answer->contents.size());
	}
	sendPendingOffer();
	if (result.mediaChanged) {
		applyNegotiatedMedia();
	}
}

void Manager::applyNegotiatedMedia() {
	if (!_mediaManager) {
		return;
	}
	const NegotiatedMedia media = _negotiator->media();
	const uint32_t localAudioSsrc = _negotiator->localAudioSsrc();
	const uint32_t localVideoSsrc = _negotiator->localVideoSsrc();
	_mediaManager->perform([media, localAudioSsrc, localVideoSsrc](MediaManager *mediaManager) {
		mediaManager->setNegotiatedMedia(media, localAudioSsrc, localVideoSsrc);
	});
}

void Manager::handleRemoteMediaState(const signaling::MediaStateMessage &state) {
	VideoState videoState = VideoState::Inactive;
	switch (state.videoState) {
		case signaling::MediaStateMessage::VideoState::Active:
			videoState = VideoState::Active;
			break;
		case signaling::MediaStateMessage::VideoState::Suspended:
			videoState = VideoState::Paused;
			break;
		default:
			videoState = VideoState::Inactive;
			break;
	}
	if (state.screencastState == signaling::MediaStateMessage::VideoState::Active) {
		videoState = VideoState::Active;
	} else if (state.screencastState == signaling::MediaStateMessage::VideoState::Suspended && videoState != VideoState::Active) {
		videoState = VideoState::Paused;
	}
	syslog(LOG_NOTICE, "IOS6WEBRTC mediaState.remote muted=%d video=%d battery=%d",
		state.isMuted ? 1 : 0,
		(int)videoState,
		state.isBatteryLow ? 1 : 0);
	if (_remoteMediaStateUpdated) {
		_remoteMediaStateUpdated(state.isMuted ? AudioState::Muted : AudioState::Active, videoState);
	}
	if (_remoteBatteryLevelIsLowUpdated) {
		_remoteBatteryLevelIsLowUpdated(state.isBatteryLow);
	}
}

void Manager::sendMediaState() {
	if (!_mediaStateReady) {
		return;
	}
	signaling::Message message;
	message.data = _localMediaState;
	emitRawSignaling(message.serialize(), true);
}

void Manager::setAudioInputDevice(std::string id) {
	_mediaManager->perform([id](MediaManager *mediaManager) {
		mediaManager->setAudioInputDevice(id);
	});
}

void Manager::setAudioOutputDevice(std::string id) {
	_mediaManager->perform([id](MediaManager *mediaManager) {
		mediaManager->setAudioOutputDevice(id);
	});
}

void Manager::setInputVolume(float level) {
	_mediaManager->perform([level](MediaManager *mediaManager) {
		mediaManager->setInputVolume(level);
	});
}

void Manager::setOutputVolume(float level) {
	_mediaManager->perform([level](MediaManager *mediaManager) {
		mediaManager->setOutputVolume(level);
	});
}

void Manager::addExternalAudioSamples(std::vector<uint8_t> &&samples) {
	std::shared_ptr<std::vector<uint8_t>> samplesPtr(new std::vector<uint8_t>(std::move(samples)));
    _mediaManager->perform([samplesPtr](MediaManager *mediaManager) mutable {
        mediaManager->addExternalAudioSamples(std::move(*samplesPtr));
    });
}

}

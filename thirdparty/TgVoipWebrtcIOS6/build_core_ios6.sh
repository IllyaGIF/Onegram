#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
OUT="${1:-/private/tmp/tgcalls_ios6_core_build}"

mkdir -p "$OUT"

ARCH="${ARCH:-i386}"
SDK="${SDK:-iphonesimulator}"
if [ "$SDK" = "iphoneos" ]; then
  MIN_VERSION="-miphoneos-version-min=4.3"
else
  MIN_VERSION="-mios-simulator-version-min=6.0"
fi
CXXFLAGS="-arch $ARCH -std=c++11 -stdlib=libstdc++ $MIN_VERSION -O2 -DTGCALLS_IOS6_AUDIO_ONLY=1"
INCLUDES="-I$ROOT/openssl-ios5/include -I$ROOT/include -I$SRC -I$SRC/tgcalls -I$ROOT/../../Telegraph/thirdparty/opus/include/opus -I$ROOT/../../submodules/libtgvoip -include $ROOT/compat_force_include.h"

SOURCES="
tgcalls/third-party/json11.cpp
tgcalls/CryptoHelper.cpp
tgcalls/EncryptedConnection.cpp
tgcalls/FieldTrialsConfig.cpp
tgcalls/Instance.cpp
tgcalls/InstanceImpl.cpp
tgcalls/Ios6DtlsCertificate.cpp
tgcalls/Ios6DtlsTransport.cpp
tgcalls/LogSinkImpl.cpp
tgcalls/Manager.cpp
tgcalls/Message.cpp
tgcalls/NetworkManager.cpp
tgcalls/Ios6TurnClient.cpp
tgcalls/Ios6TurnSocket.cpp
tgcalls/Ios6RelayConnection.cpp
tgcalls/StaticThreads.cpp
tgcalls/v2/ExternalSignalingConnection.cpp
tgcalls/v2/Signaling.cpp
tgcalls/v2/MediaNegotiator.cpp
tgcalls/Ios6MediaManager.cpp
tgcalls/Ios6VideoCapabilities.cpp
tgcalls/MediaTransport.cpp
tgcalls/media/AudioChannel.cpp
tgcalls/media/BandwidthEstimator.cpp
tgcalls/media/H264.cpp
tgcalls/media/LibvpxVp8Decoder.cpp
tgcalls/media/LibvpxVp8Encoder.cpp
tgcalls/media/NackTracker.cpp
tgcalls/media/RtpVideoPacketizer.cpp
tgcalls/media/SystemInfo.cpp
tgcalls/media/VideoCodec.cpp
tgcalls/media/VideoDecoder.cpp
tgcalls/media/VideoEncoder.cpp
tgcalls/media/VideoFrame.cpp
tgcalls/media/VideoFrameAssembler.cpp
tgcalls/media/VideoFrameConverter.cpp
tgcalls/media/VideoProfile.cpp
tgcalls/media/VideoReceiveStream.cpp
tgcalls/media/VideoSendStream.cpp
tgcalls/media/VideoSource.cpp
tgcalls/media/VideoToolboxApi.cpp
tgcalls/media/VideoToolboxH264Decoder.cpp
tgcalls/media/VideoToolboxH264Encoder.cpp
tgcalls/media/WorkerThread.cpp
tgcalls/rtp/MediaPacket.cpp
tgcalls/rtp/Rtcp.cpp
tgcalls/rtp/RtpPacket.cpp
tgcalls/rtp/RtpStatistics.cpp
tgcalls/rtp/RtpTime.cpp
tgcalls/rtp/SrtpSession.cpp
tgcalls/rtp/TransportFeedbackGenerator.cpp
"

for source in $SOURCES; do
  object="$OUT/$(echo "$source" | tr '/' '_').o"
  echo "CXX $source"
  xcrun --sdk "$SDK" clang++ $CXXFLAGS $INCLUDES -c "$SRC/$source" -o "$object"
done

echo "AR libTgVoipWebrtcIOS6Core.a"
xcrun libtool -static \
  -o "$OUT/libTgVoipWebrtcIOS6Core.a" \
  "$OUT"/*.o
echo "$OUT/libTgVoipWebrtcIOS6Core.a"

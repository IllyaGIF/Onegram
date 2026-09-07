#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SIM_OUT="${1:-/private/tmp/tgcalls_ios6_core_i386}"
ARMV7_OUT="${2:-/private/tmp/tgcalls_ios6_core_armv7}"
ARM64_OUT="${3:-/private/tmp/tgcalls_ios6_core_arm64}"
FAT_OUT="${4:-$ROOT/lib/libTgVoipWebrtcIOS6Core.a}"

ARCH=i386 SDK=iphonesimulator "$ROOT/build_core_ios6.sh" "$SIM_OUT"
ARCH=armv7 SDK=iphoneos "$ROOT/build_core_ios6.sh" "$ARMV7_OUT"

if [ "${TGCALLS_INCLUDE_ARM64:-0}" = "1" ]; then
  ARCH=arm64 SDK=iphoneos "$ROOT/build_core_ios6.sh" "$ARM64_OUT"
  xcrun lipo -create \
    "$SIM_OUT/libTgVoipWebrtcIOS6Core.a" \
    "$ARMV7_OUT/libTgVoipWebrtcIOS6Core.a" \
    "$ARM64_OUT/libTgVoipWebrtcIOS6Core.a" \
    -output "$FAT_OUT"
else
  xcrun lipo -create \
    "$SIM_OUT/libTgVoipWebrtcIOS6Core.a" \
    "$ARMV7_OUT/libTgVoipWebrtcIOS6Core.a" \
    -output "$FAT_OUT"
fi

xcrun lipo -info "$FAT_OUT"

ln -sf "$FAT_OUT" "$ROOT/../../submodules/libtgvoip/external/libTgVoipWebrtcIOS6Core.a"

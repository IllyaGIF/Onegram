#!/bin/sh
set -e

CORE_DIR="${SRCROOT}/thirdparty/TgVoipWebrtcIOS6"
OUT="${BUILT_PRODUCTS_DIR}/libTgVoipWebrtcIOS6Core.a"
TMP_DIR="/private/tmp/tgcalls_ios6_core_build"
TMP_LIB="${TMP_DIR}/libTgVoipWebrtcIOS6Core.a"

# This legacy core is only required for device armv7 builds.
case "${PLATFORM_NAME}" in
    iphoneos|"") ;;
    *)
        echo "TgVoipWebrtcIOS6Core: skip for PLATFORM_NAME=${PLATFORM_NAME}"
        exit 0
        ;;
esac

STAMP="${OUT}.source-sha1"
SOURCE_SIGNATURE="$(
    {
        find "$CORE_DIR/src" "$CORE_DIR/include" "$CORE_DIR/openssl-ios5/include" -type f -print 2>/dev/null
        printf '%s\n' \
            "$CORE_DIR/build_core_ios6.sh" \
            "$CORE_DIR/compat_force_include.h" \
            "$CORE_DIR/audio_only_sources.txt"
    } | LC_ALL=C sort | while IFS= read -r path; do
        if [ -f "$path" ]; then
            /usr/bin/shasum "$path"
        fi
    done | /usr/bin/shasum | awk '{print $1}'
)"

CURRENT_SIGNATURE=""
if [ -f "$STAMP" ]; then
    CURRENT_SIGNATURE="$(cat "$STAMP" 2>/dev/null || true)"
fi

NEED_BUILD=0
if [ ! -f "$OUT" ] || [ "$SOURCE_SIGNATURE" != "$CURRENT_SIGNATURE" ]; then
    NEED_BUILD=1
fi

if [ "$NEED_BUILD" = "0" ]; then
    echo "TgVoipWebrtcIOS6Core: up to date -> $OUT"
    exit 0
fi

echo "TgVoipWebrtcIOS6Core: rebuilding..."
rm -rf "$TMP_DIR"
mkdir -p "${BUILT_PRODUCTS_DIR}"

cd "$CORE_DIR"
ARCH="armv7" SDK="iphoneos" sh ./build_core_ios6.sh

if [ ! -f "$TMP_LIB" ]; then
    echo "error: build_core_ios6.sh did not produce $TMP_LIB" >&2
    exit 1
fi

cp -f "$TMP_LIB" "$OUT"
ranlib "$OUT" 2>/dev/null || true
printf '%s\n' "$SOURCE_SIGNATURE" > "${STAMP}.tmp"
mv -f "${STAMP}.tmp" "$STAMP"

echo "TgVoipWebrtcIOS6Core: built -> $OUT"

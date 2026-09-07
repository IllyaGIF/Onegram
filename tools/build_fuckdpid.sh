#!/bin/sh
set -eu

CORE="${SRCROOT}/Modules/NekroEngine/NekroCore"
OUTDIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
OUT="${OUTDIR}/FuckDPID"
BRIDGE_OUT="${OUTDIR}/FuckDPIBridgeD"
SDK="${SDKROOT:-$(xcrun --sdk iphoneos --show-sdk-path)}"
CC_BIN="${CC:-$(xcrun --sdk iphoneos -find clang)}"

mkdir -p "$OUTDIR"

echo "[FuckDPI] Building armv7 helper with SDK: $SDK"

"$CC_BIN" \
    -arch armv7 \
    -isysroot "$SDK" \
    -miphoneos-version-min=5.0 \
    -fno-objc-arc \
    -std=gnu99 \
    -I"$CORE" \
    -I"$CORE/tun" \
    -I"$CORE/crypto" \
    -I"$CORE/wg" \
    -I"$CORE/curl-lib/cURL/include" \
    "$CORE/nekrowarp.m" \
    "$CORE/tun/nw_tun.c" \
    "$CORE/tun/nw_route.c" \
    "$CORE/tun/nw_scope.c" \
    "$CORE/crypto/blake2s.c" \
    "$CORE/crypto/chachapoly.c" \
    "$CORE/crypto/x25519.c" \
    "$CORE/crypto/kdf.c" \
    "$CORE/crypto/selftest.c" \
    "$CORE/wg/wg.c" \
    "$CORE/wg/awg.c" \
    -framework Foundation \
    -framework Security \
    -framework SystemConfiguration \
    -framework CoreFoundation \
    "$CORE/curl-lib/cURL/libcurl.a" \
    "$CORE/curl-lib/cURL/libssl.a" \
    "$CORE/curl-lib/cURL/libcrypto.a" \
    -lz \
    -o "$OUT"

chmod 0755 "$OUT"

if command -v ldid >/dev/null 2>&1; then
    ldid -S"$CORE/entitlements.plist" "$OUT"
elif [ -x /usr/bin/codesign ]; then
    /usr/bin/codesign --force --sign - --entitlements "$CORE/entitlements.plist" "$OUT" || true
fi

echo "[FuckDPI] Bundled helper: $OUT"

echo "[FuckDPI] Building armv7 root bridge"

"$CC_BIN" \
    -arch armv7 \
    -isysroot "$SDK" \
    -miphoneos-version-min=5.0 \
    -std=gnu99 \
    "$CORE/fuckdpi_bridge.c" \
    -o "$BRIDGE_OUT"

chmod 0755 "$BRIDGE_OUT"

if command -v ldid >/dev/null 2>&1; then
    ldid -S "$BRIDGE_OUT"
elif [ -x /usr/bin/codesign ]; then
    /usr/bin/codesign --force --sign - "$BRIDGE_OUT" || true
fi

echo "[FuckDPI] Bundled bridge: $BRIDGE_OUT"

cp "${SRCROOT}/tools/install_fuckdpi_helper_on_device.sh" "${OUTDIR}/InstallFuckDPI.sh"
chmod 0755 "${OUTDIR}/InstallFuckDPI.sh"
echo "[FuckDPI] Bundled installer: ${OUTDIR}/InstallFuckDPI.sh"

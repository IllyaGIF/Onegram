# Builds FuckDPID, the privileged helper FuckDPI spawns. Everything it needs is
# in this directory, so a fresh clone builds it with nothing but Theos:
#
#     cd Modules/NekroEngine/NekroCore && THEOS=~/theos make
#     cp .theos/obj/debug/FuckDPID ../Bin/FuckDPID
#
# ../Bin/FuckDPID is what the Xcode project bundles. The helper is the same
# program as NekroWARP — a general WARP/AmneziaWG tunnel that knows nothing about
# Telegram; which networks to route is passed in at runtime as routes=CIDR,...
#
# It has to be setuid root to open a utun, which is why the app cannot grant it:
# the .deb's postinst installs it to /usr/libexec/fuckdpid with mode 4755.

TARGET = iphone:clang:latest:5.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

TOOL_NAME = FuckDPID

FuckDPID_FILES = nekrowarp.m \
                 tun/nw_tun.c \
                 tun/nw_route.c \
                 tun/nw_scope.c \
                 crypto/blake2s.c \
                 crypto/chachapoly.c \
                 crypto/x25519.c \
                 crypto/kdf.c \
                 crypto/selftest.c \
                 wg/wg.c \
                 wg/awg.c

FuckDPID_CFLAGS = -I. -Itun -Icrypto -Iwg -Icurl-lib/cURL/include -Wall
FuckDPID_LDFLAGS = -framework Foundation -framework Security \
                   -framework SystemConfiguration -framework CoreFoundation \
                   curl-lib/cURL/libcurl.a curl-lib/cURL/libssl.a \
                   curl-lib/cURL/libcrypto.a -lz
FuckDPID_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS)/makefiles/tool.mk

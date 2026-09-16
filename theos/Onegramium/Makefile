export THEOS ?= /Users/anazerka/theos

ARCHS = armv7
TARGET = iphone:clang:latest:6.0

APPLICATION_NAME = Onegramium
Onegramium_BUNDLE_NAME = Twelve
Onegramium_INSTALL_PATH = /Applications
Onegramium_FILES = $(ONEGRAMIUM_SOURCES)
Onegramium_RESOURCE_DIRS = ../../Telegraph/Resources ../../Telegraph/en.lproj ../../Telegraph/ru.lproj ../../Telegraph/de.lproj ../../Telegraph/es.lproj ../../Telegraph/it.lproj ../../Telegraph/ko.lproj ../../Telegraph/nl.lproj ../../Telegraph/pt.lproj ../../Telegraph/ar.lproj
Onegramium_BUNDLE_RESOURCES = ../../Telegraph/Telegraph-Info.plist
Onegramium_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-receiver-is-weak -Wno-conversion -DSQLITE_TEMP_STORE=2 -DSQLITE_HAS_CODEC=1 -DSQLCIPHER_CRYPTO_CC=1 -DSQLITE_ENABLE_FTS3 -DTGVOIP_USE_CUSTOM_CRYPTO -DTGVOIP_USE_AUDIO_SESSION -DTG_PUBLIC_BUILD=1
Onegramium_CCFLAGS = -std=gnu++0x
Onegramium_OBJCFLAGS = -include ../../submodules/LegacyComponents/LegacyComponents/LegacyComponentsIos6Compat.h
Onegramium_CFLAGS += -I../../submodules/MtProtoKit -I../../submodules/LegacyComponents -I../../Telegraph/thirdparty/ogg -I../../thirdparty/libphonenumber.framework/Headers -I../../legacy/TelegraphKit -I../../legacy/TL -I../../legacy/TL/TL -I../../thirdparty/pop -I../../thirdparty/libbpg -I../../thirdparty/SSignalKit -I../../submodules/libtgvoip -I../../thirdparty/Lottie/lottie-ios/Classes/PublicHeaders -I../../thirdparty/Stripe -I../../Telegraph/thirdparty/opus/include -I../../thirdparty/TgVoipWebrtcIOS6/include
Onegramium_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreFoundation CFNetwork SystemConfiguration Security MobileCoreServices AssetsLibrary AVFoundation AudioToolbox CoreMedia CoreVideo ImageIO MapKit AddressBook EventKit MessageUI MediaPlayer OpenGLES GLKit CoreMotion QuickLook Accelerate PassKit VideoToolbox
Onegramium_LIBRARIES = c++ z sqlite3 icucore crypto TgVoipWebrtcIOS6Core
Onegramium_LDFLAGS = -ObjC -L../../thirdparty/TgVoipWebrtcIOS6/lib -L../../submodules/MtProtoKit/openssl/iOS

-include Sources.mk

ifeq ($(strip $(ONEGRAMIUM_SOURCES)),)
$(error Run `make manifest` once to export the Telegraph source list.)
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

.PHONY: manifest verify-layout

manifest:
	@ruby generate_manifest.rb

verify-layout:
	@test -f ../../config.h || (echo "Missing ../../config.h; copy config.h.example first."; exit 1)
	@test -f ../../thirdparty/TgVoipWebrtcIOS6/lib/libTgVoipWebrtcIOS6Core.a || (echo "Missing rebuilt TgVoipWebrtcIOS6 armv7 archive."; exit 1)

before-all:: verify-layout

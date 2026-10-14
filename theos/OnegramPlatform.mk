libOnegramPlatform_FILES := $(shell find ../OnegramPlatform -type f -name '*.m' -print | sort)
libOnegramPlatform_FILES += ../thirdparty/quirc/quirc.c ../thirdparty/quirc/decode.c ../thirdparty/quirc/identify.c ../thirdparty/quirc/version_db.c
libOnegramPlatform_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramPlatform
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramPlatform_CFLAGS += -DONEGRAM_ARMV6=1 -DONEGRAM_IOS3_APPLICATION_BUILD=1 -I$(ONEGRAM_ROOT)/theos/compat/ios3 -I$(ONEGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
libOnegramPlatform_OPTFLAG = -O3
libOnegramPlatform_LDFLAGS =
libOnegramPlatform_LINK_INPUTS =

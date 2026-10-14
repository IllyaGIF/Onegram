libOnegramUIBridge_FILES := $(shell find ../OnegramUIBridge -type f -name '*.m' -print | sort)
libOnegramUIBridge_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramUIBridge -I$(ONEGRAM_ROOT)/OnegramUI -I$(ONEGRAM_ROOT)/OnegramPlatform
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramUIBridge_CFLAGS += -DONEGRAM_ARMV6=1 -DONEGRAM_IOS3_APPLICATION_BUILD=1 -I$(ONEGRAM_ROOT)/theos/compat/ios3 -I$(ONEGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
libOnegramUIBridge_OPTFLAG = -O3
libOnegramUIBridge_LDFLAGS =
libOnegramUIBridge_LINK_INPUTS =

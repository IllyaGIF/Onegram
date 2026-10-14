libOnegramUI_FILES := $(shell find ../OnegramUI -type f -name '*.m' -print | sort)
libOnegramUI_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramUI -I$(ONEGRAM_ROOT)/OnegramPlatform
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramUI_CFLAGS += -DONEGRAM_ARMV6=1 -DONEGRAM_IOS3_APPLICATION_BUILD=1 -I$(ONEGRAM_ROOT)/theos/compat/ios3 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/openssl-OpenSSL_1_0_2h/include -I$(ONEGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
libOnegramUI_OPTFLAG = -O3
libOnegramUI_LDFLAGS =
libOnegramUI_LINK_INPUTS =

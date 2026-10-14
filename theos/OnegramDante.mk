libOnegramDante_FILES := $(shell find ../OnegramDante -type f \( -name '*.m' -o -name '*.c' \) -print | sort)
libOnegramDante_CFLAGS = -fno-objc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramDante
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramDante_CFLAGS += -DONEGRAM_ARMV6=1 -DONEGRAM_IOS3_APPLICATION_BUILD=1 -I$(ONEGRAM_ROOT)/theos/compat/ios3 -I$(ONEGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
ifeq ($(ONEGRAM_ARCH),armv7)
libOnegramDante_CFLAGS += -I$(ONEGRAM_ROOT)/thirdparty/TgVoipWebrtcIOS6/openssl-ios5/include
else
libOnegramDante_CFLAGS += -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/openssl-OpenSSL_1_0_2h/include
endif
libOnegramDante_OPTFLAG = -O3
libOnegramDante_LDFLAGS =
libOnegramDante_LINK_INPUTS =

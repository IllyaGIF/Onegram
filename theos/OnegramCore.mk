ONEGRAM_MLKEM_DIR := $(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/mlkem-native
ONEGRAM_MLKEM_CHECK := $(shell python3 scripts/prepare_mlkem.py --output "$(ONEGRAM_MLKEM_DIR)" || echo ONEGRAM_MLKEM_FAILED)
ifneq ($(findstring ONEGRAM_MLKEM_FAILED,$(ONEGRAM_MLKEM_CHECK)),)
$(error Unable to prepare ML-KEM dependency)
endif
libOnegramCore_FILES := $(shell find ../OnegramCore -type f \( -name '*.m' -o -name '*.c' \) -print | sort)
libOnegramCore_CFLAGS = -fno-objc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramCore -I$(ONEGRAM_MLKEM_DIR)
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramCore_CFLAGS += -DONEGRAM_ARMV6=1 -DONEGRAM_IOS3_APPLICATION_BUILD=1 -I$(ONEGRAM_ROOT)/theos/compat/ios3 -I$(ONEGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
ifeq ($(ONEGRAM_ARCH),armv7)
libOnegramCore_CFLAGS += -I$(ONEGRAM_ROOT)/thirdparty/TgVoipWebrtcIOS6/openssl-ios5/include
else
libOnegramCore_CFLAGS += -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/openssl-OpenSSL_1_0_2h/include
endif
libOnegramCore_OPTFLAG = -O3
libOnegramCore_LDFLAGS =
libOnegramCore_LINK_INPUTS =

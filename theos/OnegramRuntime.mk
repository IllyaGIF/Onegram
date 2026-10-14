libOnegramRuntime_FILES = ../OnegramRuntime/OGRuntime.m ../OnegramRuntime/OGDatabaseRuntime.m
libOnegramRuntime_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramRuntime
ifeq ($(ONEGRAM_ARCH),armv6)
libOnegramRuntime_CFLAGS += -DONEGRAM_ARMV6=1 -I$(ONEGRAM_ROOT)/theos/generated/armv6/dependency-sources/libdispatch-libdispatch-187.10 -I$(ONEGRAM_ROOT)/theos/generated/armv6/dependency-sources/libclosure-libclosure-38 -include $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramIOS3Compatibility.h
endif
ifeq ($(ONEGRAM_ARCH),arm64)
libOnegramRuntime_CFLAGS += -DOS_OBJECT_USE_OBJC=0
endif
libOnegramRuntime_OPTFLAG = -O3
libOnegramRuntime_LDFLAGS =
libOnegramRuntime_LINK_INPUTS =

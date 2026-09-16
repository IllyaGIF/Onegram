libOnegramRuntime_FILES = ../OnegramRuntime/OGRuntime.m
libOnegramRuntime_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(ONEGRAM_ROOT)/OnegramRuntime
ifeq ($(ONEGRAM_ARCH),arm64)
libOnegramRuntime_CFLAGS += -DOS_OBJECT_USE_OBJC=0
endif
libOnegramRuntime_OPTFLAG = -O3
libOnegramRuntime_LDFLAGS =
libOnegramRuntime_LINK_INPUTS =

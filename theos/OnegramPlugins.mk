libOnegramPlugins_FILES := $(shell find ../OnegramPlugins -maxdepth 1 -type f \( -name '*.m' -o -name '*.c' \) -print | sort)
libOnegramPlugins_CFLAGS = -Xclang -fobjc-runtime-has-weak -fobjc-arc -fblocks -std=gnu11 -I$(ONEGRAM_ROOT)/OnegramPlugins -I$(ONEGRAM_ROOT)/submodules/LegacyComponents -I$(ONEGRAM_ROOT)/theos/$(GENERATED_DIR)/python-include
libOnegramPlugins_OPTFLAG = -O2
libOnegramPlugins_LDFLAGS =
libOnegramPlugins_LINK_INPUTS =

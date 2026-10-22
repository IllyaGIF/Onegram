SHELL := /bin/bash
.DEFAULT_GOAL := all
ONEGRAM_ROOT := $(abspath ..)
THEOS ?= $(HOME)/theos
ONEGRAM_ARCH ?= armv7
ifeq ($(ONEGRAM_ARCH),arm64)
ONEGRAM_SDK_VERSION := 11.2
ONEGRAM_DEPLOYMENT := 7.0
GENERATED_DIR := generated/arm64
APPLICATION_OUTPUT := build/arm64
THEOS_OBJ_DIR_NAME := obj/arm64-build
else ifeq ($(ONEGRAM_ARCH),armv6)
ONEGRAM_SDK_VERSION := 3.1.3
ONEGRAM_DEPLOYMENT := 3.1.3
THEOS_DEPLOYMENT := 3.1
TARGET_OS_DEPLOYMENT_VERSION := $(ONEGRAM_DEPLOYMENT)
GENERATED_DIR := generated/armv6
APPLICATION_OUTPUT := build/armv6
THEOS_OBJ_DIR_NAME := obj/armv6-build
else
ifneq ($(ONEGRAM_ARCH),armv7)
$(error Unsupported ONEGRAM_ARCH $(ONEGRAM_ARCH); expected armv6, armv7, or arm64)
endif
ONEGRAM_SDK_VERSION := 6.1
ONEGRAM_DEPLOYMENT := 4.3
GENERATED_DIR := generated
APPLICATION_OUTPUT := build
THEOS_OBJ_DIR_NAME := obj/armv7-build
endif
ifeq ($(ONEGRAM_DIAGNOSTICS),1)
THEOS_OBJ_DIR_NAME := $(THEOS_OBJ_DIR_NAME)-diag
endif
export ONEGRAM_ARCH ONEGRAM_SDK_VERSION ONEGRAM_DEPLOYMENT ONEGRAM_DIAGNOSTICS
export ONEGRAM_GENERATED_DIR := $(GENERATED_DIR)
THEOS_DEPLOYMENT ?= $(ONEGRAM_DEPLOYMENT)
TARGET := iphone:clang:$(ONEGRAM_SDK_VERSION):$(THEOS_DEPLOYMENT)
ARCHS := $(ONEGRAM_ARCH)
DEBUG := 0
FINALPACKAGE := 1
GO_EASY_ON_ME := 1
USE_DEPS := 1
XCODE_CONFIGURATION ?= Release Hockeyapp
XCODE_TARGET ?= Telegram
HOST_OS := $(shell uname -s)
ifeq ($(HOST_OS),Darwin)
XCODE_TOOLCHAIN_DIR ?= $(THEOS)/toolchain/macos/iphone
LEGACY_CLANG_DIR ?= $(XCODE_TOOLCHAIN_DIR)
THEOS_PLATFORM_SDK_ROOT := $(XCODE_TOOLCHAIN_DIR)
PREFIX := $(XCODE_TOOLCHAIN_DIR)/bin/
TARGET_LIBTOOL := $(XCODE_TOOLCHAIN_DIR)/bin/libtool
TARGET_LIPO := $(XCODE_TOOLCHAIN_DIR)/bin/lipo
TARGET_STRIP := $(XCODE_TOOLCHAIN_DIR)/bin/strip
TARGET_CODESIGN := $(XCODE_TOOLCHAIN_DIR)/bin/ldid
TARGET_DSYMUTIL := $(XCODE_TOOLCHAIN_DIR)/bin/dsymutil
else
XCODE_TOOLCHAIN_DIR ?= $(THEOS)/toolchain/linux/iphone
LEGACY_CLANG_DIR ?= $(ONEGRAM_ROOT)/theos/generated/toolchains/clang+llvm-3.2-x86_64-linux-ubuntu-12.04
endif
XCODE_DEVELOPER_FRAMEWORKS_DIR ?= $(ISYSROOT)/Developer/Library/Frameworks
XCODE_USER_LIBRARY_DIR ?= $(HOME)/Library
ifeq ($(ONEGRAM_ARCH),arm64)
REAL_TARGET_CC := $(XCODE_TOOLCHAIN_DIR)/bin/clang
REAL_TARGET_CXX := $(XCODE_TOOLCHAIN_DIR)/bin/clang++
else
REAL_TARGET_CC := $(LEGACY_CLANG_DIR)/bin/clang
REAL_TARGET_CXX := $(LEGACY_CLANG_DIR)/bin/clang++
endif
TARGET_CC := ccache $(REAL_TARGET_CC)
TARGET_CXX := ccache $(REAL_TARGET_CXX)
ifeq ($(ONEGRAM_ARCH),armv6)
ARMV6_TARGET_TRIPLE := armv6-apple-ios$(ONEGRAM_DEPLOYMENT)
ARMV6_PLATFORM_FLAGS := -target $(ARMV6_TARGET_TRIPLE) -miphoneos-version-min=$(ONEGRAM_DEPLOYMENT)
export IPHONEOS_DEPLOYMENT_TARGET := $(ONEGRAM_DEPLOYMENT)
TARGET_CC += $(ARMV6_PLATFORM_FLAGS)
TARGET_CXX += $(ARMV6_PLATFORM_FLAGS)
endif
ifeq ($(HOST_OS),Darwin)
TARGET_CC += -target $(ONEGRAM_ARCH)-apple-ios$(ONEGRAM_DEPLOYMENT)
TARGET_CXX += -target $(ONEGRAM_ARCH)-apple-ios$(ONEGRAM_DEPLOYMENT)
endif
CORE_CXX := ccache $(REAL_TARGET_CXX)
CORE_JOBS ?= 8
ARMV6_JOBS ?= $(CORE_JOBS)
XCODE_ARCLITE ?= $(ONEGRAM_ROOT)/theos/lib/libarclite_iphoneos.a
XCODE_COMPILER_RT ?= $(ONEGRAM_ROOT)/theos/lib/libclang_rt.ios.a
ifeq ($(ONEGRAM_ARCH),armv6)
XCODE_ARCLITE := $(ONEGRAM_ROOT)/theos/generated/armv6/products/libarclite_iphoneos.a
XCODE_COMPILER_RT := $(ONEGRAM_ROOT)/theos/generated/armv6/products/libclang_rt.ios.a
endif
GRAPH_INPUTS := $(wildcard ../*.xcconfig ../Telegraph.xcodeproj/project.pbxproj ../submodules/*/*.xcodeproj/project.pbxproj ../thirdparty/*/*.xcodeproj/project.pbxproj)
ONEGRAM_GENERATION_CONTEXT := $(ONEGRAM_ROOT)|$(abspath $(GENERATED_DIR))|$(ONEGRAM_ARCH)|$(ONEGRAM_SDK_VERSION)|$(XCODE_CONFIGURATION)|$(THEOS)
ifneq ($(_ONEGRAM_VALIDATED_CONTEXT),$(ONEGRAM_GENERATION_CONTEXT))
GENERATION_CONTEXT_CHECK := $(shell python3 scripts/generate.py --ensure-context --configuration "$(XCODE_CONFIGURATION)" || echo ONEGRAM_GENERATION_FAILED)
ifneq ($(findstring ONEGRAM_GENERATION_FAILED,$(GENERATION_CONTEXT_CHECK)),)
$(error Unable to prepare generated build files)
endif
ifneq ($(HOST_OS),Darwin)
ifneq ($(ONEGRAM_ARCH),arm64)
LEGACY_DEPENDENCY_CHECK := $(shell python3 scripts/fix_legacy_dependencies.py --compiler "$(REAL_TARGET_CC)" --objects "$(abspath .theos/$(THEOS_OBJ_DIR_NAME))" || echo ONEGRAM_DEPENDENCIES_FAILED)
ifneq ($(findstring ONEGRAM_DEPENDENCIES_FAILED,$(LEGACY_DEPENDENCY_CHECK)),)
$(error Unable to prepare legacy compiler dependencies)
endif
endif
endif
export _ONEGRAM_VALIDATED_CONTEXT := $(ONEGRAM_GENERATION_CONTEXT)
endif
$(GENERATED_DIR)/dependencies.mk: Makefile $(GRAPH_INPUTS) scripts/generate.py scripts/xcode_graph.py
	python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
	@touch $@
$(GENERATED_DIR)/%.mk: $(GENERATED_DIR)/dependencies.mk
	@test -f "$@" || python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
include $(GENERATED_DIR)/dependencies.mk
XCODE_LIBRARIES += libOnegramRuntime libOnegramPlatform libOnegramUI libOnegramUIBridge libOnegramDante
ifeq ($(XCODE_TARGET),libOnegramRuntime)
include OnegramRuntime.mk
else ifeq ($(XCODE_TARGET),libOnegramDante)
include OnegramDante.mk
else ifeq ($(XCODE_TARGET),libOnegramPlatform)
include OnegramPlatform.mk
else ifeq ($(XCODE_TARGET),libOnegramUI)
include OnegramUI.mk
else ifeq ($(XCODE_TARGET),libOnegramUIBridge)
include OnegramUIBridge.mk
else
include $(GENERATED_DIR)/$(XCODE_TARGET).mk
endif
ifeq ($(XCODE_TARGET),libLegacyComponents)
libLegacyComponents_CFLAGS += -I$(ONEGRAM_ROOT)/OnegramPlatform
endif
ifeq ($(XCODE_TARGET),Telegram)
ifeq ($(ONEGRAM_ARCH),armv6)
Telegram_LDFLAGS := $(subst -weak_framework PassKit,,$(Telegram_LDFLAGS))
Telegram_LDFLAGS := $(subst -framework WebP,$(GENERATED_DIR)/products/libWebP.a,$(Telegram_LDFLAGS))
Telegram_LINK_INPUTS := $(filter-out $(ONEGRAM_ROOT)/thirdparty/WebP.framework/WebP,$(Telegram_LINK_INPUTS))
Telegram_LINK_INPUTS += $(GENERATED_DIR)/products/libWebP.a
endif
Telegram_CFLAGS += -I$(ONEGRAM_ROOT)/OnegramRuntime -I$(ONEGRAM_ROOT)/OnegramPlatform -I$(ONEGRAM_ROOT)/OnegramUI -I$(ONEGRAM_ROOT)/OnegramUIBridge
Telegram_LDFLAGS += $(GENERATED_DIR)/products/libOnegramUIBridge.a $(GENERATED_DIR)/products/libOnegramUI.a $(GENERATED_DIR)/products/libOnegramPlatform.a $(GENERATED_DIR)/products/libOnegramRuntime.a $(GENERATED_DIR)/products/libOnegramDante.a
Telegram_LINK_INPUTS += $(GENERATED_DIR)/products/libOnegramUIBridge.a $(GENERATED_DIR)/products/libOnegramUI.a $(GENERATED_DIR)/products/libOnegramPlatform.a $(GENERATED_DIR)/products/libOnegramRuntime.a $(GENERATED_DIR)/products/libOnegramDante.a
ifneq ($(ONEGRAM_ARCH),arm64)
Telegram_LDFLAGS += $(XCODE_COMPILER_RT)
Telegram_LINK_INPUTS += $(XCODE_COMPILER_RT)
endif
ifeq ($(ONEGRAM_ARCH),armv6)
ARMV6_CRT := $(GENERATED_DIR)/products/crt1.3.1-armv6.o
Telegram_LDFLAGS := -L$(GENERATED_DIR)/products $(Telegram_LDFLAGS)
Telegram_LDFLAGS += -Wl,-alias_list,$(ONEGRAM_ROOT)/theos/compat/ios3/OnegramBlocksRuntimeAliases.txt
Telegram_LDFLAGS += -Wl,-unexported_symbols_list,$(ONEGRAM_ROOT)/theos/compat/ios3/OnegramRuntimePrivateSymbols.txt
Telegram_LINK_INPUTS += $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramBlocksRuntimeAliases.txt $(ONEGRAM_ROOT)/theos/compat/ios3/OnegramRuntimePrivateSymbols.txt
Telegram_LDFLAGS += -nostartfiles $(ARMV6_CRT) $(GENERATED_DIR)/products/libdispatch.a
Telegram_LINK_INPUTS += $(ARMV6_CRT) $(GENERATED_DIR)/products/libdispatch.a
endif
endif
OPTFLAG = $($(XCODE_TARGET)_OPTFLAG)
ifeq ($(XCODE_TARGET),Telegram)
APPLICATION_NAME := Telegram
else
LIBRARY_NAME := $(XCODE_TARGET)
THEOS_LINKAGE_TYPE := static
_THEOS_LIBRARY_TYPE := static
STRIP := 0
$(XCODE_TARGET)_LINKAGE_TYPE := static
$(XCODE_TARGET)_INSTALL := 0
endif
include $(THEOS)/makefiles/common.mk
ifeq ($(ONEGRAM_ARCH),arm64)
MODULESFLAGS := $(filter-out -fbuild-session-file=% -fbuild-session-timestamp=% -fmodules-validate-once-per-build-session,$(MODULESFLAGS))
export CCACHE_DIRECT := true
export CCACHE_DEPEND := true
export CCACHE_SLOPPINESS := modules
ONEGRAM_CACHE_HEADER_MAPS := $(patsubst -I%,%,$(filter -I%.hmap,$($(XCODE_TARGET)_CFLAGS)))
export CCACHE_EXTRAFILES := $(subst $(space),:,$(strip $(ONEGRAM_CACHE_HEADER_MAPS)))
endif
ifeq ($(HOST_OS),Darwin)
$(XCODE_TARGET)_CFLAGS += -I$(ONEGRAM_ROOT)/theos/compat/libstdcxx
$(XCODE_TARGET)_CFLAGS += -Wno-error=parentheses -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types
endif
ifeq ($(ONEGRAM_ARCH),arm64)
$(XCODE_TARGET)_CFLAGS += -fmodules-cache-path=$(abspath .theos/$(THEOS_OBJ_DIR_NAME)/modules)
endif
ifeq ($(ONEGRAM_DIAGNOSTICS),1)
$(XCODE_TARGET)_CFLAGS += -DONEGRAM_DIAGNOSTICS=1
else
$(XCODE_TARGET)_CFLAGS += -include $(ONEGRAM_ROOT)/OnegramRuntime/OGReleaseLogging.h
endif
_THEOS_INTERNAL_IFLAGS_C =
_THEOS_INTERNAL_CFLAGS = $(OPTFLAG) $(DEBUGFLAG)
ifeq ($(XCODE_TARGET),Telegram)
Telegram_RESOURCE_DIRS := $(ONEGRAM_ROOT)/ios6style
Telegram_RESOURCE_FILES += $(ONEGRAM_ROOT)/thirdparty/quirc/LICENSE
Telegram_CODESIGN_FLAGS = -S$(ONEGRAM_ROOT)/theos/Telegram.entitlements
include $(THEOS_MAKE_PATH)/rules.mk
include response-link.mk
include $(THEOS_MAKE_PATH)/application.mk
before-all::
	@if test "$(ONEGRAM_ARCH)" = arm64; then mkdir -p "$(abspath .theos/$(THEOS_OBJ_DIR_NAME)/modules)"; fi
	@python3 scripts/audit_xcode_target.py
	@python3 scripts/audit_onegram_ui.py
	@if ! test -x "$(REAL_TARGET_CC)" || ! test -x "$(REAL_TARGET_CXX)"; then ONEGRAM_GENERATED_DIR=generated python3 scripts/setup_legacy_clang.py; fi
	@if test "$(ONEGRAM_ARCH)" = armv6; then python3 scripts/build_armv6_dependencies.py --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)" --cc "$(REAL_TARGET_CC)" --jobs "$(ARMV6_JOBS)"; fi
	@if test "$(ONEGRAM_ARCH)" = arm64; then python3 scripts/build_arm64_dependencies.py --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)"; fi
	@if test "$(ONEGRAM_ARCH)" = armv7; then python3 scripts/build_armv7_dependencies.py --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)" --deployment "$(ONEGRAM_DEPLOYMENT)"; fi
	@python3 scripts/preflight.py --toolchain "$(XCODE_TOOLCHAIN_DIR)" --sdk "$(ISYSROOT)" --sdk-version "$(ONEGRAM_SDK_VERSION)" --arclite "$(XCODE_ARCLITE)" --compiler-rt "$(XCODE_COMPILER_RT)"
	@for target in $(XCODE_LIBRARIES); do $(MAKE) --no-print-directory XCODE_TARGET=$$target all || exit $$?; done
	@python3 scripts/build_core.py --cc "$(CORE_CXX)" --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)" --jobs "$(CORE_JOBS)"
after-all::
	@python3 scripts/package_app.py --app "$(THEOS_OBJ_DIR)/Telegram.app" --ldid "$(TARGET_CODESIGN)" $(if $(filter 0,$(ONEGRAM_PACKAGE_IPA)),--stage-only)
ifneq ($(ONEGRAM_PACKAGE_IPA),0)
	@python3 scripts/verify_binary.py $(APPLICATION_OUTPUT)/Payload/Telegram.app/Telegram --tools "$(XCODE_TOOLCHAIN_DIR)/bin"
endif
else
include $(THEOS_MAKE_PATH)/library.mk
after-all::
	@mkdir -p $(GENERATED_DIR)/products
	@cmp -s "$(THEOS_OBJ_DIR)/$(XCODE_TARGET).a" "$(GENERATED_DIR)/products/$(XCODE_TARGET).a" || cp "$(THEOS_OBJ_DIR)/$(XCODE_TARGET).a" "$(GENERATED_DIR)/products/$(XCODE_TARGET).a"
	@case "$(XCODE_TARGET)" in libOnegram*) ;; *) python3 scripts/export_headers.py "$(XCODE_TARGET)" ;; esac
endif
ifeq ($(HOST_OS),Darwin)
TARGET_LD = $(XCODE_TOOLCHAIN_DIR)/bin/clang++ -target $(ONEGRAM_ARCH)-apple-ios$(ONEGRAM_DEPLOYMENT)
else
TARGET_LD = $(THEOS)/toolchain/linux/iphone/bin/clang++
ifeq ($(ONEGRAM_ARCH),armv6)
TARGET_LD += $(ARMV6_PLATFORM_FLAGS)
endif
endif
_THEOS_INTERNAL_LDFLAGS := $(filter-out -lroot%,$(_THEOS_INTERNAL_LDFLAGS))
ifeq ($(ONEGRAM_ARCH),arm64)
ALL_DEPFLAGS = -MT $@ -MD -MP -MF "$(THEOS_OBJ_DIR)/$<.$(_THEOS_OBJ_FILE_TAG).Td"
endif
.PHONY: generate audit ipa preflight
generate:
	python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
audit:
	python3 scripts/audit_xcode_target.py
preflight:
	python3 scripts/preflight.py --toolchain "$(XCODE_TOOLCHAIN_DIR)" --sdk "$(ISYSROOT)" --sdk-version "$(ONEGRAM_SDK_VERSION)" --arclite "$(XCODE_ARCLITE)" --compiler-rt "$(XCODE_COMPILER_RT)"
ipa: all
.PHONY: universal
universal:
	$(MAKE) ONEGRAM_ARCH=armv7 ONEGRAM_PACKAGE_IPA=0 all
	$(MAKE) ONEGRAM_ARCH=arm64 ONEGRAM_PACKAGE_IPA=0 all
	python3 scripts/package_universal.py --ldid "$(TARGET_CODESIGN)" --toolchain "$(XCODE_TOOLCHAIN_DIR)"
.PHONY: universal3
universal3:
	$(MAKE) ONEGRAM_ARCH=armv6 ONEGRAM_PACKAGE_IPA=0 all
	$(MAKE) ONEGRAM_ARCH=armv7 ONEGRAM_PACKAGE_IPA=0 all
	$(MAKE) ONEGRAM_ARCH=arm64 ONEGRAM_PACKAGE_IPA=0 all
	python3 scripts/package_universal.py --ldid "$(TARGET_CODESIGN)" --toolchain "$(XCODE_TOOLCHAIN_DIR)" --architectures armv6 armv7 arm64
.PHONY: armv6
armv6:
	$(MAKE) ONEGRAM_ARCH=armv6 all
after-clean::
	rm -rf $(GENERATED_DIR)/products $(GENERATED_DIR)/core $(APPLICATION_OUTPUT)/Payload $(APPLICATION_OUTPUT)/Onegram.ipa build/universal

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
else
ONEGRAM_SDK_VERSION := 6.1
ONEGRAM_DEPLOYMENT := 4.3
GENERATED_DIR := generated
APPLICATION_OUTPUT := build
THEOS_OBJ_DIR_NAME := obj/armv7-build
endif
export ONEGRAM_ARCH ONEGRAM_SDK_VERSION ONEGRAM_DEPLOYMENT
export ONEGRAM_GENERATED_DIR := $(GENERATED_DIR)
TARGET := iphone:clang:$(ONEGRAM_SDK_VERSION):$(ONEGRAM_DEPLOYMENT)
ARCHS := $(ONEGRAM_ARCH)
DEBUG := 0
FINALPACKAGE := 1
GO_EASY_ON_ME := 1
USE_DEPS := 1
XCODE_CONFIGURATION ?= Release Hockeyapp
XCODE_TARGET ?= Telegram
HOST_OS := $(shell uname -s)
ifeq ($(HOST_OS),Darwin)
XCODE_TOOLCHAIN_DIR ?= $(shell dirname $$(dirname "$$(xcrun --find clang)"))
LEGACY_CLANG_DIR ?= $(XCODE_TOOLCHAIN_DIR)
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
CORE_CXX := ccache $(REAL_TARGET_CXX)
CORE_JOBS ?= 8
XCODE_ARCLITE ?= $(ONEGRAM_ROOT)/theos/lib/libarclite_iphoneos.a
XCODE_COMPILER_RT ?= $(ONEGRAM_ROOT)/theos/lib/libclang_rt.ios.a
GRAPH_INPUTS := $(wildcard ../*.xcconfig ../Telegraph.xcodeproj/project.pbxproj ../submodules/*/*.xcodeproj/project.pbxproj ../thirdparty/*/*.xcodeproj/project.pbxproj)
$(GENERATED_DIR)/dependencies.mk: Makefile $(GRAPH_INPUTS) scripts/generate.py scripts/xcode_graph.py
	python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
	@touch $@
$(GENERATED_DIR)/%.mk: $(GENERATED_DIR)/dependencies.mk
	@test -f "$@" || python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
include $(GENERATED_DIR)/dependencies.mk
XCODE_LIBRARIES += libOnegramRuntime
ifeq ($(XCODE_TARGET),libOnegramRuntime)
include OnegramRuntime.mk
else
include $(GENERATED_DIR)/$(XCODE_TARGET).mk
endif
ifeq ($(XCODE_TARGET),Telegram)
Telegram_CFLAGS += -I$(ONEGRAM_ROOT)/OnegramRuntime
Telegram_LDFLAGS += $(GENERATED_DIR)/products/libOnegramRuntime.a
Telegram_LINK_INPUTS += $(GENERATED_DIR)/products/libOnegramRuntime.a
ifeq ($(ONEGRAM_ARCH),armv7)
Telegram_LDFLAGS += $(XCODE_COMPILER_RT)
Telegram_LINK_INPUTS += $(XCODE_COMPILER_RT)
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
_THEOS_INTERNAL_IFLAGS_C =
_THEOS_INTERNAL_CFLAGS = $(OPTFLAG) $(DEBUGFLAG)
ifeq ($(XCODE_TARGET),Telegram)
Telegram_RESOURCE_DIRS := $(ONEGRAM_ROOT)/ios6style
Telegram_CODESIGN_FLAGS = -S$(ONEGRAM_ROOT)/theos/Telegram.entitlements
include $(THEOS_MAKE_PATH)/rules.mk
include response-link.mk
include $(THEOS_MAKE_PATH)/application.mk
before-all::
	@python3 scripts/audit_xcode_target.py
	@python3 scripts/preflight.py --toolchain "$(XCODE_TOOLCHAIN_DIR)" --sdk "$(ISYSROOT)" --arclite "$(XCODE_ARCLITE)" --compiler-rt "$(XCODE_COMPILER_RT)"
	@if ! test -x "$(REAL_TARGET_CXX)"; then python3 scripts/setup_legacy_clang.py; fi
	@if test "$(ONEGRAM_ARCH)" = arm64; then python3 scripts/build_arm64_dependencies.py --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)"; fi
	@for target in $(XCODE_LIBRARIES); do $(MAKE) --no-print-directory XCODE_TARGET=$$target all || exit $$?; done
	@python3 scripts/build_core.py --cc "$(CORE_CXX)" --sdk "$(ISYSROOT)" --toolchain "$(XCODE_TOOLCHAIN_DIR)" --jobs "$(CORE_JOBS)"
after-all::
	@python3 scripts/package_app.py --app "$(THEOS_OBJ_DIR)/Telegram.app" --ldid "$(TARGET_CODESIGN)"
	@python3 scripts/verify_binary.py $(APPLICATION_OUTPUT)/Payload/Telegram.app/Telegram
else
include $(THEOS_MAKE_PATH)/library.mk
after-all::
	@mkdir -p $(GENERATED_DIR)/products
	@cp "$(THEOS_OBJ_DIR)/$(XCODE_TARGET).a" "$(GENERATED_DIR)/products/$(XCODE_TARGET).a"
	@if test "$(XCODE_TARGET)" != "libOnegramRuntime"; then python3 scripts/export_headers.py "$(XCODE_TARGET)"; fi
endif
ifeq ($(HOST_OS),Darwin)
TARGET_LD = $(XCODE_TOOLCHAIN_DIR)/bin/clang++
else
TARGET_LD = $(THEOS)/toolchain/linux/iphone/bin/clang++
endif
_THEOS_INTERNAL_LDFLAGS := $(filter-out -lroot%,$(_THEOS_INTERNAL_LDFLAGS))
.PHONY: generate audit ipa preflight
generate:
	python3 scripts/generate.py --configuration "$(XCODE_CONFIGURATION)"
audit:
	python3 scripts/audit_xcode_target.py
preflight:
	python3 scripts/preflight.py --toolchain "$(XCODE_TOOLCHAIN_DIR)" --sdk "$(ISYSROOT)" --arclite "$(XCODE_ARCLITE)" --compiler-rt "$(XCODE_COMPILER_RT)"
ipa: all
.PHONY: universal
universal:
	$(MAKE) ONEGRAM_ARCH=armv7 all
	$(MAKE) ONEGRAM_ARCH=arm64 all
	python3 scripts/package_universal.py --ldid "$(TARGET_CODESIGN)" --toolchain "$(XCODE_TOOLCHAIN_DIR)"
after-clean::
	rm -rf $(GENERATED_DIR)/products $(GENERATED_DIR)/core $(APPLICATION_OUTPUT)/Payload $(APPLICATION_OUTPUT)/Onegram.ipa build/universal

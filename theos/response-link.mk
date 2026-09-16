ifeq ($(THEOS_CURRENT_INSTANCE),Telegram)
ifneq ($(THEOS_CURRENT_ARCH),)
define _THEOS_TEMPLATE_DEFAULT_LINKING_RULE
$$(THEOS_OBJ_DIR)/$(1): $$(OBJ_FILES_TO_LINK) $$(Telegram_LINK_INPUTS) Makefile response-link.mk $$(GENERATED_DIR)/Telegram.mk
	$$(file >$$(THEOS_OBJ_DIR)/Telegram.link.rsp,$$(foreach object,$$(OBJ_FILES_TO_LINK),"$$(object)"))
	@mkdir -p "$$(dir $$@)"
	$$(ECHO_LINKING)$$(TARGET_LD) @"$$(THEOS_OBJ_DIR)/Telegram.link.rsp" $$(ALL_LDFLAGS) -o "$$@"$$(ECHO_END)
ifneq ($$(TARGET_DSYMUTIL),)
	$$(ECHO_DEBUG_SYMBOLS)$$(TARGET_DSYMUTIL) "$$@"$$(ECHO_END)
endif
ifeq ($(SHOULD_STRIP),$(_THEOS_TRUE))
	$$(ECHO_STRIPPING)$$(TARGET_STRIP) $$(ALL_STRIP_FLAGS) "$$@"$$(ECHO_END)
endif
endef
endif
endif

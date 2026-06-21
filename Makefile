ARCHS := arm64
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := TrollSpeed
ENT_PLIST := $(PWD)/supports/entitlements.plist
LAUNCHD_PLIST := $(PWD)/layout/Library/LaunchDaemons/ch.xxtou.hudservices.plist

include $(THEOS)/makefiles/common.mk

TIPA_VERSION := $(shell ./get-version.sh)
APPLICATION_NAME := TrollSpeed

TrollSpeed_USE_MODULES := 0

TrollSpeed_FILES += $(wildcard sources/*.mm sources/*.m)
TrollSpeed_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
TrollSpeed_FILES += $(wildcard sources/*.swift)
TrollSpeed_FILES += $(wildcard sources/SPLarkController/*.swift)
TrollSpeed_FILES += $(wildcard sources/SnapshotSafeView/*.swift)

TrollSpeed_CFLAGS += -fobjc-arc
TrollSpeed_CFLAGS += -Ilibraries/headers
TrollSpeed_CFLAGS += -Isources
TrollSpeed_CFLAGS += -IImGui
TrollSpeed_CFLAGS += -Isources/KIF
# pch 只给 ObjC/ObjC++，不要传给纯 C++ 源文件
TrollSpeed_OBJCFLAGS += -include supports/hudapp-prefix.pch
TrollSpeed_OBJCCFLAGS += -include supports/hudapp-prefix.pch
# ImGui 核心 .cpp 在 imgui/ 子工程编译（可安全使用全局 CCFLAGS，且无 Swift）
# 主工程 .mm 用 per-file CFLAGS（Theos 不支持 per-file CCFLAGS）
sources/HUDRootViewController.mm_CFLAGS += -std=c++11 -fno-rtti
sources/imgui_impl_metal.mm_CFLAGS += -std=c++11 -fno-rtti
MainApplication.mm_CFLAGS += -std=c++14

# 子工程须在主应用链接前编译；LIBRARIES 只在 Theos 库目录搜索，不能用于本地 subproject
TrollSpeed_SUBPROJECTS += libimgui
TrollSpeed_LDFLAGS += $(foreach arch,$(ARCHS),$(abspath libimgui/.theos/obj)/$(arch)/imgui.a)

TrollSpeed_SWIFT_BRIDGING_HEADER += supports/hudapp-bridging-header.h

TrollSpeed_LDFLAGS += -Flibraries

TrollSpeed_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit Metal MetalKit
TrollSpeed_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
TrollSpeed_CODESIGN_FLAGS += -Ssupports/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += libimgui
SUBPROJECTS += prefs
ifneq ($(FINALPACKAGE),1)
SUBPROJECTS += memory_pressure
endif

include $(THEOS_MAKE_PATH)/aggregate.mk

before-all::
	$(ECHO_NOTHING)defaults write $(LAUNCHD_PLIST) ProgramArguments -array "$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/TrollSpeed.app/TrollSpeed" "-hud" || true$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(LAUNCHD_PLIST)$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(LAUNCHD_PLIST)$(ECHO_END)

before-package::
	$(ECHO_NOTHING)mv -f $(THEOS_STAGING_DIR)/usr/local/bin/memory_pressure $(THEOS_STAGING_DIR)/Applications/TrollSpeed.app 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)rmdir $(THEOS_STAGING_DIR)/usr/local/bin 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)rmdir $(THEOS_STAGING_DIR)/usr/local 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)rmdir $(THEOS_STAGING_DIR)/usr 2>/dev/null || true$(ECHO_END)

after-package::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/TrollSpeed.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)defaults delete $(THEOS_STAGING_DIR)/Payload/TrollSpeed.app/Info.plist CFBundleIconName 2>/dev/null || true$(ECHO_END)
	$(ECHO_NOTHING)defaults write $(THEOS_STAGING_DIR)/Payload/TrollSpeed.app/Info.plist CFBundleVersion -string $(shell openssl rand -hex 4)$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(THEOS_STAGING_DIR)/Payload/TrollSpeed.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(THEOS_STAGING_DIR)/Payload/TrollSpeed.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr TrollSpeed_$(TIPA_VERSION).tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)/TrollSpeed_$(TIPA_VERSION).tipa packages/TrollSpeed_$(TIPA_VERSION).tipa$(ECHO_END)

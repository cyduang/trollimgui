ARCHS := arm64
TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := imgui

imgui_USE_MODULES := 0
imgui_INSTALL := 0

imgui_FILES += $(wildcard ../sources/imgui*.cpp)
imgui_FILES := $(filter-out ../sources/imgui_demo.cpp,$(imgui_FILES))

imgui_CFLAGS += -I../sources
imgui_CFLAGS += -I../ImGui
imgui_CCFLAGS += -std=c++11 -fno-rtti

include $(THEOS_MAKE_PATH)/library.mk

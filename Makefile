TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := MinisPersona
MinisPersona_FILES := MinisPersona.m
MinisPersona_CFLAGS := -fobjc-arc
MinisPersona_FRAMEWORKS := UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

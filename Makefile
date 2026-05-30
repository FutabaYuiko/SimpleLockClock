THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
SDKVERSION = 15.6
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleLockClock

SimpleLockClock_FILES = Tweak.xm
SimpleLockClock_CFLAGS = -fobjc-arc
SimpleLockClock_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

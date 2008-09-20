PLAT = Simulator
VERSION = 2.1
CC = /Developer/Platforms/iPhone$(PLAT).platform/Developer/usr/bin/gcc
CFLAGS = -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhoneOS$(VERSION).sdk
CFLAGS += -x objective-c -arch i386 -fmessage-length=0 -pipe -std=c99 -Wno-trigraphs -fpascal-strings -fasm-blocks \
	  -O0 -Wreturn-type -Wunused-variable -D__IPHONE_OS_VERSION_MIN_REQUIRED=20000 \
	  -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk \
	  -fvisibility=hidden -mmacosx-version-min=10.5 -gdwarf-2 

LDFLAGS = -dynamiclib -framework Foundation -framework CoreGraphics

TARGET = MobileLoader-$(PLAT).dylib

all: $(TARGET) copy-$(PLAT)

srcs = MobileLoader.mm
$(TARGET): $(srcs) 
	$(CC) -o $(TARGET) $(CFLAGS) $(LDFLAGS) $(srcs)

copy-Simulator:

location = /Library/MobileSubstrate/DynamicLibraries
install:
	ssh root@$(iphone) rm -f $(location)/MobileLoader.dylib
	scp build/Debug-iphoneos/MobileLoader.app/QuickGold.dylib root@$(iphone):$(location)
	ssh root@$(iphone) ldid -S $(location)/MobileLoader.dylib \&\& restart

clean:
	rm -f $(TARGET)

PLAT = OS
VERSION = 2.1
DYLIB = HapticKeyboard.dylib

CC = /Developer/Platforms/iPhone$(PLAT).platform/Developer/usr/bin/gcc

CFLAGS = -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhoneOS$(VERSION).sdk \
	 -I. -I./Classes 
ifeq ($(PLAT),Simulator)
CFLAGS += -x objective-c -arch i386 -fmessage-length=0 -pipe -std=c99 -Wno-trigraphs -fpascal-strings -fasm-blocks \
	  -O0 -Wreturn-type -Wunused-variable \
          -I/Users/ashu/Documents/Applications/substrate \
          -L/Users/ashu/Documents/Applications/substrate/Simulator \
	  -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk \
	  -fvisibility=hidden -gdwarf-2 

else
CFLAGS += -x objective-c -arch armv6 -pipe -std=c99 -Wno-trigraphs -fpascal-strings -fasm-blocks \
	  -O0 -Wreturn-type -Wunused-variable -fmessage-length=0 -fvisibility=hidden \
	  -gdwarf-2 -mthumb \
          -I/Users/ashu/Documents/Applications/substrate \
	  -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk
endif

LDFLAGS = -dynamiclib -framework Foundation -framework UIKit -framework AddressBook -framework CoreGraphics \
	  -F/Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk/System/Library/PrivateFrameworks \
	  -framework QuartzCore -framework CoreTelephony -framework AudioToolbox -framework CoreLocation -lsubstrate -install_name $(DYLIB) 

TARGET = HapticKeyboard-$(PLAT).dylib

all: $(TARGET) copy-$(PLAT)

srcs = $(wildcard Classes/*.m)
hdrs = $(wildcard Classes/*.h)

$(TARGET): $(srcs) $(hdrs)
	$(CC) -o $(TARGET) $(CFLAGS) $(LDFLAGS) $(srcs)

location = /Library/MobileSubstrate/DynamicLibraries
copy-Simulator:
	cp $(TARGET) $(location)

copy-OS:

iphone = 192.168.0.103
install: HapticKeyboard-OS.dylib copy-OS
	ssh root@$(iphone) rm -f $(location)/HapticKeyboard.dylib
	scp HapticKeyboard-OS.dylib root@$(iphone):$(location)/HapticKeyboard.dylib
	ssh root@$(iphone) ldid -S $(location)/HapticKeyboard.dylib 
	ssh root@$(iphone) restart

distrib: install
	mkdir -p distrib
	scp root@$(iphone):$(location)/HapticKeyboard.dylib distrib/HapticKeyboard.dylib

shutoff: tests/shutoff.m
	$(CC) $(CFLAGS) -o tests/shutoff $<  -F/Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk/System/Library/PrivateFrameworks -framework CoreTelephony -framework Foundation
	ssh root@$(iphone) rm -f /usr/local/bin/shutoff 
	scp tests/shutoff root@$(iphone):/usr/local/bin/shutoff
	ssh root@$(iphone) ldid -S /usr/local/bin/shutoff

clean:
	rm -rf $(TARGET) $(TARGET).dSYM tests/shutoff tests/shutoff.dSYM

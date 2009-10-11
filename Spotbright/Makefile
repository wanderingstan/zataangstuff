PLAT = Simulator
VERSION = 3.0
DYLIB = Spotbright
CC = /Developer/Platforms/iPhone$(PLAT).platform/Developer/usr/bin/gcc

PRIV_FLAGS = -F/Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk/System/Library/PrivateFrameworks
CFLAGS = -D__IPHONE_OS_VERSION_MIN_REQUIRED=20000 $(PRIV_FLAGS)

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

LDFLAGS = -dynamiclib -framework Foundation -framework UIKit -framework Search -framework CoreGraphics -lsubstrate -install_name $(DYLIB).dylib

TARGET = $(DYLIB)-$(PLAT).dylib

all: $(TARGET) copy-$(PLAT)

srcs = $(wildcard *.m)
$(TARGET): $(srcs) 
	$(CC) -o $(TARGET) $(CFLAGS) $(LDFLAGS) $(srcs)

location = /Library/MobileSubstrate/DynamicLibraries
copy-Simulator:
	cp $(TARGET) $(location)
	rm -f ~/Library/Application\ Support/iPhone\ Simulator/User/Library/Preferences/com.saurik.mobilesubstrate.dat

copy-OS:

install: copy-$(PLAT)

iphone = 192.168.0.120
install: $(DYLIB)-OS.dylib copy-OS
	ssh root@$(iphone) rm -f $(location)/$(DYLIB).dylib
	scp $(DYLIB)-OS.dylib root@$(iphone):$(location)/$(DYLIB).dylib
	ssh root@$(iphone) ldid -S $(location)/$(DYLIB).dylib 
	ssh root@$(iphone) restart

distrib: install

clean:
	rm -f $(TARGET)

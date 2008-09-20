PLAT = Simulator
VERSION = 2.1
DYLIB = libsubstrate.dylib

CC = /Developer/Platforms/iPhone$(PLAT).platform/Developer/usr/bin/g++
CFLAGS = -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhoneOS$(VERSION).sdk
ifeq ($(PLAT),Simulator)
CFLAGS += -arch i386 -fmessage-length=0 -pipe -Wno-trigraphs -fpascal-strings -fasm-blocks \
	  -O0 -Wreturn-type -Wunused-variable -D__IPHONE_OS_VERSION_MIN_REQUIRED=20000 \
	  -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk \
	  -mmacosx-version-min=10.5 -gdwarf-2
else
CFLAGS += -arch armv6 -pipe -Wno-trigraphs -fpascal-strings -fasm-blocks \
	  -O0 -Wreturn-type -Wunused-variable -fmessage-length=0 -miphoneos-version-min=$(VERSION) \
	  -gdwarf-2 -mthumb \
	  -isysroot /Developer/Platforms/iPhone$(PLAT).platform/Developer/SDKs/iPhone$(PLAT)$(VERSION).sdk
endif

LDFLAGS = -dynamiclib -framework Foundation -install_name $(DYLIB)

TARGET = $(PLAT)/libsubstrate.dylib

all: $(TARGET) 

srcs = MobileHooker.mm
$(TARGET): $(srcs) 
	$(CC) -o $(TARGET) $(CFLAGS) $(LDFLAGS) $(srcs)

clean:
	rm -f $(TARGET) 

distclean: clean
	rm -f Simulator/libsubstrate.dylib OS/libsubstrate.dylib

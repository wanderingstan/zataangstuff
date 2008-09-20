/* Cydia Substrate - Meta-Library Insert for iPhoneOS
 * Copyright (C) 2008  Jay Freeman (saurik)
*/

/*
 *        Redistribution and use in source and binary
 * forms, with or without modification, are permitted
 * provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer in the documentation
 *    and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse
 *    or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

#include <dlfcn.h>
#include <unistd.h>
#include <objc/runtime.h>

__attribute__((constructor))
static void MSInitialize() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *identifier = (bundle == nil ? nil : [bundle bundleIdentifier]);
    if (identifier == nil)
        goto pool;
    {
        NSLog(@"MS:Notice: Installing: %@", identifier);
        NSFileManager *manager = [NSFileManager defaultManager];

        NSString *dylibs = @"/Users/ashu/Documents/Applications/DynamicLibraries";

        for (NSString *dylib in [manager contentsOfDirectoryAtPath:dylibs error:NULL]) {
            if (![dylib hasSuffix:@".dylib"])
                continue;
            NSString *base = [[dylibs stringByAppendingPathComponent:dylib] stringByDeletingPathExtension];
            NSLog(@"MS:Notice: Loading: %@", dylib);

            NSString *path = [dylibs stringByAppendingPathComponent:dylib];
            void *handle = dlopen([path UTF8String], RTLD_LAZY | RTLD_GLOBAL);
            if (handle == NULL) {
                NSLog(@"MS:Error: %s", dlerror());
                continue;
            }
        }
    }

  pool:
    [pool release];
}

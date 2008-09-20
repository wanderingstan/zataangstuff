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

#import <Foundation/Foundation.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <objc/runtime.h>
#include <sys/mman.h>

#include <unistd.h>

extern "C" 
void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    if (_class == nil)
        return;

    Method method = class_getInstanceMethod(_class, sel);
    if (method == nil)
        return;

    const char *name = sel_getName(sel);
    const char *type = method_getTypeEncoding(method);

    if (prefix != NULL) {
        size_t namelen = strlen(name);
        size_t fixlen = strlen(prefix);

        char newname[fixlen + namelen + 1];
        memcpy(newname, prefix, fixlen);
        memcpy(newname + fixlen, name, namelen + 1);

        if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
            NSLog(@"WB:Error: failed to rename [%s %s]", class_getName(_class), name);
    }

    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    for (unsigned int index = 0; index != count; ++index)
        if (methods[index] == method)
            goto found;

    if (imp != NULL)
        if (!class_addMethod(_class, sel, imp, type))
            NSLog(@"WB:Error: failed to rename [%s %s]", class_getName(_class), name);
    goto done;

  found:
    if (imp != NULL)
        method_setImplementation(method, imp);

  done:
    free(methods);
}


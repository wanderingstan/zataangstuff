#import <Foundation/Foundation.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <objc/runtime.h>
#include <sys/mman.h>

#include <unistd.h>

extern "C"
void test () { 
    NSLog(@"hola dude");
}

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


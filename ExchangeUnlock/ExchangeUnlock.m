#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <substrate.h>

@class SBApplication;
@class SBUIController;
@class SBIconController;
@class SBDownloadController;
@class SpringBoard;

/**
 * When you turn on an Exchange email account, iPhone auto-locks the screen
 * so that a password is needed every single time you slide the slider. That
 * is pretty f*ckin' annoying. This tool gets rid of that.
 *
 * @author zataang
 */
bool Debug_ = true;
#define RenamePrefix "exch_unl_"
void MyRename(bool instance, const char *classname, SEL sel, IMP newimp);

static BOOL __SBAwayController__isPasswordProtected(id self, SEL sel) {
    NSLog ([NSString stringWithFormat:@"isPasswordProtected called"]);
    return NO;
}

__attribute__((constructor))
static void EtcDylibInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    if ([appId hasSuffix: @"springboard"]) { 
        MyRename(YES, "SBAwayController", @selector(isPasswordProtected), (IMP)&__SBAwayController__isPasswordProtected);
    } else {
    }
    
    [pool release];
}

void MyInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}

void MyRename(bool instance, const char *name, SEL sel, IMP newimp) {    
    NSLog(@"Renaming %s::%@", name, NSStringFromSelector(sel));
    Class _class = objc_getClass(name);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", name);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    MSHookMessage(_class, sel, newimp, RenamePrefix);
}

